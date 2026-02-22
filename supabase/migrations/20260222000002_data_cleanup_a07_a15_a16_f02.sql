-- Migration: Data cleanup for audit failures A07, A15, A16, F02
-- Date: 2026-02-22

-- =========================================================
-- A07: Clear stuck emotional profiles (all 8 dimensions identical)
-- These are enrichment artifacts where every dimension = 5
-- Setting to NULL so they can be re-enriched
-- =========================================================
UPDATE movies
SET emotional_profile = NULL
WHERE emotional_profile IS NOT NULL
  AND emotional_profile->>'comfort' = emotional_profile->>'darkness'
  AND emotional_profile->>'darkness' = emotional_profile->>'emotionalIntensity'
  AND emotional_profile->>'emotionalIntensity' = emotional_profile->>'energy'
  AND emotional_profile->>'energy' = emotional_profile->>'complexity'
  AND emotional_profile->>'complexity' = emotional_profile->>'rewatchability'
  AND emotional_profile->>'rewatchability' = emotional_profile->>'humour'
  AND emotional_profile->>'humour' = emotional_profile->>'mentalStimulation';

-- =========================================================
-- A15: Delete shorts (runtime < 40 minutes)
-- These are TV episodes, shorts, and other non-feature content
-- that should not be in the recommendation pool
-- =========================================================
DELETE FROM movies
WHERE runtime > 0 AND runtime < 40;

-- =========================================================
-- A16: Delete stand-up specials
-- Stand-up specials are not movies and should be excluded
-- =========================================================
DELETE FROM movies
WHERE title ILIKE '%stand-up%'
   OR title ILIKE '%stand up%';

-- =========================================================
-- F02: Fix RLS on interactions table
-- Currently wide open for anon SELECT/INSERT
-- Tighten to require auth for SELECT, keep INSERT for anon
-- (app may insert interactions before full auth)
-- =========================================================

-- Drop the overly permissive anon SELECT policy
DROP POLICY IF EXISTS "Anon select interactions" ON interactions;

-- Create a proper RLS policy for authenticated users only
CREATE POLICY "Authenticated select own interactions"
  ON interactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Keep the service role access (implicit with RLS)
-- The anon INSERT policy stays for initial interaction tracking
