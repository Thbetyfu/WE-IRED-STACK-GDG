package report

import (
	"time"
)

type ReportStatus int16

const (
	StatusAman         ReportStatus = 1 // Aman di rumah
	StatusTitikKumpul  ReportStatus = 2 // Sudah di titik kumpul
	StatusButuhBantuan ReportStatus = 3 // Butuh bantuan
)

type ReportUrgency int16

const (
	UrgencyNone   ReportUrgency = 0 // Untuk status 1 & 2
	UrgencyBiasa  ReportUrgency = 1 // Biasa
	UrgencyKritis ReportUrgency = 2 // Kritis
)

const (
	NeedEvakuasi      = 1 << 0 // 1
	NeedMedis         = 1 << 1 // 2
	NeedMakananAir    = 1 << 2 // 4
	NeedTempatTinggal = 1 << 3 // 8
	NeedLainnya       = 1 << 4 // 16
)

const (
	ChannelAplikasi      = "aplikasi"
	ChannelOutbox        = "outbox"
	ChannelRelawan       = "relawan"
	ChannelMesh          = "mesh"
	ChannelBeacon        = "beacon"
	ChannelBeaconCheckin = "beacon_checkin"
	ChannelWhatsApp      = "whatsapp"
)

type Report struct {
	ID             string       `json:"id"`
	IncidentID     string       `json:"incident_id"`
	HouseholdID    string       `json:"household_id"`
	Seq            int          `json:"seq"`
	Status         ReportStatus `json:"status"`
	Urgency        ReportUrgency`json:"urgency"`
	Needs          int          `json:"needs"`
	MemberMask     int          `json:"member_mask"`
	Message        *string      `json:"message,omitempty"`
	Lat            *float64     `json:"lat,omitempty"`
	Lon            *float64     `json:"lon,omitempty"`
	Battery        *int         `json:"battery,omitempty"`
	Channel        string       `json:"channel"`
	ReporterUserID *string      `json:"reporter_user_id,omitempty"`
	BeaconID       *string      `json:"beacon_id,omitempty"`
	DeviceTime     time.Time    `json:"device_time"`
	ReceivedAt     time.Time    `json:"received_at"`
	RelayPath      []string     `json:"relay_path,omitempty"`
}

type HouseholdState struct {
	IncidentID            string             `json:"incident_id"`
	HouseholdID           string             `json:"household_id"`
	ReportID              *string            `json:"report_id,omitempty"`
	Seq                   int                `json:"seq"`
	Status                ReportStatus       `json:"status"`
	Urgency               ReportUrgency      `json:"urgency"`
	Needs                 int                `json:"needs"`
	MemberMask            int                `json:"member_mask"`
	PriorityScore         float64            `json:"priority_score"`
	ScoreBreakdown        map[string]float64 `json:"score_breakdown"`
	Reached               bool               `json:"reached"`
	UnconfirmedVulnerable int                `json:"unconfirmed_vulnerable"`
	NeedsConfirmation     bool               `json:"needs_confirmation"`
	UpdatedAt             time.Time          `json:"updated_at"`
}

type SubmitReportResult struct {
	Report        *Report         `json:"report"`
	State         *HouseholdState `json:"state"`
	AlreadyExists bool            `json:"already_exists"`
	ActionTaken   string          `json:"action_taken"` // "created", "already_exists", "needs_confirmation", "archived_older"
}

type BatchSyncResultItem struct {
	ReportID string `json:"report_id"`
	Status   string `json:"status"` // "diterima", "duplikat", "ditolak"
	Error    string `json:"error,omitempty"`
}

type TriageItem struct {
	HouseholdID     string          `json:"household_id"`
	Number          string          `json:"number"`
	Address         string          `json:"address"`
	BlockID         string          `json:"block_id"`
	BlockName       string          `json:"block_name,omitempty"`
	HeadName        string          `json:"head_name"`
	WAPhone         string          `json:"wa_phone"`
	HasDevice       bool            `json:"has_device"`
	VulnerableCount int             `json:"vulnerable_count"`
	Lat             *float64        `json:"lat,omitempty"`
	Lon             *float64        `json:"lon,omitempty"`
	State           *HouseholdState `json:"state,omitempty"`
	PriorityScore   float64         `json:"priority_score"`
	Reported        bool            `json:"reported"`
}
