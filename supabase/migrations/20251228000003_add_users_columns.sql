-- Add missing columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS device_id TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Index for device_id lookups (anonymous users)
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);

-- RLS Policies for users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Allow anonymous user creation" ON users;

CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (true);

CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (true);

CREATE POLICY "Allow anonymous user creation" ON users
    FOR INSERT WITH CHECK (true);
