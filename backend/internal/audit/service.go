package audit

import (
	"context"
	"time"
)

type Service struct {
	store Store
}

func NewService(store Store) *Service {
	return &Service{store: store}
}

func (s *Service) Log(ctx context.Context, regionID, userID, action, entity, entityID string, details map[string]any, ip, userAgent string) error {
	if details == nil {
		details = make(map[string]any)
	}
	log := &AuditLog{
		RegionID:  regionID,
		UserID:    userID,
		Action:    action,
		Entity:    entity,
		EntityID:  entityID,
		Details:   details,
		IPAddress: ip,
		UserAgent: userAgent,
		CreatedAt: time.Now().UTC(),
	}
	return s.store.Record(ctx, log)
}

func (s *Service) ListByRegion(ctx context.Context, regionID string, limit, offset int) ([]*AuditLog, int, error) {
	return s.store.ListByRegion(ctx, regionID, limit, offset)
}
