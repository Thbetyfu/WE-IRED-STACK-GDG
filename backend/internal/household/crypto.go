package household

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"math/big"
)

var (
	ErrDecryptionFailed = errors.New("gagal mendekripsi data catatan kesehatan")
)

// GenerateShortID8 generates an 8-byte cryptographically secure random pseudonym for relay packets (SDD 5.2).
func GenerateShortID8() ([]byte, error) {
	bytes := make([]byte, 8)
	if _, err := io.ReadFull(rand.Reader, bytes); err != nil {
		return nil, fmt.Errorf("failed to generate 8-byte short id: %w", err)
	}
	return bytes, nil
}

// GenerateInviteCode8 generates an 8-character uppercase alphanumeric single-use invite code (e.g. "INV-7K9A").
func GenerateInviteCode8() (string, error) {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // omits ambiguous characters (I, O, 0, 1)
	code := make([]byte, 8)
	code[0] = 'I'
	code[1] = 'N'
	code[2] = 'V'
	code[3] = '-'

	for i := 4; i < 8; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", err
		}
		code[i] = charset[n.Int64()]
	}

	return string(code), nil
}

// EncryptAES256GCM encrypts plaintext using AES-256-GCM with a fresh random nonce.
func EncryptAES256GCM(key []byte, plaintext []byte) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("aes-256 key must be exactly 32 bytes")
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	// 12-byte nonce must be unique for every encryption
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	// Output: nonce || ciphertext+tag
	ciphertext := gcm.Seal(nonce, nonce, plaintext, nil)
	return ciphertext, nil
}

// DecryptAES256GCM decrypts ciphertext produced by EncryptAES256GCM.
func DecryptAES256GCM(key []byte, ciphertext []byte) ([]byte, error) {
	if len(key) != 32 {
		return nil, errors.New("aes-256 key must be exactly 32 bytes")
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, ErrDecryptionFailed
	}

	nonce, actualCiphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, actualCiphertext, nil)
	if err != nil {
		return nil, ErrDecryptionFailed
	}

	return plaintext, nil
}
