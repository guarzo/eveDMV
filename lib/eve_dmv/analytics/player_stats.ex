defmodule EveDmv.Analytics.PlayerStats do
  @moduledoc """
  Ash resource for player (character) PvP performance statistics.

  Aggregates statistics across all characters for leaderboards, rankings,
  and overall PvP performance tracking. Supplements the intelligence-focused
  CharacterStats with player-facing analytics.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("player_stats")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :character_id, :integer do
      allow_nil?(false)
    end

    attribute :character_name, :string do
      allow_nil?(false)
    end

    # Basic Performance Metrics
    attribute(:total_kills, :integer, default: 0)
    attribute(:total_losses, :integer, default: 0)
    attribute(:solo_kills, :integer, default: 0)
    attribute(:solo_losses, :integer, default: 0)
    attribute(:gang_kills, :integer, default: 0)
    attribute(:gang_losses, :integer, default: 0)

    # ISK Metrics
    attribute :total_isk_destroyed, :decimal do
      constraints(precision: 20, scale: 2)
      default(0.0)
    end

    attribute :total_isk_lost, :decimal do
      constraints(precision: 20, scale: 2)
      default(0.0)
    end

    # Calculated Performance Ratios
    attribute :kill_death_ratio, :decimal do
      constraints(precision: 10, scale: 2)
      default(0.0)
    end

    attribute :isk_efficiency_percent, :decimal do
      constraints(precision: 5, scale: 2)
      default(0.0)
    end

    attribute :solo_performance_ratio, :decimal do
      constraints(precision: 10, scale: 2)
      default(0.0)
    end

    # Activity Metrics
    attribute(:first_kill_date, :utc_datetime)
    attribute(:last_kill_date, :utc_datetime)
    attribute(:active_days, :integer, default: 0)

    attribute :avg_kills_per_week, :decimal do
      constraints(precision: 8, scale: 2)
      default(0.0)
    end

    # Ship Diversity
    attribute(:ship_types_used, :integer, default: 0)
    attribute(:favorite_ship_type_id, :integer)
    attribute(:favorite_ship_name, :string)

    # Gang Behavior
    attribute :avg_gang_size, :decimal do
      constraints(precision: 6, scale: 2)
      default(1.0)
    end

    attribute(:preferred_gang_size, :string, default: "solo")

    # Geographic Activity
    attribute(:active_regions, :integer, default: 0)
    attribute(:home_region_id, :integer)
    attribute(:home_region_name, :string)

    # Risk and Skill Indicators
    attribute(:danger_rating, :integer, default: 1)

    attribute(:primary_activity, :string, default: "solo_pvp")

    # Temporal Tracking
    attribute(:stats_period_start, :utc_datetime)
    attribute(:stats_period_end, :utc_datetime)
    attribute(:last_updated, :utc_datetime, default: &DateTime.utc_now/0)

    timestamps()
  end

  relationships do
    # Note: character_id references EVE character IDs, not User IDs
    # This is intentionally not a foreign key relationship since
    # we track statistics for characters that may not be registered users
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :character_id,
        :character_name,
        :total_kills,
        :total_losses,
        :solo_kills,
        :solo_losses,
        :gang_kills,
        :gang_losses,
        :total_isk_destroyed,
        :total_isk_lost,
        :first_kill_date,
        :last_kill_date,
        :active_days,
        :ship_types_used,
        :favorite_ship_type_id,
        :favorite_ship_name,
        :avg_gang_size,
        :preferred_gang_size,
        :active_regions,
        :home_region_id,
        :home_region_name,
        :danger_rating,
        :primary_activity,
        :stats_period_start,
        :stats_period_end
      ])

      change(fn changeset, _context ->
        character_id = Ash.Changeset.get_argument_or_attribute(changeset, :character_id)
        character_name = Ash.Changeset.get_argument_or_attribute(changeset, :character_name)
        total_kills = Ash.Changeset.get_argument_or_attribute(changeset, :total_kills) || 0
        total_losses = Ash.Changeset.get_argument_or_attribute(changeset, :total_losses) || 0
        solo_kills = Ash.Changeset.get_argument_or_attribute(changeset, :solo_kills) || 0
        solo_losses = Ash.Changeset.get_argument_or_attribute(changeset, :solo_losses) || 0

        total_isk_destroyed =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_destroyed) || 0.0

        total_isk_lost =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_lost) || 0.0

        # Calculate performance ratios
        kill_death_ratio =
          if total_losses > 0,
            do: Decimal.div(total_kills, total_losses),
            else: Decimal.new(total_kills)

        total_isk = Decimal.add(total_isk_destroyed, total_isk_lost)

        isk_efficiency =
          if Decimal.gt?(total_isk, 0) do
            Decimal.mult(Decimal.div(total_isk_destroyed, total_isk), 100)
          else
            Decimal.new(0)
          end

        solo_performance =
          if solo_kills + solo_losses > 0 do
            Decimal.div(solo_kills, max(1, solo_losses))
          else
            Decimal.new(0)
          end

        changeset
        |> Ash.Changeset.change_attribute(:kill_death_ratio, kill_death_ratio)
        |> Ash.Changeset.change_attribute(:isk_efficiency_percent, isk_efficiency)
        |> Ash.Changeset.change_attribute(:solo_performance_ratio, solo_performance)
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
        :solo_losses,
        :gang_kills,
        :gang_losses,
        :total_isk_destroyed,
        :total_isk_lost,
        :first_kill_date,
        :last_kill_date,
        :active_days,
        :ship_types_used,
        :favorite_ship_type_id,
        :favorite_ship_name,
        :avg_gang_size,
        :preferred_gang_size,
        :active_regions,
        :home_region_id,
        :home_region_name,
        :danger_rating,
        :primary_activity,
        :stats_period_start,
        :stats_period_end
      ])

      change(fn changeset, _context ->
        total_kills = Ash.Changeset.get_argument_or_attribute(changeset, :total_kills) || 0
        total_losses = Ash.Changeset.get_argument_or_attribute(changeset, :total_losses) || 0
        solo_kills = Ash.Changeset.get_argument_or_attribute(changeset, :solo_kills) || 0
        solo_losses = Ash.Changeset.get_argument_or_attribute(changeset, :solo_losses) || 0

        total_isk_destroyed =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_destroyed) || 0.0

        total_isk_lost =
          Ash.Changeset.get_argument_or_attribute(changeset, :total_isk_lost) || 0.0

        # Recalculate performance ratios
        kill_death_ratio =
          if total_losses > 0,
            do: Decimal.div(total_kills, total_losses),
            else: Decimal.new(total_kills)

        total_isk = Decimal.add(total_isk_destroyed, total_isk_lost)

        isk_efficiency =
          if Decimal.gt?(total_isk, 0) do
            Decimal.mult(Decimal.div(total_isk_destroyed, total_isk), 100)
          else
            Decimal.new(0)
          end

        solo_performance =
          if solo_kills + solo_losses > 0 do
            Decimal.div(solo_kills, max(1, solo_losses))
          else
            Decimal.new(0)
          end

        changeset
        |> Ash.Changeset.change_attribute(:kill_death_ratio, kill_death_ratio)
        |> Ash.Changeset.change_attribute(:isk_efficiency_percent, isk_efficiency)
        |> Ash.Changeset.change_attribute(:solo_performance_ratio, solo_performance)
        |> Ash.Changeset.change_attribute(:last_updated, DateTime.utc_now())
      end)
    end

    read :top_killers do
      argument(:limit, :integer, default: 50)
      filter(expr(total_kills > 0))
    end

    read :top_isk_destroyers do
      argument(:limit, :integer, default: 50)
      filter(expr(total_isk_destroyed > 0))
    end

    read :top_efficiency do
      argument(:limit, :integer, default: 50)
      argument(:min_kills, :integer, default: 10)
      filter(expr(total_kills >= ^arg(:min_kills) and isk_efficiency_percent > 0))
    end

    read :top_solo_performers do
      argument(:limit, :integer, default: 50)
      argument(:min_solo_kills, :integer, default: 5)
      filter(expr(solo_kills >= ^arg(:min_solo_kills)))
    end

    read :most_dangerous do
      argument(:limit, :integer, default: 50)
      filter(expr(danger_rating >= 4))
    end

    read :by_character do
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :active_in_period do
      argument(:start_date, :utc_datetime, allow_nil?: false)
      argument(:end_date, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          last_kill_date >= ^arg(:start_date) and
            first_kill_date <= ^arg(:end_date)
        )
      )
    end
  end

  identities do
    identity(:unique_character, [:character_id])
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
    define(:read, action: :read)
    define(:get_by_character, action: :by_character, args: [:character_id])
    define(:top_killers, action: :top_killers, args: [:limit])
    define(:top_isk_destroyers, action: :top_isk_destroyers, args: [:limit])
    define(:top_efficiency, action: :top_efficiency, args: [:limit, :min_kills])
    define(:top_solo_performers, action: :top_solo_performers, args: [:limit, :min_solo_kills])
    define(:most_dangerous, action: :most_dangerous, args: [:limit])
  end
end
