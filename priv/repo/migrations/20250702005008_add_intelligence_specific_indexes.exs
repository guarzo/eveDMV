defmodule EveDmv.Repo.Migrations.AddIntelligenceSpecificIndexes do
  use Ecto.Migration

  def change do
    # Optimize character intelligence queries
    create index(:participants, [:character_id, :killmail_id],
      comment: "Speeds up character activity analysis queries")
    
    create index(:participants, [:corporation_id, :killmail_id], 
      comment: "Optimizes corporation member analysis")
    
    # Optimize temporal queries for intelligence analysis
    create index(:killmails_enriched, [:killmail_time, :victim_character_id],
      comment: "Speeds up time-based character intelligence queries")
    
    create index(:killmails_enriched, [:killmail_time, :solar_system_id],
      comment: "Optimizes system activity timeline analysis")
    
    # Optimize ship type queries for analytics
    create index(:participants, [:ship_type_id, :character_id],
      comment: "Speeds up ship preference analysis")
    
    create index(:killmails_enriched, [:victim_ship_type_id, :killmail_time],
      comment: "Optimizes ship loss analysis queries")
    
    # Optimize alliance-based intelligence queries
    create index(:participants, [:alliance_id, :killmail_time], 
      name: "participants_alliance_killmail_time_intel_idx",
      where: "alliance_id IS NOT NULL",
      comment: "Speeds up alliance intelligence analysis")
    
    # Optimize high-value killmail analysis
    create index(:killmails_enriched, [:total_value, :killmail_time],
      where: "total_value > 100000000",
      comment: "Optimizes high-value killmail intelligence queries")
    
    # Optimize character statistics lookups
    create index(:character_stats, [:character_id, :last_calculated_at],
      name: "character_stats_character_last_calc_intel_idx",
      comment: "Speeds up character intelligence data retrieval")
    
    create index(:character_stats, [:corporation_id, :dangerous_rating],
      comment: "Optimizes corporation threat assessment queries")
    
    # Optimize system inhabitant intelligence
    create index(:system_inhabitants, [:system_id, :last_seen_at],
      comment: "Speeds up system inhabitant intelligence queries")
    
    # Note: character_id, last_seen_at index already exists in initial schema
    
    # Optimize chain intelligence queries
    create index(:chain_connections, [:source_system_id, :target_system_id],
      comment: "Speeds up wormhole chain navigation queries")
    
    # Note: chain_topologies[:updated_at] index already exists in initial schema
    
    # Optimize surveillance profile matching
    # Note: profile_id, matched_at index already exists as profile_matches_profile_time_idx
    
    create index(:surveillance_profile_matches, [:killmail_id],
      comment: "Optimizes killmail-to-surveillance lookups")
  end
end
