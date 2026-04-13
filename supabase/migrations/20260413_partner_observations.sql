-- ─────────────────────────────────────────────────────────────────────────────
-- Partner Observations: male partner submits an emoji mood observation
-- when the female hasn't logged yet.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partner_observations (
  id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  observer_id     UUID    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  relationship_id UUID    NOT NULL REFERENCES public.relationships(id) ON DELETE CASCADE,
  observed_emoji  TEXT    NOT NULL,
  observed_on     DATE    NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique: one observation per observer per day
CREATE UNIQUE INDEX IF NOT EXISTS partner_observations_unique_day
  ON public.partner_observations (observer_id, observed_on);

ALTER TABLE public.partner_observations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  DROP POLICY IF EXISTS "Users can insert their own observations" ON public.partner_observations;
  DROP POLICY IF EXISTS "Partners can read observations in their relationship" ON public.partner_observations;

  CREATE POLICY "Users can insert their own observations"
    ON public.partner_observations
    FOR INSERT
    WITH CHECK (auth.uid() = observer_id);

  CREATE POLICY "Partners can read observations in their relationship"
    ON public.partner_observations
    FOR SELECT
    USING (
      relationship_id IN (
        SELECT relationship_id FROM public.users WHERE id = auth.uid()
      )
    );
END $$;
