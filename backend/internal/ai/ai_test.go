package ai_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/ai"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/audit"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
)

func setupAITestEnv() (*ai.Service, *ai.FakeProvider, *region.MemoryStore, *audit.Service) {
	fakeProvider := ai.NewFakeProvider()
	regStore := region.NewMemoryStore()
	auditStore := audit.NewMemoryStore()
	auditSvc := audit.NewService(auditStore)
	anonymizer := ai.NewAnonymizer()

	svc := ai.NewService(fakeProvider, regStore, anonymizer, auditSvc)

	// Setup test RTs
	ctx := context.Background()
	_ = regStore.CreateRegion(ctx, &region.Region{
		ID:        "rt-active",
		Name:      "RT 01",
		Code:      "RT01",
		Type:      region.TypeRT,
		AIEnabled: true,
	})
	_ = regStore.CreateRegion(ctx, &region.Region{
		ID:        "rt-disabled",
		Name:      "RT 02",
		Code:      "RT02",
		Type:      region.TypeRT,
		AIEnabled: false, // AI disabled by RT policy (FR-AI-07)
	})

	return svc, fakeProvider, regStore, auditSvc
}

// 1. Interface Compliance: All providers must implement LLMProvider
func TestAdapters_InterfaceCompliance(t *testing.T) {
	var _ ai.LLMProvider = ai.NewFakeProvider()
	var _ ai.LLMProvider = ai.NewOllamaProvider("http://localhost:11434", "qwen2.5:3b", 5*time.Second)
	var _ ai.LLMProvider = ai.NewGeminiProvider("dummy-key", "gemini-1.5-flash", 5*time.Second)

	fake := ai.NewFakeProvider()
	if fake.Name() != "fake" {
		t.Errorf("expected provider name 'fake', got '%s'", fake.Name())
	}

	ollama := ai.NewOllamaProvider("", "", 0)
	if ollama.Name() != "ollama" {
		t.Errorf("expected provider name 'ollama', got '%s'", ollama.Name())
	}

	gemini := ai.NewGeminiProvider("", "", 0)
	if gemini.Name() != "gemini" {
		t.Errorf("expected provider name 'gemini', got '%s'", gemini.Name())
	}
}

// 2. Anonymizer Mixed Data: Tests name, phone, address, and health note scrubbing
func TestAnonymizer_MixedDataSanitization(t *testing.T) {
	anonymizer := ai.NewAnonymizer()

	rawText := "Pak Budi Santoso di Jl. Mawar No. 12 RT 03/05 (telepon 081234567890) melapor air masuk rumah. " +
		"Kakek Ahmad menderita stroke dan diabetes, butuh evakuasi segera!"

	anon := anonymizer.AnonymizeText(rawText, "Budi Santoso", "Ahmad")

	// PII Assertions
	if strings.Contains(anon, "Budi Santoso") {
		t.Errorf("expected citizen name to be redacted, got: %s", anon)
	}
	if strings.Contains(anon, "Ahmad") {
		t.Errorf("expected second citizen name to be redacted, got: %s", anon)
	}
	if strings.Contains(anon, "081234567890") {
		t.Errorf("expected phone number to be redacted, got: %s", anon)
	}
	if strings.Contains(anon, "Jl. Mawar") {
		t.Errorf("expected street address to be redacted, got: %s", anon)
	}
	if strings.Contains(anon, "stroke") || strings.Contains(anon, "diabetes") {
		t.Errorf("expected medical diagnoses to be redacted, got: %s", anon)
	}

	// Must contain privacy tokens
	if !strings.Contains(anon, "[WARGA_") {
		t.Errorf("expected [WARGA_n] placeholder, got: %s", anon)
	}
	if !strings.Contains(anon, "[TELEPON_DIHAPUS]") {
		t.Errorf("expected [TELEPON_DIHAPUS] placeholder, got: %s", anon)
	}
	if !strings.Contains(anon, "[ALAMAT_DIHAPUS]") {
		t.Errorf("expected [ALAMAT_DIHAPUS] placeholder, got: %s", anon)
	}
	if !strings.Contains(anon, "[KONDISI_MEDIS]") {
		t.Errorf("expected [KONDISI_MEDIS] placeholder, got: %s", anon)
	}
}

