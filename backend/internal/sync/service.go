package sync

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/relay"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

var (
	ErrBatchTooLarge = errors.New("jumlah item melebihi batas maksimum 50 item per batch (SDD 8.1)")
)

type Service struct {
	reportSvc      *report.Service
	reportStore    report.Store
	householdStore household.Store
	incidentStore  incident.Store
	volunteerStore volunteer.Store
	realtimeHub    *realtime.Hub
	dataKey        []byte
}

func NewService(
	reportSvc *report.Service,
	reportStore report.Store,
	householdStore household.Store,
	incidentStore incident.Store,
	volunteerStore volunteer.Store,
	realtimeHub *realtime.Hub,
	dataKey []byte,
) *Service {
	return &Service{
		reportSvc:      reportSvc,
		reportStore:    reportStore,
		householdStore: householdStore,
		incidentStore:  incidentStore,
		volunteerStore: volunteerStore,
		realtimeHub:    realtimeHub,
		dataKey:        dataKey,
	}
}

// SyncReports processes a batch of JSON reports from client outbox (FR-SYNC-01, SDD 8.1).
func (s *Service) SyncReports(ctx context.Context, reports []*report.Report) ([]SyncItemResult, error) {
	if len(reports) > MaxSyncBatchSize {
		return nil, ErrBatchTooLarge
	}

	results := make([]SyncItemResult, len(reports))

	for i, r := range reports {
		results[i].Index = i
		if r == nil {
			results[i].Status = "ditolak"
			results[i].Error = "laporan bernilai nil"
			continue
		}
		results[i].ReportID = r.ID

		if r.HouseholdID == "" {
			results[i].Status = "ditolak"
			results[i].Error = "household_id wajib diisi"
			continue
		}
		if r.Status < 1 || r.Status > 3 {
			results[i].Status = "ditolak"
			results[i].Error = "status laporan harus antara 1, 2, atau 3"
			continue
		}

		res, err := s.reportSvc.SubmitReport(ctx, r)
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = err.Error()
			continue
		}

		if res.AlreadyExists {
			results[i].Status = "duplikat"
		} else {
			results[i].Status = "diterima"

			// Broadcast real-time WebSocket event
			if s.realtimeHub != nil && res.State != nil {
				_ = s.realtimeHub.BroadcastEvent(ctx, r.IncidentID, &realtime.Event{
					Entity:   "household",
					EntityID: res.State.HouseholdID,
					Op:       "UPDATE",
					Payload: map[string]any{
						"household_id":       res.State.HouseholdID,
						"incident_id":        r.IncidentID,
						"status":             res.State.Status,
						"urgency":            res.State.Urgency,
						"needs":              res.State.Needs,
						"channel":            r.Channel,
						"priority_score":     res.State.PriorityScore,
						"needs_confirmation": res.State.NeedsConfirmation,
					},
					Origin: "cloud",
				})
			}
		}
	}

	return results, nil
}

// SyncRelayPackets decodes, verifies, and applies binary relay packets per SDD 7.2 & 9.4.
func (s *Service) SyncRelayPackets(ctx context.Context, req RelaySyncRequest) ([]SyncItemResult, error) {
	if len(req.Packets) > MaxSyncBatchSize {
		return nil, ErrBatchTooLarge
	}

	results := make([]SyncItemResult, len(req.Packets))

	for i, pItem := range req.Packets {
		results[i].Index = i

		rawBytes, err := base64.StdEncoding.DecodeString(pItem.Data)
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = "format base64 tidak valid: " + err.Error()
			continue
		}

		packet, err := relay.Decode(rawBytes)
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = "gagal decode paket relay: " + err.Error()
			continue
		}

		packetKey := fmt.Sprintf("%x:%d", packet.HouseholdShortID, packet.Seq)
		results[i].PacketKey = packetKey

		// Look up incident
		inc, err := s.incidentStore.GetIncidentByShortID(ctx, packet.IncidentShortID)
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = "insiden dengan short_id tersebut tidak ditemukan"
			continue
		}

		// Look up household
		hh, err := s.householdStore.GetHouseholdByShortID(ctx, packet.HouseholdShortID[:])
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = "rumah tangga dengan short_id tersebut tidak ditemukan"
			continue
		}

		// Decrypt household key and verify HMAC
		hhKey, err := household.DecryptAES256GCM(s.dataKey, hh.KeyEnc)
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = "gagal memuat kunci otentikasi rumah tangga"
			continue
		}

		if !packet.VerifyMAC(hhKey, rawBytes) {
			results[i].Status = "ditolak"
			results[i].Error = "verifikasi HMAC-SHA256 paket gagal"
			continue
		}

		// Deterministic UUIDv5 per SDD 7.2
		reportID := packet.GenerateReportUUID().String()
		results[i].ReportID = reportID

		channel := report.ChannelRelawan
		if packet.Flags&relay.FlagIsBeaconCheckin != 0 {
			channel = report.ChannelBeaconCheckin
		}

		bat := int(packet.Battery)
		var relayPathStrs []string
		for _, node := range packet.Path {
			relayPathStrs = append(relayPathStrs, fmt.Sprintf("%d", node))
		}

		var collectorID *string
		if req.CollectorID != "" {
			collectorID = &req.CollectorID
		}

		r := &report.Report{
			ID:             reportID,
			IncidentID:     inc.ID,
			HouseholdID:    hh.ID,
			Seq:            int(packet.Seq),
			Status:         report.ReportStatus(packet.Status),
			Urgency:        report.ReportUrgency(packet.Urgency),
			Needs:          int(packet.Needs),
			MemberMask:     int(packet.MemberMask),
			Battery:        &bat,
			Lat:            packet.Lat,
			Lon:            packet.Lon,
			Channel:        channel,
			ReporterUserID: collectorID,
			DeviceTime:     packet.CreatedAt,
			ReceivedAt:     time.Now().UTC(),
			RelayPath:      relayPathStrs,
		}

		res, err := s.reportSvc.SubmitReport(ctx, r)
		if err != nil {
			results[i].Status = "ditolak"
			results[i].Error = err.Error()
			continue
		}

		if res.AlreadyExists {
			results[i].Status = "duplikat"
		} else {
			results[i].Status = "diterima"

			if s.realtimeHub != nil && res.State != nil {
				_ = s.realtimeHub.BroadcastEvent(ctx, inc.ID, &realtime.Event{
					Entity:   "household",
					EntityID: res.State.HouseholdID,
					Op:       "UPDATE",
					Payload: map[string]any{
						"household_id":       res.State.HouseholdID,
						"incident_id":        inc.ID,
						"status":             res.State.Status,
						"urgency":            res.State.Urgency,
						"needs":              res.State.Needs,
						"channel":            channel,
						"priority_score":     res.State.PriorityScore,
						"needs_confirmation": res.State.NeedsConfirmation,
					},
					Origin: "cloud",
				})
			}
		}
	}

	return results, nil
}

