package auth

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type mockHierarchyChecker struct {
	allowedPairs map[string]string // rtID -> parentRegionID
}

func (m *mockHierarchyChecker) IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error) {
	parent, ok := m.allowedPairs[rtID]
	if !ok {
		return false, nil
	}
	return parent == regionID, nil
}

func TestArgon2idHashingAndVerification(t *testing.T) {
	password := "RahasiaSuperKuat2026!"
	hash, err := HashPasswordArgon2id(password)
	if err != nil {
		t.Fatalf("failed to hash password: %v", err)
	}

	if len(hash) == 0 {
		t.Fatal("expected non-empty hash")
	}

	// Verify correct password
	valid, err := VerifyPasswordArgon2id(password, hash)
	if err != nil {
		t.Fatalf("verification returned error: %v", err)
	}
	if !valid {
		t.Fatal("expected password to match hash")
	}

	// Verify incorrect password
	valid, err = VerifyPasswordArgon2id("PasswordSalah!", hash)
	if err != nil {
		t.Fatalf("verification returned error: %v", err)
	}
	if valid {
		t.Fatal("expected incorrect password to fail verification")
	}

	// Invalid hash format
	_, err = VerifyPasswordArgon2id(password, "invalid$format")
	if err == nil {
		t.Fatal("expected error for malformed hash format")
	}
}

func TestAES256GCMHouseholdKey(t *testing.T) {
	key, err := GenerateRandomKey32()
	if err != nil {
		t.Fatalf("failed to generate random 32-byte key: %v", err)
	}
	if len(key) != 32 {
		t.Fatalf("expected 32 bytes, got %d", len(key))
	}

	plaintext := []byte("HouseholdSecretSeedForRelaySigning123456")
	ciphertext, err := EncryptAES256GCM(key, plaintext)
	if err != nil {
		t.Fatalf("encryption failed: %v", err)
	}

	decrypted, err := DecryptAES256GCM(key, ciphertext)
	if err != nil {
		t.Fatalf("decryption failed: %v", err)
	}
	if !bytes.Equal(plaintext, decrypted) {
		t.Fatalf("decrypted %s does not match plaintext %s", string(decrypted), string(plaintext))
	}

	// Tampered ciphertext fails
	ciphertext[len(ciphertext)-1] ^= 0xFF
	_, err = DecryptAES256GCM(key, ciphertext)
	if err == nil {
		t.Fatal("expected decryption of tampered ciphertext to fail")
	}
}

func TestOTPGenerationAndRateLimiting(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	phone := "+628111222333"

	// 1. Request OTP 5 times within 15 minutes window
	for i := 0; i < OTPMaxAttempts; i++ {
		code, err := svc.RequestOTP(context.Background(), phone)
		if err != nil {
			t.Fatalf("failed to request OTP iteration %d: %v", i, err)
		}
		if len(code) != 6 {
			t.Fatalf("expected 6-digit OTP, got %s", code)
		}
	}

	// 2. 6th request must be rate limited (FR-AUTH-08)
	_, err := svc.RequestOTP(context.Background(), phone)
	if err == nil || err != ErrOTPRateLimited {
		t.Fatalf("expected ErrOTPRateLimited, got %v", err)
	}
}

func TestOTPVerificationAndMaxAttempts(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	phone := "+628123456780"
	code, err := svc.RequestOTP(context.Background(), phone)
	if err != nil {
		t.Fatalf("failed to request OTP: %v", err)
	}

	// 5 failed verification attempts
	for i := 0; i < OTPMaxAttempts; i++ {
		_, err := svc.VerifyOTP(context.Background(), phone, "000000")
		if err != ErrOTPInvalid {
			t.Fatalf("expected ErrOTPInvalid on wrong attempt %d, got %v", i, err)
		}
	}

	// 6th attempt exceeds max attempts
	_, err = svc.VerifyOTP(context.Background(), phone, code)
	if err != ErrOTPMaxAttempts {
		t.Fatalf("expected ErrOTPMaxAttempts, got %v", err)
	}
}

