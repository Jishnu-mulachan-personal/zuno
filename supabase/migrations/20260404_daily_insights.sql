-- Create table for daily relationship AI insights
CREATE TABLE IF NOT EXISTS public.daily_insights (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    insight_text TEXT NOT NULL,
    last_generated_at DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Enable RLS
ALTER TABLE public.daily_insights ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own insights
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'daily_insights' 
        AND policyname = 'Users can view their own relationship insights'
    ) THEN
        CREATE POLICY "Users can view their own relationship insights"
            ON public.daily_insights
            FOR SELECT
            USING (auth.uid() = user_id);
    END IF;
END
$$;
