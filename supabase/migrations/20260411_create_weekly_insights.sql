-- Create table for weekly relationship AI insights
CREATE TABLE IF NOT EXISTS public.weekly_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES public.relationships(id) ON DELETE CASCADE,
    pattern_text TEXT NOT NULL,
    alignment_text TEXT NOT NULL,
    theme_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.weekly_insights ENABLE ROW LEVEL SECURITY;

-- Partners can view their weekly insights
CREATE POLICY "Partners can view their weekly insights" ON public.weekly_insights
    FOR SELECT USING (relationship_id = public.my_relationship_id());

-- Service role can do everything (required for Edge Functions using Service Role Key)
CREATE POLICY "Service role can manage weekly insights" ON public.weekly_insights
    USING (auth.jwt() ->> 'role' = 'service_role');
