-- Migration: Aggressive RLS fix for interactions table
-- Date: 2026-02-22
-- Issue: F02 - anon users can still read interactions

-- Ensure RLS is enabled and forced
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions FORCE ROW LEVEL SECURITY;

-- Drop ALL existing SELECT policies (try multiple name patterns)
DROP POLICY IF EXISTS "Anon select interactions" ON interactions;
DROP POLICY IF EXISTS "anon_select_interactions" ON interactions;
DROP POLICY IF EXISTS "Enable read access for all users" ON interactions;
DROP POLICY IF EXISTS "Allow anonymous access" ON interactions;
DROP POLICY IF EXISTS "public_read" ON interactions;

-- Recreate with proper auth-only SELECT
CREATE POLICY "auth_select_own_interactions"
  ON interactions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Ensure service role can still access all rows (implicit)
-- Keep INSERT policy for anon (app may write before auth)
-- Drop and recreate INSERT policy to be explicit
DROP POLICY IF EXISTS "Anon insert interactions" ON interactions;
DROP POLICY IF EXISTS "anon_insert_interactions" ON interactions;

CREATE POLICY "anon_insert_interactions"
  ON interactions
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "auth_insert_interactions"
  ON interactions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