// GetSnapshot retrieves local synchronization snapshot per SDD 8.1 & 9.4.
func (s *Service) GetSnapshot(ctx context.Context, scope, userID, role, rtID, householdID string) (*SnapshotResponse, error) {
	now := time.Now().UTC()

	if scope == "household" || (scope == "" && role == "warga") {
		if householdID == "" {
			return nil, errors.New("household_id tidak tersedia untuk pengguna warga")
		}
		hh, err := s.householdStore.GetHousehold(ctx, householdID)
		if err != nil {
			return nil, err
		}
		consent, _ := s.householdStore.GetActiveConsent(ctx, householdID)

		return &SnapshotResponse{
			Scope: "household",
			Household: &HouseholdSnapshot{
				Household:  hh,
				Consent:    consent,
				ServerTime: now,
			},
		}, nil
	}

	if scope == "volunteer" || (scope == "" && role == "relawan") {
		var blockIDs []string
		if s.volunteerStore != nil && userID != "" {
			assigned, err := s.volunteerStore.GetVolunteerBlocks(ctx, userID)
			if err == nil {
				blockIDs = assigned
			}
		}

		var households []*household.Household
		if len(blockIDs) > 0 {
			for _, bID := range blockIDs {
				bidCopy := bID
				list, err := s.householdStore.ListHouseholdsByRT(ctx, rtID, &bidCopy)
				if err == nil {
					households = append(households, list...)
				}
			}
		} else {
			list, err := s.householdStore.ListHouseholdsByRT(ctx, rtID, nil)
			if err == nil {
				households = list
			}
		}

		var activeInc *incident.Incident
		if s.incidentStore != nil && rtID != "" {
			realMode := incident.ModeNyata
			inc, err := s.incidentStore.GetActiveIncidentByRT(ctx, rtID, &realMode)
			if err == nil {
				activeInc = inc
			} else {
				drillMode := incident.ModeLatihan
				incDrill, err := s.incidentStore.GetActiveIncidentByRT(ctx, rtID, &drillMode)
				if err == nil {
					activeInc = incDrill
				}
			}
		}

		return &SnapshotResponse{
			Scope: "volunteer",
			Volunteer: &VolunteerSnapshot{
				VolunteerID:    userID,
				RTID:           rtID,
				BlockIDs:       blockIDs,
				Households:     households,
				ActiveIncident: activeInc,
				ServerTime:     now,
			},
		}, nil
	}

	return nil, errors.New("cakupan snapshot tidak valid (harus 'household' atau 'volunteer')")
}

// GetAcks retrieves received packet keys for relay cache pruning (SDD 9.4).
func (s *Service) GetAcks(ctx context.Context, incidentID string) (*AcksResponse, error) {
	reports, err := s.reportStore.ListReportsByIncident(ctx, incidentID)
	if err != nil {
		return nil, err
	}

	acks := make([]PacketAck, 0, len(reports))
	for _, r := range reports {
		hh, err := s.householdStore.GetHousehold(ctx, r.HouseholdID)
		if err == nil && hh != nil && len(hh.ShortID) > 0 {
			acks = append(acks, PacketAck{
				HouseholdShortID: hex.EncodeToString(hh.ShortID),
				Seq:              r.Seq,
			})
		}
	}

	return &AcksResponse{
		IncidentID: incidentID,
		Acks:       acks,
	}, nil
}
