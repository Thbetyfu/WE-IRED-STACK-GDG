-- 000006_init_announcements.up.sql
-- SDD 5.3 & 7.6: Signed Announcements (Ed25519) and Posko Delegations

CREATE TABLE IF NOT EXISTS announcements (
    id VARCHAR(64) PRIMARY KEY,
    region_ids TEXT[] NOT NULL,
    incident_id VARCHAR(64),
    short_id BIGINT NOT NULL,
    level VARCHAR(32) NOT NULL DEFAULT 'info',
    text VARCHAR(200) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    signature BYTEA,
    payload_raw BYTEA,
    channels TEXT[] NOT NULL DEFAULT '{"push", "relay"}',
    created_by VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_announcements_region_ids ON announcements USING GIN (region_ids);
CREATE INDEX IF NOT EXISTS idx_announcements_expires_at ON announcements (expires_at);
CREATE INDEX IF NOT EXISTS idx_announcements_incident_id ON announcements (incident_id);

CREATE TABLE IF NOT EXISTS posko_delegations (
    posko_id VARCHAR(64) PRIMARY KEY,
    rt_id VARCHAR(64) NOT NULL,
    posko_public_key BYTEA NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    cloud_signature BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
