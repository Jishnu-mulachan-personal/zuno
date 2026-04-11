-- Migration to fix RLS visibility issues between partners
-- Addresses issues with Daily Chat and Journal Log visibility
-- NOTE: Uses public.my_relationship_id() which must be defined as SECURITY DEFINER
-- to avoid infinite recursion.

-- 0. Ensure helper function exists and is robust (Redefining here for safety)
CREATE OR REPLACE FUNCTION public.my_relationship_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT relationship_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$;

-- 1. Fix Users Table visibility
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view self and partner" ON public.users;
    DROP POLICY IF EXISTS "Users can update self" ON public.users;

    -- Policy for users to see themselves and their partner
    -- We use my_relationship_id() which is SECURITY DEFINER to break recursion
    CREATE POLICY "Users can view self and partner" ON public.users 
    FOR SELECT 
    USING (
        id = auth.uid() 
        OR 
        (relationship_id IS NOT NULL AND relationship_id = public.my_relationship_id())
    );

    CREATE POLICY "Users can update self" ON public.users 
    FOR UPDATE 
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());
END $$;

-- 2. Fix Relationships Table visibility
ALTER TABLE public.relationships ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Partners can view their own relationship" ON public.relationships;

    CREATE POLICY "Partners can view their own relationship" ON public.relationships 
    FOR SELECT 
    USING (
        id = public.my_relationship_id()
    );
END $$;

-- 3. Fix Daily Logs visibility
ALTER TABLE public.daily_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their own logs" ON public.daily_logs;
    DROP POLICY IF EXISTS "Partners can view shared logs" ON public.daily_logs;

    CREATE POLICY "Users can view their own logs" ON public.daily_logs 
    FOR SELECT 
    USING (auth.uid() = user_id);

    CREATE POLICY "Partners can view shared logs" ON public.daily_logs 
    FOR SELECT 
    USING (
        share_with_partner = true 
        AND 
        user_id IN (
            SELECT u.id FROM public.users u 
            WHERE u.relationship_id = public.my_relationship_id()
        )
    );
END $$;

-- 4. Re-verify Daily Questions Answers visibility
ALTER TABLE public.couple_daily_answers ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Partners can view shared answers" ON public.couple_daily_answers;
    
    CREATE POLICY "Partners can view shared answers" ON public.couple_daily_answers 
    FOR SELECT 
    USING (
        couple_daily_question_id IN (
            SELECT q.id FROM public.couple_daily_questions q 
            WHERE q.relationship_id = public.my_relationship_id()
        )
    );
END $$;
