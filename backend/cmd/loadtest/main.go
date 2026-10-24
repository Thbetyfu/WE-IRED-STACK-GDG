package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

type loadHouseholdProvider struct {
	households map[string]*report.HouseholdInfo
}

func (m *loadHouseholdProvider) GetHouseholdsInScope(ctx context.Context, rtID string, blockIDs []string) ([]*report.HouseholdInfo, error) {
	var res []*report.HouseholdInfo
	for _, h := range m.households {
		if h.RTID == rtID {
			res = append(res, h)
		}
	}
	return res, nil
}

func (m *loadHouseholdProvider) GetHouseholdInfo(ctx context.Context, id string) (*report.HouseholdInfo, error) {
	return m.households[id], nil
}

type staticIncidentProvider struct {
	rtMap map[string]string
}

func (p *staticIncidentProvider) GetIncidentRTID(ctx context.Context, incidentID string) (string, error) {
	if rt, ok := p.rtMap[incidentID]; ok {
		return rt, nil
	}
	return "rt-01", nil
}

type staticRegionChecker struct{}

func (c *staticRegionChecker) IsRTInRegion(ctx context.Context, rtID, regionID string) (bool, error) {
	return true, nil
}

func main() {
	numRTs := flag.Int("rts", 50, "Number of concurrent RTs")
	reportsPerRT := flag.Int("reports", 300, "Reports per RT")
	target := flag.String("target", "http", "Test target: 'http' (real HTTP server over TCP/loopback) or 'internal' (in-memory service benchmark)")
	mode := flag.String("mode", "sustained", "Execution mode: 'sustained' (rate-limited, e.g. 250 RPS = 15,000/min) or 'burst' (serentak)")
	targetRPS := flag.Int("rps", 250, "Target requests per second for sustained mode (default 250 = 15,000/min)")
	durationSec := flag.Int("duration", 5, "Duration in seconds for sustained test (default 5s = 1250 req, or set higher)")
	flag.Parse()

	jwtSecret := []byte("weired-loadtest-jwt-secret-key-32b!")
	ctx := context.Background()

	store := report.NewMemoryStore()
	hhMap := make(map[string]*report.HouseholdInfo)

	for rt := 1; rt <= *numRTs; rt++ {
		rtID := fmt.Sprintf("rt-%02d", rt)
		for hh := 1; hh <= *reportsPerRT; hh++ {
			hhID := fmt.Sprintf("hh-%s-%03d", rtID, hh)
			hhMap[hhID] = &report.HouseholdInfo{
				ID:              hhID,
				RTID:            rtID,
				BlockID:         "blok-a",
				Number:          fmt.Sprintf("No-%d", hh),
				HeadName:        fmt.Sprintf("Warga %d", hh),
				VulnerableCount: hh % 3,
			}
		}
	}

	hhProvider := &loadHouseholdProvider{households: hhMap}
	svc := report.NewService(store)
	svc.SetHouseholdProvider(hhProvider)

	// Pre-generate valid JWT token for authenticated HTTP submissions
	tokenString, _, err := auth.GenerateAccessToken(jwtSecret, auth.Claims{
		UserID:   "usr-relawan-loadtest",
		Phone:    "+6281299990001",
		Role:     "relawan",
		RegionID: "rt-01",
	})
	if err != nil {
		log.Fatalf("Failed to generate test JWT token: %v", err)
	}

	var testServer *httptest.Server
	var serverURL string
	httpClient := &http.Client{
		Timeout: 5 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        500,
			MaxIdleConnsPerHost: 500,
			IdleConnTimeout:     30 * time.Second,
		},
	}

	if *target == "http" {
		r := chi.NewRouter()
		incProvider := &staticIncidentProvider{rtMap: map[string]string{"inc-load-01": "rt-01"}}
		regChecker := &staticRegionChecker{}
		handler := report.NewHandler(svc, jwtSecret, regChecker, incProvider)
		handler.Routes(r)

		testServer = httptest.NewServer(r)
		defer testServer.Close()
		serverURL = testServer.URL
	}

	totalReports := *numRTs * *reportsPerRT
	if *mode == "sustained" {
		totalReports = *targetRPS * *durationSec
	}

	fmt.Printf("============================================================\n")
	fmt.Printf("  WE-IRED Empirical Load Benchmark (N-33 / NFR-PERF-01)\n")
	fmt.Printf("  Target Engine     : %s\n", *target)
	fmt.Printf("  Mode              : %s\n", *mode)
	if *mode == "sustained" {
		fmt.Printf("  Sustained Rate    : %d req/sec (equiv to %d reports/min)\n", *targetRPS, *targetRPS*60)
		fmt.Printf("  Duration          : %d detik (Total Planned: %d request)\n", *durationSec, totalReports)
	} else {
		fmt.Printf("  Burst Volume      : %d Laporan Serentak (50 RT x 300)\n", totalReports)
	}
	if *target == "http" {
		fmt.Printf("  HTTP Endpoint     : %s/incidents/{id}/reports\n", serverURL)
		fmt.Printf("  Auth              : Bearer JWT (HS256)\n")
		fmt.Printf("  Transport         : Real TCP Loopback Client\n")
	}
	fmt.Printf("============================================================\n\n")

	var (
		wg           sync.WaitGroup
		successCount atomic.Int64
		failureCount atomic.Int64
		latenciesMu  sync.Mutex
		latencies    = make([]time.Duration, 0, totalReports)
	)

	startTime := time.Now()

	if *mode == "sustained" {
		// Sustained constant-rate submission
		ticker := time.NewTicker(time.Second / time.Duration(*targetRPS))
		defer ticker.Stop()

		var reqID atomic.Int64
		for i := 0; i < totalReports; i++ {
			<-ticker.C
			wg.Add(1)
			go func(idx int64) {
				defer wg.Done()
				rtNum := int((idx % int64(*numRTs)) + 1)
				hhNum := int(((idx / int64(*numRTs)) % int64(*reportsPerRT)) + 1)
				rtID := fmt.Sprintf("rt-%02d", rtNum)
				hhID := fmt.Sprintf("hh-%s-%03d", rtID, hhNum)

				dur, ok := executeSingleReport(*target, serverURL, httpClient, tokenString, ctx, svc, rtID, hhID, int(idx))
				if ok {
					successCount.Add(1)
				} else {
					failureCount.Add(1)
				}
				latenciesMu.Lock()
				latencies = append(latencies, dur)
				latenciesMu.Unlock()
			}(reqID.Add(1))
		}
		wg.Wait()
	} else {
		// Burst mode across all RTs concurrently
		for rt := 1; rt <= *numRTs; rt++ {
			wg.Add(1)
			go func(rtIndex int) {
				defer wg.Done()
				rtID := fmt.Sprintf("rt-%02d", rtIndex)

				for hh := 1; hh <= *reportsPerRT; hh++ {
					hhID := fmt.Sprintf("hh-%s-%03d", rtID, hh)
					dur, ok := executeSingleReport(*target, serverURL, httpClient, tokenString, ctx, svc, rtID, hhID, hh)
					if ok {
						successCount.Add(1)
					} else {
						failureCount.Add(1)
					}
					latenciesMu.Lock()
					latencies = append(latencies, dur)
					latenciesMu.Unlock()
				}
			}(rt)
		}
		wg.Wait()
	}

	totalDuration := time.Since(startTime)

	sort.Slice(latencies, func(i, j int) bool {
		return latencies[i] < latencies[j]
	})

	if len(latencies) == 0 {
		log.Fatalf("No latencies recorded")
	}

	p50 := latencies[len(latencies)*50/100]
	p95 := latencies[len(latencies)*95/100]
	p99 := latencies[len(latencies)*99/100]
	maxLat := latencies[len(latencies)-1]
	rps := float64(successCount.Load()) / totalDuration.Seconds()

	fmt.Printf("[HASIL PENGUJIAN BEBAN EMPIRIS]\n")
	fmt.Printf("  - Target Teruji       : %s\n", *target)
	fmt.Printf("  - Total Sukses        : %d / %d (%.1f%%)\n", successCount.Load(), totalReports, float64(successCount.Load())*100.0/float64(totalReports))
	fmt.Printf("  - Total Gagal         : %d\n", failureCount.Load())
	fmt.Printf("  - Waktu Selesai Total : %v\n", totalDuration)
	fmt.Printf("  - Throughput Aktual   : %.2f requests/sec\n", rps)
	fmt.Printf("  - Latensi Klien p50   : %v\n", p50)
	fmt.Printf("  - Latensi Klien p95   : %v  [TARGET <= 500ms : %s]\n", p95, passFail(p95 <= 500*time.Millisecond))
	fmt.Printf("  - Latensi Klien p99   : %v\n", p99)
	fmt.Printf("  - Latensi Maksimum    : %v\n\n", maxLat)
}

