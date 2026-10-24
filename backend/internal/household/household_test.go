package household

import (
	"bytes"
	"context"
	"strings"
	"testing"
)

func TestAgeBasedVulnerabilityCalculation(t *testing.T) {
	currentYear := 2026

	tests := []struct {
		name          string
		birthYear     int
		manualFlags   int
		expectLansia  bool
		expectBalita  bool
		expectFlags   int
	}{
		{
			name:         "Tepat Lansia 60 tahun (1966)",
			birthYear:    1966,
			manualFlags:  0,
			expectLansia: true,
			expectBalita: false,
			expectFlags:  VulnLansia,
		},
		{
			name:         "Bukan Lansia 59 tahun (1967)",
			birthYear:    1967,
			manualFlags:  0,
			expectLansia: false,
			expectBalita: false,
			expectFlags:  0,
		},
		{
			name:         "Tua 80 tahun (1946)",
			birthYear:    1946,
			manualFlags:  0,
			expectLansia: true,
			expectBalita: false,
			expectFlags:  VulnLansia,
		},
		{
			name:         "Tepat Balita 5 tahun (2021)",
			birthYear:    2021,
			manualFlags:  0,
			expectLansia: false,
			expectBalita: true,
			expectFlags:  VulnBalita,
		},
		{
			name:         "Bukan Balita 6 tahun (2020)",
			birthYear:    2020,
			manualFlags:  0,
			expectLansia: false,
			expectBalita: false,
			expectFlags:  0,
		},
		{
			name:         "Bayi baru lahir 0 tahun (2026)",
			birthYear:    2026,
			manualFlags:  0,
			expectLansia: false,
			expectBalita: true,
			expectFlags:  VulnBalita,
		},
		{
			name:         "Kombinasi Balita dan Disabilitas manual",
			birthYear:    2023,
			manualFlags:  VulnDisabilitas,
			expectLansia: false,
			expectBalita: true,
			expectFlags:  VulnBalita | VulnDisabilitas,
		},
		{
			name:         "Kombinasi Lansia dan Penyakit Kronis manual",
			birthYear:    1955,
			manualFlags:  VulnPenyakitKronis,
			expectLansia: true,
			expectBalita: false,
			expectFlags:  VulnLansia | VulnPenyakitKronis,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			res := ComputeAutoVulnFlags(tc.birthYear, currentYear, tc.manualFlags)
			isLansia := (res & VulnLansia) != 0
			isBalita := (res & VulnBalita) != 0

			if isLansia != tc.expectLansia {
				t.Errorf("expected isLansia=%v, got %v for birthYear %d", tc.expectLansia, isLansia, tc.birthYear)
			}
			if isBalita != tc.expectBalita {
				t.Errorf("expected isBalita=%v, got %v for birthYear %d", tc.expectBalita, isBalita, tc.birthYear)
			}
			if res != tc.expectFlags {
				t.Errorf("expected flags=%d, got %d", tc.expectFlags, res)
			}
		})
	}
}

func TestAES256GCMHealthNotesEncryptionAndNonceIntegrity(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}

	notes := "Pasien memiliki riwayat asma akut dan butuh tabung oksigen saat evakuasi."

	// 1. Encrypt & Decrypt
	ciphertext1, err := EncryptAES256GCM(key, []byte(notes))
	if err != nil {
		t.Fatalf("encryption failed: %v", err)
	}

	decrypted, err := DecryptAES256GCM(key, ciphertext1)
	if err != nil {
		t.Fatalf("decryption failed: %v", err)
	}
	if string(decrypted) != notes {
		t.Fatalf("decrypted text mismatch: got %s, expected %s", string(decrypted), notes)
	}

	// 2. Nonce must never be reused across encryptions of the same plaintext
	ciphertext2, err := EncryptAES256GCM(key, []byte(notes))
	if err != nil {
		t.Fatalf("second encryption failed: %v", err)
	}
	if bytes.Equal(ciphertext1, ciphertext2) {
		t.Fatal("security violation: identical ciphertext produced, nonce was reused!")
	}
}

