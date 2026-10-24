package volunteer

import (
	"context"
	"encoding/json"
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

func (s *PostgresStore) CreateBlock(ctx context.Context, b *Block) error {
	polyJSON, err := json.Marshal(b.Polygon)
	if err != nil {
		return err
	}

	query := `INSERT INTO blocks (id, rt_id, name, polygon, created_at)
	          VALUES ($1, $2, $3, $4, $5)`
	_, err = s.pool.Exec(ctx, query, b.ID, b.RTID, b.Name, polyJSON, b.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrDuplicateBlock
		}
		return err
	}
	return nil
}

func (s *PostgresStore) GetBlock(ctx context.Context, id string) (*Block, error) {
	query := `SELECT id, rt_id, name, polygon, created_at FROM blocks WHERE id = $1 LIMIT 1`
	var b Block
	var polyBytes []byte
	err := s.pool.QueryRow(ctx, query, id).Scan(&b.ID, &b.RTID, &b.Name, &polyBytes, &b.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrBlockNotFound
		}
		return nil, err
	}
	if len(polyBytes) > 0 {
		_ = json.Unmarshal(polyBytes, &b.Polygon)
	}
	return &b, nil
}

func (s *PostgresStore) ListBlocksByRT(ctx context.Context, rtID string) ([]*Block, error) {
	query := `SELECT id, rt_id, name, polygon, created_at FROM blocks WHERE rt_id = $1 ORDER BY name ASC`
	rows, err := s.pool.Query(ctx, query, rtID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Block
	for rows.Next() {
		var b Block
		var polyBytes []byte
		if err := rows.Scan(&b.ID, &b.RTID, &b.Name, &polyBytes, &b.CreatedAt); err != nil {
			return nil, err
		}
		if len(polyBytes) > 0 {
			_ = json.Unmarshal(polyBytes, &b.Polygon)
		}
		list = append(list, &b)
	}
	return list, rows.Err()
}

func (s *PostgresStore) DeleteBlock(ctx context.Context, id string) error {
	query := `DELETE FROM blocks WHERE id = $1`
	res, err := s.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrBlockNotFound
	}
	return nil
}

func (s *PostgresStore) CreateVolunteer(ctx context.Context, v *Volunteer) error {
	query := `INSERT INTO volunteers (user_id, rt_id, skills, available, last_lat, last_lon, last_loc_at, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`
	_, err := s.pool.Exec(ctx, query, v.UserID, v.RTID, v.Skills, v.Available, v.LastLat, v.LastLon, v.LastLocAt, v.CreatedAt)
	return err
}

func (s *PostgresStore) GetVolunteer(ctx context.Context, userID string) (*Volunteer, error) {
	query := `SELECT v.user_id, v.rt_id, v.skills, v.available, v.last_lat, v.last_lon, v.last_loc_at, v.created_at,
	                 u.name, u.phone
	          FROM volunteers v
	          JOIN users u ON v.user_id = u.id
	          WHERE v.user_id = $1 LIMIT 1`
	var v Volunteer
	err := s.pool.QueryRow(ctx, query, userID).Scan(
		&v.UserID, &v.RTID, &v.Skills, &v.Available, &v.LastLat, &v.LastLon, &v.LastLocAt, &v.CreatedAt,
		&v.Name, &v.Phone,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrVolunteerNotFound
		}
		return nil, err
	}

	blocks, err := s.GetVolunteerBlocks(ctx, userID)
	if err == nil {
		v.AssignedBlocks = blocks
	}

	return &v, nil
}

func (s *PostgresStore) UpdateVolunteer(ctx context.Context, v *Volunteer) error {
	query := `UPDATE volunteers SET skills = $1, available = $2, last_lat = $3, last_lon = $4, last_loc_at = $5
	          WHERE user_id = $6`
	res, err := s.pool.Exec(ctx, query, v.Skills, v.Available, v.LastLat, v.LastLon, v.LastLocAt, v.UserID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrVolunteerNotFound
	}
	return nil
}

func (s *PostgresStore) SetVolunteerAvailability(ctx context.Context, userID string, available bool) error {
	query := `UPDATE volunteers SET available = $1 WHERE user_id = $2`
	res, err := s.pool.Exec(ctx, query, available, userID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrVolunteerNotFound
	}
	return nil
}

func (s *PostgresStore) ListVolunteersByRT(ctx context.Context, rtID string) ([]*Volunteer, error) {
	query := `SELECT v.user_id, v.rt_id, v.skills, v.available, v.last_lat, v.last_lon, v.last_loc_at, v.created_at,
	                 u.name, u.phone
	          FROM volunteers v
	          JOIN users u ON v.user_id = u.id
	          WHERE v.rt_id = $1 ORDER BY u.name ASC`
	rows, err := s.pool.Query(ctx, query, rtID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Volunteer
	for rows.Next() {
		var v Volunteer
		if err := rows.Scan(
			&v.UserID, &v.RTID, &v.Skills, &v.Available, &v.LastLat, &v.LastLon, &v.LastLocAt, &v.CreatedAt,
			&v.Name, &v.Phone,
		); err != nil {
			return nil, err
		}
		blocks, err := s.GetVolunteerBlocks(ctx, v.UserID)
		if err == nil {
			v.AssignedBlocks = blocks
		}
		list = append(list, &v)
	}
	return list, rows.Err()
}

func (s *PostgresStore) AssignBlocksToVolunteer(ctx context.Context, userID string, blockIDs []string) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM volunteer_blocks WHERE user_id = $1`, userID)
	if err != nil {
		return err
	}

	for _, bID := range blockIDs {
		_, err = tx.Exec(ctx, `INSERT INTO volunteer_blocks (user_id, block_id) VALUES ($1, $2)`, userID, bID)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (s *PostgresStore) GetVolunteerBlocks(ctx context.Context, userID string) ([]string, error) {
	query := `SELECT block_id FROM volunteer_blocks WHERE user_id = $1`
	rows, err := s.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []string
	for rows.Next() {
		var bID string
		if err := rows.Scan(&bID); err != nil {
			return nil, err
		}
		result = append(result, bID)
	}
	return result, rows.Err()
}
