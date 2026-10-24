-- 000007_init_posko_sync.up.sql
-- SDD 8.2 & 8.3: Posko Sync Conflicts and Cursor Tracking

CREATE TABLE IF NOT EXISTS sync_conflicts (
    id VARCHAR(64) PRIMARY KEY,
    region_id VARCHAR(64) NOT NULL,
    posko_id VARCHAR(64) NOT NULL,
    entity VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    cloud_version JSONB NOT NULL,
    posko_version JSONB NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'unresolved',
    resolved_by VARCHAR(64),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_conflicts_region_id ON sync_conflicts (region_id);
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON sync_conflicts (status);
