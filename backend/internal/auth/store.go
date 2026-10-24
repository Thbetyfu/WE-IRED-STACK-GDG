package auth

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

var (
	ErrUserNotFound      = errors.New("pengguna tidak ditemukan")
	ErrHouseholdNotFound = errors.New("data rumah tangga dengan kode undangan tersebut tidak ditemukan")
	ErrTokenRevoked      = errors.New("refresh token telah dicabut")
)

type User struct {
	ID           string
	Name         string
	Phone        string
	Email        string
	PasswordHash string
	CreatedAt    time.Time
}

type Membership struct {
	ID          string
	UserID      string
	RegionID    string
	Role        string
	HouseholdID *string
	CreatedAt   time.Time
}

type Household struct {
	ID         string
	RTID       string
	BlockID    *string
	Number     string
	Address    string
	HeadName   string
	WAPhone    string
	ShortID    []byte
	KeyEnc     []byte
	InviteCode *string
}

type OTPRecord struct {
	ID         string
	Phone      string
	Code       string
	Attempts   int
	ExpiresAt  time.Time
	ConsumedAt *time.Time
	CreatedAt  time.Time
}

type RefreshTokenRecord struct {
	ID        string
	UserID    string
	TokenHash string
	Revoked   bool
	ExpiresAt time.Time
	CreatedAt time.Time
}

type Store interface {
	GetUserByEmail(ctx context.Context, email string) (*User, error)
	GetUserByPhone(ctx context.Context, phone string) (*User, error)
	GetUserByID(ctx context.Context, id string) (*User, error)
	CreateUser(ctx context.Context, u *User) error

	GetMemberships(ctx context.Context, userID string) ([]*Membership, error)
	AddMembership(ctx context.Context, m *Membership) error

	GetHouseholdByInviteCode(ctx context.Context, inviteCode string) (*Household, error)
	UpdateHouseholdKeyAndClearInvite(ctx context.Context, householdID string, keyEnc []byte) error

	GetRecentOTPCount(ctx context.Context, phone string, window time.Duration) (int, error)
	SaveOTP(ctx context.Context, phone, code string, expiresAt time.Time) error
	GetLatestValidOTP(ctx context.Context, phone string) (*OTPRecord, error)
	IncrementOTPAttempts(ctx context.Context, id string) (int, error)
	ConsumeOTP(ctx context.Context, id string) error

	SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error
	GetRefreshToken(ctx context.Context, tokenHash string) (*RefreshTokenRecord, error)
	RevokeRefreshToken(ctx context.Context, tokenHash string) error
}

// MemoryStore provides a thread-safe in-memory store for tests and offline execution.
type MemoryStore struct {
	mu            sync.RWMutex
	users         map[string]*User // by ID
	usersByEmail  map[string]string
	usersByPhone  map[string]string
	memberships   map[string][]*Membership // by UserID
	households    map[string]*Household    // by ID
	otps          map[string]*OTPRecord    // by ID
	refreshTokens map[string]*RefreshTokenRecord
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		users:         make(map[string]*User),
		usersByEmail:  make(map[string]string),
		usersByPhone:  make(map[string]string),
		memberships:   make(map[string][]*Membership),
		households:    make(map[string]*Household),
		otps:          make(map[string]*OTPRecord),
		refreshTokens: make(map[string]*RefreshTokenRecord),
	}
}

func (s *MemoryStore) CreateUser(ctx context.Context, u *User) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if u.ID == "" {
		u.ID = uuid.NewString()
	}
	if u.CreatedAt.IsZero() {
		u.CreatedAt = time.Now()
	}

	s.users[u.ID] = u
	if u.Email != "" {
		s.usersByEmail[u.Email] = u.ID
	}
	if u.Phone != "" {
		s.usersByPhone[u.Phone] = u.ID
	}
	return nil
}

func (s *MemoryStore) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id, ok := s.usersByEmail[email]
	if !ok {
		return nil, ErrUserNotFound
	}
	return s.users[id], nil
}

