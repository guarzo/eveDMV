defmodule EveDmv.Repo.Migrations.SwitchToPartitionedTables do
  @moduledoc """
  Switch application to use partitioned tables and implement automated partition management.

  This migration:
  1. Ensures killmails_raw_partitioned is being used instead of killmails_raw
  2. Implements automated partition creation via pg_cron (if available)
  3. Sets up maintenance procedures for old partition cleanup
  4. Creates partitions for test data dates (2024)
  """

  use Ecto.Migration
  require Logger

  def up do
    # =======================================================
    # Step 1: Enable pg_cron extension for automation (optional)
    # =======================================================

    # Try to create pg_cron extension in a separate transaction to avoid poisoning the main one
    execute """
    DO $$
    BEGIN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
        RAISE NOTICE 'pg_cron extension enabled - automated partition management will work';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron extension not available - partition automation will be disabled';
    END $$;
    """

    # =======================================================
    # Step 2: Handle the table switch based on current state
    # =======================================================

    # Handle table switching using PL/pgSQL to avoid transaction issues
    execute """
    DO $$
    DECLARE
        regular_exists BOOLEAN;
        partitioned_exists BOOLEAN;
        row_count INTEGER;
    BEGIN
        -- Check what tables exist
        SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'killmails_raw') INTO regular_exists;
        SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'killmails_raw_partitioned') INTO partitioned_exists;

        IF regular_exists AND partitioned_exists THEN
            -- Both tables exist - we need to migrate data
            RAISE NOTICE 'Both killmails_raw and killmails_raw_partitioned exist - migrating data';

            -- Check if regular table has any data
            SELECT COUNT(*) INTO row_count FROM killmails_raw;

            IF row_count > 0 THEN
                -- Copy data
                INSERT INTO killmails_raw_partitioned
                SELECT * FROM killmails_raw
                ON CONFLICT (killmail_id, killmail_time) DO NOTHING;
            END IF;

            -- Rename tables
            ALTER TABLE killmails_raw RENAME TO killmails_raw_backup;
            ALTER TABLE killmails_raw_partitioned RENAME TO killmails_raw;

        ELSIF regular_exists AND NOT partitioned_exists THEN
            -- Only regular table exists - just rename it to backup
            RAISE NOTICE 'Only killmails_raw exists - renaming to backup';
            ALTER TABLE killmails_raw RENAME TO killmails_raw_backup;

        ELSIF NOT regular_exists AND partitioned_exists THEN
            -- Only partitioned table exists - rename it to the main table name
            RAISE NOTICE 'Only killmails_raw_partitioned exists - renaming to killmails_raw';
            ALTER TABLE killmails_raw_partitioned RENAME TO killmails_raw;

        ELSE
            -- Neither table exists - this is likely a fresh database
            RAISE NOTICE 'No killmails tables exist - will be created by later migrations';
        END IF;
    END $$;
    """

    # =======================================================
    # Step 3: Create automated partition management functions
    # =======================================================

    # Function to create future partitions
    execute """
    CREATE OR REPLACE FUNCTION create_killmail_partition(target_date DATE)
    RETURNS TEXT AS $$
    DECLARE
        partition_name TEXT;
        start_date TEXT;
        end_date TEXT;
        next_month_date DATE;
        table_name TEXT;
    BEGIN
        -- Determine which table name to use (killmails_raw or killmails_raw_partitioned)
        IF EXISTS (
            SELECT 1 FROM information_schema.tables t
            WHERE t.table_name = 'killmails_raw'
            AND t.table_type = 'PARTITIONED TABLE'
        ) THEN
            table_name := 'killmails_raw';
        ELSIF EXISTS (
            SELECT 1 FROM information_schema.tables t
            WHERE t.table_name = 'killmails_raw_partitioned'
        ) THEN
            table_name := 'killmails_raw_partitioned';
        ELSE
            RETURN 'No partitioned killmails table exists';
        END IF;

        -- Generate partition name based on year and month
        partition_name := 'killmails_raw_y' ||
                         EXTRACT(YEAR FROM target_date) ||
                         'm' || LPAD(EXTRACT(MONTH FROM target_date)::TEXT, 2, '0');

        -- Calculate date range for partition
        start_date := date_trunc('month', target_date)::DATE::TEXT;
        next_month_date := (date_trunc('month', target_date) + INTERVAL '1 month')::DATE;
        end_date := next_month_date::TEXT;

        -- Check if partition already exists
        IF EXISTS (
            SELECT 1 FROM pg_tables
            WHERE tablename = partition_name
        ) THEN
            RETURN 'Partition ' || partition_name || ' already exists';
        END IF;

        -- Create the partition
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
            partition_name, table_name, start_date, end_date
        );

        -- Create indexes on the new partition
        EXECUTE format(
            'CREATE INDEX %I ON %I (solar_system_id, killmail_time)',
            partition_name || '_system_time_idx', partition_name
        );

        EXECUTE format(
            'CREATE INDEX %I ON %I (victim_character_id, killmail_time)',
            partition_name || '_victim_time_idx', partition_name
        );

        RETURN 'Created partition ' || partition_name || ' for range [' || start_date || ', ' || end_date || ')';
    END;
    $$ LANGUAGE plpgsql;
    """

    # Function to drop old partitions (older than retention period)
    execute """
    CREATE OR REPLACE FUNCTION cleanup_old_killmail_partitions(retention_months INTEGER DEFAULT 12)
    RETURNS TEXT AS $$
    DECLARE
        partition_record RECORD;
        partition_date DATE;
        cutoff_date DATE;
        dropped_count INTEGER := 0;
    BEGIN
        cutoff_date := CURRENT_DATE - (retention_months || ' months')::INTERVAL;

        -- Find and drop old partitions
        FOR partition_record IN
            SELECT tablename
            FROM pg_tables
            WHERE tablename ~ '^killmails_raw(_partitioned)?_y[0-9]{4}m[0-9]{2}$'
        LOOP
            -- Extract date from partition name
            BEGIN
                partition_date := TO_DATE(
                    substring(partition_record.tablename from 'y([0-9]{4})m([0-9]{2})'),
                    'YYYYMM'
                );

                IF partition_date < cutoff_date THEN
                    EXECUTE format('DROP TABLE %I', partition_record.tablename);
                    dropped_count := dropped_count + 1;
                    RAISE NOTICE 'Dropped old partition: %', partition_record.tablename;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Could not process partition %: %', partition_record.tablename, SQLERRM;
            END;
        END LOOP;

        RETURN 'Dropped ' || dropped_count || ' old partitions (older than ' || cutoff_date || ')';
    END;
    $$ LANGUAGE plpgsql;
    """

    # Function to ensure future partitions exist (creates next 3 months)
    execute """
    CREATE OR REPLACE FUNCTION ensure_future_killmail_partitions()
    RETURNS TEXT AS $$
    DECLARE
        result TEXT := '';
        month_offset INTEGER;
        target_date DATE;
        partition_result TEXT;
    BEGIN
        -- Create partitions for current month + next 2 months
        FOR month_offset IN 0..2 LOOP
            target_date := (CURRENT_DATE + (month_offset || ' months')::INTERVAL)::DATE;

            SELECT create_killmail_partition(target_date) INTO partition_result;
            result := result || partition_result || E'\\n';
        END LOOP;

        RETURN result;
    END;
    $$ LANGUAGE plpgsql;
    """

    # =======================================================
    # Step 4: Create partitions for test data (2024) if in test environment
    # =======================================================

    # Always create partitions for 2024 (test data) and 2025 (current year)
    execute """
    DO $$
    DECLARE
        target_date DATE;
    BEGIN
        -- Create partitions for 2024 (test data)
        FOR month IN 1..12 LOOP
            target_date := DATE '2024-01-01' + (month - 1 || ' months')::INTERVAL;
            PERFORM create_killmail_partition(target_date);
        END LOOP;

        -- Create partitions for 2025 (current year)
        FOR month IN 1..12 LOOP
            target_date := DATE '2025-01-01' + (month - 1 || ' months')::INTERVAL;
            PERFORM create_killmail_partition(target_date);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Could not create all partitions: %', SQLERRM;
    END $$;
    """

    # =======================================================
    # Step 5: Set up automated cron jobs (if pg_cron is available)
    # =======================================================

    # Only create cron jobs if pg_cron extension is available
    execute """
    DO $$
    BEGIN
        IF EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
            -- Create future partitions monthly (1st day of each month at 2 AM)
            PERFORM cron.schedule(
                'create-killmail-partitions',
                '0 2 1 * *',
                'SELECT ensure_future_killmail_partitions();'
            );

            -- Cleanup old partitions quarterly (1st day of quarter at 3 AM)
            PERFORM cron.schedule(
                'cleanup-old-killmail-partitions',
                '0 3 1 */3 *',
                'SELECT cleanup_old_killmail_partitions(12);'
            );

            RAISE NOTICE 'Automated partition management jobs scheduled';
        ELSE
            RAISE NOTICE 'pg_cron not available - automated jobs not scheduled';
        END IF;
    END $$;
    """
  end

  def down do
    # Remove cron jobs (ignore errors if they don't exist)
    execute "SELECT cron.unschedule('create-killmail-partitions') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'create-killmail-partitions');"
    execute "SELECT cron.unschedule('cleanup-old-killmail-partitions') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup-old-killmail-partitions');"

    # Drop automation functions
    execute "DROP FUNCTION IF EXISTS ensure_future_killmail_partitions();"
    execute "DROP FUNCTION IF EXISTS cleanup_old_killmail_partitions(INTEGER);"
    execute "DROP FUNCTION IF EXISTS create_killmail_partition(DATE);"

    # Try to restore original table structure
    execute """
    DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'killmails_raw_backup') THEN
            DROP TABLE IF EXISTS killmails_raw;
            ALTER TABLE killmails_raw_backup RENAME TO killmails_raw;
        END IF;
    END $$;
    """

    # Note: We don't drop pg_cron extension as it might be used by other parts of the system
  end
end