func passFail(b bool) string {
	if b {
		return "PASS"
	}
	return "FAIL"
}

func executeSingleReport(
	target string,
	serverURL string,
	client *http.Client,
	token string,
	ctx context.Context,
	svc *report.Service,
	rtID string,
	hhID string,
	seq int,
) (time.Duration, bool) {
	st := report.StatusAman
	urg := report.UrgencyBiasa
	needs := 0

	r := rand.Float64()
	if r < 0.15 {
		st = report.StatusButuhBantuan
		urg = report.UrgencyKritis
		needs = report.NeedEvakuasi | report.NeedMedis
	} else if r < 0.50 {
		st = report.StatusButuhBantuan
		urg = report.UrgencyBiasa
		needs = report.NeedMakananAir
	}

	if target == "http" {
		payload := report.SubmitReportPayload{
			HouseholdID: hhID,
			Seq:         seq,
			Status:      st,
			Urgency:     urg,
			Needs:       needs,
			Channel:     report.ChannelAplikasi,
		}

		bodyBytes, _ := json.Marshal(payload)
		req, _ := http.NewRequestWithContext(ctx, "POST", serverURL+"/incidents/inc-load-01/reports", bytes.NewReader(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)

		t0 := time.Now()
		resp, err := client.Do(req)
		dur := time.Since(t0)

		if err != nil {
			return dur, false
		}
		defer resp.Body.Close()
		io.Copy(io.Discard, resp.Body)

		return dur, resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated
	}

	// Internal service execution
	rep := &report.Report{
		ID:          fmt.Sprintf("rep-%s-%03d-%d", rtID, seq, time.Now().UnixNano()),
		IncidentID:  "inc-load-01",
		HouseholdID: hhID,
		Seq:         seq,
		Status:      st,
		Urgency:     urg,
		Needs:       needs,
		Channel:     report.ChannelAplikasi,
		ReceivedAt:  time.Now().UTC(),
	}

	t0 := time.Now()
	res, err := svc.SubmitReport(ctx, rep)
	dur := time.Since(t0)

	return dur, err == nil && res != nil
}
