-- Create table for daily cycle-specific insights
CREATE TABLE IF NOT EXISTS public.daily_cycle_insights (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    insight_text TEXT NOT NULL,
    last_generated_at DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Enable RLS
ALTER TABLE public.daily_cycle_insights ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own insights
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'daily_cycle_insights' 
        AND policyname = 'Users can view their own cycle insights'
    ) THEN
        CREATE POLICY "Users can view their own cycle insights"
            ON public.daily_cycle_insights
            FOR SELECT
            USING (auth.uid() = user_id);
    END IF;
END
$$;
