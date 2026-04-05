-- Enable pg_cron expansion if not already enabled
-- Note: This requires the pg_cron extension to be pre-installed in your Supabase instance.
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the daily_reminder function to run hourly
-- The function itself checks if 20 hours have passed since the user's last login.
-- Replace [PROJECT_ID] and [SERVICE_ROLE_KEY] with actual values during deployment
-- or set them as environment variables/secrets if your platform supports it.

SELECT cron.schedule(
  'daily-reminder-trigger',
  '0 * * * *', -- Every hour on the hour
  $$
  SELECT
    net.http_post(
      url := 'https://ewwnuhqxahnatbairsrh.supabase.co/functions/v1/daily_reminder',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_UHilTbNygFU-4t9GddjTpQ_TPU2WJkY"}'::jsonb,
      body := '{}'::jsonb
    );
  $$
);

COMMENT ON COLUMN public.notification_templates.trigger_at_utc_time IS 'UTC time of day to trigger periodic notifications (e.g., 09:00:00). Currently handled by scheduled cron jobs.';
