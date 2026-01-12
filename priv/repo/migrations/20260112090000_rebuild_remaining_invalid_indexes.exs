defmodule EveDmv.Repo.Migrations.RebuildRemainingInvalidIndexes do
  @moduledoc """
  Rebuilds remaining invalid indexes on the participants table.

  Invalid indexes:
  - idx_participants_corp_name_missing (corporation backfill)
  - idx_participants_killmail_corp_backfill (corporation backfill join)
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("SET statement_timeout = 0")

    # 1. Rebuild corp_name_missing index
    execute("DROP INDEX IF EXISTS idx_participants_corp_name_missing")

    execute("""
    CREATE INDEX CONCURRENTLY idx_participants_corp_name_missing
    ON participants (corporation_id, is_victim)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """)

    # 2. Rebuild killmail_corp_backfill index
    execute("DROP INDEX IF EXISTS idx_participants_killmail_corp_backfill")

    execute("""
    CREATE INDEX CONCURRENTLY idx_participants_killmail_corp_backfill
    ON participants (killmail_id, killmail_time, corporation_id)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """)

    execute("ANALYZE participants")
    execute("RESET statement_timeout")
  end

  def down do
    :ok
  end
end
