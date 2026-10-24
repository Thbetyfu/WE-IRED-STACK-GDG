package recap

import (
	"fmt"
	"strings"
	"time"

	"github.com/johnfercher/maroto/pkg/color"
	"github.com/johnfercher/maroto/pkg/consts"
	"github.com/johnfercher/maroto/pkg/pdf"
	"github.com/johnfercher/maroto/pkg/props"
)

// GeneratePDF creates an official PDF document for an incident recap using Maroto (FR-RCP-02).
func GeneratePDF(recap *Recap) ([]byte, error) {
	data := recap.Data
	if data == nil {
		return nil, fmt.Errorf("recap data cannot be nil")
	}

	m := pdf.NewMaroto(consts.Portrait, consts.A4)
	m.SetPageMargins(15, 15, 15)

	headerColor := color.Color{Red: 30, Green: 41, Blue: 59} // Slate 800
	accentColor := color.Color{Red: 15, Green: 118, Blue: 110} // Teal 700

	// 1. Header
	m.Row(10, func() {
		m.Col(12, func() {
			m.Text("WE-IRED — SISTEM TANGGAP BENCANA KOMUNITAS", props.Text{
				Style: consts.Bold,
				Size:  12,
				Align: consts.Center,
				Color: accentColor,
			})
		})
	})
	m.Row(8, func() {
		m.Col(12, func() {
			m.Text("LAPORAN RESMI REKAPITULASI INSIDEN BENCANA", props.Text{
				Style: consts.Bold,
				Size:  14,
				Align: consts.Center,
				Color: headerColor,
			})
		})
	})
	m.Row(6, func() {
		m.Col(12, func() {
			m.Text(fmt.Sprintf("%s — %s — %s", data.Region.RTName, data.Region.RWName, data.Region.KelurahanName), props.Text{
				Style: consts.Normal,
				Size:  10,
				Align: consts.Center,
			})
		})
	})
	m.Line(8)

	// 2. Incident Overview Section
	m.Row(6, func() {
		m.Col(12, func() {
			m.Text("I. INFORMASI KEJADIAN & WILAYAH", props.Text{Style: consts.Bold, Size: 10, Color: headerColor})
		})
	})

	startedStr := data.Incident.StartedAt.Format("02/01/2006 15:04:05 WIB")
	endedStr := "Masih Berlangsung"
	if data.Incident.EndedAt != nil {
		endedStr = data.Incident.EndedAt.Format("02/01/2006 15:04:05 WIB")
	}

	m.Row(6, func() {
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Jenis Bencana: %s (%s)", strings.ToUpper(data.Incident.Hazard), strings.ToUpper(data.Incident.Mode)), props.Text{Size: 9})
		})
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Waktu Mulai: %s", startedStr), props.Text{Size: 9})
		})
	})
	m.Row(6, func() {
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Status Insiden: %s", strings.ToUpper(data.Incident.Status)), props.Text{Size: 9})
		})
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Waktu Selesai: %s (Durasi: %s)", endedStr, data.Incident.Duration), props.Text{Size: 9})
		})
	})
	m.Line(6)

	// 3. Household Status Summary Table
	m.Row(6, func() {
		m.Col(12, func() {
			m.Text("II. REKAP STATUS KELUARGA & KERENTANAN", props.Text{Style: consts.Bold, Size: 10, Color: headerColor})
		})
	})

	hhHeader := []string{"Status", "Jumlah KK", "Persentase"}
	totalKK := data.HouseholdSummary.Total
	if totalKK == 0 {
		totalKK = 1
	}

	pct := func(val int) string {
		return fmt.Sprintf("%.1f%%", float64(val)*100.0/float64(totalKK))
	}

	hhContents := [][]string{
		{"Aman di Rumah", fmt.Sprintf("%d", data.HouseholdSummary.Aman), pct(data.HouseholdSummary.Aman)},
		{"Di Titik Kumpul", fmt.Sprintf("%d", data.HouseholdSummary.TitikKumpul), pct(data.HouseholdSummary.TitikKumpul)},
		{"Butuh Bantuan", fmt.Sprintf("%d", data.HouseholdSummary.ButuhBantuan), pct(data.HouseholdSummary.ButuhBantuan)},
		{"Belum Melapor", fmt.Sprintf("%d", data.HouseholdSummary.BelumMelapor), pct(data.HouseholdSummary.BelumMelapor)},
		{"TOTAL KELUARGA", fmt.Sprintf("%d", data.HouseholdSummary.Total), "100.0%"},
	}
	m.TableList(hhHeader, hhContents, props.TableList{
		HeaderProp: props.TableListContent{Size: 8, Style: consts.Bold},
		ContentProp: props.TableListContent{Size: 8},
		Line: true,
	})
	m.Line(6)

	// 4. Needs & Metrics
	m.Row(6, func() {
		m.Col(6, func() {
			m.Text("III. KEBUTUHAN BANTUAN AGREGAT", props.Text{Style: consts.Bold, Size: 10, Color: headerColor})
		})
		m.Col(6, func() {
			m.Text("IV. METRIK KECEPATAN RESPONS", props.Text{Style: consts.Bold, Size: 10, Color: headerColor})
		})
	})

	m.Row(5, func() {
		m.Col(6, func() { m.Text(fmt.Sprintf("• Evakuasi: %d KK", data.NeedsSummary.Evakuasi), props.Text{Size: 8}) })
		m.Col(6, func() { m.Text(fmt.Sprintf("• Waktu T90 (90%% KK Melapor): %s", data.Metrics.T90), props.Text{Size: 8}) })
	})
	m.Row(5, func() {
		m.Col(6, func() { m.Text(fmt.Sprintf("• Medis / P3K: %d KK", data.NeedsSummary.Medis), props.Text{Size: 8}) })
		m.Col(6, func() { m.Text(fmt.Sprintf("• Waktu T100 (100%% KK Melapor): %s", data.Metrics.T100), props.Text{Size: 8}) })
	})
	m.Row(5, func() {
		m.Col(6, func() { m.Text(fmt.Sprintf("• Makanan & Air: %d KK", data.NeedsSummary.MakananAir), props.Text{Size: 8}) })
		m.Col(6, func() { m.Text(fmt.Sprintf("• Rentan Terjangkau <=30m: %.1f%% (%d/%d)", data.Metrics.VulnReached30, data.VulnerableSummary.ReachedCount, data.VulnerableSummary.TotalVulnerable), props.Text{Size: 8}) })
	})
	m.Row(5, func() {
		m.Col(6, func() { m.Text(fmt.Sprintf("• Hunian Sementara: %d KK", data.NeedsSummary.TempatTinggal), props.Text{Size: 8}) })
		m.Col(6, func() { m.Text(fmt.Sprintf("• Laporan Offline Terkirim: %.1f%%", data.Metrics.OfflineDelivery), props.Text{Size: 8}) })
	})
	m.Row(5, func() {
		m.Col(6, func() { m.Text(fmt.Sprintf("• Lainnya: %d KK", data.NeedsSummary.Lainnya), props.Text{Size: 8}) })
		m.Col(6, func() { m.Text(fmt.Sprintf("• Total Penugasan Selesai: %d/%d tugas", data.TaskSummary.Completed, data.TaskSummary.Total), props.Text{Size: 8}) })
	})
	m.Line(6)

	// 5. Follow-Up Households Table (FR-RCP-01 & FR-RCP-05)
	m.Row(6, func() {
		m.Col(12, func() {
			m.Text("V. DAFTAR RUMAH BUTUH TINDAK LANJUT", props.Text{Style: consts.Bold, Size: 10, Color: headerColor})
		})
	})

	if len(data.FollowUpHouseholds) == 0 {
		m.Row(6, func() {
			m.Col(12, func() {
				m.Text("Tidak ada rumah yang membutuhkan tindak lanjut darurat.", props.Text{Style: consts.Italic, Size: 8})
			})
		})
	} else {
		fuHeader := []string{"No", "KK", "Alamat", "Status", "Urgensi", "Kebutuhan"}
		var fuContents [][]string

		for i, f := range data.FollowUpHouseholds {
			if i >= 15 { // limit preview on first pages
				fuContents = append(fuContents, []string{
					"...", "...", "...", "...", "...",
					fmt.Sprintf("Dan %d rumah lainnya (lihat lampiran CSV)", len(data.FollowUpHouseholds)-15),
				})
				break
			}
			needsStr := strings.Join(f.Needs, ", ")
			if needsStr == "" {
				needsStr = "-"
			}
			fuContents = append(fuContents, []string{
				f.Number,
				f.HeadName,
				f.Address,
				f.Status,
				f.Urgency,
				needsStr,
			})
		}

		m.TableList(fuHeader, fuContents, props.TableList{
			HeaderProp: props.TableListContent{Size: 7, Style: consts.Bold},
			ContentProp: props.TableListContent{Size: 7},
			Line: true,
		})
	}
	m.Line(6)

	// 6. Narrative & Notes
	if recap.Narrative != "" {
		m.Row(5, func() {
			m.Col(12, func() {
				m.Text("VI. NARASI RANGKUMAN & CATATAN PENGURUS", props.Text{Style: consts.Bold, Size: 10, Color: headerColor})
			})
		})
		m.Row(10, func() {
			m.Col(12, func() {
				m.Text(recap.Narrative, props.Text{Size: 8, Extrapolate: true})
			})
		})
		if recap.AIAssisted {
			m.Row(5, func() {
				m.Col(12, func() {
					m.Text("*) Disusun dengan bantuan Asisten AI — telah ditinjau dan disetujui Pengurus RT", props.Text{
						Style: consts.Italic,
						Size:  7,
						Color: color.Color{Red: 100, Green: 116, Blue: 139},
					})
				})
			})
		}
		if recap.Notes != "" {
			m.Row(8, func() {
				m.Col(12, func() {
					m.Text(fmt.Sprintf("Catatan Tambahan: %s", recap.Notes), props.Text{Size: 8, Extrapolate: true})
				})
			})
		}
		m.Line(6)
	}

	// 7. Approval Block
	approvalStatus := "BELUM DISETUJUI (DRAFT)"
	approvedBy := "-"
	approvedAt := "-"
	if recap.ApprovedBy != nil && *recap.ApprovedBy != "" {
		approvalStatus = "DISETUJUI & SAH"
		approvedBy = *recap.ApprovedBy
		if recap.ApprovedAt != nil {
			approvedAt = recap.ApprovedAt.Format("02/01/2006 15:04:05 WIB")
		}
	}

	m.Row(6, func() {
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Status Dokumen: %s", approvalStatus), props.Text{Style: consts.Bold, Size: 9})
		})
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Tanggal Cetak: %s", time.Now().Format("02/01/2006 15:04:05 WIB")), props.Text{Size: 8, Align: consts.Right})
		})
	})
	m.Row(5, func() {
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Disetujui Oleh: %s", approvedBy), props.Text{Size: 8})
		})
		m.Col(6, func() {
			m.Text(fmt.Sprintf("Waktu Persetujuan: %s", approvedAt), props.Text{Size: 8, Align: consts.Right})
		})
	})

	buf, err := m.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to generate maroto pdf: %w", err)
	}

	return buf.Bytes(), nil
}
