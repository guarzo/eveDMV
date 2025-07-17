defmodule EveDmv.Repo.Migrations.AddPerformanceIndexes do
  @moduledoc """
  Sprint 15A Performance Optimization - Phase 1: Critical Indexes
  
  Adds critical database indexes for query optimization without materialized views first.
  """

  use Ecto.Migration

  def up do
    # Add total_value column to killmails_raw for better performance
    alter table(:killmails_raw) do
      add(:total_value, :decimal, precision: 15, scale: 2)
    end

    # Add critical indexes for common query patterns
    create_performance_indexes()
  end

  def down do
    # Drop performance indexes
    drop_if_exists(index(:killmails_raw, [:victim_corporation_id, :killmail_time]))
    drop_if_exists(index(:killmails_raw, [:solar_system_id, :total_value]))
    drop_if_exists(index(:killmails_raw, ["total_value DESC"]))
    drop_if_exists(index(:participants, [:corporation_id, :killmail_time, :is_victim]))
    drop_if_exists(index(:participants, [:character_id, :killmail_time, :is_victim]))
    drop_if_exists(index(:participants, ["killmail_time DESC", "damage_done DESC"]))
    
    # Remove total_value column
    alter table(:killmails_raw) do
      remove(:total_value)
    end
  end

  defp create_performance_indexes do
    # Critical indexes for killmails_raw
    create(index(:killmails_raw, [:victim_corporation_id, :killmail_time], 
           name: "killmails_raw_victim_corp_time_idx"))
    
    create(index(:killmails_raw, [:solar_system_id, :total_value], 
           name: "killmails_raw_system_value_idx"))
    
    create(index(:killmails_raw, ["total_value DESC"], 
           name: "killmails_raw_value_desc_idx"))
    
    # Critical indexes for participants 
    create(index(:participants, [:corporation_id, :killmail_time, :is_victim], 
           name: "participants_corp_time_victim_idx"))
    
    create(index(:participants, [:character_id, :killmail_time, :is_victim], 
           name: "participants_char_time_victim_idx"))
    
    create(index(:participants, ["killmail_time DESC", "damage_done DESC"], 
           name: "participants_time_damage_desc_idx"))
  end
end