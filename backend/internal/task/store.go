package task

import (
	"context"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store interface {
	CreateTask(ctx context.Context, t *Task) error
	GetTask(ctx context.Context, id string) (*Task, error)
	UpdateTask(ctx context.Context, t *Task) error
	ListTasksByIncident(ctx context.Context, incidentID string, status *TaskStatus, volunteerID *string) ([]*Task, error)
	GetActiveVolunteerTaskCount(ctx context.Context, incidentID, volunteerID string) (int, error)
	GetActiveTaskForHousehold(ctx context.Context, incidentID, householdID string) (*Task, error)
	GetOverdueTasks(ctx context.Context, incidentID string, threshold time.Time) ([]*Task, error)
}

// MemoryStore provides in-memory thread-safe task storage for tests and posko mode.
type MemoryStore struct {
	mu    sync.RWMutex
	tasks map[string]*Task
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		tasks: make(map[string]*Task),
	}
}

func (s *MemoryStore) CreateTask(ctx context.Context, t *Task) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if t.CreatedAt.IsZero() {
		t.CreatedAt = time.Now().UTC()
	}
	t.UpdatedAt = t.CreatedAt

	copyT := *t
	s.tasks[t.ID] = &copyT
	return nil
}

func (s *MemoryStore) GetTask(ctx context.Context, id string) (*Task, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	t, exists := s.tasks[id]
	if !exists {
		return nil, ErrTaskNotFound
	}
	copyT := *t
	return &copyT, nil
}

func (s *MemoryStore) UpdateTask(ctx context.Context, t *Task) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.tasks[t.ID]; !exists {
		return ErrTaskNotFound
	}
	t.UpdatedAt = time.Now().UTC()
	copyT := *t
	s.tasks[t.ID] = &copyT
	return nil
}

func (s *MemoryStore) ListTasksByIncident(ctx context.Context, incidentID string, status *TaskStatus, volunteerID *string) ([]*Task, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Task
	for _, t := range s.tasks {
		if t.IncidentID != incidentID {
			continue
		}
		if status != nil && t.Status != *status {
			continue
		}
		if volunteerID != nil {
			if t.VolunteerID == nil || *t.VolunteerID != *volunteerID {
				continue
			}
		}
		copyT := *t
		result = append(result, &copyT)
	}
	return result, nil
}

func (s *MemoryStore) GetActiveVolunteerTaskCount(ctx context.Context, incidentID, volunteerID string) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	count := 0
	for _, t := range s.tasks {
		if t.IncidentID == incidentID && t.VolunteerID != nil && *t.VolunteerID == volunteerID {
			if t.Status == StatusDitugaskan || t.Status == StatusDiterima || t.Status == StatusDalamPerjalanan {
				count++
			}
		}
	}
	return count, nil
}

func (s *MemoryStore) GetActiveTaskForHousehold(ctx context.Context, incidentID, householdID string) (*Task, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, t := range s.tasks {
		if t.IncidentID == incidentID && t.HouseholdID == householdID {
			if t.Status == StatusDitugaskan || t.Status == StatusDiterima || t.Status == StatusDalamPerjalanan || t.Status == StatusDijangkau {
				copyT := *t
				return &copyT, nil
			}
		}
	}
	return nil, nil
}

func (s *MemoryStore) GetOverdueTasks(ctx context.Context, incidentID string, threshold time.Time) ([]*Task, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Task
	for _, t := range s.tasks {
		if (incidentID == "" || t.IncidentID == incidentID) && t.Status == StatusDitugaskan {
			if t.AssignedAt != nil && t.AssignedAt.Before(threshold) {
				copyT := *t
				copyT.IsOverdue = true
				result = append(result, &copyT)
			}
		}
	}
	return result, nil
}

// PostgresStore implements Store for PostgreSQL database.
type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) CreateTask(ctx context.Context, t *Task) error {
	query := `INSERT INTO tasks (
		id, incident_id, household_id, volunteer_id, status, outcome, reject_reason, notes,
		created_by, assigned_at, accepted_at, reached_at, completed_at, created_at, updated_at
	) VALUES (
		$1, $2, $3, $4, $5, $6, $7, $8,
		$9, $10, $11, $12, $13, $14, $15
	)`

	_, err := s.pool.Exec(ctx, query,
		t.ID, t.IncidentID, t.HouseholdID, t.VolunteerID, string(t.Status), t.Outcome, t.RejectReason, t.Notes,
		t.CreatedBy, t.AssignedAt, t.AcceptedAt, t.ReachedAt, t.CompletedAt, t.CreatedAt, t.UpdatedAt,
	)
	return err
}

