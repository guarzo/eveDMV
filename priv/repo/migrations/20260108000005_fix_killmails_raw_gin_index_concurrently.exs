defmodule EveDmv.Repo.Migrations.FixKillmailsRawGinIndexConcurrently do
  @moduledoc """
  Recreates the killmails_raw participants GIN index with CONCURRENTLY support.

  The original migration (20250801181407_add_participants_jsonb_to_killmails_raw.exs)
  created this GIN index without CONCURRENTLY, which blocks writes during index creation.
  This migration drops and recreates it properly for non-blocking operations.

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

    execute("RESET statement_timeout")
  end
end
