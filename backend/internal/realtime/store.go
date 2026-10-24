package realtime

import (
	"context"
	"encoding/json"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type EventStore interface {
	SaveEvent(ctx context.Context, e *Event) error
	GetEventsAfter(ctx context.Context, lastEventID int64, incidentID *string, regionID *string, limit int) ([]*Event, error)
}

// MemoryEventStore provides in-memory thread-safe event storage for testing and offline execution.
type MemoryEventStore struct {
	mu     sync.RWMutex
	seq    int64
	events []*Event
}

func NewMemoryEventStore() *MemoryEventStore {
	return &MemoryEventStore{
		events: make([]*Event, 0),
	}
}

func (s *MemoryEventStore) SaveEvent(ctx context.Context, e *Event) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	id := atomic.AddInt64(&s.seq, 1)
	e.ID = id
	if e.CreatedAt.IsZero() {
		e.CreatedAt = time.Now().UTC()
	}

	copyEvent := *e
	s.events = append(s.events, &copyEvent)
	return nil
}

func (s *MemoryEventStore) GetEventsAfter(ctx context.Context, lastEventID int64, incidentID *string, regionID *string, limit int) ([]*Event, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if limit <= 0 || limit > 500 {
		limit = 100
	}

	var result []*Event
	for _, e := range s.events {
		if e.ID > lastEventID {
			if incidentID != nil && *incidentID != "" {
				// Match on event's IncidentID or payload["incident_id"]
				incMatch := false
				if e.IncidentID != nil && *e.IncidentID == *incidentID {
					incMatch = true
				} else if incVal, ok := e.Payload["incident_id"].(string); ok && incVal == *incidentID {
					incMatch = true
				}
				if !incMatch {
					continue
				}
			}

			if regionID != nil && *regionID != "" {
				if e.RegionID != nil && *e.RegionID != *regionID {
					continue
				}
			}

			copyEvent := *e
			result = append(result, &copyEvent)
			if len(result) >= limit {
				break
			}
		}
	}

	return result, nil
}

// PostgresEventStore connects to the platform PostgreSQL events table.
type PostgresEventStore struct {
	pool *pgxpool.Pool
}

func NewPostgresEventStore(pool *pgxpool.Pool) *PostgresEventStore {
	return &PostgresEventStore{pool: pool}
}

func (s *PostgresEventStore) SaveEvent(ctx context.Context, e *Event) error {
	payloadJSON, err := json.Marshal(e.Payload)
	if err != nil {
		payloadJSON = []byte("{}")
	}

	if e.CreatedAt.IsZero() {
		e.CreatedAt = time.Now().UTC()
	}

	query := `INSERT INTO events (region_id, entity, entity_id, op, payload, origin, created_at)
	          VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`

	return s.pool.QueryRow(ctx, query,
		e.RegionID, e.Entity, e.EntityID, e.Op, payloadJSON, e.Origin, e.CreatedAt,
	).Scan(&e.ID)
}

func (s *PostgresEventStore) GetEventsAfter(ctx context.Context, lastEventID int64, incidentID *string, regionID *string, limit int) ([]*Event, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}

	query := `SELECT id, region_id, entity, entity_id, op, payload, origin, created_at
	          FROM events WHERE id > $1`
	var args []any
	args = append(args, lastEventID)

	argIdx := 2
	if regionID != nil && *regionID != "" {
		query += " AND region_id = $" + string(rune('0'+argIdx))
		args = append(args, *regionID)
		argIdx++
	}

	query += " ORDER BY id ASC LIMIT $" + string(rune('0'+argIdx))
	args = append(args, limit)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Event
	for rows.Next() {
		var e Event
		var payloadBytes []byte
		if err := rows.Scan(
			&e.ID, &e.RegionID, &e.Entity, &e.EntityID, &e.Op, &payloadBytes, &e.Origin, &e.CreatedAt,
		); err != nil {
			return nil, err
		}
		if len(payloadBytes) > 0 {
			_ = json.Unmarshal(payloadBytes, &e.Payload)
		}
		if e.Payload == nil {
			e.Payload = make(map[string]any)
		}

		if incidentID != nil && *incidentID != "" {
			incMatch := false
			if e.IncidentID != nil && *e.IncidentID == *incidentID {
				incMatch = true
			} else if incVal, ok := e.Payload["incident_id"].(string); ok && incVal == *incidentID {
				incMatch = true
			}
			if !incMatch {
				continue
			}
		}

		result = append(result, &e)
	}

	return result, rows.Err()
}
