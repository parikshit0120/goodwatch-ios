-- Add interaction_points column to user_profiles
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS interaction_points INTEGER DEFAULT 0;
