package synthetic

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type Handler struct {
	generator        *Generator
	jwtSecret        []byte
	hierarchyChecker auth.RegionHierarchyChecker
}

func NewHandler(generator *Generator, jwtSecret []byte, checker auth.RegionHierarchyChecker) *Handler {
	return &Handler{
		generator:        generator,
		jwtSecret:        jwtSecret,
		hierarchyChecker: checker,
	}
}

func (h *Handler) Routes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))
		r.Use(auth.RequireRole("pengurus", "admin_wilayah", "operator"))

		r.With(auth.RequireRTScope("rt", h.hierarchyChecker)).Post("/rts/{rt}/synthetic-data", h.HandleGenerateSyntheticData)
	})
}

type GenerateSyntheticRequest struct {
	TargetCount int `json:"target_count"`
}

func (h *Handler) HandleGenerateSyntheticData(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var req GenerateSyntheticRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	if req.TargetCount <= 0 {
		countStr := r.URL.Query().Get("count")
		req.TargetCount, _ = strconv.Atoi(countStr)
	}

	result, err := h.generator.GenerateRTData(r.Context(), rtID, req.TargetCount)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{"data": result})
}