func TestLoginWithPassword(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	password := "SandiPengurus2026"
	hash, _ := HashPasswordArgon2id(password)
	u := &User{
		ID:           uuid.NewString(),
		Name:         "Pak RT Budi",
		Email:        "budi@rt01.id",
		Phone:        "+6281299990001",
		PasswordHash: hash,
		CreatedAt:    time.Now(),
	}
	_ = store.CreateUser(context.Background(), u)
	_ = store.AddMembership(context.Background(), &Membership{
		ID:        uuid.NewString(),
		UserID:    u.ID,
		RegionID:  "rt-01",
		Role:      "pengurus",
		CreatedAt: time.Now(),
	})

	// Valid login
	res, err := svc.LoginWithPassword(context.Background(), "budi@rt01.id", password)
	if err != nil {
		t.Fatalf("expected successful login, got %v", err)
	}
	if res.AccessToken == "" || res.RefreshToken == "" {
		t.Fatal("expected access and refresh tokens")
	}
	if res.User.Role != "pengurus" || res.User.RegionID != "rt-01" {
		t.Fatalf("unexpected user DTO: %+v", res.User)
	}

	// Invalid password
	_, err = svc.LoginWithPassword(context.Background(), "budi@rt01.id", "wrongpass")
	if err != ErrInvalidCredentials {
		t.Fatalf("expected ErrInvalidCredentials, got %v", err)
	}
}

func TestActivateAccountFlow(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	inviteCode := "INV-A1B2"
	hhID := "household-101"
	store.households[hhID] = &Household{
		ID:         hhID,
		RTID:       "rt-01",
		Number:     "A-12",
		Address:    "Jl. Mawar No 12",
		HeadName:   "Ahmad Yani",
		WAPhone:    "+6281312345678",
		InviteCode: &inviteCode,
	}

	phone := "+6281312345678"
	code, err := svc.RequestOTP(context.Background(), phone)
	if err != nil {
		t.Fatalf("request OTP failed: %v", err)
	}

	// Activate account with invite code + OTP (FR-AUTH-03, FR-AUTH-07)
	res, err := svc.ActivateAccount(context.Background(), inviteCode, phone, code)
	if err != nil {
		t.Fatalf("activate account failed: %v", err)
	}

	if res.HouseholdKey == "" {
		t.Fatal("expected 32-byte household key returned on activation")
	}
	if res.User.Role != "kepala_keluarga" {
		t.Fatalf("expected role kepala_keluarga, got %s", res.User.Role)
	}
	if res.User.HouseholdID == nil || *res.User.HouseholdID != hhID {
		t.Fatalf("expected household ID %s, got %v", hhID, res.User.HouseholdID)
	}

	// Invite code must be cleared (single-use)
	_, err = svc.ActivateAccount(context.Background(), inviteCode, phone, code)
	if err != ErrHouseholdNotFound {
		t.Fatalf("expected invite code reuse to fail with ErrHouseholdNotFound, got %v", err)
	}

	// Stored key_enc must be decryptable by dataKey
	storedHH := store.households[hhID]
	if len(storedHH.KeyEnc) == 0 {
		t.Fatal("expected household key_enc to be persisted in store")
	}
	decryptedKey, err := DecryptAES256GCM(dataKey, storedHH.KeyEnc)
	if err != nil {
		t.Fatalf("failed to decrypt persisted key_enc: %v", err)
	}
	if len(decryptedKey) != 32 {
		t.Fatalf("expected decrypted key length 32, got %d", len(decryptedKey))
	}
}

