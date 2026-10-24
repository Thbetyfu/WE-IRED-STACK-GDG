package recap

import (
	"encoding/json"
	"errors"
	"fmt"
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
		r.Use(auth.RequireRole("pengurus", "admin_wilayah", "operator"))

		// Recap Operations (SDD 9.5)
		r.Post("/incidents/{id}/recap", h.HandleCompileRecap)
		r.Get("/incidents/{id}/recap", h.HandleGetRecapByIncident)
		r.Get("/recaps/{id}", h.HandleGetRecap)
		r.Patch("/recaps/{id}", h.HandleUpdateRecap)
		r.Post("/recaps/{id}/approve", h.HandleApproveRecap)

		// Exports (FR-RCP-02)
		r.Get("/recaps/{id}.pdf", h.HandleExportPDF)
		r.Get("/recaps/{id}.csv", h.HandleExportCSV)
		r.Post("/recaps/{id}/send-whatsapp", h.HandleSendWhatsApp)

		// AI Assisted Drafting (FR-AI-03 & SDD 9.5)
		r.Post("/ai/draft-recap", h.HandleDraftAINarrative)
	})
}

func (h *Handler) HandleCompileRecap(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	role := "pengurus"
	userID := "system"
	if claims != nil {
		role = claims.Role
		userID = claims.UserID
	}

	rcp, err := h.service.CompileRecap(r.Context(), incidentID, role, userID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]any{"data": rcp})
}

func (h *Handler) HandleGetRecapByIncident(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	role := "pengurus"
	if claims != nil {
		role = claims.Role
	}

	rcp, err := h.service.GetRecapByIncident(r.Context(), incidentID, role)
	if err != nil {
		if errors.Is(err, ErrRecapNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Rekap insiden belum disusun", nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"data": rcp})
}

func (h *Handler) HandleGetRecap(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	role := "pengurus"
	if claims != nil {
		role = claims.Role
	}

	rcp, err := h.service.GetRecap(r.Context(), id, role)
	if err != nil {
		if errors.Is(err, ErrRecapNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"data": rcp})
}

func (h *Handler) HandleUpdateRecap(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var input UpdateRecapInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body json tidak valid", nil)
		return
	}

	claims := auth.ClaimsFromContext(r.Context())
	userID := "system"
	if claims != nil {
		userID = claims.UserID
	}

	rcp, err := h.service.UpdateNotes(r.Context(), id, input, userID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"data": rcp})
}

func (h *Handler) HandleApproveRecap(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	userID := "system"
	if claims != nil {
		userID = claims.UserID
	}

	rcp, err := h.service.ApproveRecap(r.Context(), id, userID, r.RemoteAddr, r.UserAgent())
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"data": rcp})
}

func (h *Handler) HandleExportPDF(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	role := "pengurus"
	userID := "system"
	if claims != nil {
		role = claims.Role
		userID = claims.UserID
	}

	pdfBytes, err := h.service.GeneratePDF(r.Context(), id, role, userID, r.RemoteAddr, r.UserAgent())
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"rekap_%s.pdf\"", id))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(pdfBytes)
}

func (h *Handler) HandleExportCSV(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	role := "pengurus"
	userID := "system"
	if claims != nil {
		role = claims.Role
		userID = claims.UserID
	}

	csvBytes, err := h.service.GenerateCSV(r.Context(), id, role, userID, r.RemoteAddr, r.UserAgent())
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "text/csv")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"rekap_%s.csv\"", id))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(csvBytes)
}

type SendWhatsAppPayload struct {
	Phone string `json:"phone"`
}

func (h *Handler) HandleSendWhatsApp(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var payload SendWhatsAppPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil || payload.Phone == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Nomor telepon tujuan (phone) wajib diisi", nil)
		return
	}

	claims := auth.ClaimsFromContext(r.Context())
	userID := "system"
	if claims != nil {
		userID = claims.UserID
	}

	err := h.service.SendWhatsApp(r.Context(), id, payload.Phone, userID, r.RemoteAddr, r.UserAgent())
	if err != nil {
		if errors.Is(err, ErrRecapNotApproved) {
			platformErrors.WriteJSON(w, http.StatusForbidden, "NOT_APPROVED", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": map[string]string{
			"status":  "dispatched",
			"message": fmt.Sprintf("Dokumen rekap berhasil dikirimkan ke %s", payload.Phone),
		},
	})
}

type DraftAIRequest struct {
	RecapID string `json:"recap_id"`
}

func (h *Handler) HandleDraftAINarrative(w http.ResponseWriter, r *http.Request) {
	var req DraftAIRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RecapID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "recap_id wajib diisi", nil)
		return
	}

	draft, err := h.service.DraftAINarrative(r.Context(), req.RecapID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": map[string]any{
			"narrative":   draft,
			"ai_assisted": true,
			"disclaimer":  "Dibuat dengan bantuan AI — periksa kembali",
		},
	})
}
