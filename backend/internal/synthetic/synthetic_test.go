package synthetic_test

import (
	"context"
	"testing"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/assembly"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/synthetic"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
)

func TestSyntheticDataGenerator(t *testing.T) {
	ctx := context.Background()

	regStore := region.NewMemoryStore()
	hhStore := household.NewMemoryStore()
	volStore := volunteer.NewMemoryStore()
	asmStore := assembly.NewMemoryStore()
	incStore := incident.NewMemoryStore()
	repStore := report.NewMemoryStore()
	repSvc := report.NewService(repStore)

	gen := synthetic.NewGenerator(regStore, hhStore, volStore, asmStore, incStore, repSvc)

	// 1. Generate 100 households for demo RT
	rtID := "rt-demo-99"
	res, err := gen.GenerateRTData(ctx, rtID, 100)
	if err != nil {
		t.Fatalf("GenerateRTData failed: %v", err)
	}

	if res.HouseholdsCount != 100 {
		t.Errorf("expected 100 households, got %d", res.HouseholdsCount)
	}
	if res.MembersCount < 200 {
		t.Errorf("expected >= 200 members, got %d", res.MembersCount)
	}
	if res.VolunteersCount != 4 {
		t.Errorf("expected 4 volunteers, got %d", res.VolunteersCount)
	}
	if res.ReportsCount != 70 {
		t.Errorf("expected 70 simulated drill reports, got %d", res.ReportsCount)
	}
	if !res.IsSynthetic {
		t.Errorf("expected is_synthetic to be true")
	}

	// 2. Verify all generated households have is_synthetic = true and valid block binding
	households, err := hhStore.ListHouseholdsByRT(ctx, rtID, nil)
	if err != nil || len(households) != 100 {
		t.Fatalf("ListHouseholdsByRT failed or count mismatch: %d", len(households))
	}

	for _, h := range households {
		if !h.IsSynthetic {
			t.Fatalf("CRITICAL VIOLATION: synthetic household %s does NOT have is_synthetic = true", h.ID)
		}
		if h.BlockID == nil || *h.BlockID == "" {
			t.Fatalf("synthetic household %s is not bound to a valid block", h.ID)
		}
	}

	// 3. Verify assembly points are created and mapped to blocks
	aps, err := asmStore.ListAssemblyPointsByRT(ctx, rtID, true)
	if err != nil || len(aps) < 2 {
		t.Errorf("expected at least 2 active assembly points, got %d", len(aps))
	}

	// 4. Verify drill incident is strictly ModeLatihan
	drillInc, err := incStore.GetIncident(ctx, res.DrillIncidentID)
	if err != nil || drillInc == nil {
		t.Fatalf("drill incident not found: %s", res.DrillIncidentID)
	}
	if drillInc.Mode != incident.ModeLatihan {
		t.Errorf("CRITICAL VIOLATION: synthetic incident must be ModeLatihan, got %s", drillInc.Mode)
	}
}
