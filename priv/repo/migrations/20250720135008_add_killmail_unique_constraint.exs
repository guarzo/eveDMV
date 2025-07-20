defmodule EveDmv.Repo.Migrations.AddKillmailUniqueConstraint do
  @moduledoc """
  Add unique constraint on killmail_id for partitioned killmails_raw table.
  
  For partitioned tables, unique constraints must include the partition key,
  but we can create a unique index on just killmail_id on each partition
  to support upsert operations.
  """
  
  use Ecto.Migration
  
  def up do
    # Create function to add unique index to killmail partitions
    execute """
    CREATE OR REPLACE FUNCTION add_unique_index_to_partition()
    RETURNS event_trigger AS $$
    DECLARE
        obj record;
    BEGIN
        FOR obj IN 
            SELECT * FROM pg_event_trigger_ddl_commands() 
            WHERE command_tag = 'CREATE TABLE'
        LOOP
            -- Check if this is a killmails_raw partition
            IF obj.object_identity LIKE '%killmails_raw_y%' THEN
                -- Add unique index on killmail_id
                EXECUTE format(
                    'CREATE UNIQUE INDEX IF NOT EXISTS %I ON %s (killmail_id)',
                    replace(obj.object_identity, '.', '_') || '_killmail_id_unique',
                    obj.object_identity
                );
                RAISE NOTICE 'Added unique index to partition %', obj.object_identity;
            END IF;
        END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    """
    
    # Create event trigger to automatically add indexes to new partitions
    execute """
    DO $$
    BEGIN
        -- Only create trigger if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM pg_event_trigger 
            WHERE evtname = 'add_killmail_partition_indexes'
        ) THEN
            CREATE EVENT TRIGGER add_killmail_partition_indexes
            ON ddl_command_end
            WHEN TAG IN ('CREATE TABLE')
            EXECUTE FUNCTION add_unique_index_to_partition();
        END IF;
    END $$;
    """
    
    # Add unique indexes to all existing partitions
    execute """
    DO $$
    DECLARE
        partition_record RECORD;
    BEGIN
        FOR partition_record IN 
            SELECT schemaname, tablename 
            FROM pg_tables 
            WHERE tablename LIKE 'killmails_raw_y%'
        LOOP
            -- Add unique index on killmail_id for each partition
            EXECUTE format(
                'CREATE UNIQUE INDEX IF NOT EXISTS %I ON %I.%I (killmail_id)',
                partition_record.tablename || '_killmail_id_unique',
                partition_record.schemaname,
                partition_record.tablename
            );
            RAISE NOTICE 'Added unique index to partition %.%', 
                partition_record.schemaname, partition_record.tablename;
        END LOOP;
    END $$;
    """
  end
  
  def down do
    # Drop event trigger
    execute "DROP EVENT TRIGGER IF EXISTS add_killmail_partition_indexes"
    
    # Drop function
    execute "DROP FUNCTION IF EXISTS add_unique_index_to_partition()"
    
    # Remove unique indexes from all partitions
    execute """
    DO $$
    DECLARE
        partition_record RECORD;
    BEGIN
        FOR partition_record IN 
            SELECT schemaname, tablename 
            FROM pg_tables 
            WHERE tablename LIKE 'killmails_raw_y%'
        LOOP
            EXECUTE format(
                'DROP INDEX IF EXISTS %I.%I',
                partition_record.schemaname,
                partition_record.tablename || '_killmail_id_unique'
            );
        END LOOP;
    END $$;
    """
  end
end