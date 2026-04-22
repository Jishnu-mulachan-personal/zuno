-- DROP connection_felt column from daily_logs table
ALTER TABLE daily_logs DROP COLUMN IF EXISTS connection_felt;
