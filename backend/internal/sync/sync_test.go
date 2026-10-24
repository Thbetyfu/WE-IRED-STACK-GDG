package sync

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

func setupTestSyncEnv(t *testing.T) (*Service, report.Store, household.Store, incident.Store, *realtime.Hub, []byte) {
	dataKey := []byte("master-secret-key-32-bytes-long!")
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)
	hhStore := household.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	volStore := volunteer.NewMemoryStore()
	evStore := realtime.NewMemoryEventStore()
	hub := realtime.NewHub(evStore)

	svc := NewService(repSvc, repStore, hhStore, incStore, volStore, hub, dataKey)
	return svc, repStore, hhStore, incStore, hub, dataKey
}

func TestSyncReportsBatchLimitsAndIsolation(t *testing.T) {
	svc, _, _, _, _, _ := setupTestSyncEnv(t)
	ctx := context.Background()

	// 1. Batch > 50 items must be rejected per SDD 8.1
	largeBatch := make([]*report.Report, 51)
	for i := 0; i < 51; i++ {
		largeBatch[i] = &report.Report{
			ID:          fmt.Sprintf("r-%d", i),
			IncidentID:  "inc-1",
			HouseholdID: "hh-1",
			Seq:         i + 1,
			Status:      report.StatusAman,
			Channel:     report.ChannelOutbox,
		}
	}

	_, err := svc.SyncReports(ctx, largeBatch)
	if err != ErrBatchTooLarge {
		t.Fatalf("expected ErrBatchTooLarge for 51 items, got: %v", err)
	}

	// 2. Batch with 1 invalid and 2 valid items:
	// Failure of item 1 must NOT fail item 2 or item 3, nor falsely report item 1 as accepted
	mixedBatch := []*report.Report{
		{
			ID:          "rep-valid-1",
			IncidentID:  "inc-1",
			HouseholdID: "hh-1",
			Seq:         1,
			Status:      report.StatusAman,
			Channel:     report.ChannelOutbox,
		},
		{
			ID:          "rep-invalid",
			IncidentID:  "inc-1",
			HouseholdID: "", // invalid: missing household ID
			Seq:         2,
			Status:      report.StatusAman,
			Channel:     report.ChannelOutbox,
		},
		{
			ID:          "rep-valid-2",
			IncidentID:  "inc-1",
			HouseholdID: "hh-2",
			Seq:         1,
			Status:      report.StatusTitikKumpul,
			Channel:     report.ChannelOutbox,
		},
	}

	results, err := svc.SyncReports(ctx, mixedBatch)
	if err != nil {
		t.Fatalf("SyncReports failed on mixed batch: %v", err)
	}
	if len(results) != 3 {
		t.Fatalf("expected 3 results, got %d", len(results))
	}

	if results[0].Status != "diterima" {
		t.Fatalf("expected item 0 diterima, got: %s", results[0].Status)
	}
	if results[1].Status != "ditolak" || results[1].Error == "" {
		t.Fatalf("expected item 1 ditolak with error, got: status=%s, err=%s", results[1].Status, results[1].Error)
	}
	if results[2].Status != "diterima" {
		t.Fatalf("expected item 2 diterima, got: %s", results[2].Status)
	}

	// 3. Retry of the same batch must be idempotent (duplikat for valid ones)
	retryResults, err := svc.SyncReports(ctx, mixedBatch)
	if err != nil {
		t.Fatalf("retry failed: %v", err)
	}
	if retryResults[0].Status != "duplikat" {
		t.Fatalf("expected item 0 to be duplikat on retry, got: %s", retryResults[0].Status)
	}
	if retryResults[1].Status != "ditolak" {
		t.Fatalf("expected item 1 to remain ditolak on retry, got: %s", retryResults[1].Status)
	}
	if retryResults[2].Status != "duplikat" {
		t.Fatalf("expected item 2 to be duplikat on retry, got: %s", retryResults[2].Status)
	}
}

