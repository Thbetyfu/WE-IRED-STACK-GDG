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

type GeminiProvider struct {
	apiKey     string
	model      string
	httpClient *http.Client
}

func NewGeminiProvider(apiKey, model string, timeout time.Duration) *GeminiProvider {
	if model == "" {
		model = "gemini-1.5-flash"
	}
	if timeout <= 0 {
		timeout = 15 * time.Second
	}

	return &GeminiProvider{
		apiKey: apiKey,
		model:  model,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

func (p *GeminiProvider) Name() string {
	return "gemini"
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiRequest struct {
	Contents         []geminiContent        `json:"contents"`
	GenerationConfig map[string]interface{} `json:"generationConfig,omitempty"`
}

type geminiCandidate struct {
	Content geminiContent `json:"content"`
}

type geminiResponse struct {
	Candidates []geminiCandidate `json:"candidates"`
	Error      *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error,omitempty"`
}

func (p *GeminiProvider) callGemini(ctx context.Context, prompt string, jsonFormat bool) (string, error) {
	if p.apiKey == "" {
		return "", fmt.Errorf("%w: GEMINI_API_KEY tidak dikonfigurasi", ErrProviderUnavailable)
	}

	reqBody := geminiRequest{
		Contents: []geminiContent{
			{
				Parts: []geminiPart{
					{Text: prompt},
				},
			},
		},
	}
	if jsonFormat {
		reqBody.GenerationConfig = map[string]interface{}{
			"response_mime_type": "application/json",
		}
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}

	url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", p.model, p.apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
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

	var gResp geminiResponse
	if err := json.NewDecoder(resp.Body).Decode(&gResp); err != nil {
		return "", fmt.Errorf("%w: failed to parse gemini json: %v", ErrInvalidModelResponse, err)
	}

	if gResp.Error != nil {
		return "", fmt.Errorf("%w: gemini API error (%d): %s", ErrInvalidModelResponse, gResp.Error.Code, gResp.Error.Message)
	}

	if len(gResp.Candidates) == 0 || len(gResp.Candidates[0].Content.Parts) == 0 {
		return "", fmt.Errorf("%w: empty candidate in gemini response", ErrInvalidModelResponse)
	}

	return strings.TrimSpace(gResp.Candidates[0].Content.Parts[0].Text), nil
}

func (p *GeminiProvider) Summarize(ctx context.Context, msgs []AnonMessage) (*Summary, error) {
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

	respStr, err := p.callGemini(ctx, sb.String(), true)
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

func (p *GeminiProvider) ClassifyNeeds(ctx context.Context, text string) (*NeedsSuggestion, error) {
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

	respStr, err := p.callGemini(ctx, prompt, true)
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

func (p *GeminiProvider) DraftRecap(ctx context.Context, data RecapAggregate) (string, error) {
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

	narrative, err := p.callGemini(ctx, prompt, false)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(narrative), nil
}
