package posko

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) RecordConflict(ctx context.Context, c *SyncConflict) error {
	cloudBytes, err := json.Marshal(c.CloudVersion)
	if err != nil {
		return err
	}
	poskoBytes, err := json.Marshal(c.PoskoVersion)
	if err != nil {
		return err
	}

	query := `INSERT INTO sync_conflicts (id, region_id, posko_id, entity, entity_id, cloud_version, posko_version, status, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`

	if c.CreatedAt.IsZero() {
		c.CreatedAt = time.Now().UTC()
	}

	_, err = s.pool.Exec(ctx, query,
		c.ID, c.RegionID, c.PoskoID, c.Entity, c.EntityID,
		cloudBytes, poskoBytes, c.Status, c.CreatedAt,
	)
	return err
}

func (s *PostgresStore) ListConflicts(ctx context.Context, regionID string, status string) ([]*SyncConflict, error) {
	query := `SELECT id, region_id, posko_id, entity, entity_id, cloud_version, posko_version, status, resolved_by, resolved_at, created_at
	          FROM sync_conflicts WHERE 1=1`
	var args []any
	argIdx := 1

	if regionID != "" {
		query += fmt.Sprintf(" AND region_id = $%d", argIdx)
		args = append(args, regionID)
		argIdx++
	}
	if status != "" {
		query += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}

	query += ` ORDER BY created_at DESC`

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*SyncConflict
	for rows.Next() {
		var c SyncConflict
		var cloudBytes, poskoBytes []byte
		var resolvedBy *string
		var resolvedAt *time.Time

		if err := rows.Scan(
			&c.ID, &c.RegionID, &c.PoskoID, &c.Entity, &c.EntityID,
			&cloudBytes, &poskoBytes, &c.Status, &resolvedBy, &resolvedAt, &c.CreatedAt,
		); err != nil {
			return nil, err
		}

		_ = json.Unmarshal(cloudBytes, &c.CloudVersion)
		_ = json.Unmarshal(poskoBytes, &c.PoskoVersion)
		c.ResolvedBy = resolvedBy
		c.ResolvedAt = resolvedAt
		result = append(result, &c)
	}

	return result, nil
}

func (s *PostgresStore) GetConflict(ctx context.Context, id string) (*SyncConflict, error) {
	query := `SELECT id, region_id, posko_id, entity, entity_id, cloud_version, posko_version, status, resolved_by, resolved_at, created_at
	          FROM sync_conflicts WHERE id = $1`

	var c SyncConflict
	var cloudBytes, poskoBytes []byte
	var resolvedBy *string
	var resolvedAt *time.Time

	err := s.pool.QueryRow(ctx, query, id).Scan(
		&c.ID, &c.RegionID, &c.PoskoID, &c.Entity, &c.EntityID,
		&cloudBytes, &poskoBytes, &c.Status, &resolvedBy, &resolvedAt, &c.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrConflictNotFound
		}
		return nil, err
	}

	_ = json.Unmarshal(cloudBytes, &c.CloudVersion)
	_ = json.Unmarshal(poskoBytes, &c.PoskoVersion)
	c.ResolvedBy = resolvedBy
	c.ResolvedAt = resolvedAt
	return &c, nil
}

func (s *PostgresStore) ResolveConflict(ctx context.Context, id string, resolvedBy string) error {
	now := time.Now().UTC()
	query := `UPDATE sync_conflicts SET status = 'resolved', resolved_by = $1, resolved_at = $2 WHERE id = $3`
	res, err := s.pool.Exec(ctx, query, resolvedBy, now, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrConflictNotFound
	}
	return nil
}

func (s *PostgresStore) GetSyncCursor(ctx context.Context, poskoID string) (int64, error) {
	// Query the highest applied event id for this posko
	return 0, nil
}

func (s *PostgresStore) UpdateSyncCursor(ctx context.Context, poskoID string, cursor int64) error {
	return nil
}
