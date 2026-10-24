package recap

import (
	"bytes"
	"encoding/csv"
	"fmt"
	"strings"
)

// GenerateCSV serializes RecapData into structured CSV bytes (FR-RCP-02).
func GenerateCSV(data *RecapData) ([]byte, error) {
	var buf bytes.Buffer
	w := csv.NewWriter(&buf)

	// Section 1: Ringkasan Insiden
	_ = w.Write([]string{"=== REKAP INSIDEN BENCANA WE-IRED ==="})
	_ = w.Write([]string{"Kategori", "Nilai"})
	_ = w.Write([]string{"Wilayah", fmt.Sprintf("%s, %s, %s", data.Region.RTName, data.Region.RWName, data.Region.KelurahanName)})
	_ = w.Write([]string{"Jenis Bencana", data.Incident.Hazard})
	_ = w.Write([]string{"Mode Insiden", data.Incident.Mode})
	_ = w.Write([]string{"Status Insiden", data.Incident.Status})
	_ = w.Write([]string{"Waktu Mulai", data.Incident.StartedAt.Format("02/01/2006 15:04:05")})
	if data.Incident.EndedAt != nil {
		_ = w.Write([]string{"Waktu Selesai", data.Incident.EndedAt.Format("02/01/2006 15:04:05")})
	} else {
		_ = w.Write([]string{"Waktu Selesai", "Masih Berlangsung"})
	}
	_ = w.Write([]string{"Durasi", data.Incident.Duration})
	_ = w.Write([]string{""})

	// Section 2: Ringkasan Status Rumah Tangga
	_ = w.Write([]string{"=== RINGKASAN STATUS RUMAH TANGGA ==="})
	_ = w.Write([]string{"Status Rumah", "Jumlah KK"})
	_ = w.Write([]string{"Total Terdaftar", fmt.Sprintf("%d", data.HouseholdSummary.Total)})
	_ = w.Write([]string{"Aman di Rumah", fmt.Sprintf("%d", data.HouseholdSummary.Aman)})
	_ = w.Write([]string{"Sudah di Titik Kumpul", fmt.Sprintf("%d", data.HouseholdSummary.TitikKumpul)})
	_ = w.Write([]string{"Butuh Bantuan", fmt.Sprintf("%d", data.HouseholdSummary.ButuhBantuan)})
	_ = w.Write([]string{"Belum Melapor", fmt.Sprintf("%d", data.HouseholdSummary.BelumMelapor)})
	_ = w.Write([]string{""})

	// Section 3: Kebutuhan Bantuan Agregat
	_ = w.Write([]string{"=== KEBUTUHAN BANTUAN AGREGAT ==="})
	_ = w.Write([]string{"Jenis Kebutuhan", "Jumlah Permintaan"})
	_ = w.Write([]string{"Evakuasi", fmt.Sprintf("%d", data.NeedsSummary.Evakuasi)})
	_ = w.Write([]string{"Medis / P3K", fmt.Sprintf("%d", data.NeedsSummary.Medis)})
	_ = w.Write([]string{"Makanan & Air", fmt.Sprintf("%d", data.NeedsSummary.MakananAir)})
	_ = w.Write([]string{"Tempat Tinggal Sementara", fmt.Sprintf("%d", data.NeedsSummary.TempatTinggal)})
	_ = w.Write([]string{"Lainnya", fmt.Sprintf("%d", data.NeedsSummary.Lainnya)})
	_ = w.Write([]string{""})

	// Section 4: Metrik Respons
	_ = w.Write([]string{"=== METRIK RESPONS INSIDEN ==="})
	_ = w.Write([]string{"Metrik", "Nilai"})
	_ = w.Write([]string{"T90 (90% Melapor)", data.Metrics.T90})
	_ = w.Write([]string{"T100 (100% Melapor)", data.Metrics.T100})
	_ = w.Write([]string{"Rentan Terjangkau <=30m", fmt.Sprintf("%.1f%%", data.Metrics.VulnReached30)})
	_ = w.Write([]string{"Laporan Offline Diterima", fmt.Sprintf("%.1f%%", data.Metrics.OfflineDelivery)})
	_ = w.Write([]string{""})

	// Section 5: Daftar Rumah Butuh Tindak Lanjut
	_ = w.Write([]string{"=== DAFTAR RUMAH BUTUH TINDAK LANJUT ==="})
	_ = w.Write([]string{"No", "Nomor Rumah", "Kepala Keluarga", "Alamat", "Status", "Tingkat Urgensi", "Kebutuhan"})

	for i, f := range data.FollowUpHouseholds {
		needsStr := strings.Join(f.Needs, ", ")
		if needsStr == "" {
			needsStr = "-"
		}
		_ = w.Write([]string{
			fmt.Sprintf("%d", i+1),
			f.Number,
			f.HeadName,
			f.Address,
			f.Status,
			f.Urgency,
			needsStr,
		})
	}

	w.Flush()
	if err := w.Error(); err != nil {
		return nil, fmt.Errorf("failed to generate csv: %w", err)
	}

	return buf.Bytes(), nil
}
