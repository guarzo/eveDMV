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
  
  def up do
    # =====================================
    # Killmail Query Performance
    # =====================================
    
    # High-frequency access pattern: recent kills by system
    create_if_not_exists index(:killmails_raw, [:solar_system_id, :killmail_time], 
      name: :idx_killmails_system_time,
      concurrently: true,
      comment: "Optimizes system activity queries")
    
    # Character activity queries
    create_if_not_exists index(:killmails_raw, [:victim_character_id, :killmail_time], 
      name: :idx_killmails_victim_time,
      concurrently: true,
      comment: "Optimizes victim lookup queries")
    
    # Corporation and alliance activity
    create_if_not_exists index(:killmails_raw, [:victim_corporation_id, :killmail_time], 
      name: :idx_killmails_corp_time,
      concurrently: true)
    
    create_if_not_exists index(:killmails_raw, [:victim_alliance_id, :killmail_time], 
      name: :idx_killmails_alliance_time,
      concurrently: true)
    
    # Ship type analysis
    create_if_not_exists index(:killmails_raw, [:victim_ship_type_id, :killmail_time], 
      name: :idx_killmails_ship_type_time,
      concurrently: true)
    
    # Recent kills partial index (last 7 days)
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_killmails_recent 
    ON killmails_raw (killmail_time DESC)
    WHERE killmail_time > CURRENT_TIMESTAMP - INTERVAL '7 days'
    """, """
    DROP INDEX IF EXISTS idx_killmails_recent
    """
    
    # =====================================
    # Participant Analysis
    # =====================================
    
    # Character activity across all kills
    create_if_not_exists index(:participants, [:character_id, :killmail_time], 
      name: :idx_participants_character_activity,
      concurrently: true)
    
    # Ship type usage patterns
    create_if_not_exists index(:participants, [:ship_type_id, :killmail_time], 
      name: :idx_participants_ship_analysis,
      concurrently: true)
    
    # Weapon type analysis
    create_if_not_exists index(:participants, [:weapon_type_id, :character_id], 
      name: :idx_participants_weapon_analysis,
      concurrently: true,
      where: "weapon_type_id IS NOT NULL")
    
    # Corporation member activity
    create_if_not_exists index(:participants, [:corporation_id, :killmail_time], 
      name: :idx_participants_corp_activity,
      concurrently: true)
    
    # Final blow tracking
    create_if_not_exists index(:participants, [:killmail_id], 
      name: :idx_participants_final_blow,
      concurrently: true,
      where: "final_blow = true")
    
    # =====================================
    # Intelligence & Analytics
    # =====================================
    
    # Character stats lookups
    create_if_not_exists index(:character_stats, [:recent_activity_score, :threat_level], 
      name: :idx_character_stats_activity_threat,
      concurrently: true)
    
    create_if_not_exists index(:character_stats, [:last_seen, :threat_level], 
      name: :idx_character_stats_last_seen_threat,
      concurrently: true)
    
    # Player stats leaderboards
    create_if_not_exists index(:player_stats, [:kills_last_30d, :efficiency_rating], 
      name: :idx_player_stats_recent_performance,
      concurrently: true)
    
    create_if_not_exists index(:player_stats, [:total_isk_destroyed, :efficiency_rating], 
      name: :idx_player_stats_isk_efficiency,
      concurrently: true)
    
    # Ship stats analysis
    create_if_not_exists index(:ship_stats, [:ship_type_id, :usage_count], 
      name: :idx_ship_stats_popularity,
      concurrently: true)
    
    # =====================================
    # Surveillance System
    # =====================================
    
    # Active profile lookups
    create_if_not_exists index(:surveillance_profiles, [:is_active, :updated_at], 
      name: :idx_profiles_active,
      concurrently: true,
      where: "is_active = true")
    
    # Character watch lists
    create_if_not_exists index(:surveillance_profiles, [:criteria], 
      name: :idx_profiles_character_criteria,
      concurrently: true,
      using: :gin,
      comment: "GIN index for JSONB character criteria lookups")
    
    # Profile matches by character
    create_if_not_exists index(:surveillance_profile_matches, [:character_id, :created_at], 
      name: :idx_matches_character_time,
      concurrently: true)
    
    # Recent matches for notifications
    create_if_not_exists index(:surveillance_profile_matches, [:profile_id, :created_at], 
      name: :idx_matches_profile_recent,
      concurrently: true,
      where: "created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'")
    
    # =====================================
    # Battle Analysis
    # =====================================
    
    # Battle lookups by system and time
    create_if_not_exists index(:battles, [:system_id, :start_time], 
      name: :idx_battles_system_time,
      concurrently: true,
      where: "deleted_at IS NULL")
    
    # Large battles for special analysis
    create_if_not_exists index(:battles, [:participant_count, :total_isk_destroyed], 
      name: :idx_battles_large_scale,
      concurrently: true,
      where: "participant_count > 50 AND deleted_at IS NULL")
    
    # Battle killmail associations
    create_if_not_exists index(:battle_killmails, [:killmail_id], 
      name: :idx_battle_killmails_killmail,
      concurrently: true)
    
    # =====================================
    # Authentication & Users
    # =====================================
    
    # User lookups by character
    create_if_not_exists index(:users, [:character_id], 
      name: :idx_users_character,
      concurrently: true,
      unique: true)
    
    # API key lookups
    create_if_not_exists index(:api_keys, [:key_hash], 
      name: :idx_api_keys_hash,
      concurrently: true,
      unique: true)
    
    create_if_not_exists index(:api_keys, [:is_active, :expires_at], 
      name: :idx_api_keys_active_expiry,
      concurrently: true,
      where: "is_active = true")
    
    # =====================================
    # Static Data Access
    # =====================================
    
    # Item type lookups
    create_if_not_exists index(:eve_item_types, [:type_name], 
      name: :idx_item_types_name,
      concurrently: true)
    
    create_if_not_exists index(:eve_item_types, [:group_id], 
      name: :idx_item_types_group,
      concurrently: true)
    
    # Solar system lookups
    create_if_not_exists index(:eve_solar_systems, [:system_name], 
      name: :idx_solar_systems_name,
      concurrently: true)
    
    create_if_not_exists index(:eve_solar_systems, [:constellation_id], 
      name: :idx_solar_systems_constellation,
      concurrently: true)
    
    create_if_not_exists index(:eve_solar_systems, [:region_id], 
      name: :idx_solar_systems_region,
      concurrently: true)
  end
  
  def down do
    # Drop indexes in reverse order
    drop_if_exists index(:eve_solar_systems, [:region_id], name: :idx_solar_systems_region)
    drop_if_exists index(:eve_solar_systems, [:constellation_id], name: :idx_solar_systems_constellation)
    drop_if_exists index(:eve_solar_systems, [:system_name], name: :idx_solar_systems_name)
    
    drop_if_exists index(:eve_item_types, [:group_id], name: :idx_item_types_group)
    drop_if_exists index(:eve_item_types, [:type_name], name: :idx_item_types_name)
    
    drop_if_exists index(:api_keys, [:is_active, :expires_at], name: :idx_api_keys_active_expiry)
    drop_if_exists index(:api_keys, [:key_hash], name: :idx_api_keys_hash)
    drop_if_exists index(:users, [:character_id], name: :idx_users_character)
    
    drop_if_exists index(:battle_killmails, [:killmail_id], name: :idx_battle_killmails_killmail)
    drop_if_exists index(:battles, [:participant_count, :total_isk_destroyed], name: :idx_battles_large_scale)
    drop_if_exists index(:battles, [:system_id, :start_time], name: :idx_battles_system_time)
    
    drop_if_exists index(:surveillance_profile_matches, [:profile_id, :created_at], name: :idx_matches_profile_recent)
    drop_if_exists index(:surveillance_profile_matches, [:character_id, :created_at], name: :idx_matches_character_time)
    drop_if_exists index(:surveillance_profiles, [:criteria], name: :idx_profiles_character_criteria)
    drop_if_exists index(:surveillance_profiles, [:is_active, :updated_at], name: :idx_profiles_active)
    
    drop_if_exists index(:ship_stats, [:ship_type_id, :usage_count], name: :idx_ship_stats_popularity)
    drop_if_exists index(:player_stats, [:total_isk_destroyed, :efficiency_rating], name: :idx_player_stats_isk_efficiency)
    drop_if_exists index(:player_stats, [:kills_last_30d, :efficiency_rating], name: :idx_player_stats_recent_performance)
    drop_if_exists index(:character_stats, [:last_seen, :threat_level], name: :idx_character_stats_last_seen_threat)
    drop_if_exists index(:character_stats, [:recent_activity_score, :threat_level], name: :idx_character_stats_activity_threat)
    
    drop_if_exists index(:participants, [:killmail_id], name: :idx_participants_final_blow)
    drop_if_exists index(:participants, [:corporation_id, :killmail_time], name: :idx_participants_corp_activity)
    drop_if_exists index(:participants, [:weapon_type_id, :character_id], name: :idx_participants_weapon_analysis)
    drop_if_exists index(:participants, [:ship_type_id, :killmail_time], name: :idx_participants_ship_analysis)
    drop_if_exists index(:participants, [:character_id, :killmail_time], name: :idx_participants_character_activity)
    
    execute "DROP INDEX IF EXISTS idx_killmails_recent"
    
    drop_if_exists index(:killmails_raw, [:victim_ship_type_id, :killmail_time], name: :idx_killmails_ship_type_time)
    drop_if_exists index(:killmails_raw, [:victim_alliance_id, :killmail_time], name: :idx_killmails_alliance_time)
    drop_if_exists index(:killmails_raw, [:victim_corporation_id, :killmail_time], name: :idx_killmails_corp_time)
    drop_if_exists index(:killmails_raw, [:victim_character_id, :killmail_time], name: :idx_killmails_victim_time)
    drop_if_exists index(:killmails_raw, [:solar_system_id, :killmail_time], name: :idx_killmails_system_time)
  end
  
  # Helper to create indexes only if they don't exist
  defp create_if_not_exists(index_definition) do
    create index_definition
  rescue
    _ -> :ok
  end
  
  defp drop_if_exists(index_definition) do
    drop index_definition
  rescue
    _ -> :ok
  end
end