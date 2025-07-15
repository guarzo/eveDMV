defmodule EveDmv.Contexts.BattleAnalysis.Calculators.PerformanceMetricsCalculator do
  @moduledoc """
  Calculates ship performance metrics for battle analysis.

  Handles the complex calculations for:
  - DPS efficiency (actual vs theoretical damage output)
  - Survivability scores (actual vs expected survival time)
  - Tactical contributions (EWAR, logistics, tackle effectiveness)
  - Role effectiveness (how well ships fulfilled their intended role)
  - Threat assessments (danger level posed by each ship)
  """

  require Logger

  @doc """
  Calculates comprehensive performance metrics for ship instances.
  """
  def calculate_performance_metrics(ship_instances, :all) do
    # Calculate all metrics for comprehensive analysis
    performance_data =
      ship_instances
      |> Enum.map(fn instance ->
        # Enhance instance with detailed analysis
        enhanced_instance = enhance_instance_with_analysis(instance)

        survivability_score = calculate_survivability_score(enhanced_instance)
        dps_efficiency = calculate_dps_efficiency(enhanced_instance)
        tactical_contribution = calculate_tactical_contribution(enhanced_instance)

        %{
          ship_instance: enhanced_instance,
          survivability_score: survivability_score,
          dps_efficiency: dps_efficiency,
          tactical_contribution: tactical_contribution,
          role_effectiveness: calculate_role_effectiveness(enhanced_instance),
          threat_assessment: calculate_threat_assessment(enhanced_instance)
        }
      end)

    {:ok, performance_data}
  end

  def calculate_performance_metrics(ship_instances, metric)
      when metric in [:efficiency, :survivability] do
    # Calculate only specific metrics for performance
    performance_data =
      ship_instances
      |> Enum.map(fn instance ->
        base_data = %{ship_instance: instance}

        case metric do
          :efficiency ->
            Map.put(base_data, :dps_efficiency, calculate_dps_efficiency(instance))

          :survivability ->
            Map.put(base_data, :survivability_score, calculate_survivability_score(instance))
        end
      end)

    {:ok, performance_data}
  end

  @doc """
  Calculates survivability score comparing actual vs expected survival time.
  """
  def calculate_survivability_score(instance) do
    # Handle attackers who survived (no death_time)
    if instance.death_time == nil do
      # Attackers survived the entire battle
      battle_duration_seconds = round(instance.battle_context.battle_duration * 60)
      expected_survival_time = instance.theoretical_stats.expected_survival_time

      %{
        # Survived = above average performance
        raw_score: 1.5,
        context_adjusted_score: 1.5,
        normalized_score: 1.0,
        actual_survival_seconds: battle_duration_seconds,
        expected_survival_seconds: expected_survival_time,
        threat_multiplier: 1.0
      }
    else
      # Calculate how long the ship survived vs expectations
      battle_start_time = estimate_battle_start_time(instance)

      actual_survival_seconds =
        NaiveDateTime.diff(instance.death_time, battle_start_time, :second)

      expected_survival_time = instance.theoretical_stats.expected_survival_time

      # Calculate raw survival ratio
      raw_ratio = actual_survival_seconds / max(expected_survival_time, 1)

      # Adjust for threat environment
      threat_multiplier = calculate_threat_multiplier(instance)
      adjusted_ratio = raw_ratio * threat_multiplier

      # Normalize to 0-1 scale with context
      normalized_score = min(adjusted_ratio / 2.0, 1.0)

      %{
        raw_score: raw_ratio,
        context_adjusted_score: adjusted_ratio,
        normalized_score: normalized_score,
        actual_survival_seconds: actual_survival_seconds,
        expected_survival_seconds: expected_survival_time,
        threat_multiplier: threat_multiplier
      }
    end
  end

  @doc """
  Calculates DPS efficiency comparing actual vs theoretical damage output.
  """
  def calculate_dps_efficiency(instance) do
    theoretical_dps = instance.theoretical_stats.expected_dps

    actual_dps =
      if instance.death_time == nil do
        # Attackers - use damage dealt
        actual_damage = instance.damage_dealt || 0
        battle_duration_seconds = round(instance.battle_context.battle_duration * 60)
        actual_damage / max(battle_duration_seconds, 1)
      else
        # Victims - estimate damage output before death
        survival_time = calculate_survival_time(instance)
        estimated_damage_output = estimate_damage_output_before_death(instance)
        estimated_damage_output / max(survival_time, 1)
      end

    efficiency_ratio = actual_dps / max(theoretical_dps, 1)

    %{
      actual_dps: actual_dps,
      theoretical_dps: theoretical_dps,
      efficiency_ratio: efficiency_ratio,
      # Cap at 200%
      efficiency_percentage: min(efficiency_ratio * 100, 200),
      performance_rating: categorize_dps_performance(efficiency_ratio)
    }
  end

  @doc """
  Calculates tactical contribution score for support roles.
  """
  def calculate_tactical_contribution(instance) do
    # Base contribution factors
    damage_contribution = calculate_damage_contribution(instance)
    support_contribution = calculate_support_contribution(instance)
    positioning_score = calculate_positioning_score(instance)
    coordination_score = calculate_coordination_score(instance)

    # Weight contributions based on ship role
    role_weights = get_role_contribution_weights(instance.estimated_fitting.estimated_role)

    weighted_score =
      damage_contribution * role_weights.damage +
        support_contribution * role_weights.support +
        positioning_score * role_weights.positioning +
        coordination_score * role_weights.coordination

    %{
      overall_contribution: weighted_score,
      damage_contribution: damage_contribution,
      support_contribution: support_contribution,
      positioning_score: positioning_score,
      coordination_score: coordination_score,
      role_weights: role_weights
    }
  end

  @doc """
  Calculates role effectiveness based on how well ship fulfilled its intended role.
  """
  def calculate_role_effectiveness(instance) do
    intended_role = instance.estimated_fitting.estimated_role

    effectiveness_metrics =
      case intended_role do
        "DPS" -> calculate_dps_role_effectiveness(instance)
        "Tackle" -> calculate_tackle_role_effectiveness(instance)
        "Logistics" -> calculate_logistics_role_effectiveness(instance)
        "Support" -> calculate_support_role_effectiveness(instance)
        _ -> calculate_generic_role_effectiveness(instance)
      end

    Map.put(effectiveness_metrics, :intended_role, intended_role)
  end

  @doc """
  Calculates threat assessment score indicating danger level posed by this ship.
  """
  def calculate_threat_assessment(instance) do
    # Multiple threat factors
    damage_threat = calculate_damage_threat(instance)
    disruption_threat = calculate_disruption_threat(instance)
    survival_threat = calculate_survival_threat(instance)
    coordination_threat = calculate_coordination_threat(instance)

    # Combine threats with weights
    overall_threat =
      damage_threat * 0.4 +
        disruption_threat * 0.3 +
        survival_threat * 0.2 +
        coordination_threat * 0.1

    %{
      overall_threat_score: overall_threat,
      threat_level: categorize_threat_level(overall_threat),
      damage_threat: damage_threat,
      disruption_threat: disruption_threat,
      survival_threat: survival_threat,
      coordination_threat: coordination_threat
    }
  end

  # Private calculation helpers

  defp enhance_instance_with_analysis(instance) do
    # Add analysis-specific data to instance
    instance
    |> Map.put(:damage_profile, analyze_damage_profile(instance))
    |> Map.put(:tank_analysis, analyze_tank_profile(instance))
    |> Map.put(:weapon_analysis, analyze_weapon_profile(instance))
  end

  defp analyze_damage_profile(instance) do
    attackers = instance.attackers || []

    damage_breakdown =
      attackers
      |> Enum.group_by(&classify_damage_type(&1.weapon_type_id))
      |> Enum.map(fn {type, attackers_of_type} ->
        total_damage = Enum.sum(Enum.map(attackers_of_type, & &1.damage_done))
        {type, total_damage}
      end)
      |> Map.new()

    primary_damage_type = get_primary_damage_type(damage_breakdown)

    %{
      damage_breakdown: damage_breakdown,
      primary_damage_type: primary_damage_type,
      damage_diversity: calculate_damage_diversity(damage_breakdown)
    }
  end

  defp analyze_tank_profile(instance) do
    # Infer tank type from damage taken profile
    damage_profile = instance.damage_profile || %{}

    %{
      inferred_tank_type: infer_tank_type(damage_profile),
      tank_effectiveness: calculate_tank_effectiveness(instance),
      weaknesses: identify_tank_weaknesses(damage_profile)
    }
  end

  defp analyze_weapon_profile(instance) do
    if instance.death_time == nil && instance.weapon_type_id do
      # Attacker weapon analysis
      %{
        weapon_type_id: instance.weapon_type_id,
        weapon_class: classify_weapon_type(instance.weapon_type_id),
        optimal_range: get_weapon_optimal_range(instance.weapon_type_id),
        damage_type: classify_damage_type(instance.weapon_type_id)
      }
    else
      # Victim weapon analysis from fitting
      analyze_fitting_weapons(instance.estimated_fitting)
    end
  end

  defp estimate_battle_start_time(instance) do
    # Estimate when the battle started relative to this ship's death
    death_time = instance.death_time
    battle_duration_minutes = instance.battle_context.battle_duration
    estimated_start = NaiveDateTime.add(death_time, -round(battle_duration_minutes * 60), :second)
    estimated_start
  end

  defp calculate_threat_multiplier(instance) do
    # Calculate threat environment this ship faced
    attacker_count = length(instance.attackers || [])
    damage_diversity = calculate_damage_diversity(instance.damage_profile.damage_breakdown)

    base_multiplier = 1.0
    # Scale with attacker count
    attacker_multiplier = min(attacker_count / 5.0, 2.0)
    # More diverse = harder to tank
    diversity_multiplier = damage_diversity * 0.5

    base_multiplier + attacker_multiplier + diversity_multiplier
  end

  defp calculate_survival_time(instance) do
    if instance.death_time do
      battle_start = estimate_battle_start_time(instance)
      NaiveDateTime.diff(instance.death_time, battle_start, :second)
    else
      round(instance.battle_context.battle_duration * 60)
    end
  end

  defp estimate_damage_output_before_death(instance) do
    # Estimate damage this ship dealt before dying
    # This is simplified - real implementation would need more battle context
    survival_time = calculate_survival_time(instance)
    theoretical_dps = instance.theoretical_stats.expected_dps
    # Assume 70% uptime while taking damage
    theoretical_dps * survival_time * 0.7
  end

  defp categorize_dps_performance(ratio) do
    cond do
      ratio >= 1.5 -> "Excellent"
      ratio >= 1.2 -> "Good"
      ratio >= 0.8 -> "Average"
      ratio >= 0.5 -> "Below Average"
      true -> "Poor"
    end
  end

  defp calculate_damage_contribution(instance) do
    if instance.death_time == nil do
      # Attacker - use actual damage dealt
      damage_dealt = instance.damage_dealt || 0
      # Rough conversion
      total_battle_damage = instance.battle_context.isk_destroyed * 0.0001
      damage_dealt / max(total_battle_damage, 1)
    else
      # Victim - estimate contribution before death
      estimated_output = estimate_damage_output_before_death(instance)
      total_battle_damage = instance.battle_context.isk_destroyed * 0.0001
      estimated_output / max(total_battle_damage, 1)
    end
  end

  defp calculate_support_contribution(instance) do
    # Simplified support calculation based on role and ship type
    role = instance.estimated_fitting.estimated_role

    case role do
      # High support value
      "Logistics" -> 0.8
      # Medium support value
      "Tackle" -> 0.6
      # Medium support value
      "Support" -> 0.5
      # Low support value for DPS ships
      _ -> 0.2
    end
  end

  defp calculate_positioning_score(instance) do
    # Simplified positioning score based on survival vs damage dealt
    survival_score = instance.survivability_score || %{normalized_score: 0.5}
    damage_contribution = calculate_damage_contribution(instance)

    # Good positioning = high survival + meaningful damage contribution
    (survival_score.normalized_score + damage_contribution) / 2
  end

  defp calculate_coordination_score(_instance) do
    # Simplified coordination score based on timing of death relative to others
    # Real implementation would analyze kill timing patterns
    # Neutral score for now
    0.5
  end

  defp get_role_contribution_weights(role) do
    case role do
      "DPS" -> %{damage: 0.6, support: 0.1, positioning: 0.2, coordination: 0.1}
      "Tackle" -> %{damage: 0.2, support: 0.5, positioning: 0.2, coordination: 0.1}
      "Logistics" -> %{damage: 0.1, support: 0.6, positioning: 0.2, coordination: 0.1}
      "Support" -> %{damage: 0.2, support: 0.4, positioning: 0.2, coordination: 0.2}
      _ -> %{damage: 0.4, support: 0.3, positioning: 0.2, coordination: 0.1}
    end
  end

  defp calculate_dps_role_effectiveness(instance) do
    dps_efficiency = instance.dps_efficiency || calculate_dps_efficiency(instance)
    damage_contribution = calculate_damage_contribution(instance)

    %{
      primary_effectiveness: dps_efficiency.efficiency_ratio,
      secondary_effectiveness: damage_contribution,
      overall_effectiveness: (dps_efficiency.efficiency_ratio + damage_contribution) / 2,
      effectiveness_rating:
        categorize_effectiveness((dps_efficiency.efficiency_ratio + damage_contribution) / 2)
    }
  end

  defp calculate_tackle_role_effectiveness(instance) do
    # Simplified tackle effectiveness
    survival_score = instance.survivability_score || %{normalized_score: 0.5}
    positioning_score = calculate_positioning_score(instance)

    %{
      primary_effectiveness: positioning_score,
      secondary_effectiveness: survival_score.normalized_score,
      overall_effectiveness: (positioning_score + survival_score.normalized_score) / 2,
      effectiveness_rating:
        categorize_effectiveness((positioning_score + survival_score.normalized_score) / 2)
    }
  end

  defp calculate_logistics_role_effectiveness(instance) do
    # Simplified logistics effectiveness
    survival_score = instance.survivability_score || %{normalized_score: 0.5}
    support_contribution = calculate_support_contribution(instance)

    %{
      primary_effectiveness: support_contribution,
      secondary_effectiveness: survival_score.normalized_score,
      overall_effectiveness: (support_contribution + survival_score.normalized_score) / 2,
      effectiveness_rating:
        categorize_effectiveness((support_contribution + survival_score.normalized_score) / 2)
    }
  end

  defp calculate_support_role_effectiveness(instance) do
    # Generic support effectiveness
    support_contribution = calculate_support_contribution(instance)
    coordination_score = calculate_coordination_score(instance)

    %{
      primary_effectiveness: support_contribution,
      secondary_effectiveness: coordination_score,
      overall_effectiveness: (support_contribution + coordination_score) / 2,
      effectiveness_rating:
        categorize_effectiveness((support_contribution + coordination_score) / 2)
    }
  end

  defp calculate_generic_role_effectiveness(instance) do
    # Generic effectiveness calculation
    damage_contribution = calculate_damage_contribution(instance)
    survival_score = instance.survivability_score || %{normalized_score: 0.5}

    %{
      primary_effectiveness: damage_contribution,
      secondary_effectiveness: survival_score.normalized_score,
      overall_effectiveness: (damage_contribution + survival_score.normalized_score) / 2,
      effectiveness_rating:
        categorize_effectiveness((damage_contribution + survival_score.normalized_score) / 2)
    }
  end

  defp categorize_effectiveness(score) do
    cond do
      score >= 0.8 -> "Excellent"
      score >= 0.6 -> "Good"
      score >= 0.4 -> "Average"
      score >= 0.2 -> "Below Average"
      true -> "Poor"
    end
  end

  # Threat calculation helpers

  defp calculate_damage_threat(instance) do
    dps_efficiency = instance.dps_efficiency || calculate_dps_efficiency(instance)
    # Normalize to 0-1 range
    dps_efficiency.efficiency_ratio * 0.5
  end

  defp calculate_disruption_threat(instance) do
    role = instance.estimated_fitting.estimated_role

    case role do
      "Tackle" -> 0.8
      "Support" -> 0.6
      "Logistics" -> 0.7
      _ -> 0.3
    end
  end

  defp calculate_survival_threat(instance) do
    survival_score = instance.survivability_score || %{normalized_score: 0.5}
    survival_score.normalized_score
  end

  defp calculate_coordination_threat(instance) do
    # Ships that survived longer pose ongoing coordination threat
    if instance.death_time == nil do
      # Survived entire battle
      0.8
    else
      survival_time = calculate_survival_time(instance)
      battle_duration = instance.battle_context.battle_duration * 60
      survival_time / battle_duration
    end
  end

  defp categorize_threat_level(threat_score) do
    cond do
      threat_score >= 0.8 -> "Critical"
      threat_score >= 0.6 -> "High"
      threat_score >= 0.4 -> "Medium"
      threat_score >= 0.2 -> "Low"
      true -> "Minimal"
    end
  end

  # Utility helpers

  defp classify_damage_type(weapon_type_id) when is_nil(weapon_type_id), do: "Unknown"

  defp classify_damage_type(weapon_type_id) do
    cond do
      # Missiles
      weapon_type_id in 2410..2488 -> "Kinetic"
      # Energy weapons
      weapon_type_id in 2929..2969 -> "Thermal"
      # Projectiles
      weapon_type_id in 3000..3100 -> "Kinetic"
      true -> "Mixed"
    end
  end

  defp get_primary_damage_type(damage_breakdown) do
    damage_breakdown
    |> Enum.max_by(fn {_type, amount} -> amount end, fn -> {"Unknown", 0} end)
    |> elem(0)
  end

  defp calculate_damage_diversity(damage_breakdown) do
    total_damage = damage_breakdown |> Map.values() |> Enum.sum()

    if total_damage > 0 do
      # Calculate entropy-like measure of damage type diversity
      damage_breakdown
      |> Enum.map(fn {_type, amount} -> amount / total_damage end)
      # Avoid log(0)
      |> Enum.map(fn ratio -> -ratio * :math.log2(ratio + 0.001) end)
      |> Enum.sum()
      # Normalize
      |> Kernel./(2.0)
    else
      0
    end
  end

  defp infer_tank_type(damage_profile) do
    primary_damage = get_primary_damage_type(damage_profile.damage_breakdown || %{})

    case primary_damage do
      "Thermal" -> "Shield"
      "Kinetic" -> "Armor"
      "EM" -> "Shield"
      "Explosive" -> "Armor"
      _ -> "Buffer"
    end
  end

  defp calculate_tank_effectiveness(instance) do
    # Simple tank effectiveness based on survival time vs damage taken
    survival_score = instance.survivability_score || %{normalized_score: 0.5}
    damage_taken = instance.damage_taken || 0
    theoretical_hp = instance.theoretical_stats.base_hp

    if damage_taken > 0 && theoretical_hp > 0 do
      damage_ratio = damage_taken / theoretical_hp
      # Tank effectiveness = survived longer than expected given damage taken
      survival_score.normalized_score / max(damage_ratio, 0.1)
    else
      survival_score.normalized_score
    end
  end

  defp identify_tank_weaknesses(damage_profile) do
    breakdown = damage_profile.damage_breakdown || %{}

    # Identify which damage types caused the most damage
    breakdown
    |> Enum.sort_by(fn {_type, amount} -> -amount end)
    |> Enum.take(2)
    |> Enum.map(fn {type, _amount} -> type end)
  end

  defp classify_weapon_type(weapon_type_id) when is_nil(weapon_type_id), do: "Unknown"

  defp classify_weapon_type(weapon_type_id) do
    cond do
      weapon_type_id in 2410..2488 -> "Missile"
      weapon_type_id in 2929..2969 -> "Energy"
      weapon_type_id in 3000..3100 -> "Projectile"
      weapon_type_id in 3244..3246 -> "Remote Repair"
      true -> "Other"
    end
  end

  defp get_weapon_optimal_range(weapon_type_id) when is_nil(weapon_type_id), do: 0

  defp get_weapon_optimal_range(weapon_type_id) do
    # Simplified range estimates based on weapon type
    case classify_weapon_type(weapon_type_id) do
      "Missile" -> 50000
      "Energy" -> 15000
      "Projectile" -> 25000
      _ -> 10000
    end
  end

  defp analyze_fitting_weapons(fitting) do
    high_slots = fitting.high_slots || []

    if Enum.empty?(high_slots) do
      %{weapon_count: 0, primary_weapon_type: "None", range_profile: "Unknown"}
    else
      weapon_types = Enum.map(high_slots, & &1["type_id"])
      primary_weapon = Enum.at(weapon_types, 0)

      %{
        weapon_count: length(high_slots),
        primary_weapon_type: classify_weapon_type(primary_weapon),
        range_profile: classify_range_profile(weapon_types)
      }
    end
  end

  defp classify_range_profile(weapon_types) do
    ranges = Enum.map(weapon_types, &get_weapon_optimal_range/1)
    avg_range = Enum.sum(ranges) / max(length(ranges), 1)

    cond do
      avg_range > 40000 -> "Long Range"
      avg_range > 20000 -> "Medium Range"
      avg_range > 5000 -> "Short Range"
      true -> "Point Blank"
    end
  end
end
