defmodule EveDmv.Repo.Migrations.AddPerformanceIndexesStream6 do
  @moduledoc """
  Performance indexes from Stream 6 of the Performance Improvement Plan.

  These indexes address specific query patterns identified during performance analysis:
  - Battle killmail lookups by battle_id
  - Participant queries with covering indexes
  - Corporation activity with final blow filtering
  - System activity with ship type filtering
  - Historical fetch status lookups
  - API key lookups by character
  - High-value recent killmails partial index
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Disable statement timeout for concurrent index creation
    execute("SET statement_timeout = 0")

    # Battle killmail lookups - single column index for battle_id
    # The unique index on (battle_id, killmail_id) exists but a dedicated battle_id
    # index improves lookups when only filtering by battle_id
    create_if_not_exists(
      index(:battle_killmails, [:battle_id],
        name: :idx_battle_killmails_battle_id,
        concurrently: true
      )
    )

    # Participant character lookups with covering index
    # Uses PostgreSQL INCLUDE for covering index to avoid heap lookups
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_char_time_covering
    ON participants (character_id, killmail_time)
    INCLUDE (ship_type_id, corporation_id, damage_done)
    """)

    # Corporation activity queries with final blow
    # Optimizes CorporationLive queries that filter by corporation and final blow
    create_if_not_exists(
      index(:participants, [:corporation_id, :killmail_time, :final_blow],
        name: :idx_participants_corp_time_final,
        concurrently: true
      )
    )

    # System activity queries with ship type (used in SystemLive heatmaps)
    # Extends the existing system_time index to include ship type for covering
    # For partitioned tables, the index is created on each partition automatically
    create_if_not_exists(
      index(:killmails_raw, [:solar_system_id, :killmail_time, :victim_ship_type_id],
        name: :idx_killmails_system_time_ship,
        concurrently: true
      )
    )

    # Historical fetch status lookups - composite for efficient status checks
    # Complements the existing unique index on (entity_type, entity_id)
    create_if_not_exists(
      index(:historical_fetch_status, [:entity_type, :entity_id, :status],
        name: :idx_historical_fetch_entity_status,
        concurrently: true
      )
    )

    # API key lookups by character with active filter
    # Optimizes API key validation where we check character and active status
    create_if_not_exists(
      index(:api_keys, [:character_id, :is_active],
        name: :idx_api_keys_character_active,
        concurrently: true,
        where: "is_active = true"
      )
    )

    # Index for high-value killmails (used in dashboards)
    # Raw SQL required: partial index with WHERE clause on partitioned table
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_killmails_high_value
    ON killmails_raw (total_value DESC, killmail_time DESC)
    WHERE total_value > 100000000
    """)

    # Restore default statement timeout
    execute("RESET statement_timeout")
  end

  def down do
    execute("SET statement_timeout = 0")

    drop_if_exists(index(:battle_killmails, [:battle_id], name: :idx_battle_killmails_battle_id))

    # Raw SQL required: index was created with PostgreSQL INCLUDE clause for covering index,
    # which is not supported by Ecto's index macro
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_participants_char_time_covering")

    drop_if_exists(
      index(:participants, [:corporation_id, :killmail_time, :final_blow],
        name: :idx_participants_corp_time_final
      )
    )

    # Raw SQL required: Ecto's drop_if_exists doesn't support CONCURRENTLY option
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_system_time_ship")

    drop_if_exists(
      index(:historical_fetch_status, [:entity_type, :entity_id, :status],
        name: :idx_historical_fetch_entity_status
      )
    )

    drop_if_exists(
      index(:api_keys, [:character_id, :is_active], name: :idx_api_keys_character_active)
    )

    # Raw SQL required: Ecto's drop_if_exists doesn't support CONCURRENTLY option
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_high_value")

    execute("RESET statement_timeout")
  end
end
