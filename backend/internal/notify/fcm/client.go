package fcm

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"time"
)

var (
	ErrEmptyTopic      = errors.New("topik FCM tidak boleh kosong")
	ErrEmptyPayload    = errors.New("payload data FCM tidak boleh kosong")
	ErrDeliveryFailed  = errors.New("pengiriman notifikasi FCM gagal ke provider")
	ErrInvalidPriority = errors.New("prioritas FCM harus 'high' atau 'normal'")
)

const (
	PriorityHigh   = "high"
	PriorityNormal = "normal"
)

// Message holds the notification and data payload per SDD 10.2.
type Message struct {
	Title    string            `json:"title"`
	Body     string            `json:"body"`
	Priority string            `json:"priority"` // "high" (activation/tasks) | "normal"
	Data     map[string]string `json:"data"`
	TTL      time.Duration     `json:"ttl"`
}

// SendResult records delivery attempt details for diagnostic tracking.
type SendResult struct {
	MessageID   string    `json:"message_id"`
	Recipient   string    `json:"recipient"` // topic or token
	Success     bool      `json:"success"`
	Error       string    `json:"error,omitempty"`
	AttemptedAt time.Time `json:"attempted_at"`
}

// Client defines the contract for sending FCM notifications.
type Client interface {
	SendToTopic(ctx context.Context, topic string, msg *Message) (*SendResult, error)
	SendToDevice(ctx context.Context, token string, msg *Message) (*SendResult, error)
}

// Service wraps the FCM Client with topic isolation, payload validation, and failure logging.
type Service struct {
	client Client
	logger *slog.Logger
}

func NewService(client Client, logger *slog.Logger) *Service {
	if logger == nil {
		logger = slog.Default()
	}
	return &Service{
		client: client,
		logger: logger,
	}
}

// SendRTAnnouncement sends an announcement notification to the RT's topic `rt_{rtID}` (SDD 10.2).
func (s *Service) SendRTAnnouncement(ctx context.Context, rtID string, annID string, level string, text string, sig string) (*SendResult, error) {
	if rtID == "" {
		return nil, ErrEmptyTopic
	}

	priority := PriorityNormal
	if level == "darurat" {
		priority = PriorityHigh
	}

	topic := fmt.Sprintf("rt_%s", rtID)
	msg := &Message{
		Title:    fmt.Sprintf("Pengumuman %s RT", level),
		Body:     text,
		Priority: priority,
		Data: map[string]string{
			"type":            "announcement",
			"announcement_id": annID,
			"level":           level,
			"text":            text,
			"signature":       sig,
			"rt_id":           rtID,
		},
		TTL: 24 * time.Hour,
	}

	res, err := s.client.SendToTopic(ctx, topic, msg)
	if err != nil || (res != nil && !res.Success) {
		errDetail := ""
		if err != nil {
			errDetail = err.Error()
		} else if res != nil {
			errDetail = res.Error
		}
		s.logger.Error("FCM announcement delivery failed",
			"rt_id", rtID,
			"topic", topic,
			"announcement_id", annID,
			"error", errDetail,
		)
		if err != nil {
			return res, err
		}
		return res, fmt.Errorf("%w: %s", ErrDeliveryFailed, errDetail)
	}

	s.logger.Info("FCM announcement sent successfully",
		"topic", topic,
		"announcement_id", annID,
		"message_id", res.MessageID,
	)
	return res, nil
}

// SendIncidentActivation sends a HIGH PRIORITY activation payload to `rt_{rtID}`.
func (s *Service) SendIncidentActivation(ctx context.Context, rtID string, incidentID string, hazard string, mode string, shortID uint32, message string) (*SendResult, error) {
	if rtID == "" {
		return nil, ErrEmptyTopic
	}

	topic := fmt.Sprintf("rt_%s", rtID)
	msg := &Message{
		Title:    fmt.Sprintf("SIAGA BENCANA: %s", hazard),
		Body:     message,
		Priority: PriorityHigh, // MUST be high priority per SDD 10.2
		Data: map[string]string{
			"type":              "incident_activation",
			"incident_id":       incidentID,
			"hazard":            hazard,
			"mode":              mode,
			"incident_short_id": fmt.Sprintf("%d", shortID),
			"rt_id":             rtID,
			"action":            "open_report_screen",
		},
		TTL: 12 * time.Hour,
	}

	res, err := s.client.SendToTopic(ctx, topic, msg)
	if err != nil || (res != nil && !res.Success) {
		errDetail := ""
		if err != nil {
			errDetail = err.Error()
		} else if res != nil {
			errDetail = res.Error
		}
		s.logger.Error("FCM incident activation delivery failed",
			"rt_id", rtID,
			"topic", topic,
			"incident_id", incidentID,
			"error", errDetail,
		)
		if err != nil {
			return res, err
		}
		return res, fmt.Errorf("%w: %s", ErrDeliveryFailed, errDetail)
	}

	s.logger.Info("FCM incident activation delivered",
		"topic", topic,
		"incident_id", incidentID,
		"message_id", res.MessageID,
	)
	return res, nil
}

