package logger_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/logger"
)

func TestContextAttributes(t *testing.T) {
	var buf bytes.Buffer
	baseLog := logger.NewWithWriter("info", true, &buf)

	ctx := context.Background()
	ctx = logger.WithLogger(ctx, baseLog)
	ctx = logger.WithRequestID(ctx, "req-123")
	ctx = logger.WithIncidentID(ctx, "inc-456")
	ctx = logger.WithChannel(ctx, "ble_mesh")

	log := logger.FromContext(ctx)
	log.Info("test message")

	var output map[string]any
	require.NoError(t, json.Unmarshal(buf.Bytes(), &output))
	assert.Equal(t, "test message", output["msg"])
	assert.Equal(t, "req-123", output["request_id"])
	assert.Equal(t, "inc-456", output["incident_id"])
	assert.Equal(t, "ble_mesh", output["channel"])
}

func TestLoggerMiddleware(t *testing.T) {
	var buf bytes.Buffer
	baseLog := logger.NewWithWriter("info", true, &buf)

	handler := logger.Middleware(baseLog)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.Header.Set("X-Request-ID", "custom-req-id")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "custom-req-id", rec.Header().Get("X-Request-ID"))

	var output map[string]any
	require.NoError(t, json.Unmarshal(buf.Bytes(), &output))
	assert.Equal(t, "http request", output["msg"])
	assert.Equal(t, "custom-req-id", output["request_id"])
	assert.Equal(t, "GET", output["method"])
	assert.Equal(t, "/healthz", output["path"])
	assert.Equal(t, float64(200), output["status"])
}
