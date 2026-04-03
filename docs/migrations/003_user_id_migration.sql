-- 1. Migrate Daily Logs
UPDATE daily_logs SET user_id = '9b70cdae-cba3-4299-a42a-43e704c146f5' WHERE user_id = '96b3fe0f-c91f-45dd-bfc4-59623ad8c4c1';

-- 2. Migrate Cycle Data
UPDATE cycle_data SET user_id = '9b70cdae-cba3-4299-a42a-43e704c146f5' WHERE user_id = '96b3fe0f-c91f-45dd-bfc4-59623ad8c4c1';

-- 3. Migrate Historical Cycle Periods
UPDATE cycle_periods SET user_id = '9b70cdae-cba3-4299-a42a-43e704c146f5' WHERE user_id = '96b3fe0f-c91f-45dd-bfc4-59623ad8c4c1';

-- 4. Update Relationship references (if they were Partner A or B)
UPDATE relationships SET partner_a_id = '9b70cdae-cba3-4299-a42a-43e704c146f5' WHERE partner_a_id = '96b3fe0f-c91f-45dd-bfc4-59623ad8c4c1';
UPDATE relationships SET partner_b_id = '9b70cdae-cba3-4299-a42a-43e704c146f5' WHERE partner_b_id = '96b3fe0f-c91f-45dd-bfc4-59623ad8c4c1';
