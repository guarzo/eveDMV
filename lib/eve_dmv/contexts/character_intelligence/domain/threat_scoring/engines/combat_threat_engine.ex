defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.CombatThreatEngine do
  @moduledoc """
  Combat threat scoring engine for analyzing combat skill and effectiveness.

  Analyzes kill/death ratios, ISK efficiency, survival rates, target selection,
  and damage efficiency to determine combat threat level.
  """

  require Logger

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
    survival_rate = calculate_survival_rate(combat_data)

    # Target selection quality (attacking valuable targets)
    target_quality = analyze_target_selection_quality(attacker_kms)

    # Damage efficiency in fights
    damage_efficiency = calculate_damage_efficiency(attacker_kms)

    # Weighted combat skill score
    raw_score =
      normalize_score(kd_ratio, 0, 5) * 0.25 +
        normalize_score(isk_efficiency, 0, 3) * 0.25 +
        survival_rate * 0.20 +
        target_quality * 0.15 +
        damage_efficiency * 0.15

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
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
          estimate_killmail_value(km) > 100_000_000  # Targets worth >100M ISK
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
  Calculate damage efficiency in combat.
  """
  def calculate_damage_efficiency(attacker_killmails) do
    Logger.debug("Calculating damage efficiency for #{length(attacker_killmails)} killmails")

    if Enum.empty?(attacker_killmails) do
      0.5
    else
      total_damage_contribution =
        attacker_killmails
        |> Enum.map(&extract_damage_contribution/1)
        |> Enum.sum()

      average_contribution = total_damage_contribution / length(attacker_killmails)

      # Normalize damage contribution (higher is better)
      # 15% average contribution = 1.0 score
      min(1.0, average_contribution / 0.15)
    end
  end

  @doc """
  Calculate survival rate based on combat data.
  """
  def calculate_survival_rate(combat_data) do
    Logger.debug("Calculating survival rate")

    all_killmails = Map.get(combat_data, :killmails, [])
    victim_killmails = Map.get(combat_data, :victim_killmails, [])

    total_engagements = length(all_killmails)
    deaths = length(victim_killmails)

    if total_engagements > 0 do
      (total_engagements - deaths) / total_engagements
    else
      0.5  # Neutral score for no data
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

    cond do
      ship_type_id in 580..700 -> 5_000_000          # Frigates: 5M ISK
      ship_type_id in 420..450 -> 15_000_000         # Destroyers: 15M ISK
      ship_type_id in 620..650 -> 50_000_000         # Cruisers: 50M ISK
      ship_type_id in 540..570 -> 150_000_000        # Battlecruisers: 150M ISK
      ship_type_id in 640..670 -> 300_000_000        # Battleships: 300M ISK
      ship_type_id in 19_720..19_740 -> 2_000_000_000 # Capitals: 2B ISK
      true -> 25_000_000                              # Default: 25M ISK
    end
  end

  defp tactical_target?(ship_type_id) do
    # Ships that are tactically important targets
    ship_type_id in [
      # Logistics ships (very high priority)
      11_978, 11_987, 11_985, 12_003,  # Guardian, Basilisk, Oneiros, Scimitar
      # Force Recon (high priority)
      11_957, 11_958, 11_959, 11_961,
      # Command ships
      22_470, 22_852, 17_918, 17_920
    ]
  end

  defp extract_damage_contribution(killmail) do
    # Extract character's damage from killmail
    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_list(attackers) and is_number(total_damage) and total_damage > 0 ->
        character_damage =
          attackers
          |> Enum.find(&(&1["character_id"] == killmail.victim_character_id))
          |> case do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end

        character_damage / total_damage

      _ ->
        0.0
    end
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

  defp normalize_to_10_scale(score) do
    min(10.0, max(0.0, score * 10))
  end

  # Private helper functions - removed unused generate_combat_skill_insights/4
  # Function was defined but never called in the module
end
