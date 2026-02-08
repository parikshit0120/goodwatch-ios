-- ============================================
-- SECTION 8: RECOMMENDATION SESSIONS TABLE
-- For replay/debugging with session_id and input_snapshot_hash
-- ============================================

CREATE TABLE IF NOT EXISTS recommendation_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    input_snapshot_hash TEXT NOT NULL,
    profile_snapshot JSONB NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at TIMESTAMP WITH TIME ZONE,
    recommended_movie_id UUID,
    outcome TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_user_id ON recommendation_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_session_id ON recommendation_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_hash ON recommendation_sessions(input_snapshot_hash);
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_outcome ON recommendation_sessions(outcome);
CREATE INDEX IF NOT EXISTS idx_recommendation_sessions_created_at ON recommendation_sessions(created_at);

-- RLS policies
ALTER TABLE recommendation_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own sessions" ON recommendation_sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON recommendation_sessions;

CREATE POLICY "Users can view own sessions" ON recommendation_sessions
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own sessions" ON recommendation_sessions
    FOR INSERT WITH CHECK (true);

-- ============================================
-- FUNCTION: Check if same input produces same output
-- Used for verifying determinism
-- ============================================
CREATE OR REPLACE FUNCTION verify_determinism(
    p_user_id UUID,
    p_input_hash TEXT
)
RETURNS TABLE (
    session_id TEXT,
    recommended_movie_id UUID,
    outcome TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rs.session_id,
        rs.recommended_movie_id,
        rs.outcome,
        rs.created_at
    FROM recommendation_sessions rs
    WHERE rs.user_id = p_user_id
      AND rs.input_snapshot_hash = p_input_hash
    ORDER BY rs.created_at DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get session details for debugging
-- ============================================
CREATE OR REPLACE FUNCTION get_session_details(p_session_id TEXT)
RETURNS TABLE (
    session_id TEXT,
    user_id UUID,
    input_snapshot_hash TEXT,
    profile_snapshot JSONB,
    started_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    recommended_movie_id UUID,
    outcome TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rs.session_id,
        rs.user_id,
        rs.input_snapshot_hash,
        rs.profile_snapshot,
        rs.started_at,
        rs.ended_at,
        rs.recommended_movie_id,
        rs.outcome
    FROM recommendation_sessions rs
    WHERE rs.session_id = p_session_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TABLE: rejected_movies (Permanent exclusion list)
-- ============================================
CREATE TABLE IF NOT EXISTS rejected_movies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_rejected_movies_user_id ON rejected_movies(user_id);
CREATE INDEX IF NOT EXISTS idx_rejected_movies_movie_id ON rejected_movies(movie_id);

ALTER TABLE rejected_movies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own rejections" ON rejected_movies;
CREATE POLICY "Users can manage own rejections" ON rejected_movies
    FOR ALL USING (true);

-- ============================================
-- TABLE: interactions
-- ============================================
CREATE TABLE IF NOT EXISTS interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    action TEXT NOT NULL,
    rejection_reason TEXT,
    context JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_interactions_user_id ON interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_movie_id ON interactions(movie_id);
CREATE INDEX IF NOT EXISTS idx_interactions_action ON interactions(action);
CREATE INDEX IF NOT EXISTS idx_interactions_created_at ON interactions(created_at);

ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own interactions" ON interactions;
CREATE POLICY "Users can manage own interactions" ON interactions
    FOR ALL USING (true);

-- ============================================
-- TABLE: feedback
-- ============================================
CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    sentiment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedback_user_id ON feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_movie_id ON feedback(movie_id);

ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own feedback" ON feedback;
CREATE POLICY "Users can manage own feedback" ON feedback
    FOR ALL USING (true);
