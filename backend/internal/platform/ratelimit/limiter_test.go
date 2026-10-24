package ratelimit_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	apperrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/ratelimit"
)

func TestLimiterAllowAndBurst(t *testing.T) {
	lim := ratelimit.New(ratelimit.Config{
		RequestsPerSecond: 10,
		Burst:             3,
		EntryTTL:          1 * time.Minute,
	})
	defer lim.Close()

	key := "test-client"

	// 3 requests allowed (burst = 3)
	for i := 0; i < 3; i++ {
		allowed, _ := lim.Allow(key)
		assert.True(t, allowed, "Request %d should be allowed", i+1)
	}

	// 4th request immediately rejected
	allowed, retryAfter := lim.Allow(key)
	assert.False(t, allowed)
	assert.Greater(t, retryAfter, 0)
}

func TestLimiterMiddlewareIntegration(t *testing.T) {
	lim := ratelimit.New(ratelimit.Config{
		RequestsPerSecond: 1,
		Burst:             1,
		EntryTTL:          1 * time.Minute,
	})
	defer lim.Close()

	handler := lim.Middleware()(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("success"))
	}))

	// First request succeeds
	req1 := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	req1.RemoteAddr = "192.168.1.100:12345"
	rec1 := httptest.NewRecorder()
	handler.ServeHTTP(rec1, req1)
	assert.Equal(t, http.StatusOK, rec1.Code)

	// Second request immediately fails with 429
	req2 := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	req2.RemoteAddr = "192.168.1.100:12345"
	rec2 := httptest.NewRecorder()
	handler.ServeHTTP(rec2, req2)
	assert.Equal(t, http.StatusTooManyRequests, rec2.Code)
	assert.NotEmpty(t, rec2.Header().Get("Retry-After"))

	var resp apperrors.ErrorResponse
	require.NoError(t, json.Unmarshal(rec2.Body.Bytes(), &resp))
	assert.Equal(t, "RATE_LIMITED", resp.Error.Code)
	assert.Contains(t, resp.Error.Details, "retry_after_seconds")

	// Another client from different IP is still allowed
	req3 := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	req3.RemoteAddr = "192.168.1.101:12345"
	rec3 := httptest.NewRecorder()
	handler.ServeHTTP(rec3, req3)
	assert.Equal(t, http.StatusOK, rec3.Code)
}
