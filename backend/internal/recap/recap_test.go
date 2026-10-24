package recap_test

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/audit"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/whatsapp"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/recap"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/task"
)

func setupTestEnvironment(t *testing.T) (*recap.Service, *audit.Service, *whatsapp.SimulatedClient, *incident.Incident) {
	ctx := context.Background()

	recapStore := recap.NewMemoryStore()
	auditStore := audit.NewMemoryStore()
	auditSvc := audit.NewService(auditStore)

	hhStore := household.NewMemoryStore()
	regStore := region.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)
	taskStore := task.NewMemoryStore()

	waClient := whatsapp.NewSimulatedClient()
	waStore := whatsapp.NewMemoryStore()
	waSvc := whatsapp.NewService(waClient, waStore, hhStore, incStore, repStore, repSvc, nil, nil)

	service := recap.NewService(recapStore, incStore, hhStore, repStore, taskStore, regStore, auditSvc, waSvc)

	// Setup Region
	kel := &region.Region{ID: "kel-01", Name: "Kelurahan Sukamaju", Type: region.TypeKelurahan}
	_ = regStore.CreateRegion(ctx, kel)
	rw := &region.Region{ID: "rw-01", ParentID: &kel.ID, Name: "RW 03", Type: region.TypeRW}
	_ = regStore.CreateRegion(ctx, rw)
	rt := &region.Region{ID: "rt-01", ParentID: &rw.ID, Name: "RT 05", Type: region.TypeRT}
	_ = regStore.CreateRegion(ctx, rt)

	// Setup Incident
	started := time.Now().Add(-2 * time.Hour)
	ended := time.Now().Add(-10 * time.Minute)
	inc := &incident.Incident{
		ID:        "inc-01",
		RTID:      rt.ID,
		ShortID:   505,
		Hazard:    incident.HazardBanjir,
		Mode:      incident.ModeNyata,
		Status:    incident.StatusSelesai,
		StartedAt: started,
		EndedAt:   &ended,
	}
	_ = incStore.CreateIncident(ctx, inc)

	// Setup 3 Households:
	// HH-1: Aman di rumah (2 anggota, tidak rentan)
	// HH-2: Butuh Bantuan Kritis (Lansia butuh evakuasi)
	// HH-3: Belum Melapor
	hh1 := &household.Household{ID: "hh-1", RTID: rt.ID, Number: "A-01", Address: "Jl. Mawar 1", HeadName: "Ahmad"}
	_ = hhStore.CreateHousehold(ctx, hh1)
	_, _ = repStore.SaveReport(ctx, &report.Report{
		ID:          "rep-1",
		IncidentID:  inc.ID,
		HouseholdID: hh1.ID,
		Status:      report.StatusAman,
		Channel:     "aplikasi",
	})
	_ = repStore.UpsertHouseholdState(ctx, &report.HouseholdState{
		IncidentID:  inc.ID,
		HouseholdID: hh1.ID,
		ReportID:    &hh1.ID,
		Status:      report.StatusAman,
	})

	hh2 := &household.Household{ID: "hh-2", RTID: rt.ID, Number: "A-02", Address: "Jl. Mawar 2", HeadName: "Budi"}
	_ = hhStore.CreateHousehold(ctx, hh2)
	_ = hhStore.AddMember(ctx, &household.Member{
		ID:              "mem-2",
		HouseholdID:     hh2.ID,
		Name:            "Kakek Budi",
		BirthYear:       1945,
		VulnFlags:       household.VulnLansia,
		NeedsEvacAssist: true,
	})
	rep2ID := "rep-2"
	_, _ = repStore.SaveReport(ctx, &report.Report{
		ID:          rep2ID,
		IncidentID:  inc.ID,
		HouseholdID: hh2.ID,
		Status:      report.StatusButuhBantuan,
		Urgency:     report.UrgencyKritis,
		Needs:       report.NeedEvakuasi | report.NeedMedis,
		Channel:     "whatsapp",
	})
	_ = repStore.UpsertHouseholdState(ctx, &report.HouseholdState{
		IncidentID:  inc.ID,
		HouseholdID: hh2.ID,
		ReportID:    &rep2ID,
		Status:      report.StatusButuhBantuan,
		Urgency:     report.UrgencyKritis,
		Needs:       report.NeedEvakuasi | report.NeedMedis,
	})

	hh3 := &household.Household{ID: "hh-3", RTID: rt.ID, Number: "A-03", Address: "Jl. Mawar 3", HeadName: "Citra"}
	_ = hhStore.CreateHousehold(ctx, hh3)

	return service, auditSvc, waClient, inc
}

