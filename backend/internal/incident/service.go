package incident

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"math/big"
	"time"

	"github.com/google/uuid"
)

type DraftRequest struct {
	RTID          string       `json:"rt_id"`
	Hazard        HazardType   `json:"hazard"`
	Mode          IncidentMode `json:"mode"`
	ScopeBlockIDs []string     `json:"scope_block_ids"`
	Message       string       `json:"message"`
	StartedBy     string       `json:"started_by"`
}

type DirectActivationRequest struct {
	RTID          string       `json:"rt_id"`
	Hazard        HazardType   `json:"hazard"`
	Mode          IncidentMode `json:"mode"`
	ScopeBlockIDs []string     `json:"scope_block_ids"`
	Message       string       `json:"message"`
	StartedBy     string       `json:"started_by"`
}

type ReportSummaryProvider interface {
	GetIncidentStats(ctx context.Context, inc *Incident) (*IncidentSummary, *IncidentMetrics, error)
}

type Service struct {
	store          Store
	reportProvider ReportSummaryProvider
}

func NewService(store Store) *Service {
	return &Service{store: store}
}

func (s *Service) SetReportProvider(provider ReportSummaryProvider) {
	s.reportProvider = provider
}

func (s *Service) DraftActivation(ctx context.Context, req DraftRequest) (*ActivationDraft, error) {
	// Check active real incident for the RT
	realMode := ModeNyata
	activeReal, err := s.store.GetActiveIncidentByRT(ctx, req.RTID, &realMode)
	if err == nil && activeReal != nil {
		if req.Mode == ModeNyata {
			return nil, ErrActiveRealIncidentExists
		}
		if req.Mode == ModeLatihan {
			return nil, ErrRealIncidentActive
		}
	}

	tokenBytes := make([]byte, 16)
	if _, err := rand.Read(tokenBytes); err != nil {
		return nil, err
	}
	token := hex.EncodeToString(tokenBytes)

	now := time.Now().UTC()
	draft := &ActivationDraft{
		Token:         token,
		RTID:          req.RTID,
		Hazard:        req.Hazard,
		Mode:          req.Mode,
		ScopeBlockIDs: req.ScopeBlockIDs,
		Message:       req.Message,
		StartedBy:     req.StartedBy,
		CreatedAt:     now,
		ExpiresAt:     now.Add(5 * time.Minute), // SRS: valid 5 minutes
	}

	if err := s.store.SaveDraft(ctx, draft); err != nil {
		return nil, err
	}
	return draft, nil
}

func (s *Service) ConfirmActivation(ctx context.Context, token string, confirmedBy string) (*Incident, error) {
	draft, err := s.store.GetDraft(ctx, token)
	if err != nil {
		return nil, err
	}

	shortID, err := generateUint32ShortID()
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	inc := &Incident{
		ID:            uuid.NewString(),
		RTID:          draft.RTID,
		ShortID:       shortID,
		Hazard:        draft.Hazard,
		Mode:          draft.Mode,
		ScopeBlockIDs: draft.ScopeBlockIDs,
		Message:       draft.Message,
		StartedBy:     confirmedBy,
		StartedAt:     now,
		Status:        StatusAktif,
		Metrics: IncidentMetrics{
			ByChannel: make(map[string]int),
		},
		CreatedAt: now,
	}

	if err := s.store.CreateIncident(ctx, inc); err != nil {
		return nil, err
	}

	// Invalidate draft token
	_ = s.store.DeleteDraft(ctx, token)
	return inc, nil
}

func (s *Service) ActivateDirect(ctx context.Context, req DirectActivationRequest) (*Incident, error) {
	// Mode nyata requires two-step confirmation
	if req.Mode == ModeNyata {
		return nil, ErrRealIncidentRequiresConfirmation
	}

	// For drill mode, check if a real incident is active
	realMode := ModeNyata
	activeReal, err := s.store.GetActiveIncidentByRT(ctx, req.RTID, &realMode)
	if err == nil && activeReal != nil {
		return nil, ErrRealIncidentActive
	}

	shortID, err := generateUint32ShortID()
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	inc := &Incident{
		ID:            uuid.NewString(),
		RTID:          req.RTID,
		ShortID:       shortID,
		Hazard:        req.Hazard,
		Mode:          req.Mode,
		ScopeBlockIDs: req.ScopeBlockIDs,
		Message:       req.Message,
		StartedBy:     req.StartedBy,
		StartedAt:     now,
		Status:        StatusAktif,
		Metrics: IncidentMetrics{
			ByChannel: make(map[string]int),
		},
		CreatedAt: now,
	}

	if err := s.store.CreateIncident(ctx, inc); err != nil {
		return nil, err
	}
	return inc, nil
}

