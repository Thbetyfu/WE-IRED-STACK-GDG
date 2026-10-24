package whatsapp

import (
	"context"
	"errors"
	"sync"
	"time"

	"github.com/google/uuid"
)

var (
	ErrNotificationNotFound = errors.New("notifikasi tidak ditemukan")
	ErrSessionNotFound      = errors.New("sesi percakapan whatsapp tidak ditemukan")
)

// Store defines persistence for notification delivery tracking, sessions, and deduplication.
type Store interface {
	SaveNotification(ctx context.Context, n *Notification) error
	UpdateNotificationStatus(ctx context.Context, providerID string, status NotificationStatus, errorDetails *string) error
	GetNotification(ctx context.Context, id string) (*Notification, error)
	ListNotificationsByRecipient(ctx context.Context, recipient string, limit int) ([]*Notification, error)

	GetSession(ctx context.Context, phone string) (*WASession, error)
	SaveSession(ctx context.Context, s *WASession) error
	DeleteSession(ctx context.Context, phone string) error

	IsMessageProcessed(ctx context.Context, messageID string) (bool, error)
	MarkMessageProcessed(ctx context.Context, messageID string) error

	HasSentReminder(ctx context.Context, incidentID, householdID, step string) (bool, error)
	RecordReminderSent(ctx context.Context, incidentID, householdID, step string) error
}

// MemoryStore provides in-memory thread-safe storage for tests and local simulation.
type MemoryStore struct {
	mu            sync.RWMutex
	notifications map[string]*Notification // id -> notification
	byProviderID  map[string]string        // providerID -> id
	sessions      map[string]*WASession    // phone -> session
	processedMsgs map[string]time.Time     // message_id -> time
	remindersSent map[string]time.Time     // "inc:hh:step" -> time
}

func NewMemoryStore() *MemoryStore {
	return &MemoryStore{
		notifications: make(map[string]*Notification),
		byProviderID:  make(map[string]string),
		sessions:      make(map[string]*WASession),
		processedMsgs: make(map[string]time.Time),
		remindersSent: make(map[string]time.Time),
	}
}

func (s *MemoryStore) SaveNotification(ctx context.Context, n *Notification) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if n.ID == "" {
		n.ID = uuid.NewString()
	}
	if n.CreatedAt.IsZero() {
		n.CreatedAt = time.Now().UTC()
	}
	n.UpdatedAt = n.CreatedAt

	copyN := *n
	s.notifications[n.ID] = &copyN
	if n.ProviderID != nil && *n.ProviderID != "" {
		s.byProviderID[*n.ProviderID] = n.ID
	}
	return nil
}

func (s *MemoryStore) UpdateNotificationStatus(ctx context.Context, providerID string, status NotificationStatus, errorDetails *string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	id, exists := s.byProviderID[providerID]
	if !exists {
		// If not mapped by providerID, also search notifications
		for _, n := range s.notifications {
			if n.ProviderID != nil && *n.ProviderID == providerID {
				id = n.ID
				exists = true
				break
			}
		}
	}
	if !exists {
		return ErrNotificationNotFound
	}

	n := s.notifications[id]
	n.Status = status
	n.UpdatedAt = time.Now().UTC()
	if errorDetails != nil {
		n.Error = errorDetails
	}
	return nil
}

func (s *MemoryStore) GetNotification(ctx context.Context, id string) (*Notification, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	n, exists := s.notifications[id]
	if !exists {
		return nil, ErrNotificationNotFound
	}
	copyN := *n
	return &copyN, nil
}

func (s *MemoryStore) ListNotificationsByRecipient(ctx context.Context, recipient string, limit int) ([]*Notification, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Notification
	for _, n := range s.notifications {
		if n.Recipient == recipient {
			copyN := *n
			result = append(result, &copyN)
		}
		if limit > 0 && len(result) >= limit {
			break
		}
	}
	return result, nil
}

func (s *MemoryStore) GetSession(ctx context.Context, phone string) (*WASession, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	sess, exists := s.sessions[phone]
	if !exists {
		return nil, ErrSessionNotFound
	}
	copySess := *sess
	return &copySess, nil
}

func (s *MemoryStore) SaveSession(ctx context.Context, sess *WASession) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	sess.UpdatedAt = time.Now().UTC()
	copySess := *sess
	s.sessions[sess.Phone] = &copySess
	return nil
}

func (s *MemoryStore) DeleteSession(ctx context.Context, phone string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	delete(s.sessions, phone)
	return nil
}

func (s *MemoryStore) IsMessageProcessed(ctx context.Context, messageID string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	_, exists := s.processedMsgs[messageID]
	return exists, nil
}

func (s *MemoryStore) MarkMessageProcessed(ctx context.Context, messageID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.processedMsgs[messageID] = time.Now().UTC()
	return nil
}

func (s *MemoryStore) HasSentReminder(ctx context.Context, incidentID, householdID, step string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	key := incidentID + ":" + householdID + ":" + step
	_, exists := s.remindersSent[key]
	return exists, nil
}

func (s *MemoryStore) RecordReminderSent(ctx context.Context, incidentID, householdID, step string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := incidentID + ":" + householdID + ":" + step
	s.remindersSent[key] = time.Now().UTC()
	return nil
}