// 3. Proof of Pre-Anonymization: Provider MUST receive already-anonymized data, not raw PII!
func TestPreAnonymizationProof_ProviderReceivesOnlySanitizedData(t *testing.T) {
	svc, fakeProvider, _, _ := setupAITestEnv()
	ctx := context.Background()

	rawMsgs := []ai.RawMessage{
		{
			ID:            "msg-01",
			BlockID:       "A",
			Text:          "Tolong Pak RT, saya Siti Aminah di Jl. Anggrek No. 8 (081987654321). Ayah saya lumpuh dan asma!",
			SenderName:    "Siti Aminah",
			SenderPhone:   "081987654321",
			SenderAddress: "Jl. Anggrek No. 8",
			Timestamp:     time.Now(),
		},
	}

	// 1. Call Summarize
	summary, err := svc.Summarize(ctx, "rt-active", rawMsgs)
	if err != nil {
		t.Fatalf("Summarize failed: %v", err)
	}
	if summary == nil {
		t.Fatalf("expected non-nil summary")
	}

	// VERIFICATION: Check the exact arguments received by LLMProvider!
	if len(fakeProvider.LastSummarizeMsgs) == 0 {
		t.Fatalf("fake provider received no messages")
	}
	receivedText := fakeProvider.LastSummarizeMsgs[0].Text

	// Provider MUST NOT have received Siti Aminah, phone, street, or medical diagnosis!
	if strings.Contains(receivedText, "Siti Aminah") {
		t.Fatalf("BREACH: Raw name leaked to LLM provider! Received: %s", receivedText)
	}
	if strings.Contains(receivedText, "081987654321") {
		t.Fatalf("BREACH: Raw phone leaked to LLM provider! Received: %s", receivedText)
	}
	if strings.Contains(receivedText, "Jl. Anggrek") {
		t.Fatalf("BREACH: Raw address leaked to LLM provider! Received: %s", receivedText)
	}
	if strings.Contains(receivedText, "lumpuh") || strings.Contains(receivedText, "asma") {
		t.Fatalf("BREACH: Raw health condition leaked to LLM provider! Received: %s", receivedText)
	}

	// 2. Call ClassifyNeeds
	rawClassifyText := "Ibu Siti di Jl. Dahlia No 3 (085512344321) butuh perahu, kakek serangan stroke"
	_, err = svc.ClassifyNeeds(ctx, "rt-active", rawClassifyText)
	if err != nil {
		t.Fatalf("ClassifyNeeds failed: %v", err)
	}

	// VERIFICATION: Provider received sanitized text
	classifyReceived := fakeProvider.LastClassifyText
	if strings.Contains(classifyReceived, "085512344321") || strings.Contains(classifyReceived, "Jl. Dahlia") || strings.Contains(classifyReceived, "stroke") {
		t.Fatalf("BREACH: Raw PII leaked to LLM provider in ClassifyNeeds: %s", classifyReceived)
	}
}

// 4. Verification: Sensitive data is not logged in prompt/error logs
func TestNoSensitiveDataInLogs(t *testing.T) {
	anonymizer := ai.NewAnonymizer()
	rawErrorMsg := "Failed to contact citizen Ahmad Dahlan (081233445566) at Jl. Melati No. 5 regarding cuci darah schedule"

	sanitizedLog := anonymizer.SanitizeLog(rawErrorMsg)

	if strings.Contains(sanitizedLog, "081233445566") {
		t.Errorf("phone number leaked in log: %s", sanitizedLog)
	}
	if strings.Contains(sanitizedLog, "Jl. Melati") {
		t.Errorf("address leaked in log: %s", sanitizedLog)
	}
	if strings.Contains(sanitizedLog, "cuci darah") {
		t.Errorf("medical detail leaked in log: %s", sanitizedLog)
	}
}