func (s *Service) EndIncident(ctx context.Context, id string) (*Incident, error) {
	inc, err := s.store.GetIncident(ctx, id)
	if err != nil {
		return nil, err
	}
	if inc.Status == StatusSelesai {
		return nil, ErrIncidentAlreadyEnded
	}

	now := time.Now().UTC()
	inc.EndedAt = &now
	inc.Status = StatusSelesai

	if s.reportProvider != nil {
		if _, metrics, err := s.reportProvider.GetIncidentStats(ctx, inc); err == nil && metrics != nil {
			inc.Metrics = *metrics
		}
	}

	if err := s.store.UpdateIncident(ctx, inc); err != nil {
		return nil, err
	}
	return inc, nil
}

func (s *Service) GetIncident(ctx context.Context, id string) (*Incident, error) {
	return s.store.GetIncident(ctx, id)
}

func (s *Service) GetIncidentByShortID(ctx context.Context, shortID uint32) (*Incident, error) {
	return s.store.GetIncidentByShortID(ctx, shortID)
}

func (s *Service) GetActiveIncident(ctx context.Context, rtID string, mode *IncidentMode) (*Incident, error) {
	return s.store.GetActiveIncidentByRT(ctx, rtID, mode)
}

func (s *Service) ListIncidents(ctx context.Context, rtID string, mode *IncidentMode) ([]*Incident, error) {
	list, err := s.store.ListIncidentsByRT(ctx, rtID)
	if err != nil {
		return nil, err
	}
	if mode == nil {
		return list, nil
	}

	var filtered []*Incident
	for _, inc := range list {
		if inc.Mode == *mode {
			filtered = append(filtered, inc)
		}
	}
	return filtered, nil
}

func (s *Service) GetDrillsComparison(ctx context.Context, rtID string) (*DrillComparisonSummary, error) {
	drillMode := ModeLatihan
	drills, err := s.ListIncidents(ctx, rtID, &drillMode)
	if err != nil {
		return nil, err
	}

	if len(drills) == 0 {
		return &DrillComparisonSummary{
			TotalDrills:            0,
			AverageVulnReached30:   0,
			AverageOfflineDelivery: 0,
			Trend:                  "empty",
			Drills:                 []DrillComparisonMetric{},
		}, nil
	}

	var metricItems []DrillComparisonMetric
	var sumVuln float64
	var sumOffline float64

	for _, d := range drills {
		metricItems = append(metricItems, DrillComparisonMetric{
			IncidentID:      d.ID,
			Hazard:          d.Hazard,
			StartedAt:       d.StartedAt,
			T90:             d.Metrics.T90,
			T100:            d.Metrics.T100,
			VulnReached30:   d.Metrics.VulnReached30,
			OfflineDelivery: d.Metrics.OfflineDelivery,
		})
		sumVuln += d.Metrics.VulnReached30
		sumOffline += d.Metrics.OfflineDelivery
	}

	n := float64(len(drills))
	avgVuln := sumVuln / n
	avgOffline := sumOffline / n

	trend := "stable"
	if len(drills) >= 2 {
		first := metricItems[len(metricItems)-1].VulnReached30
		latest := metricItems[0].VulnReached30
		if latest > first {
			trend = "improving"
		} else if latest < first {
			trend = "needs_practice"
		}
	}

	return &DrillComparisonSummary{
		TotalDrills:            len(drills),
		AverageVulnReached30:   avgVuln,
		AverageOfflineDelivery: avgOffline,
		Trend:                  trend,
		Drills:                 metricItems,
	}, nil
}

func (s *Service) GetSummary(ctx context.Context, id string) (*IncidentSummary, error) {
	inc, err := s.store.GetIncident(ctx, id)
	if err != nil {
		return nil, err
	}

	if s.reportProvider != nil {
		summary, _, err := s.reportProvider.GetIncidentStats(ctx, inc)
		if err == nil && summary != nil {
			return summary, nil
		}
	}

	// Fallback baseline summary
	elapsed := 0
	if inc.StartedAt.Before(time.Now().UTC()) {
		if inc.EndedAt != nil {
			elapsed = int(inc.EndedAt.Sub(inc.StartedAt).Minutes())
		} else {
			elapsed = int(time.Since(inc.StartedAt).Minutes())
		}
	}

	return &IncidentSummary{
		Incident:       *inc,
		ElapsedMinutes: elapsed,
	}, nil
}

func (s *Service) ComputeMetrics(ctx context.Context, id string) (*IncidentMetrics, error) {
	inc, err := s.store.GetIncident(ctx, id)
	if err != nil {
		return nil, err
	}

	if s.reportProvider != nil {
		_, metrics, err := s.reportProvider.GetIncidentStats(ctx, inc)
		if err != nil {
			return nil, err
		}
		inc.Metrics = *metrics
		if err := s.store.UpdateIncident(ctx, inc); err != nil {
			return nil, err
		}
		return metrics, nil
	}

	return &inc.Metrics, nil
}

func generateUint32ShortID() (uint32, error) {
	maxVal := big.NewInt(4294967295) // 2^32 - 1
	n, err := rand.Int(rand.Reader, maxVal)
	if err != nil {
		return 0, err
	}
	return uint32(n.Uint64()) + 1, nil
}
