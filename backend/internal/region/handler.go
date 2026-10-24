package region

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
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

// Routes registers region endpoints.
func (h *Handler) Routes(r chi.Router) {
	// Base authenticated routes
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		// Regions & Hierarchy
		r.Get("/regions", h.HandleListRegions)
		r.Get("/regions/hierarchy", h.HandleGetHierarchy)
		r.Get("/regions/{id}/aggregate", h.HandleGetAggregate)

		// Operator only
		r.Group(func(r chi.Router) {
			r.Use(auth.RequireRole("operator"))
			r.Post("/regions", h.HandleCreateRegion)
		})

		// Accessible RT list for dashboard selector
		r.Get("/rts", h.HandleListAccessibleRTs)

		// RT-specific routes guarded by RTScope
		r.Route("/rts/{rt}", func(r chi.Router) {
			r.Use(auth.RequireRTScope("rt", h.service))

			r.Get("/", h.HandleGetRT)
			r.Get("/memberships", h.HandleListMemberships)
			r.Post("/memberships", h.HandleAddMembership)
		})
	})
}

type CreateRegionPayload struct {
	Type        RegionType `json:"type"`
	ParentID    *string    `json:"parent_id,omitempty"`
	Name        string     `json:"name"`
	Code        string     `json:"code"`
	CentroidLat float64    `json:"centroid_lat"`
	CentroidLon float64    `json:"centroid_lon"`
	AIEnabled   bool       `json:"ai_enabled"`
}

func (h *Handler) HandleCreateRegion(w http.ResponseWriter, r *http.Request) {
	var req CreateRegionPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	region := &Region{
		Type:        req.Type,
		ParentID:    req.ParentID,
		Name:        req.Name,
		Code:        req.Code,
		CentroidLat: req.CentroidLat,
		CentroidLon: req.CentroidLon,
		AIEnabled:   req.AIEnabled,
	}

	created, err := h.service.CreateRegion(r.Context(), region, Role(claims.Role))
	if err != nil {
		switch {
		case errors.Is(err, ErrUnauthorizedAction):
			platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", err.Error(), nil)
		case errors.Is(err, ErrDuplicateCode):
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
		default:
			platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": created,
	})
}

func (h *Handler) HandleListRegions(w http.ResponseWriter, r *http.Request) {
	regionType := RegionType(r.URL.Query().Get("type"))
	var parentID *string
	if p := r.URL.Query().Get("parent_id"); p != "" {
		parentID = &p
	}

	list, err := h.service.ListRegions(r.Context(), regionType, parentID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat daftar wilayah", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": list,
	})
}

func (h *Handler) HandleGetHierarchy(w http.ResponseWriter, r *http.Request) {
	var rootID *string
	if root := r.URL.Query().Get("root_id"); root != "" {
		rootID = &root
	}

	tree, err := h.service.GetHierarchy(r.Context(), rootID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal menyusun hierarki wilayah", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": tree,
	})
}

func (h *Handler) HandleListAccessibleRTs(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	rts, err := h.service.ListAccessibleRTs(r.Context(), Role(claims.Role), claims.RegionID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal mengambil daftar RT", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": rts,
	})
}

func (h *Handler) HandleGetRT(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	region, err := h.service.GetRegion(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Wilayah RT tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": region,
	})
}

func (h *Handler) HandleListMemberships(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	list, err := h.service.ListMemberships(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal mengambil keanggotaan peran", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": list,
	})
}

type AddMembershipPayload struct {
	UserID      string  `json:"user_id"`
	Role        Role    `json:"role"`
	HouseholdID *string `json:"household_id,omitempty"`
}

func (h *Handler) HandleAddMembership(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var req AddMembershipPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.UserID = strings.TrimSpace(req.UserID)
	if req.UserID == "" || req.Role == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "User ID dan Role wajib ditentukan", nil)
		return
	}

	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	m := &Membership{
		UserID:      req.UserID,
		RegionID:    rtID,
		Role:        req.Role,
		HouseholdID: req.HouseholdID,
	}

	err := h.service.AssignMembership(r.Context(), m, Role(claims.Role), claims.RegionID)
	if err != nil {
		if errors.Is(err, ErrUnauthorizedAction) {
			platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "BAD_REQUEST", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": m,
	})
}

func (h *Handler) HandleGetAggregate(w http.ResponseWriter, r *http.Request) {
	regionID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	agg, err := h.service.GetRegionAggregate(r.Context(), regionID, Role(claims.Role), claims.RegionID)
	if err != nil {
		if errors.Is(err, ErrUnauthorizedAction) {
			platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", "Anda tidak memiliki akses ke agregat wilayah ini", nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": agg,
	})
}
