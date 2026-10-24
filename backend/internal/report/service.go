package report

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
)

type HouseholdInfo struct {
	ID              string
	RTID            string
	BlockID         string
	Number          string
	Address         string
	Lat             *float64
	Lon             *float64
	HeadName        string
	WAPhone         string
	HasDevice       bool
	VulnerableCount int
}

type HouseholdInfoProvider interface {
	GetHouseholdsInScope(ctx context.Context, rtID string, blockIDs []string) ([]*HouseholdInfo, error)
	GetHouseholdInfo(ctx context.Context, id string) (*HouseholdInfo, error)
}

type Service struct {
	store             Store
	householdProvider HouseholdInfoProvider
}

func NewService(store Store) *Service {
	return &Service{store: store}
}

func (s *Service) SetHouseholdProvider(p HouseholdInfoProvider) {
	s.householdProvider = p
}

// SubmitReport processes an incoming report according to SDD 6.2 resolution rules.
func (s *Service) SubmitReport(ctx context.Context, r *Report) (*SubmitReportResult, error) {
	// Step 1: Idempotency check by ID
	if existing, err := s.store.GetReport(ctx, r.ID); err == nil && existing != nil {
		st, _ := s.store.GetHouseholdState(ctx, r.IncidentID, r.HouseholdID)
		return &SubmitReportResult{
			Report:        existing,
			State:         st,
			AlreadyExists: true,
			ActionTaken:   "already_exists",
		}, nil
	}

	// Step 2: Handle server sequence assignment for proxy (relawan) reports or unassigned seq
	if r.Channel == ChannelRelawan || r.Seq <= 0 {
		maxSeq, err := s.store.GetMaxSeq(ctx, r.IncidentID, r.HouseholdID)
		if err != nil {
			return nil, fmt.Errorf("failed to query max seq: %w", err)
		}
		r.Seq = maxSeq + 1
	}

	// Step 3: Check idempotency by (incident, household, seq)
	if existing, err := s.store.GetReportBySeq(ctx, r.IncidentID, r.HouseholdID, r.Seq); err == nil && existing != nil {
		st, _ := s.store.GetHouseholdState(ctx, r.IncidentID, r.HouseholdID)
		return &SubmitReportResult{
			Report:        existing,
			State:         st,
			AlreadyExists: true,
			ActionTaken:   "already_exists",
		}, nil
	}

	now := time.Now().UTC()
	if r.ReceivedAt.IsZero() {
		r.ReceivedAt = now
	}
	if r.DeviceTime.IsZero() {
		r.DeviceTime = r.ReceivedAt
	}

	// Step 4: Persist raw report
	alreadyExists, err := s.store.SaveReport(ctx, r)
	if err != nil {
		return nil, fmt.Errorf("failed to save report: %w", err)
	}
	if alreadyExists {
		st, _ := s.store.GetHouseholdState(ctx, r.IncidentID, r.HouseholdID)
		return &SubmitReportResult{
			Report:        r,
			State:         st,
			AlreadyExists: true,
			ActionTaken:   "already_exists",
		}, nil
	}

	// Step 5: SDD 6.2 Status Resolution Logic
	existingState, _ := s.store.GetHouseholdState(ctx, r.IncidentID, r.HouseholdID)
	actionTaken := "created"
	var targetState HouseholdState

	if existingState == nil {
		targetState = HouseholdState{
			IncidentID:        r.IncidentID,
			HouseholdID:       r.HouseholdID,
			ReportID:          &r.ID,
			Seq:               r.Seq,
			Status:            r.Status,
			Urgency:           r.Urgency,
			Needs:             r.Needs,
			MemberMask:        r.MemberMask,
			NeedsConfirmation: false,
			UpdatedAt:         r.ReceivedAt,
		}
		actionTaken = "created"
	} else {
		targetState = *existingState
		if r.Seq > existingState.Seq {
			// CRITICAL STATE EXCEPTION (SDD 6.2):
			// If current state is butuh_bantuan KRITIS, and incoming report is beacon_checkin without volunteer/citizen confirmation:
			isCritical := existingState.Status == StatusButuhBantuan && existingState.Urgency == UrgencyKritis
			isBeaconCheckin := r.Channel == ChannelBeaconCheckin
			hasConfirmation := (r.ReporterUserID != nil && *r.ReporterUserID != "") || r.Channel == ChannelRelawan || r.Channel == ChannelAplikasi

			if isCritical && isBeaconCheckin && !hasConfirmation {
				// Record report, flag needs_confirmation = true, DO NOT overwrite status!
				targetState.NeedsConfirmation = true
				targetState.UpdatedAt = r.ReceivedAt
				actionTaken = "needs_confirmation"
			} else {
				targetState.ReportID = &r.ID
				targetState.Seq = r.Seq
				targetState.Status = r.Status
				targetState.Urgency = r.Urgency
				targetState.Needs = r.Needs
				targetState.MemberMask = r.MemberMask
				targetState.UpdatedAt = r.ReceivedAt
				if r.Status != StatusButuhBantuan || r.Urgency != UrgencyKritis {
					targetState.NeedsConfirmation = false
				}
				actionTaken = "updated"
			}
		} else if r.Seq == existingState.Seq && r.ReceivedAt.Before(existingState.UpdatedAt) {
			// Tie-breaker: earlier server received_at wins
			targetState.ReportID = &r.ID
			targetState.Seq = r.Seq
			targetState.Status = r.Status
			targetState.Urgency = r.Urgency
			targetState.Needs = r.Needs
			targetState.MemberMask = r.MemberMask
			targetState.UpdatedAt = r.ReceivedAt
			actionTaken = "tie_broken_earlier"
		} else {
			// Older sequence arriving out-of-order: keep in reports log, do not regress state
			actionTaken = "archived_older"
		}
	}

	// Step 6: Recalculate Priority Score (SDD 6.1)
	vulnCount := 0
	if s.householdProvider != nil {
		if hh, err := s.householdProvider.GetHouseholdInfo(ctx, r.HouseholdID); err == nil && hh != nil {
			vulnCount = hh.VulnerableCount
		}
	}
	targetState.UnconfirmedVulnerable = vulnCount

	score, breakdown := CalculatePriorityScore(&targetState, vulnCount, time.Time{}, nil, nil)
	targetState.PriorityScore = score
	targetState.ScoreBreakdown = breakdown

	if err := s.store.UpsertHouseholdState(ctx, &targetState); err != nil {
		return nil, fmt.Errorf("failed to upsert household state: %w", err)
	}

	return &SubmitReportResult{
		Report:        r,
		State:         &targetState,
		AlreadyExists: false,
		ActionTaken:   actionTaken,
	}, nil
}

