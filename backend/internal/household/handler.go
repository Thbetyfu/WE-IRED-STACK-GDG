package household

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

// Routes registers all household endpoints per SDD 9.2.
func (h *Handler) Routes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		// RT scoped routes
		r.Route("/rts/{rt}/households", func(r chi.Router) {
			r.Use(auth.RequireRTScope("rt", h.hierarchyChecker))

			r.Get("/", h.HandleListHouseholds)
			r.Post("/", h.HandleCreateHousehold)
			r.Post("/import", h.HandleImportCSV)
		})

		// Household specific routes
		r.Route("/households/{id}", func(r chi.Router) {
			r.Use(auth.RequireHouseholdScope("id"))

			r.Get("/", h.HandleGetHousehold)
			r.Patch("/", h.HandleUpdateHousehold)
			r.Delete("/", h.HandleDeleteHousehold)
			r.Get("/export", h.HandleExportHousehold)
			r.Post("/invite", h.HandleRegenerateInvite)

			// Member management
			r.Get("/members", h.HandleListMembers)
			r.Post("/members", h.HandleAddMember)
			r.Patch("/members/{mid}", h.HandleUpdateMember)
			r.Delete("/members/{mid}", h.HandleDeleteMember)

			// Consent management
			r.Post("/consent", h.HandleRecordConsent)
			r.Delete("/consent", h.HandleRevokeConsent)
		})
	})
}

func (h *Handler) HandleListHouseholds(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var blockID *string
	if b := r.URL.Query().Get("block_id"); b != "" {
		blockID = &b
	}

	list, err := h.service.ListHouseholds(r.Context(), rtID, blockID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat daftar rumah tangga", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": list,
	})
}

func (h *Handler) HandleCreateHousehold(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")
	var req Household
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.RTID = rtID
	created, err := h.service.CreateHousehold(r.Context(), &req)
	if err != nil {
		if errors.Is(err, ErrDuplicateNumber) {
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": created,
	})
}

func (h *Handler) HandleGetHousehold(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	var hhID *string
	if claims.HouseholdID != "" {
		hhID = &claims.HouseholdID
	}

	household, err := h.service.GetHousehold(r.Context(), id, claims.Role, hhID, nil)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Data rumah tangga tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": household,
	})
}

func (h *Handler) HandleUpdateHousehold(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req Household
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.ID = id
	if err := h.service.UpdateHousehold(r.Context(), &req); err != nil {
		if errors.Is(err, ErrHouseholdNotFound) {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", err.Error(), nil)
			return
		}
		if errors.Is(err, ErrDuplicateNumber) {
			platformErrors.WriteJSON(w, http.StatusConflict, "CONFLICT", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{"message": "Data rumah tangga berhasil diperbarui"},
	})
}

func (h *Handler) HandleDeleteHousehold(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.service.DeleteHousehold(r.Context(), id); err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Data rumah tangga tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{"message": "Data rumah tangga berhasil dihapus"},
	})
}

func (h *Handler) HandleImportCSV(w http.ResponseWriter, r *http.Request) {
	rtID := chi.URLParam(r, "rt")

	// Support multipart file or direct text/csv body
	var reader = r.Body
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/form-data") {
		if err := r.ParseMultipartForm(10 << 20); err == nil {
			file, _, err := r.FormFile("file")
			if err == nil {
				defer file.Close()
				reader = file
			}
		}
	}

	summary, err := h.service.ImportCSV(r.Context(), rtID, reader)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": summary,
	})
}

func (h *Handler) HandleExportHousehold(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	var hhID *string
	if claims.HouseholdID != "" {
		hhID = &claims.HouseholdID
	}

	exportDTO, err := h.service.ExportHousehold(r.Context(), id, claims.Role, hhID, nil)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Data rumah tangga tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": exportDTO,
	})
}

func (h *Handler) HandleRegenerateInvite(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	code, err := h.service.RegenerateInviteCode(r.Context(), id)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Gagal memperbarui kode undangan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{
			"invite_code": code,
			"message":     "Kode undangan berhasil dibuat ulang",
		},
	})
}

func (h *Handler) HandleListMembers(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	members, err := h.service.ListMembers(r.Context(), id)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Gagal memuat anggota keluarga", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": members,
	})
}

func (h *Handler) HandleAddMember(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req Member
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.HouseholdID = id
	created, err := h.service.AddMember(r.Context(), &req)
	if err != nil {
		if errors.Is(err, ErrConsentRequired) {
			platformErrors.WriteJSON(w, http.StatusForbidden, "CONSENT_REQUIRED", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": created,
	})
}

func (h *Handler) HandleUpdateMember(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	mid := chi.URLParam(r, "mid")
	var req Member
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	req.HouseholdID = id
	req.ID = mid
	if err := h.service.UpdateMember(r.Context(), &req); err != nil {
		if errors.Is(err, ErrConsentRequired) {
			platformErrors.WriteJSON(w, http.StatusForbidden, "CONSENT_REQUIRED", err.Error(), nil)
			return
		}
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{"message": "Data anggota keluarga berhasil diperbarui"},
	})
}

func (h *Handler) HandleDeleteMember(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	mid := chi.URLParam(r, "mid")
	if err := h.service.DeleteMember(r.Context(), id, mid); err != nil {
		platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Data anggota keluarga tidak ditemukan", nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{"message": "Data anggota keluarga berhasil dihapus"},
	})
}

type RecordConsentPayload struct {
	GivenBy     string `json:"given_by"`
	Method      string `json:"method"`
	TextVersion string `json:"text_version"`
}

func (h *Handler) HandleRecordConsent(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req RecordConsentPayload
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", "Payload JSON tidak valid", nil)
		return
	}

	consent, err := h.service.RecordConsent(r.Context(), id, req.GivenBy, req.Method, req.TextVersion)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "VALIDATION_FAILED", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": consent,
	})
}

func (h *Handler) HandleRevokeConsent(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.service.RevokeConsent(r.Context(), id); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "BAD_REQUEST", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"data": map[string]string{
			"message": "Persetujuan berhasil dicabut. Data catatan kesehatan dan rincian kerentanan telah dihapus.",
		},
	})
}
