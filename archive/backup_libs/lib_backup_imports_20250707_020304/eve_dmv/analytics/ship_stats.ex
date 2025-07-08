defmodule EveDmv.Analytics.ShipStats do
  use Ash.Resource,

  alias EveDmv.Analytics.PerformanceCalculator
  @moduledoc """
  Ash resource for ship type performance statistics.

  Tracks effectiveness, popularity, and meta analysis for different ship types
  across all killmail data. Provides insights into ship balance, popular fits,
  and combat effectiveness.
  """

    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer


  postgres do
    table("ship_stats")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :ship_type_id, :integer do
      allow_nil?(false)
    end

    attribute :ship_name, :string do
      allow_nil?(false)
    end

    # Ship Classification
    attribute :ship_category, :string do
      allow_nil?(false)
    end

    attribute(:tech_level, :integer, default: 1)
    attribute(:meta_level, :integer, default: 0)
    attribute(:is_capital, :boolean, default: false)

    # Basic Combat Statistics
    attribute(:total_kills, :integer, default: 0)
    attribute(:total_losses, :integer, default: 0)
    attribute(:solo_kills, :integer, default: 0)
    # Unique pilots who flew this ship
    attribute(:pilots_flown, :integer, default: 0)

    # ISK Performance
    attribute :total_isk_destroyed, :decimal do
      constraints(precision: 20, scale: 2)
      default(0.0)
    end

    attribute :total_isk_lost, :decimal do
      constraints(precision: 20, scale: 2)
      default(0.0)
    end

    attribute :avg_kill_value, :decimal do
      constraints(precision: 15, scale: 2)
      default(0.0)
    end

    attribute :avg_loss_value, :decimal do
      constraints(precision: 15, scale: 2)
      default(0.0)
    end

    # Performance Metrics
    attribute :kill_death_ratio, :decimal do
      constraints(precision: 10, scale: 2)
      default(0.0)
    end

    attribute :isk_efficiency_percent, :decimal do
      constraints(precision: 5, scale: 2)
      default(0.0)
    end

    attribute :survival_rate_percent, :decimal do
      constraints(precision: 5, scale: 2)
      default(0.0)
    end

    # Combat Behavior Analysis
    attribute :avg_damage_dealt, :decimal do
      constraints(precision: 12, scale: 2)
      default(0.0)
    end

    attribute :avg_gang_size_when_killing, :decimal do
      constraints(precision: 6, scale: 2)
      default(1.0)
    end

    attribute :avg_gang_size_when_dying, :decimal do
      constraints(precision: 6, scale: 2)
      default(1.0)
    end

    attribute :solo_kill_percentage, :decimal do
      constraints(precision: 5, scale: 2)
      default(0.0)
    end

    # Target Analysis
    attribute(:most_killed_ship_type_id, :integer)
    attribute(:most_killed_ship_name, :string)
    attribute(:most_killed_by_ship_type_id, :integer)
    attribute(:most_killed_by_ship_name, :string)

    # Geographic and Temporal Patterns
    attribute(:most_active_region_id, :integer)
    attribute(:most_active_region_name, :string)
    # 0-23 UTC
    attribute(:peak_activity_hour, :integer)

    # Popularity and Usage
    # Rank by total usage (kills + losses)
    attribute(:usage_rank, :integer)
    # Rank by K/D ratio
    attribute(:effectiveness_rank, :integer)
    attribute(:popularity_trend, :string, default: "stable")

    # Meta Analysis
    attribute(:meta_tier, :string, default: "unranked")

    attribute(:role_classification, :string, default: "mixed")

    # Temporal Tracking
    attribute(:first_seen, :utc_datetime)
    attribute(:last_seen, :utc_datetime)
    attribute(:stats_period_start, :utc_datetime)
    attribute(:stats_period_end, :utc_datetime)
    attribute(:last_updated, :utc_datetime, default: &DateTime.utc_now/0)

    timestamps()
  end

  relationships do
    # Note: ship_type_id references EVE item type IDs
    # This is intentionally not a foreign key relationship for flexibility
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :ship_type_id,
        :ship_name,
        :ship_category,
        :tech_level,
        :meta_level,
        :is_capital,
        :total_kills,
        :total_losses,
        :solo_kills,
        :pilots_flown,
        :total_isk_destroyed,
        :total_isk_lost,
        :avg_damage_dealt,
        :avg_gang_size_when_killing,
        :avg_gang_size_when_dying,
        :most_killed_ship_type_id,
        :most_killed_ship_name,
        :most_killed_by_ship_type_id,
        :most_killed_by_ship_name,
        :most_active_region_id,
        :most_active_region_name,
        :peak_activity_hour,
        :meta_tier,
        :role_classification,
        :first_seen,
        :last_seen,
        :stats_period_start,
        :stats_period_end
      ])

      change(fn changeset, _context ->
        total_kills = Ash.Changeset.get_argument_or_attribute(changeset, :total_kills) || 0
        total_losses = Ash.Changeset.get_argument_or_attribute(changeset, :total_losses) || 0

        total_isk_destroyed =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_destroyed) || 0.0

        total_isk_lost =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_lost) || 0.0

        # Calculate performance metrics using shared calculator
        kill_death_ratio =
          PerformanceCalculator.calculate_kill_death_ratio(total_kills, total_losses)

        isk_efficiency =
          PerformanceCalculator.calculate_isk_efficiency(total_isk_destroyed, total_isk_lost)

        survival_rate = PerformanceCalculator.calculate_survival_rate(total_kills, total_losses)

        avg_kill_value =
          PerformanceCalculator.calculate_average_kill_value(total_isk_destroyed, total_kills)

        avg_loss_value =
          PerformanceCalculator.calculate_average_loss_value(total_isk_lost, total_losses)

        changeset
        |> Ash.Changeset.change_attribute(:kill_death_ratio, kill_death_ratio)
        |> Ash.Changeset.change_attribute(:isk_efficiency_percent, isk_efficiency)
        |> Ash.Changeset.change_attribute(:survival_rate_percent, survival_rate)
        |> Ash.Changeset.change_attribute(:avg_kill_value, avg_kill_value)
        |> Ash.Changeset.change_attribute(:avg_loss_value, avg_loss_value)
        |> Ash.Changeset.change_attribute(:last_updated, DateTime.utc_now())
      end)
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      accept([
        :total_kills,
        :total_losses,
        :solo_kills,
        :pilots_flown,
        :total_isk_destroyed,
        :total_isk_lost,
        :avg_damage_dealt,
        :avg_gang_size_when_killing,
        :avg_gang_size_when_dying,
        :most_killed_ship_type_id,
        :most_killed_ship_name,
        :most_killed_by_ship_type_id,
        :most_killed_by_ship_name,
        :most_active_region_id,
        :most_active_region_name,
        :peak_activity_hour,
        :usage_rank,
        :effectiveness_rank,
        :popularity_trend,
        :meta_tier,
        :role_classification,
        :first_seen,
        :last_seen,
        :stats_period_start,
        :stats_period_end
      ])

      change(fn changeset, _context ->
        total_kills = Ash.Changeset.get_argument_or_attribute(changeset, :total_kills) || 0
        total_losses = Ash.Changeset.get_argument_or_attribute(changeset, :total_losses) || 0

        total_isk_destroyed =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_destroyed) || 0.0

        total_isk_lost =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_lost) || 0.0

        # Recalculate performance metrics using shared calculator
        kill_death_ratio =
          PerformanceCalculator.calculate_kill_death_ratio(total_kills, total_losses)

        isk_efficiency =
          PerformanceCalculator.calculate_isk_efficiency(total_isk_destroyed, total_isk_lost)

        survival_rate = PerformanceCalculator.calculate_survival_rate(total_kills, total_losses)

        avg_kill_value =
          PerformanceCalculator.calculate_average_kill_value(total_isk_destroyed, total_kills)

        avg_loss_value =
          PerformanceCalculator.calculate_average_loss_value(total_isk_lost, total_losses)

        # Calculate solo kill percentage using shared calculator
        solo_kills = Ash.Changeset.get_argument_or_attribute(changeset, :solo_kills) || 0

        solo_kill_percentage =
          PerformanceCalculator.calculate_solo_kill_percentage(solo_kills, total_kills)

        changeset
        |> Ash.Changeset.change_attribute(:kill_death_ratio, kill_death_ratio)
        |> Ash.Changeset.change_attribute(:isk_efficiency_percent, isk_efficiency)
        |> Ash.Changeset.change_attribute(:survival_rate_percent, survival_rate)
        |> Ash.Changeset.change_attribute(:avg_kill_value, avg_kill_value)
        |> Ash.Changeset.change_attribute(:avg_loss_value, avg_loss_value)
        |> Ash.Changeset.change_attribute(:solo_kill_percentage, solo_kill_percentage)
        |> Ash.Changeset.change_attribute(:last_updated, DateTime.utc_now())
      end)
    end

    # Popular Ships
    read :most_popular do
      argument(:limit, :integer, default: 50)
      argument(:category, :string)

      filter(expr(total_kills + total_losses > 10))
      filter(expr(if is_nil(^arg(:category)), do: true, else: ship_category == ^arg(:category)))
    end

    # Most Effective Ships
    read :most_effective do
      argument(:limit, :integer, default: 50)
      argument(:min_usage, :integer, default: 50)
      argument(:category, :string)

      filter(expr(total_kills + total_losses >= ^arg(:min_usage)))
      filter(expr(if is_nil(^arg(:category)), do: true, else: ship_category == ^arg(:category)))
    end

    # Best ISK Performers
    read :best_isk_efficiency do
      argument(:limit, :integer, default: 50)
      argument(:min_usage, :integer, default: 25)
      argument(:category, :string)

      filter(expr(total_kills + total_losses >= ^arg(:min_usage)))
      filter(expr(if is_nil(^arg(:category)), do: true, else: ship_category == ^arg(:category)))
    end

    # Meta Tier Ships
    read :by_meta_tier do
      argument(:tier, :string, allow_nil?: false)
      filter(expr(meta_tier == ^arg(:tier)))
    end

    # Ship Category Analysis
    read :by_category do
      argument(:category, :string, allow_nil?: false)
      filter(expr(ship_category == ^arg(:category)))
    end

    # Rising/Declining Ships
    read :by_trend do
      argument(:trend, :string, allow_nil?: false)
      filter(expr(popularity_trend == ^arg(:trend)))
    end

    # High Activity Ships
    read :most_active do
      argument(:limit, :integer, default: 50)
      argument(:days, :integer, default: 30)

      filter(expr(total_kills + total_losses > 0))
    end

    # Ship vs Ship Analysis
    read :countered_by do
      argument(:ship_type_id, :integer, allow_nil?: false)
      filter(expr(most_killed_by_ship_type_id == ^arg(:ship_type_id)))
    end

    read :counters do
      argument(:ship_type_id, :integer, allow_nil?: false)
      filter(expr(most_killed_ship_type_id == ^arg(:ship_type_id)))
    end
  end

  identities do
    identity(:unique_ship, [:ship_type_id])
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
    define(:read, action: :read)
    define(:most_popular, action: :most_popular, args: [:limit, :category])
    define(:most_effective, action: :most_effective, args: [:limit, :min_usage, :category])

    define(:best_isk_efficiency,
      action: :best_isk_efficiency,
      args: [:limit, :min_usage, :category]
    )

    define(:by_meta_tier, action: :by_meta_tier, args: [:tier])
    define(:by_category, action: :by_category, args: [:category])
    define(:by_trend, action: :by_trend, args: [:trend])
    define(:most_active, action: :most_active, args: [:limit, :days])
  end
end
