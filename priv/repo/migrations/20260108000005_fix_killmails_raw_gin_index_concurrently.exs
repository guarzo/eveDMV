defmodule EveDmv.Repo.Migrations.FixKillmailsRawGinIndexConcurrently do
  @moduledoc """
  Recreates the killmails_raw participants GIN index.

  Note: PostgreSQL CONCURRENTLY cannot be used on partitioned tables, so this
  index creation will block writes during the operation. The migration disables
  DDL transaction and migration lock to allow other operations to proceed, and
  sets statement_timeout to 0 to prevent timeouts on large tables.

  Affected index:
  - killmails_raw_participants_gin_idx
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("SET statement_timeout = 0")

    # Drop existing GIN index
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    execute("DROP INDEX IF EXISTS killmails_raw_participants_gin_idx")

    # Recreate GIN index
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    execute("""
    CREATE INDEX IF NOT EXISTS killmails_raw_participants_gin_idx
    ON killmails_raw USING GIN (participants)
    """)

    execute("RESET statement_timeout")
  end

  def down do
    execute("SET statement_timeout = 0")

    # Drop GIN index
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    execute("DROP INDEX IF EXISTS killmails_raw_participants_gin_idx")

    # Recreate the original GIN index to restore state on rollback
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    execute("""
    CREATE INDEX IF NOT EXISTS killmails_raw_participants_gin_idx
    ON killmails_raw USING GIN (participants)
    """)

    execute("RESET statement_timeout")
  end
end
