-- Migration to fix RLS visibility for insights and mood trends
-- This allows partners in a relationship to view each other's data for better sync.

-- Ensure helper function exists (SECURITY DEFINER to avoid recursion)
CREATE OR REPLACE FUNCTION public.my_relationship_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT relationship_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$;

-- 1. Relax daily_logs RLS
-- Allows partners to see each other's logs (needed for Mood Trend Graph)
DO $$
BEGIN
    DROP POLICY IF EXISTS "Partners can view shared logs" ON public.daily_logs;
    DROP POLICY IF EXISTS "Partners can view each other's logs" ON public.daily_logs;

    CREATE POLICY "Partners can view each other's logs" ON public.daily_logs 
    FOR SELECT 
    USING (
        user_id IN (
            SELECT id FROM public.users 
            WHERE relationship_id = public.my_relationship_id()
        )
    );
END $$;

-- 2. Relax daily_insights RLS
-- Allows partners to see each other's daily AI insights
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their own relationship insights" ON public.daily_insights;
    DROP POLICY IF EXISTS "Partners can view each other's daily insights" ON public.daily_insights;

    CREATE POLICY "Partners can view each other's daily insights" ON public.daily_insights
    FOR SELECT
    USING (
        user_id IN (
            SELECT id FROM public.users 
            WHERE relationship_id = public.my_relationship_id()
        )
    );
END $$;

-- 3. Relax daily_cycle_insights RLS
-- Allows partners to see each other's cycle insights
DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can view their own cycle insights" ON public.daily_cycle_insights;
    DROP POLICY IF EXISTS "Partners can view each other's cycle insights" ON public.daily_cycle_insights;

    CREATE POLICY "Partners can view each other's cycle insights" ON public.daily_cycle_insights
    FOR SELECT
    USING (
        user_id IN (
            SELECT id FROM public.users 
            WHERE relationship_id = public.my_relationship_id()
        )
    );
END $$;
