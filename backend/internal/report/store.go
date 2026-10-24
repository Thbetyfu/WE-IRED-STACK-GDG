package report

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

var (
	ErrReportNotFound = errors.New("laporan tidak ditemukan")
	ErrStateNotFound  = errors.New("status rumah tidak ditemukan")
)

type Store interface {
	SaveReport(ctx context.Context, r *Report) (alreadyExists bool, err error)
	GetReport(ctx context.Context, id string) (*Report, error)
	GetReportBySeq(ctx context.Context, incidentID, householdID string, seq int) (*Report, error)
	ListReportsByIncident(ctx context.Context, incidentID string) ([]*Report, error)
	ListReportsByHousehold(ctx context.Context, incidentID, householdID string) ([]*Report, error)
	GetMaxSeq(ctx context.Context, incidentID, householdID string) (int, error)

	GetHouseholdState(ctx context.Context, incidentID, householdID string) (*HouseholdState, error)
	UpsertHouseholdState(ctx context.Context, s *HouseholdState) error
	ListHouseholdStates(ctx context.Context, incidentID string) ([]*HouseholdState, error)
}

// MemoryStore provides in-memory thread-safe storage for tests and local posko operation.
type MemoryStore struct {
	mu      sync.RWMutex
	reports map[string]*Report                 // id -> Report
	bySeq   map[string]string                  // "incidentID:householdID:seq" -> id
	states  map[string]*HouseholdState         // "incidentID:householdID" -> HouseholdState
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		reports: make(map[string]*Report),
		bySeq:   make(map[string]string),
		states:  make(map[string]*HouseholdState),
	}
}

func (s *MemoryStore) SaveReport(ctx context.Context, r *Report) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// 1. Idempotency check by report ID
	if _, exists := s.reports[r.ID]; exists {
		return true, nil
	}

	// 2. Idempotency check by (incident, household, seq)
	seqKey := fmt.Sprintf("%s:%s:%d", r.IncidentID, r.HouseholdID, r.Seq)
	if _, exists := s.bySeq[seqKey]; exists {
		return true, nil
	}

	if r.ReceivedAt.IsZero() {
		r.ReceivedAt = time.Now().UTC()
	}

	copyReport := *r
	s.reports[r.ID] = &copyReport
	s.bySeq[seqKey] = r.ID
	return false, nil
}

func (s *MemoryStore) GetReport(ctx context.Context, id string) (*Report, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	r, exists := s.reports[id]
	if !exists {
		return nil, ErrReportNotFound
	}
	copyReport := *r
	return &copyReport, nil
}

func (s *MemoryStore) GetReportBySeq(ctx context.Context, incidentID, householdID string, seq int) (*Report, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	seqKey := fmt.Sprintf("%s:%s:%d", incidentID, householdID, seq)
	id, exists := s.bySeq[seqKey]
	if !exists {
		return nil, ErrReportNotFound
	}
	return s.GetReport(ctx, id)
}

func (s *MemoryStore) ListReportsByIncident(ctx context.Context, incidentID string) ([]*Report, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Report
	for _, r := range s.reports {
		if r.IncidentID == incidentID {
			copyReport := *r
			result = append(result, &copyReport)
		}
	}
	return result, nil
}

func (s *MemoryStore) ListReportsByHousehold(ctx context.Context, incidentID, householdID string) ([]*Report, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Report
	for _, r := range s.reports {
		if r.IncidentID == incidentID && r.HouseholdID == householdID {
			copyReport := *r
			result = append(result, &copyReport)
		}
	}
	return result, nil
}

func (s *MemoryStore) GetMaxSeq(ctx context.Context, incidentID, householdID string) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	maxSeq := 0
	for _, r := range s.reports {
		if r.IncidentID == incidentID && r.HouseholdID == householdID {
			if r.Seq > maxSeq {
				maxSeq = r.Seq
			}
		}
	}
	return maxSeq, nil
}

func (s *MemoryStore) GetHouseholdState(ctx context.Context, incidentID, householdID string) (*HouseholdState, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	key := fmt.Sprintf("%s:%s", incidentID, householdID)
	st, exists := s.states[key]
	if !exists {
		return nil, ErrStateNotFound
	}
	copyState := *st
	return &copyState, nil
}

func (s *MemoryStore) UpsertHouseholdState(ctx context.Context, st *HouseholdState) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := fmt.Sprintf("%s:%s", st.IncidentID, st.HouseholdID)
	if st.UpdatedAt.IsZero() {
		st.UpdatedAt = time.Now().UTC()
	}
	copyState := *st
	s.states[key] = &copyState
	return nil
}

func (s *MemoryStore) ListHouseholdStates(ctx context.Context, incidentID string) ([]*HouseholdState, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*HouseholdState
	for _, st := range s.states {
		if st.IncidentID == incidentID {
			copyState := *st
			result = append(result, &copyState)
		}
	}
	return result, nil
}
