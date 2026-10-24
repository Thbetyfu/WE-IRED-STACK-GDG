package whatsapp

import (
	"time"
)

// Standard Template Names per SDD 10.1 & Meta Business Manager submission
const (
	TemplateOTPLogin       = "otp_login"
	TemplateSiagaAktivasi  = "siaga_aktivasi"
	TemplateSiagaPengingat = "siaga_pengingat"
	TemplatePengumumanRT   = "pengumuman_rt"
	TemplateRekapInsiden   = "rekap_insiden"
)

// Delivery Statuses per SDD 380 & FR-WA-07
type NotificationStatus string

const (
	StatusAntri    NotificationStatus = "antri"
	StatusTerkirim NotificationStatus = "terkirim" // Meta 'sent'
	StatusDiterima NotificationStatus = "diterima" // Meta 'delivered'
	StatusDibaca   NotificationStatus = "dibaca"   // Meta 'read'
	StatusGagal    NotificationStatus = "gagal"    // Meta 'failed'
)

// Conversational Session Steps for "Butuh Bantuan" flow (SDD 10.1)
type SessionStep string

const (
	StepAwaitingNeeds   SessionStep = "awaiting_needs"
	StepAwaitingUrgency SessionStep = "awaiting_urgency"
	StepAwaitingMessage SessionStep = "awaiting_message"
)

// Notification represents a tracked outbound communication (SDD 380).
type Notification struct {
	ID         string                 `json:"id"`
	Channel    string                 `json:"channel"` // "whatsapp"
	Recipient  string                 `json:"recipient"`
	Template   string                 `json:"template,omitempty"`
	Payload    map[string]any         `json:"payload"`
	Status     NotificationStatus     `json:"status"`
	ProviderID *string                `json:"provider_id,omitempty"` // wamid.xxx
	Error      *string                `json:"error,omitempty"`
	CreatedAt  time.Time              `json:"created_at"`
	UpdatedAt  time.Time              `json:"updated_at"`
}

// WASession tracks multi-step interactive conversation state per phone (FR-WA-04).
type WASession struct {
	Phone       string         `json:"phone"`
	IncidentID  string         `json:"incident_id"`
	HouseholdID string         `json:"household_id"`
	ReportID    string         `json:"report_id"`
	Step        SessionStep    `json:"step"`
	Context     map[string]any `json:"context"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

// Meta Webhook Structs per WhatsApp Cloud API Specification
type WebhookPayload struct {
	Object string         `json:"object"`
	Entry  []WebhookEntry `json:"entry"`
}

type WebhookEntry struct {
	ID      string          `json:"id"`
	Changes []WebhookChange `json:"changes"`
}

type WebhookChange struct {
	Value WebhookValue `json:"value"`
	Field string       `json:"field"`
}

type WebhookValue struct {
	MessagingProduct string           `json:"messaging_product"`
	Metadata         WebhookMetadata  `json:"metadata"`
	Contacts         []WebhookContact `json:"contacts,omitempty"`
	Messages         []WebhookMessage `json:"messages,omitempty"`
	Statuses         []WebhookStatus  `json:"statuses,omitempty"`
}

type WebhookMetadata struct {
	DisplayPhoneNumber string `json:"display_phone_number"`
	PhoneNumberID      string `json:"phone_number_id"`
}

type WebhookContact struct {
	Profile struct {
		Name string `json:"name"`
	} `json:"profile"`
	WAID string `json:"wa_id"`
}

type WebhookMessage struct {
	From        string                    `json:"from"`
	ID          string                    `json:"id"`
	Timestamp   string                    `json:"timestamp"`
	Type        string                    `json:"type"` // "button", "interactive", "text"
	Text        *WebhookText              `json:"text,omitempty"`
	Button      *WebhookButton            `json:"button,omitempty"`
	Interactive *WebhookInteractiveReply `json:"interactive,omitempty"`
}

type WebhookText struct {
	Body string `json:"body"`
}

type WebhookButton struct {
	Payload string `json:"payload"`
	Text    string `json:"text"`
}

type WebhookInteractiveReply struct {
	Type        string                       `json:"type"` // "button_reply", "list_reply"
	ButtonReply *WebhookInteractiveReplyItem `json:"button_reply,omitempty"`
	ListReply   *WebhookInteractiveReplyItem `json:"list_reply,omitempty"`
}

type WebhookInteractiveReplyItem struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
}

type WebhookStatus struct {
	ID           string         `json:"id"`
	Status       string         `json:"status"` // "sent", "delivered", "read", "failed"
	Timestamp    string         `json:"timestamp"`
	RecipientID  string         `json:"recipient_id"`
	Errors       []WebhookError `json:"errors,omitempty"`
}

type WebhookError struct {
	Code    int    `json:"code"`
	Title   string `json:"title"`
	Message string `json:"message"`
}

// Outbound Message Models
type TemplateParameter struct {
	Type     string            `json:"type"` // "text", "document", "image"
	Text     string            `json:"text,omitempty"`
	Document *DocumentResource `json:"document,omitempty"`
}

type DocumentResource struct {
	Link     string `json:"link"`
	Filename string `json:"filename,omitempty"`
	Caption  string `json:"caption,omitempty"`
}

type TemplateComponent struct {
	Type       string              `json:"type"` // "header", "body", "button"
	SubType    string              `json:"sub_type,omitempty"` // "url", "quick_reply"
	Index      string              `json:"index,omitempty"`
	Parameters []TemplateParameter `json:"parameters"`
}

type SendTemplateRequest struct {
	MessagingProduct string `json:"messaging_product"`
	RecipientType    string `json:"recipient_type"`
	To               string `json:"to"`
	Type             string `json:"type"`
	Template         struct {
		Name       string              `json:"name"`
		Language   struct {
			Code string `json:"code"`
		} `json:"language"`
		Components []TemplateComponent `json:"components"`
	} `json:"template"`
}

type InteractiveButton struct {
	ID    string
	Title string
}

type ListRow struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
}

type ListSection struct {
	Title string    `json:"title"`
	Rows  []ListRow `json:"rows"`
}
