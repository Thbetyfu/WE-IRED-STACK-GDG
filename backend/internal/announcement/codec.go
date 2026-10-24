package announcement

import (
	"crypto/ed25519"
	"encoding/binary"
	"errors"
	"fmt"
	"time"
	"unicode/utf8"
)

const (
	ProtocolVersion = 0x01

	// Packet Types per SDD 7.6
	TypeAnnouncement  uint8 = 0x10
	TypeIncidentAlert uint8 = 0x11

	// Announcement Levels per SDD 5.2 & 7.6
	LevelInfo    uint8 = 0x01
	LevelPenting uint8 = 0x02
	LevelDarurat uint8 = 0x03

	HeaderLength    = 20
	SignatureLength = 64
	MinPacketLength = HeaderLength + SignatureLength // 84 bytes for 0-len text
	MaxTextBytes    = 200
	MaxRunes        = 160
)

var (
	ErrPacketTooShort     = errors.New("paket pengumuman terlalu pendek (minimal 84 byte)")
	ErrUnsupportedVersion = errors.New("versi protokol tidak didukung (harus 0x01)")
	ErrInvalidPacketType  = errors.New("tipe paket tidak valid (harus 0x10 untuk pengumuman atau 0x11 untuk insiden)")
	ErrTextTooLong        = errors.New("teks pengumuman melebihi batas 160 karakter atau 200 byte")
	ErrLengthMismatch     = errors.New("panjang paket tidak sesuai dengan field len")
	ErrInvalidSignature   = errors.New("verifikasi tanda tangan Ed25519 gagal")
	ErrInvalidLevel       = errors.New("tingkat pengumuman tidak valid")
)

// Packet represents a decoded signed announcement or incident event (SDD 7.6).
type Packet struct {
	Version    uint8
	Type       uint8
	RTShortID  uint32
	AnnShortID uint32
	Level      uint8
	CreatedAt  time.Time
	ExpiresAt  time.Time
	Text       string
	Signature  []byte // 64 bytes Ed25519 signature
}

// Encode builds and signs the binary announcement packet according to SDD 7.6:
// [version 1][type 0x10|0x11][rt_short_id 4][ann_short_id 4][level 1]
// [created_at 4][expires_at 4][len 1][text <= 200 byte UTF-8][sig Ed25519 64]
func Encode(p *Packet, privKey ed25519.PrivateKey) ([]byte, error) {
	if p.Version == 0 {
		p.Version = ProtocolVersion
	}
	if p.Type != TypeAnnouncement && p.Type != TypeIncidentAlert {
		return nil, ErrInvalidPacketType
	}
	if p.Level < LevelInfo || p.Level > LevelDarurat {
		return nil, ErrInvalidLevel
	}

	textBytes := []byte(p.Text)
	if len(textBytes) > MaxTextBytes || utf8.RuneCountInString(p.Text) > MaxRunes {
		return nil, ErrTextTooLong
	}

	textLen := len(textBytes)
	totalLen := HeaderLength + textLen + SignatureLength
	buf := make([]byte, totalLen)

	buf[0] = p.Version
	buf[1] = p.Type
	binary.LittleEndian.PutUint32(buf[2:6], p.RTShortID)
	binary.LittleEndian.PutUint32(buf[6:10], p.AnnShortID)
	buf[10] = p.Level

	createdUnix := uint32(p.CreatedAt.Unix())
	if p.CreatedAt.IsZero() {
		createdUnix = uint32(time.Now().Unix())
	}
	binary.LittleEndian.PutUint32(buf[11:15], createdUnix)

	expiresUnix := uint32(p.ExpiresAt.Unix())
	binary.LittleEndian.PutUint32(buf[15:19], expiresUnix)

	buf[19] = uint8(textLen)
	copy(buf[20:20+textLen], textBytes)

	// Sign the header + text payload (first 20 + textLen bytes)
	signedData := buf[:HeaderLength+textLen]
	sig := ed25519.Sign(privKey, signedData)
	copy(buf[HeaderLength+textLen:], sig)

	p.Signature = sig
	return buf, nil
}

// DecodeAndVerify parses the binary packet and verifies the Ed25519 signature.
func DecodeAndVerify(data []byte, pubKey ed25519.PublicKey) (*Packet, error) {
	if len(data) < MinPacketLength {
		return nil, ErrPacketTooShort
	}

	version := data[0]
	if version != ProtocolVersion {
		return nil, fmt.Errorf("%w: dapat 0x%02x", ErrUnsupportedVersion, version)
	}

	pktType := data[1]
	if pktType != TypeAnnouncement && pktType != TypeIncidentAlert {
		return nil, fmt.Errorf("%w: dapat 0x%02x", ErrInvalidPacketType, pktType)
	}

	rtShortID := binary.LittleEndian.Uint32(data[2:6])
	annShortID := binary.LittleEndian.Uint32(data[6:10])
	level := data[10]
	if level < LevelInfo || level > LevelDarurat {
		return nil, ErrInvalidLevel
	}

	createdUnix := binary.LittleEndian.Uint32(data[11:15])
	expiresUnix := binary.LittleEndian.Uint32(data[15:19])
	textLen := int(data[19])

	expectedTotal := HeaderLength + textLen + SignatureLength
	if len(data) != expectedTotal {
		return nil, fmt.Errorf("%w: ekspektasi %d byte, dapat %d byte", ErrLengthMismatch, expectedTotal, len(data))
	}

	text := string(data[HeaderLength : HeaderLength+textLen])
	sig := data[HeaderLength+textLen:]

	// Verify Ed25519 signature over header + text
	signedData := data[:HeaderLength+textLen]
	if !ed25519.Verify(pubKey, signedData, sig) {
		return nil, ErrInvalidSignature
	}

	sigCopy := make([]byte, SignatureLength)
	copy(sigCopy, sig)

	return &Packet{
		Version:    version,
		Type:       pktType,
		RTShortID:  rtShortID,
		AnnShortID: annShortID,
		Level:      level,
		CreatedAt:  time.Unix(int64(createdUnix), 0).UTC(),
		ExpiresAt:  time.Unix(int64(expiresUnix), 0).UTC(),
		Text:       text,
		Signature:  sigCopy,
	}, nil
}
