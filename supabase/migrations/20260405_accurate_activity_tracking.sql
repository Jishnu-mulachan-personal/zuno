-- Convert last_log_date to last_login_at with timestamp for accurate activity tracking
-- This migration renames the existing date column and converts it to a full timestamp.
ALTER TABLE public.users 
RENAME COLUMN last_log_date TO last_login_at;

ALTER TABLE public.users 
ALTER COLUMN last_login_at TYPE TIMESTAMPTZ USING last_login_at::TIMESTAMPTZ;
