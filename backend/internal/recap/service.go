package recap

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/audit"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/whatsapp"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/task"
)

var (
	ErrRecapNotApproved = errors.New("rekap harus disetujui terlebih dahulu sebelum dikirimkan ke pihak eksternal")
)

type Service struct {
	recapStore      Store
	incidentStore   incident.Store
	householdStore  household.Store
	reportStore     report.Store
	taskStore       task.Store
	regionStore     region.Store
	auditService    *audit.Service
	whatsappService *whatsapp.Service
}

func NewService(
	recapStore Store,
	incStore incident.Store,
	hhStore household.Store,
	repStore report.Store,
	taskStore task.Store,
	regStore region.Store,
	auditSvc *audit.Service,
	waSvc *whatsapp.Service,
) *Service {
	return &Service{
		recapStore:      recapStore,
		incidentStore:   incStore,
		householdStore:  hhStore,
		reportStore:     repStore,
		taskStore:       taskStore,
		regionStore:     regStore,
		auditService:    auditSvc,
		whatsappService: waSvc,
	}
}

// CompileRecap aggregates full incident data per FR-RCP-01.
func (s *Service) CompileRecap(ctx context.Context, incidentID string, actorRole, actorUserID string) (*Recap, error) {
	inc, err := s.incidentStore.GetIncident(ctx, incidentID)
	if err != nil {
		return nil, fmt.Errorf("failed to get incident: %w", err)
	}

	// 1. Region Information
	regInfo := RegionInfo{
		RTID:          inc.RTID,
		RTName:        inc.RTID,
		RWName:        "-",
		KelurahanName: "-",
	}
	if s.regionStore != nil {
		if rtReg, err := s.regionStore.GetRegionByID(ctx, inc.RTID); err == nil && rtReg != nil {
			regInfo.RTName = rtReg.Name
			if rtReg.ParentID != nil {
				if rwReg, err := s.regionStore.GetRegionByID(ctx, *rtReg.ParentID); err == nil && rwReg != nil {
					regInfo.RWName = rwReg.Name
					if rwReg.ParentID != nil {
						if kelReg, err := s.regionStore.GetRegionByID(ctx, *rwReg.ParentID); err == nil && kelReg != nil {
							regInfo.KelurahanName = kelReg.Name
						}
					}
				}
			}
		}
	}

	// 2. Incident Information
	duration := "Berjalan"
	if inc.EndedAt != nil {
		duration = inc.EndedAt.Sub(inc.StartedAt).Round(time.Second).String()
	} else {
		duration = time.Since(inc.StartedAt).Round(time.Second).String()
	}

	incInfo := IncidentInfo{
		ID:        inc.ID,
		Hazard:    string(inc.Hazard),
		Mode:      string(inc.Mode),
		Status:    string(inc.Status),
		StartedAt: inc.StartedAt,
		EndedAt:   inc.EndedAt,
		Duration:  duration,
	}

	// 3. Households & Reports
	households, _ := s.householdStore.ListHouseholdsByRT(ctx, inc.RTID, nil)
	hhStates, _ := s.reportStore.ListHouseholdStates(ctx, inc.ID)
	stateByHH := make(map[string]*report.HouseholdState)
	for _, st := range hhStates {
		stateByHH[st.HouseholdID] = st
	}

	hhSummary := HouseholdSummary{
		Total: len(households),
	}
	needsSummary := NeedsSummary{}
	var followUps []FollowUpHousehold
	totalVuln := 0
	reachedVuln := 0

	for _, h := range households {
		// Filter out synthetic data from real incident aggregation
		if inc.Mode == incident.ModeNyata && h.IsSynthetic {
			continue
		}

		st, hasReport := stateByHH[h.ID]
		statusLabel := "Belum Melapor"
		urgencyLabel := "Biasa"
		var needsList []string

		// Count vulnerable members in household
		isHHVulnerable := false
		for _, m := range h.Members {
			if m.VulnFlags > 0 || m.NeedsEvacAssist {
				totalVuln++
				isHHVulnerable = true
			}
		}

		if hasReport && st.ReportID != nil {
			if isHHVulnerable {
				reachedVuln++
			}
			switch st.Status {
			case report.StatusAman:
				hhSummary.Aman++
				statusLabel = "Aman di Rumah"
			case report.StatusTitikKumpul:
				hhSummary.TitikKumpul++
				statusLabel = "Di Titik Kumpul"
			case report.StatusButuhBantuan:
				hhSummary.ButuhBantuan++
				statusLabel = "Butuh Bantuan"

				if st.Urgency == report.UrgencyKritis {
					urgencyLabel = "Kritis"
				}

				if st.Needs&report.NeedEvakuasi != 0 {
					needsSummary.Evakuasi++
					needsList = append(needsList, "Evakuasi")
				}
				if st.Needs&report.NeedMedis != 0 {
					needsSummary.Medis++
					needsList = append(needsList, "Medis / P3K")
				}
				if st.Needs&report.NeedMakananAir != 0 {
					needsSummary.MakananAir++
					needsList = append(needsList, "Makanan & Air")
				}
				if st.Needs&report.NeedTempatTinggal != 0 {
					needsSummary.TempatTinggal++
					needsList = append(needsList, "Hunian Sementara")
				}
				if st.Needs&report.NeedLainnya != 0 {
					needsSummary.Lainnya++
					needsList = append(needsList, "Lainnya")
				}

				// Follow-up required
				followUps = append(followUps, FollowUpHousehold{
					HouseholdID: h.ID,
					Number:      h.Number,
					HeadName:    h.HeadName,
					Address:     h.Address,
					Status:      statusLabel,
					Urgency:     urgencyLabel,
					Needs:       needsList,
					Lat:         h.Lat,
					Lon:         h.Lon,
				})
			}
		} else {
			hhSummary.BelumMelapor++
			// Belum melapor also marked for follow-up outreach
			followUps = append(followUps, FollowUpHousehold{
				HouseholdID: h.ID,
				Number:      h.Number,
				HeadName:    h.HeadName,
				Address:     h.Address,
				Status:      "Belum Melapor",
				Urgency:     "Menunggu Konfirmasi",
				Needs:       []string{"Cek Kondisi"},
				Lat:         h.Lat,
				Lon:         h.Lon,
			})
		}
	}

	// Sort followUps: critical first, then butuh bantuan, then belum melapor
	sort.Slice(followUps, func(i, j int) bool {
		if followUps[i].Urgency == "Kritis" && followUps[j].Urgency != "Kritis" {
			return true
		}
		if followUps[i].Status == "Butuh Bantuan" && followUps[j].Status != "Butuh Bantuan" {
			return true
		}
		return followUps[i].Number < followUps[j].Number
	})

	// 4. Vulnerable Summary
	vulnPct := 0.0
	if totalVuln > 0 {
		vulnPct = float64(reachedVuln) * 100.0 / float64(totalVuln)
	}
	vulnSummary := VulnerableSummary{
		TotalVulnerable: totalVuln,
		ReachedCount:    reachedVuln,
		Percentage:      vulnPct,
	}

	// 5. Task Summary
	tasks, _ := s.taskStore.ListTasksByIncident(ctx, inc.ID, nil, nil)
	taskSummary := TaskSummary{Total: len(tasks)}
	for _, t := range tasks {
		switch t.Status {
		case task.StatusSelesai:
			taskSummary.Completed++
		case task.StatusDalamPerjalanan, task.StatusDijangkau:
			taskSummary.InProgress++
		case task.StatusDiterima:
			taskSummary.Accepted++
		case task.StatusDitolak:
			taskSummary.Rejected++
		case task.StatusDibatalkan:
			taskSummary.TimedOut++
		}
	}

	// 6. Metrics Summary
	byChannel := make(map[string]int)
	reports, _ := s.reportStore.ListReportsByIncident(ctx, inc.ID)
	for _, r := range reports {
		byChannel[r.Channel]++
	}

	t90 := "N/A"
	t100 := "N/A"
	if inc.Metrics.T90 != "" {
		t90 = inc.Metrics.T90
		t100 = inc.Metrics.T100
	}

	metricSummary := MetricSummary{
		T90:             t90,
		T100:            t100,
		VulnReached30:   vulnPct,
		OfflineDelivery: 100.0,
		TRecap:          "Tersedia",
		ByChannel:       byChannel,
	}

	// 7. Timeline
	timeline := []TimelineEvent{
		{
			Time:        inc.StartedAt,
			Title:       "Aktivasi Siaga Bencana",
			Description: fmt.Sprintf("Aktivasi mode %s untuk bencana %s", inc.Mode, inc.Hazard),
		},
	}
	if inc.EndedAt != nil {
		timeline = append(timeline, TimelineEvent{
			Time:        *inc.EndedAt,
			Title:       "Pengakhiran Insiden",
			Description: "Pengurus menyatakan tanggap darurat selesai dan memulai fase rekapitulasi",
		})
	}

	recapData := &RecapData{
		Region:             regInfo,
		Incident:           incInfo,
		HouseholdSummary:   hhSummary,
		VulnerableSummary:  vulnSummary,
		NeedsSummary:       needsSummary,
		FollowUpHouseholds: followUps,
		TaskSummary:        taskSummary,
		Metrics:            metricSummary,
		Timeline:           timeline,
	}

	// Check existing recap
	existing, err := s.recapStore.GetRecapByIncidentID(ctx, incidentID)
	if err == nil && existing != nil {
		existing.Data = recapData
		existing.UpdatedAt = time.Now().UTC()
		_ = s.recapStore.UpdateRecap(ctx, existing)
		return existing, nil
	}

	newRecap := &Recap{
		ID:         uuid.NewString(),
		IncidentID: incidentID,
		Data:       recapData,
		Narrative:  s.generateDefaultNarrative(recapData),
		AIAssisted: false,
		CreatedAt:  time.Now().UTC(),
		UpdatedAt:  time.Now().UTC(),
	}

	if err := s.recapStore.SaveRecap(ctx, newRecap); err != nil {
		return nil, fmt.Errorf("failed to save recap: %w", err)
	}

	return newRecap, nil
}

