-- ============================================
-- APP VERSION HISTORY TABLE
-- ============================================
-- Tracks app versions released to the App Store.
-- Used by the update-notification GitHub Action to detect
-- new major versions and broadcast push notifications.
--
-- Seeds with current version 1.3 (notification_sent = true
-- so it doesn't trigger a push on first deploy).
-- ============================================

CREATE TABLE IF NOT EXISTS app_version_history (
    id SERIAL PRIMARY KEY,
    version TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL DEFAULT 'ios',
    released_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notification_sent BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for quick lookup of latest version per platform
CREATE INDEX IF NOT EXISTS idx_app_version_history_platform
    ON app_version_history (platform, released_at DESC);

-- Seed current version (notification already "sent" so it doesn't trigger)
INSERT INTO app_version_history (version, platform, notification_sent, notes)
VALUES ('1.3', 'ios', TRUE, 'Initial seed - v1.3 progressive picks release')
ON CONFLICT (version) DO NOTHING;

-- RLS: read-only for anon users, service role can write
ALTER TABLE app_version_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_read_app_version_history"
    ON app_version_history
    FOR SELECT
    TO anon
    USING (true);
