-- Migration for Daily Insight Questions

CREATE TABLE IF NOT EXISTS public.daily_insight_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL, -- List of strings
    selected_option TEXT,
    created_at DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS daily_insight_questions_user_date_idx ON public.daily_insight_questions(user_id, created_at);

-- Enable RLS
ALTER TABLE public.daily_insight_questions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own insight questions"
    ON public.daily_insight_questions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own insight questions"
    ON public.daily_insight_questions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can do everything on daily_insight_questions"
    ON public.daily_insight_questions
    FOR ALL
    USING (true)
    WITH CHECK (true);
