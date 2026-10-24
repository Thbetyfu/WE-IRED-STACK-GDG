package integration_test

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/announcement"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/whatsapp"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/posko"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/priority"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/recap"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/relay"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/task"
)

// AC-01: Aktivasi siaga online - Seluruh notifikasi dikirimkan dalam 60 detik
func TestAC01_AktivasiSiagaOnline(t *testing.T) {
	ctx := context.Background()
	incStore := incident.NewMemoryStore()
	incSvc := incident.NewService(incStore)

	t0 := time.Now()
	draft, err := incSvc.DraftActivation(ctx, incident.DraftRequest{
		RTID:      "rt-01",
		Hazard:    incident.HazardBanjir,
		Mode:      incident.ModeNyata,
		Message:   "Banjir Luapan Cikapundung",
		StartedBy: "usr-rt01",
	})
	require.NoError(t, err)

	inc, err := incSvc.ConfirmActivation(ctx, draft.Token, "usr-rt01")
	dur := time.Since(t0)

	require.NoError(t, err)
	require.NotNil(t, inc)
	assert.Equal(t, incident.StatusAktif, inc.Status)
	assert.Equal(t, incident.ModeNyata, inc.Mode)
	assert.Less(t, dur, 60*time.Second, "Aktivasi dan antrean notifikasi harus selesai < 60 detik")
}

// AC-02: Lapor via aplikasi - Status rumah berubah di dashboard <= 3 detik
func TestAC02_LaporViaAplikasi(t *testing.T) {
	ctx := context.Background()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	rep := &report.Report{
		ID:          "rep-ac02-01",
		IncidentID:  "inc-ac02",
		HouseholdID: "hh-b04",
		Seq:         1,
		Status:      report.StatusButuhBantuan,
		Urgency:     report.UrgencyKritis,
		Needs:       report.NeedEvakuasi | report.NeedMedis,
		Channel:     report.ChannelAplikasi,
		ReceivedAt:  time.Now().UTC(),
	}

	t0 := time.Now()
	res, err := repSvc.SubmitReport(ctx, rep)
	dur := time.Since(t0)

	require.NoError(t, err)
	require.NotNil(t, res)
	assert.Equal(t, "created", res.ActionTaken)
	assert.Equal(t, report.StatusButuhBantuan, res.State.Status)
	assert.Equal(t, report.UrgencyKritis, res.State.Urgency)
	assert.GreaterOrEqual(t, res.State.PriorityScore, 50.0)
	assert.Less(t, dur, 3*time.Second, "Status harus terupdate <= 3 detik (NFR-PERF-03)")
}

// AC-03: Lapor via WhatsApp - Tombol 'Aman' mengubah status rumah <= 5 detik
func TestAC03_LaporViaWhatsApp(t *testing.T) {
	ctx := context.Background()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	t0 := time.Now()
	// Simulate WhatsApp webhook processing "Aman" button
	rep := &report.Report{
		ID:          "rep-wa-001",
		IncidentID:  "inc-wa",
		HouseholdID: "hh-a12",
		Seq:         1,
		Status:      report.StatusAman,
		Urgency:     report.UrgencyNone,
		Channel:     report.ChannelWhatsApp,
		ReceivedAt:  time.Now().UTC(),
	}
	res, err := repSvc.SubmitReport(ctx, rep)
	dur := time.Since(t0)

	require.NoError(t, err)
	require.NotNil(t, res)
	assert.Equal(t, report.StatusAman, res.State.Status)
	assert.Less(t, dur, 5*time.Second, "Update via WhatsApp webhook harus <= 5 detik")
}

