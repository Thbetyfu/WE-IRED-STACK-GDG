CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel VARCHAR(32) NOT NULL,
    recipient VARCHAR(64) NOT NULL,
    template VARCHAR(64),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(32) NOT NULL DEFAULT 'antri',
    provider_id VARCHAR(128),
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications (recipient);
CREATE INDEX IF NOT EXISTS idx_notifications_provider_id ON notifications (provider_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications (status);

CREATE TABLE IF NOT EXISTS wa_sessions (
    phone VARCHAR(64) PRIMARY KEY,
    incident_id VARCHAR(64) NOT NULL,
    household_id VARCHAR(64) NOT NULL,
    report_id VARCHAR(64) NOT NULL,
    step VARCHAR(32) NOT NULL,
    context JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wa_processed_messages (
    message_id VARCHAR(128) PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wa_reminder_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id VARCHAR(64) NOT NULL,
    household_id VARCHAR(64) NOT NULL,
    step VARCHAR(32) NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_reminder UNIQUE (incident_id, household_id, step)
);
