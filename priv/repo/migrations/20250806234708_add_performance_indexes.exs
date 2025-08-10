defmodule EveDmv.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Indexes for killmails_raw table (primary data table)
    # These are critical for performance
    
    # Character activity queries
    create_if_not_exists(
      index(:killmails_raw, [:victim_character_id, :killmail_time], 
        name: :killmails_raw_character_activity_idx,
        comment: "Index for character activity queries"
      )
    )
    
    # Corporation/Alliance queries with time
    create_if_not_exists(
      index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id, :killmail_time],
        name: :killmails_raw_corp_alliance_time_idx,
        comment: "Composite index for corp/alliance queries with time"
      )
    )
    
    # System activity queries
    create_if_not_exists(
      index(:killmails_raw, [:solar_system_id, :killmail_time],
        name: :killmails_raw_system_time_idx,
        comment: "Index for system activity queries"
      )
    )
    
    # High value killmail queries
    create_if_not_exists(
      index(:killmails_raw, [:total_value, :killmail_time],
        name: :killmails_raw_value_time_idx,
        where: "total_value > 1000000000",
        comment: "Partial index for high-value killmails (> 1B ISK)"
      )
    )
    
    # Attacker count analysis
    create_if_not_exists(
      index(:killmails_raw, [:attacker_count, :killmail_time],
        name: :killmails_raw_attacker_count_idx,
        comment: "Index for fleet size analysis"
      )
    )
    
    # Ship type analysis
    create_if_not_exists(
      index(:killmails_raw, [:victim_ship_type_id, :killmail_time],
        name: :killmails_raw_ship_type_idx,
        comment: "Index for ship type analysis"
      )
    )
    
    # Indexes for eve_solar_systems table
    create_if_not_exists(
      index(:eve_solar_systems, [:constellation_id],
        name: :eve_solar_systems_constellation_idx,
        comment: "Index for constellation queries"
      )
    )
    
    create_if_not_exists(
      index(:eve_solar_systems, [:region_id],
        name: :eve_solar_systems_region_idx,
        comment: "Index for region queries"
      )
    )
    
    create_if_not_exists(
      index(:eve_solar_systems, [:security_status],
        name: :eve_solar_systems_security_idx,
        comment: "Index for security status queries"
      )
    )
    
    # Indexes for eve_item_types table
    create_if_not_exists(
      index(:eve_item_types, [:group_name],
        name: :eve_item_types_group_idx,
        comment: "Index for group queries"
      )
    )
    
    create_if_not_exists(
      index(:eve_item_types, [:is_ship],
        name: :eve_item_types_is_ship_idx,
        where: "is_ship = true",
        comment: "Partial index for ship queries"
      )
    )
    
    # Indexes for users table
    create_if_not_exists(
      index(:users, [:eve_character_id],
        name: :users_character_idx,
        unique: true,
        comment: "Unique index for character login"
      )
    )
    
    # Indexes for tokens table (JWT tokens)
    create_if_not_exists(
      index(:tokens, [:subject],
        name: :tokens_subject_idx,
        comment: "Index for JWT subject queries"
      )
    )
    
    create_if_not_exists(
      index(:tokens, [:expires_at],
        name: :tokens_expires_idx,
        comment: "Index for token expiration queries"
      )
    )
    
    create_if_not_exists(
      index(:tokens, [:purpose],
        name: :tokens_purpose_idx,
        comment: "Index for token purpose queries"
      )
    )
    
    # Indexes for surveillance_profiles table
    create_if_not_exists(
      index(:surveillance_profiles, [:is_active],
        name: :surveillance_profiles_active_idx,
        where: "is_active = true",
        comment: "Partial index for active profiles"
      )
    )
    
    create_if_not_exists(
      index(:surveillance_profiles, [:user_id],
        name: :surveillance_profiles_user_id_idx,
        comment: "Index for user profile queries"
      )
    )
    
    # Indexes for character_stats table
    create_if_not_exists(
      index(:character_stats, [:character_id],
        name: :character_stats_character_idx,
        unique: true,
        comment: "Unique index for character stats"
      )
    )
    
    # Indexes for surveillance_profile_matches table
    create_if_not_exists(
      index(:surveillance_profile_matches, [:profile_id, :killmail_id],
        name: :surveillance_matches_profile_killmail_idx,
        unique: true,
        comment: "Unique constraint on profile-killmail pairs"
      )
    )
    
    create_if_not_exists(
      index(:surveillance_profile_matches, [:matched_at],
        name: :surveillance_matches_time_idx,
        comment: "Index for time-based match queries"
      )
    )
  end
end