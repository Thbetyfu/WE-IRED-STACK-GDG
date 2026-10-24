package announcement

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"time"
)

var (
	ErrInvalidDelegation = errors.New("sertifikat delegasi kunci Posko tidak valid atau kedaluwarsa")
	ErrKeyNotFound       = errors.New("kunci penandatanganan tidak tersedia")
)

// PoskoDelegation contains a cloud-certified subkey for Posko offline signing (SDD 9.1).
type PoskoDelegation struct {
	PoskoID        string            `json:"posko_id"`
	RTID           string            `json:"rt_id"`
	PoskoPublicKey ed25519.PublicKey `json:"posko_public_key"`
	ValidUntil     time.Time         `json:"valid_until"`
	CloudSignature []byte            `json:"cloud_signature"` // Signed by Cloud Root Key
}

// KeyManager handles Cloud root Ed25519 keys and Posko subkey delegation.
type KeyManager struct {
	rootPrivateKey ed25519.PrivateKey
	rootPublicKey  ed25519.PublicKey
}

// NewKeyManager initializes the manager from a base64 encoded private key or generates a fresh keypair.
func NewKeyManager(base64PrivKey string) (*KeyManager, error) {
	if base64PrivKey != "" {
		keyBytes, err := base64.StdEncoding.DecodeString(base64PrivKey)
		if err != nil {
			return nil, fmt.Errorf("failed to decode ANNOUNCE_SIGNING_KEY base64: %w", err)
		}
		if len(keyBytes) == ed25519.PrivateKeySize {
			privKey := ed25519.PrivateKey(keyBytes)
			pubKey := privKey.Public().(ed25519.PublicKey)
			return &KeyManager{
				rootPrivateKey: privKey,
				rootPublicKey:  pubKey,
			}, nil
		} else if len(keyBytes) == ed25519.SeedSize {
			privKey := ed25519.NewKeyFromSeed(keyBytes)
			pubKey := privKey.Public().(ed25519.PublicKey)
			return &KeyManager{
				rootPrivateKey: privKey,
				rootPublicKey:  pubKey,
			}, nil
		} else {
			return nil, fmt.Errorf("invalid ed25519 key size (%d bytes, expected 64 or 32)", len(keyBytes))
		}
	}

	// Generate default deterministic / runtime keypair if not configured
	pubKey, privKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate ed25519 key: %w", err)
	}

	return &KeyManager{
		rootPrivateKey: privKey,
		rootPublicKey:  pubKey,
	}, nil
}

// RootPublicKey returns the Cloud Ed25519 public key.
func (km *KeyManager) RootPublicKey() ed25519.PublicKey {
	return km.rootPublicKey
}

// RootPublicKeyBase64 returns base64 encoded public key for provisioning.
func (km *KeyManager) RootPublicKeyBase64() string {
	return base64.StdEncoding.EncodeToString(km.rootPublicKey)
}

// SignAnnouncement signs a packet using the Cloud root private key.
func (km *KeyManager) SignAnnouncement(p *Packet) ([]byte, error) {
	if km.rootPrivateKey == nil {
		return nil, ErrKeyNotFound
	}
	return Encode(p, km.rootPrivateKey)
}

// GeneratePoskoDelegation generates a Posko-specific subkey and a Cloud-signed delegation certificate (SDD 9.1).
func (km *KeyManager) GeneratePoskoDelegation(poskoID, rtID string, duration time.Duration) (*PoskoDelegation, ed25519.PrivateKey, error) {
	if duration <= 0 {
		duration = 7 * 24 * time.Hour // Default 7 days validity
	}

	poskoPubKey, poskoPrivKey, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, nil, err
	}

	validUntil := time.Now().UTC().Add(duration)

	// Certificate payload: poskoID + ":" + rtID + ":" + poskoPubKey + ":" + validUntil (8 bytes)
	certPayload := buildDelegationPayload(poskoID, rtID, poskoPubKey, validUntil)
	cloudSig := ed25519.Sign(km.rootPrivateKey, certPayload)

	delegation := &PoskoDelegation{
		PoskoID:        poskoID,
		RTID:           rtID,
		PoskoPublicKey: poskoPubKey,
		ValidUntil:     validUntil,
		CloudSignature: cloudSig,
	}

	return delegation, poskoPrivKey, nil
}

// VerifyDelegation checks if a Posko subkey delegation is authentically signed by the Cloud Root Key.
func (km *KeyManager) VerifyDelegation(delegation *PoskoDelegation, now time.Time) error {
	if delegation == nil {
		return ErrInvalidDelegation
	}
	if now.IsZero() {
		now = time.Now().UTC()
	}
	if now.After(delegation.ValidUntil) {
		return fmt.Errorf("%w: telah kedaluwarsa pada %s", ErrInvalidDelegation, delegation.ValidUntil)
	}

	certPayload := buildDelegationPayload(delegation.PoskoID, delegation.RTID, delegation.PoskoPublicKey, delegation.ValidUntil)
	if !ed25519.Verify(km.rootPublicKey, certPayload, delegation.CloudSignature) {
		return fmt.Errorf("%w: tanda tangan cloud tidak cocok", ErrInvalidDelegation)
	}

	return nil
}

func buildDelegationPayload(poskoID, rtID string, pubKey ed25519.PublicKey, validUntil time.Time) []byte {
	var buf []byte
	buf = append(buf, []byte(poskoID)...)
	buf = append(buf, 0x3A) // ':'
	buf = append(buf, []byte(rtID)...)
	buf = append(buf, 0x3A)
	buf = append(buf, pubKey...)
	buf = append(buf, 0x3A)
	timeBytes := make([]byte, 8)
	binary.LittleEndian.PutUint64(timeBytes, uint64(validUntil.Unix()))
	buf = append(buf, timeBytes...)
	return buf
}
