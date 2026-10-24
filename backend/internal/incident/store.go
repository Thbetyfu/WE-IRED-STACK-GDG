package incident

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"
)

var (
	ErrIncidentNotFound                = errors.New("insiden tidak ditemukan")
	ErrActiveRealIncidentExists        = errors.New("hanya satu insiden nyata yang boleh aktif per RT pada satu waktu")
	ErrRealIncidentActive              = errors.New("insiden latihan tidak boleh dimulai saat insiden nyata aktif")
	ErrDraftNotFoundOrExpired          = errors.New("token konfirmasi aktivasi tidak valid atau telah kedaluwarsa")
	ErrIncidentAlreadyEnded            = errors.New("insiden sudah selesai")
	ErrRealIncidentRequiresConfirmation = errors.New("aktivasi insiden nyata memerlukan konfirmasi dua langkah")
)

type Store interface {
	CreateIncident(ctx context.Context, inc *Incident) error
	GetIncident(ctx context.Context, id string) (*Incident, error)
	GetIncidentByShortID(ctx context.Context, shortID uint32) (*Incident, error)
	GetActiveIncidentByRT(ctx context.Context, rtID string, mode *IncidentMode) (*Incident, error)
	ListIncidentsByRT(ctx context.Context, rtID string) ([]*Incident, error)
	UpdateIncident(ctx context.Context, inc *Incident) error

	SaveDraft(ctx context.Context, draft *ActivationDraft) error
	GetDraft(ctx context.Context, token string) (*ActivationDraft, error)
	DeleteDraft(ctx context.Context, token string) error
}

// MemoryStore provides thread-safe in-memory storage for testing and offline modes.
type MemoryStore struct {
	mu        sync.RWMutex
	incidents map[string]*Incident        // id -> Incident
	byShortID map[uint32]string           // short_id -> id
	drafts    map[string]*ActivationDraft // token -> draft
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		incidents: make(map[string]*Incident),
		byShortID: make(map[uint32]string),
		drafts:    make(map[string]*ActivationDraft),
	}
}

func (s *MemoryStore) CreateIncident(ctx context.Context, inc *Incident) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Enforce: only one real incident active per RT
	if inc.Mode == ModeNyata && inc.Status == StatusAktif {
		for _, existing := range s.incidents {
			if existing.RTID == inc.RTID && existing.Mode == ModeNyata && existing.Status == StatusAktif {
				return ErrActiveRealIncidentExists
			}
		}
	}

	// Enforce: drill cannot start if real incident is active
	if inc.Mode == ModeLatihan && inc.Status == StatusAktif {
		for _, existing := range s.incidents {
			if existing.RTID == inc.RTID && existing.Mode == ModeNyata && existing.Status == StatusAktif {
				return ErrRealIncidentActive
			}
		}
	}

	if inc.CreatedAt.IsZero() {
		inc.CreatedAt = time.Now().UTC()
	}
	if inc.StartedAt.IsZero() {
		inc.StartedAt = inc.CreatedAt
	}
	if inc.Metrics.ByChannel == nil {
		inc.Metrics.ByChannel = make(map[string]int)
	}

	copyInc := *inc
	s.incidents[inc.ID] = &copyInc
	s.byShortID[inc.ShortID] = inc.ID
	return nil
}

func (s *MemoryStore) GetIncident(ctx context.Context, id string) (*Incident, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	inc, exists := s.incidents[id]
	if !exists {
		return nil, ErrIncidentNotFound
	}
	copyInc := *inc
	return &copyInc, nil
}

func (s *MemoryStore) GetIncidentByShortID(ctx context.Context, shortID uint32) (*Incident, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id, exists := s.byShortID[shortID]
	if !exists {
		return nil, ErrIncidentNotFound
	}
	return s.GetIncident(ctx, id)
}

func (s *MemoryStore) GetActiveIncidentByRT(ctx context.Context, rtID string, mode *IncidentMode) (*Incident, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, inc := range s.incidents {
		if inc.RTID == rtID && inc.Status == StatusAktif {
			if mode == nil || inc.Mode == *mode {
				copyInc := *inc
				return &copyInc, nil
			}
		}
	}
	return nil, ErrIncidentNotFound
}

func (s *MemoryStore) ListIncidentsByRT(ctx context.Context, rtID string) ([]*Incident, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Incident
	for _, inc := range s.incidents {
		if inc.RTID == rtID {
			copyInc := *inc
			result = append(result, &copyInc)
		}
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].StartedAt.After(result[j].StartedAt)
	})

	return result, nil
}

func (s *MemoryStore) UpdateIncident(ctx context.Context, inc *Incident) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.incidents[inc.ID]; !exists {
		return ErrIncidentNotFound
	}

	copyInc := *inc
	s.incidents[inc.ID] = &copyInc
	s.byShortID[inc.ShortID] = inc.ID
	return nil
}

func (s *MemoryStore) SaveDraft(ctx context.Context, draft *ActivationDraft) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	copyDraft := *draft
	s.drafts[draft.Token] = &copyDraft
	return nil
}

func (s *MemoryStore) GetDraft(ctx context.Context, token string) (*ActivationDraft, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	draft, exists := s.drafts[token]
	if !exists || time.Now().UTC().After(draft.ExpiresAt) {
		return nil, ErrDraftNotFoundOrExpired
	}
	copyDraft := *draft
	return &copyDraft, nil
}

func (s *MemoryStore) DeleteDraft(ctx context.Context, token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.drafts, token)
	return nil
}