// BatchSyncReports processes a batch of reports from client outbox (FR-SYNC-01, FR-RPT-07).
func (s *Service) BatchSyncReports(ctx context.Context, reports []*Report) ([]BatchSyncResultItem, error) {
	results := make([]BatchSyncResultItem, 0, len(reports))

	for _, r := range reports {
		res, err := s.SubmitReport(ctx, r)
		if err != nil {
			results = append(results, BatchSyncResultItem{
				ReportID: r.ID,
				Status:   "ditolak",
				Error:    err.Error(),
			})
			continue
		}

		if res.AlreadyExists {
			results = append(results, BatchSyncResultItem{
				ReportID: r.ID,
				Status:   "duplikat",
			})
		} else {
			results = append(results, BatchSyncResultItem{
				ReportID: r.ID,
				Status:   "diterima",
			})
		}
	}

	return results, nil
}

// CalculatePriorityScore computes priority score per SDD 6.1:
// Skor = min(100, U + V + W + N + D)
func CalculatePriorityScore(
	state *HouseholdState,
	unconfirmedVuln int,
	incidentStartTime time.Time,
	lastHelpTime *time.Time,
	distMeters *float64,
) (float64, map[string]float64) {
	breakdown := make(map[string]float64)

	// U - Status & Urgensi (maks 40)
	var u float64
	if state == nil || state.Status == 0 {
		u = 22.0 // Belum melapor
	} else {
		switch state.Status {
		case StatusButuhBantuan:
			if state.Urgency == UrgencyKritis {
				u = 40.0 // Butuh bantuan kritis
			} else {
				u = 28.0 // Butuh bantuan biasa
			}
		case StatusAman:
			if state.Needs > 0 {
				u = 10.0 // Aman di rumah dengan kebutuhan
			} else {
				u = 0.0 // Aman tanpa kebutuhan (keluar antrean)
			}
		case StatusTitikKumpul:
			if unconfirmedVuln > 0 {
				u = 8.0 // Di titik kumpul dengan anggota rentan belum terkonfirmasi
			} else {
				u = 0.0 // Di titik kumpul lengkap
			}
		}
	}
	breakdown["U"] = u

	// V - Kerentanan (maks 24)
	v := math.Min(24.0, 8.0*float64(unconfirmedVuln))
	breakdown["V"] = v

	// W - Lama menunggu (maks 20)
	var w float64
	now := time.Now().UTC()
	if !incidentStartTime.IsZero() {
		var waitMinutes float64
		if state == nil || state.Status == 0 {
			waitMinutes = now.Sub(incidentStartTime).Minutes()
		} else if state.Status == StatusButuhBantuan {
			if lastHelpTime != nil && !lastHelpTime.IsZero() {
				waitMinutes = now.Sub(*lastHelpTime).Minutes()
			} else {
				waitMinutes = now.Sub(state.UpdatedAt).Minutes()
			}
		}
		if waitMinutes > 0 {
			w = math.Min(20.0, 0.25*waitMinutes)
		}
	}
	breakdown["W"] = w

	// N - Kebutuhan (maks 10)
	var n float64
	if state != nil && state.Needs > 0 {
		needsSum := 0.0
		if state.Needs&NeedEvakuasi != 0 {
			needsSum += 6.0
		}
		if state.Needs&NeedMedis != 0 {
			needsSum += 6.0
		}
		if state.Needs&NeedMakananAir != 0 {
			needsSum += 2.0
		}
		if state.Needs&NeedTempatTinggal != 0 {
			needsSum += 2.0
		}
		if state.Needs&NeedLainnya != 0 {
			needsSum += 1.0
		}
		n = math.Min(10.0, needsSum)
	}
	breakdown["N"] = n

	// D - Jarak (maks 6)
	var d float64
	if distMeters != nil && *distMeters > 0 {
		d = 6.0 * math.Min(1.0, *distMeters/500.0)
	}
	breakdown["D"] = d

	total := math.Min(100.0, u+v+w+n+d)
	breakdown["total"] = total
	return total, breakdown
}

