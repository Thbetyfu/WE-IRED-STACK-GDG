package logger

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
)

type contextKey string

const (
	keyRequestID  contextKey = "weired_request_id"
	keyIncidentID contextKey = "weired_incident_id"
	keyChannel    contextKey = "weired_channel"
	keyLogger     contextKey = "weired_logger"
)

// New initializes an *slog.Logger with structured JSON or text output.
func New(levelStr string, isJSON bool) *slog.Logger {
	return NewWithWriter(levelStr, isJSON, os.Stdout)
}

// NewWithWriter initializes an *slog.Logger with a custom writer (useful for tests).
func NewWithWriter(levelStr string, isJSON bool, w io.Writer) *slog.Logger {
	var level slog.Level
	switch strings.ToLower(strings.TrimSpace(levelStr)) {
	case "debug":
		level = slog.LevelDebug
	case "warn", "warning":
		level = slog.LevelWarn
	case "error":
		level = slog.LevelError
	default:
		level = slog.LevelInfo
	}

	opts := &slog.HandlerOptions{
		Level: level,
	}

	var handler slog.Handler
	if isJSON {
		handler = slog.NewJSONHandler(w, opts)
	} else {
		handler = slog.NewTextHandler(w, opts)
	}

	return slog.New(handler)
}

// Context helpers
func WithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, keyRequestID, requestID)
}

func RequestIDFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(keyRequestID).(string); ok {
		return v
	}
	return ""
}

func WithIncidentID(ctx context.Context, incidentID string) context.Context {
	return context.WithValue(ctx, keyIncidentID, incidentID)
}

func IncidentIDFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(keyIncidentID).(string); ok {
		return v
	}
	return ""
}

func WithChannel(ctx context.Context, channel string) context.Context {
	return context.WithValue(ctx, keyChannel, channel)
}

func ChannelFromContext(ctx context.Context) string {
	if v, ok := ctx.Value(keyChannel).(string); ok {
		return v
	}
	return ""
}

// WithLogger associates a specific logger with the context.
func WithLogger(ctx context.Context, log *slog.Logger) context.Context {
	return context.WithValue(ctx, keyLogger, log)
}

// FromContext extracts the logger with contextual attributes (request_id, incident_id, channel)
// or returns the default logger enriched with them.
func FromContext(ctx context.Context) *slog.Logger {
	base, ok := ctx.Value(keyLogger).(*slog.Logger)
	if !ok || base == nil {
		base = slog.Default()
	}

	var attrs []any
	if reqID := RequestIDFromContext(ctx); reqID != "" {
		attrs = append(attrs, "request_id", reqID)
	}
	if incID := IncidentIDFromContext(ctx); incID != "" {
		attrs = append(attrs, "incident_id", incID)
	}
	if ch := ChannelFromContext(ctx); ch != "" {
		attrs = append(attrs, "channel", ch)
	}

	if len(attrs) > 0 {
		return base.With(attrs...)
	}
	return base
}

type responseRecorder struct {
	http.ResponseWriter
	statusCode int
	bytes      int
}

func (r *responseRecorder) WriteHeader(code int) {
	r.statusCode = code
	r.ResponseWriter.WriteHeader(code)
}

func (r *responseRecorder) Write(b []byte) (int, error) {
	if r.statusCode == 0 {
		r.statusCode = http.StatusOK
	}
	n, err := r.ResponseWriter.Write(b)
	r.bytes += n
	return n, err
}

// Middleware creates an HTTP middleware that manages RequestID and logs HTTP access.
func Middleware(baseLogger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()

			reqID := r.Header.Get("X-Request-ID")
			if reqID == "" {
				reqID = uuid.NewString()
			}
			w.Header().Set("X-Request-ID", reqID)

			ctx := WithRequestID(r.Context(), reqID)
			ctx = WithLogger(ctx, baseLogger)

			rec := &responseRecorder{
				ResponseWriter: w,
				statusCode:     http.StatusOK,
			}

			next.ServeHTTP(rec, r.WithContext(ctx))

			duration := time.Since(start)
			log := FromContext(ctx)

			// Log level based on HTTP response status
			level := slog.LevelInfo
			if rec.statusCode >= 500 {
				level = slog.LevelError
			} else if rec.statusCode >= 400 {
				level = slog.LevelWarn
			}

			log.Log(ctx, level, "http request",
				"method", r.Method,
				"path", r.URL.Path,
				"status", rec.statusCode,
				"duration_ms", duration.Milliseconds(),
				"bytes", rec.bytes,
				"remote_addr", r.RemoteAddr,
			)
		})
	}
}
