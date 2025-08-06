defmodule EveDmv.Repo.Migrations.ConsolidateRedundantIndexes do
  use Ecto.Migration
  require Logger

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Find and drop redundant indexes
    Logger.info("Starting index consolidation...")

    # Drop duplicate victim_character_id indexes
    # These are redundant as we have the covering index from add_missing_critical_indexes
    drop_if_exists index(:killmails_raw, [:victim_character_id, :killmail_time],
      name: :killmails_raw_victim_time_idx)

    drop_if_exists index(:killmails_raw, [:victim_character_id, :killmail_time],
      name: :idx_killmails_victim_character)

    # Drop redundant single-column indexes that are covered by composite indexes
    # The composite affiliation index covers these individual lookups
    drop_if_exists index(:participants, [:character_id],
      name: :participants_character_id_index)

    drop_if_exists index(:participants, [:corporation_id],
      name: :participants_corporation_id_index)

    drop_if_exists index(:participants, [:alliance_id],
      name: :participants_alliance_id_index)

    # Drop redundant killmail_id indexes on participants
    # We have composite indexes that include killmail_id as first column
    drop_if_exists index(:participants, [:killmail_id],
      name: :participants_killmail_id_index)

    # Drop redundant system indexes if covered by composite
    drop_if_exists index(:killmails_raw, [:solar_system_id],
      name: :killmails_raw_solar_system_id_index)

    # Analyze tables to update statistics
    execute "ANALYZE killmails_raw;"
    execute "ANALYZE participants;"

    Logger.info("Index consolidation complete")
  end

  def down do
    # Restore original indexes if needed
    # Only restore truly necessary ones
    create_if_not_exists index(:participants, [:character_id],
      name: :participants_character_id_index,
      concurrently: true)

    create_if_not_exists index(:participants, [:corporation_id],
      name: :participants_corporation_id_index,
      concurrently: true)

    create_if_not_exists index(:participants, [:killmail_id],
      name: :participants_killmail_id_index,
      concurrently: true)

    create_if_not_exists index(:killmails_raw, [:solar_system_id],
      name: :killmails_raw_solar_system_id_index,
      concurrently: true)
  end
end
