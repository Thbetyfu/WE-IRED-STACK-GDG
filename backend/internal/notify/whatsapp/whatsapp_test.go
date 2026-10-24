package whatsapp_test

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/whatsapp"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/jobs"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

// TestTemplatePayloads_AllFiveTemplates verifies that all 5 Meta-approved templates
// conform to the specified schema, components, and parameter definitions (SDD 10.1).
func TestTemplatePayloads_AllFiveTemplates(t *testing.T) {
	phone := "6281234567890"

	// 1. otp_login (Authentication)
	otpReq := whatsapp.BuildOTPLoginPayload(phone, "123456")
	if otpReq.Template.Name != whatsapp.TemplateOTPLogin {
		t.Errorf("expected template %s, got %s", whatsapp.TemplateOTPLogin, otpReq.Template.Name)
	}
	if otpReq.Template.Language.Code != "id" {
		t.Errorf("expected language 'id', got %s", otpReq.Template.Language.Code)
	}
	if len(otpReq.Template.Components) != 2 {
		t.Fatalf("expected 2 components in otp_login, got %d", len(otpReq.Template.Components))
	}
	if otpReq.Template.Components[0].Parameters[0].Text != "123456" {
		t.Errorf("mismatched OTP code in body parameter")
	}

	// 2. siaga_aktivasi (Utility)
	aktReq := whatsapp.BuildSiagaAktivasiPayload(phone, "nyata", "Gempa Bumi", "RT 05", "INC001")
	if aktReq.Template.Name != whatsapp.TemplateSiagaAktivasi {
		t.Errorf("expected template %s, got %s", whatsapp.TemplateSiagaAktivasi, aktReq.Template.Name)
	}
	if len(aktReq.Template.Components) != 4 { // 1 body + 3 quick reply buttons
		t.Fatalf("expected 4 components in siaga_aktivasi, got %d", len(aktReq.Template.Components))
	}
	btn0Payload := aktReq.Template.Components[1].Parameters[0].Text
	if btn0Payload != "RPT|INC001|1" {
		t.Errorf("expected button 0 payload RPT|INC001|1, got %s", btn0Payload)
	}
	btn2Payload := aktReq.Template.Components[3].Parameters[0].Text
	if btn2Payload != "RPT|INC001|3" {
		t.Errorf("expected button 2 payload RPT|INC001|3, got %s", btn2Payload)
	}

	// 3. siaga_pengingat (Utility)
	pngReq := whatsapp.BuildSiagaPengingatPayload(phone, "RT 05", 10, "INC001")
	if pngReq.Template.Name != whatsapp.TemplateSiagaPengingat {
		t.Errorf("expected template %s, got %s", whatsapp.TemplateSiagaPengingat, pngReq.Template.Name)
	}
	if pngReq.Template.Components[0].Parameters[1].Text != "10" {
		t.Errorf("expected minutes elapsed '10', got %s", pngReq.Template.Components[0].Parameters[1].Text)
	}

	// 4. pengumuman_rt (Utility)
	annReq := whatsapp.BuildPengumumanRTPayload(phone, "DARURAT", "Evakuasi mandiri segera ke Lapangan RW")
	if annReq.Template.Name != whatsapp.TemplatePengumumanRT {
		t.Errorf("expected template %s, got %s", whatsapp.TemplatePengumumanRT, annReq.Template.Name)
	}
	if annReq.Template.Components[0].Parameters[0].Text != "DARURAT" {
		t.Errorf("expected level 'DARURAT', got %s", annReq.Template.Components[0].Parameters[0].Text)
	}

	// 5. rekap_insiden (Utility)
	rekapReq := whatsapp.BuildRekapInsidenPayload(phone, "RT 05", "24 Okt 2026", "https://weired.local/pdf/rekap-01.pdf")
	if rekapReq.Template.Name != whatsapp.TemplateRekapInsiden {
		t.Errorf("expected template %s, got %s", whatsapp.TemplateRekapInsiden, rekapReq.Template.Name)
	}
	if rekapReq.Template.Components[0].Type != "header" || rekapReq.Template.Components[0].Parameters[0].Document == nil {
		t.Errorf("expected header document component in rekap_insiden")
	}
}

