package posko

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

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
	// Public QR endpoint for volunteer app pairing
	r.Get("/posko/qr-config", h.HandleGetQRConfig)

	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		// Snapshot Export & Import
		r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Post("/posko/snapshot", h.HandleExportSnapshot)
		r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Post("/posko/snapshot/import", h.HandleImportSnapshot)
		r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Get("/posko/status", h.HandleGetStatus)

		// Push & Pull
		r.Post("/posko/push", h.HandlePush)
		r.Get("/posko/pull", h.HandlePull)

		// Conflict Management
		r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Get("/posko/conflicts", h.HandleListConflicts)
		r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Post("/posko/conflicts/{id}/resolve", h.HandleResolveConflict)
	})
}

type ExportSnapshotPayload struct {
	RTID     string `json:"rt_id"`
	Password string `json:"password"`
}

func (h *Handler) HandleExportSnapshot(w http.ResponseWriter, r *http.Request) {
	var payload ExportSnapshotPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	if payload.RTID == "" || payload.Password == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "rt_id dan password wajib diisi", nil)
		return
	}

	env, err := h.service.ExportSnapshot(r.Context(), payload.RTID, payload.Password)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": env,
	})
}

type ImportSnapshotPayload struct {
	Envelope EncryptedSnapshotEnvelope `json:"envelope"`
	Password string                    `json:"password"`
}

func (h *Handler) HandleImportSnapshot(w http.ResponseWriter, r *http.Request) {
	var payload ImportSnapshotPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	imported, err := h.service.ImportSnapshot(r.Context(), &payload.Envelope, payload.Password)
	if err != nil {
		if errors.Is(err, ErrInvalidSnapshotPassword) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "AUTHENTICATION_FAILED", "Kata sandi snapshot salah atau data rusak", nil)
			return
		}
		if errors.Is(err, ErrMalformedSnapshot) || errors.Is(err, ErrEmptyPassword) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": map[string]any{
			"status":      "imported",
			"rt_id":       imported.RTID,
			"households":  len(imported.Households),
			"volunteers":  len(imported.Volunteers),
			"last_cursor": imported.LastEventID,
		},
	})
}

func (h *Handler) HandlePush(w http.ResponseWriter, r *http.Request) {
	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	resp, err := h.service.ProcessPush(r.Context(), req)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": resp,
	})
}

func (h *Handler) HandlePull(w http.ResponseWriter, r *http.Request) {
	rtID := r.URL.Query().Get("rt_id")
	cursorStr := r.URL.Query().Get("cursor")
	cursor, _ := strconv.ParseInt(cursorStr, 10, 64)

	limitStr := r.URL.Query().Get("limit")
	limit, _ := strconv.Atoi(limitStr)

	resp, err := h.service.ProcessPull(r.Context(), rtID, cursor, limit)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": resp,
	})
}

func (h *Handler) HandleGetQRConfig(w http.ResponseWriter, r *http.Request) {
	rtID := r.URL.Query().Get("rt_id")
	endpointURL := r.URL.Query().Get("endpoint_url")
	fingerprint := r.URL.Query().Get("fingerprint")
	sslStr := r.URL.Query().Get("ssl")
	ssl, _ := strconv.ParseBool(sslStr)

	qrConfig, err := h.service.GenerateQRConfig(endpointURL, ssl, fingerprint, rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": qrConfig,
	})
}

func (h *Handler) HandleListConflicts(w http.ResponseWriter, r *http.Request) {
	rtID := r.URL.Query().Get("rt_id")
	status := r.URL.Query().Get("status")

	conflicts, err := h.service.ListConflicts(r.Context(), rtID, status)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if conflicts == nil {
		conflicts = []*SyncConflict{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": conflicts,
	})
}

func (h *Handler) HandleResolveConflict(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	userID := ""
	if claims != nil {
		userID = claims.UserID
	}

	err := h.service.ResolveConflict(r.Context(), id, userID)
	if err != nil {
		if errors.Is(err, ErrConflictNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": map[string]string{
			"status": "resolved",
		},
	})
}

func (h *Handler) HandleGetStatus(w http.ResponseWriter, r *http.Request) {
	rtID := r.URL.Query().Get("rt_id")
	status, err := h.service.GetStatus(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": status,
	})
}
