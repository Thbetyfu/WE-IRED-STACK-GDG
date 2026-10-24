package whatsapp

import (
	"context"
	"fmt"
	"log/slog"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/jobs"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

type Service struct {
	client         Client
	store          Store
	householdStore household.Store
	incidentStore  incident.Store
	reportStore    report.Store
	reportService  *report.Service
	jobQueue       jobs.Queue
	logger         *slog.Logger
}

func NewService(
	client Client,
	store Store,
	hhStore household.Store,
	incStore incident.Store,
	repStore report.Store,
	repSvc *report.Service,
	jobQueue jobs.Queue,
	logger *slog.Logger,
) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{
		client:         client,
		store:          store,
		householdStore: hhStore,
		incidentStore:  incStore,
		reportStore:    repStore,
		reportService:  repSvc,
		jobQueue:       jobQueue,
		logger:         logger,
	}
}

// SendOTP sends verification code for authentication (Category: Authentication).
// Implements auth.WhatsAppOTPProvider interface.
func (s *Service) SendOTP(ctx context.Context, phone string, code string, expiresInSeconds int) error {
	req := BuildOTPLoginPayload(phone, code)

	notif := &Notification{
		ID:        uuid.NewString(),
		Channel:   "whatsapp",
		Recipient: phone,
		Template:  TemplateOTPLogin,
		Payload: map[string]any{
			"code":               code,
			"expires_in_seconds": expiresInSeconds,
		},
		Status:    StatusAntri,
		CreatedAt: time.Now().UTC(),
	}
	_ = s.store.SaveNotification(ctx, notif)

	providerID, err := s.client.SendTemplate(ctx, phone, req)
	if err != nil {
		errStr := err.Error()
		_ = s.store.UpdateNotificationStatus(ctx, notif.ID, StatusGagal, &errStr)
		s.logger.Error("failed to dispatch whatsapp otp", "recipient", phone, "error", err)
		return err
	}

	notif.ProviderID = &providerID
	_ = s.store.SaveNotification(ctx, notif) // update providerID mapping
	_ = s.store.UpdateNotificationStatus(ctx, providerID, StatusTerkirim, nil)

	s.logger.Info("whatsapp otp dispatched successfully", "recipient", phone, "provider_id", providerID)
	return nil
}

// SendSiagaAktivasi broadcasts activation template to all registered households in RT (FR-WA-01, FR-WA-02).
func (s *Service) SendSiagaAktivasi(ctx context.Context, incidentID string) error {
	inc, err := s.incidentStore.GetIncident(ctx, incidentID)
	if err != nil {
		return fmt.Errorf("failed to get incident: %w", err)
	}

	households, err := s.householdStore.ListHouseholdsByRT(ctx, inc.RTID, nil)
	if err != nil {
		return fmt.Errorf("failed to list households for rt: %w", err)
	}

	shortIDStr := fmt.Sprintf("%d", inc.ShortID)
	if inc.ShortID == 0 {
		shortIDStr = inc.ID[:8]
	}

	for _, hh := range households {
		if strings.TrimSpace(hh.WAPhone) == "" {
			continue
		}

		req := BuildSiagaAktivasiPayload(hh.WAPhone, string(inc.Mode), string(inc.Hazard), inc.RTID, shortIDStr)

		notif := &Notification{
			ID:        uuid.NewString(),
			Channel:   "whatsapp",
			Recipient: hh.WAPhone,
			Template:  TemplateSiagaAktivasi,
			Payload: map[string]any{
				"incident_id": incidentID,
				"mode":        inc.Mode,
				"hazard":      inc.Hazard,
			},
			Status:    StatusAntri,
			CreatedAt: time.Now().UTC(),
		}
		_ = s.store.SaveNotification(ctx, notif)

		providerID, err := s.client.SendTemplate(ctx, hh.WAPhone, req)
		if err != nil {
			errStr := err.Error()
			_ = s.store.UpdateNotificationStatus(ctx, notif.ID, StatusGagal, &errStr)
			s.logger.Warn("failed to send siaga_aktivasi whatsapp message", "household_id", hh.ID, "phone", hh.WAPhone, "error", err)
			continue
		}

		notif.ProviderID = &providerID
		_ = s.store.SaveNotification(ctx, notif)
		_ = s.store.UpdateNotificationStatus(ctx, providerID, StatusTerkirim, nil)
	}

	return nil
}

