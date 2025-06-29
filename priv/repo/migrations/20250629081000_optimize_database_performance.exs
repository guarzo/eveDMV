defmodule EveDmv.Repo.Migrations.OptimizeDatabasePerformance do
  @moduledoc """
  Additional database optimizations for EVE DMV performance.
  
  This migration adds:
  1. Composite indexes for common query patterns
  2. Partial indexes for frequently filtered data
  3. Expression indexes for calculated fields
  4. Query optimization hints
  """

  use Ecto.Migration

  def up do
    # Composite indexes for common killmail queries
    create index(:killmails_enriched, [:killmail_time, :total_value], 
      name: "killmails_enriched_time_value_idx",
      comment: "Optimizes high-value recent killmail queries"
    )
    
    create index(:killmails_enriched, [:solar_system_id, :killmail_time], 
      name: "killmails_enriched_system_time_idx",
      comment: "Optimizes system-specific killmail timeline queries"
    )
    
    create index(:killmails_enriched, [:victim_character_id, :killmail_time], 
      name: "killmails_enriched_character_time_idx",
      comment: "Optimizes character intelligence queries"
    )

    # Partial indexes for high-value killmails (>100M ISK)
    create index(:killmails_enriched, [:killmail_time], 
      name: "killmails_enriched_high_value_time_idx",
      where: "total_value > 100000000",
      comment: "Optimizes high-value killmail queries"
    )

    # Partial index for recent killmails (using a fixed timestamp to avoid immutability issues)
    create index(:killmails_enriched, [:total_value], 
      name: "killmails_enriched_recent_value_idx", 
      where: "killmail_time > '2024-01-01'::timestamp",
      comment: "Optimizes recent killmail value queries"
    )

    # Composite indexes for participant analysis
    create index(:participants, [:character_id, :killmail_time, :is_victim], 
      name: "participants_character_analysis_idx",
      comment: "Optimizes character activity analysis"
    )
    
    create index(:participants, [:ship_type_id, :killmail_time], 
      name: "participants_ship_analysis_idx",
      comment: "Optimizes ship usage analysis"
    )

    # Index for alliance/corp member activity
    create index(:participants, [:alliance_id, :killmail_time], 
      name: "participants_alliance_activity_idx",
      where: "alliance_id IS NOT NULL",
      comment: "Optimizes alliance activity queries"
    )

    # Surveillance profile optimization indexes
    create index(:surveillance_profile_matches, [:total_value], 
      name: "profile_matches_value_idx",
      comment: "Optimizes surveillance profile value filtering"
    )

    # Character stats optimization
    create index(:character_stats, [:dangerous_rating, :last_calculated_at], 
      name: "character_stats_danger_freshness_idx",
      comment: "Optimizes danger rating queries with data freshness"
    )

    # Expression index for killmail timestamp extraction (immutable function)
    execute """
    CREATE INDEX killmails_enriched_timestamp_epoch_idx 
    ON killmails_enriched (EXTRACT(EPOCH FROM killmail_time))
    """

    # GIN index for JSON arrays in enriched killmails
    create index(:killmails_enriched, [:module_tags], 
      name: "killmails_enriched_module_tags_gin_idx",
      using: "gin",
      comment: "Optimizes module tag searches for surveillance"
    )

    # Statistics update for better query planning
    execute "ANALYZE killmails_enriched"
    execute "ANALYZE participants" 
    execute "ANALYZE surveillance_profiles"
    execute "ANALYZE surveillance_profile_matches"
  end

  def down do
    # Drop the expression index
    execute "DROP INDEX IF EXISTS killmails_enriched_timestamp_epoch_idx"

    # Drop all the indexes we created
    drop_if_exists index(:killmails_enriched, [:module_tags], 
      name: "killmails_enriched_module_tags_gin_idx")

    drop_if_exists index(:character_stats, [:dangerous_rating, :last_calculated_at], 
      name: "character_stats_danger_freshness_idx")

    drop_if_exists index(:surveillance_profile_matches, [:total_value], 
      name: "profile_matches_value_idx")

    drop_if_exists index(:participants, [:alliance_id, :killmail_time], 
      name: "participants_alliance_activity_idx")

    drop_if_exists index(:participants, [:ship_type_id, :killmail_time], 
      name: "participants_ship_analysis_idx")

    drop_if_exists index(:participants, [:character_id, :killmail_time, :is_victim], 
      name: "participants_character_analysis_idx")

    drop_if_exists index(:killmails_enriched, [:total_value], 
      name: "killmails_enriched_recent_value_idx")

    drop_if_exists index(:killmails_enriched, [:killmail_time], 
      name: "killmails_enriched_high_value_time_idx")

    drop_if_exists index(:killmails_enriched, [:victim_character_id, :killmail_time], 
      name: "killmails_enriched_character_time_idx")

    drop_if_exists index(:killmails_enriched, [:solar_system_id, :killmail_time], 
      name: "killmails_enriched_system_time_idx")

    drop_if_exists index(:killmails_enriched, [:killmail_time, :total_value], 
      name: "killmails_enriched_time_value_idx")
  end
end