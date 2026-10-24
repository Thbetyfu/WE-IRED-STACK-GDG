package task

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/priority"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

type Service struct {
	store          Store
	reportStore    report.Store
	householdStore household.Store
	volunteerStore volunteer.Store
	realtimeHub    *realtime.Hub
}

func NewService(
	store Store,
	reportStore report.Store,
	householdStore household.Store,
	volunteerStore volunteer.Store,
	realtimeHub *realtime.Hub,
) *Service {
	return &Service{
		store:          store,
		reportStore:    reportStore,
		householdStore: householdStore,
		volunteerStore: volunteerStore,
		realtimeHub:    realtimeHub,
	}
}

// ValidateTransition enforces the strict task state machine per FR-TSK-02/03/04.
func ValidateTransition(current, target TaskStatus, req UpdateTaskRequest, actorRole string, isAssignedVol bool) error {
	if current == target {
		return nil
	}

	valid := false
	switch current {
	case StatusDisarankan:
		if target == StatusDitugaskan || target == StatusDibatalkan {
			valid = true
		}
	case StatusDitugaskan:
		if target == StatusDiterima || target == StatusDitolak || target == StatusDibatalkan {
			valid = true
		}
	case StatusDiterima:
		if target == StatusDalamPerjalanan || target == StatusDijangkau || target == StatusDibatalkan {
			valid = true
		}
	case StatusDalamPerjalanan:
		if target == StatusDijangkau || target == StatusDibatalkan {
			valid = true
		}
	case StatusDijangkau:
		if target == StatusSelesai || target == StatusDibatalkan {
			valid = true
		}
	default:
		valid = false
	}

	if !valid {
		return fmt.Errorf("%w: tidak dapat beralih dari '%s' ke '%s'", ErrInvalidTaskTransition, current, target)
	}

	// Validate reject reason
	if target == StatusDitolak {
		if req.RejectReason == nil || *req.RejectReason == "" {
			return ErrRejectReasonRequired
		}
	}

	// Validate outcome on dijangkau / selesai (FR-TSK-04)
	if target == StatusDijangkau || target == StatusSelesai {
		if req.Outcome == nil || *req.Outcome == "" {
			return ErrOutcomeRequired
		}
	}

	// Role-based permissions
	if target == StatusDitugaskan || target == StatusDibatalkan {
		if actorRole != "pengurus" && actorRole != "admin_wilayah" && actorRole != "operator" {
			return errorsNew("hanya pengurus atau admin yang dapat menugaskan atau membatalkan tugas")
		}
	} else {
		// Volunteer actions (terima, tolak, dalam perjalanan, dijangkau, selesai)
		if !isAssignedVol && actorRole != "pengurus" && actorRole != "admin_wilayah" && actorRole != "operator" {
			return ErrVolunteerNotAssigned
		}
	}

	return nil
}

func errorsNew(msg string) error {
	return fmt.Errorf("%w: %s", ErrInvalidTaskTransition, msg)
}