// 5. RT AI Switch Enforcement: Calls on disabled RT must be rejected and NEVER hit provider
func TestAISettings_ToggleEnforcement(t *testing.T) {
	svc, fakeProvider, regStore, _ := setupAITestEnv()
	ctx := context.Background()

	rawMsgs := []ai.RawMessage{
		{
			ID:        "msg-01",
			BlockID:   "B",
			Text:      "Air naik semata kaki di blok B",
			Timestamp: time.Now(),
		},
	}

	// 1. RT with AI Disabled -> MUST fail immediately
	_, err := svc.Summarize(ctx, "rt-disabled", rawMsgs)
	if err == nil {
		t.Fatalf("expected ErrAIDisabledForRT, got nil")
	}
	if err != ai.ErrAIDisabledForRT {
		t.Errorf("expected ErrAIDisabledForRT, got: %v", err)
	}

	// Crucial check: Provider was NEVER called!
	if fakeProvider.SummarizeCalls != 0 {
		t.Errorf("provider was called %d times despite AI being disabled for RT!", fakeProvider.SummarizeCalls)
	}

	// ClassifyNeeds on disabled RT
	_, err = svc.ClassifyNeeds(ctx, "rt-disabled", "Air masuk rumah butuh bantuan")
	if err != ai.ErrAIDisabledForRT {
		t.Errorf("expected ErrAIDisabledForRT, got: %v", err)
	}
	if fakeProvider.ClassifyNeedsCalls != 0 {
		t.Errorf("provider was called %d times despite AI being disabled for RT!", fakeProvider.ClassifyNeedsCalls)
	}

	// 2. Enable AI on RT-disabled and verify it now succeeds
	err = svc.SetAIEnabled(ctx, "rt-disabled", true, "admin-1", "127.0.0.1", "test-agent")
	if err != nil {
		t.Fatalf("failed to enable AI for RT: %v", err)
	}

	// Verify setting state
	settings, err := svc.GetAISettings(ctx, "rt-disabled")
	if err != nil || !settings.AIEnabled {
		t.Fatalf("expected AI to be enabled for rt-disabled, got: %v", settings)
	}

	// Now call should succeed and hit provider
	_, err = svc.Summarize(ctx, "rt-disabled", rawMsgs)
	if err != nil {
		t.Fatalf("Summarize failed after enabling AI: %v", err)
	}
	if fakeProvider.SummarizeCalls != 1 {
		t.Errorf("expected 1 provider call, got %d", fakeProvider.SummarizeCalls)
	}

	_ = regStore
}

// 6. Provider Failures & Timeouts Handled Without Hallucinating
func TestProvider_FailuresAndTimeout(t *testing.T) {
	svc, fakeProvider, _, _ := setupAITestEnv()
	ctx := context.Background()

	// 1. Connection error / unavailable
	fakeProvider.ForceError = ai.ErrProviderUnavailable
	_, err := svc.ClassifyNeeds(ctx, "rt-active", "Air banjir masuk rumah")
	if err == nil {
		t.Fatalf("expected error on provider failure, got success")
	}
	if err != ai.ErrProviderUnavailable {
		t.Errorf("expected ErrProviderUnavailable, got: %v", err)
	}

	// 2. Timeout error
	fakeProvider.ForceError = nil
	fakeProvider.ForceTimeout = true
	_, err = svc.DraftRecap(ctx, "rt-active", ai.RecapAggregate{
		RTName: "RT 05",
		Hazard: "banjir",
	})
	if err == nil {
		t.Fatalf("expected error on provider timeout, got success")
	}
	if err != ai.ErrProviderTimeout {
		t.Errorf("expected ErrProviderTimeout, got: %v", err)
	}
}