func TestConsentEnforcementAndPurgeOnRevocation(t *testing.T) {
	store := NewMemoryStore()
	dataKey := make([]byte, 32)
	for i := range dataKey {
		dataKey[i] = 0xAA
	}
	svc := NewService(store, dataKey)
	ctx := context.Background()

	// 1. Create Household
	hh, err := svc.CreateHousehold(ctx, &Household{
		RTID:     "rt-01",
		Number:   "A-10",
		Address:  "Jl. Mawar 10",
		HeadName: "Santoso",
		WAPhone:  "+62812345678",
	})
	if err != nil {
		t.Fatalf("create household failed: %v", err)
	}

	// 2. Add member with health notes WITHOUT consent must fail (FR-HH-04)
	_, err = svc.AddMember(ctx, &Member{
		HouseholdID: hh.ID,
		Idx:         0,
		Name:        "Santoso",
		BirthYear:   1960,
		Sex:         "L",
		Relation:    "Kepala Keluarga",
		HealthNotes: "Riwayat serangan jantung",
	})
	if err == nil || err != ErrConsentRequired {
		t.Fatalf("expected ErrConsentRequired when no consent, got %v", err)
	}

	// 3. Record Consent (aplikasi)
	_, err = svc.RecordConsent(ctx, hh.ID, "Santoso", "aplikasi", "v1.0")
	if err != nil {
		t.Fatalf("record consent failed: %v", err)
	}

	// 4. Adding member with health notes now succeeds
	member, err := svc.AddMember(ctx, &Member{
		HouseholdID:     hh.ID,
		Idx:             0,
		Name:            "Santoso",
		BirthYear:       1960,
		Sex:             "L",
		Relation:        "Kepala Keluarga",
		HealthNotes:     "Riwayat serangan jantung",
		NeedsEvacAssist: true,
	})
	if err != nil {
		t.Fatalf("add member failed after consent: %v", err)
	}

	// 5. Authorized retrieval decrypts notes
	retrieved, err := svc.GetHousehold(ctx, hh.ID, "pengurus", nil, nil)
	if err != nil {
		t.Fatalf("get household failed: %v", err)
	}
	if len(retrieved.Members) != 1 || retrieved.Members[0].HealthNotes != "Riwayat serangan jantung" {
		t.Fatalf("expected decrypted health notes, got %+v", retrieved.Members[0])
	}

	// 6. Revoking consent purges sensitive data immediately (FR-HH-05: <= 24h)
	err = svc.RevokeConsent(ctx, hh.ID)
	if err != nil {
		t.Fatalf("revoke consent failed: %v", err)
	}

	// Verification after revocation: notes must be empty, vuln flags reset, needs_evac_assist preserved
	afterRevocation, err := svc.GetHousehold(ctx, hh.ID, "pengurus", nil, nil)
	if err != nil {
		t.Fatalf("get household after revocation failed: %v", err)
	}
	mAfter := afterRevocation.Members[0]
	if mAfter.HealthNotes != "" {
		t.Fatalf("expected health notes purged, got: %s", mAfter.HealthNotes)
	}
	if mAfter.VulnFlags != 0 {
		t.Fatalf("expected vuln flags cleared, got: %d", mAfter.VulnFlags)
	}
	if !mAfter.NeedsEvacAssist {
		t.Fatal("expected needs_evac_assist penanda preserved per FR-HH-05")
	}

	_ = member
}

func TestCSVImportWithPartialErrors(t *testing.T) {
	store := NewMemoryStore()
	dataKey := make([]byte, 32)
	svc := NewService(store, dataKey)
	ctx := context.Background()

	// Seed existing household to test duplicate conflict
	_, _ = svc.CreateHousehold(ctx, &Household{
		RTID:     "rt-01",
		Number:   "A-01",
		Address:  "Jl. Merdeka 1",
		HeadName: "Budi",
		WAPhone:  "+6281111111",
	})

	// CSV containing mixed valid, invalid, and duplicate rows
	csvContent := `nomor_rumah,alamat,nama_kk,telepon_wa,lat,lon
A-02,Jl. Kenanga 2,Ahmad Yani,+6281234567,-6.200,106.800
,Jl. Melati 3,Siti Aminah,+6281234568,-6.201,106.801
A-04,,Joko Widodo,+6281234569,-6.202,106.802
A-01,Jl. Merdeka 1 Duplicate,Budi Duplikat,+6281234570,-6.203,106.803
A-05,Jl. Mawar 5,Rudi Hartono,+6281234571,-6.204,106.804`

	summary, err := svc.ImportCSV(ctx, "rt-01", strings.NewReader(csvContent))
	if err != nil {
		t.Fatalf("import failed: %v", err)
	}

	if summary.TotalRows != 5 {
		t.Fatalf("expected 5 total rows, got %d", summary.TotalRows)
	}
	if summary.Imported != 2 { // A-02 and A-05 should succeed
		t.Fatalf("expected 2 imported rows, got %d", summary.Imported)
	}
	if summary.Failed != 3 { // Missing nomor, missing alamat, and duplicate A-01
		t.Fatalf("expected 3 failed rows, got %d", summary.Failed)
	}

	if len(summary.Errors) != 3 {
		t.Fatalf("expected 3 error items, got %d", len(summary.Errors))
	}

	// Verify error clarity
	for _, e := range summary.Errors {
		if e.Row <= 0 || e.Error == "" {
			t.Fatalf("invalid error structure: %+v", e)
		}
	}
}

