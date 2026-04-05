-- 1. Add columns to user_settings
ALTER TABLE public.user_settings 
ADD COLUMN IF NOT EXISTS privacy_preference TEXT CHECK (privacy_preference IN ('private', 'balanced', 'shared')) DEFAULT 'balanced',
ADD COLUMN IF NOT EXISTS goals TEXT[] DEFAULT '{}';

-- 2. Remove columns from relationships
-- (The user said "instead of", so we remove them from relationships)
ALTER TABLE public.relationships 
DROP COLUMN IF EXISTS privacy_preference,
DROP COLUMN IF EXISTS goals;