// TestWebhook_SignatureValidation tests HMAC-SHA256 signature verification (FR-WA-07).
func TestWebhook_SignatureValidation(t *testing.T) {
	appSecret := "meta-app-secret-12345"
	body := []byte(`{"object":"whatsapp_business_account","entry":[]}`)

	// Compute valid HMAC
	mac := hmac.New(sha256.New, []byte(appSecret))
	mac.Write(body)
	validSig := "sha256=" + hex.EncodeToString(mac.Sum(nil))

	// 1. Valid signature succeeds
	if !whatsapp.ValidateWebhookSignature(appSecret, body, validSig) {
		t.Errorf("expected signature to be valid")
	}

	// 2. Tampered body fails
	tamperedBody := []byte(`{"object":"whatsapp_business_account","entry":[{"id":"fake"}]}`)
	if whatsapp.ValidateWebhookSignature(appSecret, tamperedBody, validSig) {
		t.Errorf("expected tampered body to fail signature validation")
	}

	// 3. Wrong secret fails
	if whatsapp.ValidateWebhookSignature("wrong-secret", body, validSig) {
		t.Errorf("expected wrong secret to fail signature validation")
	}

	// 4. Missing sha256 prefix fails
	if whatsapp.ValidateWebhookSignature(appSecret, body, hex.EncodeToString(mac.Sum(nil))) {
		t.Errorf("expected missing sha256 prefix to fail")
	}
}

// TestWebhook_Idempotency_NoDoubleProcessing verifies duplicate webhooks are ignored (FR-WA-07).
func TestWebhook_Idempotency_NoDoubleProcessing(t *testing.T) {
	ctx := context.Background()

	client := whatsapp.NewSimulatedClient()
	store := whatsapp.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	svc := whatsapp.NewService(client, store, hhStore, incStore, repStore, repSvc, nil, nil)

	// Pre-create household and active incident
	hh := &household.Household{
		ID:       "hh-01",
		RTID:     "rt-01",
		HeadName: "Pak RT",
		WAPhone:  "628123456789",
	}
	_ = hhStore.CreateHousehold(ctx, hh)

	inc := &incident.Incident{
		ID:      "inc-01",
		RTID:    "rt-01",
		ShortID: 101,
		Status:  incident.StatusAktif,
		Hazard:  incident.HazardGempa,
	}
	_ = incStore.CreateIncident(ctx, inc)

	msgID := "wamid.DUPLICATE_TEST_001"

	// 1. First delivery
	err := svc.HandleIncomingMessage(ctx, "628123456789", msgID, "Aman", "RPT|101|1")
	if err != nil {
		t.Fatalf("unexpected error on first incoming message: %v", err)
	}

	// Verify report created
	rep, err := repStore.GetReportBySeq(ctx, "inc-01", "hh-01", 1)
	if err != nil || rep == nil {
		t.Fatalf("expected report to be created for hh-01")
	}

	// 2. Duplicate delivery with same message ID
	err = svc.HandleIncomingMessage(ctx, "628123456789", msgID, "Aman", "RPT|101|1")
	if err != nil {
		t.Fatalf("unexpected error on duplicate message: %v", err)
	}

	// Verify no second report created
	rep2, _ := repStore.GetReportBySeq(ctx, "inc-01", "hh-01", 2)
	if rep2 != nil {
		t.Fatalf("CRITICAL VIOLATION: duplicate message generated duplicate business report")
	}
}

