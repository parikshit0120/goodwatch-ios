-- Trend Boost Engine: Stores active trend boosts for movies
-- Used by: trend_engine.py (GitHub Actions, daily), iOS app (fetch at recommendation time)
-- INV-T01: boost_score capped at 0.08 via CHECK, no stacking (app-side logic)
-- INV-T02: active_until required (NOT NULL), expired daily by trend engine
-- INV-T03: Trends never override core signals (app-side scoring order)

CREATE TABLE IF NOT EXISTS trend_boosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The trend
    trend_name TEXT NOT NULL,
    trend_type TEXT NOT NULL CHECK (trend_type IN ('news', 'calendar', 'awards')),
    trend_source TEXT NOT NULL,
    keywords TEXT[] NOT NULL DEFAULT '{}',

    -- Boosted movie
    tmdb_id INTEGER NOT NULL,
    movie_title TEXT,
    match_reason TEXT NOT NULL,
    relevance_tag TEXT NOT NULL,

    -- Scoring (INV-T01: ceiling 0.08)
    boost_score DECIMAL(4,3) NOT NULL CHECK (boost_score >= 0.0 AND boost_score <= 0.08),

    -- Lifecycle (INV-T02: active_until required)
    active_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    active_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,

    -- Metadata
    trend_interest_score INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- One boost per movie per trend
    UNIQUE(tmdb_id, trend_name)
);

-- Fast lookup for active boosts (iOS fetch)
CREATE INDEX IF NOT EXISTS idx_trend_boosts_active ON trend_boosts(is_active, active_until);
-- Fast lookup by tmdb_id for active boosts
CREATE INDEX IF NOT EXISTS idx_trend_boosts_tmdb ON trend_boosts(tmdb_id) WHERE is_active = true;

-- RLS: anon can read (iOS app uses anon key), writes require service role
ALTER TABLE trend_boosts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trend_boosts_anon_select"
    ON trend_boosts
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "trend_boosts_service_all"
    ON trend_boosts
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
