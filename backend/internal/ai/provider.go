package ai

import (
	"context"
)

// LLMProvider defines the uniform interface for LLM backends (SDD 10.4).
// Implementations: OllamaProvider (offline/posko/local) and GeminiProvider (cloud).
// Also FakeProvider for test suites without real API credentials.
type LLMProvider interface {
	// Summarize aggregates anonymous short messages into block-by-block points and overall status (FR-AI-01).
	Summarize(ctx context.Context, msgs []AnonMessage) (*Summary, error)

	// ClassifyNeeds infers emergency need types, urgency, and vulnerability from anonymized message text (FR-AI-02).
	ClassifyNeeds(ctx context.Context, text string) (*NeedsSuggestion, error)

	// DraftRecap generates an operational incident draft narrative from aggregate statistics (FR-AI-03).
	DraftRecap(ctx context.Context, data RecapAggregate) (string, error)

	// Name returns the provider identifier: "ollama", "gemini", or "fake".
	Name() string
}
