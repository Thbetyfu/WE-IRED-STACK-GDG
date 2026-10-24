package recap

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

var (
	ErrRecapNotFound = errors.New("rekap insiden tidak ditemukan")
)

type Store interface {
	SaveRecap(ctx context.Context, r *Recap) error
	GetRecap(ctx context.Context, id string) (*Recap, error)
	GetRecapByIncidentID(ctx context.Context, incidentID string) (*Recap, error)
	UpdateRecap(ctx context.Context, r *Recap) error
}

type MemoryStore struct {
	mu           sync.RWMutex
	recaps       map[string]*Recap // id -> Recap
	byIncidentID map[string]string // incidentID -> id
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		recaps:       make(map[string]*Recap),
		byIncidentID: make(map[string]string),
	}
}

func (s *MemoryStore) SaveRecap(ctx context.Context, r *Recap) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if r.ID == "" {
		r.ID = uuid.NewString()
	}
	if r.CreatedAt.IsZero() {
		r.CreatedAt = time.Now().UTC()
	}
	r.UpdatedAt = r.CreatedAt

	copyR := *r
	s.recaps[r.ID] = &copyR
	s.byIncidentID[r.IncidentID] = r.ID
	return nil
}

func (s *MemoryStore) GetRecap(ctx context.Context, id string) (*Recap, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	r, exists := s.recaps[id]
	if !exists {
		return nil, ErrRecapNotFound
	}
	copyR := *r
	return &copyR, nil
}

func (s *MemoryStore) GetRecapByIncidentID(ctx context.Context, incidentID string) (*Recap, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id, exists := s.byIncidentID[incidentID]
	if !exists {
		return nil, ErrRecapNotFound
	}
	return s.GetRecap(ctx, id)
}

func (s *MemoryStore) UpdateRecap(ctx context.Context, r *Recap) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.recaps[r.ID]; !exists {
		return ErrRecapNotFound
	}

	r.UpdatedAt = time.Now().UTC()
	copyR := *r
	s.recaps[r.ID] = &copyR
	return nil
}
