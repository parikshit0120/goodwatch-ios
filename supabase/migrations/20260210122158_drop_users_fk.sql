-- Drop the foreign key constraint on users.id that references auth.users
-- This constraint prevents the iOS app from creating users directly via REST API
-- The app manages its own user table independently of Supabase Auth
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_id_fkey;

-- Also try the common auto-generated name pattern
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_pkey_fkey;
ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_auth;
