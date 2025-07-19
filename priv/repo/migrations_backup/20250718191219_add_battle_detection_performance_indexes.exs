defmodule EveDmv.Repo.Migrations.AddBattleDetectionPerformanceIndexes do
  use Ecto.Migration
  
  # Required for concurrent index creation
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Sprint 17 DB-002: Performance indexes for battle detection
    
    # Composite index on timestamp and solar_system_id for spatial queries
    # This is critical for battle detection which groups by system and time
    create_if_not_exists index(:killmails_raw, [:killmail_time, :solar_system_id], 
      name: :killmails_raw_time_system_idx,
      concurrently: true,
      comment: "Optimizes battle detection spatial-temporal queries")
    
    # Index on character_id and timestamp for activity tracking
    # Used for character activity analysis and participation tracking
    create_if_not_exists index(:killmails_raw, [:victim_character_id, :killmail_time], 
      name: :killmails_raw_character_activity_idx,
      concurrently: true,
      comment: "Speeds up character activity timeline queries")
    
    # Index on corporation_id and alliance_id for affiliation queries
    # Important for corporation/alliance battle analysis
    create_if_not_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id], 
      name: :killmails_raw_corp_alliance_idx,
      concurrently: true,
      comment: "Optimizes affiliation-based battle queries")
    
    # Additional composite index for corp+alliance+time queries
    create_if_not_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id, :killmail_time], 
      name: :killmails_raw_corp_alliance_time_idx,
      concurrently: true,
      comment: "Supports complex affiliation and time-based queries")
    
    # Participants table indexes for battle analysis
    create_if_not_exists index(:participants, [:character_id, :killmail_time], 
      name: :participants_character_activity_idx,
      concurrently: true,
      comment: "Character activity tracking for battle participation")
    
    create_if_not_exists index(:participants, [:corporation_id, :alliance_id], 
      name: :participants_corp_alliance_idx,
      concurrently: true,
      comment: "Affiliation queries for battle participants")
    
    # Battle-specific indexes will be created when battle tables are created
    # Commented out for now since tables don't exist yet
    # create_if_not_exists index(:battles, [:system_id, :start_time], 
    #   name: :battles_system_time_idx,
    #   concurrently: true,
    #   comment: "Efficient battle lookup by system and time",
    #   where: "deleted_at IS NULL")
    
    # create_if_not_exists index(:battles, [:start_time, :end_time], 
    #   name: :battles_time_range_idx,
    #   concurrently: true,
    #   comment: "Time range queries for battle overlap detection",
    #   where: "deleted_at IS NULL")
    
    # create_if_not_exists index(:battle_killmails, [:battle_id, :added_at], 
    #   name: :battle_killmails_battle_time_idx,
    #   concurrently: true,
    #   comment: "Efficient battle killmail timeline queries")
  end
  
  def down do
    drop_if_exists index(:killmails_raw, [:killmail_time, :solar_system_id], name: :killmails_raw_time_system_idx)
    drop_if_exists index(:killmails_raw, [:victim_character_id, :killmail_time], name: :killmails_raw_character_activity_idx)
    drop_if_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id], name: :killmails_raw_corp_alliance_idx)
    drop_if_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id, :killmail_time], name: :killmails_raw_corp_alliance_time_idx)
    
    drop_if_exists index(:participants, [:character_id, :killmail_time], name: :participants_character_activity_idx)
    drop_if_exists index(:participants, [:corporation_id, :alliance_id], name: :participants_corp_alliance_idx)
    
    # drop_if_exists index(:battles, [:system_id, :start_time], name: :battles_system_time_idx)
    # drop_if_exists index(:battles, [:start_time, :end_time], name: :battles_time_range_idx)
    # drop_if_exists index(:battle_killmails, [:battle_id, :added_at], name: :battle_killmails_battle_time_idx)
  end
end