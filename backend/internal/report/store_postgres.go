package report

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct {
	pool *pgxpool.Pool
}

func NewPostgresStore(pool *pgxpool.Pool) *PostgresStore {
	return &PostgresStore{pool: pool}
}

func (s *PostgresStore) SaveReport(ctx context.Context, r *Report) (bool, error) {
	relayJSON, err := json.Marshal(r.RelayPath)
	if err != nil {
		relayJSON = []byte("[]")
	}

	query := `INSERT INTO reports (
		id, incident_id, household_id, seq, status, urgency, needs, member_mask,
		message, lat, lon, battery, channel, reporter_user_id, beacon_id,
		device_time, received_at, relay_path
	) VALUES (
		$1, $2, $3, $4, $5, $6, $7, $8,
		$9, $10, $11, $12, $13, $14, $15,
		$16, $17, $18
	)`

	_, err = s.pool.Exec(ctx, query,
		r.ID, r.IncidentID, r.HouseholdID, r.Seq, int16(r.Status), int16(r.Urgency), r.Needs, r.MemberMask,
		r.Message, r.Lat, r.Lon, r.Battery, r.Channel, r.ReporterUserID, r.BeaconID,
		r.DeviceTime, r.ReceivedAt, relayJSON,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique violation on id or (incident, household, seq)
			return true, nil
		}
		return false, err
	}
	return false, nil
}

func (s *PostgresStore) GetReport(ctx context.Context, id string) (*Report, error) {
	query := `SELECT id, incident_id, household_id, seq, status, urgency, needs, member_mask,
	                 message, lat, lon, battery, channel, reporter_user_id, beacon_id,
	                 device_time, received_at, relay_path
	          FROM reports WHERE id = $1 LIMIT 1`

	var r Report
	var relayBytes []byte

	err := s.pool.QueryRow(ctx, query, id).Scan(
		&r.ID, &r.IncidentID, &r.HouseholdID, &r.Seq, &r.Status, &r.Urgency, &r.Needs, &r.MemberMask,
		&r.Message, &r.Lat, &r.Lon, &r.Battery, &r.Channel, &r.ReporterUserID, &r.BeaconID,
		&r.DeviceTime, &r.ReceivedAt, &relayBytes,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrReportNotFound
		}
		return nil, err
	}
	if len(relayBytes) > 0 {
		_ = json.Unmarshal(relayBytes, &r.RelayPath)
	}
	return &r, nil
}

func (s *PostgresStore) GetReportBySeq(ctx context.Context, incidentID, householdID string, seq int) (*Report, error) {
	query := `SELECT id, incident_id, household_id, seq, status, urgency, needs, member_mask,
	                 message, lat, lon, battery, channel, reporter_user_id, beacon_id,
	                 device_time, received_at, relay_path
	          FROM reports WHERE incident_id = $1 AND household_id = $2 AND seq = $3 LIMIT 1`

	var r Report
	var relayBytes []byte

	err := s.pool.QueryRow(ctx, query, incidentID, householdID, seq).Scan(
		&r.ID, &r.IncidentID, &r.HouseholdID, &r.Seq, &r.Status, &r.Urgency, &r.Needs, &r.MemberMask,
		&r.Message, &r.Lat, &r.Lon, &r.Battery, &r.Channel, &r.ReporterUserID, &r.BeaconID,
		&r.DeviceTime, &r.ReceivedAt, &relayBytes,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrReportNotFound
		}
		return nil, err
	}
	if len(relayBytes) > 0 {
		_ = json.Unmarshal(relayBytes, &r.RelayPath)
	}
	return &r, nil
}

