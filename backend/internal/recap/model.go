package recap

import (
	"time"
)

// Recap represents the compiled disaster incident report (FR-RCP-01 & SDD 386).
type Recap struct {
	ID         string     `json:"id"`
	IncidentID string     `json:"incident_id"`
	Data       *RecapData `json:"data"`
	Narrative  string     `json:"narrative"`
	AIAssisted bool       `json:"ai_assisted"`
	Notes      string     `json:"notes"`
	ApprovedBy *string    `json:"approved_by,omitempty"`
	ApprovedAt *time.Time `json:"approved_at,omitempty"`
	PDFURL     *string    `json:"pdf_url,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

// RecapData holds the aggregated incident information (FR-RCP-01).
type RecapData struct {
	Region            RegionInfo          `json:"region"`
	Incident          IncidentInfo        `json:"incident"`
	HouseholdSummary  HouseholdSummary    `json:"household_summary"`
	VulnerableSummary VulnerableSummary   `json:"vulnerable_summary"`
	NeedsSummary      NeedsSummary        `json:"needs_summary"`
	FollowUpHouseholds []FollowUpHousehold `json:"follow_up_households"`
	TaskSummary       TaskSummary         `json:"task_summary"`
	Metrics           MetricSummary       `json:"metrics"`
	Timeline          []TimelineEvent     `json:"timeline"`
}

type RegionInfo struct {
	RTID          string `json:"rt_id"`
	RTName        string `json:"rt_name"`
	RWName        string `json:"rw_name"`
	KelurahanName string `json:"kelurahan_name"`
}

type IncidentInfo struct {
	ID        string     `json:"id"`
	Hazard    string     `json:"hazard"`
	Mode      string     `json:"mode"`
	Status    string     `json:"status"`
	StartedAt time.Time  `json:"started_at"`
	EndedAt   *time.Time `json:"ended_at,omitempty"`
	Duration  string     `json:"duration"`
}

type HouseholdSummary struct {
	Total         int `json:"total"`
	Aman          int `json:"aman"`
	TitikKumpul   int `json:"titik_kumpul"`
	ButuhBantuan  int `json:"butuh_bantuan"`
	BelumMelapor  int `json:"belum_melapor"`
}

type VulnerableSummary struct {
	TotalVulnerable int     `json:"total_vulnerable"`
	ReachedCount    int     `json:"reached_count"`
	Percentage      float64 `json:"percentage"`
}

type NeedsSummary struct {
	Evakuasi      int `json:"evakuasi"`
	Medis         int `json:"medis"`
	MakananAir    int `json:"makanan_air"`
	TempatTinggal int `json:"tempat_tinggal"`
	Lainnya       int `json:"lainnya"`
}

type FollowUpHousehold struct {
	HouseholdID string   `json:"household_id"`
	Number      string   `json:"number"`
	HeadName    string   `json:"head_name"`
	Address     string   `json:"address"`
	Status      string   `json:"status"`
	Urgency     string   `json:"urgency"`
	Needs       []string `json:"needs"`
	Lat         *float64 `json:"lat,omitempty"`
	Lon         *float64 `json:"lon,omitempty"`
}

type TaskSummary struct {
	Total      int `json:"total"`
	Completed  int `json:"completed"`
	InProgress int `json:"in_progress"`
	Accepted   int `json:"accepted"`
	Rejected   int `json:"rejected"`
	TimedOut   int `json:"timed_out"`
}

type MetricSummary struct {
	T90             string         `json:"t90"`
	T100            string         `json:"t100"`
	VulnReached30   float64        `json:"vuln_reached_30"`
	OfflineDelivery float64        `json:"offline_delivery"`
	TRecap          string         `json:"t_recap"`
	ByChannel       map[string]int `json:"by_channel"`
}

type TimelineEvent struct {
	Time        time.Time `json:"time"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
}

type UpdateRecapInput struct {
	Notes      *string `json:"notes,omitempty"`
	Narrative  *string `json:"narrative,omitempty"`
	AIAssisted *bool   `json:"ai_assisted,omitempty"`
}
