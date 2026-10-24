package assembly

import (
	"context"
	"testing"
)

func TestAssemblyPointCRUDAndCapacityValidation(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	// 1. Capacity <= 0 must fail
	_, err := svc.CreateAssemblyPoint(ctx, &AssemblyPoint{
		RTID:     "rt-01",
		Name:     "Balai Warga RW 05",
		Capacity: 0,
		Lat:      -6.200,
		Lon:      106.800,
	})
	if err == nil || err != ErrInvalidCapacity {
		t.Fatalf("expected ErrInvalidCapacity for capacity 0, got %v", err)
	}

	// 2. Valid assembly point with positive capacity & facilities (FR-AP-01)
	ap, err := svc.CreateAssemblyPoint(ctx, &AssemblyPoint{
		RTID:     "rt-01",
		Name:     "Balai Warga RW 05",
		Capacity: 150,
		Lat:      -6.200,
		Lon:      106.800,
		Facilities: Facilities{
			WheelchairAccessible: true,
			Toilet:               true,
			Electricity:          true,
			Water:                true,
		},
		Contact: "Pak Budi (+62812345678)",
	})
	if err != nil {
		t.Fatalf("create assembly point failed: %v", err)
	}
	if ap.ID == "" || !ap.IsActive {
		t.Fatalf("unexpected assembly point: %+v", ap)
	}

	// 3. Retrieve
	retrieved, err := svc.GetAssemblyPoint(ctx, ap.ID)
	if err != nil {
		t.Fatalf("get assembly point failed: %v", err)
	}
	if retrieved.Capacity != 150 || !retrieved.Facilities.WheelchairAccessible {
		t.Fatalf("data mismatch: %+v", retrieved)
	}
}

func TestBlockAssemblyPointRelationValidation(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	// Create 2 assembly points
	ap1, _ := svc.CreateAssemblyPoint(ctx, &AssemblyPoint{
		RTID:     "rt-01",
		Name:     "Lapangan Olahraga RT 01",
		Capacity: 300,
		Lat:      -6.201,
		Lon:      106.801,
	})
	ap2, _ := svc.CreateAssemblyPoint(ctx, &AssemblyPoint{
		RTID:     "rt-01",
		Name:     "Masjid Al-Ikhlas",
		Capacity: 200,
		Lat:      -6.202,
		Lon:      106.802,
	})

	blockID := "block-A"

	// 1. Same AP as primary and secondary must be rejected (FR-AP-02)
	err := svc.MapBlockAssemblyPoints(ctx, blockID, ap1.ID, ap1.ID)
	if err != ErrSameAssemblyPoint {
		t.Fatalf("expected ErrSameAssemblyPoint, got %v", err)
	}

	// 2. Valid mapping with primary (rank 1) and backup (rank 2)
	err = svc.MapBlockAssemblyPoints(ctx, blockID, ap1.ID, ap2.ID)
	if err != nil {
		t.Fatalf("valid mapping failed: %v", err)
	}

	mappings, err := svc.GetBlockAssemblyPoints(ctx, blockID)
	if err != nil || len(mappings) != 2 {
		t.Fatalf("expected 2 mapped assembly points, got %+v", mappings)
	}
	if mappings[0].Rank != 1 || mappings[0].AssemblyPointID != ap1.ID {
		t.Fatalf("expected primary rank 1, got %+v", mappings[0])
	}
	if mappings[1].Rank != 2 || mappings[1].AssemblyPointID != ap2.ID {
		t.Fatalf("expected secondary rank 2, got %+v", mappings[1])
	}
}
