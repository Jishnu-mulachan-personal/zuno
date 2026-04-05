-- 1. Add journal_note_private to user_settings
ALTER TABLE public.user_settings 
ADD COLUMN IF NOT EXISTS journal_note_private BOOLEAN DEFAULT false;

-- 2. Add is_note_private to daily_logs
ALTER TABLE public.daily_logs 
ADD COLUMN IF NOT EXISTS is_note_private BOOLEAN DEFAULT false;
