package jobs_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/jobs"
)

func TestMemoryQueueEnqueueAndProcess(t *testing.T) {
	q := jobs.NewMemoryQueue(10 * time.Millisecond)

	var wg sync.WaitGroup
	var processedPayload string

	wg.Add(1)
	q.RegisterHandler("send_whatsapp_reminder", func(ctx context.Context, job *jobs.Job) error {
		defer wg.Done()
		var data struct {
			Phone string `json:"phone"`
		}
		if err := jobs.UnmarshalPayload(job.Payload, &data); err != nil {
			return err
		}
		processedPayload = data.Phone
		return nil
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	require.NoError(t, q.Start(ctx))
	defer q.Stop()

	jobID, err := q.Enqueue(ctx, "send_whatsapp_reminder", map[string]string{"phone": "+6281234567890"}, time.Now())
	require.NoError(t, err)
	assert.NotEmpty(t, jobID)

	wg.Wait()
	assert.Equal(t, "+6281234567890", processedPayload)

	// Check job status is completed
	time.Sleep(20 * time.Millisecond)
	j, err := q.GetJob(jobID)
	require.NoError(t, err)
	assert.Equal(t, jobs.StatusCompleted, j.Status)
}

func TestMemoryQueueRetryAndFail(t *testing.T) {
	q := jobs.NewMemoryQueue(10 * time.Millisecond)

	var attempts int
	var mu sync.Mutex

	q.RegisterHandler("failing_job", func(ctx context.Context, job *jobs.Job) error {
		mu.Lock()
		attempts++
		mu.Unlock()
		return errors.New("network down")
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	require.NoError(t, q.Start(ctx))
	defer q.Stop()

	jobID, err := q.Enqueue(ctx, "failing_job", nil, time.Now())
	require.NoError(t, err)

	// Wait for 1st attempt
	time.Sleep(30 * time.Millisecond)

	j, err := q.GetJob(jobID)
	require.NoError(t, err)
	assert.Equal(t, 1, j.Attempts)
	assert.NotNil(t, j.LastError)
	assert.Contains(t, *j.LastError, "network down")
}

func TestJobQueueConcurrentWorkersNoDuplicateProcessing(t *testing.T) {
	q := jobs.NewMemoryQueue(5 * time.Millisecond)
	q.SetWorkerCount(5) // 5 concurrent worker goroutines

	const totalJobs = 50
	var mu sync.Mutex
	executionCounts := make(map[string]int)
	var processedCount int
	var allDoneWg sync.WaitGroup
	allDoneWg.Add(totalJobs)

	q.RegisterHandler("concurrent_task", func(ctx context.Context, job *jobs.Job) error {
		defer allDoneWg.Done()

		mu.Lock()
		executionCounts[job.ID]++
		processedCount++
		mu.Unlock()

		// Simulate small processing time
		time.Sleep(2 * time.Millisecond)
		return nil
	})

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	require.NoError(t, q.Start(ctx))
	defer q.Stop()

	// Enqueue 50 jobs rapidly
	for i := 0; i < totalJobs; i++ {
		_, err := q.Enqueue(ctx, "concurrent_task", map[string]int{"idx": i}, time.Now())
		require.NoError(t, err)
	}

	// Wait for all jobs to be completed
	allDoneWg.Wait()

	mu.Lock()
	defer mu.Unlock()

	assert.Equal(t, totalJobs, processedCount, "Total processed count must equal enqueued count")
	assert.Equal(t, totalJobs, len(executionCounts), "Each unique job must be processed")

	for jobID, count := range executionCounts {
		assert.Equal(t, 1, count, "Job %s was executed %d times (expected exactly 1 without duplicates)", jobID, count)
	}
}
