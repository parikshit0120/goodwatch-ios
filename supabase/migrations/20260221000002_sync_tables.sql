-- ============================================================
-- MIGRATION: Sync table schema fixes for watchlist + tag weights
-- Adds missing columns to user_watchlist for soft-delete sync.
-- Creates user_tag_weights_bulk for efficient JSONB-based sync
-- (the existing user_tag_weights table uses per-tag rows, which
-- is fine for RPC functions but inefficient for full-dictionary sync).
-- ============================================================

-- ============================================================
-- 1. user_watchlist: add added_at and removed_at for soft-delete sync
-- ============================================================
ALTER TABLE user_watchlist ADD COLUMN IF NOT EXISTS added_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE user_watchlist ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ;

-- ============================================================
-- 2. user_tag_weights_bulk: single JSONB row per user for efficient sync
--    The app writes the full tag weight dictionary as one JSONB blob.
--    This avoids N individual upserts for N tags on every interaction.
-- ============================================================
CREATE TABLE IF NOT EXISTS user_tag_weights_bulk (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL UNIQUE,
    weights JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_tag_weights_bulk_user ON user_tag_weights_bulk(user_id);

-- RLS
ALTER TABLE user_tag_weights_bulk ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anon select user_tag_weights_bulk" ON user_tag_weights_bulk
    FOR SELECT TO anon USING (true);
CREATE POLICY "Anon insert user_tag_weights_bulk" ON user_tag_weights_bulk
    FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon update user_tag_weights_bulk" ON user_tag_weights_bulk
    FOR UPDATE TO anon USING (true) WITH CHECK (true);
-- No DELETE for anon.

-- ============================================================
-- DONE
-- user_watchlist: added added_at, removed_at columns
-- user_tag_weights_bulk: new JSONB-based table for efficient sync
-- ============================================================
