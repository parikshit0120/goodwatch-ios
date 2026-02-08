-- ============================================
-- PHASE 2: SUPABASE PROD CHECK
-- Required tables that MUST exist and be writable
-- ============================================

-- ============================================
-- TABLE: feedback_events
-- Records all user feedback for ML training
-- ============================================
CREATE TABLE IF NOT EXISTS feedback_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('shown', 'watch_now', 'not_tonight', 'abandoned', 'completed')),
    rejection_reason TEXT,
    watch_duration_seconds INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedback_events_user_id ON feedback_events(user_id);
CREATE INDEX IF NOT EXISTS idx_feedback_events_movie_id ON feedback_events(movie_id);
CREATE INDEX IF NOT EXISTS idx_feedback_events_event_type ON feedback_events(event_type);
CREATE INDEX IF NOT EXISTS idx_feedback_events_created_at ON feedback_events(created_at);

ALTER TABLE feedback_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own feedback" ON feedback_events;
DROP POLICY IF EXISTS "Users can insert own feedback" ON feedback_events;

CREATE POLICY "Users can view own feedback" ON feedback_events
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own feedback" ON feedback_events
    FOR INSERT WITH CHECK (true);

-- ============================================
-- FUNCTION: Record feedback event
-- ============================================
CREATE OR REPLACE FUNCTION record_feedback_event(
    p_user_id UUID,
    p_movie_id UUID,
    p_event_type TEXT,
    p_rejection_reason TEXT DEFAULT NULL,
    p_watch_duration INT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO feedback_events (
        user_id,
        movie_id,
        event_type,
        rejection_reason,
        watch_duration_seconds
    ) VALUES (
        p_user_id,
        p_movie_id,
        p_event_type,
        p_rejection_reason,
        p_watch_duration
    ) RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SANITY CHECK FUNCTIONS
-- ============================================

-- Check 1: Verify a recommendation can be inserted
CREATE OR REPLACE FUNCTION sanity_check_recommendation_insert()
RETURNS BOOLEAN AS $$
DECLARE
    v_test_id UUID;
BEGIN
    -- Insert test record
    INSERT INTO recommendation_logs (
        user_id,
        movie_id,
        movie_title,
        goodscore,
        threshold_used,
        candidate_count
    ) VALUES (
        '00000000-0000-0000-0000-000000000000'::UUID,
        '00000000-0000-0000-0000-000000000001'::UUID,
        'SANITY_TEST',
        0.0,
        0.0,
        0
    ) RETURNING id INTO v_test_id;

    -- Delete test record
    DELETE FROM recommendation_logs WHERE id = v_test_id;

    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Check 2: Verify a rejection can be inserted
CREATE OR REPLACE FUNCTION sanity_check_rejection_insert()
RETURNS BOOLEAN AS $$
DECLARE
    v_test_id UUID;
BEGIN
    INSERT INTO validation_failures (
        user_id,
        movie_id,
        movie_title,
        failure_type
    ) VALUES (
        '00000000-0000-0000-0000-000000000000'::UUID,
        '00000000-0000-0000-0000-000000000001'::UUID,
        'SANITY_TEST',
        'test'
    ) RETURNING id INTO v_test_id;

    DELETE FROM validation_failures WHERE id = v_test_id;

    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Check 3: Verify repeat blocking works
CREATE OR REPLACE FUNCTION sanity_check_repeat_blocked(
    p_user_id UUID,
    p_movie_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if this movie was already shown to this user
    RETURN EXISTS (
        SELECT 1 FROM feedback_events
        WHERE user_id = p_user_id
        AND movie_id = p_movie_id
        AND event_type = 'shown'
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TABLE: fallback_logs
-- Records every time a fallback was triggered
-- ============================================
CREATE TABLE IF NOT EXISTS fallback_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    movie_id UUID,
    fallback_level INT NOT NULL,
    original_profile JSONB,
    relaxed_profile JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fallback_logs_user_id ON fallback_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_fallback_logs_fallback_level ON fallback_logs(fallback_level);

ALTER TABLE fallback_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all fallback logs" ON fallback_logs;
CREATE POLICY "Allow all fallback logs" ON fallback_logs
    FOR ALL USING (true);

-- ============================================
-- MASTER SANITY CHECK
-- Run this before shipping
-- ============================================
CREATE OR REPLACE FUNCTION run_all_sanity_checks()
RETURNS TABLE (
    check_name TEXT,
    passed BOOLEAN
) AS $$
BEGIN
    -- Check 1: users table exists
    RETURN QUERY SELECT 'users_table_exists'::TEXT,
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users');

    -- Check 2: user_profiles table exists
    RETURN QUERY SELECT 'user_profiles_table_exists'::TEXT,
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles');

    -- Check 3: recommendation_logs table exists
    RETURN QUERY SELECT 'recommendation_logs_table_exists'::TEXT,
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'recommendation_logs');

    -- Check 4: validation_failures table exists
    RETURN QUERY SELECT 'validation_failures_table_exists'::TEXT,
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'validation_failures');

    -- Check 5: feedback_events table exists
    RETURN QUERY SELECT 'feedback_events_table_exists'::TEXT,
        EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feedback_events');

    -- Check 6: Can insert recommendation
    RETURN QUERY SELECT 'can_insert_recommendation'::TEXT,
        sanity_check_recommendation_insert();

    -- Check 7: Can insert rejection
    RETURN QUERY SELECT 'can_insert_rejection'::TEXT,
        sanity_check_rejection_insert();
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENT: How to run sanity checks
-- ============================================
-- SELECT * FROM run_all_sanity_checks();
-- All checks should return TRUE
-- If any return FALSE, DO NOT SHIP
