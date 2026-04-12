-- Migration to fix Login (Profile Setup), Account Deletion, and other RLS issues
-- Adds missing INSERT, UPDATE, and DELETE policies for core tables.

-- 1. USERS Table Policies
DO $$
BEGIN
    -- Allow users to insert their own profile during signup
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can insert self') THEN
        CREATE POLICY "Users can insert self" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
    END IF;

    -- Allow users to delete their own account
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can delete self') THEN
        CREATE POLICY "Users can delete self" ON public.users FOR DELETE USING (auth.uid() = id);
    END IF;
END $$;

-- 2. RELATIONSHIPS Table Policies
DO $$
BEGIN
    -- Fix: Use a more robust SELECT policy that doesn't rely on users table link
    -- This is critical during signup when the user isn't linked to the relationship yet.
    DROP POLICY IF EXISTS "Partners can view their own relationship" ON public.relationships;
    
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'relationships' AND policyname = 'Users can view their own relationship') THEN
        CREATE POLICY "Users can view their own relationship" ON public.relationships 
        FOR SELECT USING (
            auth.uid() = partner_a_id 
            OR auth.uid() = partner_b_id 
            OR id = (SELECT relationship_id FROM public.users WHERE id = auth.uid())
        );
    END IF;

    -- Allow users to create a relationship row
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'relationships' AND policyname = 'Users can insert relationships') THEN
        CREATE POLICY "Users can insert relationships" ON public.relationships 
        FOR INSERT WITH CHECK (
            auth.uid() = partner_a_id OR auth.uid() = partner_b_id
        );
    END IF;

    -- Allow partners to update their relationship (unpairing, status change, photo)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'relationships' AND policyname = 'Partners can update relationship') THEN
        CREATE POLICY "Partners can update relationship" ON public.relationships 
        FOR UPDATE USING (
            auth.uid() = partner_a_id 
            OR auth.uid() = partner_b_id 
            OR id = (SELECT relationship_id FROM public.users WHERE id = auth.uid())
        );
    END IF;
END $$;

-- 3. DAILY_LOGS Table Policies
DO $$
BEGIN
    -- Allow users to insert logs
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_logs' AND policyname = 'Users can insert logs') THEN
        CREATE POLICY "Users can insert logs" ON public.daily_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Allow users to update their own logs
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_logs' AND policyname = 'Users can update own logs') THEN
        CREATE POLICY "Users can update own logs" ON public.daily_logs FOR UPDATE USING (auth.uid() = user_id);
    END IF;

    -- Allow users to delete their own logs
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'daily_logs' AND policyname = 'Users can delete own logs') THEN
        CREATE POLICY "Users can delete own logs" ON public.daily_logs FOR DELETE USING (auth.uid() = user_id);
    END IF;
END $$;

-- 4. CYCLE_DATA & CYCLE_PERIODS Table Policies
DO $$
BEGIN
    -- CYCLE_DATA
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'cycle_data' AND policyname = 'Users can manage own cycle data') THEN
        CREATE POLICY "Users can manage own cycle data" ON public.cycle_data FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- CYCLE_PERIODS
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'cycle_periods' AND policyname = 'Users can manage own cycle periods') THEN
        CREATE POLICY "Users can manage own cycle periods" ON public.cycle_periods FOR ALL USING (auth.uid() = user_id);
    END IF;
END $$;

-- 5. PARTNER_INVITES Table Policies
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'partner_invites' AND policyname = 'Users can manage own invites') THEN
        CREATE POLICY "Users can manage own invites" ON public.partner_invites FOR ALL USING (auth.uid() = created_by);
    END IF;
    
    -- Also allow users to view an invite if they are about to use it
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'partner_invites' AND policyname = 'Users can view any invite by code') THEN
        CREATE POLICY "Users can view any invite by code" ON public.partner_invites FOR SELECT USING (true);
    END IF;
END $$;

-- 6. USER_NOTIFICATIONS Table Policies
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_notifications' AND policyname = 'Users can manage own notifications') THEN
        CREATE POLICY "Users can manage own notifications" ON public.user_notifications FOR ALL USING (auth.uid() = user_id);
    END IF;
END $$;

-- 7. Ensure AI_SUMMARIES can be managed
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'ai_summaries' AND policyname = 'Users can manage own ai summaries') THEN
        CREATE POLICY "Users can manage own ai summaries" ON public.ai_summaries FOR ALL USING (auth.uid() = user_id);
    END IF;
END $$;