func (s *Service) CreateTask(ctx context.Context, incidentID string, req CreateTaskRequest, creatorID string) (*Task, error) {
	if req.HouseholdID == "" {
		return nil, fmt.Errorf("household_id wajib diisi")
	}

	// Check if household already has an active task in this incident
	existingActive, err := s.store.GetActiveTaskForHousehold(ctx, incidentID, req.HouseholdID)
	if err == nil && existingActive != nil {
		return nil, fmt.Errorf("rumah tangga sudah memiliki tugas aktif (status: %s)", existingActive.Status)
	}

	status := StatusDisarankan
	if req.Status != nil {
		status = *req.Status
	}

	now := time.Now().UTC()
	var assignedAt *time.Time
	if status == StatusDitugaskan {
		if req.VolunteerID == nil || *req.VolunteerID == "" {
			return nil, fmt.Errorf("volunteer_id wajib diisi untuk tugas berstatus 'ditugaskan'")
		}
		// Check volunteer load
		load, err := s.store.GetActiveVolunteerTaskCount(ctx, incidentID, *req.VolunteerID)
		if err == nil && load >= 2 {
			return nil, ErrVolunteerOverCapacity
		}
		assignedAt = &now
	}

	t := &Task{
		ID:          uuid.NewString(),
		IncidentID:  incidentID,
		HouseholdID: req.HouseholdID,
		VolunteerID: req.VolunteerID,
		Status:      status,
		Notes:       req.Notes,
		CreatedBy:   creatorID,
		AssignedAt:  assignedAt,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if err := s.store.CreateTask(ctx, t); err != nil {
		return nil, err
	}

	s.broadcastTaskEvent(ctx, t)
	return t, nil
}

func (s *Service) UpdateTask(ctx context.Context, taskID string, req UpdateTaskRequest, actorID, actorRole string) (*Task, error) {
	t, err := s.store.GetTask(ctx, taskID)
	if err != nil {
		return nil, err
	}

	isAssignedVol := t.VolunteerID != nil && *t.VolunteerID == actorID

	if err := ValidateTransition(t.Status, req.Status, req, actorRole, isAssignedVol); err != nil {
		return nil, err
	}

	now := time.Now().UTC()

	// Apply transition mutations
	t.Status = req.Status
	if req.Notes != nil {
		t.Notes = req.Notes
	}

	switch req.Status {
	case StatusDitugaskan:
		if req.VolunteerID != nil && *req.VolunteerID != "" {
			t.VolunteerID = req.VolunteerID
		}
		if t.VolunteerID == nil || *t.VolunteerID == "" {
			return nil, fmt.Errorf("volunteer_id wajib diisi untuk penugasan")
		}
		// Verify capacity
		load, _ := s.store.GetActiveVolunteerTaskCount(ctx, t.IncidentID, *t.VolunteerID)
		if load >= 2 {
			return nil, ErrVolunteerOverCapacity
		}
		t.AssignedAt = &now

	case StatusDiterima:
		t.AcceptedAt = &now

	case StatusDijangkau:
		t.ReachedAt = &now
		t.Outcome = req.Outcome

	case StatusSelesai:
		t.CompletedAt = &now
		if req.Outcome != nil {
			t.Outcome = req.Outcome
		}

	case StatusDitolak:
		t.RejectReason = req.RejectReason
	}

	if err := s.store.UpdateTask(ctx, t); err != nil {
		return nil, err
	}

	s.broadcastTaskEvent(ctx, t)
	return t, nil
}

func (s *Service) GetTask(ctx context.Context, id string) (*Task, error) {
	t, err := s.store.GetTask(ctx, id)
	if err != nil {
		return nil, err
	}
	s.evaluateOverdue(t, time.Now().UTC())
	return t, nil
}

func (s *Service) ListTasks(ctx context.Context, incidentID string, status *TaskStatus, volunteerID *string) ([]*Task, error) {
	tasks, err := s.store.ListTasksByIncident(ctx, incidentID, status, volunteerID)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	for _, t := range tasks {
		s.evaluateOverdue(t, now)
	}
	return tasks, nil
}

// GeneratePlan produces suggested assignments using SDD 6.3 greedy algorithm.
func (s *Service) GeneratePlan(ctx context.Context, incidentID, rtID string) ([]*priority.SuggestedAssignment, error) {
	// 1. Fetch households in RT
	households, err := s.householdStore.ListHouseholdsByRT(ctx, rtID, nil)
	if err != nil {
		return nil, err
	}

	// 2. Fetch states in incident
	states, _ := s.reportStore.ListHouseholdStates(ctx, incidentID)
	stateMap := make(map[string]*report.HouseholdState)
	for _, st := range states {
		stateMap[st.HouseholdID] = st
	}

	// 3. Build priority queue
	var queue []*priority.QueueItem
	now := time.Now().UTC()

	for _, hh := range households {
		// Check if already has an active task
		activeTask, _ := s.store.GetActiveTaskForHousehold(ctx, incidentID, hh.ID)
		if activeTask != nil {
			continue
		}

		st := stateMap[hh.ID]
		score := 22.0 // default for unreported
		if st != nil {
			score = st.PriorityScore
		}
		if score <= 0 {
			continue
		}

		blockID := ""
		if hh.BlockID != nil {
			blockID = *hh.BlockID
		}

		vulnCount := 0
		for _, m := range hh.Members {
			if m.VulnFlags > 0 || m.NeedsEvacAssist {
				vulnCount++
			}
		}

		waitMins := 0.0
		if st != nil {
			waitMins = now.Sub(st.UpdatedAt).Minutes()
		}

		queue = append(queue, &priority.QueueItem{
			HouseholdID:     hh.ID,
			BlockID:         blockID,
			PriorityScore:   score,
			VulnerableCount: vulnCount,
			WaitMinutes:     waitMins,
			Lat:             hh.Lat,
			Lon:             hh.Lon,
		})
	}

	// 4. Fetch volunteers in RT
	volList, err := s.volunteerStore.ListVolunteersByRT(ctx, rtID)
	if err != nil {
		return nil, err
	}

	var candidates []*priority.VolunteerCandidate
	for _, v := range volList {
		load, _ := s.store.GetActiveVolunteerTaskCount(ctx, incidentID, v.UserID)
		candidates = append(candidates, &priority.VolunteerCandidate{
			UserID:         v.UserID,
			Name:           v.Name,
			AssignedBlocks: v.AssignedBlocks,
			ActiveLoad:     load,
			IsAvailable:    v.Available,
			LastLat:        v.LastLat,
			LastLon:        v.LastLon,
		})
	}

	// 5. Run SDD 6.3 Greedy Algorithm
	plan := priority.GenerateAssignmentPlan(queue, candidates)
	return plan, nil
}

// ApplyPlan creates tasks with status 'ditugaskan' for all suggestions approved by pengurus.
func (s *Service) ApplyPlan(ctx context.Context, incidentID, creatorID string, plan []*priority.SuggestedAssignment) ([]*Task, error) {
	now := time.Now().UTC()
	var createdTasks []*Task

	for _, item := range plan {
		// Verify volunteer capacity (< 2 active tasks)
		load, _ := s.store.GetActiveVolunteerTaskCount(ctx, incidentID, item.VolunteerID)
		if load >= 2 {
			continue
		}

		volID := item.VolunteerID
		assignedAt := now

		t := &Task{
			ID:          uuid.NewString(),
			IncidentID:  incidentID,
			HouseholdID: item.HouseholdID,
			VolunteerID: &volID,
			Status:      StatusDitugaskan,
			CreatedBy:   creatorID,
			AssignedAt:  &assignedAt,
			CreatedAt:   now,
			UpdatedAt:   now,
		}

		if err := s.store.CreateTask(ctx, t); err == nil {
			createdTasks = append(createdTasks, t)
			s.broadcastTaskEvent(ctx, t)
		}
	}

	return createdTasks, nil
}

// CheckOverdueTasks scans tasks for 5-minute timeout alert (FR-TSK-05).
func (s *Service) CheckOverdueTasks(ctx context.Context, incidentID string, now time.Time) ([]*Task, error) {
	if now.IsZero() {
		now = time.Now().UTC()
	}
	threshold := now.Add(-5 * time.Minute)

	overdueTasks, err := s.store.GetOverdueTasks(ctx, incidentID, threshold)
	if err != nil {
		return nil, err
	}

	for _, t := range overdueTasks {
		t.IsOverdue = true
		if s.realtimeHub != nil {
			_ = s.realtimeHub.BroadcastEvent(ctx, t.IncidentID, &realtime.Event{
				Entity:   "task",
				EntityID: t.ID,
				Op:       "ALERT_OVERDUE",
				Payload: map[string]any{
					"task_id":            t.ID,
					"volunteer_id":       t.VolunteerID,
					"household_id":       t.HouseholdID,
					"status":             t.Status,
					"is_overdue":         true,
					"needs_reassignment": true,
				},
				Origin: "cloud",
			})
		}
	}

	return overdueTasks, nil
}

func (s *Service) evaluateOverdue(t *Task, now time.Time) {
	if t.Status == StatusDitugaskan && t.AssignedAt != nil {
		if now.Sub(*t.AssignedAt) >= 5*time.Minute {
			t.IsOverdue = true
		}
	}
}

func (s *Service) broadcastTaskEvent(ctx context.Context, t *Task) {
	if s.realtimeHub == nil {
		return
	}
	_ = s.realtimeHub.BroadcastEvent(ctx, t.IncidentID, &realtime.Event{
		Entity:   "task",
		EntityID: t.ID,
		Op:       "UPDATE",
		Payload: map[string]any{
			"task_id":      t.ID,
			"incident_id":  t.IncidentID,
			"household_id": t.HouseholdID,
			"volunteer_id": t.VolunteerID,
			"status":       t.Status,
			"outcome":      t.Outcome,
			"is_overdue":   t.IsOverdue,
		},
		Origin: "cloud",
	})
}
