-- ============================================
-- DEVICE TOKENS TABLE
-- Stores FCM tokens for push notifications
-- ============================================

-- Create table
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, platform)
);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Allow anyone to insert tokens (app uses anon key before auth is fully set up)
CREATE POLICY "Anyone can insert device tokens"
    ON device_tokens
    FOR INSERT
    WITH CHECK (true);

-- Allow anyone to update tokens (for FCM token refresh)
CREATE POLICY "Anyone can update device tokens"
    ON device_tokens
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- Allow reading own tokens (for future use)
CREATE POLICY "Anyone can read device tokens"
    ON device_tokens
    FOR SELECT
    USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_platform ON device_tokens(platform);

-- Comment
COMMENT ON TABLE device_tokens IS 'FCM tokens for push notifications. Upserted on (user_id, platform).';
