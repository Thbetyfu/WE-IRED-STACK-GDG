package announcement

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/fcm"
)

type dummyHierarchyChecker struct{}

func (d *dummyHierarchyChecker) IsRTInRegion(ctx context.Context, regionID, rtID string) (bool, error) {
	return true, nil
}

func TestEd25519CodecSigningAndVerification(t *testing.T) {
	pubKey, privKey, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatalf("failed to generate ed25519 key: %v", err)
	}

	now := time.Now().UTC().Truncate(time.Second)
	expiresAt := now.Add(2 * time.Hour)

	pkt := &Packet{
		Version:    ProtocolVersion,
		Type:       TypeAnnouncement, // 0x10
		RTShortID:  44001,
		AnnShortID: 101,
		Level:      LevelDarurat, // 0x03
		CreatedAt:  now,
		ExpiresAt:  expiresAt,
		Text:       "Waspada air meningkat di bantaran sungai. Segera menuju titik kumpul Balai RW!",
	}

	rawBytes, err := Encode(pkt, privKey)
	if err != nil {
		t.Fatalf("failed to encode and sign: %v", err)
	}

	// Minimum length: 20 header + text len + 64 sig
	expectedLen := HeaderLength + len([]byte(pkt.Text)) + SignatureLength
	if len(rawBytes) != expectedLen {
		t.Fatalf("expected packet length %d, got %d", expectedLen, len(rawBytes))
	}

	// Verify with correct public key
	decoded, err := DecodeAndVerify(rawBytes, pubKey)
	if err != nil {
		t.Fatalf("failed to decode and verify valid packet: %v", err)
	}

	if decoded.Version != ProtocolVersion || decoded.Type != TypeAnnouncement {
		t.Fatalf("unexpected version or type: v=%d, type=0x%02x", decoded.Version, decoded.Type)
	}
	if decoded.RTShortID != 44001 || decoded.AnnShortID != 101 {
		t.Fatalf("unexpected short IDs: rt=%d, ann=%d", decoded.RTShortID, decoded.AnnShortID)
	}
	if decoded.Level != LevelDarurat {
		t.Fatalf("expected level darurat (3), got %d", decoded.Level)
	}
	if decoded.Text != pkt.Text {
		t.Fatalf("text mismatch: got %q, expected %q", decoded.Text, pkt.Text)
	}
	if decoded.CreatedAt.Unix() != now.Unix() || decoded.ExpiresAt.Unix() != expiresAt.Unix() {
		t.Fatalf("timestamp mismatch: created=%d, expires=%d", decoded.CreatedAt.Unix(), decoded.ExpiresAt.Unix())
	}
	if len(decoded.Signature) != 64 {
		t.Fatalf("expected 64-byte signature, got %d bytes", len(decoded.Signature))
	}
}

func TestTamperedPayloadOrSignatureRejection(t *testing.T) {
	pubKey, privKey, _ := ed25519.GenerateKey(nil)

	now := time.Now().UTC()
	pkt := &Packet{
		Version:    ProtocolVersion,
		Type:       TypeAnnouncement,
		RTShortID:  1,
		AnnShortID: 2,
		Level:      LevelInfo,
		CreatedAt:  now,
		ExpiresAt:  now.Add(1 * time.Hour),
		Text:       "Pengumuman asli tidak berubah.",
	}

	rawBytes, err := Encode(pkt, privKey)
	if err != nil {
		t.Fatalf("encode error: %v", err)
	}

	// 1. Tamper payload text
	tamperedPayload := make([]byte, len(rawBytes))
	copy(tamperedPayload, rawBytes)
	tamperedPayload[25] ^= 0xFF // alter a character in text

	_, err = DecodeAndVerify(tamperedPayload, pubKey)
	if !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature for tampered payload, got: %v", err)
	}

	// 2. Tamper signature byte
	tamperedSig := make([]byte, len(rawBytes))
	copy(tamperedSig, rawBytes)
	tamperedSig[len(tamperedSig)-1] ^= 0xFF // alter last byte of Ed25519 signature

	_, err = DecodeAndVerify(tamperedSig, pubKey)
	if !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature for tampered signature, got: %v", err)
	}

	// 3. Verify with wrong public key
	wrongPubKey, _, _ := ed25519.GenerateKey(nil)
	_, err = DecodeAndVerify(rawBytes, wrongPubKey)
	if !errors.Is(err, ErrInvalidSignature) {
		t.Fatalf("expected ErrInvalidSignature for wrong public key, got: %v", err)
	}

	// 4. Tamper version
	tamperedVer := make([]byte, len(rawBytes))
	copy(tamperedVer, rawBytes)
	tamperedVer[0] = 0x02
	_, err = DecodeAndVerify(tamperedVer, pubKey)
	if !errors.Is(err, ErrUnsupportedVersion) {
		t.Fatalf("expected ErrUnsupportedVersion, got: %v", err)
	}
}