// ReconstructHouseholdState applies all raw reports in sequence to rebuild the final state (SDD 6.2).
func ReconstructHouseholdState(incidentID, householdID string, reports []*Report) *HouseholdState {
	if len(reports) == 0 {
		return nil
	}

	// Sort reports by ReceivedAt to replay arrival sequence
	sorted := make([]*Report, len(reports))
	copy(sorted, reports)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].ReceivedAt.Before(sorted[j].ReceivedAt)
	})

	var state *HouseholdState

	for _, r := range sorted {
		if r.IncidentID != incidentID || r.HouseholdID != householdID {
			continue
		}

		if state == nil {
			state = &HouseholdState{
				IncidentID:        r.IncidentID,
				HouseholdID:       r.HouseholdID,
				ReportID:          &r.ID,
				Seq:               r.Seq,
				Status:            r.Status,
				Urgency:           r.Urgency,
				Needs:             r.Needs,
				MemberMask:        r.MemberMask,
				NeedsConfirmation: false,
				UpdatedAt:         r.ReceivedAt,
			}
			continue
		}

		if r.Seq > state.Seq {
			isCritical := state.Status == StatusButuhBantuan && state.Urgency == UrgencyKritis
			isBeaconCheckin := r.Channel == ChannelBeaconCheckin
			hasConfirmation := (r.ReporterUserID != nil && *r.ReporterUserID != "") || r.Channel == ChannelRelawan || r.Channel == ChannelAplikasi

			if isCritical && isBeaconCheckin && !hasConfirmation {
				state.NeedsConfirmation = true
				state.UpdatedAt = r.ReceivedAt
			} else {
				state.ReportID = &r.ID
				state.Seq = r.Seq
				state.Status = r.Status
				state.Urgency = r.Urgency
				state.Needs = r.Needs
				state.MemberMask = r.MemberMask
				state.UpdatedAt = r.ReceivedAt
				if r.Status != StatusButuhBantuan || r.Urgency != UrgencyKritis {
					state.NeedsConfirmation = false
				}
			}
		} else if r.Seq == state.Seq && r.ReceivedAt.Before(state.UpdatedAt) {
			state.ReportID = &r.ID
			state.Seq = r.Seq
			state.Status = r.Status
			state.Urgency = r.Urgency
			state.Needs = r.Needs
			state.MemberMask = r.MemberMask
			state.UpdatedAt = r.ReceivedAt
		}
	}

	return state
}

