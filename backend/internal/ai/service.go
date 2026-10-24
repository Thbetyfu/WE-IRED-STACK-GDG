package ai

import (
	"context"
	"time"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/audit"
	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/region"
)

type Service struct {
	provider     LLMProvider
	regionStore  region.Store
	anonymizer   *Anonymizer
	auditService *audit.Service
}

func NewService(
	provider LLMProvider,
	regionStore region.Store,
	anonymizer *Anonymizer,
	auditService *audit.Service,
) *Service {
	if anonymizer == nil {
		anonymizer = NewAnonymizer()
	}
	return &Service{
		provider:     provider,
		regionStore:  regionStore,
		anonymizer:   anonymizer,
		auditService: auditService,
	}
}

func (s *Service) SetProvider(p LLMProvider) {
	s.provider = p
}

func (s *Service) Provider() LLMProvider {
	return s.provider
}

// verifyRTEnforcement checks if AI is enabled for the given RT (FR-AI-07).
// Returns ErrAIDisabledForRT if the RT has toggled AI off.
func (s *Service) verifyRTEnforcement(ctx context.Context, rtID string) error {
	if s.regionStore == nil {
		return nil
	}

	reg, err := s.regionStore.GetRegionByID(ctx, rtID)
	if err != nil {
		return err
	}

	if !reg.AIEnabled {
		return ErrAIDisabledForRT
	}
	return nil
}

// Summarize processes citizen messages with full pre-anonymization (FR-AI-01, FR-AI-05).
func (s *Service) Summarize(ctx context.Context, rtID string, msgs []RawMessage) (*Summary, error) {
	if err := s.verifyRTEnforcement(ctx, rtID); err != nil {
		return nil, err
	}

	if s.provider == nil {
		return nil, ErrProviderUnavailable
	}

	if len(msgs) == 0 {
		return nil, ErrEmptyInput
	}

	// 1. Strict pre-anonymization before sending to provider (FR-AI-05)
	anonMsgs := s.anonymizer.AnonymizeMessages(msgs)

	// 2. Call provider
	summary, err := s.provider.Summarize(ctx, anonMsgs)
	if err != nil {
		return nil, err
	}

	// 3. Stamping AI Label and metadata (FR-AI-06)
	summary.AIAssisted = true
	summary.Label = AILabel
	if summary.GeneratedAt.IsZero() {
		summary.GeneratedAt = time.Now().UTC()
	}

	return summary, nil
}

// ClassifyNeeds infers needs, urgency, and vulnerability suggestions (FR-AI-02).
func (s *Service) ClassifyNeeds(ctx context.Context, rtID string, text string) (*NeedsSuggestion, error) {
	if err := s.verifyRTEnforcement(ctx, rtID); err != nil {
		return nil, err
	}

	if s.provider == nil {
		return nil, ErrProviderUnavailable
	}

	if text == "" {
		return nil, ErrEmptyInput
	}

	// 1. Strict pre-anonymization before sending to provider (FR-AI-05)
	anonText := s.anonymizer.AnonymizeText(text)

	// 2. Call provider
	suggestion, err := s.provider.ClassifyNeeds(ctx, anonText)
	if err != nil {
		return nil, err
	}

	// 3. Stamping AI Label (FR-AI-06)
	suggestion.AIAssisted = true
	suggestion.Label = AILabel
	if suggestion.GeneratedAt.IsZero() {
		suggestion.GeneratedAt = time.Now().UTC()
	}

	return suggestion, nil
}

// DraftRecap generates an incident recap narrative from aggregate numbers only (FR-AI-03).
func (s *Service) DraftRecap(ctx context.Context, rtID string, data RecapAggregate) (*DraftRecapResult, error) {
	if err := s.verifyRTEnforcement(ctx, rtID); err != nil {
		return nil, err
	}

	if s.provider == nil {
		return nil, ErrProviderUnavailable
	}

	// Data passed is strictly aggregated; no citizen identities exist.
	draft, err := s.provider.DraftRecap(ctx, data)
	if err != nil {
		return nil, err
	}

	return &DraftRecapResult{
		DraftNarrative: draft,
		AIAssisted:     true,
		Label:          AILabel,
		GeneratedAt:    time.Now().UTC(),
	}, nil
}

// GetAISettings retrieves the current AI activation status for an RT (FR-AI-07).
func (s *Service) GetAISettings(ctx context.Context, rtID string) (*AISettings, error) {
	if s.regionStore == nil {
		return &AISettings{
			RTID:           rtID,
			AIEnabled:      true,
			ActiveProvider: s.providerName(),
		}, nil
	}

	reg, err := s.regionStore.GetRegionByID(ctx, rtID)
	if err != nil {
		return nil, err
	}

	return &AISettings{
		RTID:           reg.ID,
		AIEnabled:      reg.AIEnabled,
		ActiveProvider: s.providerName(),
	}, nil
}

// SetAIEnabled updates the AI toggle for a specific RT and logs the audit event (FR-AI-07).
func (s *Service) SetAIEnabled(ctx context.Context, rtID string, enabled bool, actorID, ip, userAgent string) error {
	if s.regionStore == nil {
		return nil
	}

	if err := s.regionStore.SetAIEnabled(ctx, rtID, enabled); err != nil {
		return err
	}

	// Audit trail for AI settings modification (FR-ADM-01)
	if s.auditService != nil {
		_ = s.auditService.Log(ctx, rtID, actorID, audit.ActionUpdateAISettings, "region", rtID, map[string]any{
			"ai_enabled": enabled,
		}, ip, userAgent)
	}

	return nil
}

func (s *Service) providerName() string {
	if s.provider != nil {
		return s.provider.Name()
	}
	return "none"
}