// 7. Output Labels & Human Confirmation Flags (FR-AI-06)
func TestAIOutput_LabelsAndHumanReview(t *testing.T) {
	svc, _, _, _ := setupAITestEnv()
	ctx := context.Background()

	// Summarize output
	summary, err := svc.Summarize(ctx, "rt-active", []ai.RawMessage{
		{ID: "m1", BlockID: "C", Text: "Jalan tergenang 20 cm", Timestamp: time.Now()},
	})
	if err != nil {
		t.Fatalf("Summarize failed: %v", err)
	}
	if !summary.AIAssisted {
		t.Errorf("expected ai_assisted = true")
	}
	if summary.Label != "Dibuat dengan bantuan AI - periksa kembali" {
		t.Errorf("unexpected label: %s", summary.Label)
	}

	// Classify output
	suggestion, err := svc.ClassifyNeeds(ctx, "rt-active", "Ada lansia butuh evakuasi perahu karet")
	if err != nil {
		t.Fatalf("ClassifyNeeds failed: %v", err)
	}
	if !suggestion.AIAssisted {
		t.Errorf("expected ai_assisted = true")
	}
	if suggestion.Label != "Dibuat dengan bantuan AI - periksa kembali" {
		t.Errorf("unexpected label: %s", suggestion.Label)
	}
	if suggestion.Urgency != "kritis" {
		t.Errorf("expected urgency kritis, got %s", suggestion.Urgency)
	}
	if !suggestion.HasVulnerable {
		t.Errorf("expected has_vulnerable = true")
	}

	// Draft Recap output
	draftResult, err := svc.DraftRecap(ctx, "rt-active", ai.RecapAggregate{
		RTName:               "RT 01",
		KelurahanName:        "Sukamaju",
		Hazard:               "banjir",
		Duration:             "2 jam",
		TotalHouseholds:      50,
		SafeHouseholds:       40,
		NeedHelpHouseholds:   10,
		VulnerablePercentage: 100.0,
	})
	if err != nil {
		t.Fatalf("DraftRecap failed: %v", err)
	}
	if !draftResult.AIAssisted {
		t.Errorf("expected ai_assisted = true")
	}
	if draftResult.Label != "Dibuat dengan bantuan AI - periksa kembali" {
		t.Errorf("unexpected label: %s", draftResult.Label)
	}
}

// 8. Draft Recap does NOT automatically finalize recap without human approval
func TestDraftRecap_RequiresApproval(t *testing.T) {
	svc, _, _, _ := setupAITestEnv()
	ctx := context.Background()

	result, err := svc.DraftRecap(ctx, "rt-active", ai.RecapAggregate{
		RTName: "RT 01",
		Hazard: "banjir",
	})
	if err != nil {
		t.Fatalf("DraftRecap failed: %v", err)
	}

	// Verify that the result is merely a draft narrative string, not an approved recap
	if result.DraftNarrative == "" {
		t.Fatalf("expected non-empty draft narrative")
	}
	// AI assistant does NOT approve or create final binding decisions (FR-AI-06)
	if result.AIAssisted != true {
		t.Errorf("expected ai_assisted flag to remain true")
	}
}

// 9. HTTP Handlers Test
func TestHandler_Endpoints(t *testing.T) {
	svc, _, regStore, _ := setupAITestEnv()
	jwtSecret := []byte("test-jwt-secret-at-least-32-bytes-long")
	regionSvc := region.NewService(regStore)
	handler := ai.NewHandler(svc, jwtSecret, regionSvc)

	r := chi.NewRouter()
	handler.Routes(r)

	token, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "pengurus-01",
		Role:     "pengurus",
		RegionID: "rt-active",
	})

	// A. Test POST /ai/summarize
	sumBody := `{"rt_id":"rt-active","messages":[{"id":"m1","block_id":"A","text":"Air naik di blok A","timestamp":"2026-10-24T08:00:00Z"}]}`
	req := httptest.NewRequest(http.MethodPost, "/ai/summarize", strings.NewReader(sumBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("POST /ai/summarize failed, expected 200 got %d: %s", w.Code, w.Body.String())
	}

	// B. Test POST /ai/classify
	clsBody := `{"rt_id":"rt-active","text":"Ada kakek sakit butuh perahu evakuasi segera"}`
	req = httptest.NewRequest(http.MethodPost, "/ai/classify", strings.NewReader(clsBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("POST /ai/classify failed, expected 200 got %d: %s", w.Code, w.Body.String())
	}

	// C. Test GET /rts/rt-active/ai-settings
	req = httptest.NewRequest(http.MethodGet, "/rts/rt-active/ai-settings", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("GET /rts/rt-active/ai-settings failed, expected 200 got %d: %s", w.Code, w.Body.String())
	}

	// D. Test PATCH /rts/rt-active/ai-settings (Disable AI)
	toggleBody := `{"ai_enabled": false}`
	req = httptest.NewRequest(http.MethodPatch, "/rts/rt-active/ai-settings", strings.NewReader(toggleBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("PATCH /rts/rt-active/ai-settings failed, expected 200 got %d: %s", w.Code, w.Body.String())
	}

	// E. Test that calling /ai/classify now fails because AI was disabled on rt-active!
	req = httptest.NewRequest(http.MethodPost, "/ai/classify", strings.NewReader(clsBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Fatalf("expected 403 Forbidden after disabling AI, got %d: %s", w.Code, w.Body.String())
	}
}
