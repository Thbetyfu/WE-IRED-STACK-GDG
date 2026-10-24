package announcement

import (
	"context"
	"encoding/base64"
	"errors"
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

func (s *PostgresStore) CreateAnnouncement(ctx context.Context, a *Announcement) error {
	sigBytes, _ := base64.StdEncoding.DecodeString(a.Signature)

	query := `INSERT INTO announcements (id, region_ids, incident_id, short_id, level, text, expires_at, signature, payload_raw, channels, created_by, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`

	if a.CreatedAt.IsZero() {
		a.CreatedAt = time.Now().UTC()
	}

	_, err := s.pool.Exec(ctx, query,
		a.ID, a.RegionIDs, a.IncidentID, a.ShortID, string(a.Level),
		a.Text, a.ExpiresAt, sigBytes, a.PayloadRaw, a.Channels,
		a.CreatedBy, a.CreatedAt,
	)
	return err
}

func (s *PostgresStore) GetAnnouncement(ctx context.Context, id string) (*Announcement, error) {
	query := `SELECT id, region_ids, incident_id, short_id, level, text, expires_at, signature, payload_raw, channels, created_by, created_at
	          FROM announcements WHERE id = $1`

	var a Announcement
	var levelStr string
	var sigBytes []byte
	var incidentID *string

	err := s.pool.QueryRow(ctx, query, id).Scan(
		&a.ID, &a.RegionIDs, &incidentID, &a.ShortID, &levelStr,
		&a.Text, &a.ExpiresAt, &sigBytes, &a.PayloadRaw, &a.Channels,
		&a.CreatedBy, &a.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrAnnouncementNotFound
		}
		return nil, err
	}

	a.IncidentID = incidentID
	a.Level = AnnouncementLevel(levelStr)
	a.Signature = base64.StdEncoding.EncodeToString(sigBytes)
	return &a, nil
}

func (s *PostgresStore) ListActiveAnnouncementsByRT(ctx context.Context, rtID string, now time.Time) ([]*Announcement, error) {
	if now.IsZero() {
		now = time.Now().UTC()
	}

	query := `SELECT id, region_ids, incident_id, short_id, level, text, expires_at, signature, payload_raw, channels, created_by, created_at
	          FROM announcements
	          WHERE ($1 = ANY(region_ids) OR cardinality(region_ids) = 0)
	            AND expires_at > $2
	          ORDER BY (CASE WHEN level = 'darurat' THEN 1 ELSE 2 END) ASC, created_at DESC`

	rows, err := s.pool.Query(ctx, query, rtID, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Announcement
	for rows.Next() {
		var a Announcement
		var levelStr string
		var sigBytes []byte
		var incidentID *string

		if err := rows.Scan(
			&a.ID, &a.RegionIDs, &incidentID, &a.ShortID, &levelStr,
			&a.Text, &a.ExpiresAt, &sigBytes, &a.PayloadRaw, &a.Channels,
			&a.CreatedBy, &a.CreatedAt,
		); err != nil {
			return nil, err
		}

		a.IncidentID = incidentID
		a.Level = AnnouncementLevel(levelStr)
		a.Signature = base64.StdEncoding.EncodeToString(sigBytes)
		result = append(result, &a)
	}

	return result, nil
}

func (s *PostgresStore) ListAllAnnouncementsByRT(ctx context.Context, rtID string) ([]*Announcement, error) {
	query := `SELECT id, region_ids, incident_id, short_id, level, text, expires_at, signature, payload_raw, channels, created_by, created_at
	          FROM announcements
	          WHERE ($1 = ANY(region_ids) OR cardinality(region_ids) = 0)
	          ORDER BY created_at DESC`

	rows, err := s.pool.Query(ctx, query, rtID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Announcement
	for rows.Next() {
		var a Announcement
		var levelStr string
		var sigBytes []byte
		var incidentID *string

		if err := rows.Scan(
			&a.ID, &a.RegionIDs, &incidentID, &a.ShortID, &levelStr,
			&a.Text, &a.ExpiresAt, &sigBytes, &a.PayloadRaw, &a.Channels,
			&a.CreatedBy, &a.CreatedAt,
		); err != nil {
			return nil, err
		}

		a.IncidentID = incidentID
		a.Level = AnnouncementLevel(levelStr)
		a.Signature = base64.StdEncoding.EncodeToString(sigBytes)
		result = append(result, &a)
	}

	return result, nil
}

func (s *PostgresStore) GetLatestSignedPacketByRT(ctx context.Context, rtID string, now time.Time) ([]byte, error) {
	if now.IsZero() {
		now = time.Now().UTC()
	}

	query := `SELECT payload_raw
	          FROM announcements
	          WHERE ($1 = ANY(region_ids) OR cardinality(region_ids) = 0)
	            AND expires_at > $2
	          ORDER BY (CASE WHEN level = 'darurat' THEN 1 ELSE 2 END) ASC, created_at DESC
	          LIMIT 1`

	var raw []byte
	err := s.pool.QueryRow(ctx, query, rtID, now).Scan(&raw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrAnnouncementNotFound
		}
		return nil, err
	}
	return raw, nil
}

func (s *PostgresStore) SavePoskoDelegation(ctx context.Context, del *PoskoDelegation) error {
	query := `INSERT INTO posko_delegations (posko_id, rt_id, posko_public_key, valid_until, cloud_signature, created_at)
	          VALUES ($1, $2, $3, $4, $5, NOW())
	          ON CONFLICT (posko_id) DO UPDATE SET
	              rt_id = EXCLUDED.rt_id,
	              posko_public_key = EXCLUDED.posko_public_key,
	              valid_until = EXCLUDED.valid_until,
	              cloud_signature = EXCLUDED.cloud_signature`

	_, err := s.pool.Exec(ctx, query, del.PoskoID, del.RTID, del.PoskoPublicKey, del.ValidUntil, del.CloudSignature)
	return err
}

func (s *PostgresStore) GetPoskoDelegation(ctx context.Context, poskoID string) (*PoskoDelegation, error) {
	query := `SELECT posko_id, rt_id, posko_public_key, valid_until, cloud_signature
	          FROM posko_delegations WHERE posko_id = $1`

	var del PoskoDelegation
	err := s.pool.QueryRow(ctx, query, poskoID).Scan(
		&del.PoskoID, &del.RTID, &del.PoskoPublicKey, &del.ValidUntil, &del.CloudSignature,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrInvalidDelegation
		}
		return nil, err
	}
	return &del, nil
}
