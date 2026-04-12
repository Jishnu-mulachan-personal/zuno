-- Add graphical data columns to weekly_insights
ALTER TABLE public.weekly_insights
ADD COLUMN IF NOT EXISTS pattern_data JSONB,
ADD COLUMN IF NOT EXISTS alignment_data JSONB;