// TestRecap_AggregationAccuracy verifies FR-RCP-01 calculation traceability.
func TestRecap_AggregationAccuracy(t *testing.T) {
	svc, _, _, inc := setupTestEnvironment(t)
	ctx := context.Background()

	rcp, err := svc.CompileRecap(ctx, inc.ID, "pengurus", "user-pengurus")
	if err != nil {
		t.Fatalf("CompileRecap failed: %v", err)
	}

	d := rcp.Data
	if d == nil {
		t.Fatalf("expected non-nil recap data")
	}

	// 1. Household summary checks
	if d.HouseholdSummary.Total != 3 {
		t.Errorf("expected 3 total households, got %d", d.HouseholdSummary.Total)
	}
	if d.HouseholdSummary.Aman != 1 {
		t.Errorf("expected 1 aman, got %d", d.HouseholdSummary.Aman)
	}
	if d.HouseholdSummary.ButuhBantuan != 1 {
		t.Errorf("expected 1 butuh bantuan, got %d", d.HouseholdSummary.ButuhBantuan)
	}
	if d.HouseholdSummary.BelumMelapor != 1 {
		t.Errorf("expected 1 belum melapor, got %d", d.HouseholdSummary.BelumMelapor)
	}

	// 2. Needs summary checks
	if d.NeedsSummary.Evakuasi != 1 || d.NeedsSummary.Medis != 1 {
		t.Errorf("expected 1 evakuasi and 1 medis, got %v", d.NeedsSummary)
	}

	// 3. Vulnerable checks
	if d.VulnerableSummary.TotalVulnerable != 1 {
		t.Errorf("expected 1 vulnerable member, got %d", d.VulnerableSummary.TotalVulnerable)
	}
	if d.VulnerableSummary.ReachedCount != 1 {
		t.Errorf("expected 1 reached vulnerable member, got %d", d.VulnerableSummary.ReachedCount)
	}

	// 4. Follow-up list
	if len(d.FollowUpHouseholds) != 2 { // hh-2 (butuh bantuan) + hh-3 (belum melapor)
		t.Errorf("expected 2 follow up households, got %d", len(d.FollowUpHouseholds))
	}
	if d.FollowUpHouseholds[0].HouseholdID != "hh-2" || d.FollowUpHouseholds[0].Urgency != "Kritis" {
		t.Errorf("expected critical household hh-2 ranked first in follow-up")
	}
}

// TestRecap_PDF_And_CSV_Consistency verifies that PDF and CSV reflect identical figures
// and PDF generation finishes in <= 10 seconds (FR-RCP-02).
func TestRecap_PDF_And_CSV_Consistency(t *testing.T) {
	svc, _, _, inc := setupTestEnvironment(t)
	ctx := context.Background()

	rcp, err := svc.CompileRecap(ctx, inc.ID, "pengurus", "user-pengurus")
	if err != nil {
		t.Fatalf("CompileRecap failed: %v", err)
	}

	// 1. Measure PDF generation time (Performance Target: <= 10 seconds)
	start := time.Now()
	pdfBytes, err := svc.GeneratePDF(ctx, rcp.ID, "pengurus", "user-pengurus", "127.0.0.1", "test-agent")
	elapsed := time.Since(start)

	if err != nil {
		t.Fatalf("GeneratePDF failed: %v", err)
	}
	if len(pdfBytes) == 0 {
		t.Fatalf("expected non-empty PDF bytes")
	}
	if elapsed > 10*time.Second {
		t.Fatalf("CRITICAL PERFORMANCE VIOLATION: PDF generation took %v (limit: <= 10s)", elapsed)
	}
	t.Logf("Maroto PDF generated in %v (%d bytes)", elapsed, len(pdfBytes))

	// 2. Generate CSV
	csvBytes, err := svc.GenerateCSV(ctx, rcp.ID, "pengurus", "user-pengurus", "127.0.0.1", "test-agent")
	if err != nil {
		t.Fatalf("GenerateCSV failed: %v", err)
	}

	csvStr := string(csvBytes)

	// 3. Verify numbers consistency
	if !strings.Contains(csvStr, "Total Terdaftar,3") {
		t.Errorf("CSV missing Total Terdaftar, 3")
	}
	if !strings.Contains(csvStr, "Aman di Rumah,1") {
		t.Errorf("CSV missing Aman di Rumah, 1")
	}
	if !strings.Contains(csvStr, "Butuh Bantuan,1") {
		t.Errorf("CSV missing Butuh Bantuan, 1")
	}
	if !strings.Contains(csvStr, "Belum Melapor,1") {
		t.Errorf("CSV missing Belum Melapor, 1")
	}
	if !strings.Contains(csvStr, "A-02,Budi,Jl. Mawar 2") {
		t.Errorf("CSV missing follow-up household A-02")
	}
}