// ScheduleReminders enqueues T+10 and T+25 reminder background jobs (FR-WA-05).
func (s *Service) ScheduleReminders(ctx context.Context, incidentID string, minutes []int) error {
	if s.jobQueue == nil {
		return nil
	}

	for _, min := range minutes {
		step := fmt.Sprintf("t%d", min)
		payload := map[string]any{
			"incident_id": incidentID,
			"step":        step,
			"minutes":     min,
		}

		runAt := time.Now().Add(time.Duration(min) * time.Minute)
		_, err := s.jobQueue.Enqueue(ctx, "wa_reminder", payload, runAt)
		if err != nil {
			s.logger.Error("failed to enqueue wa_reminder job", "incident_id", incidentID, "step", step, "error", err)
		} else {
			s.logger.Info("scheduled wa_reminder job", "incident_id", incidentID, "step", step, "run_at", runAt)
		}
	}

	return nil
}

// ProcessReminderJob executes the T+10 / T+25 reminder check and dispatches messages (FR-WA-05).
// Invariant: Does not duplicate reminders on worker restart or retry!
func (s *Service) ProcessReminderJob(ctx context.Context, incidentID string, step string, minutes int) error {
	inc, err := s.incidentStore.GetIncident(ctx, incidentID)
	if err != nil {
		return fmt.Errorf("failed to get incident: %w", err)
	}

	// If incident already concluded, do not nag citizens
	if inc.EndedAt != nil {
		s.logger.Info("skipping reminder for ended incident", "incident_id", incidentID)
		return nil
	}

	households, err := s.householdStore.ListHouseholdsByRT(ctx, inc.RTID, nil)
	if err != nil {
		return err
	}

	shortIDStr := fmt.Sprintf("%d", inc.ShortID)
	if inc.ShortID == 0 {
		shortIDStr = inc.ID[:8]
	}

	for _, hh := range households {
		if strings.TrimSpace(hh.WAPhone) == "" {
			continue
		}

		// 1. Check if household already reported
		st, err := s.reportStore.GetHouseholdState(ctx, incidentID, hh.ID)
		if err == nil && st != nil && st.ReportID != nil {
			// Already reported, skip reminder!
			continue
		}

		// 2. Check if reminder for this step already sent to this household (prevents worker restart duplicates)
		alreadySent, _ := s.store.HasSentReminder(ctx, incidentID, hh.ID, step)
		if alreadySent {
			continue
		}

		// 3. Record reminder sent FIRST to guarantee idempotency across worker crashes
		_ = s.store.RecordReminderSent(ctx, incidentID, hh.ID, step)

		// 4. Send reminder template
		req := BuildSiagaPengingatPayload(hh.WAPhone, inc.RTID, minutes, shortIDStr)

		notif := &Notification{
			ID:        uuid.NewString(),
			Channel:   "whatsapp",
			Recipient: hh.WAPhone,
			Template:  TemplateSiagaPengingat,
			Payload: map[string]any{
				"incident_id": incidentID,
				"step":        step,
				"minutes":     minutes,
			},
			Status:    StatusAntri,
			CreatedAt: time.Now().UTC(),
		}
		_ = s.store.SaveNotification(ctx, notif)

		providerID, err := s.client.SendTemplate(ctx, hh.WAPhone, req)
		if err != nil {
			errStr := err.Error()
			_ = s.store.UpdateNotificationStatus(ctx, notif.ID, StatusGagal, &errStr)
			s.logger.Warn("failed to send siaga_pengingat message", "household_id", hh.ID, "error", err)
			continue
		}

		notif.ProviderID = &providerID
		_ = s.store.SaveNotification(ctx, notif)
		_ = s.store.UpdateNotificationStatus(ctx, providerID, StatusTerkirim, nil)
	}

	return nil
}

