-- Migration: Create audit system tables
-- Run this in Supabase SQL Editor

-- Audit runs (one per evening execution)
CREATE TABLE IF NOT EXISTS audit_runs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    run_date DATE NOT NULL DEFAULT CURRENT_DATE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    total_checks INTEGER DEFAULT 0,
    passed INTEGER DEFAULT 0,
    failed INTEGER DEFAULT 0,
    warnings INTEGER DEFAULT 0,
    skipped INTEGER DEFAULT 0,
    score_pct NUMERIC(5,2) DEFAULT 0,
    critical_failures INTEGER DEFAULT 0,
    run_duration_seconds INTEGER,
    agent_version TEXT DEFAULT '1.0',
    trigger_type TEXT DEFAULT 'cron' CHECK (trigger_type IN ('cron', 'manual', 'ci')),
    summary_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual audit check results
CREATE TABLE IF NOT EXISTS audit_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    run_id UUID NOT NULL REFERENCES audit_runs(id) ON DELETE CASCADE,
    check_id TEXT NOT NULL,          -- e.g., "A01", "B15", "I19"
    section TEXT NOT NULL,            -- e.g., "data_integrity", "engine_invariants"
    check_name TEXT NOT NULL,         -- human-readable description
    severity TEXT NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
    status TEXT NOT NULL CHECK (status IN ('pass', 'fail', 'warn', 'skip', 'error')),
    expected_value TEXT,              -- what we expected
    actual_value TEXT,                -- what we found
    detail TEXT,                      -- explanation / remediation needed
    source_ref TEXT,                  -- e.g., "INV-L02", "CLAUDE.md Section 15"
    duration_ms INTEGER,              -- how long this check took
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast dashboard queries
CREATE INDEX IF NOT EXISTS idx_audit_runs_date ON audit_runs(run_date DESC);
CREATE INDEX IF NOT EXISTS idx_audit_results_run ON audit_results(run_id);
CREATE INDEX IF NOT EXISTS idx_audit_results_status ON audit_results(status);
CREATE INDEX IF NOT EXISTS idx_audit_results_severity ON audit_results(severity);
CREATE INDEX IF NOT EXISTS idx_audit_results_check ON audit_results(check_id);

-- Protected file hashes (for section D checks)
CREATE TABLE IF NOT EXISTS protected_file_hashes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    file_path TEXT NOT NULL,
    approved_hash TEXT NOT NULL,       -- SHA-256 of last approved version
    approved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_by TEXT DEFAULT 'parikshit',
    notes TEXT,
    UNIQUE(file_path)
);

-- Insert baseline protected file entries (hashes to be updated by first audit run)
INSERT INTO protected_file_hashes (file_path, approved_hash, notes) VALUES
    ('GWRecommendationEngine.swift', 'PENDING_FIRST_RUN', 'Recommendation engine'),
    ('Movie.swift', 'PENDING_FIRST_RUN', 'Data model'),
    ('GWSpec.swift', 'PENDING_FIRST_RUN', 'GoodScore + TagWeightStore'),
    ('RootFlowView.swift', 'PENDING_FIRST_RUN', 'App flow/construct'),
    ('SupabaseConfig.swift', 'PENDING_FIRST_RUN', 'Database config'),
    ('CLAUDE.md', 'PENDING_FIRST_RUN', 'Project memory'),
    ('INVARIANTS.md', 'PENDING_FIRST_RUN', 'Behavioral contracts')
ON CONFLICT (file_path) DO NOTHING;

-- RLS: audit tables are public read, write only by service role
ALTER TABLE audit_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE protected_file_hashes ENABLE ROW LEVEL SECURITY;

-- Public read for dashboard
CREATE POLICY "Public read audit_runs" ON audit_runs FOR SELECT USING (true);
CREATE POLICY "Public read audit_results" ON audit_results FOR SELECT USING (true);
CREATE POLICY "Public read protected_file_hashes" ON protected_file_hashes FOR SELECT USING (true);

-- Service role write (for the agent)
CREATE POLICY "Service write audit_runs" ON audit_runs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service write audit_results" ON audit_results FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Service write protected_file_hashes" ON protected_file_hashes FOR ALL USING (true) WITH CHECK (true);
