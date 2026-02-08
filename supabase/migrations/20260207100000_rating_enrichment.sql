-- Migration: Rating Enrichment Columns
-- Adds multi-source rating fields (RT, Metacritic, Letterboxd, composite)
-- and cast/director columns to the movies table.

-- Multi-source rating enrichment columns
ALTER TABLE movies ADD COLUMN IF NOT EXISTS rt_critics_score INTEGER;  -- Rotten Tomatoes critics score (0-100)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS rt_audience_score INTEGER;  -- Rotten Tomatoes audience score (0-100)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS metacritic_score INTEGER;  -- Metacritic score (0-100)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS letterboxd_rating DOUBLE PRECISION;  -- Letterboxd average (0-5 scale)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS composite_score DOUBLE PRECISION;  -- Weighted composite (0-10 scale)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS rating_confidence DOUBLE PRECISION DEFAULT 0;  -- 0-1 confidence factor
ALTER TABLE movies ADD COLUMN IF NOT EXISTS ratings_enriched_at TIMESTAMPTZ;  -- When ratings were last enriched

-- Cast and director columns
ALTER TABLE movies ADD COLUMN IF NOT EXISTS director TEXT;
ALTER TABLE movies ADD COLUMN IF NOT EXISTS cast_list TEXT[];  -- Top 3-5 cast members
ALTER TABLE movies ADD COLUMN IF NOT EXISTS cast_enriched_at TIMESTAMPTZ;

-- Index for composite score (used for ranking)
CREATE INDEX IF NOT EXISTS idx_movies_composite_score ON movies(composite_score DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_movies_rating_confidence ON movies(rating_confidence DESC NULLS LAST);