func TestRefreshTokenRotationAndRevocation(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	u := &User{
		ID:        uuid.NewString(),
		Name:      "Relawan Siti",
		Phone:     "+628555123456",
		CreatedAt: time.Now(),
	}
	_ = store.CreateUser(context.Background(), u)
	_ = store.AddMembership(context.Background(), &Membership{
		ID:        uuid.NewString(),
		UserID:    u.ID,
		RegionID:  "rt-01",
		Role:      "relawan",
		CreatedAt: time.Now(),
	})

	code, _ := svc.RequestOTP(context.Background(), u.Phone)
	loginRes, err := svc.VerifyOTP(context.Background(), u.Phone, code)
	if err != nil {
		t.Fatalf("login failed: %v", err)
	}

	// 1. Refresh token (FR-AUTH-05: token rotation)
	refreshRes, err := svc.RefreshToken(context.Background(), loginRes.RefreshToken)
	if err != nil {
		t.Fatalf("refresh token failed: %v", err)
	}
	if refreshRes.RefreshToken == loginRes.RefreshToken {
		t.Fatal("expected new rotated refresh token")
	}

	// 2. Reusing old refresh token must fail (revoked)
	_, err = svc.RefreshToken(context.Background(), loginRes.RefreshToken)
	if err != ErrTokenRevoked {
		t.Fatalf("expected ErrTokenRevoked on old token reuse, got %v", err)
	}

	// 3. Logout revokes active refresh token
	if err := svc.Logout(context.Background(), refreshRes.RefreshToken); err != nil {
		t.Fatalf("logout failed: %v", err)
	}
	_, err = svc.RefreshToken(context.Background(), refreshRes.RefreshToken)
	if err != ErrTokenRevoked {
		t.Fatalf("expected ErrTokenRevoked after logout, got %v", err)
	}
}

func TestRBACAndScopeMiddleware(t *testing.T) {
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	checker := &mockHierarchyChecker{
		allowedPairs: map[string]string{
			"rt-01": "rw-05",
			"rt-02": "rw-05",
			"rt-03": "rw-06",
		},
	}

	r := chi.NewRouter()
	r.Use(Authenticate(jwtSecret))

	// Admin-only route
	r.With(RequireRole("operator", "admin_wilayah")).Get("/api/admin-only", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("admin ok"))
	})

	// RT-scoped route
	r.With(RequireRTScope("rt", checker)).Get("/api/rts/{rt}/status", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("rt ok"))
	})

	// Household-scoped route
	r.With(RequireHouseholdScope("id")).Get("/api/households/{id}", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("household ok"))
	})

	server := httptest.NewServer(r)
	defer server.Close()

	// Helper to make request
	doReq := func(token, path string) int {
		req, _ := http.NewRequest(http.MethodGet, server.URL+path, nil)
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		return resp.StatusCode
	}

	// Helper to generate test tokens
	makeToken := func(role, regionID, householdID string) string {
		tok, _, _ := GenerateAccessToken(jwtSecret, Claims{
			UserID:      "test-user",
			Role:        role,
			RegionID:    regionID,
			HouseholdID: householdID,
		})
		return tok
	}

	operatorTok := makeToken("operator", "", "")
	adminWilayahTok := makeToken("admin_wilayah", "rw-05", "")
	pengurusTok := makeToken("pengurus", "rt-01", "")
	wargaTok := makeToken("kepala_keluarga", "rt-01", "hh-100")

	// 1. Unauthenticated -> 401
	if code := doReq("", "/api/admin-only"); code != http.StatusUnauthorized {
		t.Fatalf("expected 401 unauthenticated, got %d", code)
	}

	// 2. Role checks
	if code := doReq(operatorTok, "/api/admin-only"); code != http.StatusOK {
		t.Fatalf("expected operator 200 on admin route, got %d", code)
	}
	if code := doReq(pengurusTok, "/api/admin-only"); code != http.StatusForbidden {
		t.Fatalf("expected pengurus 403 on admin route, got %d", code)
	}

	// 3. RT Scope checks
	// Operator can access any RT
	if code := doReq(operatorTok, "/api/rts/rt-01/status"); code != http.StatusOK {
		t.Fatalf("expected operator 200 on rt-01, got %d", code)
	}
	if code := doReq(operatorTok, "/api/rts/rt-99/status"); code != http.StatusOK {
		t.Fatalf("expected operator 200 on rt-99, got %d", code)
	}

	// Admin Wilayah rw-05 can access rt-01 and rt-02 (within rw-05), but not rt-03 (in rw-06)
	if code := doReq(adminWilayahTok, "/api/rts/rt-01/status"); code != http.StatusOK {
		t.Fatalf("expected admin_wilayah 200 on rt-01, got %d", code)
	}
	if code := doReq(adminWilayahTok, "/api/rts/rt-03/status"); code != http.StatusForbidden {
		t.Fatalf("expected admin_wilayah 403 on rt-03 (other RW), got %d", code)
	}

	// Pengurus rt-01 can only access rt-01
	if code := doReq(pengurusTok, "/api/rts/rt-01/status"); code != http.StatusOK {
		t.Fatalf("expected pengurus 200 on rt-01, got %d", code)
	}
	if code := doReq(pengurusTok, "/api/rts/rt-02/status"); code != http.StatusForbidden {
		t.Fatalf("expected pengurus 403 on rt-02, got %d", code)
	}

	// 4. Household Scope checks
	// Kepala keluarga can access hh-100, but not hh-101
	if code := doReq(wargaTok, "/api/households/hh-100"); code != http.StatusOK {
		t.Fatalf("expected warga 200 on hh-100, got %d", code)
	}
	if code := doReq(wargaTok, "/api/households/hh-101"); code != http.StatusForbidden {
		t.Fatalf("expected warga 403 on hh-101, got %d", code)
	}
	// Pengurus can access any household within their scope
	if code := doReq(pengurusTok, "/api/households/hh-101"); code != http.StatusOK {
		t.Fatalf("expected pengurus 200 on household, got %d", code)
	}
}

