-- Add energy level prediction columns to daily_cycle_insights
ALTER TABLE public.daily_cycle_insights 
ADD COLUMN IF NOT EXISTS energy_category TEXT,
ADD COLUMN IF NOT EXISTS energy_message TEXT,
ADD COLUMN IF NOT EXISTS energy_image_name TEXT;

-- Update RLS if necessary (existing policy should cover these columns)
COMMENT ON COLUMN public.daily_cycle_insights.energy_category IS 'The predicted energy category (e.g., Radiant, Calm, Balanced)';
COMMENT ON COLUMN public.daily_cycle_insights.energy_message IS 'A short AI-generated sentence describing the energy level';
COMMENT ON COLUMN public.daily_cycle_insights.energy_image_name IS 'The filename of the image to display for this energy state';