func TestIncidentEvent0x11Packet(t *testing.T) {
	km, err := NewKeyManager("")
	if err != nil {
		t.Fatalf("failed to init key manager: %v", err)
	}

	// 1. Alert for Real Incident Activation
	rawBytes, pkt, err := CreateIncidentAlertPacket(
		"inc-001",
		55001,
		44001,
		"BANJIR",
		false, // real incident
		false, // started
		km,
	)
	if err != nil {
		t.Fatalf("failed to create incident alert packet: %v", err)
	}

	if pkt.Type != TypeIncidentAlert {
		t.Fatalf("expected TypeIncidentAlert (0x11), got: 0x%02x", pkt.Type)
	}
	if pkt.Level != LevelDarurat {
		t.Fatalf("expected LevelDarurat, got %d", pkt.Level)
	}

	// Verify using Cloud Root Public Key
	decoded, err := DecodeAndVerify(rawBytes, km.RootPublicKey())
	if err != nil {
		t.Fatalf("failed to verify 0x11 incident alert packet: %v", err)
	}

	if decoded.Type != TypeIncidentAlert {
		t.Fatalf("decoded type mismatch: 0x%02x", decoded.Type)
	}
	if !strings.Contains(decoded.Text, "SIAGA BANJIR") || !strings.Contains(decoded.Text, "NYATA") {
		t.Fatalf("unexpected alert text: %q", decoded.Text)
	}

	// 2. Alert for Incident Ended
	rawEnded, pktEnded, err := CreateIncidentAlertPacket(
		"inc-001",
		55001,
		44001,
		"BANJIR",
		false,
		true, // ended
		km,
	)
	if err != nil {
		t.Fatalf("failed to create ended alert: %v", err)
	}
	if pktEnded.Level != LevelInfo {
		t.Fatalf("expected LevelInfo on ended alert, got %d", pktEnded.Level)
	}

	decodedEnded, err := DecodeAndVerify(rawEnded, km.RootPublicKey())
	if err != nil {
		t.Fatalf("failed to verify ended alert packet: %v", err)
	}
	if !strings.Contains(decodedEnded.Text, "SELESAI") {
		t.Fatalf("unexpected ended text: %q", decodedEnded.Text)
	}
}

func TestPoskoDelegationAndOfflineKeyManagement(t *testing.T) {
	km, err := NewKeyManager("")
	if err != nil {
		t.Fatalf("failed to create key manager: %v", err)
	}

	poskoID := "posko-rw05-01"
	rtID := "rt-001"

	// 1. Generate delegation
	del, poskoPrivKey, err := km.GeneratePoskoDelegation(poskoID, rtID, 48*time.Hour)
	if err != nil {
		t.Fatalf("failed to generate posko delegation: %v", err)
	}

	// 2. Verify delegation certificate with Cloud root key
	if err := km.VerifyDelegation(del, time.Now()); err != nil {
		t.Fatalf("delegation certificate verification failed: %v", err)
	}

	// 3. Expired delegation must be rejected
	expiredTime := time.Now().Add(50 * time.Hour)
	if err := km.VerifyDelegation(del, expiredTime); !errors.Is(err, ErrInvalidDelegation) {
		t.Fatalf("expected ErrInvalidDelegation on expired cert, got: %v", err)
	}

	// 4. Posko signs announcement offline using its delegated private key
	now := time.Now().UTC()
	pkt := &Packet{
		Version:    ProtocolVersion,
		Type:       TypeAnnouncement,
		RTShortID:  44001,
		AnnShortID: 999,
		Level:      LevelPenting,
		CreatedAt:  now,
		ExpiresAt:  now.Add(6 * time.Hour),
		Text:       "Pengumuman darurat dari Posko Lokal (Offline).",
	}

	poskoRawBytes, err := Encode(pkt, poskoPrivKey)
	if err != nil {
		t.Fatalf("posko failed to encode/sign announcement: %v", err)
	}

	// Verifier validates packet against Posko's certified public key
	decodedPosko, err := DecodeAndVerify(poskoRawBytes, del.PoskoPublicKey)
	if err != nil {
		t.Fatalf("failed to verify posko signed packet with posko pubkey: %v", err)
	}
	if decodedPosko.Text != pkt.Text {
		t.Fatalf("posko text mismatch: %q", decodedPosko.Text)
	}
}

