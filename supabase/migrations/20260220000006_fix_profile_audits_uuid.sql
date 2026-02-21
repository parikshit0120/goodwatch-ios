-- Fix profile_audits.supabase_id: should be TEXT (UUID format), not INTEGER
ALTER TABLE profile_audits ALTER COLUMN supabase_id TYPE TEXT;
