-- ============================================
-- GoodWatch Taste Graph & Behavioral Learning Engine
-- Migration v1: Foundation Tables
-- ============================================
-- Run this migration against the PRIMARY Supabase project:
--   jdjqrlkynwfhbtyuddjk.supabase.co
--
-- Tables created:
--   1. movie_intelligence — raw sentiment data from internet sources
--   2. watch_feedback — post-watch user emotional feedback
--   3. user_taste_profiles — per-user learned emotional preferences
--   4. profile_audits — audit results for emotional profile validation
--
-- Columns added to movies:
--   - profile_version (INT DEFAULT 1)
--   - profile_enriched_at (TIMESTAMPTZ)
--   - profile_source_richness (TEXT)
--   - embedding_version (INT DEFAULT 1)
-- ============================================

-- 1. movie_intelligence: Raw intelligence corpus from internet sources
CREATE TABLE IF NOT EXISTS movie_intelligence (
    tmdb_id INTEGER PRIMARY KEY,
    tmdb_reviews JSONB DEFAULT '[]',
    tmdb_review_count INTEGER DEFAULT 0,
    wikipedia_reception TEXT,
    reddit_discussions JSONB DEFAULT '[]',
    reddit_post_count INTEGER DEFAULT 0,
    omdb_plot TEXT,
    omdb_rt_score TEXT,
    omdb_metacritic TEXT,
    omdb_rated TEXT,
    omdb_awards TEXT,
    source_richness TEXT DEFAULT 'low' CHECK (source_richness IN ('high', 'medium', 'low')),
    collected_at TIMESTAMPTZ DEFAULT now(),
    collection_version INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_movie_intel_richness ON movie_intelligence(source_richness);
CREATE INDEX IF NOT EXISTS idx_movie_intel_collected ON movie_intelligence(collected_at);

ALTER TABLE movie_intelligence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Service reads all intel" ON movie_intelligence;
CREATE POLICY "Service reads all intel" ON movie_intelligence FOR SELECT USING (true);
DROP POLICY IF EXISTS "Service writes intel" ON movie_intelligence;
CREATE POLICY "Service writes intel" ON movie_intelligence FOR ALL USING (true);


-- 2. watch_feedback: Post-watch emotional feedback from users
CREATE TABLE IF NOT EXISTS watch_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL,

    -- Core satisfaction
    finished BOOLEAN,
    satisfaction SMALLINT CHECK (satisfaction >= 1 AND satisfaction <= 5),
    would_pick_again BOOLEAN,

    -- Emotional feedback (all 8 dimensions matching EmotionalProfile)
    felt_comfort SMALLINT CHECK (felt_comfort >= 1 AND felt_comfort <= 5),
    felt_intensity SMALLINT CHECK (felt_intensity >= 1 AND felt_intensity <= 5),
    felt_energy SMALLINT CHECK (felt_energy >= 1 AND felt_energy <= 5),
    felt_humour SMALLINT CHECK (felt_humour >= 1 AND felt_humour <= 5),
    mood_after TEXT CHECK (mood_after IN ('better', 'same', 'worse')),

    -- Context (automatic, not user input)
    time_of_day TEXT CHECK (time_of_day IN ('morning', 'afternoon', 'evening', 'night', 'late_night')),
    day_of_week SMALLINT CHECK (day_of_week >= 0 AND day_of_week <= 6),

    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_watch_feedback_user ON watch_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_watch_feedback_movie ON watch_feedback(movie_id);
CREATE INDEX IF NOT EXISTS idx_watch_feedback_satisfaction ON watch_feedback(satisfaction);

ALTER TABLE watch_feedback ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own feedback" ON watch_feedback;
CREATE POLICY "Users manage own feedback" ON watch_feedback FOR ALL USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Public aggregate read" ON watch_feedback;
CREATE POLICY "Public aggregate read" ON watch_feedback FOR SELECT USING (true);


-- 3. user_taste_profiles: Per-user learned emotional preferences
CREATE TABLE IF NOT EXISTS user_taste_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Learned preferences (0.0-1.0, null = not enough data)
    -- ALL 8 dimensions matching EmotionalProfile
    pref_comfort REAL,
    pref_darkness REAL,
    pref_intensity REAL,
    pref_energy REAL,
    pref_complexity REAL,
    pref_rewatchability REAL,
    pref_humour REAL,
    pref_mental_stimulation REAL,

    -- Contextual preferences
    weeknight_profile JSONB DEFAULT '{}',
    weekend_profile JSONB DEFAULT '{}',
    late_night_profile JSONB DEFAULT '{}',

    -- Confidence
    total_feedback_count INTEGER DEFAULT 0,
    satisfaction_avg REAL,
    last_computed_at TIMESTAMPTZ DEFAULT now(),

    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_taste_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own taste" ON user_taste_profiles;
CREATE POLICY "Users read own taste" ON user_taste_profiles FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Service writes taste" ON user_taste_profiles;
CREATE POLICY "Service writes taste" ON user_taste_profiles FOR ALL USING (true);


-- 4. profile_audits: Audit results for emotional profile validation
CREATE TABLE IF NOT EXISTS profile_audits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    run_at TIMESTAMPTZ DEFAULT now(),
    anchor_count INTEGER DEFAULT 0,
    matched_count INTEGER DEFAULT 0,
    overall_mae REAL,
    per_dimension_mae JSONB DEFAULT '{}',
    verdict TEXT CHECK (verdict IN ('RELIABLE', 'NEEDS_RECALIBRATION', 'BROKEN')),
    details JSONB DEFAULT '{}',
    profile_version_audited INTEGER DEFAULT 1
);

ALTER TABLE profile_audits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read audits" ON profile_audits;
CREATE POLICY "Public read audits" ON profile_audits FOR SELECT USING (true);
DROP POLICY IF EXISTS "Service writes audits" ON profile_audits;
CREATE POLICY "Service writes audits" ON profile_audits FOR ALL USING (true);


-- 5. Add columns to movies table (safe: all have DEFAULT values)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movies' AND column_name = 'profile_version') THEN
        ALTER TABLE movies ADD COLUMN profile_version INTEGER DEFAULT 1;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movies' AND column_name = 'profile_enriched_at') THEN
        ALTER TABLE movies ADD COLUMN profile_enriched_at TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movies' AND column_name = 'profile_source_richness') THEN
        ALTER TABLE movies ADD COLUMN profile_source_richness TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movies' AND column_name = 'embedding_version') THEN
        ALTER TABLE movies ADD COLUMN embedding_version INTEGER DEFAULT 1;
    END IF;
END $$;