func (s *PostgresStore) GetTask(ctx context.Context, id string) (*Task, error) {
	query := `SELECT id, incident_id, household_id, volunteer_id, status, outcome, reject_reason, notes,
	                 created_by, assigned_at, accepted_at, reached_at, completed_at, created_at, updated_at
	          FROM tasks WHERE id = $1 LIMIT 1`

	var t Task
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&t.ID, &t.IncidentID, &t.HouseholdID, &t.VolunteerID, &t.Status, &t.Outcome, &t.RejectReason, &t.Notes,
		&t.CreatedBy, &t.AssignedAt, &t.AcceptedAt, &t.ReachedAt, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, ErrTaskNotFound
		}
		return nil, err
	}
	return &t, nil
}

func (s *PostgresStore) UpdateTask(ctx context.Context, t *Task) error {
	query := `UPDATE tasks SET
	          volunteer_id = $1, status = $2, outcome = $3, reject_reason = $4, notes = $5,
	          assigned_at = $6, accepted_at = $7, reached_at = $8, completed_at = $9, updated_at = NOW()
	          WHERE id = $10`

	res, err := s.pool.Exec(ctx, query,
		t.VolunteerID, string(t.Status), t.Outcome, t.RejectReason, t.Notes,
		t.AssignedAt, t.AcceptedAt, t.ReachedAt, t.CompletedAt, t.ID,
	)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrTaskNotFound
	}
	return nil
}

func (s *PostgresStore) ListTasksByIncident(ctx context.Context, incidentID string, status *TaskStatus, volunteerID *string) ([]*Task, error) {
	query := `SELECT id, incident_id, household_id, volunteer_id, status, outcome, reject_reason, notes,
	                 created_by, assigned_at, accepted_at, reached_at, completed_at, created_at, updated_at
	          FROM tasks WHERE incident_id = $1`
	var args []any
	args = append(args, incidentID)
	argIdx := 2

	if status != nil {
		query += " AND status = $" + string(rune('0'+argIdx))
		args = append(args, string(*status))
		argIdx++
	}
	if volunteerID != nil {
		query += " AND volunteer_id = $" + string(rune('0'+argIdx))
		args = append(args, *volunteerID)
		argIdx++
	}
	query += " ORDER BY created_at DESC"

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Task
	for rows.Next() {
		var t Task
		if err := rows.Scan(
			&t.ID, &t.IncidentID, &t.HouseholdID, &t.VolunteerID, &t.Status, &t.Outcome, &t.RejectReason, &t.Notes,
			&t.CreatedBy, &t.AssignedAt, &t.AcceptedAt, &t.ReachedAt, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, &t)
	}
	return result, rows.Err()
}

func (s *PostgresStore) GetActiveVolunteerTaskCount(ctx context.Context, incidentID, volunteerID string) (int, error) {
	query := `SELECT COUNT(*) FROM tasks
	          WHERE incident_id = $1 AND volunteer_id = $2
	          AND status IN ('ditugaskan', 'diterima', 'dalam_perjalanan')`
	var count int
	err := s.pool.QueryRow(ctx, query, incidentID, volunteerID).Scan(&count)
	return count, err
}

func (s *PostgresStore) GetActiveTaskForHousehold(ctx context.Context, incidentID, householdID string) (*Task, error) {
	query := `SELECT id, incident_id, household_id, volunteer_id, status, outcome, reject_reason, notes,
	                 created_by, assigned_at, accepted_at, reached_at, completed_at, created_at, updated_at
	          FROM tasks
	          WHERE incident_id = $1 AND household_id = $2
	          AND status IN ('ditugaskan', 'diterima', 'dalam_perjalanan', 'dijangkau')
	          LIMIT 1`

	var t Task
	err := s.pool.QueryRow(ctx, query, incidentID, householdID).Scan(
		&t.ID, &t.IncidentID, &t.HouseholdID, &t.VolunteerID, &t.Status, &t.Outcome, &t.RejectReason, &t.Notes,
		&t.CreatedBy, &t.AssignedAt, &t.AcceptedAt, &t.ReachedAt, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &t, nil
}

func (s *PostgresStore) GetOverdueTasks(ctx context.Context, incidentID string, threshold time.Time) ([]*Task, error) {
	query := `SELECT id, incident_id, household_id, volunteer_id, status, outcome, reject_reason, notes,
	                 created_by, assigned_at, accepted_at, reached_at, completed_at, created_at, updated_at
	          FROM tasks
	          WHERE status = 'ditugaskan' AND assigned_at < $1`
	var args []any
	args = append(args, threshold)

	if incidentID != "" {
		query += " AND incident_id = $2"
		args = append(args, incidentID)
	}
	query += " ORDER BY assigned_at ASC"

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Task
	for rows.Next() {
		var t Task
		if err := rows.Scan(
			&t.ID, &t.IncidentID, &t.HouseholdID, &t.VolunteerID, &t.Status, &t.Outcome, &t.RejectReason, &t.Notes,
			&t.CreatedBy, &t.AssignedAt, &t.AcceptedAt, &t.ReachedAt, &t.CompletedAt, &t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, err
		}
		t.IsOverdue = true
		result = append(result, &t)
	}
	return result, rows.Err()
}
