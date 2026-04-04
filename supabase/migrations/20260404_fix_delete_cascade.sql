-- Comprehensive fix for account deletion by adding ON DELETE CASCADE or SET NULL to all referencing foreign keys

-- 1. RELATIONSHIPS cleanup
ALTER TABLE relationships DROP CONSTRAINT IF EXISTS fk_partner_a;
ALTER TABLE relationships
  ADD CONSTRAINT fk_partner_a
  FOREIGN KEY (partner_a_id)
  REFERENCES users(id)
  ON DELETE SET NULL;

ALTER TABLE relationships DROP CONSTRAINT IF EXISTS fk_partner_b;
ALTER TABLE relationships
  ADD CONSTRAINT fk_partner_b
  FOREIGN KEY (partner_b_id)
  REFERENCES users(id)
  ON DELETE SET NULL;

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_relationship_id_fkey;
ALTER TABLE users
  ADD CONSTRAINT users_relationship_id_fkey
  FOREIGN KEY (relationship_id)
  REFERENCES relationships(id)
  ON DELETE SET NULL;

-- 2. DAILY_LOGS cleanup (ON DELETE CASCADE)
ALTER TABLE daily_logs DROP CONSTRAINT IF EXISTS daily_logs_user_id_fkey;
ALTER TABLE daily_logs
  ADD CONSTRAINT daily_logs_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- 3. CYCLE_DATA cleanup (ON DELETE CASCADE)
ALTER TABLE cycle_data DROP CONSTRAINT IF EXISTS cycle_data_user_id_fkey;
ALTER TABLE cycle_data
  ADD CONSTRAINT cycle_data_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- 4. CYCLE_PERIODS cleanup (ON DELETE CASCADE)
ALTER TABLE cycle_periods DROP CONSTRAINT IF EXISTS cycle_periods_user_id_fkey;
ALTER TABLE cycle_periods
  ADD CONSTRAINT cycle_periods_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- 5. AI_SUMMARIES cleanup (ON DELETE CASCADE)
ALTER TABLE ai_summaries DROP CONSTRAINT IF EXISTS ai_summaries_user_id_fkey;
ALTER TABLE ai_summaries
  ADD CONSTRAINT ai_summaries_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- 6. USER_SETTINGS cleanup (ON DELETE CASCADE)
ALTER TABLE user_settings DROP CONSTRAINT IF EXISTS user_settings_user_id_fkey;
ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;

-- 7. PARTNER_INVITES cleanup
ALTER TABLE partner_invites DROP CONSTRAINT IF EXISTS partner_invites_created_by_fkey;
ALTER TABLE partner_invites
  ADD CONSTRAINT partner_invites_created_by_fkey
  FOREIGN KEY (created_by)
  REFERENCES users(id)
  ON DELETE CASCADE;

ALTER TABLE partner_invites DROP CONSTRAINT IF EXISTS partner_invites_used_by_fkey;
ALTER TABLE partner_invites
  ADD CONSTRAINT partner_invites_used_by_fkey
  FOREIGN KEY (used_by)
  REFERENCES users(id)
  ON DELETE SET NULL;

-- 8. USER_NOTIFICATIONS cleanup (ON DELETE CASCADE)
ALTER TABLE user_notifications DROP CONSTRAINT IF EXISTS user_notifications_user_id_fkey;
ALTER TABLE user_notifications
  ADD CONSTRAINT user_notifications_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES users(id)
  ON DELETE CASCADE;
