defmodule EveDmv.Repo.Migrations.AddTablePartitioning do
  use Ecto.Migration

  def up do
    # Convert killmails_raw to partitioned table
    # Partitioning by killmail_time improves query performance for time-based queries
    # and enables efficient data archival/deletion of old partitions
    
    # Drop existing indexes - they will be recreated on the partitioned table
    # Indexes on partitioned tables are automatically propagated to child partitions
    execute "DROP INDEX IF EXISTS killmails_raw_killmail_id_index"
    execute "DROP INDEX IF EXISTS killmails_raw_unique_hash_time_index"
    execute "DROP INDEX IF EXISTS killmails_raw_unique_killmail_index"
    
    # Create new partitioned table
    # Using RANGE partitioning on killmail_time for optimal time-series query performance
    # Primary key includes partition key (killmail_time) for proper constraint enforcement
    execute """
    CREATE TABLE killmails_raw_partitioned (
      killmail_id bigint NOT NULL,
      killmail_time timestamp without time zone NOT NULL,
      killmail_hash text NOT NULL,
      solar_system_id bigint NOT NULL,
      victim_character_id bigint,
      victim_corporation_id bigint,
      victim_alliance_id bigint,
      victim_ship_type_id bigint NOT NULL,
      attacker_count bigint NOT NULL DEFAULT 0,
      raw_data jsonb NOT NULL,
      source text NOT NULL DEFAULT 'wanderer-kills',
      inserted_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      PRIMARY KEY (killmail_id, killmail_time)
    ) PARTITION BY RANGE (killmail_time)
    """
    
    # Copy existing data to preserve historical killmails
    execute "INSERT INTO killmails_raw_partitioned SELECT * FROM killmails_raw"
    
    # Drop old table using CASCADE to handle dependent objects
    execute "DROP TABLE killmails_raw CASCADE"
    
    # Rename partitioned table to original name for transparent application usage
    execute "ALTER TABLE killmails_raw_partitioned RENAME TO killmails_raw"
    
    # Recreate indexes on partitioned table
    # These indexes will be automatically created on all child partitions
    execute "CREATE UNIQUE INDEX killmails_raw_unique_hash_time_index ON killmails_raw (killmail_hash, killmail_time)"
    execute "CREATE UNIQUE INDEX killmails_raw_unique_killmail_index ON killmails_raw (killmail_id, killmail_time)"
    execute "CREATE INDEX killmails_raw_killmail_id_index ON killmails_raw (killmail_id)"

    # Convert killmails_enriched to partitioned table
    # This table contains processed killmail data with names resolved and values calculated
    
    # Create new partitioned table with same structure as original
    # Partitioning enables efficient queries on recent data and easy archival
    execute """
    CREATE TABLE killmails_enriched_partitioned (
      killmail_id bigint NOT NULL,
      killmail_time timestamp without time zone NOT NULL,
      victim_character_id bigint,
      victim_character_name text,
      victim_corporation_id bigint,
      victim_corporation_name text,
      victim_alliance_id bigint,
      victim_alliance_name text,
      solar_system_id bigint NOT NULL,
      solar_system_name text,
      victim_ship_type_id bigint NOT NULL,
      victim_ship_name text,
      total_value numeric(15,2),
      ship_value numeric(15,2),
      fitted_value numeric(15,2),
      attacker_count bigint DEFAULT 0 NOT NULL,
      final_blow_character_id bigint,
      final_blow_character_name text,
      kill_category text,
      victim_ship_category text,
      module_tags text[] DEFAULT ARRAY[]::text[],
      noteworthy_modules text[] DEFAULT ARRAY[]::text[],
      enriched_at timestamp without time zone,
      price_data_source text,
      inserted_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      updated_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      PRIMARY KEY (killmail_id, killmail_time)
    ) PARTITION BY RANGE (killmail_time)
    """
    
    # Migrate existing enriched data to preserve intelligence history
    execute "INSERT INTO killmails_enriched_partitioned SELECT * FROM killmails_enriched"
    
    # Drop old table with CASCADE to handle dependent views/functions
    execute "DROP TABLE killmails_enriched CASCADE"
    
    # Rename to maintain compatibility with existing queries
    execute "ALTER TABLE killmails_enriched_partitioned RENAME TO killmails_enriched"
    
    # Recreate all performance-critical indexes
    # Unique constraint on killmail_id with partition key
    execute "CREATE UNIQUE INDEX killmails_enriched_unique_killmail_index ON killmails_enriched (killmail_id, killmail_time)"
    # Value-based filtering for high-value kill detection
    execute "CREATE INDEX killmails_enriched_value_idx ON killmails_enriched (total_value)"
    # Location-based queries for system activity
    execute "CREATE INDEX killmails_enriched_system_idx ON killmails_enriched (solar_system_id)"
    # Alliance warfare tracking
    execute "CREATE INDEX killmails_enriched_victim_alliance_idx ON killmails_enriched (victim_alliance_id)"
    # Corporation member loss tracking
    execute "CREATE INDEX killmails_enriched_victim_corp_idx ON killmails_enriched (victim_corporation_id)"
    # Individual pilot activity tracking
    execute "CREATE INDEX killmails_enriched_victim_character_idx ON killmails_enriched (victim_character_id)"
    # Time-based queries for activity feeds
    execute "CREATE INDEX killmails_enriched_time_idx ON killmails_enriched (killmail_time)"
    # Composite indexes for common query patterns
    execute "CREATE INDEX killmails_enriched_killmail_time_total_value_index ON killmails_enriched (killmail_time, total_value)"
    execute "CREATE INDEX killmails_enriched_solar_system_id_killmail_time_index ON killmails_enriched (solar_system_id, killmail_time)"
    execute "CREATE INDEX killmails_enriched_victim_character_id_killmail_time_index ON killmails_enriched (victim_character_id, killmail_time)"
    # Partial index for expensive kills (>100M ISK)
    execute "CREATE INDEX killmails_enriched_killmail_time_index ON killmails_enriched (killmail_time) WHERE total_value > 100000000"
    # Expression index for epoch-based time calculations
    execute "CREATE INDEX killmails_enriched_timestamp_epoch_idx ON killmails_enriched (EXTRACT(EPOCH FROM killmail_time))"
    # GIN index for fast module/fitting searches
    execute "CREATE INDEX killmails_enriched_module_tags_index ON killmails_enriched USING gin (module_tags)"

    # Create initial partitions for current and next few months
    # Partitions are created monthly to balance query performance and maintenance overhead
    
    # Create partitions for killmails_raw - January through March 2025
    # Each partition holds one month of raw killmail data
    execute """
    CREATE TABLE IF NOT EXISTS killmails_raw_2025_01 PARTITION OF killmails_raw
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01')
    """
    
    execute """
    CREATE TABLE IF NOT EXISTS killmails_raw_2025_02 PARTITION OF killmails_raw
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01')
    """
    
    execute """
    CREATE TABLE IF NOT EXISTS killmails_raw_2025_03 PARTITION OF killmails_raw
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01')
    """
    
    # Create matching partitions for killmails_enriched
    # Ensures enriched data is partitioned identically to raw data
    execute """
    CREATE TABLE IF NOT EXISTS killmails_enriched_2025_01 PARTITION OF killmails_enriched
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01')
    """
    
    execute """
    CREATE TABLE IF NOT EXISTS killmails_enriched_2025_02 PARTITION OF killmails_enriched
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01')
    """
    
    execute """
    CREATE TABLE IF NOT EXISTS killmails_enriched_2025_03 PARTITION OF killmails_enriched
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01')
    """
    
    # Create a function to automatically create monthly partitions
    # This utility function simplifies partition management and prevents gaps
    execute """
    CREATE OR REPLACE FUNCTION create_monthly_partitions(table_name text, start_date date, num_months int)
    RETURNS void AS $$
    DECLARE
        partition_date date;
        partition_name text;
        i int;
    BEGIN
        FOR i IN 0..num_months-1 LOOP
            partition_date := start_date + (i || ' months')::interval;
            partition_name := table_name || '_' || to_char(partition_date, 'YYYY_MM');
            
            -- Check if partition already exists to avoid errors
            IF NOT EXISTS (
                SELECT 1 FROM pg_class c
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relname = partition_name
                AND n.nspname = 'public'
            ) THEN
                EXECUTE format('CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
                    partition_name,
                    table_name,
                    partition_date,
                    partition_date + interval '1 month'
                );
                RAISE NOTICE 'Created partition % for table %', partition_name, table_name;
            END IF;
        END LOOP;
    END;
    $$ LANGUAGE plpgsql
    """
    
    # Create a maintenance function to ensure partitions exist for next 3 months
    # Should be called periodically (e.g., via cron or scheduled job) to create partitions ahead of time
    # This prevents INSERT failures when new months begin
    execute """
    CREATE OR REPLACE FUNCTION maintain_partitions()
    RETURNS void AS $$
    BEGIN
        -- Create partitions for next 3 months for both tables
        -- This ensures smooth operation across month boundaries
        PERFORM create_monthly_partitions('killmails_raw', date_trunc('month', CURRENT_DATE), 3);
        PERFORM create_monthly_partitions('killmails_enriched', date_trunc('month', CURRENT_DATE), 3);
    END;
    $$ LANGUAGE plpgsql
    """
  end

  def down do
    # Note: This is a destructive operation and would lose partition structure
    # All data from partitions will be consolidated into regular tables
    
    # Drop partition maintenance functions
    execute "DROP FUNCTION IF EXISTS maintain_partitions()"
    execute "DROP FUNCTION IF EXISTS create_monthly_partitions(text, date, int)"
    
    # Convert killmails_raw back to regular table
    # This consolidates all partition data into a single table
    execute "CREATE TABLE killmails_raw_regular AS SELECT * FROM killmails_raw"
    execute "DROP TABLE killmails_raw CASCADE"
    execute "ALTER TABLE killmails_raw_regular RENAME TO killmails_raw"
    
    # Recreate indexes on regular table
    execute "CREATE UNIQUE INDEX killmails_raw_unique_hash_time_index ON killmails_raw (killmail_hash, killmail_time)"
    execute "CREATE UNIQUE INDEX killmails_raw_unique_killmail_index ON killmails_raw (killmail_id, killmail_time)"
    execute "CREATE INDEX killmails_raw_killmail_id_index ON killmails_raw (killmail_id)"
    
    # Convert killmails_enriched back to regular table
    # This consolidates all partition data into a single table
    execute "CREATE TABLE killmails_enriched_regular AS SELECT * FROM killmails_enriched"
    execute "DROP TABLE killmails_enriched CASCADE"
    execute "ALTER TABLE killmails_enriched_regular RENAME TO killmails_enriched"
    
    # Recreate basic indexes on regular table
    # Note: Not all indexes from up() are recreated to match original schema
    execute "CREATE UNIQUE INDEX killmails_enriched_unique_killmail_index ON killmails_enriched (killmail_id, killmail_time)"
    execute "CREATE INDEX killmails_enriched_value_idx ON killmails_enriched (total_value)"
    execute "CREATE INDEX killmails_enriched_system_idx ON killmails_enriched (solar_system_id)"
    execute "CREATE INDEX killmails_enriched_victim_alliance_idx ON killmails_enriched (victim_alliance_id)"
    execute "CREATE INDEX killmails_enriched_victim_corp_idx ON killmails_enriched (victim_corporation_id)"
    execute "CREATE INDEX killmails_enriched_victim_character_idx ON killmails_enriched (victim_character_id)"
    execute "CREATE INDEX killmails_enriched_time_idx ON killmails_enriched (killmail_time)"
  end
end