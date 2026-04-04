-- Add streak_count and last_log_date to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS streak_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_log_date DATE;

-- Update RLS if needed (usually users can update their own rows)
-- If there's an existing policy for updating users, it should cover these new columns.
