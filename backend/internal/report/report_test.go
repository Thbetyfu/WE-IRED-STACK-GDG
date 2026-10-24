package report

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
)

type dummyHouseholdProvider struct {
	households []*HouseholdInfo
}

func (d *dummyHouseholdProvider) GetHouseholdsInScope(ctx context.Context, rtID string, blockIDs []string) ([]*HouseholdInfo, error) {
	return d.households, nil
}

func (d *dummyHouseholdProvider) GetHouseholdInfo(ctx context.Context, id string) (*HouseholdInfo, error) {
	for _, h := range d.households {
		if h.ID == id {
			return h, nil
		}
	}
	return nil, nil
}

type dummyIncidentProvider struct {
	rtID string
}

func (d *dummyIncidentProvider) GetIncidentRTID(ctx context.Context, incidentID string) (string, error) {
	return d.rtID, nil
}

type dummyRegionChecker struct{}

func (d *dummyRegionChecker) IsRTInRegion(ctx context.Context, regionID, rtID string) (bool, error) {
	return true, nil
}

func TestIdempotencyAndSequenceOrdering(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	svc := NewService(store)

	incidentID := "inc-100"
	householdID := "hh-100"

	// 1. Submit report seq 1 (Aman)
	r1 := &Report{
		ID:          "rep-001",
		IncidentID:  incidentID,
		HouseholdID: householdID,
		Seq:         1,
		Status:      StatusAman,
		Channel:     ChannelAplikasi,
		ReceivedAt:  time.Now().UTC(),
	}
	res1, err := svc.SubmitReport(ctx, r1)
	if err != nil {
		t.Fatalf("submit r1 failed: %v", err)
	}
	if res1.AlreadyExists {
		t.Fatal("expected r1 to not exist yet")
	}
	if res1.State.Status != StatusAman || res1.State.Seq != 1 {
		t.Fatalf("unexpected state after r1: %+v", res1.State)
	}

	// 2. Resend exactly the same report (same ID) -> should be idempotent
	res1Dup, err := svc.SubmitReport(ctx, r1)
	if err != nil {
		t.Fatalf("submit r1 duplicate failed: %v", err)
	}
	if !res1Dup.AlreadyExists {
		t.Fatal("expected r1 duplicate to be detected as already exists")
	}

	// 3. Resend different ID but duplicate (incident, household, seq=1) -> should be idempotent
	r1SeqDup := &Report{
		ID:          "rep-001-alt",
		IncidentID:  incidentID,
		HouseholdID: householdID,
		Seq:         1,
		Status:      StatusTitikKumpul,
		Channel:     ChannelAplikasi,
		ReceivedAt:  time.Now().UTC(),
	}
	res1SeqDup, err := svc.SubmitReport(ctx, r1SeqDup)
	if err != nil {
		t.Fatalf("submit r1SeqDup failed: %v", err)
	}
	if !res1SeqDup.AlreadyExists {
		t.Fatal("expected duplicate seq to be detected as already exists")
	}

	// 4. Submit newer seq 2 (Titik Kumpul) -> updates state
	r2 := &Report{
		ID:          "rep-002",
		IncidentID:  incidentID,
		HouseholdID: householdID,
		Seq:         2,
		Status:      StatusTitikKumpul,
		Channel:     ChannelAplikasi,
		ReceivedAt:  time.Now().UTC(),
	}
	res2, err := svc.SubmitReport(ctx, r2)
	if err != nil {
		t.Fatalf("submit r2 failed: %v", err)
	}
	if res2.State.Status != StatusTitikKumpul || res2.State.Seq != 2 {
		t.Fatalf("expected state status titik kumpul seq 2, got: %+v", res2.State)
	}

	// 5. Older report arriving late (seq 1 alternative with new ID) -> must NOT downgrade state
	rOlder := &Report{
		ID:          "rep-older-001",
		IncidentID:  incidentID,
		HouseholdID: householdID,
		Seq:         1,
		Status:      StatusAman,
		Channel:     ChannelMesh,
		ReceivedAt:  time.Now().UTC(),
	}
	resOlder, err := svc.SubmitReport(ctx, rOlder)
	if err != nil {
		t.Fatalf("submit rOlder failed: %v", err)
	}
	if resOlder.ActionTaken != "already_exists" && resOlder.State.Status != StatusTitikKumpul {
		t.Fatalf("expected state to remain titik kumpul, got: %+v", resOlder.State)
	}
}

