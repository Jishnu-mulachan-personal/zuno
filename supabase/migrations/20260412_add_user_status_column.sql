-- Migration to add relationship_status to users table
-- This allows persistent status even when unpaired.

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS relationship_status TEXT DEFAULT 'single';

-- Update existing users based on their current relationship's status
UPDATE public.users u
SET relationship_status = r.status
FROM public.relationships r
WHERE u.relationship_id = r.id;
