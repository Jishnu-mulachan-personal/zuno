ALTER TABLE users ADD COLUMN IF NOT EXISTS gender TEXT;

-- 1. Ensure cycle_data only has one row per user
ALTER TABLE cycle_data DROP CONSTRAINT IF EXISTS cycle_data_user_id_key;
ALTER TABLE cycle_data ADD CONSTRAINT cycle_data_user_id_key UNIQUE (user_id);

-- 2. Enable cascading deletes so cycle_data is removed when user is deleted
ALTER TABLE cycle_data DROP CONSTRAINT IF EXISTS cycle_data_user_id_fkey;
ALTER TABLE cycle_data
  ADD CONSTRAINT cycle_data_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- 3. Enable cascading deletes for daily_logs
ALTER TABLE daily_logs DROP CONSTRAINT IF EXISTS daily_logs_user_id_fkey;
ALTER TABLE daily_logs
  ADD CONSTRAINT daily_logs_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;
