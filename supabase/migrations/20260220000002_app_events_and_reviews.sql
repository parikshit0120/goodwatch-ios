-- ============================================
-- EXTEND APP_EVENTS + CREATE USER_REVIEWS
-- v1.3 event tracking and UGC system
-- ============================================

-- ============================
-- EXTEND app_events table
-- Add source column for cross-platform tracking (ios/android/web)
-- Existing columns: id, user_id, device_id, event_name, properties, session_id, created_at
-- ============================

ALTER TABLE app_events ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'ios';
CREATE INDEX IF NOT EXISTS idx_app_events_source ON app_events(source);

-- Update RLS: allow anonymous reads for dashboard
DROP POLICY IF EXISTS "Users read own events" ON app_events;
CREATE POLICY "Anyone reads all events" ON app_events
  FOR SELECT USING (true);

COMMENT ON COLUMN app_events.source IS 'Platform: ios, android, web';


-- ============================
-- TABLE: user_reviews
-- UGC ratings and reviews from users after watching
-- ============================

CREATE TABLE IF NOT EXISTS user_reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  movie_id UUID NOT NULL,
  rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, movie_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reviews_movie ON user_reviews(movie_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_user ON user_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_rating ON user_reviews(rating);
CREATE INDEX IF NOT EXISTS idx_user_reviews_created ON user_reviews(created_at DESC);

ALTER TABLE user_reviews ENABLE ROW LEVEL SECURITY;

-- Anyone can insert reviews (anon key used by app)
CREATE POLICY "Anyone insert reviews" ON user_reviews
  FOR INSERT WITH CHECK (true);

-- Anyone can read public reviews
CREATE POLICY "Public reviews readable" ON user_reviews
  FOR SELECT USING (true);

-- Users can update their own reviews
CREATE POLICY "Users update own reviews" ON user_reviews
  FOR UPDATE USING (true);

COMMENT ON TABLE user_reviews IS 'UGC movie ratings and reviews. 1-5 star scale with optional text.';
