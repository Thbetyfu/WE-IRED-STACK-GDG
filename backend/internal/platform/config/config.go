package config

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

// Mode determines where the backend is running.
type Mode string

const (
	ModeCloud Mode = "cloud"
	ModePosko Mode = "posko"
)

// Role determines what subsystems the binary runs.
type Role string

const (
	RoleAPI    Role = "api"
	RoleWorker Role = "worker"
	RoleAll    Role = "all"
)

// Config holds all platform configurations loaded from environment variables or .env.
type Config struct {
	Mode               Mode          `json:"mode"`
	Role               Role          `json:"role"`
	HTTPAddr           string        `json:"http_addr"`
	PublicBaseURL      string        `json:"public_base_url"`
	LogLevel           string        `json:"log_level"`
	DatabaseURL        string        `json:"-"` // sensitive
	JWTSecret          string        `json:"-"` // sensitive
	DataKey            string        `json:"-"` // sensitive
	AnnounceSigningKey string        `json:"-"` // sensitive
	WAPhoneNumberID    string        `json:"wa_phone_number_id"`
	WAAccessToken      string        `json:"-"` // sensitive
	WAAppSecret        string        `json:"-"` // sensitive
	WAVerifyToken      string        `json:"-"` // sensitive
	WAReminderMinutes  []int         `json:"wa_reminder_minutes"`
	FCMCredentialsFile string        `json:"fcm_credentials_file"`
	AIEnabled          bool          `json:"ai_enabled"`
	OllamaURL          string        `json:"ollama_url"`
	OllamaModel        string        `json:"ollama_model"`
	GeminiAPIKey       string        `json:"-"` // sensitive
	GeminiModel        string        `json:"gemini_model"`
	BMKGPollInterval   time.Duration `json:"bmkg_poll_interval"`
	PoskoID            string        `json:"posko_id"`
	CloudSyncURL       string        `json:"cloud_sync_url"`
}

// Default returns a Config initialized with sensible defaults according to SDD and .env.example.
func Default() *Config {
	return &Config{
		Mode:              ModeCloud,
		Role:              RoleAll,
		HTTPAddr:          ":8080",
		LogLevel:          "info",
		DatabaseURL:       "postgres://weired:weired@localhost:5432/weired?sslmode=disable",
		WAReminderMinutes: []int{10, 25},
		BMKGPollInterval:  5 * time.Minute,
		OllamaURL:         "http://localhost:11434",
	}
}

