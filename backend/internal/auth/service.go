package auth

import (
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

var (
	ErrInvalidCredentials = errors.New("email atau kata sandi tidak sesuai")
	ErrAccountInactive    = errors.New("akun belum diaktifkan")
)

type AuthResult struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	User         UserDTO   `json:"user"`
	HouseholdKey string    `json:"household_key,omitempty"` // only on activation
}

type UserDTO struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Phone       string  `json:"phone"`
	Email       string  `json:"email,omitempty"`
	Role        string  `json:"role"`
	RegionID    string  `json:"region_id"`
	HouseholdID *string `json:"household_id,omitempty"`
}

type Service struct {
	store       Store
	jwtSecret   []byte
	dataKey     []byte // 32-byte AES key for encrypting household keys
	otpProvider WhatsAppOTPProvider
}

func NewService(store Store, jwtSecret []byte, dataKey []byte) *Service {
	return &Service{
		store:     store,
		jwtSecret: jwtSecret,
		dataKey:   dataKey,
	}
}

// SetOTPProvider configures the WhatsApp OTP provider.
func (s *Service) SetOTPProvider(provider WhatsAppOTPProvider) {
	s.otpProvider = provider
}

// LoginWithPassword authenticates an administrative user via Email & Argon2id Password (FR-AUTH-02).
func (s *Service) LoginWithPassword(ctx context.Context, email, password string) (*AuthResult, error) {
	u, err := s.store.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	valid, err := VerifyPasswordArgon2id(password, u.PasswordHash)
	if err != nil || !valid {
		return nil, ErrInvalidCredentials
	}

	memberships, err := s.store.GetMemberships(ctx, u.ID)
	if err != nil || len(memberships) == 0 {
		return nil, errors.New("pengguna tidak memiliki peran wilayah")
	}

	primaryMembership := memberships[0]

	claims := Claims{
		UserID:      u.ID,
		Phone:       u.Phone,
		Role:        primaryMembership.Role,
		RegionID:    primaryMembership.RegionID,
		HouseholdID: derefString(primaryMembership.HouseholdID),
	}

	accessToken, expiresAt, err := GenerateAccessToken(s.jwtSecret, claims)
	if err != nil {
		return nil, err
	}

	rawRefresh, tokenHash, refreshExpiresAt, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	if err := s.store.SaveRefreshToken(ctx, u.ID, tokenHash, refreshExpiresAt); err != nil {
		return nil, err
	}

	return &AuthResult{
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
		ExpiresAt:    expiresAt,
		User: UserDTO{
			ID:          u.ID,
			Name:        u.Name,
			Phone:       u.Phone,
			Email:       u.Email,
			Role:        primaryMembership.Role,
			RegionID:    primaryMembership.RegionID,
			HouseholdID: primaryMembership.HouseholdID,
		},
	}, nil
}

// RequestOTP generates and sends a 6-digit WhatsApp OTP with rate limiting (FR-AUTH-01, FR-AUTH-08).
func (s *Service) RequestOTP(ctx context.Context, phone string) (string, error) {
	count, err := s.store.GetRecentOTPCount(ctx, phone, OTPRateLimitWindow)
	if err != nil {
		return "", err
	}
	if count >= OTPMaxAttempts {
		return "", ErrOTPRateLimited
	}

	code, err := GenerateNumericOTP(6)
	if err != nil {
		return "", err
	}

	expiresAt := time.Now().Add(OTPDuration)
	if err := s.store.SaveOTP(ctx, phone, code, expiresAt); err != nil {
		return "", err
	}

	// Dispatch OTP through configured WhatsApp provider (FR-WA-01, SDD 10.1)
	if s.otpProvider != nil {
		if err := s.otpProvider.SendOTP(ctx, phone, code, int(OTPDuration.Seconds())); err != nil {
			return "", fmt.Errorf("failed to dispatch otp via whatsapp: %w", err)
		}
	}

	return code, nil
}