// SendPengumuman sends public announcement via WhatsApp (FR-ANN-02).
func (s *Service) SendPengumuman(ctx context.Context, phone, level, text string) error {
	req := BuildPengumumanRTPayload(phone, level, text)

	notif := &Notification{
		ID:        uuid.NewString(),
		Channel:   "whatsapp",
		Recipient: phone,
		Template:  TemplatePengumumanRT,
		Payload: map[string]any{
			"level": level,
			"text":  text,
		},
		Status:    StatusAntri,
		CreatedAt: time.Now().UTC(),
	}
	_ = s.store.SaveNotification(ctx, notif)

	providerID, err := s.client.SendTemplate(ctx, phone, req)
	if err != nil {
		errStr := err.Error()
		_ = s.store.UpdateNotificationStatus(ctx, notif.ID, StatusGagal, &errStr)
		return err
	}

	notif.ProviderID = &providerID
	_ = s.store.SaveNotification(ctx, notif)
	_ = s.store.UpdateNotificationStatus(ctx, providerID, StatusTerkirim, nil)
	return nil
}

// SendRekap sends the incident closing PDF document (Siklus 11).
func (s *Service) SendRekap(ctx context.Context, phone, rtName, formattedDate, pdfURL string) error {
	req := BuildRekapInsidenPayload(phone, rtName, formattedDate, pdfURL)

	notif := &Notification{
		ID:        uuid.NewString(),
		Channel:   "whatsapp",
		Recipient: phone,
		Template:  TemplateRekapInsiden,
		Payload: map[string]any{
			"rt_name":        rtName,
			"formatted_date": formattedDate,
			"pdf_url":        pdfURL,
		},
		Status:    StatusAntri,
		CreatedAt: time.Now().UTC(),
	}
	_ = s.store.SaveNotification(ctx, notif)

	providerID, err := s.client.SendTemplate(ctx, phone, req)
	if err != nil {
		errStr := err.Error()
		_ = s.store.UpdateNotificationStatus(ctx, notif.ID, StatusGagal, &errStr)
		return err
	}

	notif.ProviderID = &providerID
	_ = s.store.SaveNotification(ctx, notif)
	_ = s.store.UpdateNotificationStatus(ctx, providerID, StatusTerkirim, nil)
	return nil
}

// HandleIncomingMessage processes user replies from webhook (FR-WA-03, FR-WA-04, FR-WA-06).
func (s *Service) HandleIncomingMessage(ctx context.Context, fromPhone string, messageID string, text string, buttonPayload string) error {
	// 1. Idempotency Check: deduplicate by messageID
	processed, _ := s.store.IsMessageProcessed(ctx, messageID)
	if processed {
		s.logger.Info("ignoring duplicate whatsapp message", "message_id", messageID)
		return nil
	}
	_ = s.store.MarkMessageProcessed(ctx, messageID)

	// 2. Identify household by registered phone number (FR-WA-06)
	hh, err := s.householdStore.GetHouseholdByPhone(ctx, fromPhone)
	if err != nil || hh == nil {
		// FR-WA-06: Nomor tak terdaftar dibalas panduan menghubungi pengurus tanpa membuka info pribadi
		guideMsg := "Halo, nomor WhatsApp Anda belum terdaftar dalam sistem tanggap bencana WE-IRED di lingkungan RT ini. Silakan hubungi pengurus RT Anda untuk mendaftarkan nomor dan data keluarga. Terima kasih."
		_, _ = s.client.SendText(ctx, fromPhone, guideMsg)
		s.logger.Info("replied with guide to unregistered whatsapp phone", "phone", fromPhone)
		return nil
	}

	// 3. Check for active multi-step conversation session (Butuh Bantuan flow)
	sess, err := s.store.GetSession(ctx, fromPhone)
	if err == nil && sess != nil {
		return s.handleSessionStep(ctx, hh, sess, text, buttonPayload)
	}

	// 4. Handle initial button response: RPT|{incident_short_id}|{status}
	if strings.HasPrefix(buttonPayload, "RPT|") {
		return s.handleInitialReportButton(ctx, hh, fromPhone, buttonPayload)
	}

	// Fallback text without session: Inform user how to report
	helpMsg := "Untuk melaporkan status rumah tangga Anda saat siaga bencana, silakan gunakan tombol pada pesan aktivasi siaga yang telah dikirimkan oleh pengurus RT."
	_, _ = s.client.SendText(ctx, fromPhone, helpMsg)
	return nil
}

