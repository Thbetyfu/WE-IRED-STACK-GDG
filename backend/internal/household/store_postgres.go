package household

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) CreateHousehold(ctx context.Context, h *Household) error {
	query := `INSERT INTO households (id, rt_id, block_id, number, address, lat, lon, head_name, wa_phone, has_device, short_id, key_enc, invite_code, is_synthetic, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`
	_, err := s.pool.Exec(ctx, query, h.ID, h.RTID, h.BlockID, h.Number, h.Address, h.Lat, h.Lon, h.HeadName, h.WAPhone, h.HasDevice, h.ShortID, h.KeyEnc, h.InviteCode, h.IsSynthetic, h.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique violation
			return ErrDuplicateNumber
		}
		return err
	}
	return nil
}

func (s *PostgresStore) GetHousehold(ctx context.Context, id string) (*Household, error) {
	query := `SELECT id, rt_id, block_id, number, address, lat, lon, head_name, wa_phone, has_device, short_id, key_enc, invite_code, is_synthetic, created_at
	          FROM households WHERE id = $1 LIMIT 1`
	var h Household
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&h.ID, &h.RTID, &h.BlockID, &h.Number, &h.Address, &h.Lat, &h.Lon, &h.HeadName, &h.WAPhone,
		&h.HasDevice, &h.ShortID, &h.KeyEnc, &h.InviteCode, &h.IsSynthetic, &h.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHouseholdNotFound
		}
		return nil, err
	}
	h.SetShortID(h.ShortID)

	// Fetch members
	members, err := s.ListMembers(ctx, id)
	if err == nil {
		h.Members = members
	}

	// Check consent
	_, consentErr := s.GetActiveConsent(ctx, id)
	h.HasConsent = (consentErr == nil)

	return &h, nil
}

func (s *PostgresStore) UpdateHousehold(ctx context.Context, h *Household) error {
	query := `UPDATE households SET block_id = $1, number = $2, address = $3, lat = $4, lon = $5, head_name = $6, wa_phone = $7, has_device = $8
	          WHERE id = $9`
	res, err := s.pool.Exec(ctx, query, h.BlockID, h.Number, h.Address, h.Lat, h.Lon, h.HeadName, h.WAPhone, h.HasDevice, h.ID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrDuplicateNumber
		}
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrHouseholdNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteHousehold(ctx context.Context, id string) error {
	query := `DELETE FROM households WHERE id = $1`
	res, err := s.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrHouseholdNotFound
	}
	return nil
}

func (s *PostgresStore) ListHouseholdsByRT(ctx context.Context, rtID string, blockID *string) ([]*Household, error) {
	query := `SELECT id, rt_id, block_id, number, address, lat, lon, head_name, wa_phone, has_device, short_id, key_enc, invite_code, is_synthetic, created_at
	          FROM households WHERE rt_id = $1 AND ($2::uuid IS NULL OR block_id = $2)
	          ORDER BY number ASC`
	rows, err := s.pool.Query(ctx, query, rtID, blockID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Household
	for rows.Next() {
		var h Household
		if err := rows.Scan(
			&h.ID, &h.RTID, &h.BlockID, &h.Number, &h.Address, &h.Lat, &h.Lon, &h.HeadName, &h.WAPhone,
			&h.HasDevice, &h.ShortID, &h.KeyEnc, &h.InviteCode, &h.IsSynthetic, &h.CreatedAt,
		); err != nil {
			return nil, err
		}
		h.SetShortID(h.ShortID)
		list = append(list, &h)
	}
	return list, rows.Err()
}

func (s *PostgresStore) GetHouseholdByShortID(ctx context.Context, shortID []byte) (*Household, error) {
	query := `SELECT id, rt_id, block_id, number, address, lat, lon, head_name, wa_phone, has_device, short_id, key_enc, invite_code, is_synthetic, created_at
	          FROM households WHERE short_id = $1 LIMIT 1`
	var h Household
	err := s.pool.QueryRow(ctx, query, shortID).Scan(
		&h.ID, &h.RTID, &h.BlockID, &h.Number, &h.Address, &h.Lat, &h.Lon, &h.HeadName, &h.WAPhone,
		&h.HasDevice, &h.ShortID, &h.KeyEnc, &h.InviteCode, &h.IsSynthetic, &h.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHouseholdNotFound
		}
		return nil, err
	}
	h.SetShortID(h.ShortID)
	return &h, nil
}

func (s *PostgresStore) GetHouseholdByInviteCode(ctx context.Context, inviteCode string) (*Household, error) {
	query := `SELECT id, rt_id, block_id, number, address, lat, lon, head_name, wa_phone, has_device, short_id, key_enc, invite_code, is_synthetic, created_at
	          FROM households WHERE invite_code = $1 LIMIT 1`
	var h Household
	err := s.pool.QueryRow(ctx, query, inviteCode).Scan(
		&h.ID, &h.RTID, &h.BlockID, &h.Number, &h.Address, &h.Lat, &h.Lon, &h.HeadName, &h.WAPhone,
		&h.HasDevice, &h.ShortID, &h.KeyEnc, &h.InviteCode, &h.IsSynthetic, &h.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHouseholdNotFound
		}
		return nil, err
	}
	h.SetShortID(h.ShortID)
	return &h, nil
}

