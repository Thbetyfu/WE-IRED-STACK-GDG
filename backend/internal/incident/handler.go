package incident

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

		// RT scoped routes
		r.Route("/rts/{rt}/incidents", func(r chi.Router) {
			r.Use(auth.RequireRTScope("rt", h.hierarchyChecker))

			r.Get("/", h.HandleListIncidents)
			r.Get("/active", h.HandleGetActiveIncident)

			// Activation endpoints require pengurus or admin_wilayah
			r.With(auth.RequireRole("pengurus", "admin_wilayah")).Post("/draft", h.HandleDraftActivation)
			r.With(auth.RequireRole("pengurus", "admin_wilayah")).Post("/confirm", h.HandleConfirmActivation)
			r.With(auth.RequireRole("pengurus", "admin_wilayah")).Post("/", h.HandleDirectActivation)
		})

		r.Route("/rts/{rt}/drills", func(r chi.Router) {
			r.Use(auth.RequireRTScope("rt", h.hierarchyChecker))
			r.Get("/comparison", h.HandleGetDrillsComparison)
		})

		// Global incident routes
		r.Route("/incidents/{id}", func(r chi.Router) {
			r.Get("/", h.HandleGetIncident)
			r.Get("/summary", h.HandleGetSummary)
			r.Get("/metrics", h.HandleGetMetrics)
			r.With(auth.RequireRole("pengurus", "admin_wilayah")).Post("/end", h.HandleEndIncident)
		})
	})
}

type DraftRequestPayload struct {
	Hazard        HazardType   `json:"hazard"`
	Mode          IncidentMode `json:"mode"`
	ScopeBlockIDs []string     `json:"scope_block_ids"`
	Message       string       `json:"message"`
}

func (h *Handler) HandleDraftActivation(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	claims := auth.ClaimsFromContext(r.Context())
	userID := ""
	if claims != nil {
		userID = claims.UserID
	}

	var payload DraftRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	if payload.Hazard == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Jenis bencana (hazard) wajib diisi", nil)
		return
	}
	if payload.Mode == "" {
		payload.Mode = ModeNyata
	}

	draft, err := h.service.DraftActivation(r.Context(), DraftRequest{
		RTID:          rtID,
		Hazard:        payload.Hazard,
		Mode:          payload.Mode,
		ScopeBlockIDs: payload.ScopeBlockIDs,
		Message:       payload.Message,
		StartedBy:     userID,
	})
	if err != nil {
		if errors.Is(err, ErrActiveRealIncidentExists) || errors.Is(err, ErrRealIncidentActive) {
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": draft,
	})
}

type ConfirmRequestPayload struct {
	ConfirmationToken string `json:"confirmation_token"`
}

func (h *Handler) HandleConfirmActivation(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFromContext(r.Context())
	userID := ""
	if claims != nil {
		userID = claims.UserID
	}

	var payload ConfirmRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	if payload.ConfirmationToken == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Token konfirmasi wajib diisi", nil)
		return
	}

	inc, err := h.service.ConfirmActivation(r.Context(), payload.ConfirmationToken, userID)
	if err != nil {
		if errors.Is(err, ErrDraftNotFoundOrExpired) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
			return
		}
		if errors.Is(err, ErrActiveRealIncidentExists) || errors.Is(err, ErrRealIncidentActive) {
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": inc,
	})
}

func (h *Handler) HandleDirectActivation(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	claims := auth.ClaimsFromContext(r.Context())
	userID := ""
	if claims != nil {
		userID = claims.UserID
	}

	var payload DraftRequestPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	// Real incident MUST not bypass confirmation step
	if payload.Mode == ModeNyata {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Aktivasi insiden nyata memerlukan konfirmasi dua langkah via /draft dan /confirm", nil)
		return
	}

	inc, err := h.service.ActivateDirect(r.Context(), DirectActivationRequest{
		RTID:          rtID,
		Hazard:        payload.Hazard,
		Mode:          payload.Mode,
		ScopeBlockIDs: payload.ScopeBlockIDs,
		Message:       payload.Message,
		StartedBy:     userID,
	})
	if err != nil {
		if errors.Is(err, ErrRealIncidentActive) || errors.Is(err, ErrActiveRealIncidentExists) {
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
			return
		}
		if errors.Is(err, ErrRealIncidentRequiresConfirmation) {
			platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": inc,
	})
}

func (h *Handler) HandleEndIncident(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	inc, err := h.service.EndIncident(r.Context(), incidentID)
	if err != nil {
		if errors.Is(err, ErrIncidentNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		if errors.Is(err, ErrIncidentAlreadyEnded) {
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": inc,
	})
}

func (h *Handler) HandleGetIncident(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	inc, err := h.service.GetIncident(r.Context(), incidentID)
	if err != nil {
		if errors.Is(err, ErrIncidentNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": inc,
	})
}

func (h *Handler) HandleGetSummary(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	summary, err := h.service.GetSummary(r.Context(), incidentID)
	if err != nil {
		if errors.Is(err, ErrIncidentNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": summary,
	})
}

func (h *Handler) HandleGetMetrics(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	metrics, err := h.service.ComputeMetrics(r.Context(), incidentID)
	if err != nil {
		if errors.Is(err, ErrIncidentNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": metrics,
	})
}

func (h *Handler) HandleListIncidents(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var modeFilter *IncidentMode
	if m := r.URL.Query().Get("mode"); m != "" {
		im := IncidentMode(m)
		modeFilter = &im
	}

	incidents, err := h.service.ListIncidents(r.Context(), rtID, modeFilter)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if incidents == nil {
		incidents = []*Incident{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": incidents,
	})
}

func (h *Handler) HandleGetActiveIncident(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	inc, err := h.service.GetActiveIncident(r.Context(), rtID, nil)
	if err != nil {
		if errors.Is(err, ErrIncidentNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Tidak ada insiden aktif di RT ini", nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": inc,
	})
}

func (h *Handler) HandleGetDrillsComparison(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	comparison, err := h.service.GetDrillsComparison(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": comparison,
	})
}
