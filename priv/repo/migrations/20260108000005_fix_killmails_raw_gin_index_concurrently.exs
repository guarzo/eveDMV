defmodule EveDmv.Repo.Migrations.FixKillmailsRawGinIndexConcurrently do
  @moduledoc """
  Recreates the killmails_raw participants GIN index.

  ## PostgreSQL CONCURRENTLY Limitation on Partitioned Tables

  PostgreSQL does not support CREATE INDEX CONCURRENTLY on partitioned tables.
  When you attempt to use CONCURRENTLY on a partitioned table, PostgreSQL raises
  an error: "cannot create index on partitioned table concurrently". This is a
  fundamental PostgreSQL limitation because CONCURRENTLY requires building the
  index in a single transaction across all partitions, which conflicts with the
  non-blocking nature of concurrent index creation.

  As a result, this index creation will acquire an exclusive lock and block
  writes to the table during the operation.

  ## @disable_ddl_transaction true Mechanism

  Setting `@disable_ddl_transaction true` prevents Ecto from wrapping the
  migration in a database transaction. This is required here for two reasons:

  1. **Statement timeout control**: We need to SET statement_timeout = 0 to
     prevent the index creation from timing out on large tables. This setting
     must persist across multiple statements, which requires being outside a
     transaction that might be rolled back.

  2. **Migration lock independence**: Combined with `@disable_migration_lock true`,
     this allows other migrations or database operations to proceed without
     waiting for the advisory lock that Ecto normally holds during migrations.

  Note: While @disable_ddl_transaction is often used WITH CONCURRENTLY (since
  concurrent operations cannot run inside transactions), here we use it purely
  for timeout control since CONCURRENTLY is not available for partitioned tables.

  ## Affected Index

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
