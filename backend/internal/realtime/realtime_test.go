package realtime

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
)

type dummyIncidentChecker struct {
	incidents map[string]string // incidentID -> rtID
}

func (d *dummyIncidentChecker) GetIncidentRTID(ctx context.Context, incidentID string) (string, error) {
	if rt, ok := d.incidents[incidentID]; ok {
		return rt, nil
	}
	return "", auth.ErrInvalidToken
}

type dummyHierarchyChecker struct{}

func (d *dummyHierarchyChecker) IsRTInRegion(ctx context.Context, regionID, rtID string) (bool, error) {
	return regionID == "kelurahan-01", nil
}

func TestWebSocketAuthenticationAndScopeIsolation(t *testing.T) {
	jwtSecret := []byte("test-realtime-jwt-secret-key-32b")
	store := NewMemoryEventStore()
	hub := NewHub(store)
	incidentChecker := &dummyIncidentChecker{
		incidents: map[string]string{
			"inc-rt1": "rt-01",
			"inc-rt2": "rt-02",
		},
	}
	h := NewHandler(hub, jwtSecret, &dummyHierarchyChecker{}, incidentChecker)

	r := chi.NewRouter()
	h.Routes(r)

	server := httptest.NewServer(r)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"

	// 1. Missing token -> 401 Unauthorized
	_, resp, err := websocket.DefaultDialer.Dial(wsURL+"?incident=inc-rt1", nil)
	if err == nil || resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing token, got: %v (resp: %v)", err, resp)
	}

	// 2. Token from RT 01 trying to access incident in RT 02 -> 403 Forbidden
	tokenRT1, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "user-rt1",
		Role:     "pengurus",
		RegionID: "rt-01",
	})

	_, resp, err = websocket.DefaultDialer.Dial(wsURL+"?incident=inc-rt2&token="+tokenRT1, nil)
	if err == nil || resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for cross-RT scope violation, got: %v (resp: %v)", err, resp)
	}

	// 3. Token from RT 01 accessing incident in RT 01 -> 200/101 Switching Protocols
	conn, resp, err := websocket.DefaultDialer.Dial(wsURL+"?incident=inc-rt1&token="+tokenRT1, nil)
	if err != nil {
		t.Fatalf("dial failed for authorized client: %v", err)
	}
	defer conn.Close()
	if resp.StatusCode != http.StatusSwitchingProtocols {
		t.Fatalf("expected 101 switching protocols, got %d", resp.StatusCode)
	}
}

func TestBroadcastAndLatencyMeasurement(t *testing.T) {
	jwtSecret := []byte("test-realtime-jwt-secret-key-32b")
	store := NewMemoryEventStore()
	hub := NewHub(store)
	incidentChecker := &dummyIncidentChecker{
		incidents: map[string]string{
			"inc-latency": "rt-latency-1",
		},
	}
	h := NewHandler(hub, jwtSecret, &dummyHierarchyChecker{}, incidentChecker)

	r := chi.NewRouter()
	h.Routes(r)

	server := httptest.NewServer(r)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"

	token, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "pengurus-latency",
		Role:     "pengurus",
		RegionID: "rt-latency-1",
	})

	conn, _, err := websocket.DefaultDialer.Dial(wsURL+"?incident=inc-latency&token="+token, nil)
	if err != nil {
		t.Fatalf("dial failed: %v", err)
	}
	defer conn.Close()

	// Measure delivery latency
	startBroadcast := time.Now()
	testEvent := &Event{
		Entity:   "household",
		EntityID: "hh-1",
		Op:       "UPDATE",
		Payload: map[string]any{
			"status": 3,
			"urgency": 2,
		},
		Origin: "cloud",
	}

	if err := hub.BroadcastEvent(context.Background(), "inc-latency", testEvent); err != nil {
		t.Fatalf("broadcast failed: %v", err)
	}

	var received Event
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	if err := conn.ReadJSON(&received); err != nil {
		t.Fatalf("failed to read broadcast event: %v", err)
	}
	latency := time.Since(startBroadcast)

	t.Logf("MEASURED REAL-TIME WEBSOCKET LATENCY: %v (Target: <= 3000ms)", latency)

	if latency > 3*time.Second {
		t.Fatalf("latency exceeded 3s target: %v", latency)
	}
	if received.Entity != "household" || received.Payload["status"].(float64) != 3 {
		t.Fatalf("unexpected received event payload: %+v", received)
	}
}

func TestEventRecoveryWithLastEventID(t *testing.T) {
	jwtSecret := []byte("test-realtime-jwt-secret-key-32b")
	store := NewMemoryEventStore()
	hub := NewHub(store)
	incidentChecker := &dummyIncidentChecker{
		incidents: map[string]string{
			"inc-recovery": "rt-recovery-1",
		},
	}
	h := NewHandler(hub, jwtSecret, &dummyHierarchyChecker{}, incidentChecker)

	// Pre-populate store with 3 historical events
	_ = hub.BroadcastEvent(context.Background(), "inc-recovery", &Event{
		Entity:   "household",
		EntityID: "hh-1",
		Op:       "CREATE",
		Payload:  map[string]any{"seq": 1},
		Origin:   "cloud",
	})
	_ = hub.BroadcastEvent(context.Background(), "inc-recovery", &Event{
		Entity:   "household",
		EntityID: "hh-1",
		Op:       "UPDATE",
		Payload:  map[string]any{"seq": 2},
		Origin:   "cloud",
	})
	_ = hub.BroadcastEvent(context.Background(), "inc-recovery", &Event{
		Entity:   "household",
		EntityID: "hh-1",
		Op:       "UPDATE",
		Payload:  map[string]any{"seq": 3},
		Origin:   "cloud",
	})

	r := chi.NewRouter()
	h.Routes(r)

	server := httptest.NewServer(r)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws"

	token, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "warga-recovery",
		Role:     "warga",
		RegionID: "rt-recovery-1",
	})

	// Reconnect specifying last_event_id=1 -> should receive events 2 and 3
	conn, _, err := websocket.DefaultDialer.Dial(wsURL+"?incident=inc-recovery&token="+token+"&last_event_id=1", nil)
	if err != nil {
		t.Fatalf("dial failed: %v", err)
	}
	defer conn.Close()

	var ev2 Event
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	if err := conn.ReadJSON(&ev2); err != nil {
		t.Fatalf("failed to read missed event 2: %v", err)
	}
	if ev2.ID != 2 {
		t.Fatalf("expected event ID 2, got: %d", ev2.ID)
	}

	var ev3 Event
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	if err := conn.ReadJSON(&ev3); err != nil {
		t.Fatalf("failed to read missed event 3: %v", err)
	}
	if ev3.ID != 3 {
		t.Fatalf("expected event ID 3, got: %d", ev3.ID)
	}
}