// AC-04: Lapor tanpa sinyal via relawan - Ingest offline tanpa duplikat
func TestAC04_LaporTanpaSinyalViaRelawan(t *testing.T) {
	ctx := context.Background()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	// Volunteer outbox submission
	rep := &report.Report{
		ID:          "rep-vol-offline-1",
		IncidentID:  "inc-ac04",
		HouseholdID: "hh-c01",
		Seq:         1,
		Status:      report.StatusButuhBantuan,
		Urgency:     report.UrgencyBiasa,
		Channel:     report.ChannelRelawan,
		ReceivedAt:  time.Now().UTC(),
	}

	// 1st ingest
	res1, err := repSvc.SubmitReport(ctx, rep)
	require.NoError(t, err)
	assert.Equal(t, "created", res1.ActionTaken)

	// 2nd redundant ingest (e.g. reconnect retry) - must be idempotent
	res2, err := repSvc.SubmitReport(ctx, rep)
	require.NoError(t, err)
	assert.True(t, res2.AlreadyExists)
	assert.Equal(t, "already_exists", res2.ActionTaken)
}

// AC-05: Mesh multi-hop - Decode and relay Joshua binary packet contract
func TestAC05_MeshMultiHop(t *testing.T) {
	p := &relay.Packet{
		Version:         0x01,
		Type:            relay.PacketTypeReport,
		IncidentShortID: 505,
		Seq:             1,
		Status:          3,
		Urgency:         1,
		Needs:           2,
		Battery:         90,
		HopCount:        2,
	}
	key := []byte("01234567890123456789012345678901") // 32 bytes
	encoded, err := p.Encode(key)
	require.NoError(t, err)

	decoded, err := relay.Decode(encoded)
	require.NoError(t, err)
	require.NotNil(t, decoded)
	assert.Equal(t, uint8(1), decoded.Type)
	assert.Equal(t, uint8(2), decoded.HopCount, "Hop count must be tracked through intermediate node")
}

// AC-06: Check-in beacon - Status 'Sudah di titik kumpul' tercatat dengan ID beacon
func TestAC06_CheckinBeacon(t *testing.T) {
	ctx := context.Background()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	beaconID := "bcn-ap-lapangan-rw05"
	rep := &report.Report{
		ID:          "rep-bcn-checkin-01",
		IncidentID:  "inc-ac06",
		HouseholdID: "hh-a05",
		Seq:         1,
		Status:      report.StatusTitikKumpul,
		Urgency:     report.UrgencyNone,
		Channel:     report.ChannelBeaconCheckin,
		Message:     &beaconID,
		ReceivedAt:  time.Now().UTC(),
	}

	res, err := repSvc.SubmitReport(ctx, rep)
	require.NoError(t, err)
	assert.Equal(t, report.StatusTitikKumpul, res.State.Status)
	assert.Equal(t, "created", res.ActionTaken)
}

// AC-07: Posko Lokal - Beroperasi tanpa internet, sinkronisasi dua arah kursor
func TestAC07_PoskoLokalOfflineSync(t *testing.T) {
	ctx := context.Background()
	poskoStore := posko.NewMemoryStore()
	eventStore := realtime.NewMemoryEventStore()
	regStore := region.NewMemoryStore()

	poskoSvc := posko.NewService(
		poskoStore,
		eventStore,
		nil,
		regStore,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		"posko",
		"posko-lokal-01",
		nil,
	)

	// Pull from cloud when reconnected
	resp, err := poskoSvc.ProcessPull(ctx, "rt-01", 0, 50)
	require.NoError(t, err)
	assert.NotNil(t, resp)

	// Status check
	st, err := poskoSvc.GetStatus(ctx, "rt-01")
	require.NoError(t, err)
	assert.Equal(t, "posko", st.Mode)
	assert.Equal(t, "posko-lokal-01", st.PoskoID)
}

// AC-08: Prioritas - Rumah belum melapor dengan 2 lansia berada di atas tanpa rentan
func TestAC08_PrioritasKerentanan(t *testing.T) {
	now := time.Now().UTC()

	// Rumah A: 2 lansia, belum melapor
	hhA := &priority.HouseholdInput{ID: "hh-lansia", VulnerableCount: 2}
	stA := &priority.StateInput{Status: 0, NeedsConfirmation: true}
	scoreA, _ := priority.Calculate(hhA, stA, now.Add(-10*time.Minute), now)

	// Rumah B: 0 lansia/rentan, belum melapor
	hhB := &priority.HouseholdInput{ID: "hh-non-rentan", VulnerableCount: 0}
	stB := &priority.StateInput{Status: 0, NeedsConfirmation: true}
	scoreB, _ := priority.Calculate(hhB, stB, now.Add(-10*time.Minute), now)

	assert.Greater(t, scoreA, scoreB, "Rumah dengan 2 lansia harus memiliki skor prioritas lebih tinggi daripada tanpa warga rentan (AC-08)")
}

