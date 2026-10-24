package report_test

import (
	"context"
	"fmt"
	"math/rand"
	"sort"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/report"
)

type mockHouseholdProviderForLoad struct {
	households map[string]*report.HouseholdInfo
}

func (m *mockHouseholdProviderForLoad) GetHouseholdsInScope(ctx context.Context, rtID string, blockIDs []string) ([]*report.HouseholdInfo, error) {
	var res []*report.HouseholdInfo
	for _, h := range m.households {
		if h.RTID == rtID {
			res = append(res, h)
		}
	}
	return res, nil
}

func (m *mockHouseholdProviderForLoad) GetHouseholdInfo(ctx context.Context, id string) (*report.HouseholdInfo, error) {
	return m.households[id], nil
}

// TestLoad300ReportsPerMin50RTs executes real load testing matching NFR-PERF-01 and NFR-PERF-02:
// 300 reports/minute/RT across 50 RTs = 15,000 reports total submitted concurrently.
func TestLoad300ReportsPerMin50RTs(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping intensive load benchmark in short mode")
	}

	ctx := context.Background()
	store := report.NewMemoryStore()
	hhMap := make(map[string]*report.HouseholdInfo)

	const numRTs = 50
	const reportsPerRT = 300
	const totalReports = numRTs * reportsPerRT // 15,000

	// Seed households for 50 RTs
	for rt := 1; rt <= numRTs; rt++ {
		rtID := fmt.Sprintf("rt-%02d", rt)
		for hh := 1; hh <= reportsPerRT; hh++ {
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

	hhProvider := &mockHouseholdProviderForLoad{households: hhMap}
	svc := report.NewService(store)
	svc.SetHouseholdProvider(hhProvider)

	incidentID := "inc-load-surge-50rt"

	// Concurrency execution: 50 concurrent worker routines simulating 50 RTs simultaneously
	var wg sync.WaitGroup
	var successCount atomic.Int64
	var failureCount atomic.Int64

	latencies := make([]time.Duration, totalReports)
	var latenciesMu sync.Mutex

	startTime := time.Now()

	for rt := 1; rt <= numRTs; rt++ {
		wg.Add(1)
		go func(rtIndex int) {
			defer wg.Done()
			rtID := fmt.Sprintf("rt-%02d", rtIndex)

			r := rand.New(rand.NewSource(int64(rtIndex * 1000)))

			for hh := 1; hh <= reportsPerRT; hh++ {
				hhID := fmt.Sprintf("hh-%s-%03d", rtID, hh)

				// Status distribution: 15% kritis, 35% butuh_bantuan, 50% aman
				roll := r.Float64()
				st := report.StatusAman
				urg := report.UrgencyBiasa
				needs := 0

				if roll < 0.15 {
					st = report.StatusButuhBantuan
					urg = report.UrgencyKritis
					needs = report.NeedEvakuasi | report.NeedMedis
				} else if roll < 0.50 {
					st = report.StatusButuhBantuan
					urg = report.UrgencyBiasa
					needs = report.NeedMakananAir
				}

				rep := &report.Report{
					ID:          fmt.Sprintf("rep-%s-%03d", rtID, hh),
					IncidentID:  incidentID,
					HouseholdID: hhID,
					Seq:         1,
					Status:      st,
					Urgency:     urg,
					Needs:       needs,
					Channel:     report.ChannelAplikasi,
					ReceivedAt:  time.Now().UTC(),
				}

				t0 := time.Now()
				res, err := svc.SubmitReport(ctx, rep)
				dur := time.Since(t0)

				if err == nil && res != nil {
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
	totalDuration := time.Since(startTime)

	// Filter and sort latencies to compute percentiles
	var validLatencies []time.Duration
	for _, l := range latencies {
		if l > 0 {
			validLatencies = append(validLatencies, l)
		}
	}

	sort.Slice(validLatencies, func(i, j int) bool {
		return validLatencies[i] < validLatencies[j]
	})

	require.NotEmpty(t, validLatencies)
	p50 := validLatencies[len(validLatencies)*50/100]
	p95 := validLatencies[len(validLatencies)*95/100]
	p99 := validLatencies[len(validLatencies)*99/100]
	maxLat := validLatencies[len(validLatencies)-1]

	effectiveRPS := float64(successCount.Load()) / totalDuration.Seconds()

	t.Logf("=== HASIL BENCHMARK BEBAN NFR-PERF (300 Laporan/menit x 50 RT) ===")
	t.Logf("Total Laporan Berhasil: %d / %d", successCount.Load(), totalReports)
	t.Logf("Total Gagal: %d", failureCount.Load())
	t.Logf("Total Waktu Eksekusi: %v", totalDuration)
	t.Logf("Throughput Efektif: %.2f requests/sec (RPS)", effectiveRPS)
	t.Logf("Latensi p50: %v", p50)
	t.Logf("Latensi p95: %v (Target NFR-PERF-01 <= 500ms)", p95)
	t.Logf("Latensi p99: %v", p99)
	t.Logf("Latensi Maksimal: %v", maxLat)

	// Assertions based on NFR-PERF-01 and NFR-REL-02
	assert.Equal(t, int64(totalReports), successCount.Load(), "All 15,000 reports must succeed")
	assert.Equal(t, int64(0), failureCount.Load(), "Zero failure rate")
	assert.Less(t, p95, 500*time.Millisecond, "NFR-PERF-01: p95 latency must be <= 500ms")
}
