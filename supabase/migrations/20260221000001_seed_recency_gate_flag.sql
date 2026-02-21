-- Seed the new_user_recency_gate feature flag.
-- Excludes pre-2010 movies for users with < 10 interaction points.
-- Relaxed automatically at fallback Level 2 if not enough movies pass.
INSERT INTO feature_flags (flag_key, enabled, payload, description) VALUES
    ('new_user_recency_gate', true, '{"cutoff_year": 2010, "points_threshold": 10}', 'Exclude pre-2010 movies for new users (interaction_points < 10). Relaxed at fallback Level 2.')
ON CONFLICT (flag_key) DO NOTHING;
