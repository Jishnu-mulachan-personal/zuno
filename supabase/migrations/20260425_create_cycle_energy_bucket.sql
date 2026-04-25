-- Create a public bucket for cycle energy character illustrations
INSERT INTO storage.buckets (id, name, public)
VALUES ('cycle-energy', 'cycle-energy', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access to the cycle-energy bucket
CREATE POLICY "Public Access to Cycle Energy Images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'cycle-energy');
