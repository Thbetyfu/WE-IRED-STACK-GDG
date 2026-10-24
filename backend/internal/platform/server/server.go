package server

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/config"
	apperrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/logger"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/metrics"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/ratelimit"
)

// DBPinger defines an interface for health check database pings.
type DBPinger interface {
	Ping(ctx context.Context) error
}

// Server encapsulates the HTTP server, router, and platform dependencies.
type Server struct {
	cfg        *config.Config
	log        *slog.Logger
	pool       *pgxpool.Pool
	dbPinger   DBPinger
	limiter    *ratelimit.Limiter
	metrics    *metrics.Metrics
	router     *chi.Mux
	httpServer *http.Server
	startTime  time.Time
}

// HealthResponse represents the payload returned by /healthz.
type HealthResponse struct {
	Status    string `json:"status"`
	Mode      string `json:"mode"`
	Role      string `json:"role"`
	Database  string `json:"database"`
	Uptime    string `json:"uptime"`
	Timestamp string `json:"timestamp"`
}

// Options allows configuring dependencies when initializing the Server.
type Options struct {
	Config   *config.Config
	Logger   *slog.Logger
	Pool     *pgxpool.Pool
	DBPinger DBPinger
	Limiter  *ratelimit.Limiter
	Metrics  *metrics.Metrics
}

// New creates and configures a new Server instance.
func New(opts Options) *Server {
	if opts.Config == nil {
		opts.Config = config.Default()
	}
	if opts.Logger == nil {
		opts.Logger = logger.New(opts.Config.LogLevel, true)
	}
	if opts.Limiter == nil {
		opts.Limiter = ratelimit.New(ratelimit.DefaultConfig())
	}
	if opts.Metrics == nil {
		opts.Metrics = metrics.New()
	}

	pinger := opts.DBPinger
	if pinger == nil && opts.Pool != nil {
		pinger = opts.Pool
	}

	s := &Server{
		cfg:       opts.Config,
		log:       opts.Logger,
		pool:      opts.Pool,
		dbPinger:  pinger,
		limiter:   opts.Limiter,
		metrics:   opts.Metrics,
		startTime: time.Now(),
	}

	s.setupRoutes()

	s.httpServer = &http.Server{
		Addr:         opts.Config.HTTPAddr,
		Handler:      s.router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	return s
}

func (s *Server) setupRoutes() {
	r := chi.NewRouter()

	// 1. CORS
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-ID", "X-User-ID", "X-Beacon-Id", "X-Signature", "X-Timestamp"},
		ExposedHeaders:   []string{"Link", "Retry-After", "X-Request-ID", "X-RateLimit-Limit"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// 2. Metrics & Observability Middleware
	r.Use(s.metrics.HTTPMiddleware())
	r.Use(logger.Middleware(s.log))

	// 3. Panic Recovery formatting as SDD 9.7 standard JSON error
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					s.log.ErrorContext(r.Context(), "panic recovered in HTTP handler", "panic", rec)
					apperrors.Write(w, r, apperrors.Internal(fmt.Errorf("panic: %v", rec)))
				}
			}()
			next.ServeHTTP(w, r)
		})
	})

	// 4. Rate Limiting Middleware
	r.Use(s.limiter.Middleware())

	// Core Observability Endpoints
	r.Get("/healthz", s.handleHealthz)
	r.Handle("/metrics", s.metrics.Handler())

	s.router = r
}

// Router returns the underlying Chi router for mounting domain modules.
func (s *Server) Router() *chi.Mux {
	return s.router
}

// MountAPI mounts sub-routes onto /api/v1.
func (s *Server) MountAPI(fn func(r chi.Router)) {
	s.router.Route("/api/v1", fn)
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	dbStatus := "disconnected"
	isHealthy := true

	if s.dbPinger != nil {
		pingCtx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := s.dbPinger.Ping(pingCtx); err == nil {
			dbStatus = "connected"
		} else {
			dbStatus = "error"
			isHealthy = false
		}
	} else if s.cfg.Role == config.RoleAPI || s.cfg.Role == config.RoleAll {
		// No pool configured for active API role
		dbStatus = "not_configured"
		isHealthy = false
	}

	uptime := time.Since(s.startTime).Round(time.Second).String()
	statusText := "ok"
	statusCode := http.StatusOK

	if !isHealthy {
		statusText = "degraded"
		statusCode = http.StatusServiceUnavailable
	}

	resp := HealthResponse{
		Status:    statusText,
		Mode:      string(s.cfg.Mode),
		Role:      string(s.cfg.Role),
		Database:  dbStatus,
		Uptime:    uptime,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(resp)
}

// SetTLSConfig configures the HTTP server with TLS.
func (s *Server) SetTLSConfig(tlsConfig *tls.Config) {
	s.httpServer.TLSConfig = tlsConfig
}

// Start launches the HTTP or HTTPS listener.
func (s *Server) Start() error {
	s.log.Info("starting WE-IRED backend server",
		"addr", s.cfg.HTTPAddr,
		"mode", s.cfg.Mode,
		"role", s.cfg.Role,
		"tls", s.httpServer.TLSConfig != nil,
	)
	if s.httpServer.TLSConfig != nil {
		if err := s.httpServer.ListenAndServeTLS("", ""); err != nil && err != http.ErrServerClosed {
			return fmt.Errorf("https server failure: %w", err)
		}
		return nil
	}
	if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return fmt.Errorf("http server failure: %w", err)
	}
	return nil
}

// Shutdown gracefully stops the HTTP server.
func (s *Server) Shutdown(ctx context.Context) error {
	s.limiter.Close()
	return s.httpServer.Shutdown(ctx)
}
