defmodule EveDmv.Repo.Migrations.AddSprint17Indexes do
  @moduledoc """
  Add Sprint 17 performance indexes that tests are expecting.
  """
  
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true
  
  def up do
    # Killmails_raw indexes
    create_if_not_exists index(:killmails_raw, [:killmail_time, :solar_system_id], 
      name: :killmails_raw_time_system_idx,
      concurrently: true)
    
    create_if_not_exists index(:killmails_raw, [:victim_character_id, :killmail_time], 
      name: :killmails_raw_character_activity_idx,
      concurrently: true)
    
    create_if_not_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id], 
      name: :killmails_raw_corp_alliance_idx,
      concurrently: true)
    
    create_if_not_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id, :killmail_time], 
      name: :killmails_raw_corp_alliance_time_idx,
      concurrently: true)
    
    # Participants indexes
    create_if_not_exists index(:participants, [:damage_done, :final_blow], 
      name: :participants_damage_final_blow_idx,
      concurrently: true)
    
    create_if_not_exists index(:participants, [:ship_name, :weapon_name], 
      name: :participants_ship_weapon_names_idx,
      concurrently: true)
  end
  
  def down do
    drop_if_exists index(:participants, [:ship_name, :weapon_name], name: :participants_ship_weapon_names_idx)
    drop_if_exists index(:participants, [:damage_done, :final_blow], name: :participants_damage_final_blow_idx)
    drop_if_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id, :killmail_time], name: :killmails_raw_corp_alliance_time_idx)
    drop_if_exists index(:killmails_raw, [:victim_corporation_id, :victim_alliance_id], name: :killmails_raw_corp_alliance_idx)
    drop_if_exists index(:killmails_raw, [:victim_character_id, :killmail_time], name: :killmails_raw_character_activity_idx)
    drop_if_exists index(:killmails_raw, [:killmail_time, :solar_system_id], name: :killmails_raw_time_system_idx)
  end
end