func (s *PostgresStore) ListReportsByIncident(ctx context.Context, incidentID string) ([]*Report, error) {
	query := `SELECT id, incident_id, household_id, seq, status, urgency, needs, member_mask,
	                 message, lat, lon, battery, channel, reporter_user_id, beacon_id,
	                 device_time, received_at, relay_path
	          FROM reports WHERE incident_id = $1 ORDER BY seq ASC, received_at ASC`

	rows, err := s.pool.Query(ctx, query, incidentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Report
	for rows.Next() {
		var r Report
		var relayBytes []byte
		if err := rows.Scan(
			&r.ID, &r.IncidentID, &r.HouseholdID, &r.Seq, &r.Status, &r.Urgency, &r.Needs, &r.MemberMask,
			&r.Message, &r.Lat, &r.Lon, &r.Battery, &r.Channel, &r.ReporterUserID, &r.BeaconID,
			&r.DeviceTime, &r.ReceivedAt, &relayBytes,
		); err != nil {
			return nil, err
		}
		if len(relayBytes) > 0 {
			_ = json.Unmarshal(relayBytes, &r.RelayPath)
		}
		result = append(result, &r)
	}
	return result, rows.Err()
}

func (s *PostgresStore) ListReportsByHousehold(ctx context.Context, incidentID, householdID string) ([]*Report, error) {
	query := `SELECT id, incident_id, household_id, seq, status, urgency, needs, member_mask,
	                 message, lat, lon, battery, channel, reporter_user_id, beacon_id,
	                 device_time, received_at, relay_path
	          FROM reports WHERE incident_id = $1 AND household_id = $2 ORDER BY seq ASC, received_at ASC`

	rows, err := s.pool.Query(ctx, query, incidentID, householdID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Report
	for rows.Next() {
		var r Report
		var relayBytes []byte
		if err := rows.Scan(
			&r.ID, &r.IncidentID, &r.HouseholdID, &r.Seq, &r.Status, &r.Urgency, &r.Needs, &r.MemberMask,
			&r.Message, &r.Lat, &r.Lon, &r.Battery, &r.Channel, &r.ReporterUserID, &r.BeaconID,
			&r.DeviceTime, &r.ReceivedAt, &relayBytes,
		); err != nil {
			return nil, err
		}
		if len(relayBytes) > 0 {
			_ = json.Unmarshal(relayBytes, &r.RelayPath)
		}
		result = append(result, &r)
	}
	return result, rows.Err()
}

func (s *PostgresStore) GetMaxSeq(ctx context.Context, incidentID, householdID string) (int, error) {
	query := `SELECT COALESCE(MAX(seq), 0) FROM reports WHERE incident_id = $1 AND household_id = $2`
	var maxSeq int
	err := s.pool.QueryRow(ctx, query, incidentID, householdID).Scan(&maxSeq)
	if err != nil {
		return 0, err
	}
	return maxSeq, nil
}

func (s *PostgresStore) GetHouseholdState(ctx context.Context, incidentID, householdID string) (*HouseholdState, error) {
	query := `SELECT incident_id, household_id, report_id, status, urgency, needs, member_mask,
	                 priority_score, score_breakdown, reached, unconfirmed_vulnerable,
	                 needs_confirmation, updated_at
	          FROM household_states WHERE incident_id = $1 AND household_id = $2 LIMIT 1`

	var st HouseholdState
	var breakdownBytes []byte

	err := s.pool.QueryRow(ctx, query, incidentID, householdID).Scan(
		&st.IncidentID, &st.HouseholdID, &st.ReportID, &st.Status, &st.Urgency, &st.Needs, &st.MemberMask,
		&st.PriorityScore, &breakdownBytes, &st.Reached, &st.UnconfirmedVulnerable,
		&st.NeedsConfirmation, &st.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrStateNotFound
		}
		return nil, err
	}
	if len(breakdownBytes) > 0 {
		_ = json.Unmarshal(breakdownBytes, &st.ScoreBreakdown)
	}
	if st.ScoreBreakdown == nil {
		st.ScoreBreakdown = make(map[string]float64)
	}
	return &st, nil
}

func (s *PostgresStore) UpsertHouseholdState(ctx context.Context, st *HouseholdState) error {
	breakdownJSON, err := json.Marshal(st.ScoreBreakdown)
	if err != nil {
		breakdownJSON = []byte("{}")
	}

	query := `INSERT INTO household_states (
		incident_id, household_id, report_id, status, urgency, needs, member_mask,
		priority_score, score_breakdown, reached, unconfirmed_vulnerable,
		needs_confirmation, updated_at
	) VALUES (
		$1, $2, $3, $4, $5, $6, $7,
		$8, $9, $10, $11,
		$12, $13
	) ON CONFLICT (incident_id, household_id) DO UPDATE SET
		report_id = EXCLUDED.report_id,
		status = EXCLUDED.status,
		urgency = EXCLUDED.urgency,
		needs = EXCLUDED.needs,
		member_mask = EXCLUDED.member_mask,
		priority_score = EXCLUDED.priority_score,
		score_breakdown = EXCLUDED.score_breakdown,
		reached = EXCLUDED.reached,
		unconfirmed_vulnerable = EXCLUDED.unconfirmed_vulnerable,
		needs_confirmation = EXCLUDED.needs_confirmation,
		updated_at = EXCLUDED.updated_at`

	_, err = s.pool.Exec(ctx, query,
		st.IncidentID, st.HouseholdID, st.ReportID, int16(st.Status), int16(st.Urgency), st.Needs, st.MemberMask,
		st.PriorityScore, breakdownJSON, st.Reached, st.UnconfirmedVulnerable,
		st.NeedsConfirmation, st.UpdatedAt,
	)
	return err
}

func (s *PostgresStore) ListHouseholdStates(ctx context.Context, incidentID string) ([]*HouseholdState, error) {
	query := `SELECT incident_id, household_id, report_id, status, urgency, needs, member_mask,
	                 priority_score, score_breakdown, reached, unconfirmed_vulnerable,
	                 needs_confirmation, updated_at
	          FROM household_states WHERE incident_id = $1 ORDER BY priority_score DESC`

	rows, err := s.pool.Query(ctx, query, incidentID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*HouseholdState
	for rows.Next() {
		var st HouseholdState
		var breakdownBytes []byte
		if err := rows.Scan(
			&st.IncidentID, &st.HouseholdID, &st.ReportID, &st.Status, &st.Urgency, &st.Needs, &st.MemberMask,
			&st.PriorityScore, &breakdownBytes, &st.Reached, &st.UnconfirmedVulnerable,
			&st.NeedsConfirmation, &st.UpdatedAt,
		); err != nil {
			return nil, err
		}
		if len(breakdownBytes) > 0 {
			_ = json.Unmarshal(breakdownBytes, &st.ScoreBreakdown)
		}
		if st.ScoreBreakdown == nil {
			st.ScoreBreakdown = make(map[string]float64)
		}
		result = append(result, &st)
	}
	return result, rows.Err()
}
