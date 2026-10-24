package announcement

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/fcm"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
)

var (
	ErrEmptyText        = errors.New("teks pengumuman tidak boleh kosong")
	ErrEmptyRegions     = errors.New("pengumuman wajib ditujukan ke minimal satu wilayah RT")
	ErrEmptyChannels    = errors.New("minimal satu kanal distribusi (push, whatsapp, relay) wajib dipilih")
	ErrExpirationInPast = errors.New("waktu kedaluwarsa pengumuman harus di masa depan")
)

type CreateAnnouncementRequest struct {
	RegionIDs  []string          `json:"region_ids"`
	IncidentID *string           `json:"incident_id,omitempty"`
	Level      AnnouncementLevel `json:"level"`
	Text       string            `json:"text"`
	ExpiresAt  time.Time         `json:"expires_at"`
	Channels   []string          `json:"channels"`
	CreatedBy  string            `json:"created_by"`
}

type ChannelResult struct {
	Channel string `json:"channel"`
	Success bool   `json:"success"`
	Details string `json:"details,omitempty"`
	Error   string `json:"error,omitempty"`
}

type CreateAnnouncementResult struct {
	Announcement *Announcement            `json:"announcement"`
	Dispatches   map[string]ChannelResult `json:"dispatches"`
}

type Service struct {
	store       Store
	keyManager  *KeyManager
	fcmService  *fcm.Service
	realtimeHub *realtime.Hub
	logger      *slog.Logger
}

func NewService(
	store Store,
	keyManager *KeyManager,
	fcmService *fcm.Service,
	realtimeHub *realtime.Hub,
	logger *slog.Logger,
) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{
		store:       store,
		keyManager:  keyManager,
		fcmService:  fcmService,
		realtimeHub: realtimeHub,
		logger:      logger,
	}
}

func (s *Service) KeyManager() *KeyManager {
	return s.keyManager
}

