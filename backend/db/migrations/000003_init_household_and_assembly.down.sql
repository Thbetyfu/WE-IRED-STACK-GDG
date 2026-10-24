DROP TABLE IF EXISTS volunteer_blocks CASCADE;
DROP TABLE IF EXISTS volunteers CASCADE;
DROP TABLE IF EXISTS block_assembly_points CASCADE;
DROP TABLE IF EXISTS assembly_points CASCADE;
DROP TABLE IF EXISTS consents CASCADE;
DROP TABLE IF EXISTS members CASCADE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_households_block'
    ) THEN
        ALTER TABLE households DROP CONSTRAINT fk_households_block;
    END IF;
END $$;

DROP TABLE IF EXISTS blocks CASCADE;
