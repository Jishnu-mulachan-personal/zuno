-- Migration to add AI Insights summary tables

-- Create table for storing per-user AI conversation summaries
CREATE TABLE IF NOT EXISTS public.ai_summary_user_session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    summary_text TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index the user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_ai_summary_user_session_user_id ON public.ai_summary_user_session (user_id);

-- Enable RLS for ai_summary_user_session
ALTER TABLE public.ai_summary_user_session ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only read and write their own summaries"
ON public.ai_summary_user_session
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Create table for storing relationship AI conversation summaries
CREATE TABLE IF NOT EXISTS public.ai_summary_relationship_session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES public.relationships(id) ON DELETE CASCADE,
    summary_text TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index the relationship_id
CREATE INDEX IF NOT EXISTS idx_ai_summary_relationship_session_relationship_id ON public.ai_summary_relationship_session (relationship_id);

-- Enable RLS for ai_summary_relationship_session
-- Users can only read/write if they are part of the relationship. 
-- Assuming users table has relationship_id, a secure way is check against users table.
ALTER TABLE public.ai_summary_relationship_session ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can access relationship summary if they belong to it"
ON public.ai_summary_relationship_session
FOR ALL
USING (EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() AND users.relationship_id = ai_summary_relationship_session.relationship_id
))
WITH CHECK (EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() AND users.relationship_id = ai_summary_relationship_session.relationship_id
));

-- Function to automatically update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for auto-updating the updated_at column
CREATE TRIGGER update_ai_summary_user_session_updated_at
BEFORE UPDATE ON public.ai_summary_user_session
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ai_summary_relationship_session_updated_at
BEFORE UPDATE ON public.ai_summary_relationship_session
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