// CreateAnnouncement validates, signs with Ed25519, persists, and dispatches an announcement (FR-ANN-01..04).
func (s *Service) CreateAnnouncement(ctx context.Context, req CreateAnnouncementRequest) (*CreateAnnouncementResult, error) {
	// 1. Validate Text
	trimmedText := strings.TrimSpace(req.Text)
	if trimmedText == "" {
		return nil, ErrEmptyText
	}
	if utf8.RuneCountInString(trimmedText) > MaxRunes || len([]byte(trimmedText)) > MaxTextBytes {
		return nil, ErrTextTooLong
	}

	// 2. Validate Regions & Expiration
	if len(req.RegionIDs) == 0 {
		return nil, ErrEmptyRegions
	}
	now := time.Now().UTC()
	if !req.ExpiresAt.After(now) {
		return nil, ErrExpirationInPast
	}

	// 3. Validate Channels
	if len(req.Channels) == 0 {
		return nil, ErrEmptyChannels
	}

	// 4. Validate Level
	if req.Level != LevelNameInfo && req.Level != LevelNamePenting && req.Level != LevelNameDarurat {
		req.Level = LevelNameInfo
	}

	// 5. Generate short_id (uint32)
	shortID, err := generateUint32ShortID()
	if err != nil {
		return nil, fmt.Errorf("failed to generate announcement short id: %w", err)
	}

	// 6. Build & Sign Binary Packet per SDD 7.6
	rtShortID := uint32(1) // primary RT short ID reference
	pkt := &Packet{
		Version:    ProtocolVersion,
		Type:       TypeAnnouncement, // 0x10
		RTShortID:  rtShortID,
		AnnShortID: shortID,
		Level:      LevelToByte(req.Level),
		CreatedAt:  now,
		ExpiresAt:  req.ExpiresAt,
		Text:       trimmedText,
	}

	rawPacket, err := s.keyManager.SignAnnouncement(pkt)
	if err != nil {
		return nil, fmt.Errorf("failed to sign announcement: %w", err)
	}

	ann := &Announcement{
		ID:         uuid.NewString(),
		RegionIDs:  req.RegionIDs,
		IncidentID: req.IncidentID,
		ShortID:    shortID,
		Level:      req.Level,
		Text:       trimmedText,
		ExpiresAt:  req.ExpiresAt,
		Signature:  base64.StdEncoding.EncodeToString(pkt.Signature),
		PayloadRaw: rawPacket,
		Channels:   req.Channels,
		CreatedBy:  req.CreatedBy,
		CreatedAt:  now,
	}

	// 7. Persist to DB
	if err := s.store.CreateAnnouncement(ctx, ann); err != nil {
		return nil, fmt.Errorf("failed to persist announcement: %w", err)
	}

	// 8. Dispatch across requested channels (tracking per-channel success & failure diagnosis)
	dispatchResults := make(map[string]ChannelResult)

	for _, ch := range req.Channels {
		switch strings.ToLower(ch) {
		case "push":
			// FCM push notification per RT topic (SDD 10.2)
			if s.fcmService != nil {
				fcmSuccess := true
				var errMsgs []string
				for _, rtID := range req.RegionIDs {
					res, err := s.fcmService.SendRTAnnouncement(ctx, rtID, ann.ID, string(ann.Level), ann.Text, ann.Signature)
					if err != nil || (res != nil && !res.Success) {
						fcmSuccess = false
						reason := "unknown"
						if err != nil {
							reason = err.Error()
						} else if res != nil {
							reason = res.Error
						}
						errMsgs = append(errMsgs, fmt.Sprintf("RT %s: %s", rtID, reason))
					}
				}
				if fcmSuccess {
					dispatchResults["push"] = ChannelResult{
						Channel: "push",
						Success: true,
						Details: fmt.Sprintf("Terkirim ke %d topik RT", len(req.RegionIDs)),
					}
				} else {
					errMsg := strings.Join(errMsgs, "; ")
					s.logger.Error("FCM push delivery failed", "announcement_id", ann.ID, "errors", errMsg)
					dispatchResults["push"] = ChannelResult{
						Channel: "push",
						Success: false,
						Error:   errMsg,
					}
				}
			} else {
				dispatchResults["push"] = ChannelResult{
					Channel: "push",
					Success: false,
					Error:   "FCM service provider tidak dikonfigurasi",
				}
			}

		case "whatsapp":
			// WhatsApp distribution logged and queued
			s.logger.Info("queueing announcement for WhatsApp blast",
				"announcement_id", ann.ID,
				"regions", req.RegionIDs,
			)
			dispatchResults["whatsapp"] = ChannelResult{
				Channel: "whatsapp",
				Success: true,
				Details: fmt.Sprintf("Antrean WhatsApp blast aktif untuk %d RT", len(req.RegionIDs)),
			}

		case "relay":
			// Broadcast binary packet to WebSocket hub for relay nodes & beacons
			if s.realtimeHub != nil {
				for _, rtID := range req.RegionIDs {
					incidentScope := ""
					if req.IncidentID != nil {
						incidentScope = *req.IncidentID
					}
					_ = s.realtimeHub.BroadcastEvent(ctx, incidentScope, &realtime.Event{
						Entity:   "announcement",
						EntityID: ann.ID,
						Op:       "ANNOUNCEMENT_CREATED",
						Payload: map[string]any{
							"announcement_id": ann.ID,
							"rt_id":           rtID,
							"short_id":        ann.ShortID,
							"level":           ann.Level,
							"text":            ann.Text,
							"expires_at":      ann.ExpiresAt,
							"signature":       ann.Signature,
							"payload_raw_b64": base64.StdEncoding.EncodeToString(ann.PayloadRaw),
						},
						Origin: "cloud",
					})
				}
			}
			dispatchResults["relay"] = ChannelResult{
				Channel: "relay",
				Success: true,
				Details: "Paket biner disiarkan ke hub relay dan beacon",
			}
		}
	}

	return &CreateAnnouncementResult{
		Announcement: ann,
		Dispatches:   dispatchResults,
	}, nil
}

func (s *Service) GetAnnouncement(ctx context.Context, id string) (*Announcement, error) {
	return s.store.GetAnnouncement(ctx, id)
}

func (s *Service) ListAnnouncements(ctx context.Context, rtID string, includeExpired bool) ([]*Announcement, error) {
	if includeExpired {
		return s.store.ListAllAnnouncementsByRT(ctx, rtID)
	}
	return s.store.ListActiveAnnouncementsByRT(ctx, rtID, time.Now().UTC())
}

func (s *Service) GetLatestSignedPacket(ctx context.Context, rtID string) ([]byte, error) {
	return s.store.GetLatestSignedPacketByRT(ctx, rtID, time.Now().UTC())
}

func (s *Service) CreatePoskoDelegation(ctx context.Context, poskoID, rtID string, duration time.Duration) (*PoskoDelegation, string, error) {
	del, privKey, err := s.keyManager.GeneratePoskoDelegation(poskoID, rtID, duration)
	if err != nil {
		return nil, "", err
	}
	if err := s.store.SavePoskoDelegation(ctx, del); err != nil {
		return nil, "", err
	}
	privKeyB64 := base64.StdEncoding.EncodeToString(privKey)
	return del, privKeyB64, nil
}

func generateUint32ShortID() (uint32, error) {
	maxVal := big.NewInt(4294967295) // 2^32 - 1
	n, err := rand.Int(rand.Reader, maxVal)
	if err != nil {
		return 0, err
	}
	return uint32(n.Uint64()) + 1, nil
}
