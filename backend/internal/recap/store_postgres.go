package recap

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) SaveRecap(ctx context.Context, r *Recap) error {
	if r.ID == "" {
		r.ID = uuid.NewString()
	}
	if r.CreatedAt.IsZero() {
		r.CreatedAt = time.Now().UTC()
	}
	r.UpdatedAt = r.CreatedAt

	dataBytes, err := json.Marshal(r.Data)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO recaps (id, incident_id, data, narrative, ai_assisted, notes, approved_by, approved_at, pdf_url, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	_, err = s.pool.Exec(ctx, query,
		r.ID, r.IncidentID, dataBytes, r.Narrative, r.AIAssisted, r.Notes,
		r.ApprovedBy, r.ApprovedAt, r.PDFURL, r.CreatedAt, r.UpdatedAt,
	)
	return err
}

func (s *PostgresStore) GetRecap(ctx context.Context, id string) (*Recap, error) {
	query := `
		SELECT id, incident_id, data, narrative, ai_assisted, notes, approved_by, approved_at, pdf_url, created_at, updated_at
		FROM recaps
		WHERE id = $1
	`
	var r Recap
	var dataBytes []byte

	err := s.pool.QueryRow(ctx, query, id).Scan(
		&r.ID, &r.IncidentID, &dataBytes, &r.Narrative, &r.AIAssisted, &r.Notes,
		&r.ApprovedBy, &r.ApprovedAt, &r.PDFURL, &r.CreatedAt, &r.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRecapNotFound
		}
		return nil, err
	}

	_ = json.Unmarshal(dataBytes, &r.Data)
	return &r, nil
}

func (s *PostgresStore) GetRecapByIncidentID(ctx context.Context, incidentID string) (*Recap, error) {
	query := `
		SELECT id, incident_id, data, narrative, ai_assisted, notes, approved_by, approved_at, pdf_url, created_at, updated_at
		FROM recaps
		WHERE incident_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`
	var r Recap
	var dataBytes []byte

	err := s.pool.QueryRow(ctx, query, incidentID).Scan(
		&r.ID, &r.IncidentID, &dataBytes, &r.Narrative, &r.AIAssisted, &r.Notes,
		&r.ApprovedBy, &r.ApprovedAt, &r.PDFURL, &r.CreatedAt, &r.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRecapNotFound
		}
		return nil, err
	}

	_ = json.Unmarshal(dataBytes, &r.Data)
	return &r, nil
}

func (s *PostgresStore) UpdateRecap(ctx context.Context, r *Recap) error {
	r.UpdatedAt = time.Now().UTC()
	dataBytes, err := json.Marshal(r.Data)
	if err != nil {
		return err
	}

	query := `
		UPDATE recaps
		SET data = $1, narrative = $2, ai_assisted = $3, notes = $4,
		    approved_by = $5, approved_at = $6, pdf_url = $7, updated_at = $8
		WHERE id = $9
	`
	res, err := s.pool.Exec(ctx, query,
		dataBytes, r.Narrative, r.AIAssisted, r.Notes,
		r.ApprovedBy, r.ApprovedAt, r.PDFURL, r.UpdatedAt, r.ID,
	)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrRecapNotFound
	}
	return nil
}
