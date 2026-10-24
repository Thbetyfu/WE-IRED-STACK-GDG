package assembly

import (
	"context"
	"errors"
	"sync"
	"time"
)

var (
	ErrAssemblyPointNotFound = errors.New("titik kumpul tidak ditemukan")
	ErrInvalidCapacity       = errors.New("kapasitas titik kumpul harus lebih besar dari 0")
	ErrSameAssemblyPoint     = errors.New("titik kumpul utama dan cadangan tidak boleh sama")
	ErrInactiveAssemblyPoint = errors.New("titik kumpul tidak aktif atau tidak valid")
)

type Store interface {
	CreateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error
	GetAssemblyPoint(ctx context.Context, id string) (*AssemblyPoint, error)
	UpdateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error
	DeleteAssemblyPoint(ctx context.Context, id string) error
	ListAssemblyPointsByRT(ctx context.Context, rtID string, activeOnly bool) ([]*AssemblyPoint, error)

	SetBlockAssemblyPoints(ctx context.Context, blockID, primaryAPID, secondaryAPID string) error
	GetBlockAssemblyPoints(ctx context.Context, blockID string) ([]*BlockAssemblyPoint, error)
}

type MemoryStore struct {
	mu             sync.RWMutex
	assemblyPoints map[string]*AssemblyPoint
	blockMappings  map[string][]*BlockAssemblyPoint // blockID -> []BlockAssemblyPoint
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		assemblyPoints: make(map[string]*AssemblyPoint),
		blockMappings:  make(map[string][]*BlockAssemblyPoint),
	}
}

func (s *MemoryStore) CreateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if ap.Capacity <= 0 {
		return ErrInvalidCapacity
	}

	if ap.CreatedAt.IsZero() {
		ap.CreatedAt = time.Now().UTC()
	}

	s.assemblyPoints[ap.ID] = ap
	return nil
}

func (s *MemoryStore) GetAssemblyPoint(ctx context.Context, id string) (*AssemblyPoint, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	ap, ok := s.assemblyPoints[id]
	if !ok {
		return nil, ErrAssemblyPointNotFound
	}
	copied := *ap
	return &copied, nil
}

func (s *MemoryStore) UpdateAssemblyPoint(ctx context.Context, ap *AssemblyPoint) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.assemblyPoints[ap.ID]; !ok {
		return ErrAssemblyPointNotFound
	}

	if ap.Capacity <= 0 {
		return ErrInvalidCapacity
	}

	s.assemblyPoints[ap.ID] = ap
	return nil
}

func (s *MemoryStore) DeleteAssemblyPoint(ctx context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.assemblyPoints[id]; !ok {
		return ErrAssemblyPointNotFound
	}

	delete(s.assemblyPoints, id)
	return nil
}

func (s *MemoryStore) ListAssemblyPointsByRT(ctx context.Context, rtID string, activeOnly bool) ([]*AssemblyPoint, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*AssemblyPoint
	for _, ap := range s.assemblyPoints {
		if ap.RTID != rtID {
			continue
		}
		if activeOnly && !ap.IsActive {
			continue
		}
		copied := *ap
		result = append(result, &copied)
	}
	return result, nil
}

func (s *MemoryStore) SetBlockAssemblyPoints(ctx context.Context, blockID, primaryAPID, secondaryAPID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if primaryAPID == secondaryAPID {
		return ErrSameAssemblyPoint
	}

	primary, ok := s.assemblyPoints[primaryAPID]
	if !ok || !primary.IsActive {
		return ErrInactiveAssemblyPoint
	}

	secondary, ok := s.assemblyPoints[secondaryAPID]
	if !ok || !secondary.IsActive {
		return ErrInactiveAssemblyPoint
	}

	s.blockMappings[blockID] = []*BlockAssemblyPoint{
		{
			BlockID:         blockID,
			AssemblyPointID: primaryAPID,
			Rank:            1,
			APName:          primary.Name,
		},
		{
			BlockID:         blockID,
			AssemblyPointID: secondaryAPID,
			Rank:            2,
			APName:          secondary.Name,
		},
	}

	return nil
}

func (s *MemoryStore) GetBlockAssemblyPoints(ctx context.Context, blockID string) ([]*BlockAssemblyPoint, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	list, ok := s.blockMappings[blockID]
	if !ok {
		return []*BlockAssemblyPoint{}, nil
	}

	result := make([]*BlockAssemblyPoint, len(list))
	for i, item := range list {
		copied := *item
		result[i] = &copied
	}
	return result, nil
}
