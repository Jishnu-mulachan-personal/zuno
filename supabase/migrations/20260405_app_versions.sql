-- Create app_versions table to manage updates
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    latest_version TEXT NOT NULL,
    min_version TEXT NOT NULL,
    update_url TEXT NOT NULL,
    release_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read versions (so app can check before login)
CREATE POLICY "Public can view app versions" 
    ON public.app_versions 
    FOR SELECT 
    USING (true);

-- Insert initial version
INSERT INTO public.app_versions (platform, latest_version, min_version, update_url, release_notes)
VALUES 
('android', '1.0.0', '1.0.0', 'https://play.google.com/store/apps/details?id=com.zuno.app', 'Initial release of Zuno!'),
('ios', '1.0.0', '1.0.0', 'https://apps.apple.com/app/zuno/id000000000', 'Initial release of Zuno!');
