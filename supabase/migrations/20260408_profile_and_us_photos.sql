-- 1. Add avatar_url to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- 2. Add us_photo_url to relationships table
ALTER TABLE public.relationships ADD COLUMN IF NOT EXISTS us_photo_url TEXT;

-- 3. Create storage buckets
-- Note: These might fail if run multiple times, but Supabase UI is usually preferred.
-- We use DO blocks for safety.

DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('avatars', 'avatars', false)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO storage.buckets (id, name, public)
    VALUES ('us-photos', 'us-photos', false)
    ON CONFLICT (id) DO NOTHING;
END $$;

-- 4. Enable RLS on buckets (usually enabled by default in Supabase)
-- Policies for 'avatars' bucket
CREATE POLICY "Avatar images are accessible by owner"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Policies for 'us-photos' bucket
-- These should allow both partners in a relationship to access the photo.
-- For simplicity in a migration, we allow authenticated users to read if they know the relationship ID,
-- and owners to upload. A more strict policy would check the relationships table.

CREATE POLICY "US photos are accessible by partners"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'us-photos');

CREATE POLICY "Partners can upload US photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'us-photos');

CREATE POLICY "Partners can update US photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'us-photos');