func TestInviteCodeAndPseudonymShortID(t *testing.T) {
	store := NewMemoryStore()
	dataKey := make([]byte, 32)
	svc := NewService(store, dataKey)
	ctx := context.Background()

	h, err := svc.CreateHousehold(ctx, &Household{
		RTID:     "rt-01",
		Number:   "B-01",
		Address:  "Jl. Diponegoro 1",
		HeadName: "Gatot",
		WAPhone:  "+62855512345",
	})
	if err != nil {
		t.Fatalf("create household failed: %v", err)
	}

	// 1. Verify 8-byte short_id
	if len(h.ShortID) != 8 {
		t.Fatalf("expected 8-byte short id, got %d bytes", len(h.ShortID))
	}
	if len(h.ShortIDHex) != 16 {
		t.Fatalf("expected 16-character hex representation, got %s", h.ShortIDHex)
	}

	// 2. Verify 8-character invite code
	if h.InviteCode == nil || len(*h.InviteCode) != 8 {
		t.Fatalf("expected 8-char invite code, got %v", h.InviteCode)
	}
	oldCode := *h.InviteCode

	// 3. Regenerate invite code (FR-HH-07, SDD 688)
	newCode, err := svc.RegenerateInviteCode(ctx, h.ID)
	if err != nil {
		t.Fatalf("regenerate failed: %v", err)
	}
	if len(newCode) != 8 || newCode == oldCode {
		t.Fatalf("expected new 8-char invite code, got %s", newCode)
	}

	// 4. Lookup by invite code
	found, err := store.GetHouseholdByInviteCode(ctx, newCode)
	if err != nil || found.ID != h.ID {
		t.Fatalf("failed to find household by new invite code: %v", err)
	}
}

func TestVolunteerBlockScopingOnHouseholdDetails(t *testing.T) {
	store := NewMemoryStore()
	dataKey := make([]byte, 32)
	svc := NewService(store, dataKey)
	ctx := context.Background()

	blockA := "block-A"
	blockB := "block-B"

	hhInBlockA, _ := svc.CreateHousehold(ctx, &Household{
		RTID:     "rt-01",
		BlockID:  &blockA,
		Number:   "A-01",
		Address:  "Blok A No 1",
		HeadName: "Keluarga A",
		WAPhone:  "+628111111",
	})
	_, _ = svc.RecordConsent(ctx, hhInBlockA.ID, "Keluarga A", "aplikasi", "v1.0")
	_, _ = svc.AddMember(ctx, &Member{
		HouseholdID: hhInBlockA.ID,
		Idx:         0,
		Name:        "Warga A",
		BirthYear:   1950, // Lansia
		Sex:         "L",
		Relation:    "Kepala Keluarga",
		HealthNotes: "Catatan Rahasia Medis A",
	})

	// 1. Volunteer assigned to Block A CAN see health notes (FR-VOL-04)
	volunteerAssignedA := []string{blockA}
	resAssigned, err := svc.GetHousehold(ctx, hhInBlockA.ID, "relawan", nil, volunteerAssignedA)
	if err != nil {
		t.Fatalf("get household failed: %v", err)
	}
	if resAssigned.Members[0].HealthNotes != "Catatan Rahasia Medis A" {
		t.Fatalf("expected volunteer assigned to block A to see notes, got '%s'", resAssigned.Members[0].HealthNotes)
	}

	// 2. Volunteer assigned ONLY to Block B CANNOT see health notes (FR-VOL-04 data isolation)
	volunteerAssignedB := []string{blockB}
	resUnassigned, err := svc.GetHousehold(ctx, hhInBlockA.ID, "relawan", nil, volunteerAssignedB)
	if err != nil {
		t.Fatalf("get household failed: %v", err)
	}
	if resUnassigned.Members[0].HealthNotes != "" {
		t.Fatalf("privacy leak: volunteer outside block saw health notes: '%s'", resUnassigned.Members[0].HealthNotes)
	}
	if resUnassigned.Members[0].VulnFlags != 0 {
		t.Fatalf("privacy leak: volunteer outside block saw detailed vuln flags: %d", resUnassigned.Members[0].VulnFlags)
	}
}
