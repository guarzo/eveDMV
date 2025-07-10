defmodule EveDmv.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Killmails_raw indexes for common query patterns
    create_if_not_exists index(:killmails_raw, [:killmail_time], 
      name: :killmails_raw_killmail_time_idx,
      comment: "Speeds up timeline queries and time-based filtering")
    
    create_if_not_exists index(:killmails_raw, [:solar_system_id, :killmail_time], 
      name: :killmails_raw_system_time_idx,
      comment: "Optimizes system activity queries and battle detection")
    
    create_if_not_exists index(:killmails_raw, [:victim_character_id, :killmail_time], 
      name: :killmails_raw_victim_time_idx,
      comment: "Speeds up character intelligence and kill history queries")
    
    # Participants indexes for activity analysis
    create_if_not_exists index(:participants, [:character_id, :killmail_time], 
      name: :participants_character_time_idx,
      comment: "Optimizes character activity analysis and PvP history")
    
    create_if_not_exists index(:participants, [:corporation_id, :killmail_time], 
      name: :participants_corp_time_idx,
      comment: "Speeds up corporation member activity queries")
    
    create_if_not_exists index(:participants, [:ship_type_id, :killmail_time], 
      name: :participants_ship_time_idx,
      comment: "Enables efficient ship usage analysis and meta tracking")
    
    create_if_not_exists index(:participants, [:killmail_id], 
      name: :participants_killmail_id_idx,
      comment: "Foreign key index for efficient joins with killmails")
    
    # Character stats indexes
    create_if_not_exists index(:character_stats, [:character_id], 
      name: :character_stats_character_id_idx,
      comment: "Primary lookup index for character statistics")
    
    create_if_not_exists index(:character_stats, [:corporation_id, :dangerous_rating], 
      name: :character_stats_corp_danger_idx,
      comment: "Enables corporation threat assessment queries")
    
    # Eve static data indexes
    create_if_not_exists index(:eve_item_types, [:type_name], 
      name: :eve_item_types_name_idx,
      comment: "Fast ship/module name lookups")
    
    create_if_not_exists index(:eve_solar_systems, [:system_name], 
      name: :eve_solar_systems_name_idx,
      comment: "Fast system name lookups")
    
    create_if_not_exists index(:eve_solar_systems, [:security_status], 
      name: :eve_solar_systems_security_idx,
      comment: "Filter by security status (highsec/lowsec/nullsec)")
    
    # Update statistics for query planner after adding indexes
    execute "ANALYZE killmails_raw", ""
    execute "ANALYZE participants", ""
    execute "ANALYZE character_stats", ""
    execute "ANALYZE eve_item_types", ""
    execute "ANALYZE eve_solar_systems", ""
  end
end