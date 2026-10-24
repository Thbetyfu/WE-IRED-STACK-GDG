package announcement

import (
	"fmt"
	"time"
)

type AnnouncementLevel string

const (
	LevelNameInfo    AnnouncementLevel = "info"
	LevelNamePenting AnnouncementLevel = "penting"
	LevelNameDarurat AnnouncementLevel = "darurat"
)

func LevelToByte(l AnnouncementLevel) uint8 {
	switch l {
	case LevelNameDarurat:
		return LevelDarurat
	case LevelNamePenting:
		return LevelPenting
	default:
		return LevelInfo
	}
}

func LevelFromByte(b uint8) AnnouncementLevel {
	switch b {
	case LevelDarurat:
		return LevelNameDarurat
	case LevelPenting:
		return LevelNamePenting
	default:
		return LevelNameInfo
	}
}

// Announcement domain model (SDD 5.3 & 7.6).
type Announcement struct {
	ID         string            `json:"id"`
	RegionIDs  []string          `json:"region_ids"`
	IncidentID *string           `json:"incident_id,omitempty"`
	ShortID    uint32            `json:"short_id"`
	Level      AnnouncementLevel `json:"level"`
	Text       string            `json:"text"`
	ExpiresAt  time.Time         `json:"expires_at"`
	Signature  string            `json:"signature"`            // Base64 Ed25519 signature
	PayloadRaw []byte            `json:"payload_raw,omitempty"` // Full binary packet for BLE relay
	Channels   []string          `json:"channels"`             // push, whatsapp, relay
	CreatedBy  string            `json:"created_by"`
	CreatedAt  time.Time         `json:"created_at"`
}

func (a *Announcement) IsExpired(now time.Time) bool {
	if now.IsZero() {
		now = time.Now().UTC()
	}
	return now.After(a.ExpiresAt)
}

// CreateIncidentAlertPacket creates a signed Type 0x11 binary packet for incident activation/ending (SDD 7.6 & HRD 7.2).
// Only packets with Type 0x11 and valid Ed25519 signature can switch BLE beacons to SIAGA mode.
func CreateIncidentAlertPacket(
	incidentID string,
	incidentShortID uint32,
	rtShortID uint32,
	hazard string,
	isDrill bool,
	isEnded bool,
	km *KeyManager,
) ([]byte, *Packet, error) {
	now := time.Now().UTC()
	expiresAt := now.Add(24 * time.Hour)

	level := LevelDarurat
	modeStr := "NYATA"
	if isDrill {
		modeStr = "LATIHAN"
	}

	var alertText string
	if isEnded {
		level = LevelInfo
		alertText = fmt.Sprintf("SELESAI: %s (ID:%d)", hazard, incidentShortID)
	} else {
		alertText = fmt.Sprintf("SIAGA %s (ID:%d, %s)", hazard, incidentShortID, modeStr)
	}

	pkt := &Packet{
		Version:    ProtocolVersion,
		Type:       TypeIncidentAlert, // 0x11
		RTShortID:  rtShortID,
		AnnShortID: incidentShortID,
		Level:      level,
		CreatedAt:  now,
		ExpiresAt:  expiresAt,
		Text:       alertText,
	}

	rawBytes, err := km.SignAnnouncement(pkt)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to sign incident alert packet: %w", err)
	}

	return rawBytes, pkt, nil
}
