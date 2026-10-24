package ratelimit

import (
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	apperrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type clientBucket struct {
	tokens     float64
	lastRefill time.Time
}

// Limiter provides thread-safe in-memory rate limiting per user and per IP.
type Limiter struct {
	mu           sync.Mutex
	buckets      map[string]*clientBucket
	rate         float64       // tokens per second
	burst        float64       // max tokens
	entryTTL     time.Duration // how long to keep idle buckets
	cleanupEvery time.Duration
	stopChan     chan struct{}
}

// Config defines the rate limiting parameters.
type Config struct {
	RequestsPerSecond float64
	Burst             int
	EntryTTL          time.Duration
}

// DefaultConfig provides sensible defaults (e.g., 20 req/s, burst 50).
func DefaultConfig() Config {
	return Config{
		RequestsPerSecond: 20,
		Burst:             50,
		EntryTTL:          10 * time.Minute,
	}
}

// New creates a new Limiter and starts a background cleanup worker.
func New(cfg Config) *Limiter {
	if cfg.RequestsPerSecond <= 0 {
		cfg.RequestsPerSecond = 20
	}
	if cfg.Burst <= 0 {
		cfg.Burst = 50
	}
	if cfg.EntryTTL <= 0 {
		cfg.EntryTTL = 10 * time.Minute
	}

	l := &Limiter{
		buckets:      make(map[string]*clientBucket),
		rate:         cfg.RequestsPerSecond,
		burst:        float64(cfg.Burst),
		entryTTL:     cfg.EntryTTL,
		cleanupEvery: 1 * time.Minute,
		stopChan:     make(chan struct{}),
	}

	go l.cleanupLoop()
	return l
}

// Close stops the background cleanup worker.
func (l *Limiter) Close() {
	select {
	case <-l.stopChan:
		return
	default:
		close(l.stopChan)
	}
}

// Allow checks if a request with key is allowed, and returns (allowed, retryAfterSeconds).
func (l *Limiter) Allow(key string) (bool, int) {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	b, exists := l.buckets[key]
	if !exists {
		b = &clientBucket{
			tokens:     l.burst,
			lastRefill: now,
		}
		l.buckets[key] = b
	}

	// Refill tokens based on elapsed time
	elapsed := now.Sub(b.lastRefill).Seconds()
	b.lastRefill = now
	b.tokens += elapsed * l.rate
	if b.tokens > l.burst {
		b.tokens = l.burst
	}

	// Consume 1 token if available
	if b.tokens >= 1.0 {
		b.tokens -= 1.0
		return true, 0
	}

	// Calculate wait time until at least 1 token is available
	missing := 1.0 - b.tokens
	retryAfter := int(missing/l.rate) + 1
	return false, retryAfter
}

func (l *Limiter) cleanupLoop() {
	ticker := time.NewTicker(l.cleanupEvery)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			l.mu.Lock()
			now := time.Now()
			for k, b := range l.buckets {
				if now.Sub(b.lastRefill) > l.entryTTL {
					delete(l.buckets, k)
				}
			}
			l.mu.Unlock()
		case <-l.stopChan:
			return
		}
	}
}

// ExtractClientKey extracts client identifier: prioritized by user identifier, falling back to IP.
func ExtractClientKey(r *http.Request) string {
	// If an authenticated user ID is in headers (or downstream context)
	if uid := r.Header.Get("X-User-ID"); uid != "" {
		return "user:" + strings.TrimSpace(uid)
	}

	// Otherwise use client IP
	return "ip:" + extractIP(r)
}

func extractIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		ip := strings.TrimSpace(parts[0])
		if ip != "" {
			return ip
		}
	}
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return strings.TrimSpace(xrip)
	}

	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil && host != "" {
		return host
	}
	return r.RemoteAddr
}

// Middleware returns an HTTP middleware that enforces rate limiting per client key.
func (l *Limiter) Middleware() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := ExtractClientKey(r)
			allowed, retryAfter := l.Allow(key)
			if !allowed {
				w.Header().Set("Retry-After", strconv.Itoa(retryAfter))
				apperrors.Write(w, r, apperrors.RateLimited(retryAfter))
				return
			}

			w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%.0f", l.rate))
			next.ServeHTTP(w, r)
		})
	}
}
