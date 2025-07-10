defmodule EveDmv.Repo.Migrations.DropEnrichedKillmailsTable do
  use Ecto.Migration

  def up do
    # Drop dependent materialized views first
    execute "DROP MATERIALIZED VIEW IF EXISTS alliance_statistics CASCADE"
    execute "DROP MATERIALIZED VIEW IF EXISTS daily_killmail_summary CASCADE"
    execute "DROP MATERIALIZED VIEW IF EXISTS top_hunters_summary CASCADE"
    
    # Drop all indexes
    drop_if_exists index(:killmails_enriched, [:killmail_time])
    drop_if_exists index(:killmails_enriched, [:victim_character_id])
    drop_if_exists index(:killmails_enriched, [:victim_corporation_id])
    drop_if_exists index(:killmails_enriched, [:victim_alliance_id])
    drop_if_exists index(:killmails_enriched, [:solar_system_id])
    drop_if_exists index(:killmails_enriched, [:total_value])
    
    # Drop the table with CASCADE to handle any other dependencies
    execute "DROP TABLE IF EXISTS killmails_enriched CASCADE"
    
    execute """
    -- Drop any partitions that might exist
    DO $$
    DECLARE
      partition_name text;
    BEGIN
      FOR partition_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename LIKE 'killmails_enriched_%'
      LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', partition_name);
      END LOOP;
    END $$;
    """
  end

  def down do
    # We don't support rolling back - enriched table is permanently removed
    # See /docs/architecture/enriched-raw-analysis.md for rationale
    raise "Cannot rollback removal of enriched killmails table - it has been permanently removed from the architecture"
  end
end
