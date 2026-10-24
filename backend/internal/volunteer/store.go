package volunteer

import (
	"context"
	"errors"
	"sync"
	"time"
)

var (
	ErrBlockNotFound     = errors.New("data blok tidak ditemukan")
	ErrVolunteerNotFound = errors.New("data relawan tidak ditemukan")
	ErrDuplicateBlock    = errors.New("nama blok sudah ada di RT ini")
)

type Store interface {
	CreateBlock(ctx context.Context, b *Block) error
	GetBlock(ctx context.Context, id string) (*Block, error)
	ListBlocksByRT(ctx context.Context, rtID string) ([]*Block, error)
	DeleteBlock(ctx context.Context, id string) error

	CreateVolunteer(ctx context.Context, v *Volunteer) error
	GetVolunteer(ctx context.Context, userID string) (*Volunteer, error)
	UpdateVolunteer(ctx context.Context, v *Volunteer) error
	SetVolunteerAvailability(ctx context.Context, userID string, available bool) error
	ListVolunteersByRT(ctx context.Context, rtID string) ([]*Volunteer, error)

	AssignBlocksToVolunteer(ctx context.Context, userID string, blockIDs []string) error
	GetVolunteerBlocks(ctx context.Context, userID string) ([]string, error)
}

type MemoryStore struct {
	mu         sync.RWMutex
	blocks     map[string]*Block
	volunteers map[string]*Volunteer
	volBlocks  map[string][]string // userID -> []blockID
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		blocks:     make(map[string]*Block),
		volunteers: make(map[string]*Volunteer),
		volBlocks:  make(map[string][]string),
	}
}

func (s *MemoryStore) CreateBlock(ctx context.Context, b *Block) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, existing := range s.blocks {
		if existing.RTID == b.RTID && existing.Name == b.Name {
			return ErrDuplicateBlock
		}
	}

	if b.CreatedAt.IsZero() {
		b.CreatedAt = time.Now().UTC()
	}

	s.blocks[b.ID] = b
	return nil
}

func (s *MemoryStore) GetBlock(ctx context.Context, id string) (*Block, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	b, ok := s.blocks[id]
	if !ok {
		return nil, ErrBlockNotFound
	}
	copied := *b
	return &copied, nil
}

func (s *MemoryStore) ListBlocksByRT(ctx context.Context, rtID string) ([]*Block, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Block
	for _, b := range s.blocks {
		if b.RTID == rtID {
			copied := *b
			result = append(result, &copied)
		}
	}
	return result, nil
}

func (s *MemoryStore) DeleteBlock(ctx context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.blocks[id]; !ok {
		return ErrBlockNotFound
	}

	delete(s.blocks, id)
	return nil
}

func (s *MemoryStore) CreateVolunteer(ctx context.Context, v *Volunteer) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if v.CreatedAt.IsZero() {
		v.CreatedAt = time.Now().UTC()
	}

	s.volunteers[v.UserID] = v
	return nil
}

func (s *MemoryStore) GetVolunteer(ctx context.Context, userID string) (*Volunteer, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	v, ok := s.volunteers[userID]
	if !ok {
		return nil, ErrVolunteerNotFound
	}
	copied := *v
	copied.AssignedBlocks = s.volBlocks[userID]
	return &copied, nil
}

func (s *MemoryStore) UpdateVolunteer(ctx context.Context, v *Volunteer) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.volunteers[v.UserID]; !ok {
		return ErrVolunteerNotFound
	}

	s.volunteers[v.UserID] = v
	return nil
}

func (s *MemoryStore) SetVolunteerAvailability(ctx context.Context, userID string, available bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	v, ok := s.volunteers[userID]
	if !ok {
		return ErrVolunteerNotFound
	}

	v.Available = available
	return nil
}

func (s *MemoryStore) ListVolunteersByRT(ctx context.Context, rtID string) ([]*Volunteer, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Volunteer
	for _, v := range s.volunteers {
		if v.RTID == rtID {
			copied := *v
			copied.AssignedBlocks = s.volBlocks[v.UserID]
			result = append(result, &copied)
		}
	}
	return result, nil
}

func (s *MemoryStore) AssignBlocksToVolunteer(ctx context.Context, userID string, blockIDs []string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.volunteers[userID]; !ok {
		return ErrVolunteerNotFound
	}

	s.volBlocks[userID] = append([]string(nil), blockIDs...)
	return nil
}

func (s *MemoryStore) GetVolunteerBlocks(ctx context.Context, userID string) ([]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	blocks, ok := s.volBlocks[userID]
	if !ok {
		return []string{}, nil
	}
	res := make([]string, len(blocks))
	copy(res, blocks)
	return res, nil
}
