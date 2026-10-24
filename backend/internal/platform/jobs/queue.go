package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

// Job Statuses
const (
	StatusPending   = "pending"
	StatusRunning   = "running"
	StatusCompleted = "completed"
	StatusFailed    = "failed"
)

var (
	ErrQueueStopped      = errors.New("job queue has been stopped")
	ErrHandlerNotFound   = errors.New("no handler registered for job type")
	ErrJobNotFound       = errors.New("job not found")
	ErrInvalidJobPayload = errors.New("invalid job payload")
)

// Job represents a unit of deferred background work.
type Job struct {
	ID          string          `json:"id"`
	Type        string          `json:"type"`
	Payload     json.RawMessage `json:"payload"`
	Status      string          `json:"status"`
	Attempts    int             `json:"attempts"`
	MaxAttempts int             `json:"max_attempts"`
	RunAt       time.Time       `json:"run_at"`
	LockedAt    *time.Time      `json:"locked_at,omitempty"`
	LockedBy    *string         `json:"locked_by,omitempty"`
	LastError   *string         `json:"last_error,omitempty"`
	CreatedAt   time.Time       `json:"created_at"`
	UpdatedAt   time.Time       `json:"updated_at"`
}

// Handler is a function that processes a specific job type.
type Handler func(ctx context.Context, job *Job) error

// Queue defines the interface for scheduling and processing background jobs.
type Queue interface {
	Enqueue(ctx context.Context, jobType string, payload any, runAt time.Time) (string, error)
	RegisterHandler(jobType string, handler Handler)
	Start(ctx context.Context) error
	Stop()
}

// UnmarshalPayload unmarshals the raw JSON payload into target v.
func UnmarshalPayload(raw json.RawMessage, v any) error {
	if len(raw) == 0 {
		return nil
	}
	return json.Unmarshal(raw, v)
}

