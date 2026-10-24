package relay

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

var (
	// NamespaceWEIred is the canonical UUIDv5 namespace for WE-IRED system elements (SDD 7.1 & 7.2).
	NamespaceWEIred = uuid.MustParse("5a1e0001-6c2b-4e8a-9f3d-2b6c8e4a1d00")

	ErrPacketTooShort   = errors.New("paket relay terlalu pendek (minimal 46 byte)")
	ErrInvalidVersion   = errors.New("versi protokol paket tidak didukung (harus 0x01)")
	ErrInvalidType      = errors.New("tipe paket tidak valid (harus 0x01)")
	ErrInvalidMAC       = errors.New("verifikasi HMAC-SHA256 paket gagal")
	ErrInvalidPathLength = errors.New("panjang data path tidak valid (harus kelipatan 2 byte)")
)

const (
	PacketMinLength = 46
	PacketTypeReport = 0x01
	ProtocolVersion  = 0x01

	FlagHasLocation    = 1 << 0 // 1
	FlagIsDrill        = 1 << 1 // 2
	FlagIsBeaconCheckin = 1 << 2 // 4
)

// Packet represents a decoded 46+ byte binary relay status report packet per SDD 7.2.
type Packet struct {
	Version          uint8
	Type             uint8
	HouseholdShortID [8]byte
	IncidentShortID  uint32
	Seq              uint32
	CreatedAt        time.Time
	Status           uint8
	Urgency          uint8
	Needs            uint8
	MemberMask       uint8
	Battery          uint8
	Flags            uint8
	Lat              *float64
	Lon              *float64
	TTL              uint8
	HopCount         uint8
	MAC              [8]byte
	Path             []uint16
}

// Decode parses raw bytes into a Packet according to SDD 7.2 specification.
func Decode(data []byte) (*Packet, error) {
	if len(data) < PacketMinLength {
		return nil, ErrPacketTooShort
	}

	p := &Packet{
		Version:  data[0],
		Type:     data[1],
		Status:   data[22],
		Urgency:  data[23],
		Needs:    data[24],
		MemberMask: data[25],
		Battery:  data[26],
		Flags:    data[27],
		TTL:      data[36],
		HopCount: data[37],
	}

	if p.Version != ProtocolVersion {
		return nil, ErrInvalidVersion
	}
	if p.Type != PacketTypeReport {
		return nil, ErrInvalidType
	}

	copy(p.HouseholdShortID[:], data[2:10])
	p.IncidentShortID = binary.LittleEndian.Uint32(data[10:14])
	p.Seq = binary.LittleEndian.Uint32(data[14:18])

	unixSec := binary.LittleEndian.Uint32(data[18:22])
	p.CreatedAt = time.Unix(int64(unixSec), 0).UTC()

	// Parse GPS coordinates if flag is set
	latE6 := int32(binary.LittleEndian.Uint32(data[28:32]))
	lonE6 := int32(binary.LittleEndian.Uint32(data[32:36]))
	if p.Flags&FlagHasLocation != 0 && (latE6 != 0 || lonE6 != 0) {
		lat := float64(latE6) / 1e6
		lon := float64(lonE6) / 1e6
		p.Lat = &lat
		p.Lon = &lon
	}

	copy(p.MAC[:], data[38:46])

	// Parse optional path (hops)
	pathBytes := data[46:]
	if len(pathBytes) > 0 {
		if len(pathBytes)%2 != 0 {
			return nil, ErrInvalidPathLength
		}
		numNodes := len(pathBytes) / 2
		p.Path = make([]uint16, numNodes)
		for i := 0; i < numNodes; i++ {
			p.Path[i] = binary.LittleEndian.Uint16(pathBytes[i*2 : i*2+2])
		}
	}

	return p, nil
}

// Encode serializes the Packet into little-endian binary bytes.
func (p *Packet) Encode(householdKey []byte) ([]byte, error) {
	totalLen := PacketMinLength + len(p.Path)*2
	buf := make([]byte, totalLen)

	buf[0] = ProtocolVersion
	buf[1] = PacketTypeReport
	copy(buf[2:10], p.HouseholdShortID[:])
	binary.LittleEndian.PutUint32(buf[10:14], p.IncidentShortID)
	binary.LittleEndian.PutUint32(buf[14:18], p.Seq)
	binary.LittleEndian.PutUint32(buf[18:22], uint32(p.CreatedAt.Unix()))

	buf[22] = p.Status
	buf[23] = p.Urgency
	buf[24] = p.Needs
	buf[25] = p.MemberMask
	buf[26] = p.Battery
	buf[27] = p.Flags

	if p.Lat != nil && p.Lon != nil && (p.Flags&FlagHasLocation != 0) {
		latE6 := int32(mathRound(*p.Lat * 1e6))
		lonE6 := int32(mathRound(*p.Lon * 1e6))
		binary.LittleEndian.PutUint32(buf[28:32], uint32(latE6))
		binary.LittleEndian.PutUint32(buf[32:36], uint32(lonE6))
	}

	buf[36] = p.TTL
	buf[37] = p.HopCount

	// Compute HMAC over bytes 0-35
	mac, err := ComputeHMAC(householdKey, buf[:36])
	if err != nil {
		return nil, err
	}
	copy(buf[38:46], mac[:])
	p.MAC = mac

	// Path
	for i, nodeID := range p.Path {
		binary.LittleEndian.PutUint16(buf[46+i*2:46+i*2+2], nodeID)
	}

	return buf, nil
}

// VerifyMAC checks if the packet's MAC matches HMAC-SHA256(householdKey, bytes 0..35)[0..8].
func (p *Packet) VerifyMAC(householdKey []byte, rawData []byte) bool {
	if len(rawData) < 36 {
		return false
	}
	expectedMAC, err := ComputeHMAC(householdKey, rawData[:36])
	if err != nil {
		return false
	}
	return hmac.Equal(p.MAC[:], expectedMAC[:])
}

// ComputeHMAC calculates the first 8 bytes of HMAC-SHA256 for bytes 0-35.
func ComputeHMAC(key []byte, payload []byte) ([8]byte, error) {
	var mac [8]byte
	if len(key) == 0 {
		return mac, errors.New("kunci rumah tangga tidak boleh kosong")
	}
	h := hmac.New(sha256.New, key)
	h.Write(payload)
	sum := h.Sum(nil)
	copy(mac[:], sum[:8])
	return mac, nil
}

// GenerateReportUUID generates deterministic UUIDv5 per SDD 7.2:
// id = UUIDv5(namespace WE-IRED, household_short_id + incident_short_id + seq)
func (p *Packet) GenerateReportUUID() uuid.UUID {
	data := fmt.Sprintf("%x:%d:%d", p.HouseholdShortID, p.IncidentShortID, p.Seq)
	return uuid.NewSHA1(NamespaceWEIred, []byte(data))
}

func mathRound(val float64) float64 {
	if val < 0 {
		return float64(int64(val - 0.5))
	}
	return float64(int64(val + 0.5))
}
