-- ============================================================
-- MIGRATION: Feature flags table for remote feature control
-- Allows toggling features without App Store releases.
-- ============================================================

CREATE TABLE IF NOT EXISTS feature_flags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    flag_key TEXT NOT NULL UNIQUE,
    enabled BOOLEAN NOT NULL DEFAULT false,
    payload JSONB DEFAULT '{}',
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: public read, service role write (same pattern as mood_mappings)
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read feature flags" ON feature_flags FOR SELECT USING (true);
CREATE POLICY "Service role can manage feature flags" ON feature_flags FOR ALL USING (auth.role() = 'service_role');

-- Seed initial flags
INSERT INTO feature_flags (flag_key, enabled, payload, description) VALUES
    ('progressive_picks', true, '{"enabled_tiers": [5,4,3,2,1]}', 'Progressive pick reduction system (5 to 1)'),
    ('feedback_v2', true, '{}', 'GWWatchFeedbackView 2-stage feedback flow'),
    ('push_notifications', true, '{"friday_hour": 19, "saturday_hour": 19, "inactive_days": 3}', 'Weekend + re-engagement push notifications'),
    ('remote_mood_mapping', true, '{}', 'Supabase-driven mood dimensional targets'),
    ('taste_engine', true, '{"max_weight": 0.15}', 'Taste graph scoring integration'),
    ('card_rejection', true, '{"max_rejections_per_position": 1}', 'X button on pick cards with replacement'),
    ('implicit_skip_tracking', true, '{"delta": -0.05}', 'Track implicit rejections in multi-pick')
ON CONFLICT (flag_key) DO NOTHING;