func (s *Service) handleInitialReportButton(ctx context.Context, hh *household.Household, phone, payload string) error {
	parts := strings.Split(payload, "|")
	if len(parts) < 3 {
		return fmt.Errorf("invalid button payload format: %s", payload)
	}

	shortIDStr := parts[1]
	statusInt, err := strconv.Atoi(parts[2])
	if err != nil {
		return fmt.Errorf("invalid status in button payload: %w", err)
	}

	// Lookup active incident for household RT
	inc, err := s.incidentStore.GetActiveIncidentByRT(ctx, hh.RTID, nil)
	if err != nil || inc == nil {
		// Fallback lookup by short ID
		var shortID uint32
		if sid64, parseErr := strconv.ParseUint(shortIDStr, 10, 32); parseErr == nil {
			shortID = uint32(sid64)
		}
		inc, err = s.incidentStore.GetIncidentByShortID(ctx, shortID)
		if err != nil || inc == nil {
			_, _ = s.client.SendText(ctx, phone, "Tidak ada insiden siaga aktif di RT Anda saat ini.")
			return nil
		}
	}

	status := report.ReportStatus(statusInt)
	repID := uuid.NewString()

	rep := &report.Report{
		ID:          repID,
		IncidentID:  inc.ID,
		HouseholdID: hh.ID,
		Channel:     report.ChannelWhatsApp,
		Status:      status,
		Urgency:     report.UrgencyNone,
		ReceivedAt:  time.Now().UTC(),
		DeviceTime:  time.Now().UTC(),
	}

	res, err := s.reportService.SubmitReport(ctx, rep)
	if err != nil {
		s.logger.Error("failed to submit whatsapp report", "household_id", hh.ID, "error", err)
		return err
	}

	switch status {
	case report.StatusAman:
		_, _ = s.client.SendText(ctx, phone, "Terima kasih, laporan kondisi rumah Anda telah tercatat: Aman di rumah. Tetap waspada dan ikuti panduan pengurus.")
		return nil

	case report.StatusTitikKumpul:
		_, _ = s.client.SendText(ctx, phone, "Terima kasih, laporan kondisi rumah Anda telah tercatat: Sudah di titik kumpul. Tetap tertib bersama warga lainnya.")
		return nil

	case report.StatusButuhBantuan:
		// Start multi-step interactive flow (SDD 10.1): Daftar Kebutuhan -> Urgensi -> Pesan
		sess := &WASession{
			Phone:       phone,
			IncidentID:  inc.ID,
			HouseholdID: hh.ID,
			ReportID:    res.Report.ID,
			Step:        StepAwaitingNeeds,
			Context:     make(map[string]any),
		}
		_ = s.store.SaveSession(ctx, sess)

		prompt := "Kondisi BUTUH BANTUAN telah diterima. Silakan pilih jenis kebutuhan utama (balas dengan angka 1-5):\n" +
			"1. Evakuasi\n" +
			"2. Medis / P3K\n" +
			"3. Makanan & Air\n" +
			"4. Tempat Tinggal Sementara\n" +
			"5. Lainnya"
		_, _ = s.client.SendText(ctx, phone, prompt)
		return nil
	}

	return nil
}

