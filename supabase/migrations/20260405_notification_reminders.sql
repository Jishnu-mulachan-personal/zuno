-- Add title and trigger_at_utc_time to notification_templates
ALTER TABLE public.notification_templates 
ADD COLUMN IF NOT EXISTS title TEXT,
ADD COLUMN IF NOT EXISTS trigger_at_utc_time TIME;

-- Update existing templates with titles and trigger times
UPDATE public.notification_templates 
SET title = 'Check-in Alert' 
WHERE type = 'partner_checkin' AND title IS NULL;

UPDATE public.notification_templates 
SET title = 'Time for a Check-in! 💚',
    trigger_at_utc_time = '13:00:00' 
WHERE type = 'gentle_reminder';
