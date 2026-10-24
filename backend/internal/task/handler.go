package task

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/priority"
)

type IncidentInfoProvider interface {
	GetIncidentRTID(ctx context.Context, incidentID string) (string, error)
}

type Handler struct {
	service          *Service
	jwtSecret        []byte
	incidentProvider IncidentInfoProvider
}

func NewHandler(service *Service, jwtSecret []byte, incidentProvider IncidentInfoProvider) *Handler {
	return &Handler{
		service:          service,
		jwtSecret:        jwtSecret,
		incidentProvider: incidentProvider,
	}
}

func (h *Handler) Routes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		// Incident-specific task endpoints
		r.Route("/incidents/{id}", func(r chi.Router) {
			r.Get("/tasks", h.HandleListTasks)
			r.Post("/tasks", h.HandleCreateTask)
			r.Get("/tasks/overdue", h.HandleGetOverdueTasks)

			// Plan generation and application
			r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Get("/plan", h.HandleGetPlan)
			r.With(auth.RequireRole("pengurus", "admin_wilayah", "operator")).Post("/plan/apply", h.HandleApplyPlan)
		})

		// Single task operations
		r.Route("/tasks/{id}", func(r chi.Router) {
			r.Get("/", h.HandleGetTask)
			r.Patch("/", h.HandleUpdateTask)
		})
	})
}

func (h *Handler) HandleListTasks(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")

	var statusFilter *TaskStatus
	if s := r.URL.Query().Get("status"); s != "" {
		st := TaskStatus(s)
		statusFilter = &st
	}

	var volFilter *string
	if v := r.URL.Query().Get("volunteer_id"); v != "" {
		volFilter = &v
	}

	tasks, err := h.service.ListTasks(r.Context(), incidentID, statusFilter, volFilter)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if tasks == nil {
		tasks = []*Task{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": tasks,
	})
}

func (h *Handler) HandleCreateTask(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	var req CreateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	task, err := h.service.CreateTask(r.Context(), incidentID, req, claims.UserID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": task,
	})
}

func (h *Handler) HandleGetTask(w http.ResponseWriter, r *http.Request) {
	taskID := chi.URLParam(r, "id")
	task, err := h.service.GetTask(r.Context(), taskID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Tugas tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": task,
	})
}

func (h *Handler) HandleUpdateTask(w http.ResponseWriter, r *http.Request) {
	taskID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	var req UpdateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	updated, err := h.service.UpdateTask(r.Context(), taskID, req, claims.UserID, claims.Role)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": updated,
	})
}

func (h *Handler) HandleGetPlan(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	rtID := ""
	if h.incidentProvider != nil {
		rtID, _ = h.incidentProvider.GetIncidentRTID(r.Context(), incidentID)
	}

	plan, err := h.service.GeneratePlan(r.Context(), incidentID, rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if plan == nil {
		plan = []*priority.SuggestedAssignment{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": plan,
	})
}

func (h *Handler) HandleApplyPlan(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	var plan []*priority.SuggestedAssignment
	if err := json.NewDecoder(r.Body).Decode(&plan); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	tasks, err := h.service.ApplyPlan(r.Context(), incidentID, claims.UserID, plan)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": tasks,
	})
}

func (h *Handler) HandleGetOverdueTasks(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	tasks, err := h.service.CheckOverdueTasks(r.Context(), incidentID, time.Now().UTC())
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if tasks == nil {
		tasks = []*Task{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": tasks,
	})
}
