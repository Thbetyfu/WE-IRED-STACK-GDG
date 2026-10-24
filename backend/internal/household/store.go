package household

import (
	"context"
	"encoding/hex"
	"errors"
	"strings"
	"sync"
	"time"
)

var (
	ErrHouseholdNotFound = errors.New("data rumah tangga tidak ditemukan")
	ErrMemberNotFound    = errors.New("data anggota keluarga tidak ditemukan")
	ErrDuplicateNumber   = errors.New("nomor rumah sudah terdaftar di RT ini")
	ErrInvalidMemberIdx  = errors.New("indeks anggota keluarga harus antara 0 dan 7")
	ErrConsentRequired   = errors.New("persetujuan warga wajib dicatat sebelum menyimpan data kerentanan dan catatan kesehatan")
	ErrConsentRevoked    = errors.New("persetujuan warga telah dicabut")
)

type Store interface {
	CreateHousehold(ctx context.Context, h *Household) error
	GetHousehold(ctx context.Context, id string) (*Household, error)
	UpdateHousehold(ctx context.Context, h *Household) error
	DeleteHousehold(ctx context.Context, id string) error
	ListHouseholdsByRT(ctx context.Context, rtID string, blockID *string) ([]*Household, error)
	GetHouseholdByShortID(ctx context.Context, shortID []byte) (*Household, error)
	GetHouseholdByInviteCode(ctx context.Context, inviteCode string) (*Household, error)
	GetHouseholdByPhone(ctx context.Context, phone string) (*Household, error)
	UpdateInviteCode(ctx context.Context, id string, newCode *string) error

	AddMember(ctx context.Context, m *Member) error
	GetMember(ctx context.Context, householdID, memberID string) (*Member, error)
	UpdateMember(ctx context.Context, m *Member) error
	DeleteMember(ctx context.Context, householdID, memberID string) error
	ListMembers(ctx context.Context, householdID string) ([]*Member, error)

	RecordConsent(ctx context.Context, c *Consent) error
	GetActiveConsent(ctx context.Context, householdID string) (*Consent, error)
	RevokeConsent(ctx context.Context, householdID string) error
	PurgeSensitiveHealthData(ctx context.Context, householdID string) error
}

// MemoryStore provides an in-memory implementation of Store for testing and offline execution.
type MemoryStore struct {
	mu          sync.RWMutex
	households  map[string]*Household        // id -> Household
	members     map[string]map[string]*Member // householdID -> memberID -> Member
	consents    map[string][]*Consent         // householdID -> []Consent
	inviteCodes map[string]string             // inviteCode -> householdID
	byShortID   map[string]string             // hex(shortID) -> householdID
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		households:  make(map[string]*Household),
		members:     make(map[string]map[string]*Member),
		consents:    make(map[string][]*Consent),
		inviteCodes: make(map[string]string),
		byShortID:   make(map[string]string),
	}
}

func (s *MemoryStore) CreateHousehold(ctx context.Context, h *Household) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Check duplicate number in same RT
	for _, existing := range s.households {
		if existing.RTID == h.RTID && existing.Number == h.Number {
			return ErrDuplicateNumber
		}
	}

	if h.CreatedAt.IsZero() {
		h.CreatedAt = time.Now().UTC()
	}

	s.households[h.ID] = h
	if h.InviteCode != nil && *h.InviteCode != "" {
		s.inviteCodes[*h.InviteCode] = h.ID
	}
	if len(h.ShortID) > 0 {
		s.byShortID[hex.EncodeToString(h.ShortID)] = h.ID
	}
	return nil
}

func (s *MemoryStore) GetHousehold(ctx context.Context, id string) (*Household, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	h, exists := s.households[id]
	if !exists {
		return nil, ErrHouseholdNotFound
	}

	// Copy and populate members
	copied := *h
	copied.Members = make([]*Member, 0)
	if mmap, ok := s.members[id]; ok {
		for _, m := range mmap {
			mCopy := *m
			copied.Members = append(copied.Members, &mCopy)
		}
	}

	// Check consent
	copied.HasConsent = s.hasActiveConsentLocked(id)

	return &copied, nil
}

