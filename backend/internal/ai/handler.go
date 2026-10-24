package ai

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
		r.Use(auth.RequireRole("pengurus", "admin_wilayah", "operator", "relawan"))

		// AI Assistant Endpoints (SDD 10.4 & FR-AI)
		r.Post("/ai/summarize", h.HandleSummarize)
		r.Post("/ai/classify", h.HandleClassify)
		r.Post("/ai/draft-recap", h.HandleDraftRecap)

		// AI Settings Toggle Per RT (FR-AI-07)
		r.With(auth.RequireRTScope("rt", h.hierarchyChecker)).Get("/rts/{rt}/ai-settings", h.HandleGetAISettings)
		r.With(auth.RequireRTScope("rt", h.hierarchyChecker), auth.RequireRole("pengurus", "admin_wilayah")).
			Patch("/rts/{rt}/ai-settings", h.HandleUpdateAISettings)
	})
}

type summarizeRequest struct {
	RTID     string       `json:"rt_id"`
	Messages []RawMessage `json:"messages"`
}

func (h *Handler) HandleSummarize(w http.ResponseWriter, r *http.Request) {
	var req summarizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "invalid_payload", "Payload request tidak valid", nil)
		return
	}

	if req.RTID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "missing_rt_id", "rt_id wajib disertakan", nil)
		return
	}

	summary, err := h.service.Summarize(r.Context(), req.RTID, req.Messages)
	if err != nil {
		h.handleAIError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status": "success",
		"data":   summary,
	})
}

type classifyRequest struct {
	RTID string `json:"rt_id"`
	Text string `json:"text"`
}

func (h *Handler) HandleClassify(w http.ResponseWriter, r *http.Request) {
	var req classifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "invalid_payload", "Payload request tidak valid", nil)
		return
	}

	if req.RTID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "missing_rt_id", "rt_id wajib disertakan", nil)
		return
	}

	suggestion, err := h.service.ClassifyNeeds(r.Context(), req.RTID, req.Text)
	if err != nil {
		h.handleAIError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status": "success",
		"data":   suggestion,
	})
}

type draftRecapRequest struct {
	RTID string         `json:"rt_id"`
	Data RecapAggregate `json:"data"`
}

func (h *Handler) HandleDraftRecap(w http.ResponseWriter, r *http.Request) {
	var req draftRecapRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "invalid_payload", "Payload request tidak valid", nil)
		return
	}

	if req.RTID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "missing_rt_id", "rt_id wajib disertakan", nil)
		return
	}

	draft, err := h.service.DraftRecap(r.Context(), req.RTID, req.Data)
	if err != nil {
		h.handleAIError(w, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status": "success",
		"data":   draft,
	})
}

func (h *Handler) HandleGetAISettings(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	settings, err := h.service.GetAISettings(r.Context(), rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "rt_not_found", "Wilayah RT tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status": "success",
		"data":   settings,
	})
}

type updateAISettingsRequest struct {
	AIEnabled bool `json:"ai_enabled"`
}

func (h *Handler) HandleUpdateAISettings(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	claims := auth.ClaimsFromContext(r.Context())
	actorID := "anonymous"
	if claims != nil {
		actorID = claims.UserID
	}

	var req updateAISettingsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "invalid_payload", "Payload tidak valid", nil)
		return
	}

	ip := r.RemoteAddr
	ua := r.UserAgent()

	if err := h.service.SetAIEnabled(r.Context(), rtID, req.AIEnabled, actorID, ip, ua); err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "update_failed", "Gagal memperbarui pengaturan AI RT", nil)
		return
	}

	settings, _ := h.service.GetAISettings(r.Context(), rtID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status": "success",
		"data":   settings,
	})
}

func (h *Handler) handleAIError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrAIDisabledForRT):
		platformErrors.WriteJSON(w, http.StatusForbidden, "ai_disabled_for_rt", err.Error(), nil)
	case errors.Is(err, ErrProviderUnavailable):
		platformErrors.WriteJSON(w, http.StatusServiceUnavailable, "ai_provider_unavailable", err.Error(), nil)
	case errors.Is(err, ErrProviderTimeout):
		platformErrors.WriteJSON(w, http.StatusGatewayTimeout, "ai_provider_timeout", err.Error(), nil)
	case errors.Is(err, ErrEmptyInput):
		platformErrors.WriteJSON(w, http.StatusBadRequest, "ai_empty_input", err.Error(), nil)
	case errors.Is(err, ErrInvalidModelResponse):
		platformErrors.WriteJSON(w, http.StatusBadGateway, "ai_invalid_response", err.Error(), nil)
	default:
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "ai_internal_error", err.Error(), nil)
	}
}
