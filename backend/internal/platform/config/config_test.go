package config_test

import (
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/config"
)

func TestDefaultConfig(t *testing.T) {
	cfg := config.Default()
	require.NotNil(t, cfg)
	assert.Equal(t, config.ModeCloud, cfg.Mode)
	assert.Equal(t, config.RoleAll, cfg.Role)
	assert.Equal(t, ":8080", cfg.HTTPAddr)
	assert.Equal(t, "info", cfg.LogLevel)
	assert.Equal(t, []int{10, 25}, cfg.WAReminderMinutes)
	assert.Equal(t, 5*time.Minute, cfg.BMKGPollInterval)
	assert.NoError(t, cfg.Validate())
}

func TestParseEnvReader(t *testing.T) {
	content := `
# Comment at top
MODE=posko # inline comment
ROLE=all
HTTP_ADDR=":9090"
PUBLIC_BASE_URL='https://posko.we-ired.local'
WA_REMINDER_MINUTES=5,15,30
AI_ENABLED=true
`
	m, err := config.ParseEnvReader(strings.NewReader(content))
	require.NoError(t, err)
	assert.Equal(t, "posko", m["MODE"])
	assert.Equal(t, "all", m["ROLE"])
	assert.Equal(t, ":9090", m["HTTP_ADDR"])
	assert.Equal(t, "https://posko.we-ired.local", m["PUBLIC_BASE_URL"])
	assert.Equal(t, "5,15,30", m["WA_REMINDER_MINUTES"])
	assert.Equal(t, "true", m["AI_ENABLED"])
}

func TestConfigValidation(t *testing.T) {
	t.Run("InvalidMode", func(t *testing.T) {
		cfg := config.Default()
		cfg.Mode = "invalid_mode"
		err := cfg.Validate()
		require.Error(t, err)
		assert.Contains(t, err.Error(), "konfigurasi MODE tidak valid")
	})

	t.Run("InvalidRole", func(t *testing.T) {
		cfg := config.Default()
		cfg.Role = "invalid_role"
		err := cfg.Validate()
		require.Error(t, err)
		assert.Contains(t, err.Error(), "konfigurasi ROLE tidak valid")
	})

	t.Run("MissingHTTPAddr", func(t *testing.T) {
		cfg := config.Default()
		cfg.HTTPAddr = ""
		err := cfg.Validate()
		require.Error(t, err)
		assert.Contains(t, err.Error(), "HTTP_ADDR wajib diisi")
	})

	t.Run("MissingDatabaseURL", func(t *testing.T) {
		cfg := config.Default()
		cfg.DatabaseURL = ""
		err := cfg.Validate()
		require.Error(t, err)
		assert.Contains(t, err.Error(), "DATABASE_URL wajib diisi")
	})

	t.Run("ValidConfig", func(t *testing.T) {
		cfg := config.Default()
		assert.NoError(t, cfg.Validate())
	})
}
