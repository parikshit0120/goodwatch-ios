-- Fix movie_intelligence table: add columns that collect_movie_intelligence.py writes
-- but were missing from the original taste_graph_v1 migration

DO $$
BEGIN
    -- Movie metadata columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'imdb_id') THEN
        ALTER TABLE movie_intelligence ADD COLUMN imdb_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'title') THEN
        ALTER TABLE movie_intelligence ADD COLUMN title TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'year') THEN
        ALTER TABLE movie_intelligence ADD COLUMN year INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'original_language') THEN
        ALTER TABLE movie_intelligence ADD COLUMN original_language TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'overview') THEN
        ALTER TABLE movie_intelligence ADD COLUMN overview TEXT;
    END IF;

    -- TMDB keywords
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'tmdb_keywords') THEN
        ALTER TABLE movie_intelligence ADD COLUMN tmdb_keywords JSONB DEFAULT '[]';
    END IF;

    -- Reddit thread count (separate from reddit_discussions)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'reddit_thread_count') THEN
        ALTER TABLE movie_intelligence ADD COLUMN reddit_thread_count INTEGER DEFAULT 0;
    END IF;

    -- OMDB extra columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'omdb_imdb_rating') THEN
        ALTER TABLE movie_intelligence ADD COLUMN omdb_imdb_rating TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'omdb_box_office') THEN
        ALTER TABLE movie_intelligence ADD COLUMN omdb_box_office TEXT;
    END IF;

    -- Collection metadata
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'sources_collected') THEN
        ALTER TABLE movie_intelligence ADD COLUMN sources_collected JSONB DEFAULT '[]';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'movie_intelligence' AND column_name = 'collection_errors') THEN
        ALTER TABLE movie_intelligence ADD COLUMN collection_errors JSONB;
    END IF;

    -- reddit_discussions was JSONB but script writes TEXT
    -- Change reddit_discussions to TEXT if it's currently JSONB
    -- (safe: column is empty, table was just created)
    ALTER TABLE movie_intelligence ALTER COLUMN reddit_discussions TYPE TEXT USING reddit_discussions::TEXT;

    -- reddit_post_count rename: script uses reddit_thread_count instead
    -- Keep reddit_post_count for backward compat, reddit_thread_count added above
END $$;