// TestConversationalFlow_ButuhBantuan verifies the interactive state machine:
// Daftar Kebutuhan -> Urgensi -> Pesan Tambahan (FR-WA-04 & SDD 10.1).
func TestConversationalFlow_ButuhBantuan(t *testing.T) {
	ctx := context.Background()

	client := whatsapp.NewSimulatedClient()
	store := whatsapp.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	svc := whatsapp.NewService(client, store, hhStore, incStore, repStore, repSvc, nil, nil)

	phone := "62811223344"
	hh := &household.Household{
		ID:       "hh-bantuan-01",
		RTID:     "rt-01",
		HeadName: "Ibu Hartati",
		WAPhone:  phone,
	}
	_ = hhStore.CreateHousehold(ctx, hh)

	inc := &incident.Incident{
		ID:      "inc-bantuan-01",
		RTID:    "rt-01",
		ShortID: 202,
		Status:  incident.StatusAktif,
		Hazard:  incident.HazardBanjir,
	}
	_ = incStore.CreateIncident(ctx, inc)

	// Step 1: Citizen presses "Butuh Bantuan" (RPT|202|3)
	err := svc.HandleIncomingMessage(ctx, phone, "wamid.BTN_01", "Butuh Bantuan", "RPT|202|3")
	if err != nil {
		t.Fatalf("Step 1 failed: %v", err)
	}

	// Verify session initialized to awaiting_needs
	sess, err := store.GetSession(ctx, phone)
	if err != nil || sess.Step != whatsapp.StepAwaitingNeeds {
		t.Fatalf("expected session step awaiting_needs, got %v", sess)
	}

	lastMsg := client.LastSentMessage(phone)
	if !strings.Contains(lastMsg.Text, "BUTUH BANTUAN") || !strings.Contains(lastMsg.Text, "Evakuasi") {
		t.Errorf("expected needs prompt, got: %s", lastMsg.Text)
	}

	// Step 2: Citizen enters invalid input ("bantuan apa ya?")
	err = svc.HandleIncomingMessage(ctx, phone, "wamid.TXT_01", "bantuan apa ya?", "")
	if err != nil {
		t.Fatalf("Step 2 failed: %v", err)
	}

	// Verify session context is PRESERVED, not broken
	sess, _ = store.GetSession(ctx, phone)
	if sess.Step != whatsapp.StepAwaitingNeeds {
		t.Errorf("session step should remain awaiting_needs after invalid input, got %s", sess.Step)
	}
	lastMsg = client.LastSentMessage(phone)
	if !strings.Contains(lastMsg.Text, "tidak valid") {
		t.Errorf("expected invalid input guidance, got: %s", lastMsg.Text)
	}

	// Step 3: Citizen enters valid choice "1" (Evakuasi)
	err = svc.HandleIncomingMessage(ctx, phone, "wamid.TXT_02", "1", "")
	if err != nil {
		t.Fatalf("Step 3 failed: %v", err)
	}

	sess, _ = store.GetSession(ctx, phone)
	if sess.Step != whatsapp.StepAwaitingUrgency {
		t.Fatalf("expected step awaiting_urgency, got %s", sess.Step)
	}
	if sess.Context["needs"] != report.NeedEvakuasi {
		t.Errorf("expected needs mask %d, got %v", report.NeedEvakuasi, sess.Context["needs"])
	}

	// Step 4: Citizen enters invalid urgency input ("secepatnya")
	err = svc.HandleIncomingMessage(ctx, phone, "wamid.TXT_03", "secepatnya", "")
	if err != nil {
		t.Fatalf("Step 4 failed: %v", err)
	}
	sess, _ = store.GetSession(ctx, phone)
	if sess.Step != whatsapp.StepAwaitingUrgency {
		t.Errorf("session should stay awaiting_urgency, got %s", sess.Step)
	}

	// Step 5: Citizen enters valid urgency "2" (Kritis)
	err = svc.HandleIncomingMessage(ctx, phone, "wamid.TXT_04", "2", "")
	if err != nil {
		t.Fatalf("Step 5 failed: %v", err)
	}

	sess, _ = store.GetSession(ctx, phone)
	if sess.Step != whatsapp.StepAwaitingMessage {
		t.Fatalf("expected step awaiting_message, got %s", sess.Step)
	}

	// Check report was updated to UrgencyKritis
	st, _ := repStore.GetHouseholdState(ctx, inc.ID, hh.ID)
	if st.Urgency != report.UrgencyKritis {
		t.Errorf("expected urgency %d (Kritis), got %d", report.UrgencyKritis, st.Urgency)
	}

	// Step 6: Citizen sends additional info message
	detailMsg := "Ada 1 lansia lumpuh butuh tandu evakuasi"
	err = svc.HandleIncomingMessage(ctx, phone, "wamid.TXT_05", detailMsg, "")
	if err != nil {
		t.Fatalf("Step 6 failed: %v", err)
	}

	// Verify session is deleted/completed
	_, err = store.GetSession(ctx, phone)
	if err == nil {
		t.Errorf("expected session to be deleted after completion")
	}

	// Final confirmation message
	lastMsg = client.LastSentMessage(phone)
	if !strings.Contains(lastMsg.Text, "Laporan lengkap telah tercatat") {
		t.Errorf("expected final confirmation message, got: %s", lastMsg.Text)
	}
}