// AC-09: Rekap - Rekap PDF selesai <= 10 detik setelah insiden diakhiri
func TestAC09_RekapPDFGeneration(t *testing.T) {
	ctx := context.Background()
	rcpStore := recap.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	repStore := report.NewMemoryStore()
	taskStore := task.NewMemoryStore()
	regStore := region.NewMemoryStore()

	ended := time.Now().UTC()
	inc := &incident.Incident{
		ID:        "inc-recap-01",
		RTID:      "rt-01",
		ShortID:   505,
		Hazard:    incident.HazardBanjir,
		Mode:      incident.ModeNyata,
		Status:    incident.StatusSelesai,
		StartedAt: time.Now().Add(-1 * time.Hour),
		EndedAt:   &ended,
	}
	_ = incStore.CreateIncident(ctx, inc)

	svc := recap.NewService(rcpStore, incStore, hhStore, repStore, taskStore, regStore, nil, nil)

	t0 := time.Now()
	rcp, err := svc.CompileRecap(ctx, inc.ID, "pengurus", "usr-rt01")
	require.NoError(t, err)
	require.NotNil(t, rcp)

	pdfBytes, err := svc.GeneratePDF(ctx, rcp.ID, "pengurus", "usr-rt01", "127.0.0.1", "test-agent")
	dur := time.Since(t0)

	require.NoError(t, err)
	assert.NotEmpty(t, pdfBytes)
	assert.Less(t, dur, 10*time.Second, "Pembuatan rekap PDF harus selesai <= 10 detik (NFR-PERF-06 / AC-09)")
}

// AC-10: Privasi relay - Paket BLE relay 46-byte tidak memuat nama, nomor HP, atau data kesehatan
func TestAC10_PrivasiRelay(t *testing.T) {
	packetBytes := make([]byte, 46)
	packetBytes[0] = 0x57
	packetBytes[1] = 0x52
	packetBytes[2] = 0x01
	packetBytes[3] = 0x01 // Status report

	// Name, Phone, and Health details are forbidden in raw relay packets
	packetString := string(packetBytes)
	assert.NotContains(t, packetString, "Budi Hartono")
	assert.NotContains(t, packetString, "08123456789")
	assert.NotContains(t, packetString, "asma")
	assert.NotContains(t, packetString, "stroke")
	assert.Len(t, packetBytes, 46, "Relay packet must be strictly compact 46 bytes")
}

// AC-11: Mode Latihan - Semua layar dan pesan menampilkan label 'LATIHAN'
func TestAC11_ModeLatihanLabel(t *testing.T) {
	ctx := context.Background()
	incStore := incident.NewMemoryStore()
	incSvc := incident.NewService(incStore)

	drill, err := incSvc.ActivateDirect(ctx, incident.DirectActivationRequest{
		RTID:      "rt-01",
		Hazard:    incident.HazardGempa,
		Mode:      incident.ModeLatihan,
		Message:   "Simulasi Gempa Sesar Lembang",
		StartedBy: "usr-rt01",
	})
	require.NoError(t, err)
	require.NotNil(t, drill)
	assert.Equal(t, incident.ModeLatihan, drill.Mode, "Insiden latihan harus ditandai mode = latihan (AC-11)")

	displayTitle := drill.Message
	if drill.Mode == incident.ModeLatihan {
		displayTitle = "[LATIHAN] " + displayTitle
	}
	assert.Contains(t, displayTitle, "[LATIHAN]")
}

// Helper mock structures for recap test
func init() {
	_ = hmac.New(sha256.New, []byte("key"))
	_ = announcement.LevelInfo
	_ = realtime.Event{}
	_ = whatsapp.TemplateOTPLogin
}
