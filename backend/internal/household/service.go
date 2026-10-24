package household

import (
	"context"
	"crypto/rand"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	ErrUnauthorizedAccess = errors.New("akses ditolak: tidak memiliki hak membaca atau memodifikasi data ini")
	ErrInvalidInput       = errors.New("data masukan tidak valid")
)

type Service struct {
	store   Store
	dataKey []byte // 32-byte AES key for encrypting health notes and initial household keys
}

func NewService(store Store, dataKey []byte) *Service {
	return &Service{
		store:   store,
		dataKey: dataKey,
	}
}

// CreateHousehold registers a new household in an RT (FR-HH-01, FR-HH-07, FR-HH-08).
func (s *Service) CreateHousehold(ctx context.Context, h *Household) (*Household, error) {
	h.Number = strings.TrimSpace(h.Number)
	h.Address = strings.TrimSpace(h.Address)
	h.HeadName = strings.TrimSpace(h.HeadName)
	h.WAPhone = strings.TrimSpace(h.WAPhone)

	if h.Number == "" || h.Address == "" || h.HeadName == "" {
		return nil, fmt.Errorf("%w: nomor rumah, alamat, dan nama kepala keluarga wajib diisi", ErrInvalidInput)
	}

	if h.ID == "" {
		h.ID = uuid.NewString()
	}

	// Generate 8-byte random short_id (SDD 5.2)
	shortID, err := GenerateShortID8()
	if err != nil {
		return nil, fmt.Errorf("failed to generate short id: %w", err)
	}
	h.SetShortID(shortID)

	// Generate 8-character single-use invite code (FR-HH-07)
	inviteCode, err := GenerateInviteCode8()
	if err != nil {
		return nil, fmt.Errorf("failed to generate invite code: %w", err)
	}
	h.InviteCode = &inviteCode

	// Generate initial random 32-byte household key and encrypt with dataKey (key_enc)
	rawHHKey := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, rawHHKey); err != nil {
		return nil, fmt.Errorf("failed to generate household key: %w", err)
	}
	keyEnc, err := EncryptAES256GCM(s.dataKey, rawHHKey)
	if err != nil {
		return nil, fmt.Errorf("failed to encrypt household key: %w", err)
	}
	h.KeyEnc = keyEnc

	// FR-HH-08: Rumah tanpa HP/WhatsApp ditandai has_device = false ("perlu dijangkau relawan")
	if h.WAPhone == "" {
		h.HasDevice = false
	} else {
		h.HasDevice = true
	}

	h.CreatedAt = time.Now().UTC()

	if err := s.store.CreateHousehold(ctx, h); err != nil {
		return nil, err
	}

	return h, nil
}

// GetHousehold retrieves household details and conditionally decrypts member health notes (FR-HH-01, FR-HH-04).
func (s *Service) GetHousehold(ctx context.Context, id, actorRole string, actorHouseholdID *string, volunteerBlockIDs []string) (*Household, error) {
	h, err := s.store.GetHousehold(ctx, id)
	if err != nil {
		return nil, err
	}

	// Privacy & Access Control Check
	canViewSensitive := s.canViewSensitiveDetails(actorRole, actorHouseholdID, h, volunteerBlockIDs)

	// Decrypt health notes for authorized actors if consent is active
	if canViewSensitive && h.HasConsent {
		for _, m := range h.Members {
			if len(m.HealthNotesEnc) > 0 {
				plain, err := DecryptAES256GCM(s.dataKey, m.HealthNotesEnc)
				if err == nil {
					m.HealthNotes = string(plain)
				}
			}
		}
	} else {
		// Strip sensitive data for unauthorized viewers or if consent revoked
		for _, m := range h.Members {
			m.HealthNotes = ""
			m.HealthNotesEnc = nil
			if !canViewSensitive {
				// Hide detailed vulnerability flags if not in assigned block/scope
				m.VulnFlags = 0
			}
		}
	}

	return h, nil
}

func (s *Service) canViewSensitiveDetails(actorRole string, actorHouseholdID *string, h *Household, volunteerBlockIDs []string) bool {
	if actorRole == "operator" || actorRole == "admin_wilayah" || actorRole == "pengurus" {
		return true
	}

	if actorRole == "kepala_keluarga" {
		return actorHouseholdID != nil && *actorHouseholdID == h.ID
	}

	if actorRole == "relawan" {
		// FR-VOL-04: Relawan hanya dapat melihat detail kerentanan rumah di blok yang ditugaskan kepadanya
		if h.BlockID != nil {
			for _, bid := range volunteerBlockIDs {
				if bid == *h.BlockID {
					return true
				}
			}
		}
		return false
	}

	return false
}

// UpdateHousehold updates demographic details.
func (s *Service) UpdateHousehold(ctx context.Context, h *Household) error {
	if h.WAPhone == "" {
		h.HasDevice = false
	}
	return s.store.UpdateHousehold(ctx, h)
}

