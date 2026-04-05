-- Drop the old constraint
ALTER TABLE public.relationships 
DROP CONSTRAINT IF EXISTS relationships_status_check;

-- Add the new constraint with supported statuses
-- We include 'single' and 'committed' which were missing in the original constraint.
ALTER TABLE public.relationships
ADD CONSTRAINT relationships_status_check 
CHECK (status IN ('single', 'committed', 'engaged', 'married', 'dating', 'trying_for_baby'));
