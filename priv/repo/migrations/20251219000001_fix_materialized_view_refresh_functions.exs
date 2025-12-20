defmodule EveDmv.Repo.Migrations.FixMaterializedViewRefreshFunctions do
  @moduledoc """
  Fixes materialized view refresh functions to support CONCURRENTLY refresh.

  The error "cannot refresh materialized view concurrently" occurs because:
  1. The refresh functions weren't created in the active migrations
  2. A unique index without WHERE clause is required for concurrent refresh

  This migration:
  - Creates unique indexes on materialized views for concurrent refresh support
  - Creates refresh functions with fallback to non-concurrent if concurrent fails
  """

  use Ecto.Migration

  def up do
    # Ensure unique indexes exist for concurrent refresh
    # character_activity_summary needs unique index on character_id
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        WHERE c.relname = 'character_activity_summary'
        AND i.indisunique = true
      ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS character_activity_summary_character_id_unique_idx
        ON character_activity_summary (character_id);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not create unique index on character_activity_summary: %', SQLERRM;
    END $$;
    """

    # corporation_member_summary needs unique index on (corporation_id, character_id)
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_index i
        JOIN pg_class c ON c.oid = i.indrelid
        WHERE c.relname = 'corporation_member_summary'
        AND i.indisunique = true
      ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS corporation_member_summary_corp_char_unique_idx
        ON corporation_member_summary (corporation_id, character_id);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not create unique index on corporation_member_summary: %', SQLERRM;
    END $$;
    """

    # Create refresh_character_activity_summary function with fallback
    execute """
    CREATE OR REPLACE FUNCTION refresh_character_activity_summary()
    RETURNS void AS $$
    BEGIN
      -- Check if view exists
      IF NOT EXISTS (
        SELECT 1 FROM pg_matviews WHERE matviewname = 'character_activity_summary'
      ) THEN
        RAISE NOTICE 'Materialized view character_activity_summary does not exist, skipping refresh';
        RETURN;
      END IF;

      -- Try concurrent refresh first (requires unique index)
      BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY character_activity_summary;
        RAISE NOTICE 'Successfully refreshed character_activity_summary concurrently';
      EXCEPTION WHEN OTHERS THEN
        -- Fall back to non-concurrent refresh
        RAISE NOTICE 'Concurrent refresh failed, falling back to non-concurrent: %', SQLERRM;
        REFRESH MATERIALIZED VIEW character_activity_summary;
        RAISE NOTICE 'Successfully refreshed character_activity_summary (non-concurrent)';
      END;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create refresh_corporation_member_summary function with fallback
    execute """
    CREATE OR REPLACE FUNCTION refresh_corporation_member_summary()
    RETURNS void AS $$
    BEGIN
      -- Check if view exists
      IF NOT EXISTS (
        SELECT 1 FROM pg_matviews WHERE matviewname = 'corporation_member_summary'
      ) THEN
        RAISE NOTICE 'Materialized view corporation_member_summary does not exist, skipping refresh';
        RETURN;
      END IF;

      -- Try concurrent refresh first (requires unique index)
      BEGIN
        REFRESH MATERIALIZED VIEW CONCURRENTLY corporation_member_summary;
        RAISE NOTICE 'Successfully refreshed corporation_member_summary concurrently';
      EXCEPTION WHEN OTHERS THEN
        -- Fall back to non-concurrent refresh
        RAISE NOTICE 'Concurrent refresh failed, falling back to non-concurrent: %', SQLERRM;
        REFRESH MATERIALIZED VIEW corporation_member_summary;
        RAISE NOTICE 'Successfully refreshed corporation_member_summary (non-concurrent)';
      END;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create refresh_all_performance_views function for convenience
    execute """
    CREATE OR REPLACE FUNCTION refresh_all_performance_views()
    RETURNS void AS $$
    BEGIN
      PERFORM refresh_character_activity_summary();
      PERFORM refresh_corporation_member_summary();
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS refresh_all_performance_views();"
    execute "DROP FUNCTION IF EXISTS refresh_corporation_member_summary();"
    execute "DROP FUNCTION IF EXISTS refresh_character_activity_summary();"

    # Note: We don't drop the indexes as they're beneficial for queries
  end
end
