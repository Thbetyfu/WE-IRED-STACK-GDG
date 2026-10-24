package metrics_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/metrics"
)

func TestMetricsCollectionAndEndpoint(t *testing.T) {
	m := metrics.New()
	require.NotNil(t, m)

	// Record sample metrics
	m.ReportsTotal.WithLabelValues("ble_mesh", "butuh_bantuan", "banjir").Inc()
	m.WebSocketConnections.Set(5)
	m.JobsQueued.WithLabelValues("pending").Set(12)

	handler := m.Handler()

	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusOK, rec.Code)
	body := rec.Body.String()

	assert.Contains(t, body, "weired_reports_total")
	assert.Contains(t, body, "channel=\"ble_mesh\"")
	assert.Contains(t, body, "weired_websocket_connections 5")
	assert.Contains(t, body, "weired_jobs_queued{status=\"pending\"} 12")
}

func TestHTTPMiddlewareMetrics(t *testing.T) {
	m := metrics.New()

	router := m.HTTPMiddleware()(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusCreated)
	}))

	req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	assert.Equal(t, http.StatusCreated, rec.Code)

	metricsRec := httptest.NewRecorder()
	m.Handler().ServeHTTP(metricsRec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	body := metricsRec.Body.String()

	assert.Contains(t, body, "weired_http_duration_seconds_count")
	assert.Contains(t, body, "method=\"POST\"")
	assert.Contains(t, body, "status=\"201\"")
}