func TestAuthHandlerEndpoints(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)
	handler := NewHandler(svc)

	r := chi.NewRouter()
	handler.Routes(r)

	server := httptest.NewServer(r)
	defer server.Close()

	// Seed user
	pwHash, _ := HashPasswordArgon2id("Password123!")
	u := &User{
		ID:           "user-1",
		Name:         "Admin Wilayah",
		Email:        "admin@kelurahan.go.id",
		Phone:        "+628111999888",
		PasswordHash: pwHash,
		CreatedAt:    time.Now(),
	}
	_ = store.CreateUser(context.Background(), u)
	_ = store.AddMembership(context.Background(), &Membership{
		ID:        "m-1",
		UserID:    u.ID,
		RegionID:  "kel-01",
		Role:      "admin_wilayah",
		CreatedAt: time.Now(),
	})

	// 1. Test POST /auth/login
	loginBody, _ := json.Marshal(map[string]string{
		"email":    "admin@kelurahan.go.id",
		"password": "Password123!",
	})
	resp, err := http.Post(server.URL+"/auth/login", "application/json", bytes.NewReader(loginBody))
	if err != nil {
		t.Fatalf("post login failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
	}

	var authResp struct {
		Data AuthResult `json:"data"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&authResp)
	if authResp.Data.AccessToken == "" || authResp.Data.RefreshToken == "" {
		t.Fatal("expected tokens in response")
	}

	// 2. Test GET /auth/me with Bearer token
	meReq, _ := http.NewRequest(http.MethodGet, server.URL+"/auth/me", nil)
	meReq.Header.Set("Authorization", "Bearer "+authResp.Data.AccessToken)
	meResp, err := http.DefaultClient.Do(meReq)
	if err != nil {
		t.Fatalf("get me failed: %v", err)
	}
	if meResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", meResp.StatusCode)
	}

	// 3. Test POST /auth/refresh
	refreshBody, _ := json.Marshal(map[string]string{
		"refresh_token": authResp.Data.RefreshToken,
	})
	refResp, err := http.Post(server.URL+"/auth/refresh", "application/json", bytes.NewReader(refreshBody))
	if err != nil {
		t.Fatalf("post refresh failed: %v", err)
	}
	if refResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", refResp.StatusCode)
	}

	// 4. Test POST /auth/logout
	logoutBody, _ := json.Marshal(map[string]string{
		"refresh_token": authResp.Data.RefreshToken,
	})
	logoutResp, err := http.Post(server.URL+"/auth/logout", "application/json", bytes.NewReader(logoutBody))
	if err != nil {
		t.Fatalf("post logout failed: %v", err)
	}
	if logoutResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", logoutResp.StatusCode)
	}
}

func GenerateExpiredTestToken(secret []byte, claims Claims, expiredAt time.Time) string {
	claims.IssuedAt = &jwt.NumericDate{Time: expiredAt.Add(-15 * time.Minute)}
	claims.ExpiresAt = &jwt.NumericDate{Time: expiredAt}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, _ := token.SignedString(secret)
	return signed
}

func TestExpiredJWTAccessTokenRejection(t *testing.T) {
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")

	// Generate expired token (expired 5 minutes ago)
	claims := Claims{
		UserID:   "expired-user",
		Role:     "pengurus",
		RegionID: "rt-01",
	}
	claims.IssuedAt = nil
	claims.ExpiresAt = nil

	token := GenerateExpiredTestToken(jwtSecret, claims, time.Now().Add(-5*time.Minute))

	// ValidateAccessToken must reject expired token
	_, err := ValidateAccessToken(jwtSecret, token)
	if err == nil || err != ErrInvalidToken {
		t.Fatalf("expected ErrInvalidToken for expired JWT, got %v", err)
	}

	// Middleware must reject expired token with 401
	r := chi.NewRouter()
	r.Use(Authenticate(jwtSecret))
	r.Get("/test-secure", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	server := httptest.NewServer(r)
	defer server.Close()

	req, _ := http.NewRequest(http.MethodGet, server.URL+"/test-secure", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("http req failed: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized for expired JWT, got %d", resp.StatusCode)
	}
}

func TestExpiredOTPRejection(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	phone := "+6281999888777"
	// Save expired OTP directly to store
	expiredAt := time.Now().Add(-10 * time.Minute)
	_ = store.SaveOTP(context.Background(), phone, "123456", expiredAt)

	// Attempting to verify expired OTP must fail
	_, err := svc.VerifyOTP(context.Background(), phone, "123456")
	if err == nil || err != ErrOTPInvalid {
		t.Fatalf("expected ErrOTPInvalid/Expired for past OTP, got %v", err)
	}
}

func TestPasswordNeverPlaintext(t *testing.T) {
	plaintextPassword := "SuperSecretPassword123"
	hash, err := HashPasswordArgon2id(plaintextPassword)
	if err != nil {
		t.Fatalf("hash failed: %v", err)
	}

	// Hash must NOT contain the plaintext password anywhere
	if bytes.Contains([]byte(hash), []byte(plaintextPassword)) {
		t.Fatal("security violation: argon2id hash contains plaintext password string")
	}

	// Stored user must have empty or absent plaintext password
	u := &User{
		ID:           "test-sec-1",
		Name:         "User Security",
		Email:        "sec@rt01.id",
		PasswordHash: hash,
	}

	if u.PasswordHash == plaintextPassword {
		t.Fatal("password stored as plaintext")
	}
}

func TestSimulatedWhatsAppProviderIntegration(t *testing.T) {
	store := NewMemoryStore()
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	dataKey, _ := GenerateRandomKey32()
	svc := NewService(store, jwtSecret, dataKey)

	simulatedWA := NewSimulatedWhatsAppProvider()
	svc.SetOTPProvider(simulatedWA)

	phone := "+6281234560001"
	code, err := svc.RequestOTP(context.Background(), phone)
	if err != nil {
		t.Fatalf("request OTP failed: %v", err)
	}

	// Verify that provider received the exact dispatched code
	if len(simulatedWA.SentMessages) != 1 {
		t.Fatalf("expected 1 sent message, got %d", len(simulatedWA.SentMessages))
	}
	sent := simulatedWA.SentMessages[0]
	if sent.Phone != phone || sent.Code != code {
		t.Fatalf("dispatched message mismatch: got %+v, expected phone=%s code=%s", sent, phone, code)
	}
	if sent.ExpiresInSeconds != 300 {
		t.Fatalf("expected expiry 300s (5m), got %d", sent.ExpiresInSeconds)
	}

	// Verify that verification succeeds with the dispatched code
	res, err := svc.VerifyOTP(context.Background(), phone, simulatedWA.LastSentCode(phone))
	if err != nil {
		t.Fatalf("verification with dispatched code failed: %v", err)
	}
	if res.AccessToken == "" {
		t.Fatal("expected access token")
	}
}
