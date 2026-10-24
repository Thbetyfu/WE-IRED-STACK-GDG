package sync

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

type Handler struct {
	service   *Service
	jwtSecret []byte
}

func NewHandler(service *Service, jwtSecret []byte) *Handler {
	return &Handler{
		service:   service,
		jwtSecret: jwtSecret,
	}
}

func (h *Handler) Routes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		r.Post("/sync/reports", h.HandleSyncReports)
		r.Post("/sync/relay-packets", h.HandleSyncRelayPackets)
		r.Get("/sync/snapshot", h.HandleGetSnapshot)
		r.Get("/sync/acks", h.HandleGetAcks)
	})
}

func (h *Handler) HandleSyncReports(w http.ResponseWriter, r *http.Request) {
	var reports []*report.Report
	if err := json.NewDecoder(r.Body).Decode(&reports); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid (harus array laporan)", nil)
		return
	}

	results, err := h.service.SyncReports(r.Context(), reports)
	if err != nil {
		if errors.Is(err, ErrBatchTooLarge) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": results,
	})
}

func (h *Handler) HandleSyncRelayPackets(w http.ResponseWriter, r *http.Request) {
	var req RelaySyncRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	claims := auth.ClaimsFromContext(r.Context())
	if req.CollectorID == "" && claims != nil {
		req.CollectorID = claims.UserID
	}

	results, err := h.service.SyncRelayPackets(r.Context(), req)
	if err != nil {
		if errors.Is(err, ErrBatchTooLarge) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": results,
	})
}

func (h *Handler) HandleGetSnapshot(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	scope := r.URL.Query().Get("scope")
	snapshot, err := h.service.GetSnapshot(r.Context(), scope, claims.UserID, claims.Role, claims.RegionID, claims.HouseholdID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": snapshot,
	})
}

func (h *Handler) HandleGetAcks(w http.ResponseWriter, r *http.Request) {
	incidentID := r.URL.Query().Get("incident")
	if incidentID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Parameter 'incident' wajib diisi", nil)
		return
	}

	acks, err := h.service.GetAcks(r.Context(), incidentID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": acks,
	})
}
