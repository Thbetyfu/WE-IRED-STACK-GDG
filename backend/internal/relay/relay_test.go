package relay

import (
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"
	"time"
)

type TestVectorFile struct {
	Description string `json:"description"`
	TestCases   []struct {
		Name                 string   `json:"name"`
		Version              uint8    `json:"version"`
		Type                 uint8    `json:"type"`
		HouseholdShortIDHex  string   `json:"household_short_id_hex"`
		IncidentShortID      uint32   `json:"incident_short_id"`
		Seq                  uint32   `json:"seq"`
		CreatedAtUnix        int64    `json:"created_at_unix"`
		Status               uint8    `json:"status"`
		Urgency              uint8    `json:"urgency"`
		Needs                uint8    `json:"needs"`
		MemberMask           uint8    `json:"member_mask"`
		Battery              uint8    `json:"battery"`
		Flags                uint8    `json:"flags"`
		LatE6                int32    `json:"lat_e6"`
		LonE6                int32    `json:"lon_e6"`
		TTL                  uint8    `json:"ttl"`
		HopCount             uint8    `json:"hop_count"`
		HouseholdKeyHex      string   `json:"household_key_hex"`
		ExpectedMACHex       string   `json:"expected_mac_hex"`
		PathNodeIDs          []uint16 `json:"path_node_ids"`
		ExpectedPacketHex    string   `json:"expected_packet_hex"`
	} `json:"test_cases"`
}

func TestRelayCodecAgainstJoshuaTestVectors(t *testing.T) {
	data, err := os.ReadFile("../../../docs/test-vectors/relay_packet.json")
	if err != nil {
		t.Fatalf("failed to read test vector file: %v", err)
	}

	var vecFile TestVectorFile
	if err := json.Unmarshal(data, &vecFile); err != nil {
		t.Fatalf("failed to unmarshal test vector json: %v", err)
	}

	for _, tc := range vecFile.TestCases {
		t.Run(tc.Name, func(t *testing.T) {
			rawExpected, err := hex.DecodeString(tc.ExpectedPacketHex)
			if err != nil {
				t.Fatalf("invalid hex in test case: %v", err)
			}
			keyBytes, err := hex.DecodeString(tc.HouseholdKeyHex)
			if err != nil {
				t.Fatalf("invalid key hex: %v", err)
			}

			// 1. Decode test
			packet, err := Decode(rawExpected)
			if err != nil {
				t.Fatalf("Decode failed: %v", err)
			}

			if packet.Version != tc.Version {
				t.Fatalf("version mismatch: got %d, want %d", packet.Version, tc.Version)
			}
			if packet.Type != tc.Type {
				t.Fatalf("type mismatch: got %d, want %d", packet.Type, tc.Type)
			}
			if packet.IncidentShortID != tc.IncidentShortID {
				t.Fatalf("incident short id mismatch: got %d, want %d", packet.IncidentShortID, tc.IncidentShortID)
			}
			if packet.Seq != tc.Seq {
				t.Fatalf("seq mismatch: got %d, want %d", packet.Seq, tc.Seq)
			}
			if packet.CreatedAt.Unix() != tc.CreatedAtUnix {
				t.Fatalf("created_at mismatch: got %d, want %d", packet.CreatedAt.Unix(), tc.CreatedAtUnix)
			}
			if packet.Status != tc.Status {
				t.Fatalf("status mismatch: got %d, want %d", packet.Status, tc.Status)
			}
			if packet.Urgency != tc.Urgency {
				t.Fatalf("urgency mismatch: got %d, want %d", packet.Urgency, tc.Urgency)
			}
			if packet.Needs != tc.Needs {
				t.Fatalf("needs mismatch: got %d, want %d", packet.Needs, tc.Needs)
			}

			// 2. MAC verification
			if !packet.VerifyMAC(keyBytes, rawExpected) {
				t.Fatal("VerifyMAC returned false for valid packet and key")
			}

			// 3. Re-encode test
			encoded, err := packet.Encode(keyBytes)
			if err != nil {
				t.Fatalf("Encode failed: %v", err)
			}
			encodedHex := hex.EncodeToString(encoded)
			if encodedHex != tc.ExpectedPacketHex {
				t.Fatalf("re-encoded packet hex mismatch:\ngot:  %s\nwant: %s", encodedHex, tc.ExpectedPacketHex)
			}

			// 4. Test deterministic UUIDv5 generation
			uuidVal := packet.GenerateReportUUID()
			if uuidVal.Version() != 5 {
				t.Fatalf("expected UUIDv5, got version: %d", uuidVal.Version())
			}
		})
	}
}

func TestRelayCodecValidationErrors(t *testing.T) {
	// 1. Too short
	_, err := Decode([]byte{0x01, 0x01})
	if err != ErrPacketTooShort {
		t.Fatalf("expected ErrPacketTooShort, got: %v", err)
	}

	// 2. Invalid version
	shortPacket := make([]byte, PacketMinLength)
	shortPacket[0] = 0x02 // invalid version
	shortPacket[1] = 0x01
	_, err = Decode(shortPacket)
	if err != ErrInvalidVersion {
		t.Fatalf("expected ErrInvalidVersion, got: %v", err)
	}

	// 3. Invalid type
	shortPacket[0] = 0x01
	shortPacket[1] = 0x99 // invalid type
	_, err = Decode(shortPacket)
	if err != ErrInvalidType {
		t.Fatalf("expected ErrInvalidType, got: %v", err)
	}

	// 4. Invalid path length (odd byte length)
	oddPathPacket := make([]byte, PacketMinLength+3)
	oddPathPacket[0] = 0x01
	oddPathPacket[1] = 0x01
	_, err = Decode(oddPathPacket)
	if err != ErrInvalidPathLength {
		t.Fatalf("expected ErrInvalidPathLength, got: %v", err)
	}
}

func TestTamperedHMACRejection(t *testing.T) {
	p := &Packet{
		Version:         1,
		Type:            1,
		IncidentShortID: 999,
		Seq:             10,
		CreatedAt:       time.Now().UTC(),
		Status:          1,
	}
	key := []byte("secret-key-32-bytes-long-1234567")
	encoded, err := p.Encode(key)
	if err != nil {
		t.Fatalf("encode failed: %v", err)
	}

	// Tamper with payload byte (e.g. status)
	tampered := make([]byte, len(encoded))
	copy(tampered, encoded)
	tampered[22] = 3 // changed status from 1 to 3 without updating HMAC

	decoded, err := Decode(tampered)
	if err != nil {
		t.Fatalf("decode tampered failed: %v", err)
	}

	if decoded.VerifyMAC(key, tampered) {
		t.Fatal("expected VerifyMAC to fail for tampered packet")
	}
}