// GetIncidentStats implements incident.ReportSummaryProvider interface.
func (s *Service) GetIncidentStats(ctx context.Context, inc *incident.Incident) (*incident.IncidentSummary, *incident.IncidentMetrics, error) {
	reports, err := s.store.ListReportsByIncident(ctx, inc.ID)
	if err != nil {
		return nil, nil, err
	}
	states, err := s.store.ListHouseholdStates(ctx, inc.ID)
	if err != nil {
		return nil, nil, err
	}

	stateMap := make(map[string]*HouseholdState)
	for _, st := range states {
		stateMap[st.HouseholdID] = st
	}

	var allHouseholds []*HouseholdInfo
	if s.householdProvider != nil {
		allHouseholds, _ = s.householdProvider.GetHouseholdsInScope(ctx, inc.RTID, inc.ScopeBlockIDs)
	}

	totalHouseholds := len(allHouseholds)
	if totalHouseholds == 0 && len(states) > 0 {
		totalHouseholds = len(states)
	}

	reportedCount := len(states)
	amanCount := 0
	titikKumpulCount := 0
	butuhBantuanCount := 0
	kritisCount := 0

	for _, st := range states {
		switch st.Status {
		case StatusAman:
			amanCount++
		case StatusTitikKumpul:
			titikKumpulCount++
		case StatusButuhBantuan:
			butuhBantuanCount++
			if st.Urgency == UrgencyKritis {
				kritisCount++
			}
		}
	}

	belumMelaporCount := totalHouseholds - reportedCount
	if belumMelaporCount < 0 {
		belumMelaporCount = 0
	}

	elapsed := 0
	if inc.StartedAt.Before(time.Now().UTC()) {
		if inc.EndedAt != nil {
			elapsed = int(inc.EndedAt.Sub(inc.StartedAt).Minutes())
		} else {
			elapsed = int(time.Since(inc.StartedAt).Minutes())
		}
	}

	summary := &incident.IncidentSummary{
		Incident:          *inc,
		TotalHouseholds:   totalHouseholds,
		ReportedCount:     reportedCount,
		AmanCount:         amanCount,
		TitikKumpulCount:  titikKumpulCount,
		ButuhBantuanCount: butuhBantuanCount,
		KritisCount:       kritisCount,
		BelumMelaporCount: belumMelaporCount,
		ElapsedMinutes:    elapsed,
	}

	// Calculate SDD 6.5 Metrics
	metrics := s.computeMetricsInternal(inc, allHouseholds, reports, stateMap)

	return summary, metrics, nil
}

func (s *Service) computeMetricsInternal(
	inc *incident.Incident,
	households []*HouseholdInfo,
	reports []*Report,
	states map[string]*HouseholdState,
) *incident.IncidentMetrics {
	byChannel := make(map[string]int)
	offlineCreatedCount := 0
	offlineDeliveredCount := 0

	// Sort reports by received_at to calculate t90 / t100
	sortedReports := make([]*Report, len(reports))
	copy(sortedReports, reports)
	sort.Slice(sortedReports, func(i, j int) bool {
		return sortedReports[i].ReceivedAt.Before(sortedReports[j].ReceivedAt)
	})

	reportedHH := make(map[string]time.Time)
	for _, r := range sortedReports {
		byChannel[r.Channel]++

		isOfflineChannel := r.Channel == ChannelOutbox || r.Channel == ChannelRelawan || r.Channel == ChannelMesh || r.Channel == ChannelBeacon
		if isOfflineChannel {
			offlineCreatedCount++
			offlineDeliveredCount++
		}

		if _, exists := reportedHH[r.HouseholdID]; !exists {
			reportedHH[r.HouseholdID] = r.ReceivedAt
		}
	}

	totalHouseholds := len(households)
	if totalHouseholds == 0 {
		totalHouseholds = len(states)
	}

	t90 := ""
	t100 := ""

	if totalHouseholds > 0 {
		target90 := int(math.Ceil(float64(totalHouseholds) * 0.9))
		target100 := totalHouseholds

		count := 0
		for _, r := range sortedReports {
			count++
			if count >= target90 && t90 == "" {
				diff := r.ReceivedAt.Sub(inc.StartedAt)
				if diff < 0 {
					diff = 0
				}
				t90 = fmt.Sprintf("%.0fm", diff.Minutes())
			}
			if count >= target100 && t100 == "" {
				diff := r.ReceivedAt.Sub(inc.StartedAt)
				if diff < 0 {
					diff = 0
				}
				t100 = fmt.Sprintf("%.0fm", diff.Minutes())
			}
		}
	}

	// vuln_reached_30: percentage of households with vulnerable members reaching safe/assembly point within 30 min
	totalVulnHouseholds := 0
	safeVulnWithin30 := 0
	for _, hh := range households {
		if hh.VulnerableCount > 0 {
			totalVulnHouseholds++
			if st, ok := states[hh.ID]; ok {
				if st.Status == StatusAman || st.Status == StatusTitikKumpul || st.Reached {
					if st.UpdatedAt.Sub(inc.StartedAt) <= 30*time.Minute {
						safeVulnWithin30++
					}
				}
			}
		}
	}

	vulnReached30 := 0.0
	if totalVulnHouseholds > 0 {
		vulnReached30 = (float64(safeVulnWithin30) / float64(totalVulnHouseholds)) * 100.0
	}

	offlineDelivery := 100.0
	if offlineCreatedCount > 0 {
		offlineDelivery = (float64(offlineDeliveredCount) / float64(offlineCreatedCount)) * 100.0
	}

	tRecap := ""
	if inc.EndedAt != nil {
		tRecap = "siap_direkap"
	}

	return &incident.IncidentMetrics{
		T90:             t90,
		T100:            t100,
		VulnReached30:   vulnReached30,
		ByChannel:       byChannel,
		OfflineDelivery: offlineDelivery,
		TRecap:          tRecap,
	}
}

