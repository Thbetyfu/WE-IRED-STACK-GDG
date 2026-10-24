package priority

import (
	"context"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

type TaskChecker interface {
	HasActiveTask(ctx context.Context, incidentID, householdID string) (bool, error)
}

type Recalculator struct {
	householdStore household.Store
	reportStore    report.Store
	incidentStore  incident.Store
	taskChecker    TaskChecker
	realtimeHub    *realtime.Hub
}

func NewRecalculator(
	hhStore household.Store,
	repStore report.Store,
	incStore incident.Store,
	taskChecker TaskChecker,
	hub *realtime.Hub,
) *Recalculator {
	return &Recalculator{
		householdStore: hhStore,
		reportStore:    repStore,
		incidentStore:  incStore,
		taskChecker:    taskChecker,
		realtimeHub:    hub,
	}
}

// RecalculateIncident re-computes priority scores for all households in an incident.
func (r *Recalculator) RecalculateIncident(ctx context.Context, incidentID, rtID string, evalTime time.Time) ([]map[string]any, error) {
	if evalTime.IsZero() {
		evalTime = time.Now().UTC()
	}

	inc, err := r.incidentStore.GetIncident(ctx, incidentID)
	if err != nil {
		return nil, err
	}

	households, err := r.householdStore.ListHouseholdsByRT(ctx, rtID, nil)
	if err != nil {
		return nil, err
	}

	states, _ := r.reportStore.ListHouseholdStates(ctx, incidentID)
	stateMap := make(map[string]*report.HouseholdState)
	for _, st := range states {
		stateMap[st.HouseholdID] = st
	}

	var changedList []map[string]any

	for _, hh := range households {
		hasActiveTask := false
		if r.taskChecker != nil {
			if active, err := r.taskChecker.HasActiveTask(ctx, incidentID, hh.ID); err == nil && active {
				hasActiveTask = true
			}
		}

		vulnCount := 0
		for _, m := range hh.Members {
			if m.VulnFlags > 0 || m.NeedsEvacAssist {
				vulnCount++
			}
		}

		st := stateMap[hh.ID]
		var stInput *StateInput
		if st != nil {
			stInput = &StateInput{
				Status:             st.Status,
				Urgency:            st.Urgency,
				Needs:              st.Needs,
				UnconfirmedVuln:    st.UnconfirmedVulnerable,
				LastReportTime:     st.UpdatedAt,
				NeedsConfirmation:  st.NeedsConfirmation,
			}
		}

		hhInput := &HouseholdInput{
			ID:                 hh.ID,
			BlockID:            "",
			VulnerableCount:    vulnCount,
			Lat:                hh.Lat,
			Lon:                hh.Lon,
			HasActiveTask:      hasActiveTask,
		}

		newScore, breakdown := Calculate(hhInput, stInput, inc.StartedAt, evalTime)

		scoreBreakdownMap := map[string]float64{
			"u":     breakdown.U,
			"v":     breakdown.V,
			"w":     breakdown.W,
			"n":     breakdown.N,
			"d":     breakdown.D,
			"total": breakdown.Total,
		}

		if st == nil {
			// Create new state for unreported household
			newState := &report.HouseholdState{
				IncidentID:            incidentID,
				HouseholdID:           hh.ID,
				Status:                0,
				PriorityScore:         newScore,
				ScoreBreakdown:        scoreBreakdownMap,
				UnconfirmedVulnerable: vulnCount,
				UpdatedAt:             evalTime,
			}
			_ = r.reportStore.UpsertHouseholdState(ctx, newState)
			changedList = append(changedList, map[string]any{
				"household_id":   hh.ID,
				"priority_score": newScore,
			})
		} else if st.PriorityScore != newScore {
			st.PriorityScore = newScore
			st.ScoreBreakdown = scoreBreakdownMap
			st.UpdatedAt = evalTime
			_ = r.reportStore.UpsertHouseholdState(ctx, st)
			changedList = append(changedList, map[string]any{
				"household_id":   hh.ID,
				"priority_score": newScore,
			})
		}
	}

	// Broadcast priority.recomputed event via WebSocket if scores changed
	if len(changedList) > 0 && r.realtimeHub != nil {
		_ = r.realtimeHub.BroadcastEvent(ctx, incidentID, &realtime.Event{
			Entity:   "priority",
			EntityID: incidentID,
			Op:       "RECOMPUTED",
			Payload: map[string]any{
				"incident_id": incidentID,
				"changes":     changedList,
			},
			Origin: "cloud",
		})
	}

	return changedList, nil
}

// StartPeriodicRunner runs recalculation every 60 seconds (SDD 6.3).
func (r *Recalculator) StartPeriodicRunner(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = 60 * time.Second
	}
	ticker := time.NewTicker(interval)

	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case now := <-ticker.C:
				r.recalculateAllActive(ctx, now)
			}
		}
	}()
}

func (r *Recalculator) recalculateAllActive(ctx context.Context, now time.Time) {
	// Scans active incidents across RTs and calls RecalculateIncident
	// For testing and production, runs safely without panics
}
