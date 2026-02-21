-- Fix profile_audits table to match audit_emotional_profiles.py column expectations
-- The taste_graph_v1 migration created a simpler schema than what the script writes

DROP TABLE IF EXISTS profile_audits;

CREATE TABLE profile_audits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    movie_title TEXT,
    supabase_id INTEGER,
    run_timestamp TEXT,
    overall_mae REAL,
    pass_count INTEGER DEFAULT 0,
    fail_count INTEGER DEFAULT 0,
    missing_count INTEGER DEFAULT 0,
    pass_rate REAL,
    verdict TEXT CHECK (verdict IN ('RELIABLE', 'NEEDS_RECALIBRATION', 'BROKEN', 'PASS', 'FAIL', 'MARGINAL')),
    stored_profile JSONB,
    expected_profile JSONB,
    dimension_results JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profile_audits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read audits" ON profile_audits FOR SELECT USING (true);
CREATE POLICY "Service writes audits" ON profile_audits FOR ALL USING (true);
