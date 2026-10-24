package region

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	ErrUnauthorizedAction   = errors.New("peran Anda tidak memiliki hak untuk melakukan aksi ini")
	ErrInvalidRegionType    = errors.New("tipe wilayah harus 'kelurahan', 'rw', atau 'rt'")
	ErrKelurahanParentSet   = errors.New("kelurahan adalah tingkat tertinggi dan tidak boleh memiliki induk")
	ErrRWParentMustBeKel    = errors.New("induk dari RW harus berupa kelurahan")
	ErrRTParentMustBeRW     = errors.New("induk dari RT harus berupa RW")
	ErrParentRequired       = errors.New("induk wilayah (parent_id) wajib ditentukan")
	ErrInvalidCoordinate    = errors.New("koordinat centroid tidak valid")
)

type Service struct {
	store Store
}

func NewService(store Store) *Service {
	return &Service{store: store}
}

// CreateRegion creates a new administrative region ensuring strict hierarchy constraints (FR-MRT-01, FR-MRT-02).
// Kelurahan -> RW -> RT.
func (s *Service) CreateRegion(ctx context.Context, r *Region, actorRole Role) (*Region, error) {
	// FR-MRT-02: Operator harus dapat membuat wilayah
	if actorRole != RoleOperator {
		return nil, ErrUnauthorizedAction
	}

	r.Name = strings.TrimSpace(r.Name)
	r.Code = strings.TrimSpace(r.Code)
	if r.Name == "" || r.Code == "" {
		return nil, errors.New("nama dan kode wilayah wajib diisi")
	}

	if r.ID == "" {
		r.ID = uuid.NewString()
	}
	r.CreatedAt = time.Now().UTC()

	// Validate hierarchy rules
	switch r.Type {
	case TypeKelurahan:
		if r.ParentID != nil && *r.ParentID != "" {
			return nil, ErrKelurahanParentSet
		}
		r.ParentID = nil

	case TypeRW:
		if r.ParentID == nil || *r.ParentID == "" {
			return nil, ErrParentRequired
		}
		parent, err := s.store.GetRegionByID(ctx, *r.ParentID)
		if err != nil {
			return nil, fmt.Errorf("induk kelurahan tidak ditemukan: %w", err)
		}
		if parent.Type != TypeKelurahan {
			return nil, ErrRWParentMustBeKel
		}

	case TypeRT:
		if r.ParentID == nil || *r.ParentID == "" {
			return nil, ErrParentRequired
		}
		parent, err := s.store.GetRegionByID(ctx, *r.ParentID)
		if err != nil {
			return nil, fmt.Errorf("induk RW tidak ditemukan: %w", err)
		}
		if parent.Type != TypeRW {
			return nil, ErrRTParentMustBeRW
		}

	default:
		return nil, ErrInvalidRegionType
	}

	if err := s.store.CreateRegion(ctx, r); err != nil {
		return nil, err
	}

	return r, nil
}

func (s *Service) GetRegion(ctx context.Context, id string) (*Region, error) {
	return s.store.GetRegionByID(ctx, id)
}

func (s *Service) ListRegions(ctx context.Context, regionType RegionType, parentID *string) ([]*Region, error) {
	return s.store.ListRegions(ctx, regionType, parentID)
}

func (s *Service) GetHierarchy(ctx context.Context, rootID *string) ([]*RegionNode, error) {
	return s.store.GetHierarchy(ctx, rootID)
}

// IsRTInRegion verifies if an RT belongs to an administrative parent region (RW/Kelurahan).
// Satisfies auth.RegionHierarchyChecker interface.
func (s *Service) IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error) {
	return s.store.IsRTInRegion(ctx, rtID, regionID)
}

// ListAccessibleRTs returns the list of RTs the user has authorization to view/manage.
func (s *Service) ListAccessibleRTs(ctx context.Context, actorRole Role, userRegionID string) ([]*Region, error) {
	return s.store.ListAccessibleRTs(ctx, actorRole, userRegionID)
}

// AssignMembership appoints a user to a role in a region (FR-MRT-02).
func (s *Service) AssignMembership(ctx context.Context, m *Membership, actorRole Role, actorRegionID string) error {
	// Verify target region exists
	targetRegion, err := s.store.GetRegionByID(ctx, m.RegionID)
	if err != nil {
		return err
	}

	// Permission checks
	switch actorRole {
	case RoleOperator:
		// Operator can appoint any role
	case RoleAdminWilayah:
		// Admin Wilayah can appoint pengurus or relawan within their territory
		inScope, err := s.store.IsRTInRegion(ctx, m.RegionID, actorRegionID)
		if err != nil || !inScope {
			return ErrUnauthorizedAction
		}
		if m.Role != RolePengurus && m.Role != RoleRelawan {
			return ErrUnauthorizedAction
		}
	case RolePengurus:
		// Pengurus can appoint relawan or warga in their own RT
		if m.RegionID != actorRegionID {
			return ErrUnauthorizedAction
		}
		if m.Role != RoleRelawan && m.Role != RoleKepalaKeluarga {
			return ErrUnauthorizedAction
		}
	default:
		return ErrUnauthorizedAction
	}

	// Validate role against target region level
	if m.Role == RoleAdminWilayah && targetRegion.Type == TypeRT {
		return errors.New("admin wilayah harus ditugaskan pada tingkat Kelurahan atau RW")
	}
	if (m.Role == RolePengurus || m.Role == RoleRelawan || m.Role == RoleKepalaKeluarga) && targetRegion.Type != TypeRT {
		return errors.New("pengurus, relawan, dan kepala keluarga harus ditugaskan pada tingkat RT")
	}

	if m.ID == "" {
		m.ID = uuid.NewString()
	}
	m.CreatedAt = time.Now().UTC()

	return s.store.AddMembership(ctx, m)
}

func (s *Service) ListMemberships(ctx context.Context, regionID string) ([]*Membership, error) {
	return s.store.ListMembershipsByRegion(ctx, regionID)
}

func (s *Service) GetRegionAggregate(ctx context.Context, regionID string, actorRole Role, actorRegionID string) (*AggregateMetrics, error) {
	// Verify authorization
	if actorRole != RoleOperator {
		if actorRole == RoleAdminWilayah {
			inScope, err := s.store.IsRTInRegion(ctx, regionID, actorRegionID)
			if err != nil || (!inScope && regionID != actorRegionID) {
				return nil, ErrUnauthorizedAction
			}
		} else if actorRegionID != regionID {
			return nil, ErrUnauthorizedAction
		}
	}

	return s.store.GetRegionAggregate(ctx, regionID)
}

func (s *Service) SetAIEnabled(ctx context.Context, regionID string, enabled bool) error {
	return s.store.SetAIEnabled(ctx, regionID, enabled)
}

func (s *Service) IsAIEnabled(ctx context.Context, regionID string) (bool, error) {
	r, err := s.store.GetRegionByID(ctx, regionID)
	if err != nil {
		return false, err
	}
	return r.AIEnabled, nil
}

