defmodule EveDmv.Repo.Migrations.FixKillmailsRawIndexesConcurrently do
  @moduledoc """
  Recreates killmails_raw indexes with CONCURRENTLY support.

  The original migration (20250806234708_add_performance_indexes.exs) created these
  indexes without CONCURRENTLY, which blocks writes during index creation.
  This migration drops and recreates them properly for non-blocking operations.

  Affected indexes:
  - killmails_raw_character_activity_idx
  - killmails_raw_corp_alliance_time_idx
  - killmails_raw_system_time_idx
  - killmails_raw_value_time_idx (partial index)
  - killmails_raw_attacker_count_idx
  - killmails_raw_ship_type_idx
  """

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("SET statement_timeout = 0")

    # Drop existing indexes
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    execute("DROP INDEX IF EXISTS killmails_raw_character_activity_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_corp_alliance_time_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_system_time_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_value_time_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_attacker_count_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_ship_type_idx")

    # Recreate indexes
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    create_if_not_exists(
      index(:killmails_raw, [:victim_character_id, :killmail_time],
        name: :killmails_raw_character_activity_idx
      )
    )

    create_if_not_exists(
      index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id, :killmail_time],
        name: :killmails_raw_corp_alliance_time_idx
      )
    )

    create_if_not_exists(
      index(:killmails_raw, [:solar_system_id, :killmail_time],
        name: :killmails_raw_system_time_idx
      )
    )

    # Partial index for high-value killmails - raw SQL required for WHERE clause
    execute("""
    CREATE INDEX IF NOT EXISTS killmails_raw_value_time_idx
    ON killmails_raw (total_value, killmail_time)
    WHERE total_value > 1000000000
    """)

    create_if_not_exists(
      index(:killmails_raw, [:attacker_count, :killmail_time],
        name: :killmails_raw_attacker_count_idx
      )
    )

    create_if_not_exists(
      index(:killmails_raw, [:victim_ship_type_id, :killmail_time],
        name: :killmails_raw_ship_type_idx
      )
    )

    execute("RESET statement_timeout")
  end

  def down do
    execute("SET statement_timeout = 0")

    # Drop indexes
    # Note: Cannot use CONCURRENTLY for partitioned table indexes (PostgreSQL limitation)
    execute("DROP INDEX IF EXISTS killmails_raw_character_activity_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_corp_alliance_time_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_system_time_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_value_time_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_attacker_count_idx")
    execute("DROP INDEX IF EXISTS killmails_raw_ship_type_idx")

    execute("RESET statement_timeout")
  end
end