// Load reads configuration by first populating defaults, optionally reading an .env file,
// and finally overriding with process environment variables.
func Load(envPath string) (*Config, error) {
	cfg := Default()

	// If envPath is specified and exists, parse it into process env or a map
	if envPath != "" {
		if file, err := os.Open(envPath); err == nil {
			defer file.Close()
			if envMap, parseErr := ParseEnvReader(file); parseErr == nil {
				for k, v := range envMap {
					// only set if not already present in environment
					if _, exists := os.LookupEnv(k); !exists {
						_ = os.Setenv(k, v)
					}
				}
			}
		}
	}

	// Apply environment variables
	if v := os.Getenv("MODE"); v != "" {
		cfg.Mode = Mode(strings.ToLower(strings.TrimSpace(v)))
	}
	if v := os.Getenv("ROLE"); v != "" {
		cfg.Role = Role(strings.ToLower(strings.TrimSpace(v)))
	}
	if v := os.Getenv("HTTP_ADDR"); v != "" {
		cfg.HTTPAddr = strings.TrimSpace(v)
	}
	if v := os.Getenv("PUBLIC_BASE_URL"); v != "" {
		cfg.PublicBaseURL = strings.TrimRight(strings.TrimSpace(v), "/")
	}
	if v := os.Getenv("LOG_LEVEL"); v != "" {
		cfg.LogLevel = strings.ToLower(strings.TrimSpace(v))
	}
	if v := os.Getenv("DATABASE_URL"); v != "" {
		cfg.DatabaseURL = strings.TrimSpace(v)
	}
	if v := os.Getenv("JWT_SECRET"); v != "" {
		cfg.JWTSecret = strings.TrimSpace(v)
	}
	if v := os.Getenv("DATA_KEY"); v != "" {
		cfg.DataKey = strings.TrimSpace(v)
	}
	if v := os.Getenv("ANNOUNCE_SIGNING_KEY"); v != "" {
		cfg.AnnounceSigningKey = strings.TrimSpace(v)
	}

	// WhatsApp
	if v := os.Getenv("WA_PHONE_NUMBER_ID"); v != "" {
		cfg.WAPhoneNumberID = strings.TrimSpace(v)
	}
	if v := os.Getenv("WA_ACCESS_TOKEN"); v != "" {
		cfg.WAAccessToken = strings.TrimSpace(v)
	}
	if v := os.Getenv("WA_APP_SECRET"); v != "" {
		cfg.WAAppSecret = strings.TrimSpace(v)
	}
	if v := os.Getenv("WA_VERIFY_TOKEN"); v != "" {
		cfg.WAVerifyToken = strings.TrimSpace(v)
	}
	if v := os.Getenv("WA_REMINDER_MINUTES"); v != "" {
		parts := strings.Split(v, ",")
		var mins []int
		for _, p := range parts {
			if m, err := strconv.Atoi(strings.TrimSpace(p)); err == nil {
				mins = append(mins, m)
			}
		}
		if len(mins) > 0 {
			cfg.WAReminderMinutes = mins
		}
	}

	// FCM
	if v := os.Getenv("FCM_CREDENTIALS_FILE"); v != "" {
		cfg.FCMCredentialsFile = strings.TrimSpace(v)
	}

	// AI
	if v := os.Getenv("AI_ENABLED"); v != "" {
		cfg.AIEnabled = strings.EqualFold(strings.TrimSpace(v), "true") || strings.TrimSpace(v) == "1"
	}
	if v := os.Getenv("OLLAMA_URL"); v != "" {
		cfg.OllamaURL = strings.TrimRight(strings.TrimSpace(v), "/")
	}
	if v := os.Getenv("OLLAMA_MODEL"); v != "" {
		cfg.OllamaModel = strings.TrimSpace(v)
	}
	if v := os.Getenv("GEMINI_API_KEY"); v != "" {
		cfg.GeminiAPIKey = strings.TrimSpace(v)
	}
	if v := os.Getenv("GEMINI_MODEL"); v != "" {
		cfg.GeminiModel = strings.TrimSpace(v)
	}

	// BMKG
	if v := os.Getenv("BMKG_POLL_INTERVAL"); v != "" {
		if d, err := time.ParseDuration(strings.TrimSpace(v)); err == nil {
			cfg.BMKGPollInterval = d
		}
	}

	// Posko
	if v := os.Getenv("POSKO_ID"); v != "" {
		cfg.PoskoID = strings.TrimSpace(v)
	}
	if v := os.Getenv("CLOUD_SYNC_URL"); v != "" {
		cfg.CloudSyncURL = strings.TrimRight(strings.TrimSpace(v), "/")
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// Validate checks the configuration constraints and returns informative error messages
// if mandatory configurations are missing or invalid.
func (c *Config) Validate() error {
	if c.Mode != ModeCloud && c.Mode != ModePosko {
		return fmt.Errorf("konfigurasi MODE tidak valid: %q (nilai yang didukung: 'cloud' atau 'posko')", c.Mode)
	}
	if c.Role != RoleAPI && c.Role != RoleWorker && c.Role != RoleAll {
		return fmt.Errorf("konfigurasi ROLE tidak valid: %q (nilai yang didukung: 'api', 'worker', atau 'all')", c.Role)
	}
	if strings.TrimSpace(c.HTTPAddr) == "" {
		return fmt.Errorf("konfigurasi HTTP_ADDR wajib diisi (contoh: ':8080')")
	}
	if strings.TrimSpace(c.DatabaseURL) == "" {
		return fmt.Errorf("konfigurasi DATABASE_URL wajib diisi untuk koneksi PostgreSQL (contoh: 'postgres://weired:weired@localhost:5432/weired?sslmode=disable')")
	}
	return nil
}

// ParseEnvReader parses key-value pairs from an io.Reader formatted like a .env file.
func ParseEnvReader(r io.Reader) (map[string]string, error) {
	result := make(map[string]string)
	scanner := bufio.NewScanner(r)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])

		// Strip inline comment if not quoted
		if !strings.HasPrefix(val, "\"") && !strings.HasPrefix(val, "'") {
			if idx := strings.Index(val, "#"); idx != -1 {
				val = strings.TrimSpace(val[:idx])
			}
		}

		// Strip surrounding single or double quotes
		if (strings.HasPrefix(val, "\"") && strings.HasSuffix(val, "\"")) ||
			(strings.HasPrefix(val, "'") && strings.HasSuffix(val, "'")) {
			if len(val) >= 2 {
				val = val[1 : len(val)-1]
			}
		}

		result[key] = val
	}

	return result, scanner.Err()
}
