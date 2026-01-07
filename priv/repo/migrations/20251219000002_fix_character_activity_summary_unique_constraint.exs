defmodule EveDmv.Repo.Migrations.FixCharacterActivitySummaryUniqueConstraint do
  @moduledoc """
  Fixes the character_activity_summary materialized view to ensure unique character_ids.

  The original view grouped by (character_id, character_name), which causes duplicates
  when a character changes their name. This migration:

  1. Drops the existing view
  2. Recreates it with GROUP BY only on character_id (using MAX for character_name)
  3. Creates a proper UNIQUE index for concurrent refresh support

  This enables REFRESH MATERIALIZED VIEW CONCURRENTLY which doesn't block read queries.
  """

  use Ecto.Migration

  # Disable migration lock timeout for long-running operations
  @disable_migration_lock true
  @disable_ddl_transaction true

  def up do
    # Disable statement timeout for this migration (materialized view creation on large tables)
    execute "SET statement_timeout = 0;"
    # Drop existing indexes first
    execute """
    DROP INDEX IF EXISTS character_activity_summary_character_id_idx;
    """

    execute """
    DROP INDEX IF EXISTS character_activity_summary_total_kills_idx;
    """

    execute """
    DROP INDEX IF EXISTS character_activity_summary_last_activity_idx;
    """

    execute """
    DROP INDEX IF EXISTS character_activity_summary_character_id_unique_idx;
    """

    # Drop and recreate the materialized view with correct grouping
    execute """
    DROP MATERIALIZED VIEW IF EXISTS character_activity_summary;
    """

    # Recreate with GROUP BY only on character_id
    # Use MAX(character_name) to get the most recent name
    execute """
    CREATE MATERIALIZED VIEW character_activity_summary AS
    SELECT
      p.character_id,
      MAX(p.character_name) as character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as total_kills,
      COUNT(*) FILTER (WHERE p.is_victim = true) as total_losses,
      MAX(k.killmail_time) as last_activity,
      COUNT(DISTINCT k.solar_system_id) as unique_systems,
      COUNT(DISTINCT p.ship_type_id) as unique_ships_flown
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.character_id IS NOT NULL
    GROUP BY p.character_id
    WITH DATA;
    """

    # Create UNIQUE index first (required for concurrent refresh)
    execute """
    CREATE UNIQUE INDEX character_activity_summary_character_id_unique_idx
    ON character_activity_summary (character_id);
    """

    # Create other useful indexes
    execute """
    CREATE INDEX character_activity_summary_total_kills_idx
    ON character_activity_summary (total_kills DESC);
    """

    execute """
    CREATE INDEX character_activity_summary_last_activity_idx
    ON character_activity_summary (last_activity DESC);
    """

    # Reset statement timeout
    execute "RESET statement_timeout;"
  end

  def down do
    # Disable statement timeout for this migration
    execute "SET statement_timeout = 0;"
    # Drop indexes
    execute "DROP INDEX IF EXISTS character_activity_summary_last_activity_idx;"
    execute "DROP INDEX IF EXISTS character_activity_summary_total_kills_idx;"
    execute "DROP INDEX IF EXISTS character_activity_summary_character_id_unique_idx;"

    # Drop and recreate original view
    execute "DROP MATERIALIZED VIEW IF EXISTS character_activity_summary;"

    # Recreate original view (grouped by character_id, character_name)
    execute """
    CREATE MATERIALIZED VIEW character_activity_summary AS
    SELECT
      p.character_id,
      p.character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as total_kills,
      COUNT(*) FILTER (WHERE p.is_victim = true) as total_losses,
      MAX(k.killmail_time) as last_activity,
      COUNT(DISTINCT k.solar_system_id) as unique_systems,
      COUNT(DISTINCT p.ship_type_id) as unique_ships_flown
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    GROUP BY p.character_id, p.character_name
    WITH DATA;
    """

    # Recreate original indexes
    execute "CREATE INDEX character_activity_summary_character_id_idx ON character_activity_summary (character_id);"
    execute "CREATE INDEX character_activity_summary_total_kills_idx ON character_activity_summary (total_kills DESC);"
    execute "CREATE INDEX character_activity_summary_last_activity_idx ON character_activity_summary (last_activity DESC);"

    # Reset statement timeout
    execute "RESET statement_timeout;"
  end
end
