defmodule EveDmv.Repo.Migrations.AddParticipantsPerformanceIndexes do
  @moduledoc """
  Adds performance indexes to the participants table for commonly slow query patterns.

  Issues addressed:
  1. GROUP BY ship usage queries - character_stats, ship preference analysis
  2. Window functions in battle detection - PARTITION BY solar_system_id, hour
  3. Alliance-wide aggregations - COUNT(DISTINCT killmail_id) for alliance stats
  4. Corporation name backfill - DISTINCT corporation_id WHERE name is missing
  5. Gang synergy analysis - ANY(character_ids) with is_victim filter

  All indexes are created CONCURRENTLY to avoid locking the table in production.
  Statement timeout is disabled to allow index creation on large tables.
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Disable statement timeout for concurrent index creation on large tables
    execute("SET statement_timeout = 0")

    # 1. Support GROUP BY ship usage queries (character_stats.ex, participant.ex)
    # Query pattern: GROUP BY ship_type_id, ship_name WHERE character_id = $1
    # Used by: Ship preference analysis, character intelligence
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_character_ship
    ON participants (character_id, ship_type_id, ship_name, killmail_time)
    WHERE character_id IS NOT NULL
    """)

    # 2. Support window functions in battle detection (detection_service.ex)
    # Query pattern: PARTITION BY solar_system_id, date_trunc('hour', killmail_time)
    # Used by: Battle clustering, activity pattern detection
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_character_system_time
    ON participants (character_id, solar_system_id, killmail_time)
    WHERE character_id IS NOT NULL
    """)

    # 3. Support alliance-wide aggregations (unified_repository.ex)
    # Query pattern: COUNT(DISTINCT killmail_id) WHERE alliance_id = $1
    # Used by: Alliance stats, coalition analysis
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_alliance_killmail
    ON participants (alliance_id, killmail_time, killmail_id)
    WHERE alliance_id IS NOT NULL
    """)

    # 4. Support corporation name backfill (corporation_name_backfill.ex)
    # Query pattern: DISTINCT corporation_id WHERE corporation_name IS NULL OR = ''
    # Used by: Maintenance jobs that populate missing corporation names
    # Partial index keeps it small - only rows needing backfill
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_corp_missing_name
    ON participants (corporation_id)
    WHERE corporation_id IS NOT NULL
      AND (corporation_name IS NULL OR corporation_name = '')
    """)

    # 5. Support gang synergy analysis (gang_synergy_analyzer.ex)
    # Query pattern: WHERE character_id = ANY($1) AND is_victim = false
    # Used by: Gang synergy detection, fleet composition analysis
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_gang_analysis
    ON participants (character_id, is_victim, killmail_time, killmail_id)
    WHERE character_id IS NOT NULL
    """)

    # 6. Support corporation-wide queries (corporation analysis)
    # Query pattern: WHERE corporation_id = $1 GROUP BY character_id
    # Used by: Corporation member analysis, timezone detection
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_corporation_member
    ON participants (corporation_id, character_id, killmail_time)
    WHERE corporation_id IS NOT NULL
    """)

    # Restore default statement timeout
    execute("RESET statement_timeout")
  end

  def down do
    execute("SET statement_timeout = 0")

    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_character_ship")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_character_system_time")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_alliance_killmail")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_corp_missing_name")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_gang_analysis")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_corporation_member")

    execute("RESET statement_timeout")
  end
end
