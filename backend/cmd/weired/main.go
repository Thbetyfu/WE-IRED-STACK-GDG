package main

import (
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/ai"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/assembly"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/announcement"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/audit"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/household"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/incident"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/fcm"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/notify/whatsapp"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/posko"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/priority"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/realtime"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/recap"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
	weiredSync "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/sync"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/synthetic"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/task"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/volunteer"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/config"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/database"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/jobs"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/logger"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/metrics"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/ratelimit"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/server"
)

func main() {
	// Parse CLI flags
	var (
		envFileFlag = flag.String("config", ".env", "Path to .env configuration file")
		modeFlag    = flag.String("mode", "", "Execution mode: cloud or posko")
		roleFlag    = flag.String("role", "", "Execution role: api, worker, or all")
		migrateFlag = flag.Bool("migrate", false, "Run database migrations up before startup")
	)
	flag.Parse()

	// Load Configuration
	cfg, err := config.Load(*envFileFlag)
	if err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Override with CLI flags if provided
	if *modeFlag != "" {
		cfg.Mode = config.Mode(*modeFlag)
	}
	if *roleFlag != "" {
		cfg.Role = config.Role(*roleFlag)
	}
	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: invalid configuration: %v\n", err)
		os.Exit(1)
	}

	// Initialize Structured Logger
	log := logger.New(cfg.LogLevel, true)
	log.Info("initializing WE-IRED platform",
		"mode", cfg.Mode,
		"role", cfg.Role,
		"log_level", cfg.LogLevel,
	)

	// Context for application lifecycle
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle Graceful Termination Signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Initialize Database Pool
	var poolConfig = database.DefaultConfig(cfg.DatabaseURL)
	dbPool, err := database.NewPool(ctx, poolConfig)
	if err != nil {
		log.Warn("database connection pool initialization error", "error", err)
	} else {
		defer dbPool.Close()
		if pingErr := database.Ping(ctx, dbPool); pingErr != nil {
			log.Warn("database ping failed; running with degraded database state", "error", pingErr)
		} else {
			log.Info("connected to PostgreSQL successfully")
		}
	}

	// Run database migrations if requested
	if *migrateFlag && dbPool != nil {
		log.Info("running database migrations up...")
		// Use migration runner with db/migrations filesystem
		dirFS := os.DirFS("db")
		if err := database.RunMigrations(cfg.DatabaseURL, dirFS, "migrations"); err != nil {
			log.Error("database migration failure", "error", err)
			os.Exit(1)
		}
		log.Info("database migrations completed successfully")
	}

	// Initialize Job Queue
	var jobQueue jobs.Queue
	if dbPool != nil && database.Ping(ctx, dbPool) == nil {
		jobQueue = jobs.NewPGQueue(dbPool, 2*time.Second, 10)
	} else {
		log.Info("using in-memory job queue")
		jobQueue = jobs.NewMemoryQueue(200 * time.Millisecond)
	}

	// Start worker if role is 'worker' or 'all'
	if cfg.Role == config.RoleWorker || cfg.Role == config.RoleAll {
		log.Info("starting background job worker")
		if err := jobQueue.Start(ctx); err != nil {
			log.Error("failed to start job queue worker", "error", err)
		}
		defer jobQueue.Stop()
	}

	// Initialize Observability & Rate Limiter
	promMetrics := metrics.New()
	limiter := ratelimit.New(ratelimit.DefaultConfig())
	defer limiter.Close()

	// Initialize HTTP Server
	srv := server.New(server.Options{
		Config:  cfg,
		Logger:  log,
		Pool:    dbPool,
		Limiter: limiter,
		Metrics: promMetrics,
	})

	// Initialize Domain Services & Mount API Routes
	var authStore auth.Store
	var regionStore region.Store
	var householdStore household.Store
	var assemblyStore assembly.Store
	var volunteerStore volunteer.Store
	var incidentStore incident.Store
	var reportStore report.Store
	var taskStore task.Store
	var announcementStore announcement.Store
	var poskoStore posko.Store
	var whatsappStore whatsapp.Store
	var auditStore audit.Store
	var recapStore recap.Store

	if dbPool != nil && database.Ping(ctx, dbPool) == nil {
		authStore = auth.NewPostgresStore(dbPool)
		regionStore = region.NewPostgresStore(dbPool)
		householdStore = household.NewPostgresStore(dbPool)
		assemblyStore = assembly.NewPostgresStore(dbPool)
		volunteerStore = volunteer.NewPostgresStore(dbPool)
		incidentStore = incident.NewPostgresStore(dbPool)
		reportStore = report.NewPostgresStore(dbPool)
		taskStore = task.NewPostgresStore(dbPool)
		announcementStore = announcement.NewPostgresStore(dbPool)
		poskoStore = posko.NewPostgresStore(dbPool)
		whatsappStore = whatsapp.NewPostgresStore(dbPool)
		auditStore = audit.NewPostgresStore(dbPool)
		recapStore = recap.NewPostgresStore(dbPool)
	} else {
		log.Info("using in-memory domain stores")
		authStore = auth.NewMemoryStore()
		regionStore = region.NewMemoryStore()
		householdStore = household.NewMemoryStore()
		assemblyStore = assembly.NewMemoryStore()
		volunteerStore = volunteer.NewMemoryStore()
		incidentStore = incident.NewMemoryStore()
		reportStore = report.NewMemoryStore()
		taskStore = task.NewMemoryStore()
		announcementStore = announcement.NewMemoryStore()
		poskoStore = posko.NewMemoryStore()
		whatsappStore = whatsapp.NewMemoryStore()
		auditStore = audit.NewMemoryStore()
		recapStore = recap.NewMemoryStore()
	}

	authSvc := auth.NewService(authStore, []byte(cfg.JWTSecret), []byte(cfg.DataKey))
	authHandler := auth.NewHandler(authSvc)

	regionSvc := region.NewService(regionStore)
	regionHandler := region.NewHandler(regionSvc, []byte(cfg.JWTSecret))

	householdSvc := household.NewService(householdStore, []byte(cfg.DataKey))
	householdHandler := household.NewHandler(householdSvc, []byte(cfg.JWTSecret), regionSvc)

	assemblySvc := assembly.NewService(assemblyStore)
	assemblyHandler := assembly.NewHandler(assemblySvc, []byte(cfg.JWTSecret), regionSvc)

	volunteerSvc := volunteer.NewService(volunteerStore)
	volunteerHandler := volunteer.NewHandler(volunteerSvc, []byte(cfg.JWTSecret), regionSvc)

	incidentSvc := incident.NewService(incidentStore)
	reportSvc := report.NewService(reportStore)

	var eventStore realtime.EventStore
	if dbPool != nil && database.Ping(ctx, dbPool) == nil {
		eventStore = realtime.NewPostgresEventStore(dbPool)
	} else {
		eventStore = realtime.NewMemoryEventStore()
	}
	realtimeHub := realtime.NewHub(eventStore)

	// Cross-domain integrations
	hhAdapter := &householdAdapter{svc: householdSvc}
	reportSvc.SetHouseholdProvider(hhAdapter)
	incidentSvc.SetReportProvider(reportSvc)

	incAdapter := &incidentAdapter{svc: incidentSvc}
	incidentHandler := incident.NewHandler(incidentSvc, []byte(cfg.JWTSecret), regionSvc)
	reportHandler := report.NewHandler(reportSvc, []byte(cfg.JWTSecret), regionSvc, incAdapter)
	realtimeHandler := realtime.NewHandler(realtimeHub, []byte(cfg.JWTSecret), regionSvc, incAdapter)

	syncSvc := weiredSync.NewService(reportSvc, reportStore, householdStore, incidentStore, volunteerStore, realtimeHub, []byte(cfg.DataKey))
	syncHandler := weiredSync.NewHandler(syncSvc, []byte(cfg.JWTSecret))

	taskSvc := task.NewService(taskStore, reportStore, householdStore, volunteerStore, realtimeHub)
	taskHandler := task.NewHandler(taskSvc, []byte(cfg.JWTSecret), incAdapter)

	fcmClient := fcm.NewSimulatedClient()
	fcmSvc := fcm.NewService(fcmClient, log)

	keyManager, err := announcement.NewKeyManager(cfg.AnnounceSigningKey)
	if err != nil {
		log.Error("failed to initialize Ed25519 announcement key manager", "error", err)
		os.Exit(1)
	}

	announcementSvc := announcement.NewService(announcementStore, keyManager, fcmSvc, realtimeHub, log)
	announcementHandler := announcement.NewHandler(announcementSvc, []byte(cfg.JWTSecret), regionSvc)

	poskoSvc := posko.NewService(
		poskoStore,
		eventStore,
		householdStore,
		regionStore,
		volunteerStore,
		assemblyStore,
		reportSvc,
		taskSvc,
		keyManager,
		jobQueue,
		string(cfg.Mode),
		cfg.PoskoID,
		log,
	)
	poskoHandler := posko.NewHandler(poskoSvc, []byte(cfg.JWTSecret), regionSvc)

	// WhatsApp Cloud API Integration (SDD 10.1 & FR-WA)
	var waClient whatsapp.Client
	if cfg.WAPhoneNumberID != "" && cfg.WAAccessToken != "" {
		log.Info("configuring Meta WhatsApp Cloud API client")
		waClient = whatsapp.NewMetaCloudClient(cfg.WAPhoneNumberID, cfg.WAAccessToken)
	} else {
		log.Info("using simulated WhatsApp Cloud API client")
		waClient = whatsapp.NewSimulatedClient()
	}

	whatsappSvc := whatsapp.NewService(
		waClient,
		whatsappStore,
		householdStore,
		incidentStore,
		reportStore,
		reportSvc,
		jobQueue,
		log,
	)
	// Unified OTP Provider across platform
	authSvc.SetOTPProvider(whatsappSvc)

	// Register WhatsApp Reminder worker job handler
	if jobQueue != nil {
		jobQueue.RegisterHandler("wa_reminder", func(ctx context.Context, j *jobs.Job) error {
			var p struct {
				IncidentID string `json:"incident_id"`
				Step       string `json:"step"`
				Minutes    int    `json:"minutes"`
			}
			if err := jobs.UnmarshalPayload(j.Payload, &p); err != nil {
				return err
			}
			return whatsappSvc.ProcessReminderJob(ctx, p.IncidentID, p.Step, p.Minutes)
		})
	}

	whatsappHandler := whatsapp.NewHandler(whatsappSvc, cfg.WAVerifyToken, cfg.WAAppSecret, []byte(cfg.JWTSecret))

	taskAdapter := &taskCheckerAdapter{store: taskStore}
	priorityRecalculator := priority.NewRecalculator(householdStore, reportStore, incidentStore, taskAdapter, realtimeHub)
	if cfg.Role == config.RoleWorker || cfg.Role == config.RoleAll {
		log.Info("starting periodic priority recalculator runner (60s)")
		priorityRecalculator.StartPeriodicRunner(ctx, 60*time.Second)
	}

	auditSvc := audit.NewService(auditStore)
	auditHandler := audit.NewHandler(auditSvc, []byte(cfg.JWTSecret), regionSvc)

	recapSvc := recap.NewService(recapStore, incidentStore, householdStore, reportStore, taskStore, regionStore, auditSvc, whatsappSvc)
	recapHandler := recap.NewHandler(recapSvc, []byte(cfg.JWTSecret), regionSvc)

	syntheticGen := synthetic.NewGenerator(regionStore, householdStore, volunteerStore, assemblyStore, incidentStore, reportSvc)
	syntheticHandler := synthetic.NewHandler(syntheticGen, []byte(cfg.JWTSecret), regionSvc)

	// Initialize LLM Provider & AI Assistant (SDD 10.4 & FR-AI)
	var llmProvider ai.LLMProvider
	if cfg.Mode == config.ModeCloud && cfg.GeminiAPIKey != "" {
		log.Info("configuring Gemini LLM provider for cloud mode", "model", cfg.GeminiModel)
		llmProvider = ai.NewGeminiProvider(cfg.GeminiAPIKey, cfg.GeminiModel, 20*time.Second)
	} else if cfg.OllamaURL != "" {
		log.Info("configuring Ollama LLM provider", "url", cfg.OllamaURL, "model", cfg.OllamaModel)
		llmProvider = ai.NewOllamaProvider(cfg.OllamaURL, cfg.OllamaModel, 20*time.Second)
	} else {
		log.Info("using simulated fake LLM provider")
		llmProvider = ai.NewFakeProvider()
	}

	aiAnonymizer := ai.NewAnonymizer()
	aiSvc := ai.NewService(llmProvider, regionStore, aiAnonymizer, auditSvc)
	aiHandler := ai.NewHandler(aiSvc, []byte(cfg.JWTSecret), regionSvc)

	srv.MountAPI(func(r chi.Router) {
		authHandler.Routes(r)
		regionHandler.Routes(r)
		householdHandler.Routes(r)
		assemblyHandler.Routes(r)
		volunteerHandler.Routes(r)
		incidentHandler.Routes(r)
		reportHandler.Routes(r)
		realtimeHandler.Routes(r)
		syncHandler.Routes(r)
		taskHandler.Routes(r)
		announcementHandler.Routes(r)
		poskoHandler.Routes(r)
		whatsappHandler.Routes(r)
		auditHandler.Routes(r)
		recapHandler.Routes(r)
		syntheticHandler.Routes(r)
		aiHandler.Routes(r)
	})

	// Also support direct root webhook endpoints for Meta WhatsApp webhook verification
	srv.Router().Get("/webhook/whatsapp", whatsappHandler.HandleVerifyWebhook)
	srv.Router().Post("/webhook/whatsapp", whatsappHandler.HandleReceiveWebhook)

	// Posko Lokal Mode: Initialize self-signed HTTPS certificate (FR-PSK-04 & NFR-SEC-01)
	if cfg.Mode == config.ModePosko {
		cert, fp, err := posko.GenerateSelfSignedCert([]string{"localhost", "127.0.0.1"})
		if err != nil {
			log.Warn("failed to generate posko self-signed TLS cert; continuing with plain HTTP", "error", err)
		} else {
			log.Info("posko local mode enabled with self-signed TLS", "fingerprint", fp)
			srv.SetTLSConfig(&tls.Config{
				Certificates: []tls.Certificate{cert},
				MinVersion:   tls.VersionTLS12,
			})
		}
	}

	// Start HTTP Server in background if role is 'api' or 'all'
	if cfg.Role == config.RoleAPI || cfg.Role == config.RoleAll {
		go func() {
			if err := srv.Start(); err != nil {
				log.Error("http server stopped unexpectedly", "error", err)
				cancel()
			}
		}()
	}

	// Block until signal received
	select {
	case sig := <-sigChan:
		log.Info("received shutdown signal", "signal", sig.String())
	case <-ctx.Done():
		log.Info("context cancelled, shutting down")
	}

	// Graceful Shutdown with Timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if cfg.Role == config.RoleAPI || cfg.Role == config.RoleAll {
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Error("error during server graceful shutdown", "error", err)
		} else {
			log.Info("http server gracefully stopped")
		}
	}

	log.Info("WE-IRED platform stopped cleanly")
}