// VerifyOTP verifies an OTP and logs in the citizen or volunteer (FR-AUTH-01, FR-AUTH-08).
func (s *Service) VerifyOTP(ctx context.Context, phone, code string) (*AuthResult, error) {
	otp, err := s.store.GetLatestValidOTP(ctx, phone)
	if err != nil {
		return nil, ErrOTPInvalid
	}

	attempts, err := s.store.IncrementOTPAttempts(ctx, otp.ID)
	if err != nil {
		return nil, err
	}
	if attempts > OTPMaxAttempts {
		return nil, ErrOTPMaxAttempts
	}

	if otp.Code != code {
		return nil, ErrOTPInvalid
	}

	if err := s.store.ConsumeOTP(ctx, otp.ID); err != nil {
		return nil, err
	}

	// Retrieve user or create fallback for citizen
	u, err := s.store.GetUserByPhone(ctx, phone)
	if err != nil {
		// New citizen user
		u = &User{
			ID:        uuid.NewString(),
			Name:      "Warga",
			Phone:     phone,
			CreatedAt: time.Now(),
		}
		if err := s.store.CreateUser(ctx, u); err != nil {
			return nil, err
		}
	}

	memberships, err := s.store.GetMemberships(ctx, u.ID)
	role := "kepala_keluarga"
	regionID := ""
	var householdID *string

	if err == nil && len(memberships) > 0 {
		role = memberships[0].Role
		regionID = memberships[0].RegionID
		householdID = memberships[0].HouseholdID
	}

	claims := Claims{
		UserID:      u.ID,
		Phone:       u.Phone,
		Role:        role,
		RegionID:    regionID,
		HouseholdID: derefString(householdID),
	}

	accessToken, expiresAt, err := GenerateAccessToken(s.jwtSecret, claims)
	if err != nil {
		return nil, err
	}

	rawRefresh, tokenHash, refreshExpiresAt, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	if err := s.store.SaveRefreshToken(ctx, u.ID, tokenHash, refreshExpiresAt); err != nil {
		return nil, err
	}

	return &AuthResult{
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
		ExpiresAt:    expiresAt,
		User: UserDTO{
			ID:          u.ID,
			Name:        u.Name,
			Phone:       u.Phone,
			Email:       u.Email,
			Role:        role,
			RegionID:    regionID,
			HouseholdID: householdID,
		},
	}, nil
}

// ActivateAccount activates a household via single-use invite code + OTP, deriving a 32-byte household key (FR-AUTH-03, FR-AUTH-07).
func (s *Service) ActivateAccount(ctx context.Context, inviteCode, phone, code string) (*AuthResult, error) {
	// 1. Verify invite code
	household, err := s.store.GetHouseholdByInviteCode(ctx, inviteCode)
	if err != nil {
		return nil, ErrHouseholdNotFound
	}

	// 2. Verify OTP
	otp, err := s.store.GetLatestValidOTP(ctx, phone)
	if err != nil {
		return nil, ErrOTPInvalid
	}
	if otp.Code != code {
		return nil, ErrOTPInvalid
	}
	if err := s.store.ConsumeOTP(ctx, otp.ID); err != nil {
		return nil, err
	}

	// 3. Generate 32-byte cryptographic random household key (FR-AUTH-07, SDD 5.2)
	rawHouseholdKey, err := GenerateRandomKey32()
	if err != nil {
		return nil, err
	}

	// 4. Encrypt household key with AES-256-GCM using dataKey
	keyEnc, err := EncryptAES256GCM(s.dataKey, rawHouseholdKey)
	if err != nil {
		return nil, fmt.Errorf("failed to encrypt household key: %w", err)
	}

	// 5. Update household record and invalidate invite code (single use)
	if err := s.store.UpdateHouseholdKeyAndClearInvite(ctx, household.ID, keyEnc); err != nil {
		return nil, err
	}

	// 6. Create or link Kepala Keluarga user
	u, err := s.store.GetUserByPhone(ctx, phone)
	if err != nil {
		u = &User{
			ID:        uuid.NewString(),
			Name:      household.HeadName,
			Phone:     phone,
			CreatedAt: time.Now(),
		}
		if err := s.store.CreateUser(ctx, u); err != nil {
			return nil, err
		}
	}

	// 7. Add membership
	membership := &Membership{
		ID:          uuid.NewString(),
		UserID:      u.ID,
		RegionID:    household.RTID,
		Role:        "kepala_keluarga",
		HouseholdID: &household.ID,
		CreatedAt:   time.Now(),
	}
	_ = s.store.AddMembership(ctx, membership)

	// 8. Generate JWT session tokens
	claims := Claims{
		UserID:      u.ID,
		Phone:       u.Phone,
		Role:        "kepala_keluarga",
		RegionID:    household.RTID,
		HouseholdID: household.ID,
	}

	accessToken, expiresAt, err := GenerateAccessToken(s.jwtSecret, claims)
	if err != nil {
		return nil, err
	}

	rawRefresh, tokenHash, refreshExpiresAt, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	if err := s.store.SaveRefreshToken(ctx, u.ID, tokenHash, refreshExpiresAt); err != nil {
		return nil, err
	}

	return &AuthResult{
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
		ExpiresAt:    expiresAt,
		HouseholdKey: hex.EncodeToString(rawHouseholdKey),
		User: UserDTO{
			ID:          u.ID,
			Name:        u.Name,
			Phone:       u.Phone,
			Role:        "kepala_keluarga",
			RegionID:    household.RTID,
			HouseholdID: &household.ID,
		},
	}, nil
}