func TestCriticalStateProtectionAgainstBeaconCheckin(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	svc := NewService(store)

	incidentID := "inc-200"
	householdID := "hh-200"

	// 1. Citizen reports butuh_bantuan KRITIS (seq 1)
	r1 := &Report{
		ID:          "rep-crit-001",
		IncidentID:  incidentID,
		HouseholdID: householdID,
		Seq:         1,
		Status:      StatusButuhBantuan,
		Urgency:     UrgencyKritis,
		Needs:       NeedEvakuasi | NeedMedis,
		Channel:     ChannelAplikasi,
		ReceivedAt:  time.Now().UTC(),
	}
	res1, err := svc.SubmitReport(ctx, r1)
	if err != nil {
		t.Fatalf("submit critical report failed: %v", err)
	}
	if res1.State.Status != StatusButuhBantuan || res1.State.Urgency != UrgencyKritis {
		t.Fatalf("expected critical state, got: %+v", res1.State)
	}

	// 2. An automated beacon check-in arrives with seq 2 (status titik kumpul / aman)
	// SDD 6.2: Must NOT overwrite critical status!
	rBeacon := &Report{
		ID:             "rep-beacon-002",
		IncidentID:     incidentID,
		HouseholdID:    householdID,
		Seq:            2,
		Status:         StatusTitikKumpul,
		Urgency:        UrgencyNone,
		Channel:        ChannelBeaconCheckin,
		ReporterUserID: nil, // unconfirmed / automatic
		ReceivedAt:     time.Now().UTC(),
	}
	resBeacon, err := svc.SubmitReport(ctx, rBeacon)
	if err != nil {
		t.Fatalf("submit beacon checkin failed: %v", err)
	}

	if resBeacon.ActionTaken != "needs_confirmation" {
		t.Fatalf("expected action needs_confirmation, got %s", resBeacon.ActionTaken)
	}
	// Status MUST still be butuh_bantuan and urgency kritis!
	if resBeacon.State.Status != StatusButuhBantuan || resBeacon.State.Urgency != UrgencyKritis {
		t.Fatalf("CRITICAL STATE WAS OVERWRITTEN! Status: %d, Urgency: %d", resBeacon.State.Status, resBeacon.State.Urgency)
	}
	if !resBeacon.State.NeedsConfirmation {
		t.Fatal("expected needs_confirmation = true")
	}

	// 3. Volunteer confirms household is evacuated (channel = relawan)
	volUserID := "user-vol-1"
	rVol := &Report{
		ID:             "rep-vol-003",
		IncidentID:     incidentID,
		HouseholdID:    householdID,
		Seq:            0, // auto sequence
		Status:         StatusTitikKumpul,
		Urgency:        UrgencyNone,
		Channel:        ChannelRelawan,
		ReporterUserID: &volUserID,
		ReceivedAt:     time.Now().UTC(),
	}
	resVol, err := svc.SubmitReport(ctx, rVol)
	if err != nil {
		t.Fatalf("submit volunteer confirmation failed: %v", err)
	}
	if resVol.State.Status != StatusTitikKumpul {
		t.Fatalf("expected status titik kumpul after volunteer confirmation, got: %d", resVol.State.Status)
	}
	if resVol.State.NeedsConfirmation {
		t.Fatal("expected needs_confirmation to be cleared after volunteer confirmation")
	}
	if resVol.Report.Seq != 3 {
		t.Fatalf("expected server assigned seq = 3, got: %d", resVol.Report.Seq)
	}
}

func TestPriorityScoreCalculationSDD61(t *testing.T) {
	// SDD 6.1:
	// Butuh bantuan kritis = 40
	// 2 anggota rentan = 8 * 2 = 16
	// Evakuasi (6) + Medis (6) = 12 -> cap at 10
	// Total tanpa jarak / wait = min(100, 40 + 16 + 0 + 10 + 0) = 66
	st := &HouseholdState{
		Status:  StatusButuhBantuan,
		Urgency: UrgencyKritis,
		Needs:   NeedEvakuasi | NeedMedis,
	}

	score, breakdown := CalculatePriorityScore(st, 2, time.Time{}, nil, nil)
	if score != 66.0 {
		t.Fatalf("expected score 66.0, got: %f (breakdown: %+v)", score, breakdown)
	}
	if breakdown["U"] != 40.0 {
		t.Fatalf("expected U=40, got: %f", breakdown["U"])
	}
	if breakdown["V"] != 16.0 {
		t.Fatalf("expected V=16, got: %f", breakdown["V"])
	}
	if breakdown["N"] != 10.0 {
		t.Fatalf("expected N=10 (capped), got: %f", breakdown["N"])
	}
}

func TestStateReconstructionFromRawReports(t *testing.T) {
	incidentID := "inc-300"
	householdID := "hh-300"

	t0 := time.Now().UTC().Add(-10 * time.Minute)
	t1 := time.Now().UTC().Add(-5 * time.Minute)
	t2 := time.Now().UTC()

	reports := []*Report{
		{
			ID:          "r-1",
			IncidentID:  incidentID,
			HouseholdID: householdID,
			Seq:         1,
			Status:      StatusAman,
			Channel:     ChannelAplikasi,
			ReceivedAt:  t0,
		},
		{
			ID:          "r-2",
			IncidentID:  incidentID,
			HouseholdID: householdID,
			Seq:         2,
			Status:      StatusButuhBantuan,
			Urgency:     UrgencyBiasa,
			Needs:       NeedMakananAir,
			Channel:     ChannelAplikasi,
			ReceivedAt:  t1,
		},
		{
			ID:          "r-3",
			IncidentID:  incidentID,
			HouseholdID: householdID,
			Seq:         3,
			Status:      StatusTitikKumpul,
			Channel:     ChannelAplikasi,
			ReceivedAt:  t2,
		},
	}

	// Feed reports in shuffled order to test reconstruction
	shuffled := []*Report{reports[2], reports[0], reports[1]}
	reconstructed := ReconstructHouseholdState(incidentID, householdID, shuffled)

	if reconstructed == nil {
		t.Fatal("expected non-nil reconstructed state")
	}
	if reconstructed.Seq != 3 || reconstructed.Status != StatusTitikKumpul {
		t.Fatalf("expected reconstructed state seq=3 status=titik kumpul, got: %+v", reconstructed)
	}
}

