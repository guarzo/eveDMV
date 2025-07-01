defmodule EveDmv.Repo.Migrations.AddPerformanceOptimizations do
  use Ecto.Migration

  def change do
    # Core Performance Indexes for Killmails Enriched
    create index(:killmails_enriched, [:killmail_time, :total_value])
    create index(:killmails_enriched, [:solar_system_id, :killmail_time])
    create index(:killmails_enriched, [:victim_character_id, :killmail_time])

    # Partial index for high-value killmails (>100M ISK)
    create index(:killmails_enriched, [:killmail_time], where: "total_value > 100000000")

    # Expression index for timestamp calculations
    execute """
    CREATE INDEX killmails_enriched_timestamp_epoch_idx
    ON killmails_enriched (EXTRACT(EPOCH FROM killmail_time))
    """, "DROP INDEX killmails_enriched_timestamp_epoch_idx"

    # GIN index for JSON array searches
    create index(:killmails_enriched, [:module_tags], using: :gin)

    # Participants Table Indexes
    create index(:participants, [:character_id, :killmail_time, :is_victim])
    create index(:participants, [:ship_type_id, :killmail_time])
    create index(:participants, [:alliance_id, :killmail_time], where: "alliance_id IS NOT NULL")
    create index(:participants, [:killmail_id])
    create index(:participants, [:corporation_id, :character_id, :killmail_time])

    # Character Stats Indexes
    create index(:character_stats, [:dangerous_rating, :last_calculated_at])
    create index(:character_stats, [:corporation_id, :last_calculated_at])
    create index(:character_stats, [:character_id, :last_calculated_at])

    # Surveillance System Indexes
    create index(:surveillance_profiles, [:user_id, :is_active])
    create index(:surveillance_profiles, [:is_active])
    create index(:surveillance_profiles, [:user_id])

    create index(:surveillance_profile_matches, [:profile_id, :matched_at])
    create index(:surveillance_profile_matches, [:matched_at])
    create index(:surveillance_profile_matches, [:killmail_id, :killmail_time])
    create index(:surveillance_profile_matches, [:profile_id])
    create index(:surveillance_profile_matches, [:total_value])

    # Killmails Raw Indexes
    create index(:killmails_raw, [:killmail_id])

    
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
