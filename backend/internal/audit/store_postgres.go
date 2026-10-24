package audit

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) Record(ctx context.Context, l *AuditLog) error {
	if l.ID == "" {
		l.ID = uuid.NewString()
	}
	if l.CreatedAt.IsZero() {
		l.CreatedAt = time.Now().UTC()
	}

	detailsBytes, err := json.Marshal(l.Details)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO audit_logs (id, region_id, user_id, action, entity, entity_id, details, ip_address, user_agent, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err = s.pool.Exec(ctx, query,
		l.ID, l.RegionID, l.UserID, l.Action, l.Entity, l.EntityID,
		detailsBytes, l.IPAddress, l.UserAgent, l.CreatedAt,
	)
	return err
}

func (s *PostgresStore) ListByRegion(ctx context.Context, regionID string, limit, offset int) ([]*AuditLog, int, error) {
	if limit <= 0 {
		limit = 50
	}

	countQuery := `SELECT COUNT(*) FROM audit_logs WHERE region_id = $1`
	var total int
	err := s.pool.QueryRow(ctx, countQuery, regionID).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	query := `
		SELECT id, region_id, user_id, action, entity, entity_id, details, ip_address, user_agent, created_at
		FROM audit_logs
		WHERE region_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := s.pool.Query(ctx, query, regionID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []*AuditLog
	for rows.Next() {
		var l AuditLog
		var detailsBytes []byte
		var ip *string
		var ua *string

		if err := rows.Scan(
			&l.ID, &l.RegionID, &l.UserID, &l.Action, &l.Entity, &l.EntityID,
			&detailsBytes, &ip, &ua, &l.CreatedAt,
		); err != nil {
			return nil, 0, err
		}

		if ip != nil {
			l.IPAddress = *ip
		}
		if ua != nil {
			l.UserAgent = *ua
		}
		_ = json.Unmarshal(detailsBytes, &l.Details)
		list = append(list, &l)
	}

	return list, total, nil
}
