package household

import (
	"encoding/hex"
	"time"
)

// Vulnerability bitmask flags according to SDD 337.
const (
	VulnLansia         = 1 << 0 // bit 0: lansia (age >= 60)
	VulnDisabilitas    = 1 << 1 // bit 1: disabilitas
	VulnIbuHamil       = 1 << 2 // bit 2: ibu hamil
	VulnBalita         = 1 << 3 // bit 3: balita (age <= 5)
	VulnPenyakitKronis  = 1 << 4 // bit 4: penyakit kronis
)

// ComputeAutoVulnFlags automatically computes age-based flags (lansia & balita) per FR-HH-03.
func ComputeAutoVulnFlags(birthYear int, currentYear int, existingFlags int) int {
	if currentYear <= 0 {
		currentYear = time.Now().Year()
	}

	age := currentYear - birthYear
	flags := existingFlags

	// Lansia (usia >= 60)
	if age >= 60 {
		flags |= VulnLansia
	} else {
		// Only clear if it was an auto-flag; if manually set, caller preserves it
	}

	// Balita (usia <= 5 dan >= 0)
	if age >= 0 && age <= 5 {
		flags |= VulnBalita
	}

	return flags
}

type Household struct {
	ID          string    `json:"id"`
	RTID        string    `json:"rt_id"`
	BlockID     *string   `json:"block_id,omitempty"`
	Number      string    `json:"number"`
	Address     string    `json:"address"`
	Lat         *float64  `json:"lat,omitempty"`
	Lon         *float64  `json:"lon,omitempty"`
	HeadName    string    `json:"head_name"`
	WAPhone     string    `json:"wa_phone"`
	HasDevice   bool      `json:"has_device"` // false -> perlu dijangkau relawan (FR-HH-08)
	ShortID     []byte    `json:"-"`
	ShortIDHex  string    `json:"short_id"` // 8-byte hex representation (16 chars)
	KeyEnc      []byte    `json:"-"`
	InviteCode  *string   `json:"invite_code,omitempty"`
	IsSynthetic bool      `json:"is_synthetic"`
	HasConsent  bool      `json:"has_consent"`
	Members     []*Member `json:"members,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

func (h *Household) SetShortID(b []byte) {
	h.ShortID = b
	h.ShortIDHex = hex.EncodeToString(b)
}

type Member struct {
	ID              string    `json:"id"`
	HouseholdID     string    `json:"household_id"`
	Idx             int       `json:"idx"` // 0-7, urutan untuk bitmask paket
	Name            string    `json:"name"`
	BirthYear       int       `json:"birth_year"`
	Sex             string    `json:"sex"` // L / P
	Relation        string    `json:"relation"`
	VulnFlags       int       `json:"vuln_flags"`
	HealthNotesEnc  []byte    `json:"-"`
	HealthNotes     string    `json:"health_notes,omitempty"` // plaintext if authorized
	NeedsEvacAssist bool      `json:"needs_evac_assist"`
	CreatedAt       time.Time `json:"created_at"`
}

type Consent struct {
	ID          string     `json:"id"`
	HouseholdID string     `json:"household_id"`
	GivenBy     string     `json:"given_by"`
	Method      string     `json:"method"` // aplikasi | kertas | lisan_disaksikan
	TextVersion string     `json:"text_version"`
	GivenAt     time.Time  `json:"given_at"`
	RevokedAt   *time.Time `json:"revoked_at,omitempty"`
}

type CSVRowError struct {
	Row   int    `json:"row"`
	Field string `json:"field,omitempty"`
	Error string `json:"error"`
}

type CSVImportSummary struct {
	TotalRows int            `json:"total_rows"`
	Imported  int            `json:"imported"`
	Failed    int            `json:"failed"`
	Errors    []CSVRowError  `json:"errors"`
}

type HouseholdExportDTO struct {
	Household
	ExportedAt time.Time `json:"exported_at"`
}
