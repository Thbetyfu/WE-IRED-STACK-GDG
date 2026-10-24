package sync

import (
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
)

const MaxSyncBatchSize = 50

type RelayPacketItem struct {
	Data string   `json:"data"` // base64 encoded binary packet (SDD 7.2)
	Path []uint16 `json:"path,omitempty"`
}

type RelaySyncRequest struct {
	CollectorID string            `json:"collector_id"`
	Packets     []RelayPacketItem `json:"packets"`
}

type SyncItemResult struct {
	Index     int    `json:"index"`
	ReportID  string `json:"report_id,omitempty"`
	PacketKey string `json:"packet_key,omitempty"` // household_short_id:seq
	Status    string `json:"status"`               // "diterima", "duplikat", "ditolak"
	Error     string `json:"error,omitempty"`
}

type PacketAck struct {
	HouseholdShortID string `json:"household_short_id"`
	Seq              int    `json:"seq"`
}

type AcksResponse struct {
	IncidentID string      `json:"incident_id"`
	Acks       []PacketAck `json:"acks"`
}

type HouseholdSnapshot struct {
	Household   *household.Household `json:"household"`
	Consent     *household.Consent   `json:"consent,omitempty"`
	ServerTime  time.Time            `json:"server_time"`
}

type VolunteerSnapshot struct {
	VolunteerID     string                `json:"volunteer_id"`
	RTID            string                `json:"rt_id"`
	BlockIDs        []string              `json:"block_ids"`
	Households      []*household.Household`json:"households"`
	ActiveIncident  *incident.Incident    `json:"active_incident,omitempty"`
	ServerTime      time.Time             `json:"server_time"`
}

type SnapshotResponse struct {
	Scope     string             `json:"scope"`
	Household *HouseholdSnapshot `json:"household,omitempty"`
	Volunteer *VolunteerSnapshot `json:"volunteer,omitempty"`
}