type householdAdapter struct {
	svc *household.Service
}

func (a *householdAdapter) GetHouseholdsInScope(ctx context.Context, rtID string, blockIDs []string) ([]*report.HouseholdInfo, error) {
	var results []*report.HouseholdInfo
	if len(blockIDs) == 0 {
		list, err := a.svc.ListHouseholds(ctx, rtID, nil)
		if err != nil {
			return nil, err
		}
		for _, h := range list {
			results = append(results, convertHousehold(h))
		}
		return results, nil
	}

	for _, bID := range blockIDs {
		bidCopy := bID
		list, err := a.svc.ListHouseholds(ctx, rtID, &bidCopy)
		if err != nil {
			return nil, err
		}
		for _, h := range list {
			results = append(results, convertHousehold(h))
		}
	}
	return results, nil
}

func (a *householdAdapter) GetHouseholdInfo(ctx context.Context, id string) (*report.HouseholdInfo, error) {
	h, err := a.svc.GetHousehold(ctx, id, "pengurus", nil, nil)
	if err != nil {
		return nil, err
	}
	return convertHousehold(h), nil
}

func convertHousehold(h *household.Household) *report.HouseholdInfo {
	if h == nil {
		return nil
	}
	vuln := 0
	for _, m := range h.Members {
		if m.VulnFlags > 0 || m.NeedsEvacAssist {
			vuln++
		}
	}
	blockID := ""
	if h.BlockID != nil {
		blockID = *h.BlockID
	}
	return &report.HouseholdInfo{
		ID:              h.ID,
		RTID:            h.RTID,
		BlockID:         blockID,
		Number:          h.Number,
		Address:         h.Address,
		Lat:             h.Lat,
		Lon:             h.Lon,
		HeadName:        h.HeadName,
		WAPhone:         h.WAPhone,
		HasDevice:       h.HasDevice,
		VulnerableCount: vuln,
	}
}

type incidentAdapter struct {
	svc *incident.Service
}

func (a *incidentAdapter) GetIncidentRTID(ctx context.Context, incidentID string) (string, error) {
	inc, err := a.svc.GetIncident(ctx, incidentID)
	if err != nil {
		return "", err
	}
	return inc.RTID, nil
}

type taskCheckerAdapter struct {
	store task.Store
}

func (a *taskCheckerAdapter) HasActiveTask(ctx context.Context, incidentID, householdID string) (bool, error) {
	t, err := a.store.GetActiveTaskForHousehold(ctx, incidentID, householdID)
	return t != nil, err
}
