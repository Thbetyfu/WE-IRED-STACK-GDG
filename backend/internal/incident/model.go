package incident

import (
	"time"
)

type HazardType string

const (
	HazardBanjir    HazardType = "banjir"
	HazardLongsor   HazardType = "longsor"
	HazardGempa     HazardType = "gempa"
	HazardKebakaran HazardType = "kebakaran"
	HazardLainnya   HazardType = "lainnya"
)

type IncidentMode string

const (
	ModeNyata   IncidentMode = "nyata"
	ModeLatihan IncidentMode = "latihan"
)

type IncidentStatus string

const (
	StatusAktif   IncidentStatus = "aktif"
	StatusSelesai IncidentStatus = "selesai"
)

type IncidentMetrics struct {
	T90             string         `json:"t90"`              // Selisih waktu aktivasi ke 90% rumah melapor (SDD 6.5)
	T100            string         `json:"t100"`             // Selisih waktu aktivasi ke 100% rumah melapor (SDD 6.5)
	VulnReached30   float64        `json:"vuln_reached_30"`  // Persentase rumah rentan terjangkau <= 30 menit (0.0 - 100.0)
	ByChannel       map[string]int `json:"by_channel"`       // Jumlah laporan per kanal
	OfflineDelivery float64        `json:"offline_delivery"` // Rasio laporan offline sampai ke backend (0.0 - 100.0)
	TRecap          string         `json:"t_recap"`          // Durasi akhir insiden ke rekap disetujui
}

type Incident struct {
	ID            string          `json:"id"`
	RTID          string          `json:"rt_id"`
	ShortID       uint32          `json:"short_id"` // uint32 untuk paket relay (SDD 5.2, 7.2)
	Hazard        HazardType      `json:"hazard"`
	Mode          IncidentMode    `json:"mode"`
	ScopeBlockIDs []string        `json:"scope_block_ids"` // kosong = seluruh RT
	Message       string          `json:"message"`
	StartedBy     string          `json:"started_by"`
	StartedAt     time.Time       `json:"started_at"`
	EndedAt       *time.Time      `json:"ended_at,omitempty"`
	Status        IncidentStatus  `json:"status"`
	Metrics       IncidentMetrics `json:"metrics"`
	CreatedAt     time.Time       `json:"created_at"`
}

type ActivationDraft struct {
	Token         string       `json:"confirmation_token"`
	RTID          string       `json:"rt_id"`
	Hazard        HazardType   `json:"hazard"`
	Mode          IncidentMode `json:"mode"`
	ScopeBlockIDs []string     `json:"scope_block_ids"`
	Message       string       `json:"message"`
	StartedBy     string       `json:"started_by"`
	CreatedAt     time.Time    `json:"created_at"`
	ExpiresAt     time.Time    `json:"expires_at"`
}

type IncidentSummary struct {
	Incident         Incident       `json:"incident"`
	TotalHouseholds  int            `json:"total_households"`
	ReportedCount    int            `json:"reported_count"`
	AmanCount        int            `json:"aman_count"`
	TitikKumpulCount int            `json:"titik_kumpul_count"`
	ButuhBantuanCount int           `json:"butuh_bantuan_count"`
	KritisCount      int            `json:"kritis_count"`
	BelumMelaporCount int           `json:"belum_melapor_count"`
	ElapsedMinutes   int            `json:"elapsed_minutes"`
}

type DrillComparisonMetric struct {
	IncidentID      string     `json:"incident_id"`
	Hazard          HazardType `json:"hazard"`
	StartedAt       time.Time  `json:"started_at"`
	T90             string     `json:"t90"`
	T100            string     `json:"t100"`
	VulnReached30   float64    `json:"vuln_reached_30"`
	OfflineDelivery float64    `json:"offline_delivery"`
}

type DrillComparisonSummary struct {
	TotalDrills            int                     `json:"total_drills"`
	AverageVulnReached30   float64                 `json:"average_vuln_reached_30"`
	AverageOfflineDelivery float64                 `json:"average_offline_delivery"`
	Trend                  string                  `json:"trend"` // "improving", "stable", "empty"
	Drills                 []DrillComparisonMetric `json:"drills"`
}
