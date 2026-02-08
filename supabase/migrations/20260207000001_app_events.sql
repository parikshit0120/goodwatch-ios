-- App Events Table
-- Stores all client-side analytics events from MetricsService.swift
-- Events are batch-uploaded from the iOS app (buffered in-memory, flushed on background)
-- Used by the marketing data pipeline (sync_metrics.py) to compute KPIs

CREATE TABLE IF NOT EXISTS app_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID,
    device_id TEXT,
    event_name TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    session_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Performance indexes for pipeline queries
CREATE INDEX idx_app_events_user ON app_events(user_id);
CREATE INDEX idx_app_events_device ON app_events(device_id);
CREATE INDEX idx_app_events_event ON app_events(event_name);
CREATE INDEX idx_app_events_created ON app_events(created_at DESC);
CREATE INDEX idx_app_events_session ON app_events(session_id);

-- Composite index for common queries: "events by user in time range"
CREATE INDEX idx_app_events_user_time ON app_events(user_id, created_at DESC);

-- Enable RLS
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

-- Allow any authenticated or anonymous user to insert events (write-only from client)
CREATE POLICY "Anyone can insert events"
    ON app_events FOR INSERT
    WITH CHECK (true);

-- Users can only read their own events
CREATE POLICY "Users read own events"
    ON app_events FOR SELECT
    USING (
        auth.uid() = user_id
        OR device_id = current_setting('request.jwt.claims', true)::json->>'sub'
    );

-- Service role (used by pipeline script) can read all events
-- (Service role bypasses RLS by default, so no policy needed)

COMMENT ON TABLE app_events IS 'Client-side analytics events from GoodWatch iOS app. Populated by MetricsService.swift dual logging (Firebase + Supabase).';
COMMENT ON COLUMN app_events.event_name IS 'Event type: app_open, pick_shown, watch_now, session_reset, retry_soft, reject_hard, availability_filtered_out, onboarding_start, onboarding_complete, sign_in, first_recommendation, feedback_given';
COMMENT ON COLUMN app_events.properties IS 'Event-specific metadata as JSON. e.g. {"auth_type": "google"}, {"sentiment": "loved"}, {"movie_id": "abc123"}';
COMMENT ON COLUMN app_events.session_id IS 'UUID generated per app session. Groups events from a single app launch.';
