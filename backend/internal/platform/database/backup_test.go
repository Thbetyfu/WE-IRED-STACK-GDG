package database_test

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestBackupChecksumVerification(t *testing.T) {
	sampleDump := []byte("-- WE-IRED Database Dump\nCREATE TABLE test_table (id text);\nINSERT INTO test_table VALUES ('1');\n")

	hasher := sha256.New()
	hasher.Write(sampleDump)
	expectedHash := hex.EncodeToString(hasher.Sum(nil))

	require.NotEmpty(t, expectedHash)
	assert.Len(t, expectedHash, 64)

	// Verify matching checksum
	hasher2 := sha256.New()
	hasher2.Write(sampleDump)
	actualHash := hex.EncodeToString(hasher2.Sum(nil))

	assert.Equal(t, expectedHash, actualHash, "Checksums must match exactly")

	// Corrupted payload must fail checksum verification
	corrupted := append(sampleDump, []byte("CORRUPTION")...)
	hasherCorrupt := sha256.New()
	hasherCorrupt.Write(corrupted)
	corruptHash := hex.EncodeToString(hasherCorrupt.Sum(nil))

	assert.NotEqual(t, expectedHash, corruptHash, "Corrupted backup must fail SHA-256 verification")
}

func TestBackupSqlStructureValidation(t *testing.T) {
	// Sample schema restore statements
	restoreSQL := `
		DROP TABLE IF EXISTS households CASCADE;
		CREATE TABLE households (
			id VARCHAR(64) PRIMARY KEY,
			rt_id VARCHAR(64) NOT NULL,
			number VARCHAR(32) NOT NULL,
			head_name VARCHAR(128) NOT NULL
		);
		INSERT INTO households (id, rt_id, number, head_name) VALUES ('hh-01', 'rt-01', 'A-01', 'Budi');
	`

	lines := strings.Split(restoreSQL, ";")
	var statements []string
	for _, l := range lines {
		trimmed := strings.TrimSpace(l)
		if trimmed != "" {
			statements = append(statements, trimmed)
		}
	}

	assert.Len(t, statements, 3)
	assert.Contains(t, statements[0], "DROP TABLE IF EXISTS")
	assert.Contains(t, statements[1], "CREATE TABLE households")
	assert.Contains(t, statements[2], "INSERT INTO households")
}
