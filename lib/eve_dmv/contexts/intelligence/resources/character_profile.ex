defmodule EveDmv.Contexts.Intelligence.Resources.CharacterProfile do
  @moduledoc """
  Ash resource for character intelligence profiles.
  Consolidates character data from previous character_intelligence and player_profile contexts.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("character_profiles")
    repo(EveDmv.Repo)

    # Indexes for performance
    custom_indexes do
      index(["character_id"], unique: true)
      index(["corporation_id"])
      index(["alliance_id"])
      index(["threat_score"])
      index(["last_seen"])
      index(["security_status"])
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Basic character information
    attribute(:character_id, :integer, allow_nil?: false)
    attribute(:character_name, :string, allow_nil?: false)
    attribute(:corporation_id, :integer)
    attribute(:corporation_name, :string)
    attribute(:alliance_id, :integer)
    attribute(:alliance_name, :string)

    # Profile metadata
    attribute(:profile_created_at, :utc_datetime_usec, default: &DateTime.utc_now/0)
    attribute(:last_updated, :utc_datetime_usec, default: &DateTime.utc_now/0)
    attribute(:last_seen, :utc_datetime_usec)

    # Combat statistics
    attribute(:total_kills, :integer, default: 0)
    attribute(:total_losses, :integer, default: 0)
    attribute(:kill_death_ratio, :decimal, default: Decimal.new("0.0"))
    attribute(:solo_kills, :integer, default: 0)
    attribute(:solo_losses, :integer, default: 0)
    attribute(:solo_ratio, :decimal, default: Decimal.new("0.0"))

    # ISK metrics
    attribute(:total_isk_destroyed, :decimal, default: Decimal.new("0.0"))
    attribute(:total_isk_lost, :decimal, default: Decimal.new("0.0"))
    attribute(:isk_efficiency, :decimal, default: Decimal.new("0.0"))

    # Activity metrics
    attribute(:activity_level, :atom,
      constraints: [one_of: [:minimal, :low, :moderate, :active, :very_active, :hyperactive]]
    )

    attribute(:active_days, :integer, default: 0)
    attribute(:avg_kills_per_week, :decimal, default: Decimal.new("0.0"))
    attribute(:first_kill_date, :utc_datetime_usec)
    attribute(:last_kill_date, :utc_datetime_usec)

    # Gang preferences
    attribute(:avg_gang_size, :decimal, default: Decimal.new("1.0"))

    attribute(:preferred_gang_size, :atom,
      constraints: [one_of: [:solo, :small_gang, :medium_gang, :fleet]]
    )

    attribute(:gang_participation_ratio, :decimal, default: Decimal.new("0.0"))

    # Ship statistics
    attribute(:ship_types_used, :integer, default: 0)
    attribute(:favorite_ship_type_id, :integer)
    attribute(:favorite_ship_name, :string)
    attribute(:capital_usage_ratio, :decimal, default: Decimal.new("0.0"))

    # Threat assessment
    attribute(:threat_score, :decimal, default: Decimal.new("0.0"))

    attribute(:danger_rating, :atom,
      constraints: [
        one_of: [:minimal, :low, :moderate, :dangerous, :very_dangerous, :extremely_dangerous]
      ]
    )

    attribute(:threat_level, :atom,
      constraints: [one_of: [:minimal, :low, :moderate, :high, :critical]]
    )

    # Classification
    attribute(:pilot_type, :atom,
      constraints: [
        one_of: [
          :elite_solo_hunter,
          :solo_specialist,
          :fleet_pilot,
          :gang_specialist,
          :generalist
        ]
      ]
    )

    attribute(:skill_level, :atom,
      constraints: [one_of: [:novice, :intermediate, :experienced, :veteran, :elite]]
    )

    attribute(:primary_activity, :atom,
      constraints: [one_of: [:inactive, :solo_hunter, :fleet_pilot, :mixed]]
    )

    # Behavioral patterns
    attribute(:timezone_estimate, :string)
    attribute(:predictability_score, :decimal, default: Decimal.new("0.5"))
    attribute(:primary_region, :string)
    attribute(:active_regions, :integer, default: 1)

    attribute(:roaming_range, :atom,
      constraints: [one_of: [:local, :regional, :inter_regional, :nomadic]]
    )

    # Security and reputation
    attribute(:security_status, :atom,
      constraints: [one_of: [:criminal, :suspect, :neutral, :positive]]
    )

    attribute(:bounty_value, :decimal, default: Decimal.new("0.0"))
    attribute(:faction_warfare_participation, :boolean, default: false)

    # Analytics metadata
    attribute(:data_quality_score, :decimal, default: Decimal.new("0.0"))

    attribute(:analysis_confidence, :atom,
      constraints: [one_of: [:very_low, :low, :medium, :high, :very_high]]
    )

    attribute(:last_analysis_run, :utc_datetime_usec)

    # JSON fields for complex data
    attribute(:threat_breakdown, :map)
    attribute(:ship_preferences, :map)
    attribute(:behavioral_patterns, :map)
    attribute(:performance_metrics, :map)
    attribute(:notable_patterns, {:array, :string}, default: [])

    timestamps()
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :character_id,
        :character_name,
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :total_kills,
        :total_losses,
        :kill_death_ratio,
        :solo_kills,
        :solo_losses,
        :solo_ratio,
        :total_isk_destroyed,
        :total_isk_lost,
        :isk_efficiency,
        :activity_level,
        :active_days,
        :avg_kills_per_week,
        :first_kill_date,
        :last_kill_date,
        :avg_gang_size,
        :preferred_gang_size,
        :gang_participation_ratio,
        :ship_types_used,
        :favorite_ship_type_id,
        :favorite_ship_name,
        :capital_usage_ratio,
        :threat_score,
        :danger_rating,
        :threat_level,
        :pilot_type,
        :skill_level,
        :primary_activity,
        :timezone_estimate,
        :predictability_score,
        :primary_region,
        :active_regions,
        :roaming_range,
        :security_status,
        :bounty_value,
        :faction_warfare_participation,
        :data_quality_score,
        :analysis_confidence,
        :threat_breakdown,
        :ship_preferences,
        :behavioral_patterns,
        :performance_metrics,
        :notable_patterns
      ])

      change(set_attribute(:last_updated, &DateTime.utc_now/0))
      change(set_attribute(:last_analysis_run, &DateTime.utc_now/0))
    end

    update :update do
      primary?(true)

      accept([
        :character_name,
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :total_kills,
        :total_losses,
        :kill_death_ratio,
        :solo_kills,
        :solo_losses,
        :solo_ratio,
        :total_isk_destroyed,
        :total_isk_lost,
        :isk_efficiency,
        :activity_level,
        :active_days,
        :avg_kills_per_week,
        :first_kill_date,
        :last_kill_date,
        :avg_gang_size,
        :preferred_gang_size,
        :gang_participation_ratio,
        :ship_types_used,
        :favorite_ship_type_id,
        :favorite_ship_name,
        :capital_usage_ratio,
        :threat_score,
        :danger_rating,
        :threat_level,
        :pilot_type,
        :skill_level,
        :primary_activity,
        :timezone_estimate,
        :predictability_score,
        :primary_region,
        :active_regions,
        :roaming_range,
        :security_status,
        :bounty_value,
        :faction_warfare_participation,
        :data_quality_score,
        :analysis_confidence,
        :last_seen,
        :threat_breakdown,
        :ship_preferences,
        :behavioral_patterns,
        :performance_metrics,
        :notable_patterns
      ])

      change(set_attribute(:last_updated, &DateTime.utc_now/0))
    end

    update :update_analysis do
      accept([
        :threat_score,
        :danger_rating,
        :threat_level,
        :pilot_type,
        :skill_level,
        :primary_activity,
        :predictability_score,
        :data_quality_score,
        :analysis_confidence,
        :threat_breakdown,
        :ship_preferences,
        :behavioral_patterns,
        :performance_metrics,
        :notable_patterns
      ])

      change(set_attribute(:last_updated, &DateTime.utc_now/0))
      change(set_attribute(:last_analysis_run, &DateTime.utc_now/0))
    end

    update :update_stats do
      accept([
        :total_kills,
        :total_losses,
        :kill_death_ratio,
        :solo_kills,
        :solo_losses,
        :solo_ratio,
        :total_isk_destroyed,
        :total_isk_lost,
        :isk_efficiency,
        :activity_level,
        :active_days,
        :avg_kills_per_week,
        :last_kill_date,
        :avg_gang_size,
        :preferred_gang_size,
        :gang_participation_ratio,
        :ship_types_used,
        :favorite_ship_type_id,
        :favorite_ship_name,
        :capital_usage_ratio,
        :last_seen
      ])

      change(set_attribute(:last_updated, &DateTime.utc_now/0))
    end
  end

  preparations do
    prepare(build(sort: [:character_name]))
  end

  identities do
    identity(:character_id, [:character_id])
  end

  validations do
    validate(compare(:total_kills, greater_than_or_equal_to: 0))
    validate(compare(:total_losses, greater_than_or_equal_to: 0))
    validate(compare(:threat_score, greater_than_or_equal_to: 0))
    validate(compare(:threat_score, less_than_or_equal_to: 100))
    validate(compare(:isk_efficiency, greater_than_or_equal_to: 0))
    validate(compare(:isk_efficiency, less_than_or_equal_to: 100))
    validate(compare(:predictability_score, greater_than_or_equal_to: 0))
    validate(compare(:predictability_score, less_than_or_equal_to: 1))
  end

  code_interface do
    domain(EveDmv.Api)
    define(:create)
    define(:read)
    define(:update)
    define(:destroy)
    define(:update_analysis)
    define(:update_stats)
  end

  policies do
    # Character intelligence profiles are public EVE intel
    policy action_type(:read) do
      description("Character profiles are publicly readable")
      authorize_if(always())
    end

    # Only internal systems/admins can modify character profiles
    policy action_type([:create, :update, :destroy]) do
      description("Only system or admin can modify character profiles")
      authorize_if(actor_attribute_equals(:role, :system))
      authorize_if(actor_attribute_equals(:role, :admin))
    end
  end

  # Custom calculations

  def calculate_kill_death_ratio(kills, losses) when losses > 0 do
    Decimal.div(Decimal.new(kills), Decimal.new(losses))
  end

  def calculate_kill_death_ratio(kills, _losses) do
    Decimal.new(kills)
  end

  def calculate_isk_efficiency(destroyed, lost) do
    total = Decimal.add(destroyed, lost)

    if Decimal.compare(total, Decimal.new(0)) == :gt do
      destroyed
      |> Decimal.div(total)
      |> Decimal.mult(Decimal.new(100))
    else
      Decimal.new(0)
    end
  end

  def classify_activity_level(kills_per_week) do
    weekly_rate = Decimal.to_float(kills_per_week)

    cond do
      weekly_rate >= 50 -> :hyperactive
      weekly_rate >= 20 -> :very_active
      weekly_rate >= 10 -> :active
      weekly_rate >= 3 -> :moderate
      weekly_rate >= 1 -> :low
      true -> :minimal
    end
  end

  def determine_pilot_type(solo_ratio, gang_ratio, fleet_ratio) do
    solo = Decimal.to_float(solo_ratio)
    gang = Decimal.to_float(gang_ratio)
    fleet = Decimal.to_float(fleet_ratio)

    cond do
      solo > 0.8 -> :elite_solo_hunter
      solo > 0.6 -> :solo_specialist
      fleet > 0.6 -> :fleet_pilot
      gang > 0.4 -> :gang_specialist
      true -> :generalist
    end
  end

  def assess_skill_level(kd_ratio, isk_efficiency, ship_diversity) do
    kd = Decimal.to_float(kd_ratio)
    eff = Decimal.to_float(isk_efficiency)

    composite_score = kd * 0.4 + eff * 0.4 + ship_diversity * 0.2

    cond do
      composite_score > 80 -> :elite
      composite_score > 60 -> :veteran
      composite_score > 40 -> :experienced
      composite_score > 20 -> :intermediate
      true -> :novice
    end
  end
end
