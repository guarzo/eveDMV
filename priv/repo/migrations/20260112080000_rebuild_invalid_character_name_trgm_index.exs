defmodule EveDmv.Repo.Migrations.RebuildInvalidCharacterNameTrgmIndex do
  @moduledoc """
  Rebuilds the invalid idx_participants_character_name_trgm index.

  The original index creation failed partway through, leaving the index in an
  invalid state (indisvalid = false). This migration drops and recreates it.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Disable statement timeout for index operations on large tables
    execute("SET statement_timeout = 0")

    # Drop the invalid index
    execute("DROP INDEX IF EXISTS idx_participants_character_name_trgm")

    # Recreate the index concurrently (won't lock table)
    execute("""
    CREATE INDEX CONCURRENTLY idx_participants_character_name_trgm
    ON participants USING gin (character_name gin_trgm_ops)
    WHERE character_name IS NOT NULL
    """)

    # Restore default statement timeout
    execute("RESET statement_timeout")
  end

  def down do
    # Nothing to do - the original migration handles this index
    :ok
  end
end
