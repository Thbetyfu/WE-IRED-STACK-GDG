package auth

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Routes registers all auth endpoints under /api/v1/auth.
func (h *Handler) Routes(r chi.Router) {
	r.Route("/auth", func(r chi.Router) {
		r.Post("/otp/request", h.HandleRequestOTP)
		r.Post("/otp/verify", h.HandleVerifyOTP)
		r.Post("/login", h.HandleLogin)
		r.Post("/activate", h.HandleActivate)
		r.Post("/refresh", h.HandleRefresh)
		r.Post("/logout", h.HandleLogout)

		// Protected route to check token & get profile
		r.Group(func(r chi.Router) {
			r.Use(Authenticate(h.service.jwtSecret))
			r.Get("/me", h.HandleMe)
		})
	})
}

type OTPRequestPayload struct {
	Phone string `json:"phone"`
}

func (h *Handler) HandleRequestOTP(w http.ResponseWriter, r *http.Request) {
	var req OTPRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.Phone = strings.TrimSpace(req.Phone)
	if req.Phone == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Nomor WhatsApp wajib diisi", map[string]interface{}{"field": "phone"})
		return
	}

	_, err := h.service.RequestOTP(r.Context(), req.Phone)
	if err != nil {
		if errors.Is(err, ErrOTPRateLimited) {
			platformErrors.WriteJSON(w, http.StatusTooManyRequests, "RATE_LIMITED", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal mengirim OTP", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]interface{}{
			"message":    "Kode OTP berhasil dikirim via WhatsApp",
			"expires_in": 300, // 5 minutes
		},
	})
}

type OTPVerifyPayload struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

func (h *Handler) HandleVerifyOTP(w http.ResponseWriter, r *http.Request) {
	var req OTPVerifyPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.Phone = strings.TrimSpace(req.Phone)
	req.Code = strings.TrimSpace(req.Code)
	if req.Phone == "" || req.Code == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Nomor WhatsApp dan kode OTP wajib diisi", nil)
		return
	}

	result, err := h.service.VerifyOTP(r.Context(), req.Phone, req.Code)
	if err != nil {
		switch {
		case errors.Is(err, ErrOTPInvalid):
			platformErrors.WriteJSON(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", err.Error(), nil)
		case errors.Is(err, ErrOTPExpired):
			platformErrors.WriteJSON(w, http.StatusUnauthorized, "OTP_EXPIRED", err.Error(), nil)
		case errors.Is(err, ErrOTPMaxAttempts):
			platformErrors.WriteJSON(w, http.StatusTooManyRequests, "MAX_ATTEMPTS_EXCEEDED", err.Error(), nil)
		default:
			platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memverifikasi OTP", nil)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": result,
	})
}

type LoginPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *Handler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	var req LoginPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.Email = strings.TrimSpace(req.Email)
	if req.Email == "" || req.Password == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Email dan kata sandi wajib diisi", nil)
		return
	}

	result, err := h.service.LoginWithPassword(r.Context(), req.Email, req.Password)
	if err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			platformErrors.WriteJSON(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Email atau kata sandi tidak valid", nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": result,
	})
}

type ActivatePayload struct {
	InviteCode string `json:"invite_code"`
	Phone      string `json:"phone"`
	Code       string `json:"code"`
}

func (h *Handler) HandleActivate(w http.ResponseWriter, r *http.Request) {
	var req ActivatePayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.InviteCode = strings.TrimSpace(req.InviteCode)
	req.Phone = strings.TrimSpace(req.Phone)
	req.Code = strings.TrimSpace(req.Code)

	if req.InviteCode == "" || req.Phone == "" || req.Code == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Kode undangan, nomor WhatsApp, dan kode OTP wajib diisi", nil)
		return
	}

	result, err := h.service.ActivateAccount(r.Context(), req.InviteCode, req.Phone, req.Code)
	if err != nil {
		switch {
		case errors.Is(err, ErrHouseholdNotFound):
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
		case errors.Is(err, ErrOTPInvalid):
			platformErrors.WriteJSON(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Kode OTP salah", nil)
		case errors.Is(err, ErrOTPExpired):
			platformErrors.WriteJSON(w, http.StatusUnauthorized, "OTP_EXPIRED", "Kode OTP kedaluwarsa", nil)
		default:
			platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Aktivasi akun gagal: "+err.Error(), nil)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": result,
	})
}

type RefreshPayload struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) HandleRefresh(w http.ResponseWriter, r *http.Request) {
	var req RefreshPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.RefreshToken = strings.TrimSpace(req.RefreshToken)
	if req.RefreshToken == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Refresh token wajib disertakan", nil)
		return
	}

	result, err := h.service.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "INVALID_TOKEN", "Refresh token tidak valid atau telah dicabut", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": result,
	})
}

type LogoutPayload struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) HandleLogout(w http.ResponseWriter, r *http.Request) {
	var req LogoutPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.RefreshToken = strings.TrimSpace(req.RefreshToken)
	if req.RefreshToken != "" {
		_ = h.service.Logout(r.Context(), req.RefreshToken)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]interface{}{
			"message": "Berhasil keluar dari sesi",
		},
	})
}

func (h *Handler) HandleMe(w http.ResponseWriter, r *http.Request) {
	claims := ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Tidak terautentikasi", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]interface{}{
			"user_id":      claims.UserID,
			"phone":        claims.Phone,
			"role":         claims.Role,
			"region_id":    claims.RegionID,
			"household_id": claims.HouseholdID,
		},
	})
}
