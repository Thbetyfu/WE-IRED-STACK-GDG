package assembly

import (
	"encoding/json"
	"errors"
	"net/http"

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
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		r.Route("/rts/{rt}", func(r chi.Router) {
			r.Use(auth.RequireRTScope("rt", h.hierarchyChecker))

			// Assembly points CRUD
			r.Get("/assembly-points", h.HandleList)
			r.Post("/assembly-points", h.HandleCreate)
			r.Get("/assembly-points/{id}", h.HandleGet)
			r.Patch("/assembly-points/{id}", h.HandleUpdate)
			r.Delete("/assembly-points/{id}", h.HandleDelete)

			// Block mapping
			r.Post("/blocks/{block}/assembly-points", h.HandleSetBlockMapping)
			r.Get("/blocks/{block}/assembly-points", h.HandleGetBlockMapping)
		})
	})
}

func (h *Handler) HandleList(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	activeOnly := r.URL.Query().Get("active") == "true"

	list, err := h.service.ListAssemblyPoints(r.Context(), rtID, activeOnly)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat titik kumpul", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": list})
}

func (h *Handler) HandleCreate(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var req AssemblyPoint
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.RTID = rtID
	created, err := h.service.CreateAssemblyPoint(r.Context(), &req)
	if err != nil {
		if errors.Is(err, ErrInvalidCapacity) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": created})
}

func (h *Handler) HandleGet(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	ap, err := h.service.GetAssemblyPoint(r.Context(), id)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Titik kumpul tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": ap})
}

func (h *Handler) HandleUpdate(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req AssemblyPoint
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.ID = id
	if err := h.service.UpdateAssemblyPoint(r.Context(), &req); err != nil {
		if errors.Is(err, ErrAssemblyPointNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": map[string]string{"message": "Titik kumpul berhasil diperbarui"}})
}

func (h *Handler) HandleDelete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.service.DeleteAssemblyPoint(r.Context(), id); err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Titik kumpul tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": map[string]string{"message": "Titik kumpul berhasil dihapus"}})
}

type SetBlockMappingPayload struct {
	PrimaryAPID   string `json:"primary_ap_id"`
	SecondaryAPID string `json:"secondary_ap_id"`
}

func (h *Handler) HandleSetBlockMapping(w http.ResponseWriter, r *http.Request) {
	blockID := chi.URLParam(r, "block")
	var req SetBlockMappingPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	if err := h.service.MapBlockAssemblyPoints(r.Context(), blockID, req.PrimaryAPID, req.SecondaryAPID); err != nil {
		if errors.Is(err, ErrSameAssemblyPoint) || errors.Is(err, ErrInactiveAssemblyPoint) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{"message": "Pemetaan titik kumpul utama dan cadangan berhasil disimpan"},
	})
}

func (h *Handler) HandleGetBlockMapping(w http.ResponseWriter, r *http.Request) {
	blockID := chi.URLParam(r, "block")
	mapping, err := h.service.GetBlockAssemblyPoints(r.Context(), blockID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat pemetaan titik kumpul", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": mapping})
}
