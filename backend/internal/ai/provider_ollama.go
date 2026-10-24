package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

type OllamaProvider struct {
	baseURL    string
	model      string
	httpClient *http.Client
}

func NewOllamaProvider(baseURL, model string, timeout time.Duration) *OllamaProvider {
	if baseURL == "" {
		baseURL = "http://localhost:11434"
	}
	if model == "" {
		model = "qwen2.5:3b"
	}
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	return &OllamaProvider{
		baseURL: strings.TrimRight(baseURL, "/"),
		model:   model,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

func (p *OllamaProvider) Name() string {
	return "ollama"
}

type ollamaGenerateRequest struct {
	Model  string `json:"model"`
	Prompt string `json:"prompt"`
	Stream bool   `json:"stream"`
	Format string `json:"format,omitempty"`
}

type ollamaGenerateResponse struct {
	Response string `json:"response"`
	Done     bool   `json:"done"`
	Error    string `json:"error,omitempty"`
}

func (p *OllamaProvider) callOllama(ctx context.Context, prompt string, jsonFormat bool) (string, error) {
	reqBody := ollamaGenerateRequest{
		Model:  p.model,
		Prompt: prompt,
		Stream: false,
	}
	if jsonFormat {
		reqBody.Format = "json"
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/api/generate", bytes.NewReader(bodyBytes))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		var netErr net.Error
		if errors.As(err, &netErr) && netErr.Timeout() {
			return "", ErrProviderTimeout
		}
		return "", fmt.Errorf("%w: %v", ErrProviderUnavailable, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("%w: HTTP %d %s", ErrProviderUnavailable, resp.StatusCode, string(raw))
	}

	var ollamaResp ollamaGenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&ollamaResp); err != nil {
		return "", fmt.Errorf("%w: failed to parse ollama json: %v", ErrInvalidModelResponse, err)
	}

	if ollamaResp.Error != "" {
		return "", fmt.Errorf("%w: ollama error: %s", ErrInvalidModelResponse, ollamaResp.Error)
	}

	return strings.TrimSpace(ollamaResp.Response), nil
}

func (p *OllamaProvider) Summarize(ctx context.Context, msgs []AnonMessage) (*Summary, error) {
	if len(msgs) == 0 {
		return nil, ErrEmptyInput
	}

	var sb strings.Builder
	sb.WriteString("Anda adalah Asisten Operasi Tanggap Bencana RT. Ringkas pesan warga yang telah dianonimkan berikut ke dalam format JSON.\n")
	sb.WriteString("Format output JSON wajib:\n")
	sb.WriteString("{\n")
	sb.WriteString("  \"overall_summary\": \"...\",\n")
	sb.WriteString("  \"points_by_block\": {\n")
	sb.WriteString("    \"A\": [\"...\"],\n")
	sb.WriteString("    \"B\": [\"...\"]\n")
	sb.WriteString("  }\n")
	sb.WriteString("}\n\n")
	sb.WriteString("Daftar Pesan Anonim Warga:\n")

	for _, m := range msgs {
		sb.WriteString(fmt.Sprintf("- [Blok %s] %s (Waktu: %s)\n", m.BlockID, m.Text, m.Timestamp.Format("15:04")))
	}

	respStr, err := p.callOllama(ctx, sb.String(), true)
	if err != nil {
		return nil, err
	}

	var parsed struct {
		OverallSummary string              `json:"overall_summary"`
		PointsByBlock  map[string][]string `json:"points_by_block"`
	}
	if err := json.Unmarshal([]byte(respStr), &parsed); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidModelResponse, err)
	}

	if parsed.PointsByBlock == nil {
		parsed.PointsByBlock = make(map[string][]string)
	}

	return &Summary{
		PointsByBlock:  parsed.PointsByBlock,
		OverallSummary: parsed.OverallSummary,
		AIAssisted:     true,
		Label:          AILabel,
		GeneratedAt:    time.Now().UTC(),
	}, nil
}

