package whatsapp

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	platformErrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

type Handler struct {
	service     *Service
	verifyToken string
	appSecret   string
	jwtSecret   []byte
}

func NewHandler(service *Service, verifyToken, appSecret string, jwtSecret []byte) *Handler {
	return &Handler{
		service:     service,
		verifyToken: verifyToken,
		appSecret:   appSecret,
		jwtSecret:   jwtSecret,
	}
}

func (h *Handler) Routes(r chi.Router) {
	// Webhook endpoints for Meta WhatsApp Cloud API (FR-WA-07)
	r.Get("/webhook/whatsapp", h.HandleVerifyWebhook)
	r.Post("/webhook/whatsapp", h.HandleReceiveWebhook)

	// Admin / Operator endpoints
	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate(h.jwtSecret))
		r.Use(auth.RequireRole("pengurus", "admin_wilayah", "operator"))

		r.Get("/notifications/whatsapp", h.HandleListNotifications)
	})
}

// HandleVerifyWebhook handles the initial Meta webhook subscription verification handshake.
func (h *Handler) HandleVerifyWebhook(w http.ResponseWriter, r *http.Request) {
	mode := r.URL.Query().Get("hub.mode")
	token := r.URL.Query().Get("hub.verify_token")
	challenge := r.URL.Query().Get("hub.challenge")

	if mode == "subscribe" && token == h.verifyToken {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(challenge))
		return
	}

	http.Error(w, "Forbidden", http.StatusForbidden)
}

// HandleReceiveWebhook receives and processes inbound WhatsApp messages and delivery receipts.
func (h *Handler) HandleReceiveWebhook(w http.ResponseWriter, r *http.Request) {
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "INVALID_BODY", "Gagal membaca body request", nil)
		return
	}

	// 1. Validate X-Hub-Signature-256 (FR-WA-07)
	sigHeader := r.Header.Get("X-Hub-Signature-256")
	if h.appSecret != "" {
		if !ValidateWebhookSignature(h.appSecret, bodyBytes, sigHeader) {
			platformErrors.WriteJSON(w, http.StatusUnauthorized, "INVALID_SIGNATURE", "Tanda tangan webhook WhatsApp tidak valid", nil)
			return
		}
	}

	// 2. Parse Webhook Payload
	var payload WebhookPayload
	if err := json.Unmarshal(bodyBytes, &payload); err != nil {
		platformErrors.WriteJSON(w, http.StatusBadRequest, "MALFORMED_JSON", "Format webhook json tidak valid", nil)
		return
	}

	ctx := r.Context()

	// 3. Process Entries & Changes
	for _, entry := range payload.Entry {
		for _, change := range entry.Changes {
			if change.Field != "messages" {
				continue
			}

			// Process Incoming Messages
			for _, msg := range change.Value.Messages {
				var text string
				var buttonPayload string

				if msg.Text != nil {
					text = msg.Text.Body
				}
				if msg.Button != nil {
					buttonPayload = msg.Button.Payload
					if text == "" {
						text = msg.Button.Text
					}
				}
				if msg.Interactive != nil {
					if msg.Interactive.ButtonReply != nil {
						buttonPayload = msg.Interactive.ButtonReply.ID
						if text == "" {
							text = msg.Interactive.ButtonReply.Title
						}
					} else if msg.Interactive.ListReply != nil {
						buttonPayload = msg.Interactive.ListReply.ID
						if text == "" {
							text = msg.Interactive.ListReply.Title
						}
					}
				}

				_ = h.service.HandleIncomingMessage(ctx, msg.From, msg.ID, text, buttonPayload)
			}

			// Process Status Updates
			for _, st := range change.Value.Statuses {
				var errDetail *string
				if len(st.Errors) > 0 {
					d := st.Errors[0].Title + ": " + st.Errors[0].Message
					errDetail = &d
				}
				_ = h.service.HandleStatusUpdate(ctx, st.ID, st.Status, errDetail)
			}
		}
	}

	// Meta requires quick 200 OK response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (h *Handler) HandleListNotifications(w http.ResponseWriter, r *http.Request) {
	phone := r.URL.Query().Get("phone")
	limitStr := r.URL.Query().Get("limit")
	limit, _ := strconv.Atoi(limitStr)

	list, err := h.service.ListNotificationsByRecipient(r.Context(), phone, limit)
	if err != nil {
		platformErrors.WriteJSON(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
		return
	}
	if list == nil {
		list = []*Notification{}
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"data": list})
}
