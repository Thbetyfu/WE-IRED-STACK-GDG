package realtime

import (
	"time"
)

type EventType string

const (
	EventIncidentUpdated        EventType = "incident.updated"
	EventHouseholdStatusChanged EventType = "household.status_changed"
	EventPriorityRecomputed     EventType = "priority.recomputed"
	EventTaskUpdated            EventType = "task.updated"
	EventAnnouncementCreated    EventType = "announcement.created"
	EventBeaconTelemetry        EventType = "beacon.telemetry"
	EventExtAlertMatched        EventType = "ext_alert.matched"
)

// Event represents an immutable change event per SDD Section 5 & 9.6.
type Event struct {
	ID         int64          `json:"id"`
	RegionID   *string        `json:"region_id,omitempty"`
	IncidentID *string        `json:"incident_id,omitempty"`
	Entity     string         `json:"entity"`
	EntityID   string         `json:"entity_id"`
	Op         string         `json:"op"`
	Payload    map[string]any `json:"payload"`
	Origin     string         `json:"origin"`
	CreatedAt  time.Time      `json:"created_at"`
}
