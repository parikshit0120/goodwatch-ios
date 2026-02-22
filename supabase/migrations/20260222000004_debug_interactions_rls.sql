-- Debug: Drop ALL policies on interactions and recreate from scratch

-- First, check if RLS is even on — force it
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE interactions FORCE ROW LEVEL SECURITY;

-- Drop every single policy on interactions table
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname FROM pg_policies WHERE tablename = 'interactions' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON interactions', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- Now create only what we need:
-- 1. Authenticated users can read their own interactions
CREATE POLICY "auth_read_own" ON interactions
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 2. Anon can insert (for pre-auth interaction tracking)
CREATE POLICY "anon_insert" ON interactions
  FOR INSERT TO anon
  WITH CHECK (true);

-- 3. Authenticated can insert their own
CREATE POLICY "auth_insert_own" ON interactions
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
