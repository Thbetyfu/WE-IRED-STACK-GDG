package region

import (
	"context"
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

func (s *PostgresStore) CreateRegion(ctx context.Context, r *Region) error {
	query := `INSERT INTO regions (id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`
	_, err := s.pool.Exec(ctx, query, r.ID, string(r.Type), r.ParentID, r.Name, r.Code, r.CentroidLat, r.CentroidLon, r.AIEnabled, r.CreatedAt)
	return err
}

func (s *PostgresStore) GetRegionByID(ctx context.Context, id string) (*Region, error) {
	query := `SELECT id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at
	          FROM regions WHERE id = $1 LIMIT 1`
	var r Region
	var regionType string
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&r.ID, &regionType, &r.ParentID, &r.Name, &r.Code, &r.CentroidLat, &r.CentroidLon, &r.AIEnabled, &r.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRegionNotFound
		}
		return nil, err
	}
	r.Type = RegionType(regionType)
	return &r, nil
}

func (s *PostgresStore) GetRegionByCode(ctx context.Context, code string) (*Region, error) {
	query := `SELECT id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at
	          FROM regions WHERE code = $1 LIMIT 1`
	var r Region
	var regionType string
	err := s.pool.QueryRow(ctx, query, code).Scan(
		&r.ID, &regionType, &r.ParentID, &r.Name, &r.Code, &r.CentroidLat, &r.CentroidLon, &r.AIEnabled, &r.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRegionNotFound
		}
		return nil, err
	}
	r.Type = RegionType(regionType)
	return &r, nil
}

func (s *PostgresStore) ListRegions(ctx context.Context, regionType RegionType, parentID *string) ([]*Region, error) {
	query := `SELECT id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at
	          FROM regions WHERE ($1 = '' OR type = $1) AND ($2::uuid IS NULL OR parent_id = $2)
	          ORDER BY name ASC`
	rows, err := s.pool.Query(ctx, query, string(regionType), parentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Region
	for rows.Next() {
		var r Region
		var rType string
		if err := rows.Scan(&r.ID, &rType, &r.ParentID, &r.Name, &r.Code, &r.CentroidLat, &r.CentroidLon, &r.AIEnabled, &r.CreatedAt); err != nil {
			return nil, err
		}
		r.Type = RegionType(rType)
		result = append(result, &r)
	}
	return result, rows.Err()
}

func (s *PostgresStore) GetHierarchy(ctx context.Context, rootID *string) ([]*RegionNode, error) {
	query := `SELECT id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at
	          FROM regions ORDER BY name ASC`
	rows, err := s.pool.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	nodes := make(map[string]*RegionNode)
	for rows.Next() {
		var r Region
		var rType string
		if err := rows.Scan(&r.ID, &rType, &r.ParentID, &r.Name, &r.Code, &r.CentroidLat, &r.CentroidLon, &r.AIEnabled, &r.CreatedAt); err != nil {
			return nil, err
		}
		r.Type = RegionType(rType)
		nodes[r.ID] = &RegionNode{Region: r}
	}

	var roots []*RegionNode
	for _, node := range nodes {
		if node.ParentID == nil {
			if rootID == nil || node.ID == *rootID {
				roots = append(roots, node)
			}
		} else {
			parent, exists := nodes[*node.ParentID]
			if exists {
				parent.Children = append(parent.Children, node)
			}
		}
	}

	if rootID != nil && len(roots) == 0 {
		if specificNode, exists := nodes[*rootID]; exists {
			return []*RegionNode{specificNode}, nil
		}
	}

	return roots, nil
}

func (s *PostgresStore) IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error) {
	if rtID == regionID {
		return true, nil
	}

	query := `
		WITH RECURSIVE ancestors AS (
			SELECT id, parent_id FROM regions WHERE id = $1
			UNION ALL
			SELECT r.id, r.parent_id FROM regions r
			JOIN ancestors a ON r.id = a.parent_id
		)
		SELECT EXISTS (SELECT 1 FROM ancestors WHERE id = $2);
	`
	var exists bool
	err := s.pool.QueryRow(ctx, query, rtID, regionID).Scan(&exists)
	return exists, err
}

