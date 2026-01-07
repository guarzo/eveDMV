defmodule EveDmv.Repo.Migrations.AddParticipantsCorpNameMissingIndex do
  @moduledoc """
  Adds a partial index on participants table for efficient corporation name backfill queries.

  This index covers the common query pattern used by CorporationNameBackfill:
  - Find participants where corporation_id is set but corporation_name is missing
  - Grouped by corporation_id and is_victim

  Using a partial index dramatically reduces index size and improves query performance
  since we only index rows that need backfilling.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Create partial index for finding participants with missing corporation names
    # This is used by CorporationNameBackfill to efficiently find killmails to update
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_corp_name_missing
    ON participants (corporation_id, is_victim)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """

    # Also add an index to help with the killmails_raw join
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_killmail_corp_backfill
    ON participants (killmail_id, killmail_time, corporation_id)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """
  end

  def down do
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_participants_corp_name_missing"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_participants_killmail_corp_backfill"
  end
end
