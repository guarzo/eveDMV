defmodule EveDmv.Repo.Migrations.AddMissingCriticalIndexes do
  use Ecto.Migration
  require Logger
  
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Ship type analysis index - critical for ship usage queries
    create_if_not_exists index(:participants, [:ship_type_id, :killmail_time], 
      name: :idx_participants_ship_type_analysis,
      concurrently: true,
      comment: "Optimizes ship type analysis queries")
    
    # Weapon type analysis index - speeds up weapon analysis  
    create_if_not_exists index(:participants, [:weapon_type_id], 
      name: :idx_participants_weapon_type,
      where: "weapon_type_id IS NOT NULL",
      concurrently: true,
      comment: "Speeds up weapon analysis queries")
    
    # Surveillance profile filter tree GIN index
    create_if_not_exists index(:surveillance_profiles, [:filter_tree], 
      name: :idx_surveillance_profiles_filter_gin,
      using: :gin,
      concurrently: true,
      comment: "Enables fast JSONB filter searches")
    
    # ZKB value queries expression index
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_killmails_zkb_value
    ON killmails_raw ((raw_data->'zkb'->>'totalValue')::bigint DESC)
    WHERE raw_data ? 'zkb'
    """
    
    # Covering index for character analysis - includes key fields to avoid table lookups
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_killmails_character_covering
    ON killmails_raw (victim_character_id, killmail_time DESC)
    INCLUDE (solar_system_id, victim_ship_type_id, total_value)
    WHERE killmail_time >= '2024-01-01'
    """
    
    # Composite index for character/corporation lookups
    create_if_not_exists index(:participants, 
      [:character_id, :corporation_id, :alliance_id, :killmail_time],
      name: :idx_participants_affiliation_composite,
      concurrently: true,
      comment: "Composite index for affiliation queries")
    
    # System activity analysis index
    create_if_not_exists index(:killmails_raw, [:solar_system_id, :killmail_time],
      name: :idx_killmails_system_activity,
      concurrently: true,
      comment: "Optimizes system activity queries")
    
    # Battle detection index for clustering
    create_if_not_exists index(:killmails_raw, [:solar_system_id, :killmail_time, :total_value],
      name: :idx_killmails_battle_detection,
      where: "killmail_time >= '2024-01-01'",
      concurrently: true,
      comment: "Supports battle detection clustering")
    
    # Character stats tracking index
    create_if_not_exists index(:character_stats, [:character_id, :updated_at],
      name: :idx_character_stats_tracking,
      concurrently: true,
      comment: "Tracks character stat updates")
    
    # Fleet composition analysis index
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_participants_fleet_analysis
    ON participants (killmail_id, is_victim, ship_type_id)
    WHERE is_victim = false
    """
    
    Logger.info("Critical indexes created successfully")
  end

  def down do
    # Drop indexes in reverse order
    execute "DROP INDEX IF EXISTS idx_participants_fleet_analysis"
    drop_if_exists index(:character_stats, [:character_id, :updated_at], name: :idx_character_stats_tracking)
    drop_if_exists index(:killmails_raw, [:solar_system_id, :killmail_time, :total_value], name: :idx_killmails_battle_detection)
    drop_if_exists index(:killmails_raw, [:solar_system_id, :killmail_time], name: :idx_killmails_system_activity)
    drop_if_exists index(:participants, [:character_id, :corporation_id, :alliance_id, :killmail_time], name: :idx_participants_affiliation_composite)
    execute "DROP INDEX IF EXISTS idx_killmails_character_covering"
    execute "DROP INDEX IF EXISTS idx_killmails_zkb_value"
    drop_if_exists index(:surveillance_profiles, [:filter_tree], name: :idx_surveillance_profiles_filter_gin)
    drop_if_exists index(:participants, [:weapon_type_id], name: :idx_participants_weapon_type)
    drop_if_exists index(:participants, [:ship_type_id, :killmail_time], name: :idx_participants_ship_type_analysis)
  end
end
