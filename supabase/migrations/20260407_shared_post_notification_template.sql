-- Add shared_post notification template
INSERT INTO public.notification_templates (type, title, message)
VALUES ('shared_post', 'New Moment Shared! ✨', 'Your partner just shared a new moment with you. Check it out!')
ON CONFLICT (type) DO UPDATE SET 
  title = EXCLUDED.title,
  message = EXCLUDED.message;
