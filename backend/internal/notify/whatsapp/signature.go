package whatsapp

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// ValidateWebhookSignature checks whether the X-Hub-Signature-256 matches HMAC-SHA256(secret, bodyBytes).
func ValidateWebhookSignature(appSecret string, bodyBytes []byte, signatureHeader string) bool {
	if appSecret == "" || signatureHeader == "" {
		return false
	}

	parts := strings.SplitN(signatureHeader, "=", 2)
	if len(parts) != 2 || parts[0] != "sha256" {
		return false
	}

	expectedMAC, err := hex.DecodeString(parts[1])
	if err != nil {
		return false
	}

	mac := hmac.New(sha256.New, []byte(appSecret))
	mac.Write(bodyBytes)
	calculatedMAC := mac.Sum(nil)

	return hmac.Equal(expectedMAC, calculatedMAC)
}
