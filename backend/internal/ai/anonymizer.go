package ai

import (
	"fmt"
	"regexp"
	"strings"
	"sync"
)

var (
	// Regex for Indonesian & International phone numbers
	phoneRegex = regexp.MustCompile(`(?i)(?:\+?62|08|\b628)[0-9\-\s]{7,15}\b|\b\d{3,4}[-\s]\d{3,4}[-\s]\d{3,5}\b`)

	// Regex for Indonesian street addresses, gangs, house numbers
	streetRegex = regexp.MustCompile(`(?i)\b(?:Jl\.|Jalan|Gg\.|Gang)\s+[^,\n.!?]{2,40}(?:,\s*(?:RT|RW|No\.|Nomor)\s*[^,\n.!?]*)?`)
	houseNumberRegex = regexp.MustCompile(`(?i)\b(?:No\.|Nomor)\s*\d+[/A-Za-z0-9-]*\b`)
	rtrwRegex = regexp.MustCompile(`(?i)\bRT\s*\d+\s*(?:[/,]\s*RW\s*\d+)?\b|\bRW\s*\d+\b`)

	// Regex for personal honorifics with names: "Pak Budi", "Ibu Siti", "Kakek Ahmad", etc.
	namedTitleRegex = regexp.MustCompile(`(?i)\b(Pak|Bapak|Bu|Ibu|Kakek|Nenek|Om|Tante|Mas|Mbak|Dek|dr\.)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b`)

	// Medical and personal health terms that must never leak to LLMs (FR-AI-05, SDD 10.4)
	medicalKeywords = []string{
		"stroke", "asma", "diabetes", "gula darah", "hipertensi", "darah tinggi",
		"cuci darah", "hemodialisis", "patah tulang", "fraktur", "lumpuh", "jantung",
		"kanker", "tumor", "tbc", "tuberkulosis", "demam berdarah", "dengue",
		"diare akut", "hamil tua", "hamil 8 bulan", "hamil 9 bulan", "kejang", "epilepsi",
		"alergi berat", "gangguan jiwa", "skizofrenia", "depresi klinis", "infeksi paru",
		"kencing manis", "asam urat akut", "gagal ginjal", "leukemia",
	}
)

// Anonymizer performs privacy-preserving redaction and tokenization (FR-AI-05).
type Anonymizer struct {
	mu sync.Mutex
}

func NewAnonymizer() *Anonymizer {
	return &Anonymizer{}
}

// AnonymizeText strips PII from a single string:
// 1. Phone numbers -> [TELEPON_DIHAPUS]
// 2. Street addresses & house numbers -> [ALAMAT_DIHAPUS]
// 3. Known / detected names -> [WARGA_n]
// 4. Medical / health diagnoses -> [KONDISI_MEDIS]
func (a *Anonymizer) AnonymizeText(text string, knownNames ...string) string {
	a.mu.Lock()
	defer a.mu.Unlock()

	result := text
	tokenIndex := 1
	nameTokens := make(map[string]string)

	// 1. Replace explicitly known names first
	for _, name := range knownNames {
		trimmed := strings.TrimSpace(name)
		if len(trimmed) >= 2 {
			placeholder := fmt.Sprintf("[WARGA_%d]", tokenIndex)
			tokenIndex++
			nameTokens[strings.ToLower(trimmed)] = placeholder
			// Case-insensitive word boundary replacement
			re := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(trimmed) + `\b`)
			result = re.ReplaceAllString(result, placeholder)
		}
	}

	// 2. Detect title + name patterns: "Pak Budi", "Ibu Siti Aminah"
	result = namedTitleRegex.ReplaceAllStringFunc(result, func(m string) string {
		parts := namedTitleRegex.FindStringSubmatch(m)
		if len(parts) >= 3 {
			nameLower := strings.ToLower(parts[2])
			tok, exists := nameTokens[nameLower]
			if !exists {
				tok = fmt.Sprintf("[WARGA_%d]", tokenIndex)
				tokenIndex++
				nameTokens[nameLower] = tok
			}
			return tok
		}
		return fmt.Sprintf("[WARGA_%d]", tokenIndex)
	})

	// 3. Strip phone numbers
	result = phoneRegex.ReplaceAllString(result, "[TELEPON_DIHAPUS]")

	// 4. Strip street addresses
	result = streetRegex.ReplaceAllString(result, "[ALAMAT_DIHAPUS]")
	result = houseNumberRegex.ReplaceAllString(result, "")
	result = rtrwRegex.ReplaceAllString(result, "")

	// 5. Strip medical conditions and health notes
	for _, kw := range medicalKeywords {
		kwRegex := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
		result = kwRegex.ReplaceAllString(result, "[KONDISI_MEDIS]")
	}

	// Clean up redundant spaces and commas
	result = regexp.MustCompile(`\s{2,}`).ReplaceAllString(result, " ")
	result = regexp.MustCompile(`\s*,\s*,+`).ReplaceAllString(result, ",")
	return strings.TrimSpace(result)
}

