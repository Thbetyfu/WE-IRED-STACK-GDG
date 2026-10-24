package announcement

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type Handler struct {
	service          *Service
	jwtSecret        []byte
	hierarchyChecker auth.RegionHierarchyChecker
}

func NewHandler(service *Service, jwtSecret []byte, checker auth.RegionHierarchyChecker) *Handler {
	return &Handler{
		service:          service,
		jwtSecret:        jwtSecret,
		hierarchyChecker: checker,
	}
}

func (h *Handler) Routes(r chi.Router) {
	// Public key endpoint for device provisioning & BLE verify
	r.Get("/api/v1/announcements/public-key", h.HandleGetPublicKey)

	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		// RT scoped routes
		r.Route("/rts/{rt}/announcements", func(r chi.Router) {
			r.Use(auth.RequireRTScope("rt", h.hierarchyChecker))

			r.Get("/", h.HandleListAnnouncements)
			r.Get("/latest-packet", h.HandleGetLatestSignedPacket)
			r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Post("/", h.HandleCreateAnnouncement)
		})

		// Global / single announcement routes
		r.Route("/announcements", func(r chi.Router) {
			r.Get("/{id}", h.HandleGetAnnouncement)
			r.Get("/public-key", h.HandleGetPublicKey)
		})

		// Posko delegation route
		r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Post("/posko/delegation", h.HandleCreatePoskoDelegation)
	})
}

type CreateAnnouncementPayload struct {
	Level      AnnouncementLevel `json:"level"`
	Text       string            `json:"text"`
	ExpiresAt  time.Time         `json:"expires_at"`
	IncidentID *string           `json:"incident_id,omitempty"`
	Channels   []string          `json:"channels"`
}

func (h *Handler) HandleCreateAnnouncement(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	claims := auth.ClaimsFromContext(r.Context())
	userID := ""
	if claims != nil {
		userID = claims.UserID
	}

	var payload CreateAnnouncementPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	if len(payload.Channels) == 0 {
		payload.Channels = []string{"push", "relay"}
	}

	result, err := h.service.CreateAnnouncement(r.Context(), CreateAnnouncementRequest{
		RegionIDs:  []string{rtID},
		IncidentID: payload.IncidentID,
		Level:      payload.Level,
		Text:       payload.Text,
		ExpiresAt:  payload.ExpiresAt,
		Channels:   payload.Channels,
		CreatedBy:  userID,
	})
	if err != nil {
		if errors.Is(err, ErrEmptyText) || errors.Is(err, ErrTextTooLong) ||
			errors.Is(err, ErrEmptyRegions) || errors.Is(err, ErrEmptyChannels) ||
			errors.Is(err, ErrExpirationInPast) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": result,
	})
}

func (h *Handler) HandleListAnnouncements(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	includeExpired, _ := strconv.ParseBool(r.URL.Query().Get("include_expired"))

	list, err := h.service.ListAnnouncements(r.Context(), rtID, includeExpired)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if list == nil {
		list = []*Announcement{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": list,
	})
}

func (h *Handler) HandleGetAnnouncement(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	ann, err := h.service.GetAnnouncement(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrAnnouncementNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": ann,
	})
}

func (h *Handler) HandleGetLatestSignedPacket(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	packet, err := h.service.GetLatestSignedPacket(r.Context(), rtID)
	if err != nil {
		if errors.Is(err, ErrAnnouncementNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Tidak ada pengumuman aktif", nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/octet-stream")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(packet)
}

func (h *Handler) HandleGetPublicKey(w http.ResponseWriter, r *http.Request) {
	pubKeyB64 := h.service.KeyManager().RootPublicKeyBase64()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": map[string]string{
			"algorithm":  "Ed25519",
			"public_key": pubKeyB64,
		},
	})
}

type DelegationRequestPayload struct {
	PoskoID     string `json:"posko_id"`
	RTID        string `json:"rt_id"`
	DurationDay int    `json:"duration_days"`
}

func (h *Handler) HandleCreatePoskoDelegation(w http.ResponseWriter, r *http.Request) {
	var payload DelegationRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	if payload.PoskoID == "" || payload.RTID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "posko_id dan rt_id wajib diisi", nil)
		return
	}

	duration := 7 * 24 * time.Hour
	if payload.DurationDay > 0 {
		duration = time.Duration(payload.DurationDay) * 24 * time.Hour
	}

	del, privKeyB64, err := h.service.CreatePoskoDelegation(r.Context(), payload.PoskoID, payload.RTID, duration)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": map[string]any{
			"delegation":        del,
			"posko_private_key": privKeyB64,
		},
	})
}
