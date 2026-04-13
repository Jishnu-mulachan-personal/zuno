-- ─────────────────────────────────────────────────────────────────────────────
-- Partner Cycle Insights: daily AI-generated JSONB for male partner view
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partner_cycle_insights (
  relationship_id UUID PRIMARY KEY REFERENCES public.relationships(id) ON DELETE CASCADE,
  insight_data    JSONB    NOT NULL DEFAULT '{}',
  last_generated_at DATE   NOT NULL DEFAULT CURRENT_DATE
);

ALTER TABLE public.partner_cycle_insights ENABLE ROW LEVEL SECURITY;

-- Both partners in the relationship can read the row
DO $$
BEGIN
  DROP POLICY IF EXISTS "Partners can view partner cycle insights" ON public.partner_cycle_insights;

  CREATE POLICY "Partners can view partner cycle insights"
    ON public.partner_cycle_insights
    FOR SELECT
    USING (
      relationship_id IN (
        SELECT relationship_id FROM public.users WHERE id = auth.uid()
      )
    );
END $$;

-- Service role can write (edge function uses service role key)
-- No explicit INSERT/UPDATE policy needed for service role (bypasses RLS).

-- pg_cron daily trigger (enable on Supabase Pro plan):
-- SELECT cron.schedule(
--   'partner-insights-daily',
--   '0 6 * * *',             -- 6 AM UTC every day
--   $$
--     SELECT net.http_post(
--       url := current_setting('app.supabase_url') || '/functions/v1/generate_partner_insights',
--       headers := jsonb_build_object('Content-Type','application/json'),
--       body := '{}'::jsonb
--     );
--   $$
-- );
