package metrics

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics encapsulates all Prometheus metrics collectors per SDD 14.
type Metrics struct {
	Registry             *prometheus.Registry
	ReportsTotal         *prometheus.CounterVec
	HTTPDuration         *prometheus.HistogramVec
	JobsTotal            *prometheus.CounterVec
	JobsQueued           *prometheus.GaugeVec
	WhatsAppFailures     *prometheus.CounterVec
	WebSocketConnections prometheus.Gauge
}

// New creates and registers WE-IRED Prometheus metrics.
func New() *Metrics {
	reg := prometheus.NewRegistry()

	m := &Metrics{
		Registry: reg,
		ReportsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "weired",
				Name:      "reports_total",
				Help:      "Total count of reports received grouped by channel, status, and hazard.",
			},
			[]string{"channel", "status", "hazard"},
		),
		HTTPDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Namespace: "weired",
				Name:      "http_duration_seconds",
				Help:      "Latency of HTTP requests in seconds.",
				Buckets:   prometheus.DefBuckets,
			},
			[]string{"method", "path", "status"},
		),
		JobsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "weired",
				Name:      "jobs_total",
				Help:      "Total count of processed background jobs.",
			},
			[]string{"type", "status"},
		),
		JobsQueued: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Namespace: "weired",
				Name:      "jobs_queued",
				Help:      "Current number of jobs in the queue by status.",
			},
			[]string{"status"},
		),
		WhatsAppFailures: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: "weired",
				Name:      "whatsapp_failures_total",
				Help:      "Total WhatsApp delivery failures by template and error type.",
			},
			[]string{"template", "error_type"},
		),
		WebSocketConnections: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: "weired",
				Name:      "websocket_connections",
				Help:      "Current active WebSocket client connections.",
			},
		),
	}

	reg.MustRegister(
		m.ReportsTotal,
		m.HTTPDuration,
		m.JobsTotal,
		m.JobsQueued,
		m.WhatsAppFailures,
		m.WebSocketConnections,
	)

	return m
}

// Handler returns the Prometheus HTTP metrics handler for this registry.
func (m *Metrics) Handler() http.Handler {
	return promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{
		EnableOpenMetrics: true,
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

// HTTPMiddleware measures HTTP request durations and status codes.
func (m *Metrics) HTTPMiddleware() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

			next.ServeHTTP(rec, r)

			duration := time.Since(start).Seconds()
			m.HTTPDuration.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(rec.status)).Observe(duration)
		})
	}
}