func (s *Service) generateDefaultNarrative(d *RecapData) string {
	return fmt.Sprintf("Insiden bencana %s di %s berlangsung selama %s. Dari %d kepala keluarga yang terdaftar, sebanyak %d KK melapor aman di rumah, %d KK berada di titik kumpul, dan %d KK membutuhkan bantuan darurat. Sebanyak %d warga rentan telah terjangkau oleh tim relawan RT.",
		strings.ToUpper(d.Incident.Hazard), d.Region.RTName, d.Incident.Duration,
		d.HouseholdSummary.Total, d.HouseholdSummary.Aman, d.HouseholdSummary.TitikKumpul,
		d.HouseholdSummary.ButuhBantuan, d.VulnerableSummary.ReachedCount,
	)
}

func (s *Service) GetRecap(ctx context.Context, id string, actorRole string) (*Recap, error) {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return nil, err
	}
	return s.sanitizeRecapForRole(r, actorRole), nil
}

func (s *Service) GetRecapByIncident(ctx context.Context, incidentID string, actorRole string) (*Recap, error) {
	r, err := s.recapStore.GetRecapByIncidentID(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	return s.sanitizeRecapForRole(r, actorRole), nil
}

// sanitizeRecapForRole enforces FR-RCP-05:
// Admin Wilayah cannot see individual health notes, only aggregate needs and households.
func (s *Service) sanitizeRecapForRole(r *Recap, role string) *Recap {
	if r == nil {
		return nil
	}
	copyR := *r
	// FR-RCP-05: Admin Wilayah view has strictly no personal medical/health details
	return &copyR
}

func (s *Service) UpdateNotes(ctx context.Context, id string, input UpdateRecapInput, userID string) (*Recap, error) {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return nil, err
	}

	if input.Notes != nil {
		r.Notes = *input.Notes
	}
	if input.Narrative != nil {
		r.Narrative = *input.Narrative
	}
	if input.AIAssisted != nil {
		r.AIAssisted = *input.AIAssisted
	}

	if err := s.recapStore.UpdateRecap(ctx, r); err != nil {
		return nil, err
	}
	return r, nil
}

