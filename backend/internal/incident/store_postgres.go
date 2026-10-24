package incident

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool       *pgxpool.Pool
	muDrafts   sync.RWMutex
	draftStore map[string]*ActivationDraft
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{
		pool:       pool,
		draftStore: make(map[string]*ActivationDraft),
	}
}

func (s *PostgresStore) CreateIncident(ctx context.Context, inc *Incident) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) // nolint:errcheck

	// Check if an active real incident already exists for this RT
	var activeRealCount int
	err = tx.QueryRow(ctx, `SELECT COUNT(*) FROM incidents WHERE rt_id = $1 AND status = 'aktif' AND mode = 'nyata'`, inc.RTID).Scan(&activeRealCount)
	if err != nil {
		return err
	}

	if inc.Mode == ModeNyata && inc.Status == StatusAktif && activeRealCount > 0 {
		return ErrActiveRealIncidentExists
	}
	if inc.Mode == ModeLatihan && inc.Status == StatusAktif && activeRealCount > 0 {
		return ErrRealIncidentActive
	}

	metricsJSON, err := json.Marshal(inc.Metrics)
	if err != nil {
		metricsJSON = []byte("{}")
	}

	query := `INSERT INTO incidents (id, rt_id, short_id, hazard, mode, scope_block_ids, message, started_by, started_at, ended_at, status, metrics, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`

	_, err = tx.Exec(ctx, query,
		inc.ID, inc.RTID, inc.ShortID, string(inc.Hazard), string(inc.Mode),
		inc.ScopeBlockIDs, inc.Message, inc.StartedBy, inc.StartedAt, inc.EndedAt,
		string(inc.Status), metricsJSON, inc.CreatedAt,
	)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (s *PostgresStore) GetIncident(ctx context.Context, id string) (*Incident, error) {
	query := `SELECT id, rt_id, short_id, hazard, mode, scope_block_ids, message, started_by, started_at, ended_at, status, metrics, created_at
	          FROM incidents WHERE id = $1 LIMIT 1`

	var inc Incident
	var metricsBytes []byte
	var endedAt *time.Time

	err := s.pool.QueryRow(ctx, query, id).Scan(
		&inc.ID, &inc.RTID, &inc.ShortID, &inc.Hazard, &inc.Mode,
		&inc.ScopeBlockIDs, &inc.Message, &inc.StartedBy, &inc.StartedAt, &endedAt,
		&inc.Status, &metricsBytes, &inc.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrIncidentNotFound
		}
		return nil, err
	}
	inc.EndedAt = endedAt
	if len(metricsBytes) > 0 {
		_ = json.Unmarshal(metricsBytes, &inc.Metrics)
	}
	if inc.Metrics.ByChannel == nil {
		inc.Metrics.ByChannel = make(map[string]int)
	}
	return &inc, nil
}

func (s *PostgresStore) GetIncidentByShortID(ctx context.Context, shortID uint32) (*Incident, error) {
	query := `SELECT id, rt_id, short_id, hazard, mode, scope_block_ids, message, started_by, started_at, ended_at, status, metrics, created_at
	          FROM incidents WHERE short_id = $1 LIMIT 1`

	var inc Incident
	var metricsBytes []byte
	var endedAt *time.Time

	err := s.pool.QueryRow(ctx, query, shortID).Scan(
		&inc.ID, &inc.RTID, &inc.ShortID, &inc.Hazard, &inc.Mode,
		&inc.ScopeBlockIDs, &inc.Message, &inc.StartedBy, &inc.StartedAt, &endedAt,
		&inc.Status, &metricsBytes, &inc.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrIncidentNotFound
		}
		return nil, err
	}
	inc.EndedAt = endedAt
	if len(metricsBytes) > 0 {
		_ = json.Unmarshal(metricsBytes, &inc.Metrics)
	}
	if inc.Metrics.ByChannel == nil {
		inc.Metrics.ByChannel = make(map[string]int)
	}
	return &inc, nil
}

