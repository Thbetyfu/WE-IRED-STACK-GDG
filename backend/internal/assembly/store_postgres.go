package assembly

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) CreateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error {
	if ap.Capacity <= 0 {
		return ErrInvalidCapacity
	}

	facJSON, err := json.Marshal(ap.Facilities)
	if err != nil {
		return err
	}

	query := `INSERT INTO assembly_points (id, rt_id, name, lat, lon, capacity, facilities, contact, is_active, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`
	_, err = s.pool.Exec(ctx, query, ap.ID, ap.RTID, ap.Name, ap.Lat, ap.Lon, ap.Capacity, facJSON, ap.Contact, ap.IsActive, ap.CreatedAt)
	return err
}

func (s *PostgresStore) GetAssemblyPoint(ctx context.Context, id string) (*AssemblyPoint, error) {
	query := `SELECT id, rt_id, name, lat, lon, capacity, facilities, contact, is_active, created_at
	          FROM assembly_points WHERE id = $1 LIMIT 1`
	var ap AssemblyPoint
	var facJSON []byte
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&ap.ID, &ap.RTID, &ap.Name, &ap.Lat, &ap.Lon, &ap.Capacity, &facJSON, &ap.Contact, &ap.IsActive, &ap.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrAssemblyPointNotFound
		}
		return nil, err
	}
	_ = json.Unmarshal(facJSON, &ap.Facilities)
	return &ap, nil
}

func (s *PostgresStore) UpdateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error {
	if ap.Capacity <= 0 {
		return ErrInvalidCapacity
	}

	facJSON, err := json.Marshal(ap.Facilities)
	if err != nil {
		return err
	}

	query := `UPDATE assembly_points SET name = $1, lat = $2, lon = $3, capacity = $4, facilities = $5, contact = $6, is_active = $7
	          WHERE id = $8`
	res, err := s.pool.Exec(ctx, query, ap.Name, ap.Lat, ap.Lon, ap.Capacity, facJSON, ap.Contact, ap.IsActive, ap.ID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrAssemblyPointNotFound
	}
	return nil
}

func (s *PostgresStore) DeleteAssemblyPoint(ctx context.Context, id string) error {
	query := `DELETE FROM assembly_points WHERE id = $1`
	res, err := s.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrAssemblyPointNotFound
	}
	return nil
}

func (s *PostgresStore) ListAssemblyPointsByRT(ctx context.Context, rtID string, activeOnly bool) ([]*AssemblyPoint, error) {
	query := `SELECT id, rt_id, name, lat, lon, capacity, facilities, contact, is_active, created_at
	          FROM assembly_points WHERE rt_id = $1 AND ($2 = false OR is_active = true)
	          ORDER BY name ASC`
	rows, err := s.pool.Query(ctx, query, rtID, activeOnly)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*AssemblyPoint
	for rows.Next() {
		var ap AssemblyPoint
		var facJSON []byte
		if err := rows.Scan(
			&ap.ID, &ap.RTID, &ap.Name, &ap.Lat, &ap.Lon, &ap.Capacity, &facJSON, &ap.Contact, &ap.IsActive, &ap.CreatedAt,
		); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(facJSON, &ap.Facilities)
		list = append(list, &ap)
	}
	return list, rows.Err()
}

func (s *PostgresStore) SetBlockAssemblyPoints(ctx context.Context, blockID, primaryAPID, secondaryAPID string) error {
	if primaryAPID == secondaryAPID {
		return ErrSameAssemblyPoint
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Delete existing mappings
	_, err = tx.Exec(ctx, `DELETE FROM block_assembly_points WHERE block_id = $1`, blockID)
	if err != nil {
		return err
	}

	// Insert primary (rank 1)
	_, err = tx.Exec(ctx, `INSERT INTO block_assembly_points (block_id, assembly_point_id, rank) VALUES ($1, $2, 1)`, blockID, primaryAPID)
	if err != nil {
		return err
	}

	// Insert secondary (rank 2)
	_, err = tx.Exec(ctx, `INSERT INTO block_assembly_points (block_id, assembly_point_id, rank) VALUES ($1, $2, 2)`, blockID, secondaryAPID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (s *PostgresStore) GetBlockAssemblyPoints(ctx context.Context, blockID string) ([]*BlockAssemblyPoint, error) {
	query := `SELECT bap.block_id, bap.assembly_point_id, bap.rank, ap.name
	          FROM block_assembly_points bap
	          JOIN assembly_points ap ON bap.assembly_point_id = ap.id
	          WHERE bap.block_id = $1
	          ORDER BY bap.rank ASC`
	rows, err := s.pool.Query(ctx, query, blockID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*BlockAssemblyPoint
	for rows.Next() {
		var bap BlockAssemblyPoint
		if err := rows.Scan(&bap.BlockID, &bap.AssemblyPointID, &bap.Rank, &bap.APName); err != nil {
			return nil, err
		}
		list = append(list, &bap)
	}
	return list, rows.Err()
}
