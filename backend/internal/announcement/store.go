package announcement

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"
)

var (
	ErrAnnouncementNotFound = errors.New("pengumuman tidak ditemukan")
)

type Store interface {
	CreateAnnouncement(ctx context.Context, a *Announcement) error
	GetAnnouncement(ctx context.Context, id string) (*Announcement, error)
	ListActiveAnnouncementsByRT(ctx context.Context, rtID string, now time.Time) ([]*Announcement, error)
	ListAllAnnouncementsByRT(ctx context.Context, rtID string) ([]*Announcement, error)
	GetLatestSignedPacketByRT(ctx context.Context, rtID string, now time.Time) ([]byte, error)

	SavePoskoDelegation(ctx context.Context, del *PoskoDelegation) error
	GetPoskoDelegation(ctx context.Context, poskoID string) (*PoskoDelegation, error)
}

type MemoryStore struct {
	mu            sync.RWMutex
	announcements map[string]*Announcement
	delegations   map[string]*PoskoDelegation
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		announcements: make(map[string]*Announcement),
		delegations:   make(map[string]*PoskoDelegation),
	}
}

func (s *MemoryStore) CreateAnnouncement(ctx context.Context, a *Announcement) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if a.CreatedAt.IsZero() {
		a.CreatedAt = time.Now().UTC()
	}

	copyA := *a
	s.announcements[a.ID] = &copyA
	return nil
}

func (s *MemoryStore) GetAnnouncement(ctx context.Context, id string) (*Announcement, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	a, exists := s.announcements[id]
	if !exists {
		return nil, ErrAnnouncementNotFound
	}
	copyA := *a
	return &copyA, nil
}

// ListActiveAnnouncementsByRT returns non-expired announcements for the specified RT,
// with emergency level ordered first (FR-ANN-03).
func (s *MemoryStore) ListActiveAnnouncementsByRT(ctx context.Context, rtID string, now time.Time) ([]*Announcement, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if now.IsZero() {
		now = time.Now().UTC()
	}

	var active []*Announcement
	for _, a := range s.announcements {
		// Filter by RT scope
		inScope := false
		if len(a.RegionIDs) == 0 {
			inScope = true
		} else {
			for _, r := range a.RegionIDs {
				if r == rtID {
					inScope = true
					break
				}
			}
		}

		if inScope && !a.IsExpired(now) {
			copyA := *a
			active = append(active, &copyA)
		}
	}

	// Order: Darurat first, then latest CreatedAt
	sort.Slice(active, func(i, j int) bool {
		iDarurat := active[i].Level == LevelNameDarurat
		jDarurat := active[j].Level == LevelNameDarurat
		if iDarurat && !jDarurat {
			return true
		}
		if !iDarurat && jDarurat {
			return false
		}
		return active[i].CreatedAt.After(active[j].CreatedAt)
	})

	return active, nil
}

func (s *MemoryStore) ListAllAnnouncementsByRT(ctx context.Context, rtID string) ([]*Announcement, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var list []*Announcement
	for _, a := range s.announcements {
		inScope := false
		if len(a.RegionIDs) == 0 {
			inScope = true
		} else {
			for _, r := range a.RegionIDs {
				if r == rtID {
					inScope = true
					break
				}
			}
		}

		if inScope {
			copyA := *a
			list = append(list, &copyA)
		}
	}

	sort.Slice(list, func(i, j int) bool {
		return list[i].CreatedAt.After(list[j].CreatedAt)
	})

	return list, nil
}

func (s *MemoryStore) GetLatestSignedPacketByRT(ctx context.Context, rtID string, now time.Time) ([]byte, error) {
	active, err := s.ListActiveAnnouncementsByRT(ctx, rtID, now)
	if err != nil {
		return nil, err
	}
	if len(active) == 0 {
		return nil, ErrAnnouncementNotFound
	}
	return active[0].PayloadRaw, nil
}

func (s *MemoryStore) SavePoskoDelegation(ctx context.Context, del *PoskoDelegation) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	copyDel := *del
	s.delegations[del.PoskoID] = &copyDel
	return nil
}

func (s *MemoryStore) GetPoskoDelegation(ctx context.Context, poskoID string) (*PoskoDelegation, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	del, exists := s.delegations[poskoID]
	if !exists {
		return nil, ErrInvalidDelegation
	}
	copyDel := *del
	return &copyDel, nil
}
