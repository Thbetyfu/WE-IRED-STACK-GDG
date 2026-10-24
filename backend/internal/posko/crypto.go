package posko

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net"
	"strings"
	"time"

	"golang.org/x/crypto/argon2"
)

var (
	ErrInvalidSnapshotPassword = errors.New("kata sandi enkripsi snapshot tidak valid (dekripsi GCM gagal)")
	ErrMalformedSnapshot       = errors.New("format amplop snapshot terenkripsi tidak valid")
	ErrEmptyPassword           = errors.New("kata sandi snapshot tidak boleh kosong")
)

const (
	SnapshotMagic = "WRSN"
	SaltLength    = 16
	NonceLength   = 12
	KeyLength     = 32
)

// EncryptSnapshot serializes and encrypts the snapshot payload using AES-256-GCM with Argon2id derived key (SDD 8.2).
func EncryptSnapshot(payload *SnapshotPayload, password string) (*EncryptedSnapshotEnvelope, error) {
	if strings.TrimSpace(password) == "" {
		return nil, ErrEmptyPassword
	}

	rawJSON, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal snapshot payload: %w", err)
	}

	// 1. Generate 16-byte random salt
	salt := make([]byte, SaltLength)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return nil, fmt.Errorf("failed to generate random salt: %w", err)
	}

	// 2. Derive 32-byte key using Argon2id
	derivedKey := argon2.IDKey([]byte(password), salt, 1, 64*1024, 2, KeyLength)

	// 3. Setup AES-256-GCM
	block, err := aes.NewCipher(derivedKey)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize AES cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize GCM: %w", err)
	}

	// 4. Generate 12-byte random nonce
	nonce := make([]byte, NonceLength)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("failed to generate nonce: %w", err)
	}

	// 5. Encrypt with authentication tag
	ciphertext := gcm.Seal(nil, nonce, rawJSON, []byte(SnapshotMagic))

	return &EncryptedSnapshotEnvelope{
		Magic:      SnapshotMagic,
		Salt:       base64.StdEncoding.EncodeToString(salt),
		Nonce:      base64.StdEncoding.EncodeToString(nonce),
		Ciphertext: base64.StdEncoding.EncodeToString(ciphertext),
		CreatedAt:  time.Now().UTC(),
	}, nil
}

// DecryptSnapshot decrypts the envelope using password and returns the SnapshotPayload.
// If the password is wrong, AES-GCM tag verification strictly fails.
func DecryptSnapshot(env *EncryptedSnapshotEnvelope, password string) (*SnapshotPayload, error) {
	if env == nil || env.Magic != SnapshotMagic {
		return nil, ErrMalformedSnapshot
	}
	if strings.TrimSpace(password) == "" {
		return nil, ErrEmptyPassword
	}

	salt, err := base64.StdEncoding.DecodeString(env.Salt)
	if err != nil || len(salt) != SaltLength {
		return nil, ErrMalformedSnapshot
	}

	nonce, err := base64.StdEncoding.DecodeString(env.Nonce)
	if err != nil || len(nonce) != NonceLength {
		return nil, ErrMalformedSnapshot
	}

	ciphertext, err := base64.StdEncoding.DecodeString(env.Ciphertext)
	if err != nil || len(ciphertext) < gcmTagSize() {
		return nil, ErrMalformedSnapshot
	}

	// Derive key with same Argon2id parameters
	derivedKey := argon2.IDKey([]byte(password), salt, 1, 64*1024, 2, KeyLength)

	block, err := aes.NewCipher(derivedKey)
	if err != nil {
		return nil, fmt.Errorf("failed to create cipher: %w", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("failed to create GCM: %w", err)
	}

	// Open will return an error if tag doesn't match (wrong password)
	plaintext, err := gcm.Open(nil, nonce, ciphertext, []byte(SnapshotMagic))
	if err != nil {
		return nil, ErrInvalidSnapshotPassword
	}

	var payload SnapshotPayload
	if err := json.Unmarshal(plaintext, &payload); err != nil {
		return nil, fmt.Errorf("failed to unmarshal decrypted snapshot payload: %w", err)
	}

	return &payload, nil
}

func gcmTagSize() int {
	return 16
}

// GenerateSelfSignedCert creates an in-memory ECDSA TLS certificate and computes its SHA-256 fingerprint (FR-PSK-04 & NFR-SEC-01).
func GenerateSelfSignedCert(hostnames []string) (tls.Certificate, string, error) {
	priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return tls.Certificate{}, "", fmt.Errorf("failed to generate ecdsa key: %w", err)
	}

	serialNumberLimit := new(big.Int).Lsh(big.NewInt(1), 128)
	serialNumber, err := rand.Int(rand.Reader, serialNumberLimit)
	if err != nil {
		return tls.Certificate{}, "", err
	}

	notBefore := time.Now().Add(-1 * time.Hour)
	notAfter := notBefore.Add(365 * 24 * time.Hour) // 1 year validity

	template := x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			Organization: []string{"WE-IRED Posko Lokal"},
			CommonName:   "weired-posko.local",
		},
		NotBefore:             notBefore,
		NotAfter:              notAfter,
		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
	}

	// Default IP & DNS SANs
	template.DNSNames = append(template.DNSNames, "localhost", "weired-posko.local")
	template.IPAddresses = append(template.IPAddresses, net.ParseIP("127.0.0.1"), net.ParseIP("192.168.4.1"))

	for _, h := range hostnames {
		if ip := net.ParseIP(h); ip != nil {
			template.IPAddresses = append(template.IPAddresses, ip)
		} else if h != "" {
			template.DNSNames = append(template.DNSNames, h)
		}
	}

	derBytes, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		return tls.Certificate{}, "", fmt.Errorf("failed to create certificate: %w", err)
	}

	// Compute SHA-256 fingerprint formatted with colon separators (e.g. AA:BB:CC:...)
	fingerprintBytes := sha256.Sum256(derBytes)
	fingerprintHex := strings.ToUpper(hex.EncodeToString(fingerprintBytes[:]))
	var formattedFP strings.Builder
	for i := 0; i < len(fingerprintHex); i += 2 {
		if i > 0 {
			formattedFP.WriteString(":")
		}
		formattedFP.WriteString(fingerprintHex[i : i+2])
	}

	tlsCert := tls.Certificate{
		Certificate: [][]byte{derBytes},
		PrivateKey:  priv,
	}

	return tlsCert, formattedFP.String(), nil
}
