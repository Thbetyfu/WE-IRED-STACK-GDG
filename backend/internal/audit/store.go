package audit

import (
	"context"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
)

type Store interface {
	Record(ctx context.Context, l *AuditLog) error
	ListByRegion(ctx context.Context, regionID string, limit, offset int) ([]*AuditLog, int, error)
}

type MemoryStore struct {
	mu   sync.RWMutex
	logs []*AuditLog
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		logs: make([]*AuditLog, 0),
	}
}

func (s *MemoryStore) Record(ctx context.Context, l *AuditLog) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if l.ID == "" {
		l.ID = uuid.NewString()
	}
	if l.CreatedAt.IsZero() {
		l.CreatedAt = time.Now().UTC()
	}

	copyLog := *l
	s.logs = append(s.logs, &copyLog)
	return nil
}

func (s *MemoryStore) ListByRegion(ctx context.Context, regionID string, limit, offset int) ([]*AuditLog, int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var filtered []*AuditLog
	for _, l := range s.logs {
		if regionID == "" || l.RegionID == regionID {
			copyLog := *l
			filtered = append(filtered, &copyLog)
		}
	}

	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].CreatedAt.After(filtered[j].CreatedAt)
	})

	total := len(filtered)
	if offset >= total {
		return []*AuditLog{}, total, nil
	}

	end := offset + limit
	if limit <= 0 || end > total {
		end = total
	}

	return filtered[offset:end], total, nil
}
