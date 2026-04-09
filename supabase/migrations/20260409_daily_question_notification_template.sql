-- Add daily_question_answer notification template
INSERT INTO public.notification_templates (type, title, message)
VALUES ('daily_question_answer', 'Question Answered! 💚', 'Your partner has answered a daily question. Go check what they said!')
ON CONFLICT (type) DO UPDATE SET
  title = EXCLUDED.title,
  message = EXCLUDED.message;