func TestAnnouncementCRUDAndExpirationFilter(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	km, _ := NewKeyManager("")
	simFCM := fcm.NewSimulatedClient()
	fcmSvc := fcm.NewService(simFCM, nil)
	svc := NewService(store, km, fcmSvc, nil, nil)

	rtID := "rt-001"
	now := time.Now().UTC()

	// 1. Create active normal announcement (expires in 2h)
	res1, err := svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{rtID},
		Level:     LevelNameInfo,
		Text:      "Kerja bakti saluran air RT 01",
		ExpiresAt: now.Add(2 * time.Hour),
		Channels:  []string{"push", "relay"},
		CreatedBy: "user-pengurus-1",
	})
	if err != nil {
		t.Fatalf("failed to create announcement 1: %v", err)
	}
	if res1.Announcement.ShortID == 0 || res1.Announcement.Signature == "" {
		t.Fatal("expected non-zero short_id and signature")
	}

	// 2. Create active emergency announcement (darurat, expires in 4h)
	res2, err := svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{rtID},
		Level:     LevelNameDarurat,
		Text:      "DARURAT: Pintu air meluap, segera evakuasi!",
		ExpiresAt: now.Add(4 * time.Hour),
		Channels:  []string{"push", "whatsapp", "relay"},
		CreatedBy: "user-pengurus-1",
	})
	if err != nil {
		t.Fatalf("failed to create announcement 2: %v", err)
	}
	if res2.Announcement.ID == "" {
		t.Fatal("expected non-empty announcement ID for res2")
	}

	// 3. Create expired announcement (manually inserted into store to test rule)
	expiredAnn := &Announcement{
		ID:        "ann-expired",
		RegionIDs: []string{rtID},
		ShortID:   888,
		Level:     LevelNameInfo,
		Text:      "Pengumuman lama tahun lalu",
		ExpiresAt: now.Add(-1 * time.Hour), // Expired 1h ago!
		CreatedAt: now.Add(-24 * time.Hour),
	}
	_ = store.CreateAnnouncement(ctx, expiredAnn)

	// Rule Check: Pengumuman yang kedaluwarsa tidak dikirim atau ditampilkan melampaui aturan yang berlaku
	activeList, err := svc.ListAnnouncements(ctx, rtID, false)
	if err != nil {
		t.Fatalf("failed to list active announcements: %v", err)
	}

	if len(activeList) != 2 {
		t.Fatalf("expected exactly 2 active announcements, got %d", len(activeList))
	}

	for _, a := range activeList {
		if a.ID == "ann-expired" {
			t.Fatal("RULE VIOLATION: expired announcement was returned in active list")
		}
	}

	// FR-ANN-03 Check: pengumuman darurat di urutan pertama
	if activeList[0].Level != LevelNameDarurat {
		t.Fatalf("FR-ANN-03 violation: expected emergency announcement first, got %s", activeList[0].Level)
	}

	// Check latest binary packet
	packetBytes, err := svc.GetLatestSignedPacket(ctx, rtID)
	if err != nil {
		t.Fatalf("failed to get latest packet: %v", err)
	}
	if len(packetBytes) < MinPacketLength {
		t.Fatalf("latest packet too short: %d", len(packetBytes))
	}
}

