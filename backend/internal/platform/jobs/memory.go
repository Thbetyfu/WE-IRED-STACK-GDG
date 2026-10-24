package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
)

// MemoryQueue provides an in-memory, thread-safe implementation of Queue.
type MemoryQueue struct {
	mu           sync.Mutex
	jobs         map[string]*Job
	handlers     map[string]Handler
	pollInterval time.Duration
	workerCount  int
	stopChan     chan struct{}
	wg           sync.WaitGroup
	running      bool
}

// NewMemoryQueue creates a new MemoryQueue.
func NewMemoryQueue(pollInterval time.Duration) *MemoryQueue {
	if pollInterval <= 0 {
		pollInterval = 100 * time.Millisecond
	}
	return &MemoryQueue{
		jobs:         make(map[string]*Job),
		handlers:     make(map[string]Handler),
		pollInterval: pollInterval,
		workerCount:  1,
		stopChan:     make(chan struct{}),
	}
}

// SetWorkerCount configures how many concurrent worker goroutines run.
func (q *MemoryQueue) SetWorkerCount(n int) {
	q.mu.Lock()
	defer q.mu.Unlock()
	if n > 0 {
		q.workerCount = n
	}
}

func (q *MemoryQueue) RegisterHandler(jobType string, handler Handler) {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.handlers[jobType] = handler
}

func (q *MemoryQueue) Enqueue(ctx context.Context, jobType string, payload any, runAt time.Time) (string, error) {
	q.mu.Lock()
	defer q.mu.Unlock()

	var raw json.RawMessage
	if payload != nil {
		bytes, err := json.Marshal(payload)
		if err != nil {
			return "", fmt.Errorf("%w: %v", ErrInvalidJobPayload, err)
		}
		raw = bytes
	}

	if runAt.IsZero() {
		runAt = time.Now()
	}

	jobID := uuid.NewString()
	now := time.Now()

	job := &Job{
		ID:          jobID,
		Type:        jobType,
		Payload:     raw,
		Status:      StatusPending,
		Attempts:    0,
		MaxAttempts: 3,
		RunAt:       runAt,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	q.jobs[jobID] = job
	return jobID, nil
}

func (q *MemoryQueue) Start(ctx context.Context) error {
	q.mu.Lock()
	if q.running {
		q.mu.Unlock()
		return nil
	}
	q.running = true
	workers := q.workerCount
	if workers <= 0 {
		workers = 1
	}
	q.mu.Unlock()

	for i := 0; i < workers; i++ {
		q.wg.Add(1)
		go q.workerLoop(ctx)
	}
	return nil
}

func (q *MemoryQueue) Stop() {
	q.mu.Lock()
	if !q.running {
		q.mu.Unlock()
		return
	}
	q.running = false
	close(q.stopChan)
	q.mu.Unlock()

	q.wg.Wait()
}

func (q *MemoryQueue) workerLoop(ctx context.Context) {
	defer q.wg.Done()
	ticker := time.NewTicker(q.pollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-q.stopChan:
			return
		case <-ticker.C:
			q.processNextBatch(ctx)
		}
	}
}

func (q *MemoryQueue) processNextBatch(ctx context.Context) {
	q.mu.Lock()
	now := time.Now()
	var candidate *Job

	for _, j := range q.jobs {
		if j.Status == StatusPending && !j.RunAt.After(now) {
			candidate = j
			candidate.Status = StatusRunning
			nowLock := time.Now()
			candidate.LockedAt = &nowLock
			candidate.Attempts++
			candidate.UpdatedAt = nowLock
			break
		}
	}
	q.mu.Unlock()

	if candidate == nil {
		return
	}

	q.mu.Lock()
	h, exists := q.handlers[candidate.Type]
	q.mu.Unlock()

	if !exists {
		errMsg := fmt.Sprintf("%v: %s", ErrHandlerNotFound, candidate.Type)
		q.markJob(candidate.ID, StatusFailed, &errMsg, time.Time{})
		return
	}

	err := h(ctx, candidate)
	nowFinish := time.Now()

	if err != nil {
		errStr := err.Error()
		slog.Warn("job execution failed", "job_id", candidate.ID, "type", candidate.Type, "attempt", candidate.Attempts, "error", err)

		if candidate.Attempts >= candidate.MaxAttempts {
			q.markJob(candidate.ID, StatusFailed, &errStr, nowFinish)
		} else {
			// Exponential backoff
			backoff := time.Duration(candidate.Attempts*candidate.Attempts) * time.Second
			nextRun := nowFinish.Add(backoff)
			q.markJob(candidate.ID, StatusPending, &errStr, nextRun)
		}
	} else {
		q.markJob(candidate.ID, StatusCompleted, nil, nowFinish)
	}
}

func (q *MemoryQueue) markJob(id, status string, lastErr *string, nextRun time.Time) {
	q.mu.Lock()
	defer q.mu.Unlock()

	if j, ok := q.jobs[id]; ok {
		j.Status = status
		j.LastError = lastErr
		j.UpdatedAt = time.Now()
		if !nextRun.IsZero() {
			j.RunAt = nextRun
		}
	}
}

// GetJob returns a copy of the job by ID (useful for tests).
func (q *MemoryQueue) GetJob(id string) (*Job, error) {
	q.mu.Lock()
	defer q.mu.Unlock()

	j, ok := q.jobs[id]
	if !ok {
		return nil, ErrJobNotFound
	}
	cp := *j
	return &cp, nil
}
