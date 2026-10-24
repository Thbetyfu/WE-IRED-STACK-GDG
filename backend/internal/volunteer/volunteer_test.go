package volunteer

import (
	"context"
	"testing"
)

func TestBlockCRUD(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	// 1. Create Block
	b, err := svc.CreateBlock(ctx, &Block{
		RTID: "rt-01",
		Name: "Blok Melati",
	})
	if err != nil {
		t.Fatalf("create block failed: %v", err)
	}
	if b.ID == "" {
		t.Fatal("expected generated UUID for block")
	}

	// 2. Duplicate block name in same RT fails
	_, err = svc.CreateBlock(ctx, &Block{
		RTID: "rt-01",
		Name: "Blok Melati",
	})
	if err == nil || err != ErrDuplicateBlock {
		t.Fatalf("expected ErrDuplicateBlock, got %v", err)
	}

	// 3. List blocks
	list, err := svc.ListBlocks(ctx, "rt-01")
	if err != nil || len(list) != 1 {
		t.Fatalf("expected 1 block, got %d", len(list))
	}
}

func TestVolunteerRegistrationAndAvailability(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	// 1. Register volunteer with skills (FR-VOL-02)
	v, err := svc.RegisterVolunteer(ctx, &Volunteer{
		UserID: "user-relawan-1",
		RTID:   "rt-01",
		Skills: []string{"P3K", "evakuasi"},
	})
	if err != nil {
		t.Fatalf("register volunteer failed: %v", err)
	}
	if !v.Available {
		t.Fatal("expected default availability true")
	}

	// 2. Toggle availability (siap / tidak tersedia per FR-VOL-03)
	err = svc.SetAvailability(ctx, v.UserID, false)
	if err != nil {
		t.Fatalf("set availability failed: %v", err)
	}

	retrieved, err := svc.GetVolunteer(ctx, v.UserID)
	if err != nil {
		t.Fatalf("get volunteer failed: %v", err)
	}
	if retrieved.Available {
		t.Fatal("expected availability to be false")
	}

	err = svc.SetAvailability(ctx, v.UserID, true)
	if err != nil {
		t.Fatalf("set availability back to true failed: %v", err)
	}
	retrieved, _ = svc.GetVolunteer(ctx, v.UserID)
	if !retrieved.Available {
		t.Fatal("expected availability to be true")
	}
}

func TestVolunteerBlockScopingAndTaskClaiming(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	blockA := "block-id-A"
	blockB := "block-id-B"

	// Register volunteer assigned only to Block A
	v, err := svc.RegisterVolunteer(ctx, &Volunteer{
		UserID:         "user-relawan-A",
		RTID:           "rt-01",
		Skills:         []string{"P3K"},
		AssignedBlocks: []string{blockA},
	})
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	// 1. Volunteer CAN access and claim tasks in Block A
	canAccessA, err := svc.CanVolunteerAccessBlock(ctx, v.UserID, blockA)
	if err != nil || !canAccessA {
		t.Fatalf("expected volunteer to have access to block A, got %v", canAccessA)
	}
	canClaimA, err := svc.CanVolunteerClaimTask(ctx, v.UserID, blockA)
	if err != nil || !canClaimA {
		t.Fatalf("expected volunteer to claim task in block A, got %v", canClaimA)
	}

	// 2. Volunteer CANNOT access or claim tasks in Block B (Scope enforcement)
	canAccessB, err := svc.CanVolunteerAccessBlock(ctx, v.UserID, blockB)
	if err != nil || canAccessB {
		t.Fatalf("expected volunteer to NOT have access to block B, got %v", canAccessB)
	}
	canClaimB, err := svc.CanVolunteerClaimTask(ctx, v.UserID, blockB)
	if err == nil || err != ErrTaskBlockUnauthorized || canClaimB {
		t.Fatalf("expected ErrTaskBlockUnauthorized when claiming task in block B, got err=%v", err)
	}
}
