defmodule EveDmv.Repo.Migrations.AddPerformanceIndexes do
  @moduledoc """
  Add database indexes to improve query performance based on Sprint 5 optimization analysis.
  
  These indexes target the most common query patterns identified in the performance review:
  - Character lookups by corporation
  - Killmail filtering by system and time
  - Participant filtering by character and time
  """
  use Ecto.Migration

  def up do
    # Index for character stats filtering by corporation (used in home defense analyzer)
    create_if_not_exists index(:character_stats, [:corporation_id, :last_calculated_at], 
           name: :idx_character_stats_corporation_calculated)

    # Index for participants filtering by character and time (used in character analysis)
    create_if_not_exists index(:participants, [:character_id, :killmail_time], 
           name: :idx_participants_character_killmail_time)

    # Index for killmail filtering by system and time (used in kill feed)
    create_if_not_exists index(:killmails_enriched, [:solar_system_id, :killmail_time], 
           name: :idx_killmails_enriched_system_time)

    # Index for killmail raw lookups by ID (used in pipeline deduplication)
    create_if_not_exists index(:killmails_raw, [:killmail_id], 
           name: :idx_killmails_raw_killmail_id)

    # Index for participants by killmail (used in enrichment process)
    create_if_not_exists index(:participants, [:killmail_id], 
           name: :idx_participants_killmail_id)

    # Index for character stats by character ID (used frequently in lookups)
    create_if_not_exists index(:character_stats, [:character_id, :last_calculated_at], 
           name: :idx_character_stats_character_id)

    # Composite index for corporation member analysis
    create_if_not_exists index(:participants, [:corporation_id, :character_id, :killmail_time], 
           name: :idx_participants_corp_char_time)
  end

  def down do
    drop_if_exists index(:character_stats, [:corporation_id, :last_calculated_at])
    drop_if_exists index(:participants, [:character_id, :killmail_time])
    drop_if_exists index(:killmails_enriched, [:solar_system_id, :killmail_time])
    drop_if_exists index(:killmails_raw, [:killmail_id])
    drop_if_exists index(:participants, [:killmail_id])
    drop_if_exists index(:character_stats, [:character_id, :last_calculated_at])
    drop_if_exists index(:participants, [:corporation_id, :character_id, :killmail_time])
  end
end