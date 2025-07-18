defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.CombatThreatEngine do
  @moduledoc """
  Combat threat scoring engine for analyzing combat skill and effectiveness.

  Analyzes kill/death ratios, ISK efficiency, survival rates, target selection,
  and damage efficiency to determine combat threat level.
  """

  require Logger
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedCalculations

  # Score calculation weights
  @kd_ratio_weight 0.25
  @isk_efficiency_weight 0.25
  @survival_rate_weight 0.20
  @target_quality_weight 0.15
  @damage_efficiency_weight 0.15

  # Ship type ID ranges
  @ship_type_ranges %{
    frigate: 580..700,
    destroyer: 420..450,
    cruiser: 620..650,
    battlecruiser: 540..570,
    battleship: 640..670,
    capital: 19_720..19_740
  }

  # Ship valuation estimates
  @ship_values %{
    frigate: 5_000_000,
    destroyer: 15_000_000,
    cruiser: 50_000_000,
    battlecruiser: 150_000_000,
    battleship: 300_000_000,
    capital: 2_000_000_000,
    default: 25_000_000
  }

  # Tactical target ship IDs
  @tactical_ship_ids %{
    logistics: [11_978, 11_987, 11_985, 12_003],
    force_recon: [11_957, 11_958, 11_959, 11_961],
    command_ships: [22_470, 22_852, 17_918, 17_920],
    interdictors: [11_995, 11_993, 22_460, 22_464],
    heavy_interdictors: [12_013, 12_015, 12_017, 12_019],
    strategic_cruisers: [29_984, 29_986, 29_988, 29_990]
  }

  @doc """
  Calculate combat skill score based on combat data.
  """
  def calculate_combat_skill_score(combat_data) do
    Logger.debug("Calculating combat skill score")

    victim_kms = Map.get(combat_data, :victim_killmails, [])
    attacker_kms = Map.get(combat_data, :attacker_killmails, [])

    # Kill/Death ratio with sophisticated weighting
    kills = length(attacker_kms)
    deaths = length(victim_kms)
    kd_ratio = if deaths > 0, do: kills / deaths, else: min(kills, 10.0)

    # ISK efficiency (kills vs losses)
    isk_destroyed = calculate_total_isk_destroyed(attacker_kms)
    isk_lost = calculate_total_isk_lost(victim_kms)

    isk_efficiency =
      if isk_lost > 0, do: isk_destroyed / isk_lost, else: min(isk_destroyed / 1_000_000, 10.0)

    # Survival analysis
    survival_rate = SharedCalculations.calculate_survival_rate(combat_data, victim_kms)

    # Target selection quality (attacking valuable targets)
    target_quality = analyze_target_selection_quality(attacker_kms)

    # Damage efficiency in fights
    damage_efficiency = SharedCalculations.calculate_damage_efficiency(attacker_kms)

    # Weighted combat skill score
    raw_score =
      normalize_score(kd_ratio, 0, 5) * @kd_ratio_weight +
        normalize_score(isk_efficiency, 0, 3) * @isk_efficiency_weight +
        survival_rate * @survival_rate_weight +
        target_quality * @target_quality_weight +
        damage_efficiency * @damage_efficiency_weight

    %{
      raw_score: raw_score,
      normalized_score: SharedCalculations.normalize_to_10_scale(raw_score),
      components: %{
        kd_ratio: kd_ratio,
        isk_efficiency: isk_efficiency,
        survival_rate: survival_rate,
        target_quality: target_quality,
        damage_efficiency: damage_efficiency,
        total_killmails: length(attacker_kms) + length(victim_kms)
      },
      insights: generate_combat_skill_insights(raw_score, kd_ratio, isk_efficiency, survival_rate)
    }
  end

  @doc """
  Analyze target selection quality.
  """
  def analyze_target_selection_quality(attacker_killmails) do
    Logger.debug("Analyzing target selection quality for #{length(attacker_killmails)} killmails")

    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Analyze value and tactical importance of targets
      valuable_targets =
        Enum.count(attacker_killmails, fn km ->
          # Targets worth >100M ISK
          estimate_killmail_value(km) > 100_000_000
        end)

      tactical_targets =
        Enum.count(attacker_killmails, fn km ->
          tactical_target?(km.victim_ship_type_id)
        end)

      total_kills = length(attacker_killmails)

      # Weight valuable and tactical targets
      quality_score =
        (valuable_targets * 1.5 + tactical_targets * 1.2 + total_kills) / (total_kills * 2.5)

      min(1.0, quality_score)
    end
  end

  @doc """
  Calculate total ISK destroyed from killmails.
  """
  def calculate_total_isk_destroyed(attacker_killmails) do
    Logger.debug("Calculating total ISK destroyed for #{length(attacker_killmails)} killmails")

    # Simplified ISK calculation - would use actual ship values in production
    attacker_killmails
    |> Enum.map(&estimate_killmail_value/1)
    |> Enum.sum()
  end

  @doc """
  Calculate total ISK lost from killmails.
  """
  def calculate_total_isk_lost(victim_killmails) do
    Logger.debug("Calculating total ISK lost for #{length(victim_killmails)} killmails")

    victim_killmails
    |> Enum.map(&estimate_killmail_value/1)
    |> Enum.sum()
  end

  # Private helper functions

  defp estimate_killmail_value(killmail) do
    # Heuristic ship value estimation based on type
    ship_type_id = killmail.victim_ship_type_id

    # Find which ship class this type ID belongs to
    ship_class =
      @ship_type_ranges
      |> Enum.find(fn {_class, range} -> ship_type_id in range end)
      |> case do
        {class, _range} -> class
        nil -> :default
      end

    # Return the corresponding value
    Map.get(@ship_values, ship_class, @ship_values.default)
  end

  defp tactical_target?(ship_type_id) do
    # Ships that are tactically important targets
    # Check if the ship type ID is in any of the tactical ship ID lists
    @tactical_ship_ids
    |> Map.values()
    |> Enum.any?(fn ship_ids -> ship_type_id in ship_ids end)
  end

  defp generate_combat_skill_insights(raw_score, kd_ratio, isk_efficiency, survival_rate) do
    insights = []

    insights =
      if kd_ratio > 3.0 do
        ["Excellent kill/death ratio (#{Float.round(kd_ratio, 1)}:1)" | insights]
      else
        insights
      end

    insights =
      if isk_efficiency > 2.0 do
        ["Strong ISK efficiency - destroys more value than lost" | insights]
      else
        insights
      end

    insights =
      if survival_rate > 0.8 do
        ["High survival rate (#{round(survival_rate * 100)}%) - good at disengaging" | insights]
      else
        insights
      end

    insights =
      if raw_score > 0.8 do
        ["Elite combat performance across all metrics" | insights]
      else
        insights
      end

    insights
  end

  defp normalize_score(value, min_val, max_val) do
    clamped_value = min(max_val, max(min_val, value))
    (clamped_value - min_val) / (max_val - min_val)
  end

  # Private helper functions - removed unused generate_combat_skill_insights/4
  # Function was defined but never called in the module
end
