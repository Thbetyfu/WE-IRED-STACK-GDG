package whatsapp

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) SaveNotification(ctx context.Context, n *Notification) error {
	if n.ID == "" {
		n.ID = uuid.NewString()
	}
	if n.CreatedAt.IsZero() {
		n.CreatedAt = time.Now().UTC()
	}
	n.UpdatedAt = n.CreatedAt

	payloadBytes, err := json.Marshal(n.Payload)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO notifications (id, channel, recipient, template, payload, status, provider_id, error, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err = s.pool.Exec(ctx, query,
		n.ID, n.Channel, n.Recipient, n.Template, payloadBytes,
		string(n.Status), n.ProviderID, n.Error, n.CreatedAt, n.UpdatedAt,
	)
	return err
}

func (s *PostgresStore) UpdateNotificationStatus(ctx context.Context, providerID string, status NotificationStatus, errorDetails *string) error {
	now := time.Now().UTC()
	query := `
		UPDATE notifications
		SET status = $1, error = COALESCE($2, error), updated_at = $3
		WHERE provider_id = $4
	`
	res, err := s.pool.Exec(ctx, query, string(status), errorDetails, now, providerID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return ErrNotificationNotFound
	}
	return nil
}

func (s *PostgresStore) GetNotification(ctx context.Context, id string) (*Notification, error) {
	query := `
		SELECT id, channel, recipient, template, payload, status, provider_id, error, created_at, updated_at
		FROM notifications
		WHERE id = $1
	`
	var n Notification
	var statusStr string
	var payloadBytes []byte
	var template *string

	err := s.pool.QueryRow(ctx, query, id).Scan(
		&n.ID, &n.Channel, &n.Recipient, &template, &payloadBytes,
		&statusStr, &n.ProviderID, &n.Error, &n.CreatedAt, &n.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotificationNotFound
		}
		return nil, err
	}

	n.Status = NotificationStatus(statusStr)
	if template != nil {
		n.Template = *template
	}
	_ = json.Unmarshal(payloadBytes, &n.Payload)
	return &n, nil
}

func (s *PostgresStore) ListNotificationsByRecipient(ctx context.Context, recipient string, limit int) ([]*Notification, error) {
	if limit <= 0 {
		limit = 50
	}

	query := `
		SELECT id, channel, recipient, template, payload, status, provider_id, error, created_at, updated_at
		FROM notifications
		WHERE recipient = $1
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := s.pool.Query(ctx, query, recipient, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Notification
	for rows.Next() {
		var n Notification
		var statusStr string
		var payloadBytes []byte
		var template *string

		if err := rows.Scan(
			&n.ID, &n.Channel, &n.Recipient, &template, &payloadBytes,
			&statusStr, &n.ProviderID, &n.Error, &n.CreatedAt, &n.UpdatedAt,
		); err != nil {
			return nil, err
		}

		n.Status = NotificationStatus(statusStr)
		if template != nil {
			n.Template = *template
		}
		_ = json.Unmarshal(payloadBytes, &n.Payload)
		result = append(result, &n)
	}

	return result, nil
}

func (s *PostgresStore) GetSession(ctx context.Context, phone string) (*WASession, error) {
	query := `
		SELECT phone, incident_id, household_id, report_id, step, context, updated_at
		FROM wa_sessions
		WHERE phone = $1
	`
	var sess WASession
	var stepStr string
	var ctxBytes []byte

	err := s.pool.QueryRow(ctx, query, phone).Scan(
		&sess.Phone, &sess.IncidentID, &sess.HouseholdID, &sess.ReportID,
		&stepStr, &ctxBytes, &sess.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSessionNotFound
		}
		return nil, err
	}

	sess.Step = SessionStep(stepStr)
	_ = json.Unmarshal(ctxBytes, &sess.Context)
	return &sess, nil
}

func (s *PostgresStore) SaveSession(ctx context.Context, sess *WASession) error {
	ctxBytes, err := json.Marshal(sess.Context)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	sess.UpdatedAt = now

	query := `
		INSERT INTO wa_sessions (phone, incident_id, household_id, report_id, step, context, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (phone) DO UPDATE
		SET incident_id = EXCLUDED.incident_id,
		    household_id = EXCLUDED.household_id,
		    report_id = EXCLUDED.report_id,
		    step = EXCLUDED.step,
		    context = EXCLUDED.context,
		    updated_at = EXCLUDED.updated_at
	`
	_, err = s.pool.Exec(ctx, query,
		sess.Phone, sess.IncidentID, sess.HouseholdID, sess.ReportID,
		string(sess.Step), ctxBytes, now,
	)
	return err
}

func (s *PostgresStore) DeleteSession(ctx context.Context, phone string) error {
	query := `DELETE FROM wa_sessions WHERE phone = $1`
	_, err := s.pool.Exec(ctx, query, phone)
	return err
}

func (s *PostgresStore) IsMessageProcessed(ctx context.Context, messageID string) (bool, error) {
	query := `SELECT 1 FROM wa_processed_messages WHERE message_id = $1`
	var one int
	err := s.pool.QueryRow(ctx, query, messageID).Scan(&one)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (s *PostgresStore) MarkMessageProcessed(ctx context.Context, messageID string) error {
	query := `
		INSERT INTO wa_processed_messages (message_id, processed_at)
		VALUES ($1, NOW())
		ON CONFLICT (message_id) DO NOTHING
	`
	_, err := s.pool.Exec(ctx, query, messageID)
	return err
}

func (s *PostgresStore) HasSentReminder(ctx context.Context, incidentID, householdID, step string) (bool, error) {
	query := `SELECT 1 FROM wa_reminder_logs WHERE incident_id = $1 AND household_id = $2 AND step = $3`
	var one int
	err := s.pool.QueryRow(ctx, query, incidentID, householdID, step).Scan(&one)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (s *PostgresStore) RecordReminderSent(ctx context.Context, incidentID, householdID, step string) error {
	query := `
		INSERT INTO wa_reminder_logs (incident_id, household_id, step, sent_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (incident_id, household_id, step) DO NOTHING
	`
	_, err := s.pool.Exec(ctx, query, incidentID, householdID, step)
	return err
}
