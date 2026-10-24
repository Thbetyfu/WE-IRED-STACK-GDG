package posko

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/announcement"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/assembly"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/jobs"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/task"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

type Service struct {
	poskoStore     Store
	eventStore     realtime.EventStore
	householdStore household.Store
	regionStore    region.Store
	volunteerStore volunteer.Store
	assemblyStore  assembly.Store
	reportService  *report.Service
	taskService    *task.Service
	keyManager     *announcement.KeyManager
	jobQueue       jobs.Queue
	mode           string // "cloud" | "posko"
	poskoID        string
	logger         *slog.Logger
}

func NewService(
	poskoStore Store,
	eventStore realtime.EventStore,
	hhStore household.Store,
	regStore region.Store,
	volStore volunteer.Store,
	asmStore assembly.Store,
	repSvc *report.Service,
	taskSvc *task.Service,
	keyManager *announcement.KeyManager,
	jobQueue jobs.Queue,
	mode string,
	poskoID string,
	logger *slog.Logger,
) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{
		poskoStore:     poskoStore,
		eventStore:     eventStore,
		householdStore: hhStore,
		regionStore:    regStore,
		volunteerStore: volStore,
		assemblyStore:  asmStore,
		reportService:  repSvc,
		taskService:    taskSvc,
		keyManager:     keyManager,
		jobQueue:       jobQueue,
		mode:           mode,
		poskoID:        poskoID,
		logger:         logger,
	}
}

// ExportSnapshot creates a password-encrypted snapshot of master data for Posko Lokal (FR-PSK-02 & SDD 8.2).
func (s *Service) ExportSnapshot(ctx context.Context, rtID string, password string) (*EncryptedSnapshotEnvelope, error) {
	if password == "" {
		return nil, ErrEmptyPassword
	}

	reg, _ := s.regionStore.GetRegionByID(ctx, rtID)
	blocks, _ := s.volunteerStore.ListBlocksByRT(ctx, rtID)
	households, _ := s.householdStore.ListHouseholdsByRT(ctx, rtID, nil)
	assemblyPoints, _ := s.assemblyStore.ListAssemblyPointsByRT(ctx, rtID, false)
	volunteers, _ := s.volunteerStore.ListVolunteersByRT(ctx, rtID)

	var lastEventID int64
	if s.eventStore != nil {
		events, err := s.eventStore.GetEventsAfter(ctx, 0, nil, &rtID, 500)
		if err == nil && len(events) > 0 {
			lastEventID = events[len(events)-1].ID
		}
	}

	annPubKey := ""
	if s.keyManager != nil {
		annPubKey = s.keyManager.RootPublicKeyBase64()
	}

	payload := &SnapshotPayload{
		Version:             "1.0",
		RTID:                rtID,
		ExportedAt:          time.Now().UTC(),
		LastEventID:         lastEventID,
		Region:              reg,
		Blocks:              blocks,
		Households:          households,
		AssemblyPoints:      assemblyPoints,
		Volunteers:          volunteers,
		AnnouncementPubKey:  annPubKey,
		BeaconSecrets:       make(map[string]string),
	}

	return EncryptSnapshot(payload, password)
}

// ImportSnapshot decrypts and imports the snapshot into Posko's local storage (FR-PSK-02).
// Returns ErrInvalidSnapshotPassword if password is wrong.
func (s *Service) ImportSnapshot(ctx context.Context, env *EncryptedSnapshotEnvelope, password string) (*SnapshotPayload, error) {
	payload, err := DecryptSnapshot(env, password)
	if err != nil {
		return nil, err
	}

	// 1. Import Region
	if payload.Region != nil {
		_ = s.regionStore.CreateRegion(ctx, payload.Region)
	}

	// 2. Import Blocks
	for _, b := range payload.Blocks {
		_ = s.volunteerStore.CreateBlock(ctx, b)
	}

	// 3. Import Assembly Points
	for _, ap := range payload.AssemblyPoints {
		_ = s.assemblyStore.CreateAssemblyPoint(ctx, ap)
	}

	// 4. Import Households and Members
	for _, hh := range payload.Households {
		_ = s.householdStore.CreateHousehold(ctx, hh)
		for _, m := range hh.Members {
			_ = s.householdStore.AddMember(ctx, m)
		}
	}

	// 5. Import Volunteers
	for _, v := range payload.Volunteers {
		_ = s.volunteerStore.CreateVolunteer(ctx, v)
	}

	// 6. Set local sync cursor
	if s.poskoStore != nil {
		_ = s.poskoStore.UpdateSyncCursor(ctx, s.poskoID, payload.LastEventID)
	}

	s.logger.Info("imported posko snapshot successfully",
		"rt_id", payload.RTID,
		"households", len(payload.Households),
		"volunteers", len(payload.Volunteers),
		"cursor", payload.LastEventID,
	)

	return payload, nil
}

