-- ============================================
-- SYNC INFRASTRUCTURE MIGRATION
-- Tables and functions for OTT catalog sync
-- ============================================

-- ============================================
-- TABLE: sync_log
-- Tracks all sync operations for debugging and monitoring
-- ============================================
CREATE TABLE IF NOT EXISTS sync_log (
    id SERIAL PRIMARY KEY,
    sync_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    duration_seconds INT,
    movies_processed INT DEFAULT 0,
    movies_added INT DEFAULT 0,
    movies_updated INT DEFAULT 0,
    movies_skipped INT DEFAULT 0,
    movies_marked_unavailable INT DEFAULT 0,
    provider_counts JSONB DEFAULT '{}',
    errors TEXT[] DEFAULT '{}',
    success BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for querying recent syncs
CREATE INDEX IF NOT EXISTS idx_sync_log_date ON sync_log(sync_date DESC);

-- ============================================
-- ADD COLUMNS: streaming_links and tmdb_id
-- For deep links and duplicate prevention
-- ============================================
DO $$
BEGIN
    -- Add tmdb_id column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'movies' AND column_name = 'tmdb_id'
    ) THEN
        ALTER TABLE movies ADD COLUMN tmdb_id INT;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_movies_tmdb_id ON movies(tmdb_id) WHERE tmdb_id IS NOT NULL;
    END IF;

    -- Add streaming_links column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'movies' AND column_name = 'streaming_links'
    ) THEN
        ALTER TABLE movies ADD COLUMN streaming_links JSONB DEFAULT '{}';
    END IF;

    -- Add backdrop_path column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'movies' AND column_name = 'backdrop_path'
    ) THEN
        ALTER TABLE movies ADD COLUMN backdrop_path TEXT;
    END IF;
END $$;

-- ============================================
-- FUNCTION: Get sync history
-- ============================================
CREATE OR REPLACE FUNCTION get_sync_history(p_limit INT DEFAULT 10)
RETURNS TABLE (
    sync_date TIMESTAMP WITH TIME ZONE,
    duration_seconds INT,
    movies_processed INT,
    movies_added INT,
    movies_updated INT,
    success BOOLEAN,
    error_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.sync_date,
        s.duration_seconds,
        s.movies_processed,
        s.movies_added,
        s.movies_updated,
        s.success,
        COALESCE(array_length(s.errors, 1), 0)::INT as error_count
    FROM sync_log s
    ORDER BY s.sync_date DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get OTT platform statistics
-- ============================================
CREATE OR REPLACE FUNCTION get_ott_platform_stats()
RETURNS TABLE (
    platform_name TEXT,
    movie_count BIGINT,
    avg_rating FLOAT,
    first_time_eligible BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH provider_movies AS (
        SELECT
            provider->>'name' as platform,
            m.id,
            COALESCE(m.imdb_rating, m.vote_average, 0) as rating,
            COALESCE(m.imdb_votes, m.vote_count, 0) as votes
        FROM movies m,
            jsonb_array_elements(m.ott_providers) as provider
        WHERE provider->>'type' = 'flatrate'
            AND m.content_type = 'movie'
    )
    SELECT
        platform::TEXT as platform_name,
        COUNT(DISTINCT id)::BIGINT as movie_count,
        ROUND(AVG(rating)::NUMERIC, 2)::FLOAT as avg_rating,
        COUNT(DISTINCT id) FILTER (WHERE rating >= 7.5 AND votes >= 2000)::BIGINT as first_time_eligible
    FROM provider_movies
    GROUP BY platform
    ORDER BY movie_count DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Validate sync data integrity
-- ============================================
CREATE OR REPLACE FUNCTION validate_sync_integrity()
RETURNS TABLE (
    check_name TEXT,
    check_passed BOOLEAN,
    details TEXT
) AS $$
DECLARE
    total_movies BIGINT;
    with_streaming BIGINT;
    orphan_movies BIGINT;
    first_time_eligible BIGINT;
BEGIN
    -- Get counts
    SELECT COUNT(*) INTO total_movies FROM movies;
    SELECT COUNT(*) INTO with_streaming FROM movies WHERE ott_providers IS NOT NULL AND jsonb_array_length(ott_providers) > 0;
    SELECT COUNT(*) INTO orphan_movies FROM movies WHERE (ott_providers IS NULL OR jsonb_array_length(ott_providers) = 0) AND vote_count >= 1000;
    SELECT COUNT(*) INTO first_time_eligible FROM first_time_quality_movies;

    -- Return checks
    RETURN QUERY VALUES
        ('Total movies', total_movies >= 5000, format('%s movies', total_movies)),
        ('Movies with streaming', with_streaming >= 4000, format('%s movies', with_streaming)),
        ('Orphan movies (popular, no streaming)', orphan_movies <= 100, format('%s movies', orphan_movies)),
        ('First-time eligible', first_time_eligible >= 500, format('%s movies', first_time_eligible));
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get deep link for a movie
-- ============================================
CREATE OR REPLACE FUNCTION get_movie_deep_link(
    p_movie_id UUID,
    p_platform TEXT
)
RETURNS TEXT AS $$
DECLARE
    link TEXT;
    movie_title TEXT;
BEGIN
    -- First try stored deep link
    SELECT streaming_links->>p_platform, title
    INTO link, movie_title
    FROM movies
    WHERE id = p_movie_id;

    IF link IS NOT NULL THEN
        RETURN link;
    END IF;

    -- Fall back to search URL
    IF movie_title IS NOT NULL THEN
        CASE p_platform
            WHEN 'Netflix' THEN
                RETURN 'https://www.netflix.com/search?q=' || url_encode(movie_title);
            WHEN 'Amazon Prime Video' THEN
                RETURN 'https://www.primevideo.com/search?phrase=' || url_encode(movie_title);
            WHEN 'JioHotstar', 'Hotstar', 'Disney+ Hotstar' THEN
                RETURN 'https://www.hotstar.com/in/search?q=' || url_encode(movie_title);
            WHEN 'SonyLIV' THEN
                RETURN 'https://www.sonyliv.com/search?searchTerm=' || url_encode(movie_title);
            WHEN 'Zee5', 'ZEE5' THEN
                RETURN 'https://www.zee5.com/search?q=' || url_encode(movie_title);
            WHEN 'JioCinema' THEN
                RETURN 'https://www.jiocinema.com/search/' || url_encode(movie_title);
            ELSE
                RETURN 'https://www.justwatch.com/in/search?q=' || url_encode(movie_title);
        END CASE;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- URL encode helper function
CREATE OR REPLACE FUNCTION url_encode(text_input TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN replace(replace(replace(text_input, ' ', '%20'), '''', '%27'), '&', '%26');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================
-- RLS Policies for sync_log (read-only for anon)
-- ============================================
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read sync_log" ON sync_log;
CREATE POLICY "Allow read sync_log" ON sync_log
    FOR SELECT USING (true);

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE sync_log IS 'Tracks OTT catalog sync operations';
COMMENT ON FUNCTION get_sync_history IS 'Returns recent sync history';
COMMENT ON FUNCTION get_ott_platform_stats IS 'Returns movie counts per OTT platform';
COMMENT ON FUNCTION validate_sync_integrity IS 'Validates data integrity after sync';
