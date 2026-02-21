-- ============================================
-- ADD APNs TOKEN COLUMN TO DEVICE_TOKENS
-- Stores raw APNs device token for direct APNs sending
-- ============================================

-- Add apns_token column (nullable — FCM token is still primary)
ALTER TABLE device_tokens ADD COLUMN IF NOT EXISTS apns_token TEXT;

-- Comment
COMMENT ON COLUMN device_tokens.apns_token IS 'Raw APNs device token (hex). Used for direct APNs push sending.';
