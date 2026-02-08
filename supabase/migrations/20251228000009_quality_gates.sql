-- ============================================
-- TIERED QUALITY GATES MIGRATION
-- Trust-based quality filtering for recommendations
-- ============================================

-- TIERED QUALITY GATES:
-- - First-time (0 accepts): 7.5+ rating, 2000+ votes ("Highly acclaimed")
-- - Early trust (1-3 accepts): 7.0+ rating, 1500+ votes ("Crowd favorite")
-- - Building (4-10 accepts): 6.5+ rating, 1000+ votes ("Strong pick")
-- - Trusted (11+ accepts): 6.0+ rating, 500+ votes ("Good match")

-- ============================================
-- FUNCTION: Get tiered quality thresholds
-- ============================================
CREATE OR REPLACE FUNCTION get_quality_tier(p_accept_count INT)
RETURNS TABLE (
    min_rating FLOAT,
    min_votes INT,
    tier_label TEXT
) AS $$
BEGIN
    IF p_accept_count = 0 THEN
        RETURN QUERY SELECT 7.5::FLOAT, 2000, 'Highly acclaimed'::TEXT;
    ELSIF p_accept_count <= 3 THEN
        RETURN QUERY SELECT 7.0::FLOAT, 1500, 'Crowd favorite'::TEXT;
    ELSIF p_accept_count <= 10 THEN
        RETURN QUERY SELECT 6.5::FLOAT, 1000, 'Strong pick'::TEXT;
    ELSE
        RETURN QUERY SELECT 6.0::FLOAT, 500, 'Good match'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- FUNCTION: Check if a movie passes tiered quality gates
-- ============================================
CREATE OR REPLACE FUNCTION passes_quality_gates(
    p_vote_average FLOAT,
    p_vote_count INT,
    p_runtime INT,
    p_content_type TEXT,
    p_accept_count INT DEFAULT 0
)
RETURNS BOOLEAN AS $$
DECLARE
    tier RECORD;
BEGIN
    SELECT * INTO tier FROM get_quality_tier(p_accept_count);
    RETURN (
        COALESCE(p_vote_average, 0) >= tier.min_rating
        AND COALESCE(p_vote_count, 0) >= tier.min_votes
        AND COALESCE(p_runtime, 0) >= 60
        AND COALESCE(p_runtime, 0) <= 240
        AND COALESCE(p_content_type, '') = 'movie'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- VIEW: First-time user quality movies (strictest)
-- Only exceptional content: 7.5+ rating, 2000+ votes
-- ============================================
CREATE OR REPLACE VIEW first_time_quality_movies AS
SELECT *
FROM movies
WHERE
    ott_providers IS NOT NULL
    AND jsonb_array_length(ott_providers) > 0
    AND COALESCE(imdb_rating, vote_average, 0) >= 7.5
    AND COALESCE(imdb_votes, vote_count, 0) >= 2000
    AND COALESCE(runtime, 0) >= 60
    AND COALESCE(runtime, 0) <= 240
    AND content_type = 'movie';

-- ============================================
-- VIEW: Trusted user quality movies (most lenient)
-- Good content: 6.0+ rating, 500+ votes
-- ============================================
CREATE OR REPLACE VIEW quality_movies AS
SELECT *
FROM movies
WHERE
    ott_providers IS NOT NULL
    AND jsonb_array_length(ott_providers) > 0
    AND COALESCE(imdb_rating, vote_average, 0) >= 6.0
    AND COALESCE(imdb_votes, vote_count, 0) >= 500
    AND COALESCE(runtime, 0) >= 60
    AND COALESCE(runtime, 0) <= 240
    AND content_type = 'movie';

-- ============================================
-- FUNCTION: Get tiered quality movies count
-- Shows how many movies are available at each tier
-- ============================================
CREATE OR REPLACE FUNCTION get_tiered_quality_stats()
RETURNS TABLE (
    tier_name TEXT,
    min_rating FLOAT,
    min_votes INT,
    movie_count BIGINT,
    with_streaming BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        'First-time (0 accepts)'::TEXT,
        7.5::FLOAT,
        2000,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 7.5 AND COALESCE(imdb_votes, vote_count, 0) >= 2000 AND content_type = 'movie')::BIGINT,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 7.5 AND COALESCE(imdb_votes, vote_count, 0) >= 2000 AND content_type = 'movie' AND ott_providers IS NOT NULL AND jsonb_array_length(ott_providers) > 0)::BIGINT
    UNION ALL
    SELECT
        'Early trust (1-3 accepts)'::TEXT,
        7.0::FLOAT,
        1500,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 7.0 AND COALESCE(imdb_votes, vote_count, 0) >= 1500 AND content_type = 'movie')::BIGINT,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 7.0 AND COALESCE(imdb_votes, vote_count, 0) >= 1500 AND content_type = 'movie' AND ott_providers IS NOT NULL AND jsonb_array_length(ott_providers) > 0)::BIGINT
    UNION ALL
    SELECT
        'Building (4-10 accepts)'::TEXT,
        6.5::FLOAT,
        1000,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 6.5 AND COALESCE(imdb_votes, vote_count, 0) >= 1000 AND content_type = 'movie')::BIGINT,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 6.5 AND COALESCE(imdb_votes, vote_count, 0) >= 1000 AND content_type = 'movie' AND ott_providers IS NOT NULL AND jsonb_array_length(ott_providers) > 0)::BIGINT
    UNION ALL
    SELECT
        'Trusted (11+ accepts)'::TEXT,
        6.0::FLOAT,
        500,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 6.0 AND COALESCE(imdb_votes, vote_count, 0) >= 500 AND content_type = 'movie')::BIGINT,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) >= 6.0 AND COALESCE(imdb_votes, vote_count, 0) >= 500 AND content_type = 'movie' AND ott_providers IS NOT NULL AND jsonb_array_length(ott_providers) > 0)::BIGINT;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get quality movies count by filter (legacy)
