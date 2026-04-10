-- Add share_journal_with_partner to user_settings
ALTER TABLE public.user_settings 
ADD COLUMN IF NOT EXISTS share_journal_with_partner BOOLEAN DEFAULT false;

-- Add share_with_partner to daily_logs
ALTER TABLE public.daily_logs 
ADD COLUMN IF NOT EXISTS share_with_partner BOOLEAN DEFAULT false;
