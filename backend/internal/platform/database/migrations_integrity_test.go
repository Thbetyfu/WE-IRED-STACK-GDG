package database_test

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestMigrationFilesIntegrity tests all 9 migration pairs for SDD 9 and NFR-REL compliance.
func TestMigrationFilesIntegrity(t *testing.T) {
	migrationsDir := filepath.Join("..", "..", "..", "db", "migrations")
	entries, err := os.ReadDir(migrationsDir)
	require.NoError(t, err, "Migrations directory must exist and be readable")

	upFiles := make(map[int]string)
	downFiles := make(map[int]string)

	re := regexp.MustCompile(`^(\d{6})_(\w+)\.(up|down)\.sql$`)

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		matches := re.FindStringSubmatch(name)
		if len(matches) == 4 {
			var num int
			_, err := fmt.Sscanf(matches[1], "%d", &num)
			require.NoError(t, err)

			if matches[3] == "up" {
				upFiles[num] = name
			} else {
				downFiles[num] = name
			}
		}
	}

	// We have 9 planned migration versions
	assert.GreaterOrEqual(t, len(upFiles), 9, "Must have at least 9 migrations")
	assert.Equal(t, len(upFiles), len(downFiles), "Each up migration must have a corresponding down migration")

	for i := 1; i <= len(upFiles); i++ {
		upName, ok := upFiles[i]
		require.True(t, ok, "Migration %06d.up.sql must exist", i)
		downName, ok := downFiles[i]
		require.True(t, ok, "Migration %06d.down.sql must exist", i)

		// Read UP SQL
		upPath := filepath.Join(migrationsDir, upName)
		upContent, err := os.ReadFile(upPath)
		require.NoError(t, err)
		assert.NotEmpty(t, upContent, "Migration %s cannot be empty", upName)

		// Read DOWN SQL
		downPath := filepath.Join(migrationsDir, downName)
		downContent, err := os.ReadFile(downPath)
		require.NoError(t, err)
		assert.NotEmpty(t, downContent, "Migration %s cannot be empty", downName)

		// Check for CREATE TABLE in UP and DROP TABLE in DOWN
		upStr := string(upContent)
		downStr := string(downContent)

		if strings.Contains(upStr, "CREATE TABLE") {
			assert.Contains(t, downStr, "DROP TABLE", "Down migration %s must contain DROP TABLE to rollback %s", downName, upName)
		}
	}
}

func TestCoreTableSchemasDeclared(t *testing.T) {
	migrationsDir := filepath.Join("..", "..", "..", "db", "migrations")

	requiredTables := []string{
		"jobs",
		"events",
		"regions",
		"users",
		"households",
		"blocks",
		"members",
		"consents",
		"assembly_points",
		"incidents",
		"reports",
		"household_states",
		"tasks",
		"announcements",
		"posko_delegations",
		"sync_conflicts",
		"notifications",
		"recaps",
		"audit_logs",
	}

	// Read all up migrations
	allSQL := ""
	for i := 1; i <= 9; i++ {
		matches, err := filepath.Glob(filepath.Join(migrationsDir, fmt.Sprintf("%06d_*.up.sql", i)))
		require.NoError(t, err)
		require.NotEmpty(t, matches)
		data, err := os.ReadFile(matches[0])
		require.NoError(t, err)
		allSQL += "\n" + string(data)
	}

	for _, tbl := range requiredTables {
		pattern := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s", tbl)
		assert.Contains(t, allSQL, pattern, "Migration files must define table: %s", tbl)
	}
}
