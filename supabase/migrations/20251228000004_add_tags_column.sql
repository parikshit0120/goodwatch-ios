-- Add tags column to movies table
ALTER TABLE movies ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

-- Create index for tag searches
CREATE INDEX IF NOT EXISTS idx_movies_tags ON movies USING GIN(tags);

-- Update existing movies with derived tags based on emotional_profile
-- This is a one-time migration to populate tags from existing data

UPDATE movies SET tags = ARRAY[]::TEXT[] WHERE tags IS NULL;

-- Function to derive tags from emotional_profile
CREATE OR REPLACE FUNCTION derive_movie_tags(ep JSONB, rating DOUBLE PRECISION)
RETURNS TEXT[] AS $$
DECLARE
    tags TEXT[] := '{}';
    complexity INT;
    darkness INT;
    comfort INT;
    energy INT;
    mental_stim INT;
    rewatchability INT;
    intensity INT;
BEGIN
    IF ep IS NULL THEN
        RETURN ARRAY['medium', 'safe_bet', 'full_attention'];
    END IF;

    complexity := COALESCE((ep->>'complexity')::INT, 5);
    darkness := COALESCE((ep->>'darkness')::INT, 5);
    comfort := COALESCE((ep->>'comfort')::INT, 5);
    energy := COALESCE((ep->>'energy')::INT, 5);
    mental_stim := COALESCE((ep->>'mentalStimulation')::INT, 5);
    rewatchability := COALESCE((ep->>'rewatchability')::INT, 5);
    intensity := COALESCE((ep->>'emotionalIntensity')::INT, 5);

    -- Cognitive Load
    IF complexity <= 3 THEN
        tags := array_append(tags, 'light');
    ELSIF complexity <= 6 THEN
        tags := array_append(tags, 'medium');
    ELSE
        tags := array_append(tags, 'heavy');
    END IF;

    -- Emotional Outcome
    IF darkness >= 7 THEN
        tags := array_append(tags, 'dark');
    ELSIF comfort >= 7 THEN
        tags := array_append(tags, 'feel_good');
    ELSIF comfort >= 5 AND darkness <= 4 THEN
        tags := array_append(tags, 'uplifting');
    ELSE
        tags := array_append(tags, 'bittersweet');
    END IF;

    -- Energy
    IF energy <= 3 THEN
        tags := array_append(tags, 'calm');
    ELSIF energy >= 7 THEN
        tags := array_append(tags, 'high_energy');
    ELSE
        tags := array_append(tags, 'tense');
    END IF;

    -- Attention
    IF mental_stim <= 3 THEN
        tags := array_append(tags, 'background_friendly');
    ELSIF rewatchability >= 7 THEN
        tags := array_append(tags, 'rewatchable');
    ELSE
        tags := array_append(tags, 'full_attention');
    END IF;

    -- Regret Risk
    IF COALESCE(rating, 7.0) >= 7.5 AND intensity <= 6 THEN
        tags := array_append(tags, 'safe_bet');
    ELSIF intensity >= 8 OR darkness >= 8 THEN
        tags := array_append(tags, 'acquired_taste');
    ELSE
        tags := array_append(tags, 'polarizing');
    END IF;

    RETURN tags;
END;
$$ LANGUAGE plpgsql;

-- Apply tags to all movies
UPDATE movies
SET tags = derive_movie_tags(emotional_profile, COALESCE(imdb_rating, vote_average))
WHERE tags = '{}' OR tags IS NULL;
