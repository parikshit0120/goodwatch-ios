-- ============================================
-- SECTION 8: SUPABASE STORAGE CONTRACT
-- Persist permanently:
--   - user_profiles
--   - user_platforms
--   - user_languages
--   - user_runtime_window
--   - interactions
--   - per-user tag_weights
--
-- Schema rules:
--   - user_id is primary foreign key
--   - movie_id indexed
--   - timestamps preserved
-- ============================================

-- ============================================
-- TABLE: user_tag_weights (per-user tag weights for rejection learning)
-- ============================================
CREATE TABLE IF NOT EXISTS user_tag_weights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tag TEXT NOT NULL,
    weight FLOAT DEFAULT 1.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, tag)
);

-- Indexes for tag weight lookups
CREATE INDEX IF NOT EXISTS idx_user_tag_weights_user_id ON user_tag_weights(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tag_weights_tag ON user_tag_weights(tag);

-- RLS for tag weights
ALTER TABLE user_tag_weights ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own tag weights" ON user_tag_weights;
DROP POLICY IF EXISTS "Users can insert own tag weights" ON user_tag_weights;
DROP POLICY IF EXISTS "Users can update own tag weights" ON user_tag_weights;

CREATE POLICY "Users can view own tag weights" ON user_tag_weights
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own tag weights" ON user_tag_weights
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own tag weights" ON user_tag_weights
    FOR UPDATE USING (true);

-- ============================================
-- Ensure user_profiles has all required fields
-- ============================================
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS min_runtime INT DEFAULT 60;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS max_runtime INT DEFAULT 180;

-- ============================================
-- Add 'abandoned' and 'completed' actions to interactions
-- ============================================
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS interactions_action_check;
ALTER TABLE interactions ADD CONSTRAINT interactions_action_check
    CHECK (action IN ('shown', 'watch_now', 'not_tonight', 'already_seen', 'abandoned', 'completed'));

-- ============================================
-- FUNCTION: Update tag weight (upsert)
-- ============================================
CREATE OR REPLACE FUNCTION upsert_tag_weight(
    p_user_id UUID,
    p_tag TEXT,
    p_delta FLOAT
)
RETURNS FLOAT AS $$
DECLARE
    v_new_weight FLOAT;
BEGIN
    INSERT INTO user_tag_weights (user_id, tag, weight, updated_at)
    VALUES (p_user_id, p_tag, 1.0 + p_delta, NOW())
    ON CONFLICT (user_id, tag)
    DO UPDATE SET
        weight = user_tag_weights.weight + p_delta,
        updated_at = NOW()
    RETURNING weight INTO v_new_weight;

    RETURN v_new_weight;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get all tag weights for a user
-- ============================================
CREATE OR REPLACE FUNCTION get_user_tag_weights(p_user_id UUID)
RETURNS TABLE (tag TEXT, weight FLOAT) AS $$
BEGIN
    RETURN QUERY
    SELECT utw.tag, utw.weight
    FROM user_tag_weights utw
    WHERE utw.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Refine user profile from interactions
-- "Every app return MUST refine the profile"
-- ============================================
CREATE OR REPLACE FUNCTION refine_user_profile(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_interaction RECORD;
    v_delta FLOAT;
    v_movie RECORD;
BEGIN
    -- Get recent unprocessed interactions
    FOR v_interaction IN
        SELECT i.movie_id, i.action, i.created_at
        FROM interactions i
        WHERE i.user_id = p_user_id
        AND i.created_at > (
            SELECT COALESCE(MAX(updated_at), '1970-01-01'::timestamptz)
            FROM user_profiles
            WHERE user_id = p_user_id
        )
        ORDER BY i.created_at
    LOOP
        -- Determine delta based on action
        v_delta := CASE v_interaction.action
            WHEN 'completed' THEN 0.1
            WHEN 'not_tonight' THEN -0.1
            WHEN 'abandoned' THEN -0.3
            ELSE 0.0
        END;

        -- Skip if no weight change
        IF v_delta = 0 THEN
            CONTINUE;
        END IF;

        -- Get movie tags
        SELECT tags INTO v_movie FROM movies WHERE id = v_interaction.movie_id;

        -- Update weights for each tag
        IF v_movie.tags IS NOT NULL THEN
            FOR i IN 1..array_length(v_movie.tags, 1) LOOP
                PERFORM upsert_tag_weight(p_user_id, v_movie.tags[i], v_delta);
            END LOOP;
        END IF;
    END LOOP;

    -- Update profile timestamp
    UPDATE user_profiles SET updated_at = NOW() WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get complete user profile (for app return)
-- ============================================
CREATE OR REPLACE FUNCTION get_refined_profile(p_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    preferred_languages TEXT[],
    platforms TEXT[],
    min_runtime INT,
    max_runtime INT,
    tag_weights JSONB,
    profile_version INT
) AS $$
BEGIN
    -- First refine the profile
    PERFORM refine_user_profile(p_user_id);

    -- Return refined profile
    RETURN QUERY
    SELECT
        up.user_id,
        up.preferred_languages,
        up.platforms,
        up.min_runtime,
        up.max_runtime,
        (
            SELECT COALESCE(jsonb_object_agg(utw.tag, utw.weight), '{}'::jsonb)
            FROM user_tag_weights utw
            WHERE utw.user_id = up.user_id
        ) as tag_weights,
        up.profile_version
    FROM user_profiles up
    WHERE up.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;