// RefreshToken rotates an existing refresh token and returns a new token pair (FR-AUTH-05).
func (s *Service) RefreshToken(ctx context.Context, rawRefreshToken string) (*AuthResult, error) {
	tokenHash := HashRefreshToken(rawRefreshToken)
	record, err := s.store.GetRefreshToken(ctx, tokenHash)
	if err != nil {
		return nil, ErrInvalidToken
	}

	if record.Revoked || time.Now().After(record.ExpiresAt) {
		return nil, ErrTokenRevoked
	}

	// Revoke old refresh token (token rotation)
	_ = s.store.RevokeRefreshToken(ctx, tokenHash)

	u, err := s.store.GetUserByID(ctx, record.UserID)
	if err != nil {
		return nil, ErrUserNotFound
	}

	memberships, err := s.store.GetMemberships(ctx, u.ID)
	role := "kepala_keluarga"
	regionID := ""
	var householdID *string

	if err == nil && len(memberships) > 0 {
		role = memberships[0].Role
		regionID = memberships[0].RegionID
		householdID = memberships[0].HouseholdID
	}

	claims := Claims{
		UserID:      u.ID,
		Phone:       u.Phone,
		Role:        role,
		RegionID:    regionID,
		HouseholdID: derefString(householdID),
	}

	accessToken, expiresAt, err := GenerateAccessToken(s.jwtSecret, claims)
	if err != nil {
		return nil, err
	}

	newRawRefresh, newTokenHash, newRefreshExpiresAt, err := GenerateRefreshToken()
	if err != nil {
		return nil, err
	}

	if err := s.store.SaveRefreshToken(ctx, u.ID, newTokenHash, newRefreshExpiresAt); err != nil {
		return nil, err
	}

	return &AuthResult{
		AccessToken:  accessToken,
		RefreshToken: newRawRefresh,
		ExpiresAt:    expiresAt,
		User: UserDTO{
			ID:          u.ID,
			Name:        u.Name,
			Phone:       u.Phone,
			Email:       u.Email,
			Role:        role,
			RegionID:    regionID,
			HouseholdID: householdID,
		},
	}, nil
}

// Logout revokes the given refresh token.
func (s *Service) Logout(ctx context.Context, rawRefreshToken string) error {
	tokenHash := HashRefreshToken(rawRefreshToken)
	return s.store.RevokeRefreshToken(ctx, tokenHash)
}

func derefString(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
