-- Migration: Add dubbed content columns to movies table
-- Run in Supabase SQL Editor: https://supabase.com/dashboard/project/jdjqrlkynwfhbtyuddjk/sql
-- Date: 2026-02-25
-- Related: INV-L09 (Dubbed Content Separation)

-- Step 1: Add dubbed_languages column (text array, empty by default)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS dubbed_languages text[] DEFAULT '{}';

-- Step 2: Add dub_confidence column (text, 'unknown' by default)
ALTER TABLE movies ADD COLUMN IF NOT EXISTS dub_confidence text DEFAULT 'unknown';

-- Step 3: GIN index for fast array containment queries on dubbed_languages
CREATE INDEX IF NOT EXISTS idx_movies_dubbed_languages ON movies USING GIN (dubbed_languages);

-- Step 4: Seed known dubbed movies
-- These are well-known Indian movies with confirmed dubbed versions

-- RRR (2022) - Telugu original, dubbed in Hindi, English, Tamil, Malayalam, Kannada
UPDATE movies SET dubbed_languages = '{hi,en,ta,ml,kn}', dub_confidence = 'confirmed'
WHERE title ILIKE '%RRR%' AND year = 2022 AND original_language = 'te';

-- Baahubali: The Beginning (2015) - Telugu original
UPDATE movies SET dubbed_languages = '{hi,en,ta,ml,kn}', dub_confidence = 'confirmed'
WHERE title ILIKE '%Baahubali%Beginning%' AND year = 2015 AND original_language = 'te';

-- Baahubali 2: The Conclusion (2017) - Telugu original
UPDATE movies SET dubbed_languages = '{hi,en,ta,ml,kn}', dub_confidence = 'confirmed'
WHERE title ILIKE '%Baahubali%Conclusion%' AND year = 2017 AND original_language = 'te';

-- KGF Chapter 1 (2018) - Kannada original
UPDATE movies SET dubbed_languages = '{hi,en,te,ta,ml}', dub_confidence = 'confirmed'
WHERE title ILIKE '%KGF%' AND year = 2018 AND original_language = 'kn';

-- KGF Chapter 2 (2022) - Kannada original
UPDATE movies SET dubbed_languages = '{hi,en,te,ta,ml}', dub_confidence = 'confirmed'
WHERE title ILIKE '%KGF%Chapter 2%' AND year = 2022 AND original_language = 'kn';

-- Pushpa: The Rise (2021) - Telugu original
UPDATE movies SET dubbed_languages = '{hi,en,ta,ml,kn}', dub_confidence = 'confirmed'
WHERE title ILIKE '%Pushpa%Rise%' AND year = 2021 AND original_language = 'te';

-- Dangal (2016) - Hindi original, dubbed in English, Tamil, Telugu
UPDATE movies SET dubbed_languages = '{en,ta,te}', dub_confidence = 'confirmed'
WHERE title ILIKE '%Dangal%' AND year = 2016 AND original_language = 'hi';

-- 3 Idiots (2009) - Hindi original, dubbed in English, Tamil, Telugu
UPDATE movies SET dubbed_languages = '{en,ta,te}', dub_confidence = 'confirmed'
WHERE title ILIKE '%3 Idiots%' AND year = 2009 AND original_language = 'hi';

-- Kantara (2022) - Kannada original
UPDATE movies SET dubbed_languages = '{hi,en,te,ta,ml}', dub_confidence = 'confirmed'
WHERE title ILIKE '%Kantara%' AND year = 2022 AND original_language = 'kn';

-- Vikram (2022) - Tamil original
UPDATE movies SET dubbed_languages = '{hi,en,te,ml,kn}', dub_confidence = 'confirmed'
WHERE title ILIKE '%Vikram%' AND year = 2022 AND original_language = 'ta';

-- Verify: count movies with dubbed_languages set
SELECT COUNT(*) AS dubbed_count FROM movies WHERE dubbed_languages != '{}';
