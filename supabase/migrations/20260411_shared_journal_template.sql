-- Add shared_journal notification template
INSERT INTO public.notification_templates (type, title, message)
VALUES ('shared_journal', 'New Journal Log! 🌸', 'Your partner just shared their day with you. Check it out on the Us tab! ✨')
ON CONFLICT (type) DO UPDATE SET 
  title = EXCLUDED.title,
  message = EXCLUDED.message;