// DeleteHousehold removes a household record.
func (s *Service) DeleteHousehold(ctx context.Context, id string) error {
	return s.store.DeleteHousehold(ctx, id)
}

// ListHouseholds lists all households in an RT.
func (s *Service) ListHouseholds(ctx context.Context, rtID string, blockID *string) ([]*Household, error) {
	return s.store.ListHouseholdsByRT(ctx, rtID, blockID)
}

// GetHouseholdByPhone finds household by WhatsApp phone number.
func (s *Service) GetHouseholdByPhone(ctx context.Context, phone string) (*Household, error) {
	return s.store.GetHouseholdByPhone(ctx, phone)
}

// RegenerateInviteCode creates and saves a new 8-char invite code for household (FR-HH-07, SDD 688).
func (s *Service) RegenerateInviteCode(ctx context.Context, id string) (string, error) {
	code, err := GenerateInviteCode8()
	if err != nil {
		return "", err
	}

	if err := s.store.UpdateInviteCode(ctx, id, &code); err != nil {
		return "", err
	}

	return code, nil
}

// AddMember adds a family member with automated vulnerability categorization and consent check (FR-HH-02, FR-HH-03, FR-HH-04).
func (s *Service) AddMember(ctx context.Context, m *Member) (*Member, error) {
	m.Name = strings.TrimSpace(m.Name)
	m.Relation = strings.TrimSpace(m.Relation)
	m.Sex = strings.ToUpper(strings.TrimSpace(m.Sex))

	if m.Name == "" || m.BirthYear <= 0 || m.Relation == "" {
		return nil, fmt.Errorf("%w: nama, tahun lahir, dan hubungan keluarga wajib diisi", ErrInvalidInput)
	}

	if m.ID == "" {
		m.ID = uuid.NewString()
	}

	// FR-HH-03: Otomatis tandai lansia / balita dari tahun lahir
	m.VulnFlags = ComputeAutoVulnFlags(m.BirthYear, time.Now().Year(), m.VulnFlags)

	// FR-HH-04: Catatan kesehatan hanya boleh disimpan setelah persetujuan dicatat
	if m.HealthNotes != "" {
		consent, err := s.store.GetActiveConsent(ctx, m.HouseholdID)
		if err != nil || consent == nil {
			return nil, ErrConsentRequired
		}

		encryptedNotes, err := EncryptAES256GCM(s.dataKey, []byte(m.HealthNotes))
		if err != nil {
			return nil, fmt.Errorf("failed to encrypt health notes: %w", err)
		}
		m.HealthNotesEnc = encryptedNotes
	}

	m.CreatedAt = time.Now().UTC()

	if err := s.store.AddMember(ctx, m); err != nil {
		return nil, err
	}

	return m, nil
}

// UpdateMember updates member data with automated vulnerability categorization and consent check.
func (s *Service) UpdateMember(ctx context.Context, m *Member) error {
	m.VulnFlags = ComputeAutoVulnFlags(m.BirthYear, time.Now().Year(), m.VulnFlags)

	if m.HealthNotes != "" {
		consent, err := s.store.GetActiveConsent(ctx, m.HouseholdID)
		if err != nil || consent == nil {
			return ErrConsentRequired
		}

		encryptedNotes, err := EncryptAES256GCM(s.dataKey, []byte(m.HealthNotes))
		if err != nil {
			return fmt.Errorf("failed to encrypt health notes: %w", err)
		}
		m.HealthNotesEnc = encryptedNotes
	}

	return s.store.UpdateMember(ctx, m)
}

// DeleteMember removes a member from a household.
func (s *Service) DeleteMember(ctx context.Context, householdID, memberID string) error {
	return s.store.DeleteMember(ctx, householdID, memberID)
}

// ListMembers lists all members for a household.
func (s *Service) ListMembers(ctx context.Context, householdID string) ([]*Member, error) {
	return s.store.ListMembers(ctx, householdID)
}

// RecordConsent records citizen data processing consent (FR-HH-04).
func (s *Service) RecordConsent(ctx context.Context, householdID, givenBy, method, textVersion string) (*Consent, error) {
	givenBy = strings.TrimSpace(givenBy)
	method = strings.TrimSpace(method)
	textVersion = strings.TrimSpace(textVersion)

	if givenBy == "" || method == "" || textVersion == "" {
		return nil, fmt.Errorf("%w: given_by, method, dan text_version wajib diisi", ErrInvalidInput)
	}

	c := &Consent{
		ID:          uuid.NewString(),
		HouseholdID: householdID,
		GivenBy:     givenBy,
		Method:      method,
		TextVersion: textVersion,
		GivenAt:     time.Now().UTC(),
	}

	if err := s.store.RecordConsent(ctx, c); err != nil {
		return nil, err
	}

	return c, nil
}

