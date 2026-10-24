package task

import (
	"errors"
	"time"
)

type TaskStatus string

const (
	StatusDisarankan      TaskStatus = "disarankan"
	StatusDitugaskan      TaskStatus = "ditugaskan"
	StatusDiterima        TaskStatus = "diterima"
	StatusDalamPerjalanan TaskStatus = "dalam_perjalanan"
	StatusDijangkau       TaskStatus = "dijangkau"
	StatusSelesai         TaskStatus = "selesai"
	StatusDitolak         TaskStatus = "ditolak"
	StatusDibatalkan      TaskStatus = "dibatalkan"
)

type TaskOutcome string

const (
	OutcomeAmanDiTempat TaskOutcome = "aman_di_tempat"
	OutcomeDievakuasi   TaskOutcome = "dievakuasi"
	OutcomeDirujuk      TaskOutcome = "dirujuk"
	OutcomeButuhLanjutan TaskOutcome = "butuh_lanjutan"
)

var (
	ErrTaskNotFound          = errors.New("tugas tidak ditemukan")
	ErrInvalidTaskTransition = errors.New("perubahan status tugas tidak diperbolehkan oleh state machine")
	ErrRejectReasonRequired  = errors.New("alasan penolakan tugas wajib diisi saat menolak tugas")
	ErrOutcomeRequired       = errors.New("hasil penjangkauan (outcome) wajib diisi saat tugas dijangkau atau selesai (FR-TSK-04)")
	ErrVolunteerNotAssigned  = errors.New("tugas ini tidak ditugaskan kepada relawan yang melakukan perubahan")
	ErrVolunteerOverCapacity = errors.New("relawan telah mencapai kapasitas beban aktif maksimum (2 tugas aktif)")
)

type Task struct {
	ID           string       `json:"id"`
	IncidentID   string       `json:"incident_id"`
	HouseholdID  string       `json:"household_id"`
	VolunteerID  *string      `json:"volunteer_id,omitempty"`
	Status       TaskStatus   `json:"status"`
	Outcome      *TaskOutcome `json:"outcome,omitempty"`
	RejectReason *string      `json:"reject_reason,omitempty"`
	Notes        *string      `json:"notes,omitempty"`
	CreatedBy    string       `json:"created_by"`
	AssignedAt   *time.Time   `json:"assigned_at,omitempty"`
	AcceptedAt   *time.Time   `json:"accepted_at,omitempty"`
	ReachedAt    *time.Time   `json:"reached_at,omitempty"`
	CompletedAt  *time.Time   `json:"completed_at,omitempty"`
	CreatedAt    time.Time    `json:"created_at"`
	UpdatedAt    time.Time    `json:"updated_at"`
	IsOverdue    bool         `json:"is_overdue"` // FR-TSK-05: true jika > 5 menit belum diterima
}

type UpdateTaskRequest struct {
	Status       TaskStatus   `json:"status"`
	Outcome      *TaskOutcome `json:"outcome,omitempty"`
	RejectReason *string      `json:"reject_reason,omitempty"`
	Notes        *string      `json:"notes,omitempty"`
	VolunteerID  *string      `json:"volunteer_id,omitempty"`
}

type CreateTaskRequest struct {
	HouseholdID string      `json:"household_id"`
	VolunteerID *string     `json:"volunteer_id,omitempty"`
	Status      *TaskStatus `json:"status,omitempty"`
	Notes       *string     `json:"notes,omitempty"`
}