-- ============================================
CREATE OR REPLACE FUNCTION get_quality_movie_stats()
RETURNS TABLE (
    total_movies BIGINT,
    quality_movies BIGINT,
    first_time_eligible BIGINT,
    below_rating_threshold BIGINT,
    below_vote_threshold BIGINT,
    wrong_runtime BIGINT,
    wrong_content_type BIGINT,
    no_streaming BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM movies)::BIGINT as total_movies,
        (SELECT COUNT(*) FROM quality_movies)::BIGINT as quality_movies,
        (SELECT COUNT(*) FROM first_time_quality_movies)::BIGINT as first_time_eligible,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_rating, vote_average, 0) < 6.0)::BIGINT as below_rating_threshold,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(imdb_votes, vote_count, 0) < 500)::BIGINT as below_vote_threshold,
        (SELECT COUNT(*) FROM movies WHERE COALESCE(runtime, 0) < 60 OR COALESCE(runtime, 0) > 240)::BIGINT as wrong_runtime,
        (SELECT COUNT(*) FROM movies WHERE content_type != 'movie' OR content_type IS NULL)::BIGINT as wrong_content_type,
        (SELECT COUNT(*) FROM movies WHERE ott_providers IS NULL OR jsonb_array_length(ott_providers) = 0)::BIGINT as no_streaming;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VERIFICATION QUERY: Run this after migration
-- Should return only high-quality movies
-- ============================================
-- SELECT title, vote_average, vote_count, release_year, runtime
-- FROM movies
-- WHERE COALESCE(imdb_rating, vote_average, 0) >= 6.5
-- AND COALESCE(imdb_votes, vote_count, 0) >= 500
-- AND runtime >= 60
-- AND runtime <= 240
-- AND content_type = 'movie'
-- ORDER BY COALESCE(imdb_rating, vote_average, 0) DESC
-- LIMIT 20;

-- ============================================
-- INDEX: Optimize quality gate queries
-- ============================================
CREATE INDEX IF NOT EXISTS idx_movies_quality_gate
ON movies (
    content_type,
    imdb_rating,
    imdb_votes,
    runtime
)
WHERE content_type = 'movie'
    AND imdb_rating IS NOT NULL
    AND imdb_votes IS NOT NULL;