func (s *MemoryStore) GetUserByPhone(ctx context.Context, phone string) (*User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	id, ok := s.usersByPhone[phone]
	if !ok {
		return nil, ErrUserNotFound
	}
	return s.users[id], nil
}

func (s *MemoryStore) GetUserByID(ctx context.Context, id string) (*User, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	u, ok := s.users[id]
	if !ok {
		return nil, ErrUserNotFound
	}
	return u, nil
}

func (s *MemoryStore) AddMembership(ctx context.Context, m *Membership) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if m.ID == "" {
		m.ID = uuid.NewString()
	}
	s.memberships[m.UserID] = append(s.memberships[m.UserID], m)
	return nil
}

func (s *MemoryStore) GetMemberships(ctx context.Context, userID string) ([]*Membership, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.memberships[userID], nil
}

func (s *MemoryStore) AddHousehold(h *Household) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.households[h.ID] = h
}

func (s *MemoryStore) GetHouseholdByInviteCode(ctx context.Context, inviteCode string) (*Household, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, h := range s.households {
		if h.InviteCode != nil && *h.InviteCode == inviteCode {
			return h, nil
		}
	}
	return nil, ErrHouseholdNotFound
}

func (s *MemoryStore) UpdateHouseholdKeyAndClearInvite(ctx context.Context, householdID string, keyEnc []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	h, ok := s.households[householdID]
	if !ok {
		return ErrHouseholdNotFound
	}
	h.KeyEnc = keyEnc
	h.InviteCode = nil // consumed single-use invite code
	return nil
}

func (s *MemoryStore) GetRecentOTPCount(ctx context.Context, phone string, window time.Duration) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	since := time.Now().Add(-window)
	count := 0
	for _, rec := range s.otps {
		if rec.Phone == phone && rec.CreatedAt.After(since) {
			count++
		}
	}
	return count, nil
}

func (s *MemoryStore) SaveOTP(ctx context.Context, phone, code string, expiresAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	id := uuid.NewString()
	s.otps[id] = &OTPRecord{
		ID:        id,
		Phone:     phone,
		Code:      code,
		Attempts:  0,
		ExpiresAt: expiresAt,
		CreatedAt: time.Now(),
	}
	return nil
}

func (s *MemoryStore) GetLatestValidOTP(ctx context.Context, phone string) (*OTPRecord, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var latest *OTPRecord
	now := time.Now()

	for _, rec := range s.otps {
		if rec.Phone == phone && rec.ConsumedAt == nil && rec.ExpiresAt.After(now) {
			if latest == nil || rec.CreatedAt.After(latest.CreatedAt) {
				latest = rec
			}
		}
	}

	if latest == nil {
		return nil, ErrOTPInvalid
	}
	return latest, nil
}

func (s *MemoryStore) IncrementOTPAttempts(ctx context.Context, id string) (int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	rec, ok := s.otps[id]
	if !ok {
		return 0, ErrOTPInvalid
	}
	rec.Attempts++
	return rec.Attempts, nil
}

func (s *MemoryStore) ConsumeOTP(ctx context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	rec, ok := s.otps[id]
	if !ok {
		return ErrOTPInvalid
	}
	now := time.Now()
	rec.ConsumedAt = &now
	return nil
}

func (s *MemoryStore) SaveRefreshToken(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.refreshTokens[tokenHash] = &RefreshTokenRecord{
		ID:        uuid.NewString(),
		UserID:    userID,
		TokenHash: tokenHash,
		Revoked:   false,
		ExpiresAt: expiresAt,
		CreatedAt: time.Now(),
	}
	return nil
}

func (s *MemoryStore) GetRefreshToken(ctx context.Context, tokenHash string) (*RefreshTokenRecord, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	rec, ok := s.refreshTokens[tokenHash]
	if !ok {
		return nil, ErrInvalidToken
	}
	return rec, nil
}

func (s *MemoryStore) RevokeRefreshToken(ctx context.Context, tokenHash string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	rec, ok := s.refreshTokens[tokenHash]
	if !ok {
		return nil
	}
	rec.Revoked = true
	return nil
}
