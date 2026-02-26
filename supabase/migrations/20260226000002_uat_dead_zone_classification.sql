-- UAT Dead Zone Classification
-- Adds columns for classifying dead zones as fixable vs accepted
-- Part of UAT Engine v1.1

ALTER TABLE uat_scenarios ADD COLUMN IF NOT EXISTS dead_zone_class TEXT;
ALTER TABLE uat_runs ADD COLUMN IF NOT EXISTS fixable_dead_zones INTEGER;
ALTER TABLE uat_runs ADD COLUMN IF NOT EXISTS accepted_dead_zones INTEGER;

-- Index for filtering by classification
CREATE INDEX IF NOT EXISTS idx_uat_scenarios_dz_class
    ON uat_scenarios(dead_zone_class) WHERE dead_zone_class IS NOT NULL;
