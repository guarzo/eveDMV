-- Initialize PostgreSQL with pg_cron extension for EVE DMV development
-- This script runs when the database is first created

-- Create the pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create pg_stat_statements extension for performance monitoring
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Grant necessary permissions for pg_cron usage
-- Note: In development, we'll use the postgres superuser for simplicity
-- In production, you should create a dedicated user with minimal permissions

-- Create a sample cron job to verify pg_cron is working
-- This job runs every minute and logs to the PostgreSQL log
SELECT cron.schedule(
    'test-pg-cron',
    '* * * * *',
    'SELECT pg_notify(''pg_cron_test'', ''pg_cron is working at '' || now());'
);

-- Create a function to help verify pg_cron functionality
CREATE OR REPLACE FUNCTION check_pg_cron_status()
RETURNS TABLE(
    jobid bigint,
    schedule text,
    command text,
    nodename text,
    nodeport integer,
    database text,
    username text,
    active boolean,
    jobname text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        j.jobid,
        j.schedule,
        j.command,
        j.nodename,
        j.nodeport,
        j.database,
        j.username,
        j.active,
        j.jobname
    FROM cron.job j
    ORDER BY j.jobid;
END;
$$ LANGUAGE plpgsql;

-- Log that initialization is complete
SELECT pg_notify('pg_cron_init', 'PostgreSQL with pg_cron initialized successfully');