-- GoodWatch Supabase Schema (Updated for existing tables)
-- Adds missing columns and creates new tables

-- ============================================
-- TABLE: user_profiles
-- ============================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    preferred_languages TEXT[] DEFAULT '{}',
    platforms TEXT[] DEFAULT '{}',
    mood_preferences JSONB DEFAULT '{}',
    runtime_preferences JSONB DEFAULT '{}',
    confidence_level FLOAT DEFAULT 0.0,
    profile_version INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

-- ============================================
-- TABLE: interactions
-- ============================================
CREATE TABLE IF NOT EXISTS interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('shown', 'watch_now', 'not_tonight', 'already_seen')),
    rejection_reason TEXT,
    context JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for interaction queries
CREATE INDEX IF NOT EXISTS idx_interactions_user_id ON interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_movie_id ON interactions(movie_id);
CREATE INDEX IF NOT EXISTS idx_interactions_action ON interactions(action);
CREATE INDEX IF NOT EXISTS idx_interactions_user_movie ON interactions(user_id, movie_id);

-- ============================================
-- TABLE: feedback
-- ============================================
CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    sentiment TEXT NOT NULL CHECK (sentiment IN ('loved', 'liked', 'neutral', 'regretted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for feedback queries
CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_movie_id ON feedback(movie_id);

-- ============================================
-- TABLE: rejected_movies (permanent exclusions)
-- ============================================
CREATE TABLE IF NOT EXISTS rejected_movies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('already_seen', 'not_interested', 'permanent_skip')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);

-- Index for rejection lookups
CREATE INDEX IF NOT EXISTS idx_rejected_movies_user_id ON rejected_movies(user_id);

-- ============================================
-- FUNCTION: Update user_profiles.updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_user_profile_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.profile_version = OLD.profile_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-updating timestamp and version
DROP TRIGGER IF EXISTS trigger_update_user_profile ON user_profiles;
CREATE TRIGGER trigger_update_user_profile
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_user_profile_timestamp();

-- ============================================
-- FUNCTION: Update users.last_active_at
-- ============================================
CREATE OR REPLACE FUNCTION update_user_last_active()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users SET last_active_at = NOW() WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update last_active on interaction
DROP TRIGGER IF EXISTS trigger_update_last_active ON interactions;
CREATE TRIGGER trigger_update_last_active
    AFTER INSERT ON interactions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_last_active();

-- ============================================
-- RLS Policies (Row Level Security)
-- ============================================
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE rejected_movies ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view own interactions" ON interactions;
DROP POLICY IF EXISTS "Users can insert interactions" ON interactions;
DROP POLICY IF EXISTS "Users can view own feedback" ON feedback;
DROP POLICY IF EXISTS "Users can insert feedback" ON feedback;
DROP POLICY IF EXISTS "Users can view own rejections" ON rejected_movies;
DROP POLICY IF EXISTS "Users can insert rejections" ON rejected_movies;

-- User profiles policies
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (true);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (true);

-- Interactions policies
CREATE POLICY "Users can view own interactions" ON interactions
    FOR SELECT USING (true);

CREATE POLICY "Users can insert interactions" ON interactions
    FOR INSERT WITH CHECK (true);

-- Feedback policies
CREATE POLICY "Users can view own feedback" ON feedback
    FOR SELECT USING (true);

CREATE POLICY "Users can insert feedback" ON feedback
    FOR INSERT WITH CHECK (true);

-- Rejected movies policies
CREATE POLICY "Users can view own rejections" ON rejected_movies
    FOR SELECT USING (true);

CREATE POLICY "Users can insert rejections" ON rejected_movies
    FOR INSERT WITH CHECK (true);

-- ============================================
-- FUNCTION: Get recommended movie (updated for your movies table)
-- Uses your existing movies table structure
-- INCLUDES HARD QUALITY GATES (NON-NEGOTIABLE)
-- ============================================
CREATE OR REPLACE FUNCTION get_recommended_movie(
    p_user_id UUID,
    p_platforms TEXT[],
    p_max_runtime INT DEFAULT 180,
    p_mood TEXT DEFAULT 'neutral'
)
RETURNS TABLE (
    movie_id UUID,
    title TEXT,
    goodscore FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id as movie_id,
        m.title,
        COALESCE(m.imdb_rating, m.vote_average, 0.0)::FLOAT as goodscore
    FROM movies m
    WHERE
        m.ott_providers IS NOT NULL
        AND jsonb_array_length(m.ott_providers) > 0
        AND COALESCE(m.runtime, 120) <= p_max_runtime
        -- HARD QUALITY GATES (NON-NEGOTIABLE)
        -- No garbage content should EVER be recommended
        AND COALESCE(m.imdb_rating, m.vote_average, 0) >= 6.5  -- Quality floor
        AND COALESCE(m.imdb_votes, m.vote_count, 0) >= 500     -- Proof of real audience
        AND COALESCE(m.runtime, 120) >= 60                      -- No shorts
        AND COALESCE(m.runtime, 120) <= 240                     -- No TV series masquerading as movies
        AND m.content_type = 'movie'                            -- No cooking shows, reality TV
        AND m.id NOT IN (
            SELECT rm.movie_id FROM rejected_movies rm WHERE rm.user_id = p_user_id
        )
        AND m.id NOT IN (
            SELECT i.movie_id FROM interactions i
            WHERE i.user_id = p_user_id
            AND i.action IN ('not_tonight', 'already_seen')
            AND i.created_at > NOW() - INTERVAL '7 days'
        )
    ORDER BY
        COALESCE(m.imdb_rating, m.vote_average, 0) DESC,
        m.popularity DESC NULLS LAST
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;
