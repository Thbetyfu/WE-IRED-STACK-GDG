package volunteer

import (
	"encoding/json"
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

			// Blocks CRUD
			r.Get("/blocks", h.HandleListBlocks)
			r.Post("/blocks", h.HandleCreateBlock)
			r.Delete("/blocks/{id}", h.HandleDeleteBlock)

			// Volunteers CRUD
			r.Get("/volunteers", h.HandleListVolunteers)
			r.Post("/volunteers", h.HandleRegisterVolunteer)
			r.Get("/volunteers/{id}", h.HandleGetVolunteer)
			r.Patch("/volunteers/{id}/availability", h.HandleSetAvailability)
			r.Post("/volunteers/{id}/blocks", h.HandleAssignBlocks)
		})
	})
}

func (h *Handler) HandleListBlocks(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	list, err := h.service.ListBlocks(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat daftar blok", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": list})
}

func (h *Handler) HandleCreateBlock(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var req Block
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.RTID = rtID
	created, err := h.service.CreateBlock(r.Context(), &req)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": created})
}

func (h *Handler) HandleDeleteBlock(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.service.DeleteBlock(r.Context(), id); err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Blok tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": map[string]string{"message": "Blok berhasil dihapus"}})
}

func (h *Handler) HandleListVolunteers(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	list, err := h.service.ListVolunteers(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat relawan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": list})
}

func (h *Handler) HandleRegisterVolunteer(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var req Volunteer
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.RTID = rtID
	created, err := h.service.RegisterVolunteer(r.Context(), &req)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": created})
}

func (h *Handler) HandleGetVolunteer(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	v, err := h.service.GetVolunteer(r.Context(), id)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Relawan tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"data": v})
}

type SetAvailabilityPayload struct {
	Available bool `json:"available"`
}

func (h *Handler) HandleSetAvailability(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req SetAvailabilityPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	if err := h.service.SetAvailability(r.Context(), id, req.Available); err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Relawan tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]interface{}{
			"user_id":   id,
			"available": req.Available,
			"message":   "Status ketersediaan berhasil diperbarui",
		},
	})
}

type AssignBlocksPayload struct {
	BlockIDs []string `json:"block_ids"`
}

func (h *Handler) HandleAssignBlocks(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req AssignBlocksPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	if err := h.service.AssignBlocks(r.Context(), id, req.BlockIDs); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "BAD_REQUEST", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]interface{}{
			"user_id":        id,
			"assigned_blocks": req.BlockIDs,
			"message":        "Penugasan blok relawan berhasil disimpan",
		},
	})
}
