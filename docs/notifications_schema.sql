-- Create notification_templates table
CREATE TABLE public.notification_templates (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  type text NOT NULL UNIQUE,
  message text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert initial templates
INSERT INTO public.notification_templates (type, message) VALUES
('partner_checkin', 'Your partner just checked in! 💖'),
('gentle_reminder', 'Hey, just a gentle reminder to log your day 🌟');

-- Add fcm_token to users
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='users' AND column_name='fcm_token') THEN
        ALTER TABLE public.users ADD COLUMN fcm_token text;
    END IF;
END $$;

-- Enable RLS
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated users
CREATE POLICY "Allow read access to all authenticated users"
ON public.notification_templates
FOR SELECT
TO authenticated
USING (true);


CREATE TABLE public.user_notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.users(id) NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  is_read boolean DEFAULT false
);

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon to read user_notifications" ON public.user_notifications FOR SELECT USING (true);
CREATE POLICY "Allow anon to insert user_notifications" ON public.user_notifications FOR INSERT WITH CHECK (true);



-- Enable Realtime for user_notifications
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notifications;
