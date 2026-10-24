package whatsapp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Client abstracts message delivery to WhatsApp Cloud API (FR-WA-01).
type Client interface {
	SendTemplate(ctx context.Context, to string, req SendTemplateRequest) (string, error)
	SendText(ctx context.Context, to string, text string) (string, error)
	SendInteractiveButtons(ctx context.Context, to string, bodyText string, buttons []InteractiveButton) (string, error)
	SendInteractiveList(ctx context.Context, to string, headerText, bodyText, buttonText string, sections []ListSection) (string, error)
	SendDocument(ctx context.Context, to string, documentURL, filename, caption string) (string, error)
}

// MetaCloudClient calls Meta WhatsApp Cloud API via Graph API v21.0.
type MetaCloudClient struct {
	phoneNumberID string
	accessToken   string
	httpClient    *http.Client
}

func NewMetaCloudClient(phoneNumberID, accessToken string) *MetaCloudClient {
	return &MetaCloudClient{
		phoneNumberID: phoneNumberID,
		accessToken:   accessToken,
		httpClient:    &http.Client{Timeout: 15 * time.Second},
	}
}

func (c *MetaCloudClient) postMessage(ctx context.Context, payload any) (string, error) {
	if c.phoneNumberID == "" || c.accessToken == "" {
		return "", fmt.Errorf("whatsapp cloud api credentials not configured")
	}

	url := fmt.Sprintf("https://graph.facebook.com/v21.0/%s/messages", c.phoneNumberID)
	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create http request: %w", err)
	}

	// Token is NEVER logged
	req.Header.Set("Authorization", "Bearer "+c.accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("meta whatsapp cloud api request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("meta whatsapp cloud api returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var metaRes struct {
		Messages []struct {
			ID string `json:"id"`
		} `json:"messages"`
	}
	if err := json.Unmarshal(respBody, &metaRes); err == nil && len(metaRes.Messages) > 0 {
		return metaRes.Messages[0].ID, nil
	}

	return fmt.Sprintf("wamid.UNKNOWN_%s", uuid.NewString()[:8]), nil
}

func (c *MetaCloudClient) SendTemplate(ctx context.Context, to string, req SendTemplateRequest) (string, error) {
	req.MessagingProduct = "whatsapp"
	req.RecipientType = "individual"
	req.To = to
	req.Type = "template"
	return c.postMessage(ctx, req)
}

func (c *MetaCloudClient) SendText(ctx context.Context, to string, text string) (string, error) {
	payload := map[string]any{
		"messaging_product": "whatsapp",
		"recipient_type":    "individual",
		"to":                to,
		"type":              "text",
		"text": map[string]string{
			"body": text,
		},
	}
	return c.postMessage(ctx, payload)
}

func (c *MetaCloudClient) SendInteractiveButtons(ctx context.Context, to string, bodyText string, buttons []InteractiveButton) (string, error) {
	var buttonItems []map[string]any
	for _, b := range buttons {
		buttonItems = append(buttonItems, map[string]any{
			"type": "reply",
			"reply": map[string]string{
				"id":    b.ID,
				"title": b.Title,
			},
		})
	}

	payload := map[string]any{
		"messaging_product": "whatsapp",
		"recipient_type":    "individual",
		"to":                to,
		"type":              "interactive",
		"interactive": map[string]any{
			"type": "button",
			"body": map[string]string{
				"text": bodyText,
			},
			"action": map[string]any{
				"buttons": buttonItems,
			},
		},
	}
	return c.postMessage(ctx, payload)
}

func (c *MetaCloudClient) SendInteractiveList(ctx context.Context, to string, headerText, bodyText, buttonText string, sections []ListSection) (string, error) {
	payload := map[string]any{
		"messaging_product": "whatsapp",
		"recipient_type":    "individual",
		"to":                to,
		"type":              "interactive",
		"interactive": map[string]any{
			"type": "list",
			"header": map[string]string{
				"type": "text",
				"text": headerText,
			},
			"body": map[string]string{
				"text": bodyText,
			},
			"action": map[string]any{
				"button":   buttonText,
				"sections": sections,
			},
		},
	}
	return c.postMessage(ctx, payload)
}

func (c *MetaCloudClient) SendDocument(ctx context.Context, to string, documentURL, filename, caption string) (string, error) {
	payload := map[string]any{
		"messaging_product": "whatsapp",
		"recipient_type":    "individual",
		"to":                to,
		"type":              "document",
		"document": map[string]string{
			"link":     documentURL,
			"filename": filename,
			"caption":  caption,
		},
	}
	return c.postMessage(ctx, payload)
}

// SimulatedClient records all outbound communications in memory for testing and local development.
type SimulatedClient struct {
	mu           sync.Mutex
	SentMessages []SentMessageRecord
	ShouldFail   bool
}

type SentMessageRecord struct {
	Type        string
	To          string
	TemplateReq *SendTemplateRequest
	Text        string
	Buttons     []InteractiveButton
	ListSections []ListSection
	DocumentURL string
	Filename    string
	ProviderID  string
	SentAt      time.Time
}

func NewSimulatedClient() *SimulatedClient {
	return &SimulatedClient{
		SentMessages: make([]SentMessageRecord, 0),
	}
}

func (s *SimulatedClient) record(rec SentMessageRecord) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.ShouldFail {
		return "", fmt.Errorf("simulated whatsapp provider failure")
	}

	rec.ProviderID = fmt.Sprintf("wamid.SIM_%s", uuid.NewString()[:8])
	rec.SentAt = time.Now().UTC()
	s.SentMessages = append(s.SentMessages, rec)
	return rec.ProviderID, nil
}

func (s *SimulatedClient) SendTemplate(ctx context.Context, to string, req SendTemplateRequest) (string, error) {
	reqCopy := req
	return s.record(SentMessageRecord{
		Type:        "template",
		To:          to,
		TemplateReq: &reqCopy,
	})
}

func (s *SimulatedClient) SendText(ctx context.Context, to string, text string) (string, error) {
	return s.record(SentMessageRecord{
		Type: "text",
		To:   to,
		Text: text,
	})
}

func (s *SimulatedClient) SendInteractiveButtons(ctx context.Context, to string, bodyText string, buttons []InteractiveButton) (string, error) {
	return s.record(SentMessageRecord{
		Type:    "interactive_buttons",
		To:      to,
		Text:    bodyText,
		Buttons: buttons,
	})
}

func (s *SimulatedClient) SendInteractiveList(ctx context.Context, to string, headerText, bodyText, buttonText string, sections []ListSection) (string, error) {
	return s.record(SentMessageRecord{
		Type:         "interactive_list",
		To:           to,
		Text:         bodyText,
		ListSections: sections,
	})
}

func (s *SimulatedClient) SendDocument(ctx context.Context, to string, documentURL, filename, caption string) (string, error) {
	return s.record(SentMessageRecord{
		Type:        "document",
		To:          to,
		Text:        caption,
		DocumentURL: documentURL,
		Filename:    filename,
	})
}

func (s *SimulatedClient) GetSentMessages() []SentMessageRecord {
	s.mu.Lock()
	defer s.mu.Unlock()
	copied := make([]SentMessageRecord, len(s.SentMessages))
	copy(copied, s.SentMessages)
	return copied
}

func (s *SimulatedClient) LastSentMessage(to string) *SentMessageRecord {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i := len(s.SentMessages) - 1; i >= 0; i-- {
		if s.SentMessages[i].To == to {
			rec := s.SentMessages[i]
			return &rec
		}
	}
	return nil
}