func TestMax160CharactersValidation(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	km, _ := NewKeyManager("")
	svc := NewService(store, km, nil, nil, nil)

	rtID := "rt-001"
	now := time.Now().UTC()

	// 1. Empty text -> ErrEmptyText
	_, err := svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{rtID},
		Level:     LevelNameInfo,
		Text:      "   ",
		ExpiresAt: now.Add(1 * time.Hour),
		Channels:  []string{"push"},
	})
	if !errors.Is(err, ErrEmptyText) {
		t.Fatalf("expected ErrEmptyText, got: %v", err)
	}

	// 2. Exactly 160 characters -> SUCCESS
	exact160 := strings.Repeat("A", 160)
	res, err := svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{rtID},
		Level:     LevelNameInfo,
		Text:      exact160,
		ExpiresAt: now.Add(1 * time.Hour),
		Channels:  []string{"push"},
		CreatedBy: "user-1",
	})
	if err != nil {
		t.Fatalf("160 characters should succeed, got: %v", err)
	}
	if res.Announcement.Text != exact160 {
		t.Fatal("text mismatch on 160 chars")
	}

	// 3. 161 characters -> ErrTextTooLong
	exceed161 := strings.Repeat("A", 161)
	_, err = svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{rtID},
		Level:     LevelNameInfo,
		Text:      exceed161,
		ExpiresAt: now.Add(1 * time.Hour),
		Channels:  []string{"push"},
		CreatedBy: "user-1",
	})
	if !errors.Is(err, ErrTextTooLong) {
		t.Fatalf("expected ErrTextTooLong for 161 chars, got: %v", err)
	}

	// 4. Expiration in the past -> ErrExpirationInPast
	_, err = svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{rtID},
		Level:     LevelNameInfo,
		Text:      "Test expired input",
		ExpiresAt: now.Add(-5 * time.Minute),
		Channels:  []string{"push"},
	})
	if !errors.Is(err, ErrExpirationInPast) {
		t.Fatalf("expected ErrExpirationInPast, got: %v", err)
	}
}

func TestDistributionFailureTracking(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryStore()
	km, _ := NewKeyManager("")

	simFCM := fcm.NewSimulatedClient()
	simFCM.SimulateErr = errors.New("FCM quota exceeded or network timeout")
	fcmSvc := fcm.NewService(simFCM, nil)

	svc := NewService(store, km, fcmSvc, nil, nil)

	// Create announcement with push channel
	res, err := svc.CreateAnnouncement(ctx, CreateAnnouncementRequest{
		RegionIDs: []string{"rt-001"},
		Level:     LevelNameDarurat,
		Text:      "Evakuasi segera ke titik kumpul!",
		ExpiresAt: time.Now().Add(2 * time.Hour),
		Channels:  []string{"push", "relay"},
		CreatedBy: "user-pengurus",
	})
	if err != nil {
		t.Fatalf("unexpected creation failure: %v", err)
	}

	// Rule Check: Pengiriman tidak dilaporkan berhasil hanya karena payload berhasil dibuat
	pushRes := res.Dispatches["push"]
	if pushRes.Success {
		t.Fatal("RULE VIOLATION: FCM push was reported as success despite simulated provider error")
	}
	if !strings.Contains(pushRes.Error, "FCM quota exceeded") {
		t.Fatalf("expected diagnostic error recorded, got: %q", pushRes.Error)
	}

	// Relay channel should still succeed independently
	relayRes := res.Dispatches["relay"]
	if !relayRes.Success {
		t.Fatalf("expected relay channel to succeed independently, got: %+v", relayRes)
	}
}