func (s *MemoryStore) UpdateHousehold(ctx context.Context, h *Household) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	existing, exists := s.households[h.ID]
	if !exists {
		return ErrHouseholdNotFound
	}

	// Check duplicate number in same RT
	if existing.Number != h.Number {
		for _, o := range s.households {
			if o.ID != h.ID && o.RTID == h.RTID && o.Number == h.Number {
				return ErrDuplicateNumber
			}
		}
	}

	s.households[h.ID] = h
	return nil
}

func (s *MemoryStore) DeleteHousehold(ctx context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	h, exists := s.households[id]
	if !exists {
		return ErrHouseholdNotFound
	}

	if h.InviteCode != nil {
		delete(s.inviteCodes, *h.InviteCode)
	}
	delete(s.households, id)
	delete(s.members, id)
	delete(s.consents, id)
	return nil
}

func (s *MemoryStore) ListHouseholdsByRT(ctx context.Context, rtID string, blockID *string) ([]*Household, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Household
	for _, h := range s.households {
		if h.RTID != rtID {
			continue
		}
		if blockID != nil {
			if h.BlockID == nil || *h.BlockID != *blockID {
				continue
			}
		}

		copied := *h
		copied.Members = make([]*Member, 0)
		if mmap, ok := s.members[h.ID]; ok {
			for _, m := range mmap {
				mCopy := *m
				copied.Members = append(copied.Members, &mCopy)
			}
		}
		copied.HasConsent = s.hasActiveConsentLocked(h.ID)
		result = append(result, &copied)
	}
	return result, nil
}

func (s *MemoryStore) GetHouseholdByShortID(ctx context.Context, shortID []byte) (*Household, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	hexKey := hex.EncodeToString(shortID)
	id, exists := s.byShortID[hexKey]
	if !exists {
		// Fallback check
		for _, h := range s.households {
			if hex.EncodeToString(h.ShortID) == hexKey {
				id = h.ID
				exists = true
				break
			}
		}
	}
	if !exists {
		return nil, ErrHouseholdNotFound
	}
	return s.GetHousehold(ctx, id)
}

func (s *MemoryStore) GetHouseholdByInviteCode(ctx context.Context, inviteCode string) (*Household, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id, exists := s.inviteCodes[inviteCode]
	if !exists {
		return nil, ErrHouseholdNotFound
	}

	h, exists := s.households[id]
	if !exists {
		return nil, ErrHouseholdNotFound
	}

	copied := *h
	copied.HasConsent = s.hasActiveConsentLocked(id)
	return &copied, nil
}

func (s *MemoryStore) GetHouseholdByPhone(ctx context.Context, phone string) (*Household, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	normTarget := normalizePhone(phone)
	if normTarget == "" {
		return nil, ErrHouseholdNotFound
	}

	for _, h := range s.households {
		if normalizePhone(h.WAPhone) == normTarget {
			copied := *h
			copied.HasConsent = s.hasActiveConsentLocked(h.ID)
			return &copied, nil
		}
	}

	return nil, ErrHouseholdNotFound
}

func normalizePhone(p string) string {
	var b strings.Builder
	for _, ch := range p {
		if ch >= '0' && ch <= '9' {
			b.WriteRune(ch)
		}
	}
	s := b.String()
	if strings.HasPrefix(s, "0") {
		s = "62" + s[1:]
	}
	return s
}

func (s *MemoryStore) UpdateInviteCode(ctx context.Context, id string, newCode *string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	h, exists := s.households[id]
	if !exists {
		return ErrHouseholdNotFound
	}

	if h.InviteCode != nil {
		delete(s.inviteCodes, *h.InviteCode)
	}

	h.InviteCode = newCode
	if newCode != nil && *newCode != "" {
		s.inviteCodes[*newCode] = id
	}
	return nil
}

