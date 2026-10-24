package priority

import (
	"math"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

type Breakdown struct {
	U     float64 `json:"u"`     // Status & Urgensi (maks 40)
	V     float64 `json:"v"`     // Kerentanan (maks 24)
	W     float64 `json:"w"`     // Lama Menunggu (maks 20)
	N     float64 `json:"n"`     // Kebutuhan (maks 10)
	D     float64 `json:"d"`     // Jarak (maks 6)
	Total float64 `json:"total"` // min(100, U + V + W + N + D)
}

type HouseholdInput struct {
	ID                    string
	BlockID               string
	VulnerableCount       int
	Lat                   *float64
	Lon                   *float64
	DistanceToAPMeters    *float64
	HasActiveTask         bool // tugas berstatus 'dijangkau' atau 'selesai' keluar dari antrean
}

type StateInput struct {
	Status             report.ReportStatus
	Urgency            report.ReportUrgency
	Needs              int
	UnconfirmedVuln    int
	LastReportTime     time.Time
	NeedsConfirmation  bool
}

// Calculate computes the priority score and detailed breakdown per SDD 6.1.
// Skor = min(100, U + V + W + N + D)
func Calculate(
	hh *HouseholdInput,
	st *StateInput,
	incidentStartTime time.Time,
	evalTime time.Time,
) (float64, Breakdown) {
	var b Breakdown

	if evalTime.IsZero() {
		evalTime = time.Now().UTC()
	}

	// U - Status & Urgensi (Maks 40)
	if st == nil || st.Status == 0 {
		b.U = 22.0 // Belum melapor
	} else {
		switch st.Status {
		case report.StatusButuhBantuan:
			if st.Urgency == report.UrgencyKritis {
				b.U = 40.0 // Butuh bantuan kritis
			} else {
				b.U = 28.0 // Butuh bantuan biasa
			}
		case report.StatusAman:
			if st.Needs > 0 {
				b.U = 10.0 // Aman di rumah dengan kebutuhan
			} else {
				b.U = 0.0 // Aman tanpa kebutuhan (keluar antrean)
			}
		case report.StatusTitikKumpul:
			vulnRemain := 0
			if hh != nil {
				vulnRemain = hh.VulnerableCount
			}
			if st.UnconfirmedVuln > 0 {
				vulnRemain = st.UnconfirmedVuln
			}
			if vulnRemain > 0 {
				b.U = 8.0 // Di titik kumpul dengan anggota rentan belum terkonfirmasi
			} else {
				b.U = 0.0 // Di titik kumpul lengkap
			}
		}
	}

	// V - Kerentanan (Maks 24): 8 * jumlah anggota rentan belum terkonfirmasi aman
	unconfirmedVuln := 0
	if hh != nil {
		unconfirmedVuln = hh.VulnerableCount
	}
	if st != nil && st.UnconfirmedVuln > 0 {
		unconfirmedVuln = st.UnconfirmedVuln
	}
	b.V = math.Min(24.0, 8.0*float64(unconfirmedVuln))

	// W - Lama Menunggu (Maks 20): 0.25 * menit sejak aktivasi (belum melapor) atau sejak laporan butuh bantuan terakhir
	var waitMinutes float64
	if st == nil || st.Status == 0 {
		if !incidentStartTime.IsZero() && evalTime.After(incidentStartTime) {
			waitMinutes = evalTime.Sub(incidentStartTime).Minutes()
		}
	} else if st.Status == report.StatusButuhBantuan {
		refTime := st.LastReportTime
		if refTime.IsZero() {
			refTime = incidentStartTime
		}
		if !refTime.IsZero() && evalTime.After(refTime) {
			waitMinutes = evalTime.Sub(refTime).Minutes()
		}
	}
	if waitMinutes > 0 {
		b.W = math.Min(20.0, 0.25*waitMinutes)
	}

	// N - Kebutuhan (Maks 10)
	if st != nil && st.Needs > 0 {
		needsSum := 0.0
		if st.Needs&report.NeedEvakuasi != 0 {
			needsSum += 6.0
		}
		if st.Needs&report.NeedMedis != 0 {
			needsSum += 6.0
		}
		if st.Needs&report.NeedMakananAir != 0 {
			needsSum += 2.0
		}
		if st.Needs&report.NeedTempatTinggal != 0 {
			needsSum += 2.0
		}
		if st.Needs&report.NeedLainnya != 0 {
			needsSum += 1.0
		}
		b.N = math.Min(10.0, needsSum)
	}

	// D - Jarak (Maks 6): 6 * min(1.0, jarak / 500 m)
	if hh != nil && hh.DistanceToAPMeters != nil && *hh.DistanceToAPMeters > 0 {
		ratio := *hh.DistanceToAPMeters / 500.0
		b.D = 6.0 * math.Min(1.0, ratio)
	}

	// If household has completed or reached task without new need, exit queue
	if hh != nil && hh.HasActiveTask && (st == nil || st.Status != report.StatusButuhBantuan) {
		b.Total = 0.0
		return 0.0, b
	}

	b.Total = math.Min(100.0, round1(b.U+b.V+b.W+b.N+b.D))
	return b.Total, b
}

func round1(val float64) float64 {
	return math.Round(val*10) / 10
}
