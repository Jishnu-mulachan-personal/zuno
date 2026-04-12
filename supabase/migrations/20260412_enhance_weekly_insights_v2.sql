-- Add specific columns for the new premium Insights UI
ALTER TABLE public.weekly_insights
ADD COLUMN IF NOT EXISTS mood_harmony_insight TEXT,
ADD COLUMN IF NOT EXISTS vibe_title TEXT,
ADD COLUMN IF NOT EXISTS vibe_text TEXT,
ADD COLUMN IF NOT EXISTS recommendation TEXT,
ADD COLUMN IF NOT EXISTS highlights JSONB;
