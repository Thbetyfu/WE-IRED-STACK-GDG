package server_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/config"
	apperrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/server"
)

type mockPinger struct {
	err error
}

func (m *mockPinger) Ping(ctx context.Context) error {
	return m.err
}

func TestHealthzEndpoint_Healthy(t *testing.T) {
	cfg := config.Default()
	cfg.Mode = config.ModeCloud
	cfg.Role = config.RoleAll

	srv := server.New(server.Options{
		Config:   cfg,
		DBPinger: &mockPinger{err: nil},
	})

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "application/json; charset=utf-8", rec.Header().Get("Content-Type"))

	var resp server.HealthResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, "ok", resp.Status)
	assert.Equal(t, "cloud", resp.Mode)
	assert.Equal(t, "all", resp.Role)
	assert.Equal(t, "connected", resp.Database)
	assert.NotEmpty(t, resp.Uptime)
	assert.NotEmpty(t, resp.Timestamp)
}

func TestHealthzEndpoint_Degraded(t *testing.T) {
	cfg := config.Default()
	cfg.Mode = config.ModeCloud
	cfg.Role = config.RoleAll

	srv := server.New(server.Options{
		Config:   cfg,
		DBPinger: &mockPinger{err: errors.New("connection refused")},
	})

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)

	var resp server.HealthResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, "degraded", resp.Status)
	assert.Equal(t, "error", resp.Database)
}

func TestHealthzEndpoint_NotConfigured(t *testing.T) {
	cfg := config.Default()
	cfg.Mode = config.ModeCloud
	cfg.Role = config.RoleAll

	srv := server.New(server.Options{
		Config: cfg,
	})

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	assert.Equal(t, http.StatusServiceUnavailable, rec.Code)

	var resp server.HealthResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, "degraded", resp.Status)
	assert.Equal(t, "not_configured", resp.Database)
}

func TestMetricsEndpoint(t *testing.T) {
	srv := server.New(server.Options{
		Config:   config.Default(),
		DBPinger: &mockPinger{err: nil},
	})

	// Warmup request to ensure HTTP metrics middleware observes at least one request
	warmupReq := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	warmupRec := httptest.NewRecorder()
	srv.Router().ServeHTTP(warmupRec, warmupReq)
	assert.Equal(t, http.StatusOK, warmupRec.Code)

	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Contains(t, rec.Body.String(), "weired_websocket_connections")
	assert.Contains(t, rec.Body.String(), "weired_http_duration_seconds")
}

func TestPanicRecovery(t *testing.T) {
	srv := server.New(server.Options{
		Config: config.Default(),
	})

	srv.MountAPI(func(r chi.Router) {
		r.Get("/panic", func(w http.ResponseWriter, r *http.Request) {
			panic("unexpected internal crash")
		})
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/panic", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	assert.Equal(t, http.StatusInternalServerError, rec.Code)

	var errResp apperrors.ErrorResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &errResp))
	assert.Equal(t, apperrors.CodeInternalError, errResp.Error.Code)
	assert.Equal(t, "Terjadi kesalahan pada sistem", errResp.Error.Message)
}

func TestCORSPreflight(t *testing.T) {
	srv := server.New(server.Options{
		Config: config.Default(),
	})

	req := httptest.NewRequest(http.MethodOptions, "/healthz", nil)
	req.Header.Set("Origin", "http://localhost:3000")
	req.Header.Set("Access-Control-Request-Method", "GET")
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "*", rec.Header().Get("Access-Control-Allow-Origin"))
}
