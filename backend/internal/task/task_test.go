package task

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
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/priority"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

type dummyTaskIncidentProvider struct {
	rtID string
}

func (d *dummyTaskIncidentProvider) GetIncidentRTID(ctx context.Context, incidentID string) (string, error) {
	return d.rtID, nil
}

func setupTaskTestEnv() (*Service, Store, household.Store, volunteer.Store) {
	taskStore := NewMemoryStore()
	repStore := report.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	volStore := volunteer.NewMemoryStore()
	evStore := realtime.NewMemoryEventStore()
	hub := realtime.NewHub(evStore)

	svc := NewService(taskStore, repStore, hhStore, volStore, hub)
	return svc, taskStore, hhStore, volStore
}

func TestTaskStateMachineTransitions(t *testing.T) {
	svc, _, _, _ := setupTaskTestEnv()
	ctx := context.Background()

	incidentID := "inc-task-1"
	householdID := "hh-task-1"
	pengurusID := "pengurus-1"
	volunteerID := "vol-1"
	otherVolID := "vol-2"

	// 1. Create task (disarankan)
	task, err := svc.CreateTask(ctx, incidentID, CreateTaskRequest{
		HouseholdID: householdID,
	}, pengurusID)
	if err != nil {
		t.Fatalf("CreateTask failed: %v", err)
	}
	if task.Status != StatusDisarankan {
		t.Fatalf("expected status disarankan, got: %s", task.Status)
	}

	// 2. Illegal jump: disarankan -> selesai -> must fail
	outcomeAman := OutcomeAmanDiTempat
	_, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status:  StatusSelesai,
		Outcome: &outcomeAman,
	}, pengurusID, "pengurus")
	if err == nil {
		t.Fatal("expected error on illegal transition disarankan -> selesai")
	}

	// 3. Assign task: disarankan -> ditugaskan
	task, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status:      StatusDitugaskan,
		VolunteerID: &volunteerID,
	}, pengurusID, "pengurus")
	if err != nil {
		t.Fatalf("transition to ditugaskan failed: %v", err)
	}
	if task.Status != StatusDitugaskan || task.AssignedAt == nil {
		t.Fatalf("expected status ditugaskan with assigned_at, got: %+v", task)
	}

	// 4. Other volunteer tries to accept -> must fail (ErrVolunteerNotAssigned)
	_, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status: StatusDiterima,
	}, otherVolID, "relawan")
	if err != ErrVolunteerNotAssigned {
		t.Fatalf("expected ErrVolunteerNotAssigned, got: %v", err)
	}

	// 5. Assigned volunteer accepts: ditugaskan -> diterima
	task, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status: StatusDiterima,
	}, volunteerID, "relawan")
	if err != nil {
		t.Fatalf("transition to diterima failed: %v", err)
	}
	if task.Status != StatusDiterima || task.AcceptedAt == nil {
		t.Fatalf("expected status diterima with accepted_at, got: %+v", task)
	}

	// 6. Transition to dijangkau without outcome -> must fail (ErrOutcomeRequired)
	_, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status: StatusDijangkau,
	}, volunteerID, "relawan")
	if err != ErrOutcomeRequired {
		t.Fatalf("expected ErrOutcomeRequired on dijangkau, got: %v", err)
	}

	// 7. Transition to dijangkau with outcome -> success
	outcomeEvac := OutcomeDievakuasi
	task, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status:  StatusDijangkau,
		Outcome: &outcomeEvac,
	}, volunteerID, "relawan")
	if err != nil {
		t.Fatalf("transition to dijangkau failed: %v", err)
	}
	if task.Status != StatusDijangkau || task.ReachedAt == nil || *task.Outcome != OutcomeDievakuasi {
		t.Fatalf("unexpected state after dijangkau: %+v", task)
	}

	// 8. Transition to selesai -> success
	task, err = svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status:  StatusSelesai,
		Outcome: &outcomeEvac,
	}, volunteerID, "relawan")
	if err != nil {
		t.Fatalf("transition to selesai failed: %v", err)
	}
	if task.Status != StatusSelesai || task.CompletedAt == nil {
		t.Fatalf("expected status selesai with completed_at, got: %+v", task)
	}
}

func TestRejectRequiresReason(t *testing.T) {
	svc, _, _, _ := setupTaskTestEnv()
	ctx := context.Background()

	volunteerID := "vol-reject-1"
	statusAssigned := StatusDitugaskan
	task, _ := svc.CreateTask(ctx, "inc-rej", CreateTaskRequest{
		HouseholdID: "hh-rej-1",
		VolunteerID: &volunteerID,
		Status:      &statusAssigned,
	}, "pengurus-1")

	// Reject without reason -> fails
	_, err := svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status: StatusDitolak,
	}, volunteerID, "relawan")
	if err != ErrRejectReasonRequired {
		t.Fatalf("expected ErrRejectReasonRequired, got: %v", err)
	}

	// Reject with reason -> succeeds
	reason := "Sedang menolong korban darurat lain"
	updated, err := svc.UpdateTask(ctx, task.ID, UpdateTaskRequest{
		Status:       StatusDitolak,
		RejectReason: &reason,
	}, volunteerID, "relawan")
	if err != nil {
		t.Fatalf("reject with reason failed: %v", err)
	}
	if updated.Status != StatusDitolak || *updated.RejectReason != reason {
		t.Fatalf("unexpected updated rejected task: %+v", updated)
	}
}

