-- Enable Realtime replication for Daily Questions answers
-- This allows the app to listen for partner answers/reviews live.
alter publication supabase_realtime add table public.couple_daily_answers;
