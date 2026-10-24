package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// WhatsAppOTPProvider defines the contract for sending OTP messages via WhatsApp (SDD 10.1, FR-WA-01).
type WhatsAppOTPProvider interface {
	SendOTP(ctx context.Context, phone string, code string, expiresInSeconds int) error
}

// MetaCloudWhatsAppProvider implements WhatsAppOTPProvider calling Meta WhatsApp Cloud API (Graph API).
type MetaCloudWhatsAppProvider struct {
	phoneNumberID string
	accessToken   string
	httpClient    *http.Client
}

func NewMetaCloudWhatsAppProvider(phoneNumberID, accessToken string) *MetaCloudWhatsAppProvider {
	return &MetaCloudWhatsAppProvider{
		phoneNumberID: phoneNumberID,
		accessToken:   accessToken,
		httpClient:    &http.Client{Timeout: 10 * time.Second},
	}
}

func (p *MetaCloudWhatsAppProvider) SendOTP(ctx context.Context, phone string, code string, expiresInSeconds int) error {
	if p.phoneNumberID == "" || p.accessToken == "" {
		return fmt.Errorf("whatsapp cloud api credentials not configured")
	}

	url := fmt.Sprintf("https://graph.facebook.com/v21.0/%s/messages", p.phoneNumberID)

	// Format per SDD 10.1 Template: otp_login (Category: Authentication)
	payload := map[string]interface{}{
		"messaging_product": "whatsapp",
		"recipient_type":    "individual",
		"to":                phone,
		"type":              "template",
		"template": map[string]interface{}{
			"name": "otp_login",
			"language": map[string]string{
				"code": "id",
			},
			"components": []map[string]interface{}{
				{
					"type": "body",
					"parameters": []map[string]interface{}{
						{
							"type": "text",
							"text": code,
						},
					},
				},
				{
					"type":     "button",
					"sub_type": "url",
					"index":    "0",
					"parameters": []map[string]interface{}{
						{
							"type": "text",
							"text": code,
						},
					},
				},
			},
		},
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return err
	}

	req.Header.Set("Authorization", "Bearer "+p.accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to call meta whatsapp api: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("meta whatsapp api returned status %d", resp.StatusCode)
	}

	return nil
}

// SimulatedWhatsAppProvider is an in-memory test provider used for unit & integration testing.
type SimulatedWhatsAppProvider struct {
	mu           sync.Mutex
	SentMessages []SentOTPMessage
	ShouldFail   bool
}

type SentOTPMessage struct {
	Phone            string
	Code             string
	ExpiresInSeconds int
	SentAt           time.Time
}

func NewSimulatedWhatsAppProvider() *SimulatedWhatsAppProvider {
	return &SimulatedWhatsAppProvider{
		SentMessages: make([]SentOTPMessage, 0),
	}
}

func (p *SimulatedWhatsAppProvider) SendOTP(ctx context.Context, phone string, code string, expiresInSeconds int) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.ShouldFail {
		return fmt.Errorf("simulated whatsapp provider failure")
	}

	p.SentMessages = append(p.SentMessages, SentOTPMessage{
		Phone:            phone,
		Code:             code,
		ExpiresInSeconds: expiresInSeconds,
		SentAt:           time.Now().UTC(),
	})

	return nil
}

func (p *SimulatedWhatsAppProvider) LastSentCode(phone string) string {
	p.mu.Lock()
	defer p.mu.Unlock()

	for i := len(p.SentMessages) - 1; i >= 0; i-- {
		if p.SentMessages[i].Phone == phone {
			return p.SentMessages[i].Code
		}
	}
	return ""
}