// GetTriageTable returns triage households sorted by priority (SDD 6.1, FR-DSH-07).
func (s *Service) GetTriageTable(ctx context.Context, incidentID, rtID string, statusFilter *ReportStatus, blockFilter *string) ([]*TriageItem, error) {
	var households []*HouseholdInfo
	if s.householdProvider != nil {
		var blockIDs []string
		if blockFilter != nil && *blockFilter != "" {
			blockIDs = []string{*blockFilter}
		}
		hhList, err := s.householdProvider.GetHouseholdsInScope(ctx, rtID, blockIDs)
		if err == nil {
			households = hhList
		}
	}

	states, err := s.store.ListHouseholdStates(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	stateMap := make(map[string]*HouseholdState)
	for _, st := range states {
		stateMap[st.HouseholdID] = st
	}

	var items []*TriageItem
	for _, hh := range households {
		st := stateMap[hh.ID]

		// Apply status filter if requested
		if statusFilter != nil {
			if st == nil || st.Status != *statusFilter {
				continue
			}
		}

		score := 22.0 // default for unreported
		reported := false
		if st != nil {
			score = st.PriorityScore
			reported = true
		} else {
			score, _ = CalculatePriorityScore(nil, hh.VulnerableCount, time.Time{}, nil, nil)
		}

		items = append(items, &TriageItem{
			HouseholdID:     hh.ID,
			Number:          hh.Number,
			Address:         hh.Address,
			BlockID:         hh.BlockID,
			HeadName:        hh.HeadName,
			WAPhone:         hh.WAPhone,
			HasDevice:       hh.HasDevice,
			VulnerableCount: hh.VulnerableCount,
			Lat:             hh.Lat,
			Lon:             hh.Lon,
			State:           st,
			PriorityScore:   score,
			Reported:        reported,
		})
	}

	// Sort by priority descending
	sort.Slice(items, func(i, j int) bool {
		return items[i].PriorityScore > items[j].PriorityScore
	})

	return items, nil
}

// GetUnreportedHouseholds returns households that have not reported yet, sorted by priority.
func (s *Service) GetUnreportedHouseholds(ctx context.Context, incidentID, rtID string) ([]*TriageItem, error) {
	var households []*HouseholdInfo
	if s.householdProvider != nil {
		hhList, err := s.householdProvider.GetHouseholdsInScope(ctx, rtID, nil)
		if err == nil {
			households = hhList
		}
	}

	states, err := s.store.ListHouseholdStates(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	reportedMap := make(map[string]bool)
	for _, st := range states {
		reportedMap[st.HouseholdID] = true
	}

	var unreported []*TriageItem
	for _, hh := range households {
		if reportedMap[hh.ID] {
			continue
		}

		score, _ := CalculatePriorityScore(nil, hh.VulnerableCount, time.Time{}, nil, nil)
		unreported = append(unreported, &TriageItem{
			HouseholdID:     hh.ID,
			Number:          hh.Number,
			Address:         hh.Address,
			BlockID:         hh.BlockID,
			HeadName:        hh.HeadName,
			WAPhone:         hh.WAPhone,
			HasDevice:       hh.HasDevice,
			VulnerableCount: hh.VulnerableCount,
			Lat:             hh.Lat,
			Lon:             hh.Lon,
			State:           nil,
			PriorityScore:   score,
			Reported:        false,
		})
	}

	sort.Slice(unreported, func(i, j int) bool {
		return unreported[i].PriorityScore > unreported[j].PriorityScore
	})

	return unreported, nil
}

// ListReportsByHousehold returns historical reports for a household in an incident.
func (s *Service) ListReportsByHousehold(ctx context.Context, incidentID, householdID string) ([]*Report, error) {
	return s.store.ListReportsByHousehold(ctx, incidentID, householdID)
}
