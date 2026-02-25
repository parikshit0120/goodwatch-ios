-- UAT Engine Tables
-- Created: 2026-02-26
-- Purpose: Store automated user acceptance test results for recommendation engine

-- 1. UAT run summaries
CREATE TABLE IF NOT EXISTS uat_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id TEXT UNIQUE NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  total_scenarios INTEGER,
  passed INTEGER,
  failed INTEGER,
  quality_warnings INTEGER,
  avg_goodscore DECIMAL(4,2),
  median_goodscore DECIMAL(4,2),
  min_goodscore DECIMAL(4,2),
  p10_goodscore DECIMAL(4,2),
  mood_coverage JSONB,
  language_coverage JSONB,
  platform_coverage JSONB,
  catalog_size INTEGER,
  engine_version TEXT,
  status TEXT DEFAULT 'running',
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_uat_runs_created ON uat_runs(created_at DESC);

-- 2. Individual scenario results
CREATE TABLE IF NOT EXISTS uat_scenarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id TEXT NOT NULL,
  scenario_id TEXT NOT NULL,
  scenario_type TEXT NOT NULL,
  mood TEXT,
  languages TEXT[] NOT NULL,
  platforms TEXT[] NOT NULL,
  user_tier TEXT NOT NULL,
  energy_level TEXT,
  status TEXT NOT NULL,
  candidate_count INTEGER,
  scored_count INTEGER,
  top_movie_id INTEGER,
  top_movie_title TEXT,
  top_movie_goodscore DECIMAL(4,2),
  top_movie_language TEXT,
  avg_candidate_goodscore DECIMAL(4,2),
  score_spread DECIMAL(4,2),
  genre_diversity INTEGER,
  failure_reason TEXT,
  bottleneck_filter TEXT,
  candidates_before_bottleneck INTEGER,
  execution_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_uat_scenarios_run ON uat_scenarios(run_id);
CREATE INDEX IF NOT EXISTS idx_uat_scenarios_status ON uat_scenarios(status);
CREATE INDEX IF NOT EXISTS idx_uat_scenarios_fail ON uat_scenarios(run_id) WHERE status = 'fail';

-- 3. Coverage heatmap cells
CREATE TABLE IF NOT EXISTS uat_coverage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id TEXT NOT NULL,
  mood TEXT NOT NULL,
  language TEXT NOT NULL,
  platform TEXT NOT NULL,
  user_tier TEXT NOT NULL,
  candidate_count INTEGER,
  has_recommendation BOOLEAN,
  top_goodscore DECIMAL(4,2),
  avg_goodscore DECIMAL(4,2),
  health TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_uat_coverage_run ON uat_coverage(run_id);
CREATE INDEX IF NOT EXISTS idx_uat_coverage_health ON uat_coverage(health);

-- 4. Regression tracking (auto-saved dead zones)
CREATE TABLE IF NOT EXISTS uat_regressions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_config JSONB NOT NULL,
  first_failed_at TIMESTAMPTZ NOT NULL,
  first_fixed_at TIMESTAMPTZ,
  last_checked_at TIMESTAMPTZ,
  last_status TEXT,
  consecutive_passes INTEGER DEFAULT 0,
  tags TEXT[],
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS policies: anon read for command center, service_role for writes
ALTER TABLE uat_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE uat_scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE uat_coverage ENABLE ROW LEVEL SECURITY;
ALTER TABLE uat_regressions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_uat_runs') THEN
    CREATE POLICY anon_read_uat_runs ON uat_runs FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'service_write_uat_runs') THEN
    CREATE POLICY service_write_uat_runs ON uat_runs FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_uat_scenarios') THEN
    CREATE POLICY anon_read_uat_scenarios ON uat_scenarios FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'service_write_uat_scenarios') THEN
    CREATE POLICY service_write_uat_scenarios ON uat_scenarios FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_uat_coverage') THEN
    CREATE POLICY anon_read_uat_coverage ON uat_coverage FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'service_write_uat_coverage') THEN
    CREATE POLICY service_write_uat_coverage ON uat_coverage FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_read_uat_regressions') THEN
    CREATE POLICY anon_read_uat_regressions ON uat_regressions FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'service_write_uat_regressions') THEN
    CREATE POLICY service_write_uat_regressions ON uat_regressions FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;
