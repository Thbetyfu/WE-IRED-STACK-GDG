package priority

import (
	"context"
	"math"
	"testing"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

// TestSDD61Example1 tests the first explicit calculation example in SDD Section 6.1:
// "rumah belum melapor 40 menit, 2 lansia, 300 m dari titik kumpul:
// U = 22, V = 16, W = 10, N = 0, D = 3,6 -> Skor 51,6."
func TestSDD61Example1(t *testing.T) {
	evalTime := time.Date(2026, 10, 24, 10, 40, 0, 0, time.UTC)
	incidentStartTime := evalTime.Add(-40 * time.Minute)

	dist := 300.0
	hh := &HouseholdInput{
		ID:                 "hh-ex1",
		VulnerableCount:    2, // 2 lansia
		DistanceToAPMeters: &dist,
	}
	// State is nil (belum melapor)
	score, b := Calculate(hh, nil, incidentStartTime, evalTime)

	if b.U != 22.0 {
		t.Fatalf("expected U = 22.0, got: %f", b.U)
	}
	if b.V != 16.0 {
		t.Fatalf("expected V = 16.0 (8 * 2), got: %f", b.V)
	}
	if b.W != 10.0 {
		t.Fatalf("expected W = 10.0 (0.25 * 40m), got: %f", b.W)
	}
	if b.N != 0.0 {
		t.Fatalf("expected N = 0.0, got: %f", b.N)
	}
	if math.Abs(b.D-3.6) > 0.001 {
		t.Fatalf("expected D = 3.6 (6 * 300/500), got: %f", b.D)
	}
	if math.Abs(score-51.6) > 0.001 {
		t.Fatalf("expected Total Skor = 51.6, got: %f", score)
	}
}

// TestSDD61Example2 tests the second explicit calculation example in SDD Section 6.1:
// "Rumah butuh bantuan kritis (medis + evakuasi), 1 balita, laporan 10 menit lalu, 100 m:
// U = 40, V = 8, W = 2,5, N = 10 (dibatasi), D = 1,2 -> Skor 61,7."
func TestSDD61Example2(t *testing.T) {
	evalTime := time.Date(2026, 10, 24, 11, 0, 0, 0, time.UTC)
	lastReportTime := evalTime.Add(-10 * time.Minute)
	incidentStartTime := evalTime.Add(-30 * time.Minute)

	dist := 100.0
	hh := &HouseholdInput{
		ID:                 "hh-ex2",
		VulnerableCount:    1, // 1 balita
		DistanceToAPMeters: &dist,
	}

	st := &StateInput{
		Status:          report.StatusButuhBantuan,
		Urgency:         report.UrgencyKritis,
		Needs:           report.NeedMedis | report.NeedEvakuasi, // 6 + 6 = 12 -> cap at 10
		UnconfirmedVuln: 1,
		LastReportTime:  lastReportTime,
	}

	score, b := Calculate(hh, st, incidentStartTime, evalTime)

	if b.U != 40.0 {
		t.Fatalf("expected U = 40.0 (butuh bantuan kritis), got: %f", b.U)
	}
	if b.V != 8.0 {
		t.Fatalf("expected V = 8.0 (8 * 1), got: %f", b.V)
	}
	if b.W != 2.5 {
		t.Fatalf("expected W = 2.5 (0.25 * 10m), got: %f", b.W)
	}
	if b.N != 10.0 {
		t.Fatalf("expected N = 10.0 (capped at 10), got: %f", b.N)
	}
	if math.Abs(b.D-1.2) > 0.001 {
		t.Fatalf("expected D = 1.2 (6 * 100/500), got: %f", b.D)
	}
	if math.Abs(score-61.7) > 0.001 {
		t.Fatalf("expected Total Skor = 61.7, got: %f", score)
	}
}

func TestScoreBreakdownAndCaps(t *testing.T) {
	evalTime := time.Now().UTC()
	incidentStart := evalTime.Add(-120 * time.Minute) // 120 min -> 0.25 * 120 = 30 -> capped at 20

	dist := 1000.0 // > 500m -> 6.0 * 1.0 = 6.0 capped
	hh := &HouseholdInput{
		ID:                 "hh-cap",
		VulnerableCount:    5, // 8 * 5 = 40 -> capped at 24
		DistanceToAPMeters: &dist,
	}

	st := &StateInput{
		Status:          report.StatusButuhBantuan,
		Urgency:         report.UrgencyKritis, // 40
		Needs:           report.NeedEvakuasi | report.NeedMedis | report.NeedMakananAir | report.NeedTempatTinggal | report.NeedLainnya, // 17 -> cap 10
		UnconfirmedVuln: 5,
		LastReportTime:  evalTime.Add(-120 * time.Minute),
	}

	score, b := Calculate(hh, st, incidentStart, evalTime)

	if b.U != 40.0 {
		t.Fatalf("expected U=40, got %f", b.U)
	}
	if b.V != 24.0 {
		t.Fatalf("expected V capped at 24.0, got %f", b.V)
	}
	if b.W != 20.0 {
		t.Fatalf("expected W capped at 20.0, got %f", b.W)
	}
	if b.N != 10.0 {
		t.Fatalf("expected N capped at 10.0, got %f", b.N)
	}
	if b.D != 6.0 {
		t.Fatalf("expected D capped at 6.0, got %f", b.D)
	}
	// 40 + 24 + 20 + 10 + 6 = 100.0
	if score != 100.0 || b.Total != 100.0 {
		t.Fatalf("expected max score 100.0, got: %f", score)
	}
}

func TestStatusVariantsAndQueueExit(t *testing.T) {
	evalTime := time.Now().UTC()
	incStart := evalTime.Add(-10 * time.Minute)

	// 1. Aman di rumah tanpa kebutuhan -> U = 0, keluar dari antrean
	hh1 := &HouseholdInput{ID: "h-aman-no-needs"}
	st1 := &StateInput{Status: report.StatusAman, Needs: 0}
	score1, b1 := Calculate(hh1, st1, incStart, evalTime)
	if b1.U != 0.0 || score1 != 0.0 {
		t.Fatalf("expected 0 for safe without needs, got: %f", score1)
	}

	// 2. Aman di rumah dengan kebutuhan -> U = 10
	st2 := &StateInput{Status: report.StatusAman, Needs: report.NeedMakananAir}
	_, b2 := Calculate(hh1, st2, incStart, evalTime)
	if b2.U != 10.0 {
		t.Fatalf("expected U = 10 for safe with needs, got: %f", b2.U)
	}

	// 3. Di titik kumpul dengan anggota rentan belum terkonfirmasi -> U = 8
	st3 := &StateInput{Status: report.StatusTitikKumpul, UnconfirmedVuln: 1}
	_, b3 := Calculate(hh1, st3, incStart, evalTime)
	if b3.U != 8.0 {
		t.Fatalf("expected U = 8 for assembly point with unconfirmed vuln, got: %f", b3.U)
	}

	// 4. Di titik kumpul lengkap -> U = 0
	st4 := &StateInput{Status: report.StatusTitikKumpul, UnconfirmedVuln: 0}
	_, b4 := Calculate(hh1, st4, incStart, evalTime)
	if b4.U != 0.0 {
		t.Fatalf("expected U = 0 for assembly point complete, got: %f", b4.U)
	}

	// 5. Rumah dengan tugas aktif (HasActiveTask = true) dan bukan butuh bantuan baru -> keluar antrean
	hh5 := &HouseholdInput{ID: "h-active-task", HasActiveTask: true}
	st5 := &StateInput{Status: report.StatusTitikKumpul}
	score5, _ := Calculate(hh5, st5, incStart, evalTime)
	if score5 != 0.0 {
		t.Fatalf("expected score 0 for active task exiting queue, got: %f", score5)
	}
}

func TestGreedyAssignmentPlanSDD63(t *testing.T) {
	// Households in queue
	lat1, lon1 := -6.917, 107.619
	lat2, lon2 := -6.918, 107.620
	lat3, lon3 := -6.919, 107.621

	queue := []*QueueItem{
		{HouseholdID: "hh-1", BlockID: "block-A", PriorityScore: 70.0, Lat: &lat1, Lon: &lon1},
		{HouseholdID: "hh-2", BlockID: "block-A", PriorityScore: 50.0, Lat: &lat2, Lon: &lon2},
		{HouseholdID: "hh-3", BlockID: "block-B", PriorityScore: 40.0, Lat: &lat3, Lon: &lon3},
	}

	v1Lat, v1Lon := -6.9171, 107.6191
	v2Lat, v2Lon := -6.9191, 107.6211
	v3Lat, v3Lon := -6.920, 107.622

	volunteers := []*VolunteerCandidate{
		{
			UserID:         "vol-A1",
			Name:           "Budi (Block A)",
			AssignedBlocks: []string{"block-A"},
			ActiveLoad:     0,
			IsAvailable:    true,
			LastLat:        &v1Lat,
			LastLon:        &v1Lon,
		},
		{
			UserID:         "vol-B1",
			Name:           "Agus (Block B)",
			AssignedBlocks: []string{"block-B"},
			ActiveLoad:     0,
			IsAvailable:    true,
			LastLat:        &v2Lat,
			LastLon:        &v2Lon,
		},
		{
			UserID:         "vol-Busy",
			Name:           "Busy Volunteer",
			AssignedBlocks: []string{"block-A"},
			ActiveLoad:     2, // max active load, cannot be assigned!
			IsAvailable:    true,
			LastLat:        &v3Lat,
			LastLon:        &v3Lon,
		},
		{
			UserID:         "vol-Offline",
			Name:           "Unavailable Volunteer",
			AssignedBlocks: []string{"block-A"},
			ActiveLoad:     0,
			IsAvailable:    false, // unavailable!
		},
	}

	plan := GenerateAssignmentPlan(queue, volunteers)

	if len(plan) != 3 {
		t.Fatalf("expected 3 assignments, got: %d", len(plan))
	}

	// hh-1 (Score 70, block-A) -> should pick vol-A1 (same block, load 0)
	if plan[0].HouseholdID != "hh-1" || plan[0].VolunteerID != "vol-A1" {
		t.Fatalf("unexpected plan 0: %+v", plan[0])
	}
	if !plan[0].SameBlock {
		t.Fatal("expected plan 0 to be same block")
	}

	// hh-2 (Score 50, block-A) -> vol-A1 now has load 1, but still same block and < 2
	if plan[1].HouseholdID != "hh-2" || plan[1].VolunteerID != "vol-A1" {
		t.Fatalf("unexpected plan 1: %+v", plan[1])
	}

	// hh-3 (Score 40, block-B) -> vol-B1 (block-B, load 0)
	if plan[2].HouseholdID != "hh-3" || plan[2].VolunteerID != "vol-B1" {
		t.Fatalf("unexpected plan 2: %+v", plan[2])
	}

	// vol-Busy (load 2) and vol-Offline (unavailable) must NOT be assigned to anyone
	for _, p := range plan {
		if p.VolunteerID == "vol-Busy" || p.VolunteerID == "vol-Offline" {
			t.Fatalf("assigned invalid volunteer: %+v", p)
		}
	}
}

type mockTaskChecker struct {
	activeHouseholds map[string]bool
}

func (m *mockTaskChecker) HasActiveTask(ctx context.Context, incidentID, householdID string) (bool, error) {
	return m.activeHouseholds[householdID], nil
}

func TestRecalculator(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	hhStore := household.NewMemoryStore()
	repStore := report.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	hub := realtime.NewHub(realtime.NewMemoryEventStore())

	checker := &mockTaskChecker{
		activeHouseholds: map[string]bool{"hh-active": true},
	}

	recalc := NewRecalculator(hhStore, repStore, incStore, checker, hub)

	rtID := "rt-001"
	incID := "inc-001"
	startTime := time.Now().Add(-30 * time.Minute)

	_ = incStore.CreateIncident(ctx, &incident.Incident{
		ID:        incID,
		RTID:      rtID,
		Mode:      incident.ModeNyata,
		Status:    incident.StatusAktif,
		StartedAt: startTime,
	})

	// Household 1: without active task, 1 vulnerable
	_ = hhStore.CreateHousehold(ctx, &household.Household{
		ID:     "hh-1",
		RTID:   rtID,
		Number: "A1",
	})
	_ = hhStore.AddMember(ctx, &household.Member{
		ID:          "m1",
		HouseholdID: "hh-1",
		VulnFlags:   1, // elderly
	})

	// Household 2: with active task
	_ = hhStore.CreateHousehold(ctx, &household.Household{
		ID:     "hh-active",
		RTID:   rtID,
		Number: "A2",
	})

	evalTime := time.Now()
	changes, err := recalc.RecalculateIncident(ctx, incID, rtID, evalTime)
	if err != nil {
		t.Fatalf("unexpected recalculation error: %v", err)
	}

	if len(changes) != 2 {
		t.Fatalf("expected 2 changes, got: %d", len(changes))
	}

	// Active household should have U=0, Total=0
	stActive, _ := repStore.GetHouseholdState(ctx, incID, "hh-active")
	if stActive.PriorityScore != 0 {
		t.Fatalf("expected active household to have priority score 0, got %f", stActive.PriorityScore)
	}

	// hh-1: unreported (U=22), 1 elderly (V=8), 30m wait (W=30/4=7.5) -> Total = 37.5
	st1, _ := repStore.GetHouseholdState(ctx, incID, "hh-1")
	if st1.PriorityScore < 37.0 || st1.PriorityScore > 38.0 {
		t.Fatalf("expected score ~37.5, got %f", st1.PriorityScore)
	}

	// Second recalculation without changes should yield 0 changes
	changes2, err := recalc.RecalculateIncident(ctx, incID, rtID, evalTime)
	if err != nil {
		t.Fatalf("recalculate error: %v", err)
	}
	if len(changes2) != 0 {
		t.Fatalf("expected 0 changes on no-op recalc, got: %d", len(changes2))
	}

	// Start periodic runner and stop cleanly
	runnerCtx, runnerCancel := context.WithCancel(context.Background())
	recalc.StartPeriodicRunner(runnerCtx, 20*time.Millisecond)
	time.Sleep(50 * time.Millisecond)
	runnerCancel()
}
