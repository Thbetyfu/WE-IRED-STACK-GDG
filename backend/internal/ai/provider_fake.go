package ai

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"
)

// FakeProvider provides a mock/spy implementation of LLMProvider for deterministic unit tests,
// verifying privacy invariants, and allowing execution without external network or API keys.
type FakeProvider struct {
	mu sync.Mutex

	// Counters and recordings for test assertions
	SummarizeCalls     int
	ClassifyNeedsCalls int
	DraftRecapCalls    int

	LastSummarizeMsgs  []AnonMessage
	LastClassifyText   string
	LastDraftRecapData *RecapAggregate

	// Injected behaviors
	ForceError   error
	CustomDraft  string
	ForceTimeout bool
}

func NewFakeProvider() *FakeProvider {
	return &FakeProvider{}
}

func (p *FakeProvider) Name() string {
	return "fake"
}

func (p *FakeProvider) Summarize(ctx context.Context, msgs []AnonMessage) (*Summary, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.SummarizeCalls++
	p.LastSummarizeMsgs = msgs

	if p.ForceTimeout {
		return nil, ErrProviderTimeout
	}
	if p.ForceError != nil {
		return nil, p.ForceError
	}
	if len(msgs) == 0 {
		return nil, ErrEmptyInput
	}

	pointsByBlock := make(map[string][]string)
	for _, m := range msgs {
		blk := m.BlockID
		if blk == "" {
			blk = "A"
		}
		pointsByBlock[blk] = append(pointsByBlock[blk], fmt.Sprintf("Warga melaporkan: %s", m.Text))
	}

	return &Summary{
		PointsByBlock:  pointsByBlock,
		OverallSummary: fmt.Sprintf("Ringkasan situasi mencakup %d laporan warga terdistribusi di %d blok.", len(msgs), len(pointsByBlock)),
		AIAssisted:     true,
		Label:          AILabel,
		GeneratedAt:    time.Now().UTC(),
	}, nil
}

func (p *FakeProvider) ClassifyNeeds(ctx context.Context, text string) (*NeedsSuggestion, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.ClassifyNeedsCalls++
	p.LastClassifyText = text

	if p.ForceTimeout {
		return nil, ErrProviderTimeout
	}
	if p.ForceError != nil {
		return nil, p.ForceError
	}
	if strings.TrimSpace(text) == "" {
		return nil, ErrEmptyInput
	}

	lower := strings.ToLower(text)
	var needs []string
	urgency := "biasa"
	hasVuln := false

	if strings.Contains(lower, "perahu") || strings.Contains(lower, "evakuasi") || strings.Contains(lower, "sepinggang") || strings.Contains(lower, "terjebak") {
		needs = append(needs, "evakuasi")
		urgency = "kritis"
	}
	if strings.Contains(lower, "medis") || strings.Contains(lower, "kondisi_medis") || strings.Contains(lower, "obat") || strings.Contains(lower, "p3k") {
		needs = append(needs, "medis")
		urgency = "kritis"
	}
	if strings.Contains(lower, "makanan") || strings.Contains(lower, "air") || strings.Contains(lower, "lapar") {
		needs = append(needs, "makanan_air")
	}
	if strings.Contains(lower, "hunian") || strings.Contains(lower, "tenda") {
		needs = append(needs, "tempat_tinggal")
	}
	if strings.Contains(lower, "lansia") || strings.Contains(lower, "balita") || strings.Contains(lower, "kakek") || strings.Contains(lower, "nenek") || strings.Contains(lower, "rentan") {
		hasVuln = true
	}

	if len(needs) == 0 {
		needs = append(needs, "lainnya")
	}

	return &NeedsSuggestion{
		Needs:         needs,
		NeedsMask:     calculateNeedsMask(needs),
		Urgency:       urgency,
		HasVulnerable: hasVuln,
		Confidence:    0.92,
		Reasoning:     "Klasifikasi otomatis berbasis analisis kata kunci anonim.",
		AIAssisted:    true,
		Label:         AILabel,
		GeneratedAt:   time.Now().UTC(),
	}, nil
}

func (p *FakeProvider) DraftRecap(ctx context.Context, data RecapAggregate) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.DraftRecapCalls++
	dataCopy := data
	p.LastDraftRecapData = &dataCopy

	if p.ForceTimeout {
		return "", ErrProviderTimeout
	}
	if p.ForceError != nil {
		return "", p.ForceError
	}

	if p.CustomDraft != "" {
		return p.CustomDraft, nil
	}

	return fmt.Sprintf(
		"Ringkasan Operasi Tanggap Bencana %s di %s (%s). Durasi tanggap darurat berlangsung selama %s dengan partisipasi %d KK. "+
			"Kondisi warga: %d KK aman di rumah, %d KK berada di titik kumpul, dan %d KK memerlukan bantuan darurat. "+
			"Intervensi kebutuhan meliputi %d evakuasi fisik dan %d penanganan medis/P3K. Tingkat keterjangkauan warga rentan mencapai %.1f%% "+
			"(%d dari %d jiwa warga rentan terdata).",
		strings.ToUpper(data.Hazard), data.RTName, data.KelurahanName, data.Duration,
		data.TotalHouseholds, data.SafeHouseholds, data.ShelterHouseholds, data.NeedHelpHouseholds,
		data.NeedsEvakuasi, data.NeedsMedis, data.VulnerablePercentage, data.VulnerableReached, data.VulnerableCount,
	), nil
}
