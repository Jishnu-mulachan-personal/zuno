-- Run this in your Supabase SQL Editor before using the Pair with Partner feature.

CREATE TABLE IF NOT EXISTS partner_invites (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token      TEXT UNIQUE NOT NULL,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  used_by    UUID REFERENCES users(id),
  used       BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE partner_invites ENABLE ROW LEVEL SECURITY;

-- Policy: anyone authenticated can insert their own invite
CREATE POLICY "Users can create invites" ON partner_invites
  FOR INSERT WITH CHECK (true);

-- Policy: anyone authenticated can read all invites (needed for token lookup)
CREATE POLICY "Anyone can read invites by token" ON partner_invites
  FOR SELECT USING (true);

-- Policy: anyone authenticated can claim an invite (mark it used)
CREATE POLICY "Users can claim unclaimed invites" ON partner_invites
  FOR UPDATE USING (true);
