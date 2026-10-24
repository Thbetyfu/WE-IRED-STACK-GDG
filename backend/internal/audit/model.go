package audit

import (
	"time"
)

const (
	ActionAccessVulnerableData = "access_vulnerable_data"
	ActionExportRecapPDF       = "export_recap_pdf"
	ActionExportRecapCSV       = "export_recap_csv"
	ActionIncidentActivate     = "incident_activate"
	ActionIncidentEnd          = "incident_end"
	ActionMasterDataModify     = "master_data_modify"
	ActionRecapApprove         = "recap_approve"
	ActionSendWhatsAppRecap    = "send_whatsapp_recap"
	ActionUpdateAISettings     = "update_ai_settings"
)

type AuditLog struct {
	ID        string         `json:"id"`
	RegionID  string         `json:"region_id"`
	UserID    string         `json:"user_id"`
	Action    string         `json:"action"`
	Entity    string         `json:"entity"`
	EntityID  string         `json:"entity_id"`
	Details   map[string]any `json:"details"`
	IPAddress string         `json:"ip_address,omitempty"`
	UserAgent string         `json:"user_agent,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
}