func (s *PostgresStore) ListAccessibleRTs(ctx context.Context, role Role, userRegionID string) ([]*Region, error) {
	if role == RoleOperator {
		return s.ListRegions(ctx, TypeRT, nil)
	}

	if role == RolePengurus || role == RoleRelawan || role == RoleKepalaKeluarga {
		r, err := s.GetRegionByID(ctx, userRegionID)
		if err != nil {
			return nil, err
		}
		if r.Type == TypeRT {
			return []*Region{r}, nil
		}
		return []*Region{}, nil
	}

	if role == RoleAdminWilayah {
		query := `
			WITH RECURSIVE descendants AS (
				SELECT id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at
				FROM regions WHERE id = $1
				UNION ALL
				SELECT r.id, r.type, r.parent_id, r.name, r.code, r.centroid_lat, r.centroid_lon, r.ai_enabled, r.created_at
				FROM regions r JOIN descendants d ON r.parent_id = d.id
			)
			SELECT id, type, parent_id, name, code, centroid_lat, centroid_lon, ai_enabled, created_at
			FROM descendants WHERE type = 'rt' ORDER BY name ASC;
		`
		rows, err := s.pool.Query(ctx, query, userRegionID)
		if err != nil {
			return nil, err
		}
		defer rows.Close()

		var result []*Region
		for rows.Next() {
			var r Region
			var rType string
			if err := rows.Scan(&r.ID, &rType, &r.ParentID, &r.Name, &r.Code, &r.CentroidLat, &r.CentroidLon, &r.AIEnabled, &r.CreatedAt); err != nil {
				return nil, err
			}
			r.Type = RegionType(rType)
			result = append(result, &r)
		}
		return result, rows.Err()
	}

	return []*Region{}, nil
}

func (s *PostgresStore) AddMembership(ctx context.Context, m *Membership) error {
	query := `INSERT INTO memberships (id, user_id, region_id, role, household_id, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6)`
	_, err := s.pool.Exec(ctx, query, m.ID, m.UserID, m.RegionID, string(m.Role), m.HouseholdID, m.CreatedAt)
	return err
}

func (s *PostgresStore) ListMembershipsByRegion(ctx context.Context, regionID string) ([]*Membership, error) {
	query := `SELECT m.id, m.user_id, m.region_id, m.role, m.household_id, m.created_at,
	                 COALESCE(u.name, ''), COALESCE(u.phone, ''), COALESCE(u.email, '')
	          FROM memberships m
	          LEFT JOIN users u ON m.user_id = u.id
	          WHERE m.region_id = $1
	          ORDER BY m.created_at ASC`
	rows, err := s.pool.Query(ctx, query, regionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*Membership
	for rows.Next() {
		var m Membership
		var roleStr string
		if err := rows.Scan(
			&m.ID, &m.UserID, &m.RegionID, &roleStr, &m.HouseholdID, &m.CreatedAt,
			&m.UserName, &m.UserPhone, &m.UserEmail,
		); err != nil {
			return nil, err
		}
		m.Role = Role(roleStr)
		list = append(list, &m)
	}
	return list, rows.Err()
}

func (s *PostgresStore) GetRegionAggregate(ctx context.Context, regionID string) (*AggregateMetrics, error) {
	target, err := s.GetRegionByID(ctx, regionID)
	if err != nil {
		return nil, err
	}

	// Count RTs
	rts, err := s.ListAccessibleRTs(ctx, RoleAdminWilayah, regionID)
	totalRTs := len(rts)
	if target.Type == TypeRT {
		totalRTs = 1
	}

	return &AggregateMetrics{
		RegionID:        regionID,
		RegionName:      target.Name,
		TotalRTs:        totalRTs,
		ActiveIncidents: 0,
		HouseholdsByStatus: map[string]int{
			"aman":           0,
			"titik_kumpul":   0,
			"butuh_bantuan":  0,
			"kritis":         0,
			"belum_melapor":  0,
		},
		VulnerableUnreached: 0,
	}, nil
}

func (s *PostgresStore) SetAIEnabled(ctx context.Context, regionID string, enabled bool) error {
	query := `UPDATE regions SET ai_enabled = $1 WHERE id = $2`
	tag, err := s.pool.Exec(ctx, query, enabled, regionID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrRegionNotFound
	}
	return nil
}

