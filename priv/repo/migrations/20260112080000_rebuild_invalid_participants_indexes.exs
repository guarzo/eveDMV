defmodule EveDmv.Repo.Migrations.RebuildInvalidParticipantsIndexes do
  @moduledoc """
  Rebuilds invalid indexes on the participants table.

  Multiple CONCURRENTLY index creations failed partway through, leaving indexes
  in an invalid state (indisvalid = false). This migration drops and recreates them.

  Invalid indexes found:
  - idx_participants_character_name_trgm (trigram search)
  - idx_participants_corp_name_missing (corporation backfill)
  - idx_participants_killmail_corp_backfill (corporation backfill join)
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Disable statement timeout for index operations on large tables
    execute("SET statement_timeout = 0")

    # 1. Rebuild character_name trigram index
    execute("DROP INDEX IF EXISTS idx_participants_character_name_trgm")

    execute("""
    CREATE INDEX CONCURRENTLY idx_participants_character_name_trgm
    ON participants USING gin (character_name gin_trgm_ops)
    WHERE character_name IS NOT NULL
    """)

    # 2. Rebuild corp_name_missing index (for backfill queries)
    execute("DROP INDEX IF EXISTS idx_participants_corp_name_missing")

    execute("""
    CREATE INDEX CONCURRENTLY idx_participants_corp_name_missing
    ON participants (corporation_id, is_victim)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """)

    # 3. Rebuild killmail_corp_backfill index (for backfill joins)
    execute("DROP INDEX IF EXISTS idx_participants_killmail_corp_backfill")

    execute("""
    CREATE INDEX CONCURRENTLY idx_participants_killmail_corp_backfill
    ON participants (killmail_id, killmail_time, corporation_id)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """)

    # Update statistics after index creation
    execute("ANALYZE participants")

    # Restore default statement timeout
    execute("RESET statement_timeout")
  end

  def down do
    # Nothing to do - the original migrations handle these indexes
    :ok
  end
end
