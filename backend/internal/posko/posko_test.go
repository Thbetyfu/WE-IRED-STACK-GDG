package posko_test

import (
	"bytes"
	"context"
	"crypto/x509"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/assembly"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/jobs"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/posko"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

// TestSnapshot_EncryptionAndDecryption verifies password-based snapshot encryption (SDD 8.2).
// Ensures:
// - Valid password decrypts cleanly
// - Wrong password strictly fails without data leakage
// - Sensitive fields (health_notes_enc, key_enc) remain encrypted
func TestSnapshot_EncryptionAndDecryption(t *testing.T) {
	ctx := context.Background()

	// 1. Setup sample data with encrypted sensitive fields
	secretKey := []byte("01234567890123456789012345678901") // 32 bytes
	hhService := household.NewService(household.NewMemoryStore(), secretKey)

	// Create household with encrypted health notes
	hh, err := hhService.CreateHousehold(ctx, &household.Household{
		RTID:     "rt-01",
		Number:   "A-01",
		Address:  "Jl. Merdeka No. 1",
		HeadName: "Budi Santoso",
		WAPhone:  "628123456789",
	})
	if err != nil {
		t.Fatalf("failed to create household: %v", err)
	}

	_, err = hhService.RecordConsent(ctx, hh.ID, "Budi Santoso", "digital_form", "v1.0")
	if err != nil {
		t.Fatalf("failed to record consent: %v", err)
	}

	_, err = hhService.AddMember(ctx, &household.Member{
		HouseholdID:     hh.ID,
		Name:            "Kakek Budi",
		Relation:        "Orang Tua",
		BirthYear:       1940,
		NeedsEvacAssist: true,
		HealthNotes:     "Diabetes kronis dan perlu kursi roda",
	})
	if err != nil {
		t.Fatalf("failed to add member: %v", err)
	}

	// Fetch raw household to verify health_notes_enc is indeed encrypted ciphertext
	rawHH, err := hhService.GetHousehold(ctx, hh.ID, "pengurus", nil, nil)
	if err != nil {
		t.Fatalf("failed to get household: %v", err)
	}

	for _, m := range rawHH.Members {
		if strings.Contains(string(m.HealthNotesEnc), "Diabetes") {
			t.Fatalf("CRITICAL SECURITY VIOLATION: Health notes stored in plaintext!")
		}
		if len(m.HealthNotesEnc) == 0 {
			t.Fatalf("expected encrypted health notes to be non-empty")
		}
	}

	payload := &posko.SnapshotPayload{
		Version:     "1.0",
		RTID:        "rt-01",
		ExportedAt:  time.Now().UTC(),
		LastEventID: 42,
		Households:  []*household.Household{rawHH},
	}

	snapshotPassword := "SandiKuatPosko123!#"

	// 2. Encrypt Snapshot
	env, err := posko.EncryptSnapshot(payload, snapshotPassword)
	if err != nil {
		t.Fatalf("EncryptSnapshot failed: %v", err)
	}

	if env.Magic != "WRSN" {
		t.Fatalf("expected Magic 'WRSN', got %s", env.Magic)
	}
	if strings.Contains(env.Ciphertext, "Budi") || strings.Contains(env.Ciphertext, "Merdeka") {
		t.Fatalf("CRITICAL SECURITY VIOLATION: Plaintext leaked in snapshot envelope!")
	}

	// 3. Decrypt with correct password
	decrypted, err := posko.DecryptSnapshot(env, snapshotPassword)
	if err != nil {
		t.Fatalf("DecryptSnapshot failed with valid password: %v", err)
	}

	if decrypted.RTID != "rt-01" {
		t.Errorf("expected RTID 'rt-01', got %s", decrypted.RTID)
	}
	if len(decrypted.Households) != 1 || decrypted.Households[0].HeadName != "Budi Santoso" {
		t.Errorf("decrypted household data mismatch")
	}

	// 4. Decrypt with wrong password must strictly fail
	_, err = posko.DecryptSnapshot(env, "KataSandiSalah123")
	if err == nil {
		t.Fatalf("expected error when decrypting with wrong password, got nil")
	}
	if !strings.Contains(err.Error(), "tidak valid") {
		t.Errorf("expected invalid password error, got: %v", err)
	}

	// 5. Empty password must fail
	_, err = posko.EncryptSnapshot(payload, "")
	if err == nil {
		t.Fatalf("expected error for empty password, got nil")
	}
}

// TestPosko_Push_CursorAndIdempotency tests SDD 8.3 push sync invariants:
// - ack_cursor never skips failed events
// - re-sending events is idempotent
func TestPosko_Push_CursorAndIdempotency(t *testing.T) {
	ctx := context.Background()

	hhStore := household.NewMemoryStore()
	poskoStore := posko.NewMemoryStore()
	eventStore := realtime.NewMemoryEventStore()
	jobQ := jobs.NewMemoryQueue(100 * time.Millisecond)

	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	svc := posko.NewService(
		poskoStore,
		eventStore,
		hhStore,
		region.NewMemoryStore(),
		volunteer.NewMemoryStore(),
		assembly.NewMemoryStore(),
		repSvc,
		nil,
		nil,
		jobQ,
		"cloud",
		"posko-01",
		nil,
	)

	// Pre-create household
	hh := &household.Household{
		ID:       "hh-01",
		RTID:     "rt-01",
		Number:   "A-01",
		Address:  "Jl. Anggrek 1",
		HeadName: "Siti Rahma",
	}
	_ = hhStore.CreateHousehold(ctx, hh)

	incID := "inc-01"

	// Build 2 valid events and 1 invalid event in between
	ev1 := &realtime.Event{
		ID:         1,
		IncidentID: &incID,
		Entity:     "report",
		EntityID:   "rep-01",
		Op:         "INSERT",
		Payload: map[string]any{
			"id":           "rep-01",
			"incident_id":  "inc-01",
			"household_id": "hh-01",
			"status":       float64(report.StatusAman),
			"urgency":      float64(report.UrgencyNone),
			"channel":      report.ChannelAplikasi,
			"seq":          float64(1),
			"reported_at":  time.Now().UTC().Format(time.RFC3339),
		},
	}

	// Event with malformed payload that fails unmarshaling
	ev2 := &realtime.Event{
		ID:         2,
		IncidentID: &incID,
		Entity:     "report",
		EntityID:   "rep-02",
		Op:         "INSERT",
		Payload: map[string]any{
			"id":           "rep-02",
			"incident_id":  "inc-01",
			"household_id": "hh-01",
			"status":       "not_an_int_status", // Fails unmarshal into ReportStatus
		},
	}

	ev3 := &realtime.Event{
		ID:         3,
		IncidentID: &incID,
		Entity:     "report",
		EntityID:   "rep-03",
		Op:         "INSERT",
		Payload: map[string]any{
			"id":           "rep-03",
			"incident_id":  "inc-01",
			"household_id": "hh-01",
			"status":       float64(report.StatusTitikKumpul),
			"urgency":      float64(report.UrgencyNone),
			"channel":      report.ChannelAplikasi,
			"seq":          float64(2),
			"reported_at":  time.Now().UTC().Format(time.RFC3339),
		},
	}

	pushReq := posko.PushRequest{
		PoskoID: "posko-01",
		RTID:    "rt-01",
		Events:  []*realtime.Event{ev1, ev2, ev3},
	}

	resp, err := svc.ProcessPush(ctx, pushReq)
	if err != nil {
		t.Fatalf("ProcessPush unexpected error: %v", err)
	}

	// Cursor INVARIANT: Cursor must halt at event 1, NOT skipping event 2!
	if resp.AckCursor != 1 {
		t.Errorf("CRITICAL INVARIANT VIOLATION: ack_cursor should halt at 1, got %d", resp.AckCursor)
	}
	if resp.EventsApplied != 1 {
		t.Errorf("expected 1 event applied, got %d", resp.EventsApplied)
	}

	// Verify idempotency: Resend ev1
	pushReqRetry := posko.PushRequest{
		PoskoID: "posko-01",
		RTID:    "rt-01",
		Events:  []*realtime.Event{ev1},
	}

	respRetry, err := svc.ProcessPush(ctx, pushReqRetry)
	if err != nil {
		t.Fatalf("ProcessPush retry unexpected error: %v", err)
	}
	if respRetry.AckCursor != 1 {
		t.Errorf("expected AckCursor 1 on retry, got %d", respRetry.AckCursor)
	}
}

// TestPosko_MasterDataConflict verifies FR-PSK-06 conflict detection and recording.
func TestPosko_MasterDataConflict(t *testing.T) {
	ctx := context.Background()

	hhStore := household.NewMemoryStore()
	poskoStore := posko.NewMemoryStore()

	svc := posko.NewService(
		poskoStore,
		nil,
		hhStore,
		region.NewMemoryStore(),
		volunteer.NewMemoryStore(),
		assembly.NewMemoryStore(),
		nil,
		nil,
		nil,
		nil,
		"cloud",
		"posko-01",
		nil,
	)

	// Existing household in Cloud
	cloudHH := &household.Household{
		ID:       "hh-conflict-01",
		RTID:     "rt-01",
		Number:   "B-05",
		Address:  "Jl. Cemara No. 5 (Versi Cloud)",
		HeadName: "Agus Pratama",
	}
	_ = hhStore.CreateHousehold(ctx, cloudHH)

	// Event from Posko with conflicting address
	evConflict := &realtime.Event{
		ID:       10,
		Entity:   "household",
		EntityID: "hh-conflict-01",
		Op:       "UPDATE",
		Payload: map[string]any{
			"id":        "hh-conflict-01",
			"rt_id":     "rt-01",
			"address":   "Jl. Cemara No. 5 Posko Offline Edit",
			"head_name": "Agus Pratama",
		},
	}

	pushReq := posko.PushRequest{
		PoskoID: "posko-01",
		RTID:    "rt-01",
		Events:  []*realtime.Event{evConflict},
	}

	resp, err := svc.ProcessPush(ctx, pushReq)
	if err != nil {
		t.Fatalf("ProcessPush failed: %v", err)
	}

	if resp.ConflictsCount != 1 {
		t.Errorf("expected 1 conflict detected, got %d", resp.ConflictsCount)
	}

	// Verify cloud version was NOT blindly overwritten
	retained, err := hhStore.GetHousehold(ctx, "hh-conflict-01")
	if err != nil {
		t.Fatalf("GetHousehold failed: %v", err)
	}
	if retained.Address != "Jl. Cemara No. 5 (Versi Cloud)" {
		t.Errorf("CRITICAL VIOLATION: Cloud master data was overwritten during conflict: %s", retained.Address)
	}

	// Verify conflict recorded in store and can be listed & resolved
	conflicts, err := svc.ListConflicts(ctx, "rt-01", "unresolved")
	if err != nil {
		t.Fatalf("ListConflicts failed: %v", err)
	}
	if len(conflicts) != 1 {
		t.Fatalf("expected 1 unresolved conflict, got %d", len(conflicts))
	}

	conflictID := conflicts[0].ID
	err = svc.ResolveConflict(ctx, conflictID, "user-admin-01")
	if err != nil {
		t.Fatalf("ResolveConflict failed: %v", err)
	}

	// After resolve, unresolved list should be empty
	unresolved, _ := svc.ListConflicts(ctx, "rt-01", "unresolved")
	if len(unresolved) != 0 {
		t.Errorf("expected 0 unresolved conflicts, got %d", len(unresolved))
	}
}

// TestPosko_DeferredJobsSurvive verifies offline WhatsApp/FCM jobs enqueued survive and execute.
func TestPosko_DeferredJobsSurvive(t *testing.T) {
	ctx := context.Background()

	jobQ := jobs.NewMemoryQueue(50 * time.Millisecond)
	_ = jobQ.Start(ctx)
	defer jobQ.Stop()

	svc := posko.NewService(
		posko.NewMemoryStore(),
		nil,
		household.NewMemoryStore(),
		region.NewMemoryStore(),
		volunteer.NewMemoryStore(),
		assembly.NewMemoryStore(),
		nil,
		nil,
		nil,
		jobQ,
		"cloud",
		"posko-01",
		nil,
	)

	executedJob := make(chan string, 1)
	jobQ.RegisterHandler("whatsapp_reminder", func(ctx context.Context, j *jobs.Job) error {
		var payload map[string]any
		_ = json.Unmarshal(j.Payload, &payload)
		executedJob <- payload["phone"].(string)
		return nil
	})

	pushReq := posko.PushRequest{
		PoskoID: "posko-01",
		RTID:    "rt-01",
		Jobs: []posko.DeferredJob{
			{
				ID:        uuid.NewString(),
				Queue:     "whatsapp_reminder",
				Payload:   map[string]any{"phone": "6281234567890", "message": "Evakuasi segera ke titik kumpul"},
				CreatedAt: time.Now().UTC(),
			},
		},
	}

	_, err := svc.ProcessPush(ctx, pushReq)
	if err != nil {
		t.Fatalf("ProcessPush failed: %v", err)
	}

	select {
	case phone := <-executedJob:
		if phone != "6281234567890" {
			t.Errorf("expected phone 6281234567890, got %s", phone)
		}
	case <-time.After(2 * time.Second):
		t.Fatalf("timed out waiting for deferred job to execute")
	}
}

// TestPosko_SelfSignedCertAndQR verifies TLS certificate generation and QR matching fingerprint.
func TestPosko_SelfSignedCertAndQR(t *testing.T) {
	cert, fp, err := posko.GenerateSelfSignedCert([]string{"192.168.1.100", "weired-posko.local"})
	if err != nil {
		t.Fatalf("GenerateSelfSignedCert failed: %v", err)
	}

	if len(cert.Certificate) == 0 {
		t.Fatalf("expected non-empty TLS certificate")
	}

	// Verify fingerprint format AA:BB:CC:...
	parts := strings.Split(fp, ":")
	if len(parts) != 32 {
		t.Fatalf("expected 32 hex octets in SHA-256 fingerprint, got %d (fp=%s)", len(parts), fp)
	}

	// Verify parsed certificate
	x509Cert, err := x509.ParseCertificate(cert.Certificate[0])
	if err != nil {
		t.Fatalf("ParseCertificate failed: %v", err)
	}

	if x509Cert.Subject.CommonName != "weired-posko.local" {
		t.Errorf("expected CN 'weired-posko.local', got %s", x509Cert.Subject.CommonName)
	}

	// Test QR generation
	svc := posko.NewService(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "posko", "posko-rt01", nil)
	qr, err := svc.GenerateQRConfig("https://192.168.1.100:8443", true, fp, "rt-01")
	if err != nil {
		t.Fatalf("GenerateQRConfig failed: %v", err)
	}

	if qr.CertFingerprint != fp {
		t.Errorf("QR CertFingerprint mismatch: expected %s, got %s", fp, qr.CertFingerprint)
	}
	if qr.EndpointURL != "https://192.168.1.100:8443" {
		t.Errorf("QR EndpointURL mismatch: %s", qr.EndpointURL)
	}
	if !qr.SSL {
		t.Errorf("expected SSL to be true")
	}
}

// TestPosko_HTTPHandler verifies HTTP endpoints with auth & role guards.
func TestPosko_HTTPHandler(t *testing.T) {
	jwtSecret := []byte("test-jwt-secret-key-32bytes-1234")
	poskoStore := posko.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	regStore := region.NewMemoryStore()
	volStore := volunteer.NewMemoryStore()
	asmStore := assembly.NewMemoryStore()

	_ = regStore.CreateRegion(context.Background(), &region.Region{
		ID:   "rt-01",
		Code: "RT01",
		Name: "RT 01",
		Type: region.TypeRT,
	})

	svc := posko.NewService(
		poskoStore,
		nil,
		hhStore,
		regStore,
		volStore,
		asmStore,
		nil,
		nil,
		nil,
		nil,
		"cloud",
		"posko-01",
		nil,
	)

	handler := posko.NewHandler(svc, jwtSecret, nil)

	r := chi.NewRouter()
	handler.Routes(r)

	// 1. QR Config (Public endpoint)
	reqQR := httptest.NewRequest("GET", "/posko/qr-config?rt_id=rt-01&endpoint_url=https://192.168.4.1:8443&fingerprint=AA:BB:CC&ssl=true", nil)
	recQR := httptest.NewRecorder()
	r.ServeHTTP(recQR, reqQR)

	if recQR.Code != http.StatusOK {
		t.Fatalf("expected 200 for QR config, got %d", recQR.Code)
	}

	// Generate tokens
	pengurusToken, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "user-p1",
		Role:     "pengurus",
		RegionID: "rt-01",
	})
	wargaToken, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "user-w1",
		Role:     "warga",
		RegionID: "rt-01",
	})

	// 2. Export Snapshot as Pengurus
	exportBody := map[string]any{
		"rt_id":    "rt-01",
		"password": "PasswordSuperKuat123!",
	}
	exportBytes, _ := json.Marshal(exportBody)

	reqExport := httptest.NewRequest("POST", "/posko/snapshot", bytes.NewReader(exportBytes))
	reqExport.Header.Set("Authorization", "Bearer "+pengurusToken)
	reqExport.Header.Set("Content-Type", "application/json")
	recExport := httptest.NewRecorder()
	r.ServeHTTP(recExport, reqExport)

	if recExport.Code != http.StatusOK {
		t.Fatalf("expected 200 for export snapshot, got %d (body: %s)", recExport.Code, recExport.Body.String())
	}

	var exportRes struct {
		Data posko.EncryptedSnapshotEnvelope `json:"data"`
	}
	_ = json.Unmarshal(recExport.Body.Bytes(), &exportRes)

	if exportRes.Data.Magic != "WRSN" {
		t.Fatalf("expected magic WRSN in exported envelope")
	}

	// 3. Export Snapshot as Warga should be FORBIDDEN
	reqExportWarga := httptest.NewRequest("POST", "/posko/snapshot", bytes.NewReader(exportBytes))
	reqExportWarga.Header.Set("Authorization", "Bearer "+wargaToken)
	recExportWarga := httptest.NewRecorder()
	r.ServeHTTP(recExportWarga, reqExportWarga)

	if recExportWarga.Code != http.StatusForbidden {
		t.Fatalf("expected 403 Forbidden for warga exporting snapshot, got %d", recExportWarga.Code)
	}

	// 4. Import Snapshot with wrong password must return 400 AUTHENTICATION_FAILED
	importWrongBody := map[string]any{
		"envelope": exportRes.Data,
		"password": "WrongPassword!",
	}
	wrongBytes, _ := json.Marshal(importWrongBody)
	reqImportWrong := httptest.NewRequest("POST", "/posko/snapshot/import", bytes.NewReader(wrongBytes))
	reqImportWrong.Header.Set("Authorization", "Bearer "+pengurusToken)
	reqImportWrong.Header.Set("Content-Type", "application/json")
	recImportWrong := httptest.NewRecorder()
	r.ServeHTTP(recImportWrong, reqImportWrong)

	if recImportWrong.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for wrong snapshot password, got %d (body: %s)", recImportWrong.Code, recImportWrong.Body.String())
	}
	if !strings.Contains(recImportWrong.Body.String(), "AUTHENTICATION_FAILED") {
		t.Errorf("expected error code AUTHENTICATION_FAILED, got: %s", recImportWrong.Body.String())
	}

	// 5. Import Snapshot with correct password
	importCorrectBody := map[string]any{
		"envelope": exportRes.Data,
		"password": "PasswordSuperKuat123!",
	}
	correctBytes, _ := json.Marshal(importCorrectBody)
	reqImportCorrect := httptest.NewRequest("POST", "/posko/snapshot/import", bytes.NewReader(correctBytes))
	reqImportCorrect.Header.Set("Authorization", "Bearer "+pengurusToken)
	reqImportCorrect.Header.Set("Content-Type", "application/json")
	recImportCorrect := httptest.NewRecorder()
	r.ServeHTTP(recImportCorrect, reqImportCorrect)

	if recImportCorrect.Code != http.StatusOK {
		t.Fatalf("expected 200 for correct snapshot import, got %d (body: %s)", recImportCorrect.Code, recImportCorrect.Body.String())
	}
}
