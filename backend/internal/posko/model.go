package posko

import (
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/assembly"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

// SnapshotPayload represents the decrypted data payload exported from Cloud for Posko (SDD 8.2).
type SnapshotPayload struct {
	Version             string                     `json:"version"`
	RTID                string                     `json:"rt_id"`
	ExportedAt          time.Time                  `json:"exported_at"`
	LastEventID         int64                      `json:"last_event_id"`
	Region              *region.Region             `json:"region"`
	Blocks              []*volunteer.Block         `json:"blocks"`
	Households          []*household.Household     `json:"households"`
	AssemblyPoints      []*assembly.AssemblyPoint  `json:"assembly_points"`
	Volunteers          []*volunteer.Volunteer     `json:"volunteers"`
	AnnouncementPubKey  string                     `json:"announcement_pub_key"`
	BeaconSecrets       map[string]string          `json:"beacon_secrets"` // beacon_id -> secret
}

// EncryptedSnapshotEnvelope represents the serialized AES-256-GCM package.
type EncryptedSnapshotEnvelope struct {
	Magic      string `json:"magic"` // "WRSN" (WE-IRED Snapshot)
	Salt       string `json:"salt"`  // Base64 16 bytes
	Nonce      string `json:"nonce"` // Base64 12 bytes
	Ciphertext string `json:"ciphertext"` // Base64 ciphertext + tag
	CreatedAt  time.Time `json:"created_at"`
}

// PushRequest represents events sent from Posko to Cloud (SDD 8.3).
type PushRequest struct {
	PoskoID string            `json:"posko_id"`
	RTID    string            `json:"rt_id"`
	Events  []*realtime.Event `json:"events"`
	Jobs    []DeferredJob     `json:"jobs,omitempty"`
}

// PushResponse returns acknowledgment cursor and conflicts if any.
type PushResponse struct {
	AckCursor      int64  `json:"ack_cursor"`
	EventsApplied  int    `json:"events_applied"`
	ConflictsCount int    `json:"conflicts_count"`
	Message        string `json:"message"`
}

// PullResponse represents events delivered from Cloud to Posko.
type PullResponse struct {
	Events     []*realtime.Event `json:"events"`
	NextCursor int64             `json:"next_cursor"`
	HasMore    bool              `json:"has_more"`
}

// DeferredJob represents an offline action (WhatsApp/FCM) queued at Posko to be executed by Cloud.
type DeferredJob struct {
	ID        string         `json:"id"`
	Queue     string         `json:"queue"` // "whatsapp" | "fcm"
	Payload   map[string]any `json:"payload"`
	CreatedAt time.Time      `json:"created_at"`
}

// SyncConflict documents master data divergence between Cloud and Posko (SDD 8.3).
type SyncConflict struct {
	ID           string         `json:"id"`
	RegionID     string         `json:"region_id"`
	PoskoID      string         `json:"posko_id"`
	Entity       string         `json:"entity"` // "household" | "member"
	EntityID     string         `json:"entity_id"`
	CloudVersion map[string]any `json:"cloud_version"`
	PoskoVersion map[string]any `json:"posko_version"`
	Status       string         `json:"status"` // "unresolved" | "resolved" | "ignored"
	ResolvedBy   *string        `json:"resolved_by,omitempty"`
	ResolvedAt   *time.Time     `json:"resolved_at,omitempty"`
	CreatedAt    time.Time      `json:"created_at"`
}

// QRConfigPayload represents the connection string encoded into the Posko QR code (FR-PSK-04).
type QRConfigPayload struct {
	PoskoID         string    `json:"posko_id"`
	RTID            string    `json:"rt_id"`
	EndpointURL     string    `json:"endpoint_url"`
	SSL             bool      `json:"ssl"`
	CertFingerprint string    `json:"cert_fingerprint"` // SHA-256 hex uppercase
	GeneratedAt     time.Time `json:"generated_at"`
}

// PoskoStatus represents current synchronization and operational status of Posko / Cloud.
type PoskoStatus struct {
	Mode             string     `json:"mode"`
	PoskoID          string     `json:"posko_id"`
	Cursor           int64      `json:"cursor"`
	ConflictsCount   int        `json:"conflicts_count"`
	PendingConflicts int        `json:"pending_conflicts"`
	Status           string     `json:"status"` // "operational", "standby"
	LastSyncAt       *time.Time `json:"last_sync_at,omitempty"`
}
