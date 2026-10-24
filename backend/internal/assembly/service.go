package assembly

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	ErrInvalidAssemblyData = errors.New("data titik kumpul tidak valid")
)

type Service struct {
	store Store
}

func NewService(store Store) *Service {
	return &Service{store: store}
}

// CreateAssemblyPoint registers a new assembly point with facilities per FR-AP-01.
func (s *Service) CreateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) (*AssemblyPoint, error) {
	ap.Name = strings.TrimSpace(ap.Name)
	if ap.Name == "" {
		return nil, fmt.Errorf("%w: nama titik kumpul wajib diisi", ErrInvalidAssemblyData)
	}

	if ap.Capacity <= 0 {
		return nil, ErrInvalidCapacity
	}

	if ap.ID == "" {
		ap.ID = uuid.NewString()
	}
	ap.IsActive = true
	ap.CreatedAt = time.Now().UTC()

	if err := s.store.CreateAssemblyPoint(ctx, ap); err != nil {
		return nil, err
	}

	return ap, nil
}

func (s *Service) GetAssemblyPoint(ctx context.Context, id string) (*AssemblyPoint, error) {
	return s.store.GetAssemblyPoint(ctx, id)
}

func (s *Service) UpdateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error {
	ap.Name = strings.TrimSpace(ap.Name)
	if ap.Name == "" {
		return fmt.Errorf("%w: nama titik kumpul wajib diisi", ErrInvalidAssemblyData)
	}
	if ap.Capacity <= 0 {
		return ErrInvalidCapacity
	}
	return s.store.UpdateAssemblyPoint(ctx, ap)
}

func (s *Service) DeleteAssemblyPoint(ctx context.Context, id string) error {
	return s.store.DeleteAssemblyPoint(ctx, id)
}

func (s *Service) ListAssemblyPoints(ctx context.Context, rtID string, activeOnly bool) ([]*AssemblyPoint, error) {
	return s.store.ListAssemblyPointsByRT(ctx, rtID, activeOnly)
}

// MapBlockAssemblyPoints assigns primary (rank 1) and secondary (rank 2) assembly points for a block (FR-AP-02).
func (s *Service) MapBlockAssemblyPoints(ctx context.Context, blockID, primaryAPID, secondaryAPID string) error {
	if primaryAPID == secondaryAPID {
		return ErrSameAssemblyPoint
	}

	// Verify both assembly points exist and are active
	primary, err := s.store.GetAssemblyPoint(ctx, primaryAPID)
	if err != nil || !primary.IsActive {
		return fmt.Errorf("%w: titik kumpul utama tidak valid", ErrInactiveAssemblyPoint)
	}

	secondary, err := s.store.GetAssemblyPoint(ctx, secondaryAPID)
	if err != nil || !secondary.IsActive {
		return fmt.Errorf("%w: titik kumpul cadangan tidak valid", ErrInactiveAssemblyPoint)
	}

	return s.store.SetBlockAssemblyPoints(ctx, blockID, primaryAPID, secondaryAPID)
}

func (s *Service) GetBlockAssemblyPoints(ctx context.Context, blockID string) ([]*BlockAssemblyPoint, error) {
	return s.store.GetBlockAssemblyPoints(ctx, blockID)
}
