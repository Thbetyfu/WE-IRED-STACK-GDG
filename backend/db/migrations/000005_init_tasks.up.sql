-- Migrasi skema penugasan relawan (FR-TSK, SDD 5.2, N-13)

CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    volunteer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'disarankan' CHECK (status IN ('disarankan', 'ditugaskan', 'diterima', 'dalam_perjalanan', 'dijangkau', 'selesai', 'ditolak', 'dibatalkan')),
    outcome VARCHAR(32) CHECK (outcome IS NULL OR outcome IN ('aman_di_tempat', 'dievakuasi', 'dirujuk', 'butuh_lanjutan')),
    reject_reason TEXT,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    reached_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_incident_status ON tasks(incident_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_volunteer ON tasks(volunteer_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_household ON tasks(household_id);
