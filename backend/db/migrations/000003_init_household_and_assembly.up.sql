-- Migrasi skema blok, anggota keluarga, persetujuan privasi, titik kumpul, dan relawan (SDD 5.2, N-07, N-08)

CREATE TABLE IF NOT EXISTS blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rt_id UUID NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    polygon JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_blocks_rt_id ON blocks(rt_id);

-- Menambahkan foreign key blok pada tabel households
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_households_block'
    ) THEN
        ALTER TABLE households ADD CONSTRAINT fk_households_block 
        FOREIGN KEY (block_id) REFERENCES blocks(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    idx SMALLINT NOT NULL CHECK (idx >= 0 AND idx <= 7),
    name VARCHAR(128) NOT NULL,
    birth_year INT NOT NULL,
    sex VARCHAR(16) NOT NULL,
    relation VARCHAR(32) NOT NULL,
    vuln_flags INT NOT NULL DEFAULT 0,
    health_notes_enc BYTEA,
    needs_evac_assist BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_household_idx UNIQUE (household_id, idx)
);

CREATE INDEX IF NOT EXISTS idx_members_household_id ON members(household_id);

CREATE TABLE IF NOT EXISTS consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    given_by VARCHAR(128) NOT NULL,
    method VARCHAR(32) NOT NULL CHECK (method IN ('aplikasi', 'kertas', 'lisan_disaksikan')),
    text_version VARCHAR(32) NOT NULL,
    given_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_consents_household_id ON consents(household_id);

CREATE TABLE IF NOT EXISTS assembly_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rt_id UUID NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0),
    facilities JSONB NOT NULL DEFAULT '{}'::jsonb,
    contact VARCHAR(128),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assembly_points_rt_id ON assembly_points(rt_id);

CREATE TABLE IF NOT EXISTS block_assembly_points (
    block_id UUID NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
    assembly_point_id UUID NOT NULL REFERENCES assembly_points(id) ON DELETE CASCADE,
    rank SMALLINT NOT NULL CHECK (rank IN (1, 2)),
    PRIMARY KEY (block_id, rank)
);

CREATE TABLE IF NOT EXISTS volunteers (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    rt_id UUID NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
    skills TEXT[] NOT NULL DEFAULT '{}',
    available BOOLEAN NOT NULL DEFAULT true,
    last_lat DOUBLE PRECISION,
    last_lon DOUBLE PRECISION,
    last_loc_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_volunteers_rt_id ON volunteers(rt_id);

CREATE TABLE IF NOT EXISTS volunteer_blocks (
    user_id UUID NOT NULL REFERENCES volunteers(user_id) ON DELETE CASCADE,
    block_id UUID NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, block_id)
);
