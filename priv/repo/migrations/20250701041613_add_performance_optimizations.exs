defmodule EveDmv.Repo.Migrations.AddPerformanceOptimizations do
  use Ecto.Migration

  def change do
    # Core Performance Indexes for Killmails Enriched
    # Speeds up timeline queries and value-based filtering in kill feed
    create index(:killmails_enriched, [:killmail_time, :total_value],
      comment: "Speeds up timeline queries and value-based filtering in kill feed")
    
    # Optimizes location-based queries for system activity monitoring
    create index(:killmails_enriched, [:solar_system_id, :killmail_time],
      comment: "Optimizes location-based queries for system activity monitoring")
    
    # Speeds up character intelligence queries in intelligence modules
    create index(:killmails_enriched, [:victim_character_id, :killmail_time],
      comment: "Speeds up character intelligence queries in intelligence modules")

    # Partial index for high-value killmails (>100M ISK)
    # Used by surveillance system to track expensive losses
    create index(:killmails_enriched, [:killmail_time], 
      where: "total_value > 100000000",
      comment: "Optimizes queries for high-value killmail tracking in surveillance")

    # Expression index for timestamp calculations
    # Used for time-based aggregations and analytics
    execute """
    CREATE INDEX killmails_enriched_timestamp_epoch_idx
    ON killmails_enriched (EXTRACT(EPOCH FROM killmail_time))
    """, "DROP INDEX killmails_enriched_timestamp_epoch_idx"

    # GIN index for JSON array searches
    # Enables fast module and fitting searches
    create index(:killmails_enriched, [:module_tags], using: :gin,
      comment: "Enables fast module and fitting searches using JSON containment")

    # Participants Table Indexes
    # Core index for character activity analysis
    create index(:participants, [:character_id, :killmail_time, :is_victim],
      comment: "Core index for character activity analysis in intelligence")
    
    # Speeds up ship type analysis queries
    create index(:participants, [:ship_type_id, :killmail_time],
      comment: "Speeds up ship type analysis and fleet composition queries")
    
    # Alliance-based filtering with NULL optimization
    create index(:participants, [:alliance_id, :killmail_time], 
      where: "alliance_id IS NOT NULL",
      comment: "Alliance-based filtering with NULL optimization")
    
    # Foreign key index for join performance
    create index(:participants, [:killmail_id],
      comment: "Foreign key index for efficient joins with killmails")
    
    # Corporation member activity analysis
    create index(:participants, [:corporation_id, :character_id, :killmail_time],
      comment: "Speeds up corporation member activity analysis")

    # Character Stats Indexes
    # Dangerous character leaderboard queries
    create index(:character_stats, [:dangerous_rating, :last_calculated_at],
      comment: "Optimizes dangerous character leaderboard queries")
    
    # Corporation member statistics
    create index(:character_stats, [:corporation_id, :last_calculated_at],
      comment: "Speeds up corporation member statistics aggregation")
    
    # Character lookup performance
    create index(:character_stats, [:character_id, :last_calculated_at],
      comment: "Optimizes individual character statistics lookups")

    # Surveillance System Indexes
    # User profile management queries
    create index(:surveillance_profiles, [:user_id, :is_active],
      comment: "Optimizes user profile management queries")
    
    # Active profile filtering for matching engine
    create index(:surveillance_profiles, [:is_active],
      comment: "Speeds up active profile filtering for matching engine")
    
    # User profile lookups
    create index(:surveillance_profiles, [:user_id],
      comment: "Optimizes user profile lookups")

    # Profile match history queries
    create index(:surveillance_profile_matches, [:profile_id, :matched_at],
      comment: "Speeds up profile match history queries")
    
    # Recent matches timeline
    create index(:surveillance_profile_matches, [:matched_at],
      comment: "Optimizes recent matches timeline queries")
    
    # Killmail-based match lookups
    create index(:surveillance_profile_matches, [:killmail_id, :killmail_time],
      comment: "Enables efficient killmail-based match lookups")
    
    # Profile match aggregation
    create index(:surveillance_profile_matches, [:profile_id],
      comment: "Speeds up profile match count aggregation")
    
    # High-value match filtering
    create index(:surveillance_profile_matches, [:total_value],
      comment: "Optimizes high-value match filtering queries")

    # Killmails Raw Indexes
    # Deduplication and pipeline processing
    create index(:killmails_raw, [:killmail_id],
      comment: "Enables fast deduplication checks in pipeline processing")

    
    # Update statistics for query planner
    execute "ANALYZE killmails_enriched", ""
    execute "ANALYZE participants", ""
    execute "ANALYZE surveillance_profiles", ""
    execute "ANALYZE surveillance_profile_matches", ""
    execute "ANALYZE character_stats", ""
    execute "ANALYZE system_inhabitants", ""
    execute "ANALYZE chain_topologies", ""
    execute "ANALYZE chain_connections", ""
  end
end
