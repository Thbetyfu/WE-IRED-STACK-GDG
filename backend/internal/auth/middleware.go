package auth

import (
	"context"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type contextKey string

const (
	claimsContextKey contextKey = "weired.auth.claims"
)

// RegionHierarchyChecker allows checking if an RT belongs to a parent region (RW/Kelurahan).
type RegionHierarchyChecker interface {
	IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error)
}

// Authenticate returns a middleware that validates Bearer JWT access tokens.
func Authenticate(jwtSecret []byte) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tokenString := ""
			authHeader := r.Header.Get("Authorization")
			if strings.HasPrefix(authHeader, "Bearer ") {
				tokenString = strings.TrimPrefix(authHeader, "Bearer ")
			} else if queryToken := r.URL.Query().Get("token"); queryToken != "" {
				// Query param token for WebSockets / direct file links
				tokenString = queryToken
			}

			if tokenString == "" {
				errors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Token autentikasi tidak ditemukan", nil)
				return
			}

			claims, err := ValidateAccessToken(jwtSecret, tokenString)
			if err != nil {
				errors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Token autentikasi tidak valid atau kedaluwarsa", nil)
				return
			}

			ctx := context.WithValue(r.Context(), claimsContextKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// ClaimsFromContext extracts validated JWT claims from the request context.
func ClaimsFromContext(ctx context.Context) *Claims {
	claims, ok := ctx.Value(claimsContextKey).(*Claims)
	if !ok {
		return nil
	}
	return claims
}

// RequireRole checks whether the authenticated user possesses one of the allowed roles.
func RequireRole(allowedRoles ...string) func(http.Handler) http.Handler {
	roleSet := make(map[string]struct{}, len(allowedRoles))
	for _, role := range allowedRoles {
		roleSet[role] = struct{}{}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims := ClaimsFromContext(r.Context())
			if claims == nil {
				errors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
				return
			}

			if _, ok := roleSet[claims.Role]; !ok {
				errors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", "Peran pengguna tidak memiliki hak akses untuk aksi ini", map[string]interface{}{
					"current_role":  claims.Role,
					"allowed_roles": allowedRoles,
				})
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// RequireRTScope enforces RT data isolation (FR-MRT-01).
// - operator: access all RTs
// - admin_wilayah: access RTs within their Kelurahan/RW
// - pengurus, relawan, kepala_keluarga: access their assigned RT only
func RequireRTScope(paramKey string, checker RegionHierarchyChecker) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims := ClaimsFromContext(r.Context())
			if claims == nil {
				errors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
				return
			}

			rtID := chi.URLParam(r, paramKey)
			if rtID == "" {
				// Also check query param fallback
				rtID = r.URL.Query().Get(paramKey)
			}

			if rtID == "" {
				errors.WriteJSON(w, http.StatusBadRequest, "BAD_REQUEST", "Parameter RT tidak ditemukan", nil)
				return
			}

			// 1. Operator has full system scope
			if claims.Role == "operator" {
				next.ServeHTTP(w, r)
				return
			}

			// 2. Direct RT match
			if claims.RegionID == rtID {
				next.ServeHTTP(w, r)
				return
			}

			// 3. Admin Wilayah hierarchy check
			if claims.Role == "admin_wilayah" && checker != nil {
				inScope, err := checker.IsRTInRegion(r.Context(), rtID, claims.RegionID)
				if err == nil && inScope {
					next.ServeHTTP(w, r)
					return
				}
			}

			errors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN_SCOPE", "Akses ditolak: Wilayah RT di luar lingkup kewenangan Anda", map[string]interface{}{
				"target_rt":   rtID,
				"user_region": claims.RegionID,
				"role":        claims.Role,
			})
		})
	}
}

// RequireHouseholdScope enforces data isolation for citizen accounts (FR-HH-01 s.d. FR-HH-05).
// Kepala keluarga can only access their own household ID.
func RequireHouseholdScope(paramKey string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims := ClaimsFromContext(r.Context())
			if claims == nil {
				errors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
				return
			}

			// Operators, pengurus, relawan, and admin_wilayah have administrative scope within their RT
			if claims.Role != "kepala_keluarga" {
				next.ServeHTTP(w, r)
				return
			}

			targetHouseholdID := chi.URLParam(r, paramKey)
			if targetHouseholdID == "" {
				targetHouseholdID = r.URL.Query().Get(paramKey)
			}

			if targetHouseholdID == "" || claims.HouseholdID != targetHouseholdID {
				errors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN_SCOPE", "Akses ditolak: Anda hanya dapat mengakses data rumah tangga Anda sendiri", map[string]interface{}{
					"household_id": targetHouseholdID,
				})
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
