-- ─────────────────────────────────────────────────────────────────────────────
-- Partner Insights Bidirectional: Support for insights about both partners
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add about_user_id column
ALTER TABLE public.partner_cycle_insights ADD COLUMN about_user_id UUID REFERENCES public.users(id);

-- 2. Populate about_user_id based on existing relationship data 
-- (Existing rows were exclusively for the female partner)
UPDATE public.partner_cycle_insights pci
SET about_user_id = (
  SELECT u.id 
  FROM public.users u 
  WHERE u.relationship_id = pci.relationship_id AND u.gender = 'Female'
  LIMIT 1
);

-- 3. Cleanup: Remove rows where partner couldn't be determined (should be 0 in healthy data)
DELETE FROM public.partner_cycle_insights WHERE about_user_id IS NULL;

-- 4. Constraint Updates
ALTER TABLE public.partner_cycle_insights ALTER COLUMN about_user_id SET NOT NULL;
ALTER TABLE public.partner_cycle_insights DROP CONSTRAINT IF EXISTS partner_cycle_insights_pkey;
ALTER TABLE public.partner_cycle_insights ADD PRIMARY KEY (relationship_id, about_user_id);

-- 5. Policy Updates (Simplified to ensure both partners can read each other's insights)
DROP POLICY IF EXISTS "Partners can view partner cycle insights" ON public.partner_cycle_insights;

CREATE POLICY "Partners can view partner daily insights"
  ON public.partner_cycle_insights
  FOR SELECT
  USING (
    relationship_id IN (
      SELECT relationship_id FROM public.users WHERE id = auth.uid()
    )
  );