// TestRecap_ApprovalAndWhatsAppDispatch verifies FR-RCP-03 and FR-RCP-04:
// Notes, approval, and sending document to WhatsApp (only approved recaps can be sent).
func TestRecap_ApprovalAndWhatsAppDispatch(t *testing.T) {
	svc, auditSvc, waClient, inc := setupTestEnvironment(t)
	ctx := context.Background()

	rcp, _ := svc.CompileRecap(ctx, inc.ID, "pengurus", "user-pengurus")

	// 1. Sending unapproved recap MUST fail
	err := svc.SendWhatsApp(ctx, rcp.ID, "6281234567890", "user-pengurus", "127.0.0.1", "test-agent")
	if err == nil {
		t.Fatalf("expected error sending unapproved recap, got nil")
	}
	if !strings.Contains(err.Error(), "harus disetujui") {
		t.Errorf("unexpected error: %v", err)
	}

	// 2. Update Notes & AI draft
	draft, err := svc.DraftAINarrative(ctx, rcp.ID)
	if err != nil || draft == "" {
		t.Fatalf("DraftAINarrative failed: %v", err)
	}

	notes := "Bantuan logistik dan perahu karet tambahan diperlukan untuk evakuasi lanjutan."
	updated, err := svc.UpdateNotes(ctx, rcp.ID, recap.UpdateRecapInput{Notes: &notes}, "user-pengurus")
	if err != nil || updated.Notes != notes {
		t.Fatalf("UpdateNotes failed: %v", err)
	}
	if !updated.AIAssisted {
		t.Errorf("expected AIAssisted flag to be true")
	}

	// 3. Approve Recap
	approved, err := svc.ApproveRecap(ctx, rcp.ID, "Ketua RT 05", "127.0.0.1", "test-agent")
	if err != nil {
		t.Fatalf("ApproveRecap failed: %v", err)
	}
	if approved.ApprovedBy == nil || *approved.ApprovedBy != "Ketua RT 05" {
		t.Errorf("approval mismatch")
	}

	// 4. Send approved recap via WhatsApp
	err = svc.SendWhatsApp(ctx, rcp.ID, "6281234567890", "Ketua RT 05", "127.0.0.1", "test-agent")
	if err != nil {
		t.Fatalf("SendWhatsApp failed: %v", err)
	}

	lastWAMsg := waClient.LastSentMessage("6281234567890")
	if lastWAMsg == nil {
		t.Fatalf("expected WhatsApp document to be dispatched")
	}
	if lastWAMsg.Type != "template" || lastWAMsg.TemplateReq.Template.Name != whatsapp.TemplateRekapInsiden {
		t.Errorf("expected rekap_insiden template sent via WhatsApp")
	}

	// 5. Verify Audit Logs
	logs, total, err := auditSvc.ListByRegion(ctx, inc.RTID, 10, 0)
	if err != nil || total < 2 {
		t.Fatalf("expected audit logs recorded for approve and whatsapp dispatch, got %d", total)
	}

	hasApproveLog := false
	hasSendLog := false
	for _, l := range logs {
		if l.Action == audit.ActionRecapApprove {
			hasApproveLog = true
		}
		if l.Action == audit.ActionSendWhatsAppRecap {
			hasSendLog = true
		}
	}
	if !hasApproveLog || !hasSendLog {
		t.Errorf("missing audit log entries: approve=%v, send=%v", hasApproveLog, hasSendLog)
	}
}

// TestRecap_AdminWilayah_PrivacyProtection verifies FR-RCP-05:
// Admin Wilayah cannot access individual medical health notes.
func TestRecap_AdminWilayah_PrivacyProtection(t *testing.T) {
	svc, _, _, inc := setupTestEnvironment(t)
	ctx := context.Background()

	rcp, err := svc.CompileRecap(ctx, inc.ID, "admin_wilayah", "user-camat")
	if err != nil {
		t.Fatalf("CompileRecap failed: %v", err)
	}

	// Verify Admin Wilayah view does not include raw health notes
	for _, f := range rcp.Data.FollowUpHouseholds {
		// Only categories (e.g. Evakuasi, Medis) are present, no personal medical notes
		for _, n := range f.Needs {
			if strings.Contains(strings.ToLower(n), "kanker") || strings.Contains(strings.ToLower(n), "stroke") {
				t.Fatalf("CRITICAL PRIVACY VIOLATION: Individual health notes leaked to Admin Wilayah!")
			}
		}
	}
}
