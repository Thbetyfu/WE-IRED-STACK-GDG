package posko

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"
)

var (
	ErrConflictNotFound = errors.New("konflik sinkronisasi tidak ditemukan")
)

type Store interface {
	RecordConflict(ctx context.Context, c *SyncConflict) error
	ListConflicts(ctx context.Context, regionID string, status string) ([]*SyncConflict, error)
	GetConflict(ctx context.Context, id string) (*SyncConflict, error)
	ResolveConflict(ctx context.Context, id string, resolvedBy string) error

	GetSyncCursor(ctx context.Context, poskoID string) (int64, error)
	UpdateSyncCursor(ctx context.Context, poskoID string, cursor int64) error
}

type MemoryStore struct {
	mu        sync.RWMutex
	conflicts map[string]*SyncConflict
	cursors   map[string]int64
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		conflicts: make(map[string]*SyncConflict),
		cursors:   make(map[string]int64),
	}
}

func (s *MemoryStore) RecordConflict(ctx context.Context, c *SyncConflict) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if c.CreatedAt.IsZero() {
		c.CreatedAt = time.Now().UTC()
	}

	copyC := *c
	s.conflicts[c.ID] = &copyC
	return nil
}

func (s *MemoryStore) ListConflicts(ctx context.Context, regionID string, status string) ([]*SyncConflict, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*SyncConflict
	for _, c := range s.conflicts {
		if regionID != "" && c.RegionID != regionID {
			continue
		}
		if status != "" && c.Status != status {
			continue
		}
		copyC := *c
		list = append(list, &copyC)
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})

	return list, nil
}

func (s *MemoryStore) GetConflict(ctx context.Context, id string) (*SyncConflict, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	c, exists := s.conflicts[id]
	if !exists {
		return nil, ErrConflictNotFound
	}
	copyC := *c
	return &copyC, nil
}

func (s *MemoryStore) ResolveConflict(ctx context.Context, id string, resolvedBy string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	c, exists := s.conflicts[id]
	if !exists {
		return ErrConflictNotFound
	}

	now := time.Now().UTC()
	c.Status = "resolved"
	c.ResolvedBy = &resolvedBy
	c.ResolvedAt = &now
	return nil
}

func (s *MemoryStore) GetSyncCursor(ctx context.Context, poskoID string) (int64, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.cursors[poskoID], nil
}

func (s *MemoryStore) UpdateSyncCursor(ctx context.Context, poskoID string, cursor int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cursors[poskoID] = cursor
	return nil
}
