-- ============================================
-- Update derive_movie_tags function v2
-- ============================================
-- Improved tag derivation with genre-based sanity clamps:
-- - Comedy: caps darkness at 6, floors comfort at 5
-- - Animation/Family: caps darkness at 4, floors comfort at 6
-- - Horror: floors darkness at 6, caps comfort at 5
--
-- Also updates scoring metadata columns.
-- ============================================

-- Drop old function
DROP FUNCTION IF EXISTS derive_movie_tags(JSONB, DOUBLE PRECISION);

-- New v2 function with genres parameter for sanity clamps
CREATE OR REPLACE FUNCTION derive_movie_tags_v2(
    ep JSONB,
    rating DOUBLE PRECISION,
    genre_names TEXT[] DEFAULT '{}'
)
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
    humour INT;
    is_comedy BOOLEAN;
    is_family BOOLEAN;
    is_horror BOOLEAN;
BEGIN
    IF ep IS NULL THEN
        -- No emotional profile = unknown safety
        RETURN ARRAY['medium', 'polarizing', 'full_attention'];
    END IF;

    complexity := COALESCE((ep->>'complexity')::INT, 5);
    darkness := COALESCE((ep->>'darkness')::INT, 5);
    comfort := COALESCE((ep->>'comfort')::INT, 5);
    energy := COALESCE((ep->>'energy')::INT, 5);
    mental_stim := COALESCE((ep->>'mentalStimulation')::INT, 5);
    rewatchability := COALESCE((ep->>'rewatchability')::INT, 5);
    intensity := COALESCE((ep->>'emotionalIntensity')::INT, 5);
    humour := COALESCE((ep->>'humour')::INT, 5);

    -- Genre-based sanity clamps
    is_comedy := 'Comedy' = ANY(genre_names) OR 'comedy' = ANY(genre_names);
    is_family := 'Animation' = ANY(genre_names) OR 'Family' = ANY(genre_names)
                 OR 'animation' = ANY(genre_names) OR 'family' = ANY(genre_names);
    is_horror := 'Horror' = ANY(genre_names) OR 'horror' = ANY(genre_names);

    IF is_comedy THEN
        IF darkness > 6 AND humour >= 5 THEN
            darkness := LEAST(darkness, 6);
        END IF;
        comfort := GREATEST(comfort, 5);
    END IF;

    IF is_family THEN
        darkness := LEAST(darkness, 4);
        comfort := GREATEST(comfort, 6);
    END IF;

    IF is_horror THEN
        darkness := GREATEST(darkness, 6);
        comfort := LEAST(comfort, 5);
    END IF;

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

-- Add scoring_source and scoring_version columns if not present
ALTER TABLE movies ADD COLUMN IF NOT EXISTS scoring_source TEXT DEFAULT 'deterministic';
ALTER TABLE movies ADD COLUMN IF NOT EXISTS scoring_version TEXT DEFAULT 'rule_v1';
ALTER TABLE movies ADD COLUMN IF NOT EXISTS scored_at TIMESTAMPTZ DEFAULT now();
