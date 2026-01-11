defmodule EveDmv.Repo.Migrations.AddParticipantsTrigramIndexes do
  @moduledoc """
  Adds GIN trigram indexes on participants table for efficient ILIKE searches.

  The participants table is frequently searched by character_name and corporation_name
  using ILIKE with wildcards (e.g., WHERE character_name ILIKE '%query%'). These patterns
  require trigram indexes (pg_trgm) to avoid full table scans.

  Without these indexes, ILIKE queries take 100-110ms and cause connection pool exhaustion.
  With trigram indexes, the same queries should complete in <10ms.

  Query patterns being optimized:
  - home_live.ex: SELECT ... FROM participants WHERE character_name ILIKE $1
  - home_live.ex: SELECT ... FROM participants WHERE corporation_name ILIKE $1
  - search_component.ex: Similar ILIKE queries on both columns
  - participant.ex Ash resource: search_characters_by_name, search_corporations_by_name
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Disable statement timeout for concurrent index creation
    execute "SET statement_timeout = 0"

    # Create GIN trigram index on character_name for ILIKE searches
    # GIN is preferred over GIST for trigram indexes when the column is updated infrequently
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_character_name_trgm
    ON participants USING gin (character_name gin_trgm_ops)
    WHERE character_name IS NOT NULL
    """

    # Create GIN trigram index on corporation_name for ILIKE searches
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_corporation_name_trgm
    ON participants USING gin (corporation_name gin_trgm_ops)
    WHERE corporation_name IS NOT NULL
    """

    # Restore default statement timeout
    execute "RESET statement_timeout"
  end

  def down do
    execute "SET statement_timeout = 0"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_participants_character_name_trgm"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_participants_corporation_name_trgm"
    execute "RESET statement_timeout"
  end
end
