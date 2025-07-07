defmodule EveDmv.Repo.Migrations.CreateMemberActivityIntelligenceTable do
  @moduledoc """
  Creates the member_activity_intelligence table for tracking corporation member
  activity patterns, engagement scoring, and early warning indicators.
  """
  use Ecto.Migration

  def up do
    create table(:member_activity_intelligence, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Member identification
      add :character_id, :integer, null: false
      add :character_name, :string, null: false
      add :corporation_id, :integer, null: false
      add :corporation_name, :string, null: false
      add :alliance_id, :integer
      add :alliance_name, :string

      # Analysis period
      add :activity_period_start, :utc_datetime, null: false
      add :activity_period_end, :utc_datetime, null: false
      add :analysis_generated_at, :utc_datetime, default: fragment("now()")

      # Activity metrics
      add :total_pvp_kills, :integer, default: 0
      add :total_pvp_losses, :integer, default: 0
      add :home_defense_participations, :integer, default: 0
      add :chain_operations_participations, :integer, default: 0
      add :fleet_participations, :integer, default: 0
      add :solo_activities, :integer, default: 0

      # Engagement scoring (0.0-100.0)
      add :engagement_score, :float, default: 0.0
      # increasing, decreasing, stable, irregular
      add :activity_trend, :string, default: "stable"
      # Risk scores (0-100)
      add :burnout_risk_score, :integer, default: 0
      add :disengagement_risk_score, :integer, default: 0

      # Peer comparison metrics
      add :corp_percentile_ranking, :integer, default: 50
      add :peer_comparison_score, :float, default: 0.0

      # JSONB columns for complex data
      add :activity_patterns, :map, default: %{}
      add :participation_metrics, :map, default: %{}
      add :warning_indicators, :map, default: %{}
      add :timezone_analysis, :map, default: %{}

      timestamps()
    end

    # Standard indexes for common queries
    create index(:member_activity_intelligence, [:corporation_id])
    create index(:member_activity_intelligence, [:character_id])
    create index(:member_activity_intelligence, [:activity_period_start])
    create index(:member_activity_intelligence, [:activity_period_end])
    create index(:member_activity_intelligence, [:engagement_score])

    # GIN indexes for JSONB columns
    create index(:member_activity_intelligence, [:activity_patterns], 
                 name: "member_activity_patterns_gin_idx", using: "gin")
    create index(:member_activity_intelligence, [:participation_metrics], 
                 name: "member_participation_metrics_gin_idx", using: "gin")
    create index(:member_activity_intelligence, [:warning_indicators], 
                 name: "member_warning_indicators_gin_idx", using: "gin")
    create index(:member_activity_intelligence, [:timezone_analysis], 
                 name: "member_timezone_analysis_gin_idx", using: "gin")

    # Unique constraint to prevent duplicate analysis for same period
    create unique_index(:member_activity_intelligence, 
                       [:character_id, :activity_period_start, :activity_period_end],
                       name: "member_activity_unique_period_idx")
  end

  def down do
    drop table(:member_activity_intelligence)
  end
end