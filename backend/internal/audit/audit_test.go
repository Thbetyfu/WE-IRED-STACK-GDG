package audit_test

import (
	"context"
	"testing"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/audit"
)

func TestAuditService(t *testing.T) {
	ctx := context.Background()
	store := audit.NewMemoryStore()
	svc := audit.NewService(store)

	rtID := "rt-01"
	err := svc.Log(ctx, rtID, "user-01", audit.ActionAccessVulnerableData, "household", "hh-01", map[string]any{
		"reason": "evakuasi darurat",
	}, "127.0.0.1", "curl/8.0")
	if err != nil {
		t.Fatalf("Log failed: %v", err)
	}

	time.Sleep(5 * time.Millisecond)

	err = svc.Log(ctx, rtID, "user-02", audit.ActionExportRecapPDF, "recap", "rcp-01", map[string]any{
		"pages": 2,
	}, "127.0.0.1", "Mozilla/5.0")
	if err != nil {
		t.Fatalf("Log failed: %v", err)
	}

	// List logs
	logs, total, err := svc.ListByRegion(ctx, rtID, 10, 0)
	if err != nil {
		t.Fatalf("ListByRegion failed: %v", err)
	}

	if total != 2 || len(logs) != 2 {
		t.Errorf("expected 2 audit logs, got total=%d len=%d", total, len(logs))
	}

	// Check order (latest first)
	if logs[0].Action != audit.ActionExportRecapPDF {
		t.Errorf("expected latest action %s, got %s", audit.ActionExportRecapPDF, logs[0].Action)
	}
	if logs[1].Action != audit.ActionAccessVulnerableData {
		t.Errorf("expected earlier action %s, got %s", audit.ActionAccessVulnerableData, logs[1].Action)
	}
}