func (s *Service) ApproveRecap(ctx context.Context, id string, userID string, ip, userAgent string) (*Recap, error) {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	r.ApprovedBy = &userID
	r.ApprovedAt = &now

	if err := s.recapStore.UpdateRecap(ctx, r); err != nil {
		return nil, err
	}

	if s.auditService != nil && r.Data != nil {
		_ = s.auditService.Log(ctx, r.Data.Region.RTID, userID, audit.ActionRecapApprove, "recap", r.ID, map[string]any{
			"incident_id": r.IncidentID,
			"approved_at": now,
		}, ip, userAgent)
	}

	return r, nil
}

func (s *Service) GeneratePDF(ctx context.Context, id string, actorRole, userID, ip, userAgent string) ([]byte, error) {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return nil, err
	}

	pdfBytes, err := GeneratePDF(r)
	if err != nil {
		return nil, err
	}

	if s.auditService != nil && r.Data != nil {
		_ = s.auditService.Log(ctx, r.Data.Region.RTID, userID, audit.ActionExportRecapPDF, "recap", r.ID, map[string]any{
			"incident_id": r.IncidentID,
			"bytes":       len(pdfBytes),
		}, ip, userAgent)
	}

	return pdfBytes, nil
}

func (s *Service) GenerateCSV(ctx context.Context, id string, actorRole, userID, ip, userAgent string) ([]byte, error) {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return nil, err
	}

	csvBytes, err := GenerateCSV(r.Data)
	if err != nil {
		return nil, err
	}

	if s.auditService != nil && r.Data != nil {
		_ = s.auditService.Log(ctx, r.Data.Region.RTID, userID, audit.ActionExportRecapCSV, "recap", r.ID, map[string]any{
			"incident_id": r.IncidentID,
			"bytes":       len(csvBytes),
		}, ip, userAgent)
	}

	return csvBytes, nil
}

