-- Adds period_duration column to cycle_data
-- Default is 5 days (average standard).
ALTER TABLE public.cycle_data
  ADD COLUMN IF NOT EXISTS period_duration INTEGER DEFAULT 5;