// TestReminder_T10_T25_NoDuplicatesOnRestart verifies that reminders
// do not repeatedly send on worker restart and skip already-reported households (FR-WA-05).
func TestReminder_T10_T25_NoDuplicatesOnRestart(t *testing.T) {
	ctx := context.Background()

	client := whatsapp.NewSimulatedClient()
	store := whatsapp.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)
	jobQ := jobs.NewMemoryQueue(100 * time.Millisecond)

	svc := whatsapp.NewService(client, store, hhStore, incStore, repStore, repSvc, jobQ, nil)

	inc := &incident.Incident{
		ID:        "inc-rem-01",
		RTID:      "rt-01",
		ShortID:   303,
		Status:    incident.StatusAktif,
		StartedAt: time.Now().Add(-11 * time.Minute),
	}
	_ = incStore.CreateIncident(ctx, inc)

	// Household A: already submitted report
	hhA := &household.Household{ID: "hh-A", RTID: "rt-01", Number: "A-01", HeadName: "Warga A", WAPhone: "628100000001"}
	_ = hhStore.CreateHousehold(ctx, hhA)
	repA := &report.Report{
		ID:          "rep-A",
		IncidentID:  inc.ID,
		HouseholdID: hhA.ID,
		Status:      report.StatusAman,
		Channel:     "aplikasi",
	}
	_, _ = repSvc.SubmitReport(ctx, repA)

	// Household B: has NOT submitted report
	hhB := &household.Household{ID: "hh-B", RTID: "rt-01", Number: "A-02", HeadName: "Warga B", WAPhone: "628100000002"}
	_ = hhStore.CreateHousehold(ctx, hhB)

	// 1. First run of T+10 reminder job
	err := svc.ProcessReminderJob(ctx, inc.ID, "t10", 10)
	if err != nil {
		t.Fatalf("ProcessReminderJob failed: %v", err)
	}

	// Household A should NOT receive reminder
	msgA := client.LastSentMessage(hhA.WAPhone)
	if msgA != nil {
		t.Fatalf("Household A already reported and must NOT receive reminder")
	}

	// Household B SHOULD receive reminder
	msgB := client.LastSentMessage(hhB.WAPhone)
	if msgB == nil {
		t.Fatalf("Household B has not reported and MUST receive reminder")
	}

	sentCountFirstRun := len(client.GetSentMessages())

	// 2. Simulate Worker Restart / Retry: Re-run T+10
	err = svc.ProcessReminderJob(ctx, inc.ID, "t10", 10)
	if err != nil {
		t.Fatalf("ProcessReminderJob retry failed: %v", err)
	}

	sentCountSecondRun := len(client.GetSentMessages())
	if sentCountSecondRun != sentCountFirstRun {
		t.Fatalf("CRITICAL VIOLATION: reminder sent repeatedly on worker restart/retry! Initial: %d, After: %d",
			sentCountFirstRun, sentCountSecondRun)
	}
}

// TestUnregisteredPhone_SafeResponse tests FR-WA-06:
// Unregistered numbers get guidance without revealing private information.
func TestUnregisteredPhone_SafeResponse(t *testing.T) {
	ctx := context.Background()

	client := whatsapp.NewSimulatedClient()
	store := whatsapp.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	svc := whatsapp.NewService(client, store, hhStore, incStore, repStore, repSvc, nil, nil)

	unregisteredPhone := "628999999999"
	err := svc.HandleIncomingMessage(ctx, unregisteredPhone, "wamid.UNKNOWN_01", "Tolong rumah saya kebakaran", "")
	if err != nil {
		t.Fatalf("HandleIncomingMessage failed: %v", err)
	}

	lastMsg := client.LastSentMessage(unregisteredPhone)
	if lastMsg == nil {
		t.Fatalf("expected response to unregistered phone")
	}

	// Verify guidance text
	if !strings.Contains(lastMsg.Text, "belum terdaftar") || !strings.Contains(lastMsg.Text, "pengurus RT") {
		t.Errorf("expected guide message, got: %s", lastMsg.Text)
	}

	// Verify NO private data leak (no names or internal IDs)
	if strings.Contains(lastMsg.Text, "hh-") || strings.Contains(lastMsg.Text, "rt-") {
		t.Errorf("private system identifiers leaked in unregistered response: %s", lastMsg.Text)
	}
}

// TestDeliveryStatus_Tracking tests notification status progression (FR-WA-07).
func TestDeliveryStatus_Tracking(t *testing.T) {
	ctx := context.Background()

	client := whatsapp.NewSimulatedClient()
	store := whatsapp.NewMemoryStore()
	svc := whatsapp.NewService(client, store, nil, nil, nil, nil, nil, nil)

	// Send OTP
	phone := "628123456789"
	err := svc.SendOTP(ctx, phone, "654321", 300)
	if err != nil {
		t.Fatalf("SendOTP failed: %v", err)
	}

	notifs, _ := store.ListNotificationsByRecipient(ctx, phone, 1)
	if len(notifs) != 1 {
		t.Fatalf("expected 1 notification record")
	}
	n := notifs[0]
	if n.Status != whatsapp.StatusTerkirim {
		t.Errorf("expected initial status terkirim, got %s", n.Status)
	}
	if n.ProviderID == nil {
		t.Fatalf("expected provider_id to be set")
	}

	provID := *n.ProviderID

	// 1. Webhook delivers 'delivered'
	_ = svc.HandleStatusUpdate(ctx, provID, "delivered", nil)
	updated, _ := store.GetNotification(ctx, n.ID)
	if updated.Status != whatsapp.StatusDiterima {
		t.Errorf("expected status diterima, got %s", updated.Status)
	}

	// 2. Webhook delivers 'read'
	_ = svc.HandleStatusUpdate(ctx, provID, "read", nil)
	updated, _ = store.GetNotification(ctx, n.ID)
	if updated.Status != whatsapp.StatusDibaca {
		t.Errorf("expected status dibaca, got %s", updated.Status)
	}

	// 3. Webhook delivers 'failed'
	errMsg := "User unreachable or blocked"
	_ = svc.HandleStatusUpdate(ctx, provID, "failed", &errMsg)
	updated, _ = store.GetNotification(ctx, n.ID)
	if updated.Status != whatsapp.StatusGagal {
		t.Errorf("expected status gagal, got %s", updated.Status)
	}
	if updated.Error == nil || *updated.Error != errMsg {
		t.Errorf("expected error message to be recorded")
	}
}