func (s *MemoryStore) AddMember(ctx context.Context, m *Member) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.households[m.HouseholdID]; !exists {
		return ErrHouseholdNotFound
	}

	if m.Idx < 0 || m.Idx > 7 {
		return ErrInvalidMemberIdx
	}

	if m.CreatedAt.IsZero() {
		m.CreatedAt = time.Now().UTC()
	}

	if _, ok := s.members[m.HouseholdID]; !ok {
		s.members[m.HouseholdID] = make(map[string]*Member)
	}

	// Check unique index 0-7 per household
	for _, existing := range s.members[m.HouseholdID] {
		if existing.ID != m.ID && existing.Idx == m.Idx {
			return errors.New("indeks anggota keluarga sudah digunakan (maks. 8 anggota per KK)")
		}
	}

	s.members[m.HouseholdID][m.ID] = m
	return nil
}

func (s *MemoryStore) GetMember(ctx context.Context, householdID, memberID string) (*Member, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	mmap, ok := s.members[householdID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	m, ok := mmap[memberID]
	if !ok {
		return nil, ErrMemberNotFound
	}
	mCopy := *m
	return &mCopy, nil
}

func (s *MemoryStore) UpdateMember(ctx context.Context, m *Member) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	mmap, ok := s.members[m.HouseholdID]
	if !ok {
		return ErrMemberNotFound
	}
	if _, ok := mmap[m.ID]; !ok {
		return ErrMemberNotFound
	}

	// Check idx
	if m.Idx < 0 || m.Idx > 7 {
		return ErrInvalidMemberIdx
	}
	for _, existing := range mmap {
		if existing.ID != m.ID && existing.Idx == m.Idx {
			return errors.New("indeks anggota keluarga sudah digunakan")
		}
	}

	mmap[m.ID] = m
	return nil
}

func (s *MemoryStore) DeleteMember(ctx context.Context, householdID, memberID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	mmap, ok := s.members[householdID]
	if !ok {
		return ErrMemberNotFound
	}
	if _, ok := mmap[memberID]; !ok {
		return ErrMemberNotFound
	}
	delete(mmap, memberID)
	return nil
}

func (s *MemoryStore) ListMembers(ctx context.Context, householdID string) ([]*Member, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Member
	if mmap, ok := s.members[householdID]; ok {
		for _, m := range mmap {
			mCopy := *m
			result = append(result, &mCopy)
		}
	}
	return result, nil
}

func (s *MemoryStore) RecordConsent(ctx context.Context, c *Consent) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.households[c.HouseholdID]; !exists {
		return ErrHouseholdNotFound
	}

	if c.GivenAt.IsZero() {
		c.GivenAt = time.Now().UTC()
	}

	s.consents[c.HouseholdID] = append(s.consents[c.HouseholdID], c)
	return nil
}

func (s *MemoryStore) GetActiveConsent(ctx context.Context, householdID string) (*Consent, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	list := s.consents[householdID]
	for i := len(list) - 1; i >= 0; i-- {
		c := list[i]
		if c.RevokedAt == nil {
			cCopy := *c
			return &cCopy, nil
		}
	}
	return nil, ErrConsentRevoked
}

func (s *MemoryStore) hasActiveConsentLocked(householdID string) bool {
	list := s.consents[householdID]
	for i := len(list) - 1; i >= 0; i-- {
		if list[i].RevokedAt == nil {
			return true
		}
	}
	return false
}

func (s *MemoryStore) RevokeConsent(ctx context.Context, householdID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	list, ok := s.consents[householdID]
	if !ok || len(list) == 0 {
		return ErrConsentRevoked
	}

	now := time.Now().UTC()
	for _, c := range list {
		if c.RevokedAt == nil {
			c.RevokedAt = &now
		}
	}

	return nil
}

func (s *MemoryStore) PurgeSensitiveHealthData(ctx context.Context, householdID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Clear health_notes_enc and sensitive vulnerability flags
	if mmap, ok := s.members[householdID]; ok {
		for _, m := range mmap {
			m.HealthNotesEnc = nil
			m.HealthNotes = ""
			// Retain only needs_evac_assist penanda if authorized per FR-HH-05
			m.VulnFlags = 0
		}
	}
	return nil
}