func TestAnnouncementHTTPHandler(t *testing.T) {
	store := NewMemoryStore()
	km, _ := NewKeyManager("")
	simFCM := fcm.NewSimulatedClient()
	fcmSvc := fcm.NewService(simFCM, nil)
	svc := NewService(store, km, fcmSvc, nil, nil)

	jwtSecret := []byte("secret-key-min-32-chars-long-for-test-ok")
	handler := NewHandler(svc, jwtSecret, &dummyHierarchyChecker{})

	r := chi.NewRouter()
	handler.Routes(r)

	rtID := "rt-001"
	token, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "user-pengurus-1",
		Role:     "pengurus",
		RegionID: rtID,
	})

	// 1. GET /api/v1/announcements/public-key
	req := httptest.NewRequest(http.MethodGet, "/api/v1/announcements/public-key", nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for public key, got %d: %s", rec.Code, rec.Body.String())
	}

	// 2. POST /rts/{rt}/announcements
	payload := map[string]any{
		"level":      "darurat",
		"text":       "Pemberitahuan banjir bandang level siaga 1",
		"expires_at": time.Now().Add(3 * time.Hour).Format(time.RFC3339),
		"channels":   []string{"push", "relay"},
	}
	body, _ := json.Marshal(payload)
	req = httptest.NewRequest(http.MethodPost, "/rts/"+rtID+"/announcements", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for announcement creation, got %d: %s", rec.Code, rec.Body.String())
	}

	var createResp struct {
		Data CreateAnnouncementResult `json:"data"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &createResp)
	annID := createResp.Data.Announcement.ID
	if annID == "" || createResp.Data.Announcement.Signature == "" {
		t.Fatal("expected announcement ID and Ed25519 signature")
	}

	// 3. GET /rts/{rt}/announcements
	req = httptest.NewRequest(http.MethodGet, "/rts/"+rtID+"/announcements", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for list announcements, got %d", rec.Code)
	}

	// 4. GET /rts/{rt}/announcements/latest-packet -> returns octet-stream
	req = httptest.NewRequest(http.MethodGet, "/rts/"+rtID+"/announcements/latest-packet", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for latest packet, got %d: %s", rec.Code, rec.Body.String())
	}
	if rec.Header().Get("Content-Type") != "application/octet-stream" {
		t.Fatalf("expected application/octet-stream, got: %s", rec.Header().Get("Content-Type"))
	}
	if len(rec.Body.Bytes()) < MinPacketLength {
		t.Fatalf("binary packet too short: %d", len(rec.Body.Bytes()))
	}

	// 5. POST /posko/delegation
	delPayload := map[string]any{
		"posko_id":      "posko-01",
		"rt_id":         rtID,
		"duration_days": 5,
	}
	delBody, _ := json.Marshal(delPayload)
	req = httptest.NewRequest(http.MethodPost, "/posko/delegation", bytes.NewReader(delBody))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201 for posko delegation, got %d: %s", rec.Code, rec.Body.String())
	}
}

// GenerateAnnouncementTestVector generates and verifies the test vector JSON for Joshua's test suite.
func TestGenerateAnnouncementTestVector(t *testing.T) {
	// Deterministic 32-byte seed
	seedHex := "0101010101010101010101010101010101010101010101010101010101010101"
	seedBytes, _ := hex.DecodeString(seedHex)
	privKey := ed25519.NewKeyFromSeed(seedBytes)
	pubKey := privKey.Public().(ed25519.PublicKey)

	createdTime := time.Date(2026, 10, 24, 10, 0, 0, 0, time.UTC)
	expiresTime := time.Date(2026, 10, 24, 14, 0, 0, 0, time.UTC)

	pkt := &Packet{
		Version:    ProtocolVersion,
		Type:       TypeAnnouncement,
		RTShortID:  44001,
		AnnShortID: 101,
		Level:      LevelDarurat,
		CreatedAt:  createdTime,
		ExpiresAt:  expiresTime,
		Text:       "Air sungai meluap 1.5m. Segera evakuasi ke Balai RW 05!",
	}

	rawBytes, err := Encode(pkt, privKey)
	if err != nil {
		t.Fatalf("failed to encode test vector: %v", err)
	}

	// Verify
	decoded, err := DecodeAndVerify(rawBytes, pubKey)
	if err != nil {
		t.Fatalf("test vector verification failed: %v", err)
	}
	if decoded.Text != pkt.Text {
		t.Fatal("text mismatch")
	}

	t.Logf("Joshua Test Vector: Packet Hex (%d bytes): %s", len(rawBytes), hex.EncodeToString(rawBytes))
	t.Logf("PublicKey Hex: %s", hex.EncodeToString(pubKey))
	t.Logf("Signature Hex: %s", hex.EncodeToString(pkt.Signature))
}