// TestHTTPHandler_WebhookRoutes tests the HTTP handler endpoints for Meta verification and webhook reception.
func TestHTTPHandler_WebhookRoutes(t *testing.T) {
	appSecret := "meta-secret-999"
	verifyToken := "my-verify-token-xyz"
	jwtSecret := []byte("jwt-secret-key-32bytes-12345678")

	client := whatsapp.NewSimulatedClient()
	store := whatsapp.NewMemoryStore()
	svc := whatsapp.NewService(client, store, household.NewMemoryStore(), incident.NewMemoryStore(), report.NewMemoryStore(), nil, nil, nil)
	handler := whatsapp.NewHandler(svc, verifyToken, appSecret, jwtSecret)

	r := chi.NewRouter()
	handler.Routes(r)

	// 1. GET Webhook verification handshake (valid token)
	reqVerify := httptest.NewRequest("GET", "/webhook/whatsapp?hub.mode=subscribe&hub.verify_token=my-verify-token-xyz&hub.challenge=CHALLENGE_CODE_123", nil)
	recVerify := httptest.NewRecorder()
	r.ServeHTTP(recVerify, reqVerify)

	if recVerify.Code != http.StatusOK {
		t.Errorf("expected 200 for webhook verification, got %d", recVerify.Code)
	}
	if recVerify.Body.String() != "CHALLENGE_CODE_123" {
		t.Errorf("expected challenge response, got %s", recVerify.Body.String())
	}

	// 2. GET Webhook verification handshake (invalid token)
	reqVerifyInvalid := httptest.NewRequest("GET", "/webhook/whatsapp?hub.mode=subscribe&hub.verify_token=wrong-token&hub.challenge=CODE", nil)
	recVerifyInvalid := httptest.NewRecorder()
	r.ServeHTTP(recVerifyInvalid, reqVerifyInvalid)

	if recVerifyInvalid.Code != http.StatusForbidden {
		t.Errorf("expected 403 Forbidden for wrong verify token, got %d", recVerifyInvalid.Code)
	}

	// 3. POST Webhook with invalid signature must return 401
	reqPostInvalid := httptest.NewRequest("POST", "/webhook/whatsapp", strings.NewReader(`{"object":"whatsapp_business_account"}`))
	reqPostInvalid.Header.Set("X-Hub-Signature-256", "sha256=invalidmac")
	recPostInvalid := httptest.NewRecorder()
	r.ServeHTTP(recPostInvalid, reqPostInvalid)

	if recPostInvalid.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized for invalid signature, got %d", recPostInvalid.Code)
	}

	// 4. POST Webhook with valid signature returns 200 OK
	webhookPayload := `{"object":"whatsapp_business_account","entry":[{"id":"1","changes":[{"field":"messages","value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"123","phone_number_id":"456"},"statuses":[{"id":"wamid.STATUS_01","status":"delivered"}]}}]}]}`
	mac := hmac.New(sha256.New, []byte(appSecret))
	mac.Write([]byte(webhookPayload))
	validSig := "sha256=" + hex.EncodeToString(mac.Sum(nil))

	reqPostValid := httptest.NewRequest("POST", "/webhook/whatsapp", bytes.NewReader([]byte(webhookPayload)))
	reqPostValid.Header.Set("X-Hub-Signature-256", validSig)
	reqPostValid.Header.Set("Content-Type", "application/json")
	recPostValid := httptest.NewRecorder()
	r.ServeHTTP(recPostValid, reqPostValid)

	if recPostValid.Code != http.StatusOK {
		t.Errorf("expected 200 OK for valid webhook, got %d", recPostValid.Code)
	}
}
