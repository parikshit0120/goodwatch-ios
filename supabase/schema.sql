-- GoodWatch Supabase Schema
-- This file documents the complete schema deployed to Supabase

-- ============================================
-- TABLE: users (existing, with added columns)
-- ============================================
-- Columns: id, auth_provider, email, device_id, created_at, last_active_at
-- device_id and last_active_at were added via migration

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

-- ============================================
-- TABLE: rejected_movies
-- ============================================
CREATE TABLE IF NOT EXISTS rejected_movies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('already_seen', 'not_interested', 'permanent_skip')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);

-- ============================================
-- FUNCTION: get_recommended_movie
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
        COALESCE(m.imdb_rating, m.vote_average, 7.0)::FLOAT as goodscore
    FROM movies m
    WHERE
        m.ott_providers IS NOT NULL
        AND jsonb_array_length(m.ott_providers) > 0
        AND COALESCE(m.runtime, 120) <= p_max_runtime
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
        COALESCE(m.imdb_rating, m.vote_average, 7.0) DESC,
        m.popularity DESC NULLS LAST
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;