func (s *Service) handleSessionStep(ctx context.Context, hh *household.Household, sess *WASession, text, buttonPayload string) error {
	trimmed := strings.TrimSpace(text)
	if trimmed == "" && buttonPayload != "" {
		trimmed = buttonPayload
	}

	switch sess.Step {
	case StepAwaitingNeeds:
		// Validate choices 1 to 5
		var needsMask int
		switch trimmed {
		case "1", "evakuasi", "Evakuasi":
			needsMask = report.NeedEvakuasi
		case "2", "medis", "Medis", "p3k", "P3K":
			needsMask = report.NeedMedis
		case "3", "makanan", "Makanan", "air", "Air":
			needsMask = report.NeedMakananAir
		case "4", "tempat tinggal", "hunian":
			needsMask = report.NeedTempatTinggal
		case "5", "lainnya", "Lainnya":
			needsMask = report.NeedLainnya
		default:
			// Invalid input: reject and keep context
			errPrompt := "Pilihan tidak valid. Silakan balas hanya dengan angka 1 sampai 5:\n" +
				"1. Evakuasi\n2. Medis / P3K\n3. Makanan & Air\n4. Tempat Tinggal Sementara\n5. Lainnya"
			_, _ = s.client.SendText(ctx, sess.Phone, errPrompt)
			return nil
		}

		sess.Context["needs"] = needsMask
		sess.Step = StepAwaitingUrgency
		_ = s.store.SaveSession(ctx, sess)

		urgencyPrompt := "Tingkat urgensi kebutuhan bantuan Anda:\n" +
			"1. Biasa (bisa menunggu antrean)\n" +
			"2. Kritis (mengancam keselamatan / lansia / balita darurat)\n\n" +
			"Balas dengan angka 1 (Biasa) atau 2 (Kritis):"
		_, _ = s.client.SendText(ctx, sess.Phone, urgencyPrompt)
		return nil

	case StepAwaitingUrgency:
		var urgency report.ReportUrgency
		switch trimmed {
		case "1", "biasa", "Biasa":
			urgency = report.UrgencyBiasa
		case "2", "kritis", "Kritis":
			urgency = report.UrgencyKritis
		default:
			errPrompt := "Pilihan tingkat urgensi tidak valid. Balas dengan angka 1 (Biasa) atau 2 (Kritis):"
			_, _ = s.client.SendText(ctx, sess.Phone, errPrompt)
			return nil
		}

		sess.Context["urgency"] = int(urgency)

		// Update report with needs and urgency (triggers priority calculation)
		needsVal, _ := sess.Context["needs"].(int)
		if needsVal == 0 {
			if f, ok := sess.Context["needs"].(float64); ok {
				needsVal = int(f)
			}
		}

		rep := &report.Report{
			ID:          uuid.NewString(),
			IncidentID:  sess.IncidentID,
			HouseholdID: sess.HouseholdID,
			Channel:     report.ChannelWhatsApp,
			Status:      report.StatusButuhBantuan,
			Urgency:     urgency,
			Needs:       needsVal,
			ReceivedAt:  time.Now().UTC(),
			DeviceTime:  time.Now().UTC(),
		}
		_, err := s.reportService.SubmitReport(ctx, rep)
		if err != nil {
			s.logger.Error("failed to update report with needs/urgency", "error", err)
		}

		sess.Step = StepAwaitingMessage
		_ = s.store.SaveSession(ctx, sess)

		msgPrompt := "Terima kasih, data kebutuhan dan urgensi telah diperbarui. Tim relawan posko sedang bergerak.\n" +
			"Silakan ketik pesan/keterangan tambahan jika ada (contoh patokan rumah atau jumlah anggota keluarga), atau ketik 'selesai':"
		_, _ = s.client.SendText(ctx, sess.Phone, msgPrompt)
		return nil

	case StepAwaitingMessage:
		if strings.ToLower(trimmed) != "selesai" && trimmed != "" {
			// Update report with additional message
			msgCopy := trimmed
			rep := &report.Report{
				ID:          uuid.NewString(),
				IncidentID:  sess.IncidentID,
				HouseholdID: sess.HouseholdID,
				Channel:     report.ChannelWhatsApp,
				Status:      report.StatusButuhBantuan,
				Message:     &msgCopy,
				ReceivedAt:  time.Now().UTC(),
				DeviceTime:  time.Now().UTC(),
			}
			_, _ = s.reportService.SubmitReport(ctx, rep)
		}

		// Complete and clean up session
		_ = s.store.DeleteSession(ctx, sess.Phone)

		closingMsg := "Laporan lengkap telah tercatat di Posko Tanggap Bencana. Tetap tenang dan amankan diri di lokasi."
		_, _ = s.client.SendText(ctx, sess.Phone, closingMsg)
		return nil
	}

	return nil
}

// HandleStatusUpdate updates notification record when Meta delivers message statuses (FR-WA-07).
func (s *Service) HandleStatusUpdate(ctx context.Context, providerID string, status string, errorDetails *string) error {
	var notifStatus NotificationStatus
	switch status {
	case "sent":
		notifStatus = StatusTerkirim
	case "delivered":
		notifStatus = StatusDiterima
	case "read":
		notifStatus = StatusDibaca
	case "failed":
		notifStatus = StatusGagal
	default:
		return nil
	}

	return s.store.UpdateNotificationStatus(ctx, providerID, notifStatus, errorDetails)
}

// GetNotification retrieves a tracked notification.
func (s *Service) GetNotification(ctx context.Context, id string) (*Notification, error) {
	return s.store.GetNotification(ctx, id)
}

// ListNotificationsByRecipient lists delivery history for a phone number.
func (s *Service) ListNotificationsByRecipient(ctx context.Context, phone string, limit int) ([]*Notification, error) {
	return s.store.ListNotificationsByRecipient(ctx, phone, limit)
}