// SendVolunteerTaskAssignment sends a HIGH PRIORITY assignment notification to a volunteer device or volunteer topic.
func (s *Service) SendVolunteerTaskAssignment(ctx context.Context, volunteerID string, taskID string, incidentID string, householdID string, priorityScore float64) (*SendResult, error) {
	topic := fmt.Sprintf("volunteer_%s", volunteerID)
	msg := &Message{
		Title:    "Tugas Evakuasi/Bantuan Baru",
		Body:     fmt.Sprintf("Anda ditugaskan mendatangi rumah warga (Prioritas: %.1f). Segera konfirmasi penerimaan tugas.", priorityScore),
		Priority: PriorityHigh, // High priority per SDD 10.2
		Data: map[string]string{
			"type":           "task_assigned",
			"task_id":        taskID,
			"incident_id":    incidentID,
			"household_id":   householdID,
			"volunteer_id":   volunteerID,
			"priority_score": fmt.Sprintf("%.1f", priorityScore),
			"action":         "open_task_screen",
		},
		TTL: 1 * time.Hour,
	}

	res, err := s.client.SendToTopic(ctx, topic, msg)
	if err != nil || (res != nil && !res.Success) {
		errDetail := ""
		if err != nil {
			errDetail = err.Error()
		} else if res != nil {
			errDetail = res.Error
		}
		s.logger.Error("FCM volunteer task assignment delivery failed",
			"volunteer_id", volunteerID,
			"task_id", taskID,
			"error", errDetail,
		)
		if err != nil {
			return res, err
		}
		return res, fmt.Errorf("%w: %s", ErrDeliveryFailed, errDetail)
	}

	return res, nil
}

// SimulatedClient is an in-memory client for unit testing and local development.
type SimulatedClient struct {
	mu           sync.Mutex
	SentMessages []*SentRecord
	SimulateErr  error
}

type SentRecord struct {
	Recipient string
	Message   *Message
	SentAt    time.Time
}

func NewSimulatedClient() *SimulatedClient {
	return &SimulatedClient{
		SentMessages: make([]*SentRecord, 0),
	}
}

func (c *SimulatedClient) SendToTopic(ctx context.Context, topic string, msg *Message) (*SendResult, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.SimulateErr != nil {
		return &SendResult{
			Recipient:   topic,
			Success:     false,
			Error:       c.SimulateErr.Error(),
			AttemptedAt: time.Now().UTC(),
		}, c.SimulateErr
	}

	msgID := fmt.Sprintf("projects/we-ired/messages/sim-%d", time.Now().UnixNano())
	c.SentMessages = append(c.SentMessages, &SentRecord{
		Recipient: topic,
		Message:   msg,
		SentAt:    time.Now().UTC(),
	})

	return &SendResult{
		MessageID:   msgID,
		Recipient:   topic,
		Success:     true,
		AttemptedAt: time.Now().UTC(),
	}, nil
}

func (c *SimulatedClient) SendToDevice(ctx context.Context, token string, msg *Message) (*SendResult, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.SimulateErr != nil {
		return &SendResult{
			Recipient:   token,
			Success:     false,
			Error:       c.SimulateErr.Error(),
			AttemptedAt: time.Now().UTC(),
		}, c.SimulateErr
	}

	msgID := fmt.Sprintf("projects/we-ired/messages/token-%d", time.Now().UnixNano())
	c.SentMessages = append(c.SentMessages, &SentRecord{
		Recipient: token,
		Message:   msg,
		SentAt:    time.Now().UTC(),
	})

	return &SendResult{
		MessageID:   msgID,
		Recipient:   token,
		Success:     true,
		AttemptedAt: time.Now().UTC(),
	}, nil
}

func (c *SimulatedClient) GetSentCount() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.SentMessages)
}
