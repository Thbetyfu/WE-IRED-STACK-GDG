package incident

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
)

type dummyHierarchyChecker struct{}

func (d *dummyHierarchyChecker) IsRTInRegion(ctx context.Context, regionID, rtID string) (bool, error) {
	return true, nil
}

func TestTwoStepActivationAndExclusivity(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	svc := NewService(store)

	rtID := "rt-001"
	userID := "user-pengurus-1"

	// 1. Direct activation for real mode MUST fail
	_, err := svc.ActivateDirect(ctx, DirectActivationRequest{
		RTID:      rtID,
		Hazard:    HazardBanjir,
		Mode:      ModeNyata,
		Message:   "Banjir bandang",
		StartedBy: userID,
	})
	if err != ErrRealIncidentRequiresConfirmation {
		t.Fatalf("expected ErrRealIncidentRequiresConfirmation, got: %v", err)
	}

	// 2. Draft activation for real mode
	draft, err := svc.DraftActivation(ctx, DraftRequest{
		RTID:      rtID,
		Hazard:    HazardBanjir,
		Mode:      ModeNyata,
		Message:   "Banjir bandang RT 01",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("draft activation failed: %v", err)
	}
	if draft.Token == "" {
		t.Fatal("expected non-empty token")
	}

	// 3. Confirm activation with token
	inc, err := svc.ConfirmActivation(ctx, draft.Token, userID)
	if err != nil {
		t.Fatalf("confirm activation failed: %v", err)
	}
	if inc.Status != StatusAktif {
		t.Fatalf("expected status aktif, got %s", inc.Status)
	}
	if inc.ShortID == 0 {
		t.Fatal("expected non-zero uint32 short_id")
	}
	if inc.Mode != ModeNyata {
		t.Fatalf("expected mode nyata, got %s", inc.Mode)
	}

	// 4. Token cannot be reused
	_, err = svc.ConfirmActivation(ctx, draft.Token, userID)
	if err != ErrDraftNotFoundOrExpired {
		t.Fatalf("expected ErrDraftNotFoundOrExpired on reused token, got: %v", err)
	}

	// 5. While real incident is active, cannot draft another real incident
	_, err = svc.DraftActivation(ctx, DraftRequest{
		RTID:      rtID,
		Hazard:    HazardLongsor,
		Mode:      ModeNyata,
		Message:   "Longsor susulan",
		StartedBy: userID,
	})
	if err != ErrActiveRealIncidentExists {
		t.Fatalf("expected ErrActiveRealIncidentExists, got: %v", err)
	}

	// 6. While real incident is active, drill cannot be started
	_, err = svc.ActivateDirect(ctx, DirectActivationRequest{
		RTID:      rtID,
		Hazard:    HazardGempa,
		Mode:      ModeLatihan,
		Message:   "Latihan gempa",
		StartedBy: userID,
	})
	if err != ErrRealIncidentActive {
		t.Fatalf("expected ErrRealIncidentActive, got: %v", err)
	}

	// 7. End incident
	endedInc, err := svc.EndIncident(ctx, inc.ID)
	if err != nil {
		t.Fatalf("end incident failed: %v", err)
	}
	if endedInc.Status != StatusSelesai {
		t.Fatalf("expected status selesai, got %s", endedInc.Status)
	}
	if endedInc.EndedAt == nil {
		t.Fatal("expected non-nil ended_at")
	}

	// 8. Ending again fails
	_, err = svc.EndIncident(ctx, inc.ID)
	if err != ErrIncidentAlreadyEnded {
		t.Fatalf("expected ErrIncidentAlreadyEnded, got: %v", err)
	}

	// 9. After real incident ended, drill mode CAN be activated directly
	drillInc, err := svc.ActivateDirect(ctx, DirectActivationRequest{
		RTID:      rtID,
		Hazard:    HazardGempa,
		Mode:      ModeLatihan,
		Message:   "Latihan gempa RT 01",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("drill activation failed: %v", err)
	}
	if drillInc.Mode != ModeLatihan {
		t.Fatalf("expected mode latihan, got %s", drillInc.Mode)
	}
}

func TestConcurrentRealIncidentActivation(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	svc := NewService(store)

	rtID := "rt-002"
	userID := "user-pengurus-2"

	// Create two drafts concurrently
	draft1, err := svc.DraftActivation(ctx, DraftRequest{
		RTID:      rtID,
		Hazard:    HazardBanjir,
		Mode:      ModeNyata,
		Message:   "Banjir A",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("draft1 failed: %v", err)
	}

	draft2, err := svc.DraftActivation(ctx, DraftRequest{
		RTID:      rtID,
		Hazard:    HazardBanjir,
		Mode:      ModeNyata,
		Message:   "Banjir B",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("draft2 failed: %v", err)
	}

	var wg sync.WaitGroup
	successCount := 0
	conflictCount := 0
	var mu sync.Mutex

	wg.Add(2)
	go func() {
		defer wg.Done()
		_, err := svc.ConfirmActivation(ctx, draft1.Token, userID)
		mu.Lock()
		defer mu.Unlock()
		if err == nil {
			successCount++
		} else if err == ErrActiveRealIncidentExists {
			conflictCount++
		}
	}()

	go func() {
		defer wg.Done()
		_, err := svc.ConfirmActivation(ctx, draft2.Token, userID)
		mu.Lock()
		defer mu.Unlock()
		if err == nil {
			successCount++
		} else if err == ErrActiveRealIncidentExists {
			conflictCount++
		}
	}()

	wg.Wait()

	if successCount != 1 {
		t.Fatalf("expected exactly 1 success, got %d", successCount)
	}
	if conflictCount != 1 {
		t.Fatalf("expected exactly 1 conflict, got %d", conflictCount)
	}
}

func TestIncidentHTTPHandler(t *testing.T) {
	jwtSecret := []byte("test-incident-jwt-secret-key-32b")
	store := NewMemoryStore()
	svc := NewService(store)
	h := NewHandler(svc, jwtSecret, &dummyHierarchyChecker{})

	r := chi.NewRouter()
	h.Routes(r)

	rtID := "rt-003"
	// Generate valid pengurus JWT
	token, _, err := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "pengurus-1",
		Role:     "pengurus",
		RegionID: rtID,
	})
	if err != nil {
		t.Fatalf("failed to generate jwt: %v", err)
	}

	// 1. Direct activation with mode nyata -> should be rejected HTTP 400
	directPayload := map[string]any{
		"hazard":  "banjir",
		"mode":    "nyata",
		"message": "Banjir langsung",
	}
	directBody, _ := json.Marshal(directPayload)
	req := httptest.NewRequest(http.MethodPost, "/rts/"+rtID+"/incidents", bytes.NewReader(directBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for direct real activation, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 2. Draft activation -> HTTP 201
	draftPayload := map[string]any{
		"hazard":  "banjir",
		"mode":    "nyata",
		"message": "Banjir draft",
	}
	draftBody, _ := json.Marshal(draftPayload)
	req = httptest.NewRequest(http.MethodPost, "/rts/"+rtID+"/incidents/draft", bytes.NewReader(draftBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for draft activation, got: %d (%s)", rec.Code, rec.Body.String())
	}

	var draftResp struct {
		Data ActivationDraft `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &draftResp)
	confirmationToken := draftResp.Data.Token
	if confirmationToken == "" {
		t.Fatal("expected confirmation token in draft response")
	}

	// 3. Confirm activation -> HTTP 201
	confirmPayload := map[string]any{
		"confirmation_token": confirmationToken,
	}
	confirmBody, _ := json.Marshal(confirmPayload)
	req = httptest.NewRequest(http.MethodPost, "/rts/"+rtID+"/incidents/confirm", bytes.NewReader(confirmBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for confirm activation, got: %d (%s)", rec.Code, rec.Body.String())
	}

	var incResp struct {
		Data Incident `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &incResp)
	incidentID := incResp.Data.ID

	// 4. Get Incident Summary -> HTTP 200
	req = httptest.NewRequest(http.MethodGet, "/incidents/"+incidentID+"/summary", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for summary, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 5. End Incident -> HTTP 200
	req = httptest.NewRequest(http.MethodPost, "/incidents/"+incidentID+"/end", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for end incident, got: %d (%s)", rec.Code, rec.Body.String())
	}
}

func TestDrillComparisonAndModeSeparation(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	svc := NewService(store)

	rtID := "rt-001"
	userID := "user-pengurus-1"

	// 1. Empty state
	emptyComp, err := svc.GetDrillsComparison(ctx, rtID)
	if err != nil {
		t.Fatalf("unexpected error on empty comparison: %v", err)
	}
	if emptyComp.TotalDrills != 0 || emptyComp.Trend != "empty" || len(emptyComp.Drills) != 0 {
		t.Fatalf("expected empty drill comparison, got: %+v", emptyComp)
	}

	// 2. Drill 1
	d1, err := svc.ActivateDirect(ctx, DirectActivationRequest{
		RTID:      rtID,
		Hazard:    HazardGempa,
		Mode:      ModeLatihan,
		Message:   "Simulasi gempa 1",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("failed to create drill 1: %v", err)
	}
	d1.StartedAt = time.Now().Add(-2 * time.Hour)
	d1.Metrics.VulnReached30 = 60.0
	d1.Metrics.OfflineDelivery = 40.0
	_ = store.UpdateIncident(ctx, d1)
	_, _ = svc.EndIncident(ctx, d1.ID)

	// 3. Real Incident (must NOT contaminate drill comparison)
	draft, err := svc.DraftActivation(ctx, DraftRequest{
		RTID:      rtID,
		Hazard:    HazardBanjir,
		Mode:      ModeNyata,
		Message:   "Banjir nyata",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("failed to draft real incident: %v", err)
	}
	realInc, err := svc.ConfirmActivation(ctx, draft.Token, userID)
	if err != nil {
		t.Fatalf("failed to confirm real incident: %v", err)
	}
	realInc.StartedAt = time.Now().Add(-90 * time.Minute)
	realInc.Metrics.VulnReached30 = 100.0
	realInc.Metrics.OfflineDelivery = 95.0
	_ = store.UpdateIncident(ctx, realInc)
	_, _ = svc.EndIncident(ctx, realInc.ID)

	// 4. Drill 2
	d2, err := svc.ActivateDirect(ctx, DirectActivationRequest{
		RTID:      rtID,
		Hazard:    HazardBanjir,
		Mode:      ModeLatihan,
		Message:   "Simulasi banjir 2",
		StartedBy: userID,
	})
	if err != nil {
		t.Fatalf("failed to create drill 2: %v", err)
	}
	d2.StartedAt = time.Now().Add(-1 * time.Hour)
	d2.Metrics.VulnReached30 = 80.0
	d2.Metrics.OfflineDelivery = 60.0
	_ = store.UpdateIncident(ctx, d2)
	_, _ = svc.EndIncident(ctx, d2.ID)

	// 5. Test mode isolation
	latihanMode := ModeLatihan
	nyataMode := ModeNyata
	drillsList, err := svc.ListIncidents(ctx, rtID, &latihanMode)
	if err != nil || len(drillsList) != 2 {
		t.Fatalf("expected 2 drills, got %d (err: %v)", len(drillsList), err)
	}
	realsList, err := svc.ListIncidents(ctx, rtID, &nyataMode)
	if err != nil || len(realsList) != 1 {
		t.Fatalf("expected 1 real incident, got %d (err: %v)", len(realsList), err)
	}

	// 6. Test GetDrillsComparison
	comp, err := svc.GetDrillsComparison(ctx, rtID)
	if err != nil {
		t.Fatalf("failed to get drills comparison: %v", err)
	}
	if comp.TotalDrills != 2 {
		t.Fatalf("expected 2 drills, got %d", comp.TotalDrills)
	}
	if comp.AverageVulnReached30 != 70.0 {
		t.Fatalf("expected avg vuln 70.0, got %f", comp.AverageVulnReached30)
	}
	if comp.AverageOfflineDelivery != 50.0 {
		t.Fatalf("expected avg offline 50.0, got %f", comp.AverageOfflineDelivery)
	}
	if comp.Trend != "improving" {
		t.Fatalf("expected trend improving, got %s", comp.Trend)
	}

	// 7. Test HTTP endpoints
	jwtSecret := []byte("secret-key-min-32-chars-long-for-test-ok")
	token, _, err := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "user-pengurus-1",
		Role:     "pengurus",
		RegionID: rtID,
	})
	if err != nil {
		t.Fatalf("failed to generate access token: %v", err)
	}

	handler := NewHandler(svc, jwtSecret, &dummyHierarchyChecker{})
	r := chi.NewRouter()
	handler.Routes(r)

	// GET /rts/{rt}/drills/comparison
	req := httptest.NewRequest(http.MethodGet, "/rts/"+rtID+"/drills/comparison", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for drill comparison, got %d: %s", rec.Code, rec.Body.String())
	}
	var compResp struct {
		Data DrillComparisonSummary `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &compResp)
	if compResp.Data.TotalDrills != 2 || compResp.Data.Trend != "improving" {
		t.Fatalf("unexpected HTTP comparison response: %+v", compResp.Data)
	}

	// GET /rts/{rt}/incidents?mode=latihan
	req = httptest.NewRequest(http.MethodGet, "/rts/"+rtID+"/incidents?mode=latihan", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for list drills, got %d: %s", rec.Code, rec.Body.String())
	}
	var listResp struct {
		Data []*Incident `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &listResp)
	if len(listResp.Data) != 2 {
		t.Fatalf("expected 2 drills in list, got %d", len(listResp.Data))
	}
}
