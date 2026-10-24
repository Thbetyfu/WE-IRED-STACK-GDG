package auth

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PostgresStore implements Store using pgxpool.Pool.
type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	query := `SELECT id, name, phone, email, password_hash, created_at FROM users WHERE email = $1 LIMIT 1`
	var u User
	err := s.pool.QueryRow(ctx, query, email).Scan(&u.ID, &u.Name, &u.Phone, &u.Email, &u.PasswordHash, &u.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (s *PostgresStore) GetUserByPhone(ctx context.Context, phone string) (*User, error) {
	query := `SELECT id, name, phone, email, password_hash, created_at FROM users WHERE phone = $1 LIMIT 1`
	var u User
	err := s.pool.QueryRow(ctx, query, phone).Scan(&u.ID, &u.Name, &u.Phone, &u.Email, &u.PasswordHash, &u.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (s *PostgresStore) GetUserByID(ctx context.Context, id string) (*User, error) {
	query := `SELECT id, name, phone, email, password_hash, created_at FROM users WHERE id = $1 LIMIT 1`
	var u User
	err := s.pool.QueryRow(ctx, query, id).Scan(&u.ID, &u.Name, &u.Phone, &u.Email, &u.PasswordHash, &u.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (s *PostgresStore) CreateUser(ctx context.Context, u *User) error {
	query := `INSERT INTO users (id, name, phone, email, password_hash, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6)`
	_, err := s.pool.Exec(ctx, query, u.ID, u.Name, u.Phone, u.Email, u.PasswordHash, u.CreatedAt)
	return err
}

func (s *PostgresStore) GetMemberships(ctx context.Context, userID string) ([]*Membership, error) {
	query := `SELECT id, user_id, region_id, role, household_id, created_at 
	          FROM memberships WHERE user_id = $1 ORDER BY created_at ASC`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Membership
	for rows.Next() {
		var m Membership
		if err := rows.Scan(&m.ID, &m.UserID, &m.RegionID, &m.Role, &m.HouseholdID, &m.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &m)
	}
	return list, rows.Err()
}

func (s *PostgresStore) AddMembership(ctx context.Context, m *Membership) error {
	query := `INSERT INTO memberships (id, user_id, region_id, role, household_id, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6)`
	_, err := s.pool.Exec(ctx, query, m.ID, m.UserID, m.RegionID, m.Role, m.HouseholdID, m.CreatedAt)
	return err
}

func (s *PostgresStore) GetHouseholdByInviteCode(ctx context.Context, inviteCode string) (*Household, error) {
	query := `SELECT id, rt_id, block_id, number, address, head_name, wa_phone, short_id, key_enc, invite_code
	          FROM households WHERE invite_code = $1 LIMIT 1`
	var h Household
	err := s.pool.QueryRow(ctx, query, inviteCode).Scan(
		&h.ID, &h.RTID, &h.BlockID, &h.Number, &h.Address, &h.HeadName, &h.WAPhone, &h.ShortID, &h.KeyEnc, &h.InviteCode,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrHouseholdNotFound
		}
		return nil, err
	}
	return &h, nil
}

func (s *PostgresStore) UpdateHouseholdKeyAndClearInvite(ctx context.Context, householdID string, keyEnc []byte) error {
	query := `UPDATE households SET key_enc = $1, invite_code = NULL WHERE id = $2`
	res, err := s.pool.Exec(ctx, query, keyEnc, householdID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrHouseholdNotFound
	}
	return nil
}

func (s *PostgresStore) GetRecentOTPCount(ctx context.Context, phone string, window time.Duration) (int, error) {
	cutoff := time.Now().Add(-window)
	query := `SELECT COUNT(*) FROM otp_codes WHERE phone = $1 AND created_at >= $2`
	var count int
	err := s.pool.QueryRow(ctx, query, phone, cutoff).Scan(&count)
	return count, err
}

func (s *PostgresStore) SaveOTP(ctx context.Context, phone, code string, expiresAt time.Time) error {
	query := `INSERT INTO otp_codes (phone, code, attempts, expires_at, created_at)
	          VALUES ($1, $2, 0, $3, NOW())`
	_, err := s.pool.Exec(ctx, query, phone, code, expiresAt)
	return err
}

func (s *PostgresStore) GetLatestValidOTP(ctx context.Context, phone string) (*OTPRecord, error) {
	query := `SELECT id, phone, code, attempts, expires_at, consumed_at, created_at
	          FROM otp_codes 
	          WHERE phone = $1 AND consumed_at IS NULL AND expires_at > NOW()
	          ORDER BY created_at DESC LIMIT 1`
	var r OTPRecord
	err := s.pool.QueryRow(ctx, query, phone).Scan(
		&r.ID, &r.Phone, &r.Code, &r.Attempts, &r.ExpiresAt, &r.ConsumedAt, &r.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrOTPInvalid
		}
		return nil, err
	}
	return &r, nil
}

func (s *PostgresStore) IncrementOTPAttempts(ctx context.Context, id string) (int, error) {
	query := `UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1 RETURNING attempts`
	var attempts int
	err := s.pool.QueryRow(ctx, query, id).Scan(&attempts)
	return attempts, err
}

func (s *PostgresStore) ConsumeOTP(ctx context.Context, id string) error {
	query := `UPDATE otp_codes SET consumed_at = NOW() WHERE id = $1`
	_, err := s.pool.Exec(ctx, query, id)
	return err
}

func (s *PostgresStore) SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	query := `INSERT INTO refresh_tokens (user_id, token_hash, revoked, expires_at, created_at)
	          VALUES ($1, $2, FALSE, $3, NOW())`
	_, err := s.pool.Exec(ctx, query, userID, tokenHash, expiresAt)
	return err
}

func (s *PostgresStore) GetRefreshToken(ctx context.Context, tokenHash string) (*RefreshTokenRecord, error) {
	query := `SELECT id, user_id, token_hash, revoked, expires_at, created_at
	          FROM refresh_tokens WHERE token_hash = $1 LIMIT 1`
	var r RefreshTokenRecord
	err := s.pool.QueryRow(ctx, query, tokenHash).Scan(
		&r.ID, &r.UserID, &r.TokenHash, &r.Revoked, &r.ExpiresAt, &r.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTokenRevoked
		}
		return nil, err
	}
	return &r, nil
}

func (s *PostgresStore) RevokeRefreshToken(ctx context.Context, tokenHash string) error {
	query := `UPDATE refresh_tokens SET revoked = TRUE WHERE token_hash = $1`
	_, err := s.pool.Exec(ctx, query, tokenHash)
	return err
}