func (p *OllamaProvider) ClassifyNeeds(ctx context.Context, text string) (*NeedsSuggestion, error) {
	if strings.TrimSpace(text) == "" {
		return nil, ErrEmptyInput
	}

	prompt := fmt.Sprintf(`Anda adalah asisten klasifikasi kebutuhan darurat bencana RT.
Analisis pesan warga yang telah dianonimkan berikut dan tentukan kebutuhan bantuan darurat dalam format JSON.
Format output JSON wajib:
{
  "needs": ["evakuasi", "medis", "makanan_air", "tempat_tinggal", "lainnya"],
  "urgency": "biasa atau kritis",
  "has_vulnerable": true atau false,
  "confidence": 0.85,
  "reasoning": "Alasan singkat klasifikasi"
}

Pesan Warga:
"%s"`, text)

	respStr, err := p.callOllama(ctx, prompt, true)
	if err != nil {
		return nil, err
	}

	var parsed struct {
		Needs         []string `json:"needs"`
		Urgency       string   `json:"urgency"`
		HasVulnerable bool     `json:"has_vulnerable"`
		Confidence    float64  `json:"confidence"`
		Reasoning     string   `json:"reasoning"`
	}
	if err := json.Unmarshal([]byte(respStr), &parsed); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidModelResponse, err)
	}

	if parsed.Urgency != "kritis" {
		parsed.Urgency = "biasa"
	}

	return &NeedsSuggestion{
		Needs:         parsed.Needs,
		NeedsMask:     calculateNeedsMask(parsed.Needs),
		Urgency:       parsed.Urgency,
		HasVulnerable: parsed.HasVulnerable,
		Confidence:    parsed.Confidence,
		Reasoning:     parsed.Reasoning,
		AIAssisted:    true,
		Label:         AILabel,
		GeneratedAt:   time.Now().UTC(),
	}, nil
}

func (p *OllamaProvider) DraftRecap(ctx context.Context, data RecapAggregate) (string, error) {
	prompt := fmt.Sprintf(`Anda adalah asisten penyusun draf laporan operasi siaga bencana RT.
Susunlah sebuah paragraf narasi resmi draf rekapitulasi berdasarkan data statistik operasional agregat berikut.
Jangan menyebutkan nama individu, data pribadi, atau nomor telepon. 
Tulis dalam Bahasa Indonesia formal, jelas, dan faktual.

Data Agregat Operasi:
- Wilayah: %s, %s
- Bencana: %s
- Durasi: %s
- Total Rumah Tangga: %d KK
- Aman Mandiri di Rumah: %d KK
- Di Balai Titik Kumpul: %d KK
- Membutuhkan Bantuan Darurat: %d KK
- Kebutuhan Intervensi: %d Evakuasi, %d Medis/P3K, %d Makanan & Air, %d Hunian Sementara
- Tingkat Jangkauan Warga Rentan: %.1f%% (%d jiwa terjangkau dari total %d jiwa)`,
		data.RTName, data.KelurahanName, strings.ToUpper(data.Hazard), data.Duration,
		data.TotalHouseholds, data.SafeHouseholds, data.ShelterHouseholds, data.NeedHelpHouseholds,
		data.NeedsEvakuasi, data.NeedsMedis, data.NeedsMakananAir, data.NeedsHunian,
		data.VulnerablePercentage, data.VulnerableReached, data.VulnerableCount,
	)

	narrative, err := p.callOllama(ctx, prompt, false)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(narrative), nil
}

func calculateNeedsMask(needs []string) int {
	mask := 0
	for _, n := range needs {
		switch strings.ToLower(strings.TrimSpace(n)) {
		case "evakuasi":
			mask |= 1
		case "medis":
			mask |= 2
		case "makanan_air", "makanan", "air":
			mask |= 4
		case "tempat_tinggal", "hunian":
			mask |= 8
		case "lainnya":
			mask |= 16
		}
	}
	return mask
}
