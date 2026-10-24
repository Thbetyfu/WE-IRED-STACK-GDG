package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PGQueue provides a production-grade PostgreSQL job queue implementation using FOR UPDATE SKIP LOCKED.
type PGQueue struct {
	pool         *pgxpool.Pool
	workerID     string
	handlers     map[string]Handler
	mu           sync.RWMutex
	pollInterval time.Duration
	batchSize    int
	stopChan     chan struct{}
	wg           sync.WaitGroup
	running      bool
}

// NewPGQueue creates a new PostgreSQL backed job queue.
func NewPGQueue(pool *pgxpool.Pool, pollInterval time.Duration, batchSize int) *PGQueue {
	if pollInterval <= 0 {
		pollInterval = 2 * time.Second
	}
	if batchSize <= 0 {
		batchSize = 10
	}
	return &PGQueue{
		pool:         pool,
		workerID:     fmt.Sprintf("worker-%s", uuid.NewString()[:8]),
		handlers:     make(map[string]Handler),
		pollInterval: pollInterval,
		batchSize:    batchSize,
		stopChan:     make(chan struct{}),
	}
}

func (q *PGQueue) RegisterHandler(jobType string, handler Handler) {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.handlers[jobType] = handler
}

func (q *PGQueue) Enqueue(ctx context.Context, jobType string, payload any, runAt time.Time) (string, error) {
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

	query := `
		INSERT INTO jobs (id, type, payload, status, attempts, max_attempts, run_at, created_at, updated_at)
		VALUES ($1, $2, $3, 'pending', 0, 3, $4, NOW(), NOW())
		RETURNING id;
	`

	var returnedID string
	err := q.pool.QueryRow(ctx, query, jobID, jobType, raw, runAt).Scan(&returnedID)
	if err != nil {
		return "", fmt.Errorf("failed to enqueue job: %w", err)
	}

	return returnedID, nil
}

func (q *PGQueue) Start(ctx context.Context) error {
	q.mu.Lock()
	if q.running {
		q.mu.Unlock()
		return nil
	}
	q.running = true
	q.mu.Unlock()

	q.wg.Add(1)
	go q.workerLoop(ctx)
	return nil
}

func (q *PGQueue) Stop() {
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

func (q *PGQueue) workerLoop(ctx context.Context) {
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
			q.processBatch(ctx)
		}
	}
}

func (q *PGQueue) processBatch(ctx context.Context) {
	// Atomic claim of pending jobs with FOR UPDATE SKIP LOCKED
	claimQuery := `
		WITH available AS (
			SELECT id
			FROM jobs
			WHERE status = 'pending' AND run_at <= NOW()
			ORDER BY run_at ASC
			LIMIT $1
			FOR UPDATE SKIP LOCKED
		)
		UPDATE jobs j
		SET status = 'running',
			attempts = j.attempts + 1,
			locked_at = NOW(),
			locked_by = $2,
			updated_at = NOW()
		FROM available
		WHERE j.id = available.id
		RETURNING j.id, j.type, j.payload, j.status, j.attempts, j.max_attempts, j.run_at, j.created_at, j.updated_at;
	`

	rows, err := q.pool.Query(ctx, claimQuery, q.batchSize, q.workerID)
	if err != nil {
		slog.Error("failed to claim jobs from database", "error", err)
		return
	}
	defer rows.Close()

	var jobs []*Job
	for rows.Next() {
		var j Job
		var idStr string
		err := rows.Scan(
			&idStr,
			&j.Type,
			&j.Payload,
			&j.Status,
			&j.Attempts,
			&j.MaxAttempts,
			&j.RunAt,
			&j.CreatedAt,
			&j.UpdatedAt,
		)
		if err != nil {
			slog.Error("failed to scan claimed job", "error", err)
			continue
		}
		j.ID = idStr
		jobs = append(jobs, &j)
	}

	for _, j := range jobs {
		q.mu.RLock()
		handler, exists := q.handlers[j.Type]
		q.mu.RUnlock()

		if !exists {
			slog.Error("no handler registered for claimed job", "job_id", j.ID, "type", j.Type)
			errMsg := fmt.Sprintf("%v: %s", ErrHandlerNotFound, j.Type)
			q.markFailed(ctx, j.ID, errMsg)
			continue
		}

		jobErr := handler(ctx, j)
		if jobErr != nil {
			slog.Warn("job execution failed", "job_id", j.ID, "type", j.Type, "attempt", j.Attempts, "error", jobErr)
			if j.Attempts >= j.MaxAttempts {
				q.markFailed(ctx, j.ID, jobErr.Error())
			} else {
				backoff := time.Duration(j.Attempts*j.Attempts) * time.Second
				nextRun := time.Now().Add(backoff)
				q.markRetry(ctx, j.ID, jobErr.Error(), nextRun)
			}
		} else {
			q.markCompleted(ctx, j.ID)
		}
	}
}

func (q *PGQueue) markCompleted(ctx context.Context, id string) {
	query := `
		UPDATE jobs
		SET status = 'completed',
			locked_at = NULL,
			locked_by = NULL,
			last_error = NULL,
			updated_at = NOW()
		WHERE id = $1;
	`
	_, _ = q.pool.Exec(ctx, query, id)
}

func (q *PGQueue) markFailed(ctx context.Context, id, errStr string) {
	query := `
		UPDATE jobs
		SET status = 'failed',
			locked_at = NULL,
			locked_by = NULL,
			last_error = $2,
			updated_at = NOW()
		WHERE id = $1;
	`
	_, _ = q.pool.Exec(ctx, query, id, errStr)
}

func (q *PGQueue) markRetry(ctx context.Context, id, errStr string, nextRun time.Time) {
	query := `
		UPDATE jobs
		SET status = 'pending',
			locked_at = NULL,
			locked_by = NULL,
			last_error = $2,
			run_at = $3,
			updated_at = NOW()
		WHERE id = $1;
	`
	_, _ = q.pool.Exec(ctx, query, id, errStr, nextRun)
}
