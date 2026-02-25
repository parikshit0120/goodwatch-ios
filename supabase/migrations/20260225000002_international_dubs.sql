-- Migration: Add international dubbed titles
-- Run after: 20260225000001_dubbed_content.sql
-- Date: 2026-02-25
-- Related: INV-L09 (Dubbed Content Separation) - FIX 2

-- International content dubbed in Indian languages
-- These will appear in the "International Picks" section for users
-- whose selected languages don't include the original language

UPDATE movies SET
   dubbed_languages = ARRAY['hi', 'en', 'ta', 'te'],
   dub_confidence = 'confirmed'
WHERE tmdb_id IN (
  -- Korean originals (will appear as international for non-Korean users)
  496243,   -- Parasite
  396535,   -- Train to Busan

  -- English originals dubbed in Hindi/Tamil/Telugu (available on Indian OTT)
  -- These appear as "international" only for users who DON'T have English selected
  577922,   -- Tenet
  634649,   -- Spider-Man: No Way Home
  299536,   -- Avengers: Infinity War
  299534,   -- Avengers: Endgame
  24428,    -- The Avengers
  157336,   -- Interstellar
  27205,    -- Inception
  120,      -- LOTR: Fellowship
  121,      -- LOTR: Two Towers
  122,      -- LOTR: Return of the King
  603,      -- The Matrix
  155,      -- The Dark Knight
  550,      -- Fight Club
  680,      -- Pulp Fiction
  13,       -- Forrest Gump
  278,      -- The Shawshank Redemption
  238,      -- The Godfather
  424       -- Schindler's List
) AND tmdb_id IS NOT NULL;

-- Verify count
SELECT COUNT(*) AS international_dubbed_count
FROM movies
WHERE dubbed_languages != '{}'
  AND dub_confidence = 'confirmed';