func TestIncidentMetricsCalculationSDD65(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	svc := NewService(store)

	rtID := "rt-metrics-1"
	inc := &incident.Incident{
		ID:        "inc-metrics",
		RTID:      rtID,
		Mode:      incident.ModeNyata,
		StartedAt: time.Now().UTC().Add(-20 * time.Minute),
	}

	h1 := &HouseholdInfo{ID: "h-1", RTID: rtID, VulnerableCount: 1}
	h2 := &HouseholdInfo{ID: "h-2", RTID: rtID, VulnerableCount: 0}
	svc.SetHouseholdProvider(&dummyHouseholdProvider{households: []*HouseholdInfo{h1, h2}})

	// Submit report for h1 within 10 minutes (safe)
	r1 := &Report{
		ID:          "rep-m1",
		IncidentID:  inc.ID,
		HouseholdID: h1.ID,
		Seq:         1,
		Status:      StatusAman,
		Channel:     ChannelAplikasi,
		ReceivedAt:  inc.StartedAt.Add(10 * time.Minute),
	}
	_, _ = svc.SubmitReport(ctx, r1)

	// Submit report for h2 within 15 minutes (offline outbox)
	r2 := &Report{
		ID:          "rep-m2",
		IncidentID:  inc.ID,
		HouseholdID: h2.ID,
		Seq:         1,
		Status:      StatusTitikKumpul,
		Channel:     ChannelOutbox,
		ReceivedAt:  inc.StartedAt.Add(15 * time.Minute),
	}
	_, _ = svc.SubmitReport(ctx, r2)

	summary, metrics, err := svc.GetIncidentStats(ctx, inc)
	if err != nil {
		t.Fatalf("GetIncidentStats failed: %v", err)
	}

	if summary.ReportedCount != 2 || summary.TotalHouseholds != 2 {
		t.Fatalf("unexpected summary: %+v", summary)
	}
	if metrics.T100 != "15m" {
		t.Fatalf("expected t100 = 15m, got %s", metrics.T100)
	}
	if metrics.VulnReached30 != 100.0 {
		t.Fatalf("expected vuln_reached_30 = 100%%, got: %f", metrics.VulnReached30)
	}
	if metrics.ByChannel[ChannelOutbox] != 1 || metrics.ByChannel[ChannelAplikasi] != 1 {
		t.Fatalf("unexpected by_channel metrics: %+v", metrics.ByChannel)
	}
}

func TestReportHTTPHandler(t *testing.T) {
	jwtSecret := []byte("test-report-jwt-secret-key-32b")
	store := NewMemoryStore()
	svc := NewService(store)
	rtID := "rt-handler-1"
	svc.SetHouseholdProvider(&dummyHouseholdProvider{
		households: []*HouseholdInfo{
			{ID: "hh-h1", RTID: rtID, HeadName: "Budi", VulnerableCount: 1},
		},
	})
	h := NewHandler(svc, jwtSecret, &dummyRegionChecker{}, &dummyIncidentProvider{rtID: rtID})

	r := chi.NewRouter()
	h.Routes(r)

	token, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:      "user-warga-1",
		Role:        "warga",
		HouseholdID: "hh-h1",
	})

	// 1. Submit single report
	reportPayload := map[string]any{
		"household_id": "hh-h1",
		"seq":          1,
		"status":       1,
		"channel":      "aplikasi",
	}
	body, _ := json.Marshal(reportPayload)
	req := httptest.NewRequest(http.MethodPost, "/incidents/inc-http-1/reports", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for report submit, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 2. Outbox Batch sync
	batchPayload := []map[string]any{
		{
			"id":           "rep-batch-1",
			"incident_id":  "inc-http-1",
			"household_id": "hh-h1",
			"seq":          2,
			"status":       2,
			"channel":      "outbox",
		},
	}
	batchBody, _ := json.Marshal(batchPayload)
	req = httptest.NewRequest(http.MethodPost, "/sync/reports", bytes.NewReader(batchBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for batch sync, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 3. Triage table
	req = httptest.NewRequest(http.MethodGet, "/incidents/inc-http-1/households", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for triage table, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 4. Report history for household
	req = httptest.NewRequest(http.MethodGet, "/households/hh-h1/reports?incident_id=inc-http-1", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for household reports history, got: %d (%s)", rec.Code, rec.Body.String())
	}
}