func TestSyncRelayPacketsWithJoshuaCodecAndHMAC(t *testing.T) {
	svc, _, hhStore, incStore, _, dataKey := setupTestSyncEnv(t)
	ctx := context.Background()

	rawShortID := []byte{0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
	rawHHKey := []byte{0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f}
	keyEnc, _ := household.EncryptAES256GCM(dataKey, rawHHKey)

	// Register household with this short_id and encrypted key
	hh := &household.Household{
		ID:        "hh-relay-test-1",
		RTID:      "rt-relay-1",
		Number:    "A1",
		HeadName:  "Joshua Test Household",
		ShortID:   rawShortID,
		KeyEnc:    keyEnc,
		CreatedAt: time.Now().UTC(),
	}
	_ = hhStore.CreateHousehold(ctx, hh)

	// Register incident with short_id 1001
	inc := &incident.Incident{
		ID:        "inc-relay-test-1",
		RTID:      "rt-relay-1",
		ShortID:   1001,
		Hazard:    incident.HazardBanjir,
		Mode:      incident.ModeNyata,
		Status:    incident.StatusAktif,
		StartedAt: time.Now().UTC(),
	}
	_ = incStore.CreateIncident(ctx, inc)

	// Load test vector from Joshua's relay_packet.json (case 1)
	expectedHex := "01010102030405060708e9030000010000006096c269030203055501e87396ffb3c02a060600fbd0eab03294f0e20c002200"
	rawPacketBytes, _ := hex.DecodeString(expectedHex)
	base64Packet := base64.StdEncoding.EncodeToString(rawPacketBytes)

	// 1. Submit valid relay packet
	req := RelaySyncRequest{
		CollectorID: "vol-collector-1",
		Packets: []RelayPacketItem{
			{
				Data: base64Packet,
			},
		},
	}

	results, err := svc.SyncRelayPackets(ctx, req)
	if err != nil {
		t.Fatalf("SyncRelayPackets failed: %v", err)
	}
	if len(results) != 1 || results[0].Status != "diterima" {
		t.Fatalf("expected 1 result with status diterima, got: %+v", results)
	}
	if results[0].ReportID == "" {
		t.Fatal("expected non-empty deterministic report ID")
	}

	// 2. Submit tampered relay packet (changed status byte 22 from 3 to 1) -> HMAC verification must fail
	tamperedBytes := make([]byte, len(rawPacketBytes))
	copy(tamperedBytes, rawPacketBytes)
	tamperedBytes[22] = 1
	tamperedBase64 := base64.StdEncoding.EncodeToString(tamperedBytes)

	reqTampered := RelaySyncRequest{
		CollectorID: "vol-collector-1",
		Packets: []RelayPacketItem{
			{
				Data: tamperedBase64,
			},
		},
	}

	resultsTampered, err := svc.SyncRelayPackets(ctx, reqTampered)
	if err != nil {
		t.Fatalf("SyncRelayPackets failed on tampered: %v", err)
	}
	if resultsTampered[0].Status != "ditolak" || resultsTampered[0].Error != "verifikasi HMAC-SHA256 paket gagal" {
		t.Fatalf("expected tampered packet to be ditolak with HMAC error, got: %+v", resultsTampered)
	}
}

func TestSnapshotAndAcksSync(t *testing.T) {
	svc, repStore, hhStore, incStore, _, dataKey := setupTestSyncEnv(t)
	ctx := context.Background()

	rtID := "rt-snap-1"
	rawHHKey := []byte("thirty-two-bytes-secret-key-321!")
	keyEnc, _ := household.EncryptAES256GCM(dataKey, rawHHKey)

	hh := &household.Household{
		ID:        "hh-snap-1",
		RTID:      rtID,
		Number:    "B2",
		HeadName:  "Siti",
		ShortID:   []byte{0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x11},
		KeyEnc:    keyEnc,
		CreatedAt: time.Now().UTC(),
	}
	_ = hhStore.CreateHousehold(ctx, hh)

	// 1. Household Snapshot
	snapHH, err := svc.GetSnapshot(ctx, "household", "user-1", "warga", rtID, hh.ID)
	if err != nil {
		t.Fatalf("GetSnapshot household failed: %v", err)
	}
	if snapHH.Household == nil || snapHH.Household.Household.HeadName != "Siti" {
		t.Fatalf("unexpected household snapshot: %+v", snapHH.Household)
	}

	// 2. Volunteer Snapshot
	snapVol, err := svc.GetSnapshot(ctx, "volunteer", "vol-1", "relawan", rtID, "")
	if err != nil {
		t.Fatalf("GetSnapshot volunteer failed: %v", err)
	}
	if snapVol.Volunteer == nil || len(snapVol.Volunteer.Households) != 1 {
		t.Fatalf("unexpected volunteer snapshot: %+v", snapVol.Volunteer)
	}

	// 3. Acks endpoint test
	inc := &incident.Incident{
		ID:        "inc-acks-1",
		RTID:      rtID,
		ShortID:   5555,
		Hazard:    incident.HazardBanjir,
		Mode:      incident.ModeNyata,
		Status:    incident.StatusAktif,
		StartedAt: time.Now().UTC(),
	}
	_ = incStore.CreateIncident(ctx, inc)

	r := &report.Report{
		ID:          "rep-ack-1",
		IncidentID:  inc.ID,
		HouseholdID: hh.ID,
		Seq:         5,
		Status:      report.StatusAman,
		Channel:     report.ChannelRelawan,
		ReceivedAt:  time.Now().UTC(),
	}
	_, _ = repStore.SaveReport(ctx, r)

	acksResp, err := svc.GetAcks(ctx, inc.ID)
	if err != nil {
		t.Fatalf("GetAcks failed: %v", err)
	}
	if len(acksResp.Acks) != 1 || acksResp.Acks[0].Seq != 5 {
		t.Fatalf("unexpected acks response: %+v", acksResp)
	}
	if acksResp.Acks[0].HouseholdShortID != "aabbccddeeff0011" {
		t.Fatalf("expected short_id aabbccddeeff0011, got: %s", acksResp.Acks[0].HouseholdShortID)
	}
}

func TestSyncHTTPHandlerEndpoints(t *testing.T) {
	jwtSecret := []byte("test-sync-jwt-secret-key-32b-length")
	svc, _, hhStore, _, _, dataKey := setupTestSyncEnv(t)
	h := NewHandler(svc, jwtSecret)

	r := chi.NewRouter()
	h.Routes(r)

	rawHHKey := []byte("key-32-bytes-long-for-testing-01")
	keyEnc, _ := household.EncryptAES256GCM(dataKey, rawHHKey)
	_ = hhStore.CreateHousehold(context.Background(), &household.Household{
		ID:       "hh-http-1",
		RTID:     "rt-http-1",
		Number:   "C3",
		HeadName: "Ahmad",
		ShortID:  []byte{1, 2, 3, 4, 5, 6, 7, 8},
		KeyEnc:   keyEnc,
	})

	token, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:      "user-http-1",
		Role:        "warga",
		RegionID:    "rt-http-1",
		HouseholdID: "hh-http-1",
	})

	// 1. POST /sync/reports HTTP test
	reportsPayload := []map[string]any{
		{
			"id":           "rep-http-1",
			"incident_id":  "inc-http-1",
			"household_id": "hh-http-1",
			"seq":          1,
			"status":       1,
			"channel":      "outbox",
		},
	}
	body, _ := json.Marshal(reportsPayload)
	req := httptest.NewRequest(http.MethodPost, "/sync/reports", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for /sync/reports, got: %d (%s)", rec.Code, rec.Body.String())
	}

	// 2. GET /sync/snapshot HTTP test
	req = httptest.NewRequest(http.MethodGet, "/sync/snapshot?scope=household", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for /sync/snapshot, got: %d (%s)", rec.Code, rec.Body.String())
	}
}
