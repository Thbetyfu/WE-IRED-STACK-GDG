package realtime

import (
	"context"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type IncidentScopeChecker interface {
	GetIncidentRTID(ctx context.Context, incidentID string) (string, error)
}

type Handler struct {
	hub              *Hub
	jwtSecret        []byte
	hierarchyChecker auth.RegionHierarchyChecker
	incidentChecker  IncidentScopeChecker
}

func NewHandler(
	hub *Hub,
	jwtSecret []byte,
	checker auth.RegionHierarchyChecker,
	incidentChecker IncidentScopeChecker,
) *Handler {
	return &Handler{
		hub:              hub,
		jwtSecret:        jwtSecret,
		hierarchyChecker: checker,
		incidentChecker:  incidentChecker,
	}
}

func (h *Handler) Routes(r chi.Router) {
	r.Get("/ws", h.HandleWebSocket)
}

func (h *Handler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	incidentID := r.URL.Query().Get("incident")
	if incidentID == "" {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_INPUT", "Parameter 'incident' wajib diisi", nil)
		return
	}

	// 1. Extract JWT token from query string or headers
	tokenStr := r.URL.Query().Get("token")
	if tokenStr == "" {
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenStr = strings.TrimPrefix(authHeader, "Bearer ")
		}
	}
	if tokenStr == "" {
		tokenStr = r.Header.Get("Sec-WebSocket-Protocol")
	}

	if tokenStr == "" {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Token autentikasi wajib disertakan", nil)
		return
	}

	claims, err := auth.ValidateAccessToken(h.jwtSecret, tokenStr)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusUnauthorized, "UNAUTHORIZED", "Token akses tidak valid atau kedaluwarsa", nil)
		return
	}

	// 2. Incident Scoping check (SDD Section 9.6)
	incidentRTID := ""
	if h.incidentChecker != nil {
		rtID, err := h.incidentChecker.GetIncidentRTID(r.Context(), incidentID)
		if err != nil {
			platformErrors.WriteJSON(w, http.StatusNotFound, "NOT_FOUND", "Insiden tidak ditemukan", nil)
			return
		}
		incidentRTID = rtID

		// Access scope check based on role
		switch claims.Role {
		case "pengurus", "warga", "relawan":
			if claims.RegionID != incidentRTID {
				platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", "Pengguna tidak memiliki izin untuk memantau insiden di luar wilayahnya", nil)
				return
			}
		case "admin_wilayah":
			if h.hierarchyChecker != nil {
				isInRegion, err := h.hierarchyChecker.IsRTInRegion(r.Context(), claims.RegionID, incidentRTID)
				if err != nil || !isInRegion {
					platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", "Pengguna admin wilayah tidak memiliki akses ke RT ini", nil)
					return
				}
			}
		case "operator":
			// operator has global view
		default:
			platformErrors.WriteJSON(w, http.StatusForbidden, "FORBIDDEN", "Peran pengguna tidak diizinkan", nil)
			return
		}
	}

	// 3. Parse last_event_id for event replay/recovery (SDD 9.6)
	var lastEventID int64
	if lastEventStr := r.URL.Query().Get("last_event_id"); lastEventStr != "" {
		if idVal, err := strconv.ParseInt(lastEventStr, 10, 64); err == nil {
			lastEventID = idVal
		}
	}

	// 4. Upgrade HTTP connection to WebSocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	client := &Client{
		hub:        h.hub,
		conn:       conn,
		incidentID: incidentID,
		rtID:       incidentRTID,
		userID:     claims.UserID,
		role:       claims.Role,
		send:       make(chan *Event, 128),
	}

	h.hub.Register(client)

	// 5. Send missed events for event recovery if last_event_id provided
	if lastEventID > 0 {
		_ = h.hub.SendMissedEvents(r.Context(), client, lastEventID)
	}

	go client.WritePump()
	go client.ReadPump()
}
