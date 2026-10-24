package region

import (
	"context"
	"errors"
	"sync"
	"time"
)

var (
	ErrRegionNotFound     = errors.New("wilayah tidak ditemukan")
	ErrInvalidParent      = errors.New("hierarki induk wilayah tidak valid")
	ErrDuplicateCode      = errors.New("kode wilayah sudah terdaftar")
	ErrMembershipNotFound = errors.New("keanggotaan peran tidak ditemukan")
)

type Store interface {
	CreateRegion(ctx context.Context, r *Region) error
	GetRegionByID(ctx context.Context, id string) (*Region, error)
	GetRegionByCode(ctx context.Context, code string) (*Region, error)
	ListRegions(ctx context.Context, regionType RegionType, parentID *string) ([]*Region, error)
	GetHierarchy(ctx context.Context, rootID *string) ([]*RegionNode, error)
	IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error)
	ListAccessibleRTs(ctx context.Context, role Role, userRegionID string) ([]*Region, error)

	AddMembership(ctx context.Context, m *Membership) error
	ListMembershipsByRegion(ctx context.Context, regionID string) ([]*Membership, error)
	GetRegionAggregate(ctx context.Context, regionID string) (*AggregateMetrics, error)
	SetAIEnabled(ctx context.Context, regionID string, enabled bool) error
}

// MemoryStore provides in-memory region storage for testing and standalone/Posko execution.
type MemoryStore struct {
	mu          sync.RWMutex
	regions     map[string]*Region
	regionsCode map[string]string // code -> id
	memberships map[string][]*Membership
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		regions:     make(map[string]*Region),
		regionsCode: make(map[string]string),
		memberships: make(map[string][]*Membership),
	}
}

func (s *MemoryStore) CreateRegion(ctx context.Context, r *Region) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.regionsCode[r.Code]; exists {
		return ErrDuplicateCode
	}

	if r.CreatedAt.IsZero() {
		r.CreatedAt = time.Now().UTC()
	}

	s.regions[r.ID] = r
	s.regionsCode[r.Code] = r.ID
	return nil
}

func (s *MemoryStore) GetRegionByID(ctx context.Context, id string) (*Region, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	r, exists := s.regions[id]
	if !exists {
		return nil, ErrRegionNotFound
	}
	return r, nil
}

func (s *MemoryStore) GetRegionByCode(ctx context.Context, code string) (*Region, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id, exists := s.regionsCode[code]
	if !exists {
		return nil, ErrRegionNotFound
	}
	return s.regions[id], nil
}

func (s *MemoryStore) ListRegions(ctx context.Context, regionType RegionType, parentID *string) ([]*Region, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Region
	for _, r := range s.regions {
		if regionType != "" && r.Type != regionType {
			continue
		}
		if parentID != nil {
			if r.ParentID == nil || *r.ParentID != *parentID {
				continue
			}
		}
		result = append(result, r)
	}
	return result, nil
}

func (s *MemoryStore) GetHierarchy(ctx context.Context, rootID *string) ([]*RegionNode, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Build nodes map
	nodes := make(map[string]*RegionNode, len(s.regions))
	for id, r := range s.regions {
		nodes[id] = &RegionNode{Region: *r}
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

func (s *MemoryStore) IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if rtID == regionID {
		return true, nil
	}

	curr, exists := s.regions[rtID]
	if !exists {
		return false, ErrRegionNotFound
	}

	// Traverse up the parent hierarchy
	for curr.ParentID != nil {
		parentID := *curr.ParentID
		if parentID == regionID {
			return true, nil
		}
		parent, ok := s.regions[parentID]
		if !ok {
			break
		}
		curr = parent
	}

	return false, nil
}

func (s *MemoryStore) ListAccessibleRTs(ctx context.Context, role Role, userRegionID string) ([]*Region, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var rts []*Region
	for _, r := range s.regions {
		if r.Type != TypeRT {
			continue
		}

		if role == RoleOperator {
			rts = append(rts, r)
			continue
		}

		// Direct match
		if r.ID == userRegionID {
			rts = append(rts, r)
			continue
		}

		// Hierarchy match for admin_wilayah
		if role == RoleAdminWilayah {
			curr := r
			matched := false
			for curr.ParentID != nil {
				if *curr.ParentID == userRegionID {
					matched = true
					break
				}
				parent, ok := s.regions[*curr.ParentID]
				if !ok {
					break
				}
				curr = parent
			}
			if matched {
				rts = append(rts, r)
			}
		}
	}

	return rts, nil
}

func (s *MemoryStore) AddMembership(ctx context.Context, m *Membership) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if m.CreatedAt.IsZero() {
		m.CreatedAt = time.Now().UTC()
	}

	s.memberships[m.RegionID] = append(s.memberships[m.RegionID], m)
	return nil
}

func (s *MemoryStore) ListMembershipsByRegion(ctx context.Context, regionID string) ([]*Membership, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	list := s.memberships[regionID]
	result := make([]*Membership, len(list))
	copy(result, list)
	return result, nil
}

func (s *MemoryStore) GetRegionAggregate(ctx context.Context, regionID string) (*AggregateMetrics, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	target, exists := s.regions[regionID]
	if !exists {
		return nil, ErrRegionNotFound
	}

	// Count RTs under this region
	totalRTs := 0
	for _, r := range s.regions {
		if r.Type == TypeRT {
			if r.ID == regionID {
				totalRTs++
				continue
			}
			curr := r
			for curr.ParentID != nil {
				if *curr.ParentID == regionID {
					totalRTs++
					break
				}
				parent, ok := s.regions[*curr.ParentID]
				if !ok {
					break
				}
				curr = parent
			}
		}
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

func (s *MemoryStore) SetAIEnabled(ctx context.Context, regionID string, enabled bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	r, exists := s.regions[regionID]
	if !exists {
		return ErrRegionNotFound
	}
	r.AIEnabled = enabled
	return nil
}