func (s *PostgresStore) GetHouseholdByPhone(ctx context.Context, phone string) (*Household, error) {
	norm := normalizePhone(phone)
	query := `SELECT id, rt_id, block_id, number, address, lat, lon, head_name, wa_phone, has_device, short_id, key_enc, invite_code, is_synthetic, created_at
	          FROM households
	          WHERE wa_phone = $1
	             OR REPLACE(REPLACE(REPLACE(wa_phone, ' ', ''), '-', ''), '+', '') = $2
	          LIMIT 1`
	var h Household
	err := s.pool.QueryRow(ctx, query, phone, norm).Scan(
		&h.ID, &h.RTID, &h.BlockID, &h.Number, &h.Address, &h.Lat, &h.Lon, &h.HeadName, &h.WAPhone,
		&h.HasDevice, &h.ShortID, &h.KeyEnc, &h.InviteCode, &h.IsSynthetic, &h.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHouseholdNotFound
		}
		return nil, err
	}
	h.SetShortID(h.ShortID)
	return &h, nil
}

func (s *PostgresStore) UpdateInviteCode(ctx context.Context, id string, newCode *string) error {
	query := `UPDATE households SET invite_code = $1 WHERE id = $2`
	res, err := s.pool.Exec(ctx, query, newCode, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrHouseholdNotFound
	}
	return nil
}

func (s *PostgresStore) AddMember(ctx context.Context, m *Member) error {
	query := `INSERT INTO members (id, household_id, idx, name, birth_year, sex, relation, vuln_flags, health_notes_enc, needs_evac_assist, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`
	_, err := s.pool.Exec(ctx, query, m.ID, m.HouseholdID, m.Idx, m.Name, m.BirthYear, m.Sex, m.Relation, m.VulnFlags, m.HealthNotesEnc, m.NeedsEvacAssist, m.CreatedAt)
	return err
}

func (s *PostgresStore) GetMember(ctx context.Context, householdID, memberID string) (*Member, error) {
	query := `SELECT id, household_id, idx, name, birth_year, sex, relation, vuln_flags, health_notes_enc, needs_evac_assist, created_at
	          FROM members WHERE household_id = $1 AND id = $2 LIMIT 1`
	var m Member
	err := s.pool.QueryRow(ctx, query, householdID, memberID).Scan(
		&m.ID, &m.HouseholdID, &m.Idx, &m.Name, &m.BirthYear, &m.Sex, &m.Relation, &m.VulnFlags,
		&m.HealthNotesEnc, &m.NeedsEvacAssist, &m.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}
	return &m, nil
}

func (s *PostgresStore) UpdateMember(ctx context.Context, m *Member) error {
	query := `UPDATE members SET idx = $1, name = $2, birth_year = $3, sex = $4, relation = $5, vuln_flags = $6, health_notes_enc = $7, needs_evac_assist = $8
	          WHERE household_id = $9 AND id = $10`
	res, err := s.pool.Exec(ctx, query, m.Idx, m.Name, m.BirthYear, m.Sex, m.Relation, m.VulnFlags, m.HealthNotesEnc, m.NeedsEvacAssist, m.HouseholdID, m.ID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrMemberNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteMember(ctx context.Context, householdID, memberID string) error {
	query := `DELETE FROM members WHERE household_id = $1 AND id = $2`
	res, err := s.pool.Exec(ctx, query, householdID, memberID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrMemberNotFound
	}
	return nil
}

func (s *PostgresStore) ListMembers(ctx context.Context, householdID string) ([]*Member, error) {
	query := `SELECT id, household_id, idx, name, birth_year, sex, relation, vuln_flags, health_notes_enc, needs_evac_assist, created_at
	          FROM members WHERE household_id = $1 ORDER BY idx ASC`
	rows, err := s.pool.Query(ctx, query, householdID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Member
	for rows.Next() {
		var m Member
		if err := rows.Scan(
			&m.ID, &m.HouseholdID, &m.Idx, &m.Name, &m.BirthYear, &m.Sex, &m.Relation, &m.VulnFlags,
			&m.HealthNotesEnc, &m.NeedsEvacAssist, &m.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, &m)
	}
	return list, rows.Err()
}

func (s *PostgresStore) RecordConsent(ctx context.Context, c *Consent) error {
	query := `INSERT INTO consents (id, household_id, given_by, method, text_version, given_at, revoked_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7)`
	_, err := s.pool.Exec(ctx, query, c.ID, c.HouseholdID, c.GivenBy, c.Method, c.TextVersion, c.GivenAt, c.RevokedAt)
	return err
}

func (s *PostgresStore) GetActiveConsent(ctx context.Context, householdID string) (*Consent, error) {
	query := `SELECT id, household_id, given_by, method, text_version, given_at, revoked_at
	          FROM consents WHERE household_id = $1 AND revoked_at IS NULL ORDER BY given_at DESC LIMIT 1`
	var c Consent
	err := s.pool.QueryRow(ctx, query, householdID).Scan(
		&c.ID, &c.HouseholdID, &c.GivenBy, &c.Method, &c.TextVersion, &c.GivenAt, &c.RevokedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrConsentRevoked
		}
		return nil, err
	}
	return &c, nil
}

func (s *PostgresStore) RevokeConsent(ctx context.Context, householdID string) error {
	query := `UPDATE consents SET revoked_at = NOW() WHERE household_id = $1 AND revoked_at IS NULL`
	_, err := s.pool.Exec(ctx, query, householdID)
	return err
}

func (s *PostgresStore) PurgeSensitiveHealthData(ctx context.Context, householdID string) error {
	// Erase health_notes_enc and reset detailed vulnerability flags
	query := `UPDATE members SET health_notes_enc = NULL, vuln_flags = 0 WHERE household_id = $1`
	_, err := s.pool.Exec(ctx, query, householdID)
	return err
}
