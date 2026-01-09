defmodule EveDmv.Repo.Migrations.PerformanceIndexes do
  @moduledoc """
  Performance-critical indexes for the EVE DMV application.

  These indexes are organized by use case and include:
  - Query optimization indexes
  - Foreign key indexes
  - Composite indexes for common access patterns
  - Partial indexes for filtered queries
  - JSONB GIN indexes for metadata
  """

  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # =====================================
    # Killmail Query Performance
    # =====================================

    # High-frequency access pattern: recent kills by system
    create_if_not_exists(
      index(:killmails_raw, [:solar_system_id, :killmail_time],
        name: :idx_killmails_system_time,
        concurrently: true,
        comment: "Optimizes system activity queries"
      )
    )

    # Character activity queries
    create_if_not_exists(
      index(:killmails_raw, [:victim_character_id, :killmail_time],
        name: :idx_killmails_victim_time,
        concurrently: true,
        comment: "Optimizes victim lookup queries"
      )
    )

    # Corporation and alliance activity
    create_if_not_exists(
      index(:killmails_raw, [:victim_corporation_id, :killmail_time],
        name: :idx_killmails_corp_time,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:killmails_raw, [:victim_alliance_id, :killmail_time],
        name: :idx_killmails_alliance_time,
        concurrently: true
      )
    )

    # Ship type analysis
    create_if_not_exists(
      index(:killmails_raw, [:victim_ship_type_id, :killmail_time],
        name: :idx_killmails_ship_type_time,
        concurrently: true
      )
    )

    # Recent kills index (no partial filter due to immutability requirement)
    create_if_not_exists(
      index(:killmails_raw, ["killmail_time DESC"],
        name: :idx_killmails_recent,
        concurrently: true
      )
    )

    # =====================================
    # Participant Analysis
    # =====================================

    # Character activity across all kills
    create_if_not_exists(
      index(:participants, [:character_id, :killmail_time],
        name: :idx_participants_character_activity,
        concurrently: true
      )
    )

    # Ship type usage patterns
    create_if_not_exists(
      index(:participants, [:ship_type_id, :killmail_time],
        name: :idx_participants_ship_analysis,
        concurrently: true
      )
    )

    # Weapon type analysis
    create_if_not_exists(
      index(:participants, [:weapon_type_id, :character_id],
        name: :idx_participants_weapon_analysis,
        concurrently: true,
        where: "weapon_type_id IS NOT NULL"
      )
    )

    # Corporation member activity
    create_if_not_exists(
      index(:participants, [:corporation_id, :killmail_time],
        name: :idx_participants_corp_activity,
        concurrently: true
      )
    )

    # Final blow tracking
    create_if_not_exists(
      index(:participants, [:killmail_id],
        name: :idx_participants_final_blow,
        concurrently: true,
        where: "final_blow = true"
      )
    )

    # =====================================
    # Intelligence & Analytics
    # =====================================

    # Character stats lookups - using actual columns
    create_if_not_exists(
      index(:character_stats, [:dangerous_rating, :kill_death_ratio],
        name: :idx_character_stats_danger_kdr,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:character_stats, [:total_kills, :isk_efficiency],
        name: :idx_character_stats_kills_efficiency,
        concurrently: true
      )
    )

    # Player stats leaderboards
    create_if_not_exists(
      index(:player_stats, [:total_kills, :kill_death_ratio],
        name: :idx_player_stats_kills_kdr,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:player_stats, [:total_isk_destroyed, :isk_efficiency_percent],
        name: :idx_player_stats_isk_efficiency,
        concurrently: true
      )
    )

    # Ship stats analysis
    create_if_not_exists(
      index(:ship_stats, [:ship_type_id, :total_kills],
        name: :idx_ship_stats_popularity,
        concurrently: true
      )
    )

    # =====================================
    # Surveillance System
    # =====================================

    # Active profile lookups
    create_if_not_exists(
      index(:surveillance_profiles, [:is_active, :updated_at],
        name: :idx_profiles_active,
        concurrently: true,
        where: "is_active = true"
      )
    )

    # Character watch lists
    create_if_not_exists(
      index(:surveillance_profiles, [:filter_tree],
        name: :idx_profiles_filter_tree,
        concurrently: true,
        using: :gin,
        comment: "GIN index for JSONB filter tree lookups"
      )
    )

    # Profile matches by victim name and time
    create_if_not_exists(
      index(:surveillance_profile_matches, [:victim_character_name, :matched_at],
        name: :idx_matches_victim_time,
        concurrently: true
      )
    )

    # Recent matches for notifications (removed partial filter due to immutability requirement)
    create_if_not_exists(
      index(:surveillance_profile_matches, [:profile_id, :matched_at],
        name: :idx_matches_profile_recent,
        concurrently: true
      )
    )

    # =====================================
    # Battle Analysis
    # =====================================

    # Battle lookups by system and time
    create_if_not_exists(
      index(:battles, [:system_id, :start_time],
        name: :idx_battles_system_time,
        concurrently: true,
        where: "deleted_at IS NULL"
      )
    )

    # Large battles for special analysis
    create_if_not_exists(
      index(:battles, [:participant_count, :total_isk_destroyed],
        name: :idx_battles_large_scale,
        concurrently: true,
        where: "participant_count > 50 AND deleted_at IS NULL"
      )
    )

    # Battle killmail associations
    create_if_not_exists(
      index(:battle_killmails, [:killmail_id],
        name: :idx_battle_killmails_killmail,
        concurrently: true
      )
    )

    # =====================================
    # Authentication & Users
    # =====================================

    # User lookups by character
    create_if_not_exists(
      index(:users, [:eve_character_id],
        name: :idx_users_character,
        concurrently: true,
        unique: true
      )
    )

    # API key lookups
    create_if_not_exists(
      index(:api_keys, [:api_key],
        name: :idx_api_keys_key,
        concurrently: true,
        unique: true
      )
    )

    create_if_not_exists(
      index(:api_keys, [:is_active, :expires_at],
        name: :idx_api_keys_active_expiry,
        concurrently: true,
        where: "is_active = true"
      )
    )

    # =====================================
    # Static Data Access
    # =====================================

    # Item type lookups
    create_if_not_exists(
      index(:eve_item_types, [:type_name],
        name: :idx_item_types_name,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:eve_item_types, [:group_id],
        name: :idx_item_types_group,
        concurrently: true
      )
    )

    # Solar system lookups
    create_if_not_exists(
      index(:eve_solar_systems, [:system_name],
        name: :idx_solar_systems_name,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:eve_solar_systems, [:constellation_id],
        name: :idx_solar_systems_constellation,
        concurrently: true
      )
    )

    create_if_not_exists(
      index(:eve_solar_systems, [:region_id],
        name: :idx_solar_systems_region,
        concurrently: true
      )
    )
  end

  def down do
    execute("SET statement_timeout = 0")

    # Drop indexes in reverse order
    drop_if_exists(index(:eve_solar_systems, [:region_id], name: :idx_solar_systems_region))

    drop_if_exists(
      index(:eve_solar_systems, [:constellation_id], name: :idx_solar_systems_constellation)
    )

    drop_if_exists(index(:eve_solar_systems, [:system_name], name: :idx_solar_systems_name))

    drop_if_exists(index(:eve_item_types, [:group_id], name: :idx_item_types_group))
    drop_if_exists(index(:eve_item_types, [:type_name], name: :idx_item_types_name))

    drop_if_exists(index(:api_keys, [:is_active, :expires_at], name: :idx_api_keys_active_expiry))
    drop_if_exists(index(:api_keys, [:api_key], name: :idx_api_keys_key))
    drop_if_exists(index(:users, [:eve_character_id], name: :idx_users_character))

    drop_if_exists(index(:battle_killmails, [:killmail_id], name: :idx_battle_killmails_killmail))

    drop_if_exists(
      index(:battles, [:participant_count, :total_isk_destroyed], name: :idx_battles_large_scale)
    )

    drop_if_exists(index(:battles, [:system_id, :start_time], name: :idx_battles_system_time))

    drop_if_exists(
      index(:surveillance_profile_matches, [:profile_id, :matched_at],
        name: :idx_matches_profile_recent
      )
    )

    drop_if_exists(
      index(:surveillance_profile_matches, [:victim_character_name, :matched_at],
        name: :idx_matches_victim_time
      )
    )

    drop_if_exists(index(:surveillance_profiles, [:filter_tree], name: :idx_profiles_filter_tree))

    drop_if_exists(
      index(:surveillance_profiles, [:is_active, :updated_at], name: :idx_profiles_active)
    )

    drop_if_exists(
      index(:ship_stats, [:ship_type_id, :total_kills], name: :idx_ship_stats_popularity)
    )

    drop_if_exists(
      index(:player_stats, [:total_isk_destroyed, :isk_efficiency_percent],
        name: :idx_player_stats_isk_efficiency
      )
    )

    drop_if_exists(
      index(:player_stats, [:total_kills, :kill_death_ratio], name: :idx_player_stats_kills_kdr)
    )

    drop_if_exists(
      index(:character_stats, [:total_kills, :isk_efficiency],
        name: :idx_character_stats_kills_efficiency
      )
    )

    drop_if_exists(
      index(:character_stats, [:dangerous_rating, :kill_death_ratio],
        name: :idx_character_stats_danger_kdr
      )
    )

    drop_if_exists(index(:participants, [:killmail_id], name: :idx_participants_final_blow))

    drop_if_exists(
      index(:participants, [:corporation_id, :killmail_time],
        name: :idx_participants_corp_activity
      )
    )

    drop_if_exists(
      index(:participants, [:weapon_type_id, :character_id],
        name: :idx_participants_weapon_analysis
      )
    )

    drop_if_exists(
      index(:participants, [:ship_type_id, :killmail_time], name: :idx_participants_ship_analysis)
    )

    drop_if_exists(
      index(:participants, [:character_id, :killmail_time],
        name: :idx_participants_character_activity
      )
    )

    # Raw SQL required: Ecto's drop_if_exists doesn't support CONCURRENTLY option
    # for non-blocking drops on the partitioned killmails_raw table
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_recent")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_ship_type_time")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_alliance_time")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_corp_time")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_victim_time")
    execute("DROP INDEX CONCURRENTLY IF EXISTS idx_killmails_system_time")

    execute("RESET statement_timeout")
  end
end