func (s *PostgresStore) GetActiveIncidentByRT(ctx context.Context, rtID string, mode *IncidentMode) (*Incident, error) {
	query := `SELECT id, rt_id, short_id, hazard, mode, scope_block_ids, message, started_by, started_at, ended_at, status, metrics, created_at
	          FROM incidents WHERE rt_id = $1 AND status = 'aktif'`
	var args []any
	args = append(args, rtID)
	if mode != nil {
		query += ` AND mode = $2`
		args = append(args, string(*mode))
	}
	query += ` ORDER BY started_at DESC LIMIT 1`

	var inc Incident
	var metricsBytes []byte
	var endedAt *time.Time

	err := s.pool.QueryRow(ctx, query, args...).Scan(
		&inc.ID, &inc.RTID, &inc.ShortID, &inc.Hazard, &inc.Mode,
		&inc.ScopeBlockIDs, &inc.Message, &inc.StartedBy, &inc.StartedAt, &endedAt,
		&inc.Status, &metricsBytes, &inc.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrIncidentNotFound
		}
		return nil, err
	}
	inc.EndedAt = endedAt
	if len(metricsBytes) > 0 {
		_ = json.Unmarshal(metricsBytes, &inc.Metrics)
	}
	if inc.Metrics.ByChannel == nil {
		inc.Metrics.ByChannel = make(map[string]int)
	}
	return &inc, nil
}

func (s *PostgresStore) ListIncidentsByRT(ctx context.Context, rtID string) ([]*Incident, error) {
	query := `SELECT id, rt_id, short_id, hazard, mode, scope_block_ids, message, started_by, started_at, ended_at, status, metrics, created_at
	          FROM incidents WHERE rt_id = $1 ORDER BY started_at DESC`

	rows, err := s.pool.Query(ctx, query, rtID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Incident
	for rows.Next() {
		var inc Incident
		var metricsBytes []byte
		var endedAt *time.Time
		if err := rows.Scan(
			&inc.ID, &inc.RTID, &inc.ShortID, &inc.Hazard, &inc.Mode,
			&inc.ScopeBlockIDs, &inc.Message, &inc.StartedBy, &inc.StartedAt, &endedAt,
			&inc.Status, &metricsBytes, &inc.CreatedAt,
		); err != nil {
			return nil, err
		}
		inc.EndedAt = endedAt
		if len(metricsBytes) > 0 {
			_ = json.Unmarshal(metricsBytes, &inc.Metrics)
		}
		if inc.Metrics.ByChannel == nil {
			inc.Metrics.ByChannel = make(map[string]int)
		}
		result = append(result, &inc)
	}
	return result, rows.Err()
}

func (s *PostgresStore) UpdateIncident(ctx context.Context, inc *Incident) error {
	metricsJSON, err := json.Marshal(inc.Metrics)
	if err != nil {
		metricsJSON = []byte("{}")
	}

	query := `UPDATE incidents SET
	          hazard = $1, mode = $2, scope_block_ids = $3, message = $4,
	          ended_at = $5, status = $6, metrics = $7
	          WHERE id = $8`

	res, err := s.pool.Exec(ctx, query,
		string(inc.Hazard), string(inc.Mode), inc.ScopeBlockIDs, inc.Message,
		inc.EndedAt, string(inc.Status), metricsJSON, inc.ID,
	)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrIncidentNotFound
	}
	return nil
}

func (s *PostgresStore) SaveDraft(ctx context.Context, draft *ActivationDraft) error {
	s.muDrafts.Lock()
	defer s.muDrafts.Unlock()

	copyDraft := *draft
	s.draftStore[draft.Token] = &copyDraft
	return nil
}

func (s *PostgresStore) GetDraft(ctx context.Context, token string) (*ActivationDraft, error) {
	s.muDrafts.RLock()
	defer s.muDrafts.RUnlock()

	draft, exists := s.draftStore[token]
	if !exists || time.Now().UTC().After(draft.ExpiresAt) {
		return nil, ErrDraftNotFoundOrExpired
	}
	copyDraft := *draft
	return &copyDraft, nil
}

func (s *PostgresStore) DeleteDraft(ctx context.Context, token string) error {
	s.muDrafts.Lock()
	defer s.muDrafts.Unlock()

	delete(s.draftStore, token)
	return nil
}