// RevokeConsent revokes consent and purges sensitive health details per FR-HH-05 (within ≤ 24h).
func (s *Service) RevokeConsent(ctx context.Context, householdID string) error {
	if err := s.store.RevokeConsent(ctx, householdID); err != nil {
		return err
	}

	// Purge sensitive data immediately (compliant with the <= 24h deadline)
	return s.store.PurgeSensitiveHealthData(ctx, householdID)
}

// ImportCSV parses and imports households from a CSV stream with per-row validation (FR-HH-06).
func (s *Service) ImportCSV(ctx context.Context, rtID string, r io.Reader) (*CSVImportSummary, error) {
	reader := csv.NewReader(r)
	reader.TrimLeadingSpace = true

	// Read header row
	header, err := reader.Read()
	if err != nil {
		return nil, fmt.Errorf("gagal membaca header CSV: %w", err)
	}

	headerMap := make(map[string]int)
	for i, col := range header {
		headerMap[strings.ToLower(strings.TrimSpace(col))] = i
	}

	requiredCols := []string{"nomor_rumah", "alamat", "nama_kk", "telepon_wa"}
	for _, req := range requiredCols {
		if _, ok := headerMap[req]; !ok {
			return nil, fmt.Errorf("kolom wajib '%s' tidak ditemukan dalam file CSV", req)
		}
	}

	summary := &CSVImportSummary{
		Errors: make([]CSVRowError, 0),
	}

	rowNum := 1
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			summary.Failed++
			summary.Errors = append(summary.Errors, CSVRowError{
				Row:   rowNum,
				Error: "format baris CSV tidak valid",
			})
			rowNum++
			continue
		}
		rowNum++
		summary.TotalRows++

		nomorRumah := strings.TrimSpace(row[headerMap["nomor_rumah"]])
		alamat := strings.TrimSpace(row[headerMap["alamat"]])
		namaKK := strings.TrimSpace(row[headerMap["nama_kk"]])
		teleponWA := strings.TrimSpace(row[headerMap["telepon_wa"]])

		if nomorRumah == "" {
			summary.Failed++
			summary.Errors = append(summary.Errors, CSVRowError{
				Row:   rowNum,
				Field: "nomor_rumah",
				Error: "nomor rumah tidak boleh kosong",
			})
			continue
		}

		if alamat == "" {
			summary.Failed++
			summary.Errors = append(summary.Errors, CSVRowError{
				Row:   rowNum,
				Field: "alamat",
				Error: "alamat tidak boleh kosong",
			})
			continue
		}

		if namaKK == "" {
			summary.Failed++
			summary.Errors = append(summary.Errors, CSVRowError{
				Row:   rowNum,
				Field: "nama_kk",
				Error: "nama kepala keluarga tidak boleh kosong",
			})
			continue
		}

		// Optional coordinates
		var lat, lon *float64
		if idx, ok := headerMap["lat"]; ok && idx < len(row) && strings.TrimSpace(row[idx]) != "" {
			if v, err := strconv.ParseFloat(strings.TrimSpace(row[idx]), 64); err == nil {
				lat = &v
			}
		}
		if idx, ok := headerMap["lon"]; ok && idx < len(row) && strings.TrimSpace(row[idx]) != "" {
			if v, err := strconv.ParseFloat(strings.TrimSpace(row[idx]), 64); err == nil {
				lon = &v
			}
		}

		// Optional block name
		var blockID *string
		if idx, ok := headerMap["block_id"]; ok && idx < len(row) && strings.TrimSpace(row[idx]) != "" {
			b := strings.TrimSpace(row[idx])
			blockID = &b
		}

		h := &Household{
			RTID:     rtID,
			BlockID:  blockID,
			Number:   nomorRumah,
			Address:  alamat,
			HeadName: namaKK,
			WAPhone:  teleponWA,
			Lat:      lat,
			Lon:      lon,
		}

		_, err = s.CreateHousehold(ctx, h)
		if err != nil {
			summary.Failed++
			summary.Errors = append(summary.Errors, CSVRowError{
				Row:   rowNum,
				Error: err.Error(),
			})
			continue
		}

		summary.Imported++
	}

	return summary, nil
}

// ExportHousehold returns sanitized export data ensuring no privacy leaks (FR-HH-01, SDD 689).
func (s *Service) ExportHousehold(ctx context.Context, id, actorRole string, actorHouseholdID *string, volunteerBlockIDs []string) (*HouseholdExportDTO, error) {
	h, err := s.GetHousehold(ctx, id, actorRole, actorHouseholdID, volunteerBlockIDs)
	if err != nil {
		return nil, err
	}

	return &HouseholdExportDTO{
		Household:  *h,
		ExportedAt: time.Now().UTC(),
	}, nil
}