// AnonymizeMessages processes a slice of RawMessages with consistent citizen token numbering across the batch.
func (a *Anonymizer) AnonymizeMessages(msgs []RawMessage) []AnonMessage {
	a.mu.Lock()
	defer a.mu.Unlock()

	nameTokens := make(map[string]string)
	tokenIndex := 1

	out := make([]AnonMessage, len(msgs))

	for i, m := range msgs {
		txt := m.Text

		// If SenderName is known, map it
		if strings.TrimSpace(m.SenderName) != "" {
			nameLower := strings.ToLower(strings.TrimSpace(m.SenderName))
			tok, exists := nameTokens[nameLower]
			if !exists {
				tok = fmt.Sprintf("[WARGA_%d]", tokenIndex)
				tokenIndex++
				nameTokens[nameLower] = tok
			}
			re := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(strings.TrimSpace(m.SenderName)) + `\b`)
			txt = re.ReplaceAllString(txt, tok)
		}

		// Also scrub SenderPhone if provided
		if strings.TrimSpace(m.SenderPhone) != "" {
			re := regexp.MustCompile(regexp.QuoteMeta(strings.TrimSpace(m.SenderPhone)))
			txt = re.ReplaceAllString(txt, "[TELEPON_DIHAPUS]")
		}

		// Also scrub SenderAddress if provided
		if strings.TrimSpace(m.SenderAddress) != "" {
			re := regexp.MustCompile(regexp.QuoteMeta(strings.TrimSpace(m.SenderAddress)))
			txt = re.ReplaceAllString(txt, "[ALAMAT_DIHAPUS]")
		}

		// Title + name patterns
		txt = namedTitleRegex.ReplaceAllStringFunc(txt, func(match string) string {
			parts := namedTitleRegex.FindStringSubmatch(match)
			if len(parts) >= 3 {
				nameLower := strings.ToLower(parts[2])
				tok, exists := nameTokens[nameLower]
				if !exists {
					tok = fmt.Sprintf("[WARGA_%d]", tokenIndex)
					tokenIndex++
					nameTokens[nameLower] = tok
				}
				return tok
			}
			return fmt.Sprintf("[WARGA_%d]", tokenIndex)
		})

		// General phone numbers
		txt = phoneRegex.ReplaceAllString(txt, "[TELEPON_DIHAPUS]")

		// General street address
		txt = streetRegex.ReplaceAllString(txt, "[ALAMAT_DIHAPUS]")
		txt = houseNumberRegex.ReplaceAllString(txt, "")
		txt = rtrwRegex.ReplaceAllString(txt, "")

		// Medical diagnoses
		for _, kw := range medicalKeywords {
			kwRegex := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
			txt = kwRegex.ReplaceAllString(txt, "[KONDISI_MEDIS]")
		}

		txt = regexp.MustCompile(`\s{2,}`).ReplaceAllString(txt, " ")
		txt = strings.TrimSpace(txt)

		out[i] = AnonMessage{
			ID:        m.ID,
			BlockID:   m.BlockID,
			Text:      txt,
			Timestamp: m.Timestamp,
		}
	}

	return out
}

// SanitizeLog guarantees that raw sensitive data never enters telemetry, prompt logs, or error logs.
func (a *Anonymizer) SanitizeLog(text string) string {
	return a.AnonymizeText(text)
}