func TestVolunteerMaxCapacityEnforcement(t *testing.T) {
	svc, _, _, _ := setupTaskTestEnv()
	ctx := context.Background()

	volunteerID := "vol-busy-1"
	pengurusID := "pengurus-1"

	// Assign Task 1 -> load = 1
	statusAssigned := StatusDitugaskan
	_, err := svc.CreateTask(ctx, "inc-cap", CreateTaskRequest{
		HouseholdID: "hh-cap-1",
		VolunteerID: &volunteerID,
		Status:      &statusAssigned,
	}, pengurusID)
	if err != nil {
		t.Fatalf("task 1 create failed: %v", err)
	}

	// Assign Task 2 -> load = 2 (max capacity reached)
	_, err = svc.CreateTask(ctx, "inc-cap", CreateTaskRequest{
		HouseholdID: "hh-cap-2",
		VolunteerID: &volunteerID,
		Status:      &statusAssigned,
	}, pengurusID)
	if err != nil {
		t.Fatalf("task 2 create failed: %v", err)
	}

	// Assign Task 3 -> must fail with ErrVolunteerOverCapacity (< 2 load required per SDD 6.3)
	_, err = svc.CreateTask(ctx, "inc-cap", CreateTaskRequest{
		HouseholdID: "hh-cap-3",
		VolunteerID: &volunteerID,
		Status:      &statusAssigned,
	}, pengurusID)
	if err != ErrVolunteerOverCapacity {
		t.Fatalf("expected ErrVolunteerOverCapacity for 3rd active task, got: %v", err)
	}
}

func TestFiveMinuteOverdueCheckWithControlledTime(t *testing.T) {
	svc, store, _, _ := setupTaskTestEnv()
	ctx := context.Background()

	incidentID := "inc-overdue-test"
	baseTime := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)

	// Task 1 assigned 4 minutes ago (not overdue)
	t1Assigned := baseTime.Add(-4 * time.Minute)
	vol1 := "vol-1"
	t1 := &Task{
		ID:          "task-fresh",
		IncidentID:  incidentID,
		HouseholdID: "hh-1",
		VolunteerID: &vol1,
		Status:      StatusDitugaskan,
		AssignedAt:  &t1Assigned,
		CreatedAt:   t1Assigned,
	}
	_ = store.CreateTask(ctx, t1)

	// Task 2 assigned 5 minutes 30 seconds ago (overdue!)
	t2Assigned := baseTime.Add(-5*time.Minute - 30*time.Second)
	vol2 := "vol-2"
	t2 := &Task{
		ID:          "task-stale",
		IncidentID:  incidentID,
		HouseholdID: "hh-2",
		VolunteerID: &vol2,
		Status:      StatusDitugaskan,
		AssignedAt:  &t2Assigned,
		CreatedAt:   t2Assigned,
	}
	_ = store.CreateTask(ctx, t2)

	// Controlled time evaluation at baseTime (no flaky sleeps!)
	overdueTasks, err := svc.CheckOverdueTasks(ctx, incidentID, baseTime)
	if err != nil {
		t.Fatalf("CheckOverdueTasks failed: %v", err)
	}

	if len(overdueTasks) != 1 {
		t.Fatalf("expected exactly 1 overdue task, got: %d", len(overdueTasks))
	}
	if overdueTasks[0].ID != "task-stale" {
		t.Fatalf("expected task-stale to be overdue, got: %s", overdueTasks[0].ID)
	}
	if !overdueTasks[0].IsOverdue {
		t.Fatal("expected IsOverdue to be true")
	}
}

func TestTaskHTTPHandler(t *testing.T) {
	jwtSecret := []byte("test-task-jwt-secret-key-32b-length")
	svc, _, hhStore, volStore := setupTaskTestEnv()
	rtID := "rt-task-http-1"
	h := NewHandler(svc, jwtSecret, &dummyTaskIncidentProvider{rtID: rtID})

	r := chi.NewRouter()
	h.Routes(r)

	// Seed household and volunteer
	_ = hhStore.CreateHousehold(context.Background(), &household.Household{
		ID:       "hh-http-1",
		RTID:     rtID,
		Number:   "D4",
		HeadName: "Doni",
	})
	_ = volStore.CreateVolunteer(context.Background(), &volunteer.Volunteer{
		UserID:    "user-vol-http",
		RTID:      rtID,
		Name:      "Relawan Doni",
		Available: true,
	})

	tokenPengurus, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "user-pengurus-http",
		Role:     "pengurus",
		RegionID: rtID,
	})

	// 1. GET /incidents/{id}/plan
	req := httptest.NewRequest(http.MethodGet, "/incidents/inc-http-1/plan", nil)
	req.Header.Set("Authorization", "Bearer "+tokenPengurus)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for /plan, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 2. POST /incidents/{id}/plan/apply
	applyBody, _ := json.Marshal([]priority.SuggestedAssignment{
		{
			HouseholdID: "hh-http-1",
			VolunteerID: "user-vol-http",
		},
	})
	req = httptest.NewRequest(http.MethodPost, "/incidents/inc-http-1/plan/apply", bytes.NewReader(applyBody))
	req.Header.Set("Authorization", "Bearer "+tokenPengurus)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for /plan/apply, got: %d (%s)", rec.Code, rec.Body.String())
	}

	var applyResp struct {
		Data []*Task `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &applyResp)
	if len(applyResp.Data) != 1 {
		t.Fatalf("expected 1 task applied, got: %d", len(applyResp.Data))
	}
	taskID := applyResp.Data[0].ID

	// 3. GET /tasks/{id}
	req = httptest.NewRequest(http.MethodGet, "/tasks/"+taskID, nil)
	req.Header.Set("Authorization", "Bearer "+tokenPengurus)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for GET /tasks/{id}, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 4. GET /incidents/{id}/tasks/overdue
	req = httptest.NewRequest(http.MethodGet, "/incidents/inc-http-1/tasks/overdue", nil)
	req.Header.Set("Authorization", "Bearer "+tokenPengurus)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for /tasks/overdue, got: %d (%s)", rec.Code, rec.Body.String())
	}
}
