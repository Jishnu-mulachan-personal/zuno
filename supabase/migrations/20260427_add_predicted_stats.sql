-- Add predicted physical and mood columns to daily_cycle_insights
ALTER TABLE public.daily_cycle_insights 
ADD COLUMN IF NOT EXISTS predicted_physical TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS predicted_mood TEXT[] DEFAULT '{}';

COMMENT ON COLUMN public.daily_cycle_insights.predicted_physical IS 'AI predicted physical symptoms for the day';
COMMENT ON COLUMN public.daily_cycle_insights.predicted_mood IS 'AI predicted mood for the day';
