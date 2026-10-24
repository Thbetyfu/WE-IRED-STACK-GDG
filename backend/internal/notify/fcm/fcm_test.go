package fcm

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestFCMTopicScopingAndPayloadPriorities(t *testing.T) {
	ctx := context.Background()
	sim := NewSimulatedClient()
	svc := NewService(sim, nil)

	rtID := "rt-005"

	// 1. Send RT Announcement (normal for info, high for darurat)
	_, err := svc.SendRTAnnouncement(ctx, rtID, "ann-1", "info", "Kerja bakti", "sig-123")
	if err != nil {
		t.Fatalf("send info announcement failed: %v", err)
	}

	_, err = svc.SendRTAnnouncement(ctx, rtID, "ann-2", "darurat", "BAHAYA BANJIR", "sig-456")
	if err != nil {
		t.Fatalf("send darurat announcement failed: %v", err)
	}

	// 2. Send Incident Activation (MUST be high priority per SDD 10.2)
	_, err = svc.SendIncidentActivation(ctx, rtID, "inc-100", "BANJIR", "nyata", 44001, "Aktivasi tanggap darurat banjir")
	if err != nil {
		t.Fatalf("send incident activation failed: %v", err)
	}

	// 3. Send Volunteer Task Assignment (MUST be high priority per SDD 10.2)
	_, err = svc.SendVolunteerTaskAssignment(ctx, "vol-007", "task-88", "inc-100", "hh-99", 78.5)
	if err != nil {
		t.Fatalf("send volunteer task assignment failed: %v", err)
	}

	// Verify all sent messages
	if sim.GetSentCount() != 4 {
		t.Fatalf("expected 4 sent messages, got: %d", sim.GetSentCount())
	}

	// Check Topic Scoping
	m0 := sim.SentMessages[0]
	if m0.Recipient != "rt_rt-005" || m0.Message.Priority != PriorityNormal {
		t.Fatalf("unexpected message 0: %+v", m0)
	}

	m1 := sim.SentMessages[1]
	if m1.Recipient != "rt_rt-005" || m1.Message.Priority != PriorityHigh {
		t.Fatalf("unexpected message 1 (darurat should be high priority): %+v", m1)
	}

	m2 := sim.SentMessages[2]
	if m2.Recipient != "rt_rt-005" || m2.Message.Priority != PriorityHigh {
		t.Fatalf("incident activation MUST have high priority: %+v", m2)
	}
	if m2.Message.Data["type"] != "incident_activation" || m2.Message.Data["incident_id"] != "inc-100" {
		t.Fatalf("incident activation data missing fields: %+v", m2.Message.Data)
	}

	m3 := sim.SentMessages[3]
	if m3.Recipient != "volunteer_vol-007" || m3.Message.Priority != PriorityHigh {
		t.Fatalf("volunteer task assignment MUST have high priority: %+v", m3)
	}
	if m3.Message.Data["type"] != "task_assigned" || m3.Message.Data["task_id"] != "task-88" {
		t.Fatalf("task assigned data missing fields: %+v", m3.Message.Data)
	}
}

func TestFCMFailureDiagnosisAndErrorTracking(t *testing.T) {
	ctx := context.Background()
	sim := NewSimulatedClient()
	sim.SimulateErr = errors.New("FCM server response 503 Service Unavailable")
	svc := NewService(sim, nil)

	// Sending must not report success when provider fails
	res, err := svc.SendIncidentActivation(ctx, "rt-001", "inc-1", "GEMPA", "nyata", 555, "Gempa bumi")
	if err == nil {
		t.Fatal("expected error on simulated FCM failure")
	}
	if res.Success {
		t.Fatal("SendResult.Success must be false on provider failure")
	}
	if !strings.Contains(err.Error(), "503 Service Unavailable") {
		t.Fatalf("expected diagnostic detail in error, got: %v", err)
	}
}
