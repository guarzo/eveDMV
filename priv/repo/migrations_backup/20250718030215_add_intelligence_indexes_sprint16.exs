defmodule EveDmv.Repo.Migrations.AddIntelligenceIndexesSprint16 do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    # Use regular indexes for test environment, concurrent for others
    concurrently = if Mix.env() == :test, do: "", else: "CONCURRENTLY"
    
    # Critical GIN index for JSONB attacker queries in threat scoring
    # This dramatically improves performance when searching for character_ids in raw_data attackers array
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_raw_attackers_gin
    ON killmails_raw USING GIN ((raw_data -> 'attackers'))
    """

    # Composite index for time-based intelligence queries with character filtering
    # Optimizes the victim_character_id + killmail_time queries used in threat scoring
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_time_victim_char
    ON killmails_raw (killmail_time, victim_character_id)
    """

    # Index for recent activity analysis
    # Note: Using a fixed date instead of NOW() to avoid IMMUTABLE function requirement
    # This index will need periodic recreation for optimal performance
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_recent_intelligence
    ON killmails_raw (killmail_time DESC, victim_character_id)
    WHERE killmail_time >= '2024-01-01'::timestamp
    """
  end

  def down do
    # Use regular drop for test environment, concurrent for others
    concurrently = if Mix.env() == :test, do: "", else: "CONCURRENTLY"
    
    # Drop the GIN indexes
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_raw_attackers_gin"
    
    # Drop the composite and partial indexes
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_time_victim_char"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_recent_intelligence"
  end
end