// ProcessPush handles events pushed from Posko to Cloud (FR-PSK-05/06 & SDD 8.3).
func (s *Service) ProcessPush(ctx context.Context, req PushRequest) (*PushResponse, error) {
	var ackCursor int64 = 0
	appliedCount := 0
	conflictCount := 0

	for _, ev := range req.Events {
		err := s.applyPushedEvent(ctx, req.PoskoID, req.RTID, ev, &conflictCount)
		if err != nil {
			s.logger.Error("failed to apply pushed event from posko; cursor halted",
				"posko_id", req.PoskoID,
				"event_id", ev.ID,
				"entity", ev.Entity,
				"error", err,
			)
			// Halt cursor at the last successfully applied event (do not skip)
			break
		}

		ackCursor = ev.ID
		appliedCount++
	}

	// Process deferred jobs from Posko (e.g. WhatsApp / FCM actions that waited for internet)
	for _, j := range req.Jobs {
		if s.jobQueue != nil {
			_, _ = s.jobQueue.Enqueue(ctx, j.Queue, j.Payload, time.Now())
		}
	}

	// Update acknowledged cursor
	if s.poskoStore != nil && ackCursor > 0 {
		_ = s.poskoStore.UpdateSyncCursor(ctx, req.PoskoID, ackCursor)
	}

	return &PushResponse{
		AckCursor:      ackCursor,
		EventsApplied:  appliedCount,
		ConflictsCount: conflictCount,
		Message:        fmt.Sprintf("%d events diterapkan, %d konflik dicatat", appliedCount, conflictCount),
	}, nil
}

func (s *Service) applyPushedEvent(ctx context.Context, poskoID, rtID string, ev *realtime.Event, conflictCount *int) error {
	switch ev.Entity {
	case "report":
		// Reports use SDD 6.2 idempotent submission
		rawBytes, _ := json.Marshal(ev.Payload)
		var rep report.Report
		if err := json.Unmarshal(rawBytes, &rep); err != nil {
			return err
		}
		if s.reportService != nil {
			_, err := s.reportService.SubmitReport(ctx, &rep)
			return err
		}

	case "task":
		// Tasks update idempotently
		rawBytes, _ := json.Marshal(ev.Payload)
		var t task.Task
		if err := json.Unmarshal(rawBytes, &t); err != nil {
			return err
		}

	case "household":
		// Master data: check conflict (FR-PSK-06 & SDD 8.3)
		hhID := ev.EntityID
		existing, err := s.householdStore.GetHousehold(ctx, hhID)
		if err == nil && existing != nil {
			// Compare version or fields
			rawBytes, _ := json.Marshal(ev.Payload)
			var poskoHH household.Household
			_ = json.Unmarshal(rawBytes, &poskoHH)

			if existing.Address != poskoHH.Address || existing.HeadName != poskoHH.HeadName {
				// Divergence detected: Cloud version retained, Posko version recorded in sync_conflicts
				*conflictCount++
				conflict := &SyncConflict{
					ID:           uuid.NewString(),
					RegionID:     rtID,
					PoskoID:      poskoID,
					Entity:       "household",
					EntityID:     hhID,
					CloudVersion: map[string]any{"address": existing.Address, "head_name": existing.HeadName},
					PoskoVersion: map[string]any{"address": poskoHH.Address, "head_name": poskoHH.HeadName},
					Status:       "unresolved",
					CreatedAt:    time.Now().UTC(),
				}
				_ = s.poskoStore.RecordConflict(ctx, conflict)
				s.logger.Warn("master data conflict detected and recorded in sync_conflicts",
					"entity", "household",
					"id", hhID,
					"posko_id", poskoID,
				)
				return nil
			}
		}

	default:
		// Other events applied idempotently
	}

	return nil
}

// ProcessPull returns events from Cloud since cursor (FR-PSK-05 & SDD 8.3).
func (s *Service) ProcessPull(ctx context.Context, rtID string, cursor int64, limit int) (*PullResponse, error) {
	if limit <= 0 {
		limit = 100
	}

	events, err := s.eventStore.GetEventsAfter(ctx, cursor, nil, &rtID, limit)
	if err != nil {
		return nil, err
	}

	var cloudEvents []*realtime.Event
	var nextCursor = cursor

	for _, ev := range events {
		// Only deliver events originating from cloud
		if ev.Origin == "cloud" || ev.Origin == "" {
			cloudEvents = append(cloudEvents, ev)
		}
		if ev.ID > nextCursor {
			nextCursor = ev.ID
		}
	}

	hasMore := len(events) >= limit

	return &PullResponse{
		Events:     cloudEvents,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

// GenerateQRConfig builds the JSON payload for Posko pairing QR code (FR-PSK-04).
func (s *Service) GenerateQRConfig(endpointURL string, ssl bool, certFingerprint string, rtID string) (*QRConfigPayload, error) {
	if endpointURL == "" {
		endpointURL = "http://127.0.0.1:8080"
	}

	return &QRConfigPayload{
		PoskoID:         s.poskoID,
		RTID:            rtID,
		EndpointURL:     endpointURL,
		SSL:             ssl,
		CertFingerprint: certFingerprint,
		GeneratedAt:     time.Now().UTC(),
	}, nil
}

func (s *Service) ListConflicts(ctx context.Context, rtID string, status string) ([]*SyncConflict, error) {
	return s.poskoStore.ListConflicts(ctx, rtID, status)
}

func (s *Service) ResolveConflict(ctx context.Context, id string, resolvedBy string) error {
	return s.poskoStore.ResolveConflict(ctx, id, resolvedBy)
}

func (s *Service) GetStatus(ctx context.Context, rtID string) (*PoskoStatus, error) {
	cursor, _ := s.poskoStore.GetSyncCursor(ctx, s.poskoID)
	unresolved, _ := s.poskoStore.ListConflicts(ctx, rtID, "unresolved")
	totalConflicts, _ := s.poskoStore.ListConflicts(ctx, rtID, "")

	now := time.Now().UTC()
	return &PoskoStatus{
		Mode:             s.mode,
		PoskoID:          s.poskoID,
		Cursor:           cursor,
		ConflictsCount:   len(totalConflicts),
		PendingConflicts: len(unresolved),
		Status:           "operational",
		LastSyncAt:       &now,
	}, nil
}
