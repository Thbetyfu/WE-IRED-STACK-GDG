package auth

import (
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"time"
)

const (
	OTPDuration        = 5 * time.Minute
	OTPRateLimitWindow = 15 * time.Minute
	OTPMaxAttempts     = 5
)

var (
	ErrOTPRateLimited = errors.New("terlalu banyak permintaan OTP. Silakan tunggu 15 menit.")
	ErrOTPExpired     = errors.New("kode OTP telah kedaluwarsa (berlaku 5 menit)")
	ErrOTPInvalid     = errors.New("kode OTP tidak sesuai")
	ErrOTPMaxAttempts = errors.New("batas percobaan verifikasi OTP terlampaui")
)

// GenerateNumericOTP generates a cryptographically secure numeric OTP string of given length (default 6).
func GenerateNumericOTP(length int) (string, error) {
	if length <= 0 {
		length = 6
	}

	maxVal := big.NewInt(1)
	for i := 0; i < length; i++ {
		maxVal.Mul(maxVal, big.NewInt(10))
	}

	n, err := rand.Int(rand.Reader, maxVal)
	if err != nil {
		return "", fmt.Errorf("failed to generate secure random number: %w", err)
	}

	format := fmt.Sprintf("%%0%dd", length)
	return fmt.Sprintf(format, n.Int64()), nil
}
