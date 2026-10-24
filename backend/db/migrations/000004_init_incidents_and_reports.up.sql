-- Migrasi skema insiden, laporan status rumah, household_states, dan riwayat (SDD 5.2, N-09, N-10)

CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rt_id UUID NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
    short_id BIGINT NOT NULL,
    hazard VARCHAR(32) NOT NULL CHECK (hazard IN ('banjir', 'longsor', 'gempa', 'kebakaran', 'lainnya')),
    mode VARCHAR(16) NOT NULL CHECK (mode IN ('nyata', 'latihan')),
    scope_block_ids UUID[] DEFAULT '{}',
    message TEXT NOT NULL,
    started_by UUID NOT NULL REFERENCES users(id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    status VARCHAR(16) NOT NULL DEFAULT 'aktif' CHECK (status IN ('aktif', 'selesai')),
    metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incidents_rt_status ON incidents(rt_id, status);
CREATE INDEX IF NOT EXISTS idx_incidents_short_id ON incidents(short_id);

CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY,
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    seq INT NOT NULL,
    status SMALLINT NOT NULL CHECK (status IN (1, 2, 3)),
    urgency SMALLINT NOT NULL DEFAULT 0 CHECK (urgency IN (0, 1, 2)),
    needs SMALLINT NOT NULL DEFAULT 0,
    member_mask SMALLINT NOT NULL DEFAULT 0,
    message TEXT,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    battery INT,
    channel VARCHAR(32) NOT NULL,
    reporter_user_id UUID REFERENCES users(id),
    beacon_id UUID,
    device_time TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    relay_path JSONB DEFAULT '[]'::jsonb,
    CONSTRAINT uq_reports_seq UNIQUE (incident_id, household_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_reports_incident_hh ON reports(incident_id, household_id);
CREATE INDEX IF NOT EXISTS idx_reports_received_at ON reports(received_at);

CREATE TABLE IF NOT EXISTS household_states (
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    report_id UUID REFERENCES reports(id) ON DELETE SET NULL,
    status SMALLINT NOT NULL CHECK (status IN (1, 2, 3)),
    urgency SMALLINT NOT NULL DEFAULT 0 CHECK (urgency IN (0, 1, 2)),
    needs SMALLINT NOT NULL DEFAULT 0,
    member_mask SMALLINT NOT NULL DEFAULT 0,
    priority_score DOUBLE PRECISION NOT NULL DEFAULT 0,
    score_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
    reached BOOLEAN NOT NULL DEFAULT false,
    unconfirmed_vulnerable SMALLINT NOT NULL DEFAULT 0,
    needs_confirmation BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (incident_id, household_id)
);

CREATE INDEX IF NOT EXISTS idx_household_states_priority ON household_states(incident_id, priority_score DESC);
