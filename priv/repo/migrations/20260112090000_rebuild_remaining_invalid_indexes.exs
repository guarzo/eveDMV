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

    # 1. Rebuild corp_name_missing index using REINDEX CONCURRENTLY if it exists,
    #    otherwise CREATE INDEX CONCURRENTLY. REINDEX minimizes locking compared
    #    to DROP+CREATE by not removing the index during rebuild.
    #
    #    Note: REINDEX/CREATE INDEX CONCURRENTLY cannot run inside PL/pgSQL blocks,
    #    so we check index existence via Ecto first.
    rebuild_index_concurrently(
      "idx_participants_corp_name_missing",
      """
      CREATE INDEX CONCURRENTLY idx_participants_corp_name_missing
      ON participants (corporation_id, is_victim)
      WHERE corporation_id IS NOT NULL
        AND (corporation_name IS NULL OR corporation_name = '')
      """
    )

    # 2. Rebuild killmail_corp_backfill index using same pattern
    rebuild_index_concurrently(
      "idx_participants_killmail_corp_backfill",
      """
      CREATE INDEX CONCURRENTLY idx_participants_killmail_corp_backfill
      ON participants (killmail_id, killmail_time, corporation_id)
      WHERE corporation_id IS NOT NULL
        AND (corporation_name IS NULL OR corporation_name = '')
      """
    )

    execute("ANALYZE participants")
    execute("RESET statement_timeout")
  end

  # Helper to conditionally REINDEX or CREATE an index.
  # Uses REINDEX CONCURRENTLY when the index exists (minimizes locking),
  # falls back to CREATE INDEX CONCURRENTLY when the index is absent.
  defp rebuild_index_concurrently(index_name, create_sql) do
    case repo().query("SELECT 1 FROM pg_indexes WHERE indexname = $1", [index_name]) do
      {:ok, %{num_rows: n}} when n > 0 ->
        # Index exists - use REINDEX CONCURRENTLY for minimal locking
        execute("REINDEX INDEX CONCURRENTLY #{index_name}")

      _ ->
        # Index doesn't exist - create it
        execute(create_sql)
    end
  end

  # No rollback required for this migration. Rebuilding indexes is a forward-only
  # operation that corrects invalid index state. Rolling back would either leave
  # the indexes in their rebuilt (valid) state, which is harmless, or attempt to
  # restore invalid indexes, which is undesirable. The :ok return indicates this
  # is intentionally a no-op rather than an oversight.
  def down do
    :ok
  end
end
