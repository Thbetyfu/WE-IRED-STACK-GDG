package database_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/database"
)

func TestDefaultConfig(t *testing.T) {
	cfg := database.DefaultConfig("postgres://weired:weired@localhost:5432/weired")
	assert.Equal(t, int32(25), cfg.MaxConns)
	assert.Equal(t, int32(5), cfg.MinConns)
	assert.Equal(t, 5*time.Minute, cfg.MaxConnIdleTime)
	assert.Equal(t, 1*time.Hour, cfg.MaxConnLifetime)
}

func TestNewPoolInvalidURL(t *testing.T) {
	ctx := context.Background()

	// Empty URL
	_, err := database.NewPool(ctx, database.Config{DatabaseURL: ""})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "database URL cannot be empty")

	// Malformed URL
	_, err = database.NewPool(ctx, database.Config{DatabaseURL: "not_a_valid_postgres_url://@:/"})
	require.Error(t, err)
}

func TestPingNilPool(t *testing.T) {
	ctx := context.Background()
	err := database.Ping(ctx, nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not initialized")
}

func TestMigrationFilesValid(t *testing.T) {
	// Verify that the migration files exist and can be read by fs.FS
	dirFS := os.DirFS("../../../db")
	upBytes, err := os.ReadFile("../../../db/migrations/000001_init_platform.up.sql")
	require.NoError(t, err)
	assert.Contains(t, string(upBytes), "CREATE TABLE IF NOT EXISTS jobs")
	assert.Contains(t, string(upBytes), "CREATE TABLE IF NOT EXISTS events")

	downBytes, err := os.ReadFile("../../../db/migrations/000001_init_platform.down.sql")
	require.NoError(t, err)
	assert.Contains(t, string(downBytes), "DROP TABLE IF EXISTS jobs")
	assert.Contains(t, string(downBytes), "DROP TABLE IF EXISTS events")

	// Ensure dirFS opens migrations directory without error
	f, err := dirFS.Open("migrations")
	require.NoError(t, err)
	_ = f.Close()
}
