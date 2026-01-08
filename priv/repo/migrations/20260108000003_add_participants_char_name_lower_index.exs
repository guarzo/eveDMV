defmodule EveDmv.Repo.Migrations.AddParticipantsCharNameLowerIndex do
  @moduledoc """
  Adds a functional index on LOWER(character_name) to speed up case-insensitive
  character name searches in SearchSuggestionService.get_character_suggestions_from_participants/2.

  The query pattern being optimized:
    WHERE p.character_name IS NOT NULL
      AND LOWER(p.character_name) LIKE $1

  This index allows the query planner to use index seeks instead of full table scans.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute "SET statement_timeout TO 0"

    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_char_name_lower
    ON participants (LOWER(character_name))
    WHERE character_name IS NOT NULL
    """

    execute "RESET statement_timeout"
  end

  def down do
    execute """
    DROP INDEX CONCURRENTLY IF EXISTS idx_participants_char_name_lower
    """
  end
end