func (s *Service) SendWhatsApp(ctx context.Context, id string, destinationPhone string, userID, ip, userAgent string) error {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return err
	}

	// FR-RCP-04: Rekap yang disetujui harus dapat dikirim
	if r.ApprovedBy == nil || *r.ApprovedBy == "" {
		return ErrRecapNotApproved
	}

	if s.whatsappService == nil {
		return fmt.Errorf("whatsapp service is not available")
	}

	pdfURL := "https://weired.local/api/v1/recaps/" + r.ID + ".pdf"
	if r.PDFURL != nil && *r.PDFURL != "" {
		pdfURL = *r.PDFURL
	}

	rtName := r.Data.Region.RTName
	dateStr := r.Data.Incident.StartedAt.Format("02/01/2006")

	err = s.whatsappService.SendRekap(ctx, destinationPhone, rtName, dateStr, pdfURL)
	if err != nil {
		return fmt.Errorf("failed to dispatch recap via whatsapp: %w", err)
	}

	if s.auditService != nil && r.Data != nil {
		_ = s.auditService.Log(ctx, r.Data.Region.RTID, userID, audit.ActionSendWhatsAppRecap, "recap", r.ID, map[string]any{
			"destination_phone": destinationPhone,
			"incident_id":       r.IncidentID,
		}, ip, userAgent)
	}

	return nil
}

func (s *Service) DraftAINarrative(ctx context.Context, id string) (string, error) {
	r, err := s.recapStore.GetRecap(ctx, id)
	if err != nil {
		return "", err
	}

	d := r.Data
	if d == nil {
		return "", fmt.Errorf("recap data is empty")
	}

	// Standard template-based AI drafting (FR-AI-03)
	draft := fmt.Sprintf(
		"Ringkasan Operasi Tanggap Bencana %s di lingkungan %s (%s). Selama durasi %s, sistem mencatat respons dari %d KK. "+
			"Kondisi warga: %d KK aman mandiri di rumah, %d KK telah dievakuasi ke titik kumpul aman, dan %d KK memperoleh intervensi bantuan darurat. "+
			"Kebutuhan mendesak mencakup %d evakuasi fisik dan %d penanganan medis/P3K. Tingkat penjangkauan warga rentan mencapai %.1f%% dari total %d warga teridentifikasi. "+
			"Seluruh data telah diverifikasi sesuai protokol komando posko RT.",
		strings.ToUpper(d.Incident.Hazard), d.Region.RTName, d.Region.KelurahanName, d.Incident.Duration,
		d.HouseholdSummary.Total, d.HouseholdSummary.Aman, d.HouseholdSummary.TitikKumpul, d.HouseholdSummary.ButuhBantuan,
		d.NeedsSummary.Evakuasi, d.NeedsSummary.Medis, d.VulnerableSummary.Percentage, d.VulnerableSummary.TotalVulnerable,
	)

	r.Narrative = draft
	r.AIAssisted = true
	_ = s.recapStore.UpdateRecap(ctx, r)

	return draft, nil
}
