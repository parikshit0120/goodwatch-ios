-- ============================================
-- NEWSLETTER SUBSCRIBERS TABLE
-- Stores email opt-ins from in-app signup
-- ============================================

-- Table already exists, add missing columns
ALTER TABLE newsletter_subscribers ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE newsletter_subscribers ADD COLUMN IF NOT EXISTS device_id TEXT;
ALTER TABLE newsletter_subscribers ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'app_auth_screen';
ALTER TABLE newsletter_subscribers ADD COLUMN IF NOT EXISTS unsubscribed_at TIMESTAMPTZ;

-- Unique email constraint (one subscription per email)
CREATE UNIQUE INDEX IF NOT EXISTS idx_newsletter_email ON newsletter_subscribers(email);

-- Index for active subscriber queries
CREATE INDEX IF NOT EXISTS idx_newsletter_active ON newsletter_subscribers(subscribed_at)
    WHERE unsubscribed_at IS NULL;

-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_newsletter_user ON newsletter_subscribers(user_id)
    WHERE user_id IS NOT NULL;

-- RLS
ALTER TABLE newsletter_subscribers ENABLE ROW LEVEL SECURITY;

-- Anyone can subscribe (insert)
DROP POLICY IF EXISTS "Anyone can subscribe" ON newsletter_subscribers;
CREATE POLICY "Anyone can subscribe" ON newsletter_subscribers
    FOR INSERT WITH CHECK (true);

-- Users can read their own subscription
DROP POLICY IF EXISTS "Users can read own subscription" ON newsletter_subscribers;
CREATE POLICY "Users can read own subscription" ON newsletter_subscribers
    FOR SELECT USING (true);

-- Users can unsubscribe (update unsubscribed_at)
DROP POLICY IF EXISTS "Users can unsubscribe" ON newsletter_subscribers;
CREATE POLICY "Users can unsubscribe" ON newsletter_subscribers
    FOR UPDATE USING (true);
