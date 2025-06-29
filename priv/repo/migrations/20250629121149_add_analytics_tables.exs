defmodule EveDmv.Repo.Migrations.AddAnalyticsTables do
  @moduledoc """
  Creates analytics tables for player and ship statistics.
  """

  use Ecto.Migration

  def change do
    create table(:player_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :character_id, :integer, null: false
      add :character_name, :string, null: false
      
      # Basic Performance Metrics
      add :total_kills, :integer, default: 0
      add :total_losses, :integer, default: 0
      add :solo_kills, :integer, default: 0
      add :solo_losses, :integer, default: 0
      add :gang_kills, :integer, default: 0
      add :gang_losses, :integer, default: 0

      # ISK Metrics
      add :total_isk_destroyed, :decimal, precision: 20, scale: 2, default: 0.0
      add :total_isk_lost, :decimal, precision: 20, scale: 2, default: 0.0

      # Calculated Performance Ratios
      add :kill_death_ratio, :decimal, precision: 10, scale: 2, default: 0.0
      add :isk_efficiency_percent, :decimal, precision: 5, scale: 2, default: 0.0
      add :solo_performance_ratio, :decimal, precision: 10, scale: 2, default: 0.0

      # Activity Metrics
      add :first_kill_date, :utc_datetime
      add :last_kill_date, :utc_datetime
      add :active_days, :integer, default: 0
      add :avg_kills_per_week, :decimal, precision: 8, scale: 2, default: 0.0

      # Ship Diversity
      add :ship_types_used, :integer, default: 0
      add :favorite_ship_type_id, :integer
      add :favorite_ship_name, :string

      # Gang Behavior
      add :avg_gang_size, :decimal, precision: 6, scale: 2, default: 1.0
      add :preferred_gang_size, :string, default: "solo"

      # Geographic Activity
      add :active_regions, :integer, default: 0
      add :home_region_id, :integer
      add :home_region_name, :string

      # Risk and Skill Indicators
      add :danger_rating, :integer, default: 1
      add :primary_activity, :string, default: "solo_pvp"

      # Temporal Tracking
      add :stats_period_start, :utc_datetime
      add :stats_period_end, :utc_datetime
      add :last_updated, :utc_datetime

      timestamps()
    end

    create table(:ship_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ship_type_id, :integer, null: false
      add :ship_name, :string, null: false

      # Ship Classification
      add :ship_category, :string, null: false
      add :tech_level, :integer, default: 1
      add :meta_level, :integer, default: 0
      add :is_capital, :boolean, default: false

      # Basic Combat Statistics
      add :total_kills, :integer, default: 0
      add :total_losses, :integer, default: 0
      add :pilots_flown, :integer, default: 0

      # ISK Performance
      add :total_isk_destroyed, :decimal, precision: 20, scale: 2, default: 0.0
      add :total_isk_lost, :decimal, precision: 20, scale: 2, default: 0.0
      add :avg_kill_value, :decimal, precision: 15, scale: 2, default: 0.0
      add :avg_loss_value, :decimal, precision: 15, scale: 2, default: 0.0

      # Performance Metrics
      add :kill_death_ratio, :decimal, precision: 10, scale: 2, default: 0.0
      add :isk_efficiency_percent, :decimal, precision: 5, scale: 2, default: 0.0
      add :survival_rate_percent, :decimal, precision: 5, scale: 2, default: 0.0

      # Combat Behavior Analysis
      add :avg_damage_dealt, :decimal, precision: 12, scale: 2, default: 0.0
      add :avg_gang_size_when_killing, :decimal, precision: 6, scale: 2, default: 1.0
      add :avg_gang_size_when_dying, :decimal, precision: 6, scale: 2, default: 1.0
      add :solo_kill_percentage, :decimal, precision: 5, scale: 2, default: 0.0

      # Target Analysis
      add :most_killed_ship_type_id, :integer
      add :most_killed_ship_name, :string
      add :most_killed_by_ship_type_id, :integer
      add :most_killed_by_ship_name, :string

      # Geographic and Temporal Patterns
      add :most_active_region_id, :integer
      add :most_active_region_name, :string
      add :peak_activity_hour, :integer

      # Popularity and Usage
      add :usage_rank, :integer
      add :effectiveness_rank, :integer
      add :popularity_trend, :string, default: "stable"

      # Meta Analysis
      add :meta_tier, :string, default: "unranked"
      add :role_classification, :string, default: "mixed"

      # Temporal Tracking
      add :first_seen, :utc_datetime
      add :last_seen, :utc_datetime
      add :stats_period_start, :utc_datetime
      add :stats_period_end, :utc_datetime
      add :last_updated, :utc_datetime

      timestamps()
    end

    # Create indexes for performance
    create unique_index(:player_stats, [:character_id])
    create index(:player_stats, [:total_kills])
    create index(:player_stats, [:total_isk_destroyed])
    create index(:player_stats, [:isk_efficiency_percent])
    create index(:player_stats, [:danger_rating])
    create index(:player_stats, [:last_kill_date])

    create unique_index(:ship_stats, [:ship_type_id])
    create index(:ship_stats, [:ship_category])
    create index(:ship_stats, [:total_kills])
    create index(:ship_stats, [:kill_death_ratio])
    create index(:ship_stats, [:isk_efficiency_percent])
    create index(:ship_stats, [:meta_tier])
    create index(:ship_stats, [:usage_rank])
    create index(:ship_stats, [:effectiveness_rank])
  end
end
