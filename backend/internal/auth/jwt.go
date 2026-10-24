package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("token akses tidak valid atau sudah kedaluwarsa")
)

const (
	AccessTokenDuration  = 15 * time.Minute
	RefreshTokenDuration = 30 * 24 * time.Hour // 30 days
)

// Claims represents the JWT payload claims for WE-IRED users.
type Claims struct {
	UserID      string `json:"user_id"`
	Phone       string `json:"phone"`
	Role        string `json:"role"`
	RegionID    string `json:"region_id"`
	HouseholdID string `json:"household_id,omitempty"`
	jwt.RegisteredClaims
}

// GenerateAccessToken signs a new 15-minute JWT access token.
func GenerateAccessToken(secret []byte, claims Claims) (string, time.Time, error) {
	now := time.Now().UTC()
	expiresAt := now.Add(AccessTokenDuration)

	claims.IssuedAt = jwt.NewNumericDate(now)
	claims.ExpiresAt = jwt.NewNumericDate(expiresAt)

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("failed to sign access token: %w", err)
	}

	return tokenString, expiresAt, nil
}

// ValidateAccessToken parses and validates an HMAC-SHA256 JWT access token.
func ValidateAccessToken(secret []byte, tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return secret, nil
	})

	if err != nil {
		return nil, ErrInvalidToken
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, ErrInvalidToken
}

// GenerateRefreshToken generates a secure 32-byte random refresh token and its SHA-256 hash.
func GenerateRefreshToken() (rawToken string, tokenHash string, expiresAt time.Time, err error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", "", time.Time{}, fmt.Errorf("failed to generate random token: %w", err)
	}

	rawToken = hex.EncodeToString(bytes)
	hash := sha256.Sum256([]byte(rawToken))
	tokenHash = hex.EncodeToString(hash[:])
	expiresAt = time.Now().UTC().Add(RefreshTokenDuration)

	return rawToken, tokenHash, expiresAt, nil
}

// HashRefreshToken hashes a raw refresh token using SHA-256 for lookup.
func HashRefreshToken(rawToken string) string {
	hash := sha256.Sum256([]byte(rawToken))
	return hex.EncodeToString(hash[:])
}
