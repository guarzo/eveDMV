defmodule EveDmv.Repo.Migrations.ImplementKillmailPartitioning do
  use Ecto.Migration
  require Logger

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Configure partitioning parameters
  @start_date "2024-01-01"
  @months_to_create 15  # Create partitions up to 3 months in future
  @batch_size 10_000

  def up do
    # Step 1: Create partitioned table structure
    create_partitioned_table()
    
    # Step 2: Create monthly partitions
    create_partitions()
    
    # Step 3: Copy indexes to new partitioned table
    copy_indexes()
    
    # Step 4: Migrate data (this is the slow part)
    migrate_data()
    
    # Step 5: Create partition management functions
    create_partition_management_functions()
    
    # Step 6: Swap tables
    swap_tables()
    
    Logger.info("Killmail partitioning completed successfully!")
  end

  def down do
    # Revert to non-partitioned table
    execute """
    -- Drop the partitioned table if we renamed it
    DROP TABLE IF EXISTS killmails_raw_partitioned CASCADE;
    
    -- If we already swapped, restore the original
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'killmails_raw_old') THEN
        DROP TABLE IF EXISTS killmails_raw CASCADE;
        ALTER TABLE killmails_raw_old RENAME TO killmails_raw;
      END IF;
    END $$;
    """
  end

  defp create_partitioned_table do
    execute """
    -- Create new partitioned table with same structure as original
    CREATE TABLE killmails_raw_partitioned (
      LIKE killmails_raw INCLUDING ALL EXCLUDING INDEXES
    ) PARTITION BY RANGE (killmail_time);
    
    -- Add comment
    COMMENT ON TABLE killmails_raw_partitioned IS 
      'Partitioned killmail data by month for improved query performance';
    """
  end

  defp create_partitions do
    # Generate partitions from start date to 3 months in future
    start_date = Date.from_iso8601!(@start_date)
    end_date = Date.utc_today() |> Date.add(90)  # 3 months ahead
    
    create_partitions_between(start_date, end_date)
  end

  defp create_partitions_between(current_date, end_date) when current_date < end_date do
    # Create partition for this month
    year = current_date.year
    month = current_date.month |> Integer.to_string() |> String.pad_leading(2, "0")
    partition_name = "killmails_raw_#{year}_#{month}"
    
    # Calculate next month for partition boundary
    next_month = Date.add(current_date, Date.days_in_month(current_date))
    
    execute """
    CREATE TABLE #{partition_name} PARTITION OF killmails_raw_partitioned
    FOR VALUES FROM ('#{current_date}') TO ('#{next_month}');
    """
    
    Logger.info("Created partition: #{partition_name}")
    
    # Move to next month
    create_partitions_between(next_month, end_date)
  end

  defp create_partitions_between(_current_date, _end_date), do: :ok

  defp copy_indexes do
    # Get all indexes from original table
    indexes_query = """
    SELECT indexname, indexdef
    FROM pg_indexes
    WHERE tablename = 'killmails_raw'
    AND indexname NOT LIKE '%_pkey'
    ORDER BY indexname;
    """
    
    indexes = Ecto.Adapters.SQL.query!(repo(), indexes_query).rows
    
    # Create each index on the partitioned table
    Enum.each(indexes, fn [name, definition] ->
      # Replace table name in definition
      new_definition = String.replace(definition, "killmails_raw", "killmails_raw_partitioned")
      new_definition = String.replace(new_definition, "INDEX #{name}", "INDEX #{name}_part")
      
      # Add CONCURRENTLY if not present
      unless String.contains?(new_definition, "CONCURRENTLY") do
        new_definition = String.replace(new_definition, "CREATE INDEX", "CREATE INDEX CONCURRENTLY")
      end
      
      execute new_definition
      Logger.info("Created index: #{name}_part")
    end)
  end

  defp migrate_data do
    Logger.info("Starting data migration (this may take a while)...")
    
    # Get total row count for progress tracking
    total_count = Ecto.Adapters.SQL.query!(
      repo(), 
      "SELECT COUNT(*) FROM killmails_raw"
    ).rows |> List.first() |> List.first()
    
    Logger.info("Total rows to migrate: #{total_count}")
    
    # Migrate in batches to avoid memory issues
    migrate_in_batches(0, total_count)
  end

  defp migrate_in_batches(offset, total) when offset < total do
    # Copy batch of data
    {rows_copied, _} = Ecto.Adapters.SQL.query!(
      repo(),
      """
      INSERT INTO killmails_raw_partitioned
      SELECT * FROM killmails_raw
      ORDER BY killmail_id
      LIMIT $1 OFFSET $2
      ON CONFLICT (killmail_id, killmail_time) DO NOTHING
      """,
      [@batch_size, offset]
    ).num_rows
    
    progress = Float.round((offset / total) * 100, 2)
    Logger.info("Migration progress: #{progress}% (#{offset}/#{total} rows)")
    
    # Continue with next batch
    migrate_in_batches(offset + @batch_size, total)
  end

  defp migrate_in_batches(_offset, _total), do: :ok

  defp create_partition_management_functions do
    execute """
    -- Function to create a monthly partition
    CREATE OR REPLACE FUNCTION create_monthly_partition(
      table_name text,
      partition_date date
    ) RETURNS void AS $$
    DECLARE
      partition_name text;
      start_date date;
      end_date date;
    BEGIN
      -- Ensure we're at the start of the month
      start_date := date_trunc('month', partition_date);
      end_date := start_date + interval '1 month';
      partition_name := table_name || '_' || to_char(start_date, 'YYYY_MM');
      
      -- Check if partition already exists
      IF NOT EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = partition_name
      ) THEN
        EXECUTE format(
          'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
          partition_name, table_name, start_date, end_date
        );
        RAISE NOTICE 'Created partition %', partition_name;
      END IF;
    END;
    $$ LANGUAGE plpgsql;

    -- Function to ensure future partitions exist
    CREATE OR REPLACE FUNCTION ensure_future_partitions(
      table_name text,
      months_ahead integer DEFAULT 3
    ) RETURNS void AS $$
    DECLARE
      current_date date;
      target_date date;
      i integer;
    BEGIN
      current_date := date_trunc('month', CURRENT_DATE);
      
      FOR i IN 0..months_ahead LOOP
        target_date := current_date + (i || ' months')::interval;
        PERFORM create_monthly_partition(table_name, target_date);
      END LOOP;
    END;
    $$ LANGUAGE plpgsql;

    -- Function to drop old partitions
    CREATE OR REPLACE FUNCTION drop_old_partitions(
      table_name text,
      months_to_keep integer DEFAULT 12
    ) RETURNS void AS $$
    DECLARE
      cutoff_date date;
      partition_record record;
    BEGIN
      cutoff_date := date_trunc('month', CURRENT_DATE - (months_to_keep || ' months')::interval);
      
      FOR partition_record IN
        SELECT tablename
        FROM pg_tables
        WHERE tablename LIKE table_name || '_%'
        AND tablename ~ '_[0-9]{4}_[0-9]{2}$'
      LOOP
        -- Extract date from partition name
        IF to_date(right(partition_record.tablename, 7), 'YYYY_MM') < cutoff_date THEN
          EXECUTE format('DROP TABLE %I', partition_record.tablename);
          RAISE NOTICE 'Dropped old partition %', partition_record.tablename;
        END IF;
      END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  defp swap_tables do
    execute """
    -- Begin transaction for atomic swap
    BEGIN;
    
    -- Rename original table
    ALTER TABLE killmails_raw RENAME TO killmails_raw_old;
    
    -- Rename partitioned table to original name
    ALTER TABLE killmails_raw_partitioned RENAME TO killmails_raw;
    
    -- Rename all indexes to remove _part suffix
    DO $$
    DECLARE
      idx record;
    BEGIN
      FOR idx IN
        SELECT indexname
        FROM pg_indexes
        WHERE tablename = 'killmails_raw'
        AND indexname LIKE '%_part'
      LOOP
        EXECUTE format(
          'ALTER INDEX %I RENAME TO %I',
          idx.indexname,
          replace(idx.indexname, '_part', '')
        );
      END LOOP;
    END $$;
    
    COMMIT;
    """
    
    Logger.info("Table swap completed successfully!")
  end
end