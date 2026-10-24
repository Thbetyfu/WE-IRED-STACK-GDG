package synthetic

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"github.com/google/uuid"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/assembly"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

type Generator struct {
	regionStore    region.Store
	householdStore household.Store
	volunteerStore volunteer.Store
	assemblyStore  assembly.Store
	incidentStore  incident.Store
	reportService  *report.Service
}

func NewGenerator(
	regStore region.Store,
	hhStore household.Store,
	volStore volunteer.Store,
	asmStore assembly.Store,
	incStore incident.Store,
	repSvc *report.Service,
) *Generator {
	return &Generator{
		regionStore:    regStore,
		householdStore: hhStore,
		volunteerStore: volStore,
		assemblyStore:  asmStore,
		incidentStore:  incStore,
		reportService:  repSvc,
	}
}

type GenerateResult struct {
	RTID            string `json:"rt_id"`
	HouseholdsCount int    `json:"households_count"`
	MembersCount    int    `json:"members_count"`
	VolunteersCount int    `json:"volunteers_count"`
	DrillIncidentID string `json:"drill_incident_id,omitempty"`
	ReportsCount    int    `json:"reports_count"`
	IsSynthetic     bool   `json:"is_synthetic"`
}

// GenerateRTData generates ~100 synthetic households with members, volunteers, and drill reports (FR-ADM-03).
func (g *Generator) GenerateRTData(ctx context.Context, rtID string, targetCount int) (*GenerateResult, error) {
	if targetCount <= 0 {
		targetCount = 100
	}

	// 1. Ensure Region exists
	reg, _ := g.regionStore.GetRegionByID(ctx, rtID)
	if reg == nil {
		reg = &region.Region{
			ID:   rtID,
			Code: "RT_SYNTHETIC",
			Name: "RT 05 (Data Sintetis Demo)",
			Type: region.TypeRT,
		}
		_ = g.regionStore.CreateRegion(ctx, reg)
	}

	// 2. Create 4 Blocks: Blok A, B, C, D
	blockNames := []string{"Blok A (Melati)", "Blok B (Mawar)", "Blok C (Kenanga)", "Blok D (Cempaka)"}
	var blockIDs []string
	for i, bName := range blockNames {
		bID := fmt.Sprintf("%s-block-%d", rtID, i+1)
		b := &volunteer.Block{
			ID:   bID,
			RTID: rtID,
			Name: bName,
		}
		_ = g.volunteerStore.CreateBlock(ctx, b)
		blockIDs = append(blockIDs, bID)
	}

	// 3. Create 2 Assembly Points (Utama & Cadangan)
	apUtama := &assembly.AssemblyPoint{
		ID:       fmt.Sprintf("%s-ap-utama", rtID),
		RTID:     rtID,
		Name:     "Lapangan RT 05 (Utama)",
		Capacity: 250,
		Facilities: assembly.Facilities{
			WheelchairAccessible: true,
			Toilet:               true,
			Water:                true,
			Electricity:          true,
		},
		IsActive: true,
	}
	_ = g.assemblyStore.CreateAssemblyPoint(ctx, apUtama)

	apCadangan := &assembly.AssemblyPoint{
		ID:       fmt.Sprintf("%s-ap-cadangan", rtID),
		RTID:     rtID,
		Name:     "Balai Warga RW 02 (Cadangan)",
		Capacity: 150,
		Facilities: assembly.Facilities{
			WheelchairAccessible: false,
			Toilet:               true,
			Water:                true,
		},
		IsActive: true,
	}
	_ = g.assemblyStore.CreateAssemblyPoint(ctx, apCadangan)

	for _, bid := range blockIDs {
		_ = g.assemblyStore.SetBlockAssemblyPoints(ctx, bid, apUtama.ID, apCadangan.ID)
	}

	// 4. Generate ~100 Households marked with is_synthetic = true
	firstNames := []string{"Budi", "Agus", "Bambang", "Siti", "Dewi", "Eko", "Hendra", "Ratna", "Wayan", "Surya", "Indah", "Rina", "Tri", "Yusuf", "Ahmad", "Joko"}
	lastNames := []string{"Santoso", "Pratama", "Wijaya", "Kusuma", "Hidayat", "Saputra", "Lestari", "Nugroho", "Wibowo", "Siregar", "Utami", "Firmansyah"}

	householdsPerBlock := targetCount / len(blockIDs)
	if householdsPerBlock <= 0 {
		householdsPerBlock = 25
	}

	createdHHs := 0
	createdMembers := 0
	var hhList []*household.Household

	r := rand.New(rand.NewSource(time.Now().UnixNano()))

	for bIdx, bID := range blockIDs {
		prefix := string(rune('A' + bIdx))
		for num := 1; num <= householdsPerBlock; num++ {
			hhID := fmt.Sprintf("%s-hh-%s%02d", rtID, prefix, num)
			head := fmt.Sprintf("%s %s", firstNames[r.Intn(len(firstNames))], lastNames[r.Intn(len(lastNames))])
			phone := fmt.Sprintf("62819%07d", createdHHs+1)
			hasDevice := true
			if num%8 == 0 { // ~12% have no smartphone
				phone = ""
				hasDevice = false
			}

			lat := -6.2000 + (r.Float64()-0.5)*0.005
			lon := 106.8166 + (r.Float64()-0.5)*0.005
			blockCopy := bID

			hh := &household.Household{
				ID:          hhID,
				RTID:        rtID,
				BlockID:     &blockCopy,
				Number:      fmt.Sprintf("%s-%02d", prefix, num),
				Address:     fmt.Sprintf("Jl. Mawar %s No. %d", prefix, num),
				Lat:         &lat,
				Lon:         &lon,
				HeadName:    head,
				WAPhone:     phone,
				HasDevice:   hasDevice,
				IsSynthetic: true, // FR-ADM-03: Marked as synthetic
				CreatedAt:   time.Now().UTC(),
			}

			_ = g.householdStore.CreateHousehold(ctx, hh)
			createdHHs++
			hhList = append(hhList, hh)

			// Generate 2-4 family members per household
			numMembers := 2 + r.Intn(3)
			for mIdx := 0; mIdx < numMembers; mIdx++ {
				birthYear := 1990 - r.Intn(30)
				needsEvac := false
				vulnFlags := 0

				// Add vulnerable categories (elderly, toddler, special assist)
				if mIdx == 1 && r.Float64() < 0.25 {
					birthYear = 1945 + r.Intn(15) // Lansia (>= 60 th)
					vulnFlags = household.VulnLansia
					if r.Float64() < 0.5 {
						needsEvac = true
					}
				} else if mIdx == numMembers-1 && r.Float64() < 0.20 {
					birthYear = 2021 + r.Intn(3) // Balita (<= 5 th)
					vulnFlags = household.VulnBalita
				}

				m := &household.Member{
					ID:              uuid.NewString(),
					HouseholdID:     hh.ID,
					Name:            fmt.Sprintf("%s %s", firstNames[r.Intn(len(firstNames))], lastNames[r.Intn(len(lastNames))]),
					Relation:        "Keluarga",
					BirthYear:       birthYear,
					NeedsEvacAssist: needsEvac,
					VulnFlags:       vulnFlags,
				}
				_ = g.householdStore.AddMember(ctx, m)
				createdMembers++
			}
		}
	}

	// 5. Generate Volunteers
	volNames := []string{"Relawan Andi", "Relawan Bima", "Relawan Citra", "Relawan Doni"}
	createdVols := 0
	for i, vName := range volNames {
		vID := fmt.Sprintf("%s-vol-%d", rtID, i+1)
		v := &volunteer.Volunteer{
			UserID:         vID,
			RTID:           rtID,
			Name:           vName,
			Phone:          fmt.Sprintf("62818000000%d", i+1),
			Skills:         []string{"evakuasi", "P3K"},
			Available:      true,
			AssignedBlocks: []string{blockIDs[i%len(blockIDs)]},
			CreatedAt:      time.Now().UTC(),
		}
		_ = g.volunteerStore.CreateVolunteer(ctx, v)
		createdVols++
	}

	// 6. Generate Drill Incident and Simulated Reports
	drillInc := &incident.Incident{
		ID:        fmt.Sprintf("%s-drill-%d", rtID, time.Now().Unix()),
		RTID:      rtID,
		ShortID:   uint32(8000 + r.Intn(1000)),
		Hazard:    incident.HazardBanjir,
		Mode:      incident.ModeLatihan, // Latihan mode only
		Status:    incident.StatusAktif,
		Message:   "Simulasi Latihan Tanggap Darurat Banjir RT 05",
		StartedBy: "system-demo",
		StartedAt: time.Now().Add(-45 * time.Minute),
	}
	_ = g.incidentStore.CreateIncident(ctx, drillInc)

	createdReports := 0
	for i, h := range hhList {
		if i >= 70 { // 70 households reported, 30 not reported
			break
		}

		repStatus := report.StatusAman
		repUrgency := report.UrgencyNone
		needs := 0

		if i%7 == 0 {
			repStatus = report.StatusButuhBantuan
			needs = report.NeedEvakuasi
			if i%14 == 0 {
				repUrgency = report.UrgencyKritis
				needs = report.NeedEvakuasi | report.NeedMedis
			}
		} else if i%5 == 0 {
			repStatus = report.StatusTitikKumpul
		}

		rep := &report.Report{
			ID:          uuid.NewString(),
			IncidentID:  drillInc.ID,
			HouseholdID: h.ID,
			Status:      repStatus,
			Urgency:     repUrgency,
			Needs:       needs,
			Channel:     report.ChannelAplikasi,
			ReceivedAt:  drillInc.StartedAt.Add(time.Duration(r.Intn(30)) * time.Minute),
		}

		if g.reportService != nil {
			_, _ = g.reportService.SubmitReport(ctx, rep)
		}
		createdReports++
	}

	return &GenerateResult{
		RTID:            rtID,
		HouseholdsCount: createdHHs,
		MembersCount:    createdMembers,
		VolunteersCount: createdVols,
		DrillIncidentID: drillInc.ID,
		ReportsCount:    createdReports,
		IsSynthetic:     true,
	}, nil
}
