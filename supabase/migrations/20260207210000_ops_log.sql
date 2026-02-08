-- ================================================================
-- GoodWatch: ops_log table for unified script/cron monitoring
-- Tracks every run of: enrich_ratings, sync_ott_catalog,
-- export_movies_sheet, sync_metrics, etc.
-- ================================================================

CREATE TABLE IF NOT EXISTS ops_log (
    id SERIAL PRIMARY KEY,
    script_name TEXT NOT NULL,             -- e.g. "enrich_ratings", "sync_ott_catalog"
    status TEXT NOT NULL DEFAULT 'pending', -- pending, running, success, failed
    started_at TIMESTAMPTZ DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    stats JSONB DEFAULT '{}',              -- script-specific metrics
    errors TEXT[] DEFAULT '{}',
    warnings TEXT[] DEFAULT '{}',
    dry_run BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ops_log_script ON ops_log(script_name);
CREATE INDEX IF NOT EXISTS idx_ops_log_created ON ops_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ops_log_status ON ops_log(status);

-- RLS: allow anon inserts (scripts use anon key), reads for authenticated
ALTER TABLE ops_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon insert ops_log"
    ON ops_log FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow anon select ops_log"
    ON ops_log FOR SELECT
    USING (true);
