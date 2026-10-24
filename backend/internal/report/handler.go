package report

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type IncidentInfoProvider interface {
	GetIncidentRTID(ctx context.Context, incidentID string) (string, error)
}

type Handler struct {
	service          *Service
	jwtSecret        []byte
	hierarchyChecker auth.RegionHierarchyChecker
	incidentProvider IncidentInfoProvider
}

func NewHandler(
	service *Service,
	jwtSecret []byte,
	checker auth.RegionHierarchyChecker,
	incidentProvider IncidentInfoProvider,
) *Handler {
	return &Handler{
		service:          service,
		jwtSecret:        jwtSecret,
		hierarchyChecker: checker,
		incidentProvider: incidentProvider,
	}
}

func (h *Handler) Routes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))

		// Outbox sync batch endpoint
		r.Post("/sync/reports", h.HandleBatchSyncReports)

		// Incident specific report routes
		r.Route("/incidents/{id}", func(r chi.Router) {
			r.Post("/reports", h.HandleSubmitReport)
			r.Get("/households", h.HandleGetTriageTable)
			r.Get("/unreported", h.HandleGetUnreportedHouseholds)
		})

		// Household specific reports history
		r.Get("/households/{id}/reports", h.HandleListReportsByHousehold)
	})
}

type SubmitReportPayload struct {
	ID             *string       `json:"id,omitempty"`
	HouseholdID    string        `json:"household_id"`
	Seq            int           `json:"seq"`
	Status         ReportStatus  `json:"status"`
	Urgency        ReportUrgency `json:"urgency"`
	Needs          int           `json:"needs"`
	MemberMask     int           `json:"member_mask"`
	Message        *string       `json:"message,omitempty"`
	Lat            *float64      `json:"lat,omitempty"`
	Lon            *float64      `json:"lon,omitempty"`
	Battery        *int          `json:"battery,omitempty"`
	Channel        string        `json:"channel"`
	ReporterUserID *string       `json:"reporter_user_id,omitempty"`
	BeaconID       *string       `json:"beacon_id,omitempty"`
	DeviceTime     *time.Time    `json:"device_time,omitempty"`
	RelayPath      []string      `json:"relay_path,omitempty"`
}

func (h *Handler) HandleSubmitReport(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	claims := auth.ClaimsFromContext(r.Context())
	if claims == nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Autentikasi diperlukan", nil)
		return
	}

	var payload SubmitReportPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid", nil)
		return
	}

	if payload.HouseholdID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "household_id wajib diisi", nil)
		return
	}
	if payload.Status < 1 || payload.Status > 3 {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "status laporan harus antara 1, 2, atau 3", nil)
		return
	}

	// Scoping check: citizen can only report for own household unless role is volunteer/pengurus/admin
	if claims.Role == "warga" && claims.HouseholdID != "" && claims.HouseholdID != payload.HouseholdID {
		platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", "Warga hanya dapat melaporkan untuk rumah tangganya sendiri", nil)
		return
	}

	reportID := uuid.NewString()
	if payload.ID != nil && *payload.ID != "" {
		reportID = *payload.ID
	}

	channel := payload.Channel
	if channel == "" {
		if claims.Role == "relawan" {
			channel = ChannelRelawan
		} else {
			channel = ChannelAplikasi
		}
	}

	var reporterUserID *string
	if payload.ReporterUserID != nil && *payload.ReporterUserID != "" {
		reporterUserID = payload.ReporterUserID
	} else if claims.Role == "relawan" || claims.Role == "pengurus" {
		reporterUserID = &claims.UserID
	}

	now := time.Now().UTC()
	deviceTime := now
	if payload.DeviceTime != nil && !payload.DeviceTime.IsZero() {
		deviceTime = *payload.DeviceTime
	}

	report := &Report{
		ID:             reportID,
		IncidentID:     incidentID,
		HouseholdID:    payload.HouseholdID,
		Seq:            payload.Seq,
		Status:         payload.Status,
		Urgency:        payload.Urgency,
		Needs:          payload.Needs,
		MemberMask:     payload.MemberMask,
		Message:        payload.Message,
		Lat:            payload.Lat,
		Lon:            payload.Lon,
		Battery:        payload.Battery,
		Channel:        channel,
		ReporterUserID: reporterUserID,
		BeaconID:       payload.BeaconID,
		DeviceTime:     deviceTime,
		ReceivedAt:     now,
		RelayPath:      payload.RelayPath,
	}

	result, err := h.service.SubmitReport(r.Context(), report)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	status := http.StatusOK
	if !result.AlreadyExists {
		status = http.StatusCreated
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": result,
	})
}

func (h *Handler) HandleBatchSyncReports(w http.ResponseWriter, r *http.Request) {
	var reports []*Report
	if err := json.NewDecoder(r.Body).Decode(&reports); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Format body JSON tidak valid (harus array laporan)", nil)
		return
	}

	results, err := h.service.BatchSyncReports(r.Context(), reports)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": results,
	})
}

func (h *Handler) HandleGetTriageTable(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	rtID := ""
	if h.incidentProvider != nil {
		rtID, _ = h.incidentProvider.GetIncidentRTID(r.Context(), incidentID)
	}

	var statusFilter *ReportStatus
	if s := r.URL.Query().Get("status"); s != "" {
		if val, err := strconv.Atoi(s); err == nil && val >= 1 && val <= 3 {
			st := ReportStatus(val)
			statusFilter = &st
		}
	}

	var blockFilter *string
	if b := r.URL.Query().Get("block"); b != "" {
		blockFilter = &b
	}

	items, err := h.service.GetTriageTable(r.Context(), incidentID, rtID, statusFilter, blockFilter)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if items == nil {
		items = []*TriageItem{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": items,
	})
}

func (h *Handler) HandleGetUnreportedHouseholds(w http.ResponseWriter, r *http.Request) {
	incidentID := chi.URLParam(r, "id")
	rtID := ""
	if h.incidentProvider != nil {
		rtID, _ = h.incidentProvider.GetIncidentRTID(r.Context(), incidentID)
	}

	items, err := h.service.GetUnreportedHouseholds(r.Context(), incidentID, rtID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if items == nil {
		items = []*TriageItem{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": items,
	})
}

func (h *Handler) HandleListReportsByHousehold(w http.ResponseWriter, r *http.Request) {
	householdID := chi.URLParam(r, "id")
	incidentID := r.URL.Query().Get("incident_id")

	reports, err := h.service.ListReportsByHousehold(r.Context(), incidentID, householdID)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if reports == nil {
		reports = []*Report{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"data": reports,
	})
}
