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
      where: "alliance_id IS NOT NULL",
      comment: "Speeds up alliance intelligence analysis")
    
    # Optimize high-value killmail analysis
    create index(:killmails_enriched, [:total_value, :killmail_time],
      where: "total_value > 100000000",
      comment: "Optimizes high-value killmail intelligence queries")
    
    # Optimize character statistics lookups
    create index(:character_stats, [:character_id, :last_calculated_at],
      comment: "Speeds up character intelligence data retrieval")
    
    create index(:character_stats, [:corporation_id, :dangerous_rating],
      comment: "Optimizes corporation threat assessment queries")
    
    # Optimize system inhabitant intelligence
    create index(:system_inhabitants, [:solar_system_id, :last_seen_at],
      comment: "Speeds up system inhabitant intelligence queries")
    
    create index(:system_inhabitants, [:character_id, :last_seen_at],
      comment: "Optimizes character location tracking")
    
    # Optimize chain intelligence queries
    create index(:chain_connections, [:from_system_id, :to_system_id],
      comment: "Speeds up wormhole chain navigation queries")
    
    create index(:chain_topologies, [:updated_at],
      comment: "Optimizes chain topology freshness queries")
    
    # Optimize surveillance profile matching
    create index(:surveillance_profile_matches, [:profile_id, :matched_at],
      comment: "Speeds up surveillance match history queries")
    
    create index(:surveillance_profile_matches, [:killmail_id],
      comment: "Optimizes killmail-to-surveillance lookups")
  end
end
