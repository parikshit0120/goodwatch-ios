-- ============================================
-- SECTION 3: RECOMMENDATION LOGS TABLE
-- Append-only log of all recommendations
-- Used for:
--   - Debugging validation failures
--   - Analytics on recommendation quality
--   - Ensuring repeat prevention works
-- ============================================

-- ============================================
-- TABLE: recommendation_logs
-- ============================================
CREATE TABLE IF NOT EXISTS recommendation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    movie_title TEXT NOT NULL,
    goodscore FLOAT NOT NULL,
    threshold_used FLOAT NOT NULL,
    mood TEXT,
    time_of_day TEXT,
    accepted BOOLEAN DEFAULT NULL,  -- NULL = shown, TRUE = watch_now, FALSE = rejected
    rejection_reason TEXT,
    candidate_count INT NOT NULL,
    platforms_matched TEXT[],
    language_matched TEXT,
    intent_tags_matched TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_recommendation_logs_user_id ON recommendation_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_logs_movie_id ON recommendation_logs(movie_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_logs_created_at ON recommendation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_recommendation_logs_accepted ON recommendation_logs(accepted);

-- RLS policies
ALTER TABLE recommendation_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own recommendation logs" ON recommendation_logs;
DROP POLICY IF EXISTS "Users can insert own recommendation logs" ON recommendation_logs;

CREATE POLICY "Users can view own recommendation logs" ON recommendation_logs
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own recommendation logs" ON recommendation_logs
    FOR INSERT WITH CHECK (true);

-- ============================================
-- TABLE: validation_failures (Debug table)
-- Stores movies that failed validation for debugging
-- ============================================
CREATE TABLE IF NOT EXISTS validation_failures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    movie_title TEXT NOT NULL,
    failure_type TEXT NOT NULL,
    failure_details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_validation_failures_user_id ON validation_failures(user_id);
CREATE INDEX IF NOT EXISTS idx_validation_failures_failure_type ON validation_failures(failure_type);

ALTER TABLE validation_failures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all validation failures" ON validation_failures;
CREATE POLICY "Allow all validation failures" ON validation_failures
    FOR ALL USING (true);

-- ============================================
-- FUNCTION: Log recommendation
-- ============================================
CREATE OR REPLACE FUNCTION log_recommendation(
    p_user_id UUID,
    p_movie_id UUID,
    p_movie_title TEXT,
    p_goodscore FLOAT,
    p_threshold FLOAT,
    p_mood TEXT,
    p_time_of_day TEXT,
    p_candidate_count INT,
    p_platforms TEXT[],
    p_language TEXT,
    p_intent_tags TEXT[]
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO recommendation_logs (
        user_id,
        movie_id,
        movie_title,
        goodscore,
        threshold_used,
        mood,
        time_of_day,
        candidate_count,
        platforms_matched,
        language_matched,
        intent_tags_matched
    ) VALUES (
        p_user_id,
        p_movie_id,
        p_movie_title,
        p_goodscore,
        p_threshold,
        p_mood,
        p_time_of_day,
        p_candidate_count,
        p_platforms,
        p_language,
        p_intent_tags
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Update recommendation outcome
-- Called when user accepts or rejects
-- ============================================
CREATE OR REPLACE FUNCTION update_recommendation_outcome(
    p_log_id UUID,
    p_accepted BOOLEAN,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE recommendation_logs
    SET
        accepted = p_accepted,
        rejection_reason = p_rejection_reason
    WHERE id = p_log_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get user's rejection stats
-- Useful for understanding patterns
-- ============================================
CREATE OR REPLACE FUNCTION get_user_rejection_stats(p_user_id UUID)
RETURNS TABLE (
    total_recommendations BIGINT,
    accepted_count BIGINT,
    rejected_count BIGINT,
    acceptance_rate FLOAT,
    common_rejection_reasons JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT as total_recommendations,
        COUNT(*) FILTER (WHERE accepted = true)::BIGINT as accepted_count,
        COUNT(*) FILTER (WHERE accepted = false)::BIGINT as rejected_count,
        CASE
            WHEN COUNT(*) FILTER (WHERE accepted IS NOT NULL) > 0
            THEN COUNT(*) FILTER (WHERE accepted = true)::FLOAT /
                 COUNT(*) FILTER (WHERE accepted IS NOT NULL)::FLOAT
            ELSE 0.0
        END as acceptance_rate,
        (
            SELECT COALESCE(jsonb_object_agg(rejection_reason, cnt), '{}'::jsonb)
            FROM (
                SELECT rejection_reason, COUNT(*)::INT as cnt
                FROM recommendation_logs
                WHERE user_id = p_user_id AND rejection_reason IS NOT NULL
                GROUP BY rejection_reason
                ORDER BY cnt DESC
                LIMIT 5
            ) sub
        ) as common_rejection_reasons
    FROM recommendation_logs
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Check if movie was already recommended to user
-- SECTION 8: Repeat prevention at DB level
-- ============================================
CREATE OR REPLACE FUNCTION was_movie_recommended(
    p_user_id UUID,
    p_movie_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM recommendation_logs
        WHERE user_id = p_user_id AND movie_id = p_movie_id
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get user's recommendation history
-- ============================================
CREATE OR REPLACE FUNCTION get_recommendation_history(
    p_user_id UUID,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    movie_id UUID,
    movie_title TEXT,
    goodscore FLOAT,
    accepted BOOLEAN,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rl.movie_id,
        rl.movie_title,
        rl.goodscore,
        rl.accepted,
        rl.rejection_reason,
        rl.created_at
    FROM recommendation_logs rl
    WHERE rl.user_id = p_user_id
    ORDER BY rl.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
