defmodule EveDmv.Contexts.PlayerProfile.Analyzers.CombatStatsAnalyzer do
  @moduledoc """
  Combat statistics analyzer for player profiles.

  Analyzes individual character combat performance including kill/death ratios,
  ISK efficiency, weapon preferences, and engagement patterns.
  """

  alias EveDmv.Contexts.PlayerProfile.Infrastructure.PlayerRepository
  alias EveDmv.Result
  use EveDmv.ErrorHandler
  require Logger

  @doc """
  Analyze combat statistics for a character.
  """
  @spec analyze(integer(), map()) :: Result.t(map())
  def analyze(character_id, base_data \\ %{}) when is_integer(character_id) do
    try do
      character_stats = Map.get(base_data, :character_stats, %{})
      killmail_stats = Map.get(base_data, :killmail_stats, %{})

      combat_analysis = %{
        basic_stats: calculate_basic_stats(character_stats, killmail_stats),
        weapon_analysis: analyze_weapon_preferences(character_stats),
        engagement_patterns: analyze_engagement_patterns(character_stats),
        performance_metrics: calculate_performance_metrics(character_stats, killmail_stats),
        risk_indicators: assess_risk_indicators(character_stats),
        summary: generate_combat_summary(character_stats, killmail_stats)
      }

      Result.ok(combat_analysis)
    rescue
      exception ->
        Logger.error("Combat analysis failed",
          character_id: character_id,
          error: Exception.format(:error, exception)
        )

        Result.error(:analysis_failed, "Combat analysis error: #{inspect(exception)}")
    end
  end

  # Core analysis functions

  defp calculate_basic_stats(character_stats, _killmail_stats) do
    total_kills = Map.get(character_stats, :total_kills, 0)
    total_losses = Map.get(character_stats, :total_losses, 0)
    solo_kills = Map.get(character_stats, :solo_kills, 0)

    %{
      total_kills: total_kills,
      total_losses: total_losses,
      solo_kills: solo_kills,
      solo_ratio: safe_divide(solo_kills, total_kills),
      kill_death_ratio: safe_divide(total_kills, max(total_losses, 1)),
      isk_efficiency: Map.get(character_stats, :isk_efficiency, 50.0),
      isk_destroyed: Map.get(character_stats, :isk_destroyed, 0),
      isk_lost: Map.get(character_stats, :isk_lost, 0),
      dangerous_rating: Map.get(character_stats, :dangerous_rating, 3),
      avg_gang_size: Map.get(character_stats, :avg_gang_size, 1.0),
      activity_level: calculate_activity_level(total_kills + total_losses),
      average_kill_value: Map.get(character_stats, :avg_kill_value, 0),
      average_loss_value: Map.get(character_stats, :avg_loss_value, 0)
    }
  end

  defp analyze_weapon_preferences(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})
    weapon_usage = Map.get(character_stats, :weapon_usage, %{})

    # Extract weapon patterns
    weapon_stats =
      if map_size(weapon_usage) > 0 do
        weapon_usage
      else
        # Fallback to extracting from ship usage
        extract_weapons_from_ships(ship_usage)
      end

    top_weapons =
      Enum.sort_by(weapon_stats, fn {_weapon, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {weapon, count} ->
        %{
          weapon: weapon,
          usage_count: count,
          percentage: safe_divide(count * 100, total_weapon_usage(weapon_stats))
        }
      end)

    %{
      top_weapons: top_weapons,
      weapon_diversity: map_size(weapon_stats),
      preferred_range: determine_preferred_range(top_weapons),
      weapon_specialization: calculate_weapon_specialization(weapon_stats),
      damage_types: analyze_damage_types(weapon_stats)
    }
  end

  defp analyze_engagement_patterns(character_stats) do
    active_systems = Map.get(character_stats, :active_systems, %{})
    target_profile = Map.get(character_stats, :target_profile, %{})

    # Analyze geographic patterns
    system_analysis =
      active_systems
      |> Enum.map(fn {system_id, system_data} ->
        %{
          system_id: system_id,
          system_name: Map.get(system_data, :system_name, "Unknown"),
          security: Map.get(system_data, :security, 0.0),
          kills: Map.get(system_data, :kills, 0),
          losses: Map.get(system_data, :losses, 0),
          efficiency: calculate_system_efficiency(system_data),
          last_seen: Map.get(system_data, :last_seen)
        }
      end)
      |> Enum.sort_by(& &1.kills, :desc)

    # Analyze target preferences
    preferred_targets = analyze_target_preferences(target_profile)

    %{
      favorite_systems: Enum.take(system_analysis, 5),
      security_preferences: analyze_security_preferences(system_analysis),
      target_preferences: preferred_targets,
      engagement_timing: analyze_engagement_timing(character_stats),
      avg_victim_gang_size: Map.get(target_profile, :avg_victim_gang_size, 1.0),
      home_region: identify_home_region(system_analysis),
      timezone_activity: Map.get(character_stats, :prime_timezone, "Unknown")
    }
  end

  defp calculate_performance_metrics(character_stats, killmail_stats) do
    %{
      aggression_index: calculate_aggression_index(character_stats),
      efficiency_rating: Map.get(character_stats, :isk_efficiency, 50.0),
      consistency_score: calculate_consistency_score(character_stats, killmail_stats),
      improvement_trend: calculate_improvement_trend(killmail_stats),
      peer_comparison: calculate_peer_comparison(character_stats),
      specialization_index: calculate_specialization_index(character_stats),
      survivability_rating: calculate_survivability_rating(character_stats)
    }
  end

  defp assess_risk_indicators(character_stats) do
    %{
      uses_cynos: Map.get(character_stats, :uses_cynos, false),
      flies_capitals: Map.get(character_stats, :flies_capitals, false),
      has_logi_support: Map.get(character_stats, :has_logi_support, false),
      batphone_probability: Map.get(character_stats, :batphone_probability, "low"),
      awox_probability: Map.get(character_stats, :awox_probability, 0.0),
      identified_weaknesses: Map.get(character_stats, :identified_weaknesses, %{}),
      threat_level: determine_threat_level(character_stats),
      escalation_tendency: assess_escalation_tendency(character_stats)
    }
  end

  defp generate_combat_summary(character_stats, killmail_stats) do
    total_activity =
      Map.get(character_stats, :total_kills, 0) +
        Map.get(character_stats, :total_losses, 0)

    %{
      overall_rating: calculate_overall_rating(character_stats),
      combat_style: determine_combat_style(character_stats),
      experience_level: determine_experience_level(total_activity),
      strengths: identify_strengths(character_stats),
      weaknesses: identify_weaknesses(character_stats),
      recommendations: generate_recommendations(character_stats),
      pilot_classification: classify_pilot_type(character_stats)
    }
  end

  # Helper functions

  defp safe_divide(numerator, denominator) when denominator > 0 do
    Float.round(numerator / denominator, 2)
  end

  defp safe_divide(_, _), do: 0.0

  defp calculate_kill_death_ratio(stats) do
    kills = Map.get(stats, :total_kills, 0)
    losses = Map.get(stats, :total_losses, 0)

    if losses > 0 do
      kills / losses
    else
      min(kills, 100.0)
    end
  end

  defp calculate_activity_level(total_activity) do
    cond do
      total_activity > 500 -> :very_active
      total_activity > 100 -> :active
      total_activity > 20 -> :moderate
      total_activity > 5 -> :low
      true -> :inactive
    end
  end

  defp extract_weapons_from_ships(ship_usage) do
    Enum.frequencies(Enum.flat_map(ship_usage, fn {_ship_id, ship_data} ->
      fits = Map.get(ship_data, :common_fits, [])
      Enum.flat_map(fits, fn fit ->
        Map.get(fit, :weapons, [])
      end)
    end))
  end

  defp total_weapon_usage(weapon_stats) do
    Enum.sum(Map.values(weapon_stats))
  end

  defp determine_preferred_range(weapons) do
    ranges =
      weapons
      |> Enum.map(fn %{weapon: weapon} ->
        cond do
          String.contains?(weapon, ["Blaster", "Pulse", "Autocannon"]) -> :short
          String.contains?(weapon, ["Railgun", "Beam", "Artillery"]) -> :long
          String.contains?(weapon, ["Heavy Missile", "Light Missile"]) -> :medium
          String.contains?(weapon, ["Rocket", "Heavy Assault"]) -> :short
          String.contains?(weapon, ["Cruise", "Torpedo"]) -> :long
          true -> :medium
        end
      end)
      |> Enum.frequencies()

    case Enum.max_by(ranges, fn {_range, count} -> count end, fn -> {:medium, 0} end) do
      {preferred_range, _} -> preferred_range
      _ -> :medium
    end
  end

  defp calculate_weapon_specialization(weapon_stats) do
    if map_size(weapon_stats) == 0 do
      1.0
    else
      total = Enum.sum(Map.values(weapon_stats))
      max_usage = Enum.max(Map.values(weapon_stats), fn -> 0 end)

      Float.round(max_usage / total, 2)
    end
  end

  defp analyze_damage_types(weapon_stats) do
    weapon_stats
    |> Enum.map(fn {weapon, _count} ->
      cond do
        String.contains?(weapon, ["Blaster", "Railgun", "Neutron", "Ion"]) -> :kinetic_thermal
        String.contains?(weapon, ["Pulse", "Beam", "Laser"]) -> :em_thermal
        String.contains?(weapon, ["Autocannon", "Artillery"]) -> :explosive_kinetic
        String.contains?(weapon, ["Missile", "Rocket", "Torpedo"]) -> :selectable
        true -> :mixed
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_type, count} -> -count end)
    |> Enum.take(2)
    |> Enum.map(fn {type, _} -> type end)
  end

  defp calculate_system_efficiency(system_data) do
    kills = Map.get(system_data, :kills, 0)
    losses = Map.get(system_data, :losses, 0)

    if kills + losses > 0 do
      Float.round(kills / (kills + losses) * 100, 1)
    else
      0.0
    end
  end

  defp analyze_target_preferences(target_profile) do
    ship_categories = Map.get(target_profile, :ship_categories, %{})

    ship_categories
    |> Enum.map(fn {category, data} ->
      %{
        category: category,
        kills: Map.get(data, :killed, 0),
        percentage: Map.get(data, :percentage, 0.0),
        avg_value: Map.get(data, :avg_value, 0)
      }
    end)
    |> Enum.sort_by(& &1.kills, :desc)
    |> Enum.take(5)
  end

  defp analyze_security_preferences(system_analysis) do
    security_stats =
      system_analysis
      |> Enum.group_by(fn system ->
        cond do
          system.security >= 0.5 -> :highsec
          system.security > 0.0 -> :lowsec
          system.security == 0.0 -> :nullsec
          true -> :wormhole
        end
      end)
      |> Enum.map(fn {sec_type, systems} ->
        {total_kills, total_losses} =
          Enum.reduce(systems, {0, 0}, fn system, {kills_acc, losses_acc} ->
            {kills_acc + system.kills, losses_acc + system.losses}
          end)

        {sec_type,
         %{
           kills: total_kills,
           losses: total_losses,
           systems: length(systems)
         }}
      end)
      |> Enum.into(%{})

    total_kills =
      security_stats
      |> Map.values()
      |> Enum.sum(& &1.kills)

    Enum.map(security_stats, fn {sec_type, stats} ->
      percentage =
        if total_kills > 0 do
          Float.round(stats.kills / total_kills * 100, 1)
        else
          0.0
        end

      {sec_type, Map.put(stats, :percentage, percentage)}
    end)
    |> Enum.into(%{})
  end

  defp analyze_engagement_timing(character_stats) do
    activity_by_hour = Map.get(character_stats, :activity_by_hour, %{})

    peak_hours =
      Enum.sort_by(activity_by_hour, fn {_hour, activity} -> -activity end)
      |> Enum.take(3)
      |> Enum.map(fn {hour, _} -> hour end)

    %{
      peak_hours: peak_hours,
      timezone_estimate: estimate_timezone(peak_hours),
      weekend_warrior: Map.get(character_stats, :weekend_preference, false)
    }
  end

  defp identify_home_region(system_analysis) do
    # Group by region and find most active
    # This is simplified - would need region mapping in practice
    case Enum.take(system_analysis, 1) do
      [%{system_name: name}] -> extract_region_from_system(name)
      _ -> "Unknown"
    end
  end

  defp extract_region_from_system(_system_name) do
    # Simplified - would need actual region lookup
    "Unknown Region"
  end

  defp calculate_aggression_index(character_stats) do
    kills = Map.get(character_stats, :total_kills, 0)
    losses = Map.get(character_stats, :total_losses, 0)
    solo_ratio = Map.get(character_stats, :solo_ratio, 0.0)

    base_index = safe_divide(kills, kills + losses)
    solo_bonus = solo_ratio * 0.2

    Float.round(base_index + solo_bonus, 2)
  end

  defp calculate_consistency_score(character_stats, _killmail_stats) do
    # Analyze kill/death patterns for consistency
    recent_efficiency = Map.get(character_stats, :recent_efficiency, 50.0)
    overall_efficiency = Map.get(character_stats, :isk_efficiency, 50.0)

    variance = abs(recent_efficiency - overall_efficiency)

    cond do
      variance < 10 -> 0.9
      variance < 20 -> 0.7
      variance < 30 -> 0.5
      true -> 0.3
    end
  end

  defp calculate_improvement_trend(killmail_stats) do
    recent_kd = Map.get(killmail_stats, :recent_kd_ratio, 1.0)
    overall_kd = Map.get(killmail_stats, :overall_kd_ratio, 1.0)

    cond do
      recent_kd > overall_kd * 1.2 -> :improving
      recent_kd < overall_kd * 0.8 -> :declining
      true -> :stable
    end
  end

  defp calculate_peer_comparison(character_stats) do
    # Compare against average pilot metrics
    kd_ratio =
      safe_divide(
        Map.get(character_stats, :total_kills, 0),
        max(Map.get(character_stats, :total_losses, 1), 1)
      )

    percentile =
      cond do
        kd_ratio > 5.0 -> 95
        kd_ratio > 3.0 -> 85
        kd_ratio > 2.0 -> 75
        kd_ratio > 1.5 -> 65
        kd_ratio > 1.0 -> 50
        true -> 30
      end

    %{
      percentile: percentile,
      category: categorize_percentile(percentile)
    }
  end

  defp categorize_percentile(percentile) do
    cond do
      percentile >= 90 -> :elite
      percentile >= 70 -> :above_average
      percentile >= 30 -> :average
      true -> :below_average
    end
  end

  defp calculate_specialization_index(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    if map_size(ship_usage) == 0 do
      0.0
    else
      total_usage =
        ship_usage
        |> Map.values()
        |> Enum.sum(fn ship_data -> Map.get(ship_data, :times_used, 0) end)

      max_usage =
        ship_usage
        |> Map.values()
        |> Enum.map(fn ship_data -> Map.get(ship_data, :times_used, 0) end)
        |> Enum.max(fn -> 0 end)

      Float.round(max_usage / total_usage, 2)
    end
  end

  defp calculate_survivability_rating(character_stats) do
    losses = Map.get(character_stats, :total_losses, 0)
    kills = Map.get(character_stats, :total_kills, 0)
    avg_loss_value = Map.get(character_stats, :avg_loss_value, 0)

    # Base survivability on K/D ratio
    base_rating =
      if losses > 0 do
        min(1.0, kills / losses / 3)
      else
        1.0
      end

    # Adjust for ship value risk
    value_penalty =
      if avg_loss_value > 1_000_000_000 do
        0.2
      else
        0.0
      end

    Float.round(base_rating - value_penalty, 2)
  end

  defp determine_threat_level(character_stats) do
    rating = Map.get(character_stats, :dangerous_rating, 3)
    kills = Map.get(character_stats, :total_kills, 0)

    adjusted_rating =
      cond do
        kills > 1000 and rating >= 3 -> min(5, rating + 1)
        kills < 50 and rating >= 4 -> max(3, rating - 1)
        true -> rating
      end

    case adjusted_rating do
      5 -> :extreme
      4 -> :high
      3 -> :medium
      2 -> :low
      _ -> :minimal
    end
  end

  defp assess_escalation_tendency(character_stats) do
    uses_cynos = Map.get(character_stats, :uses_cynos, false)
    flies_capitals = Map.get(character_stats, :flies_capitals, false)
    avg_gang_size = Map.get(character_stats, :avg_gang_size, 1.0)

    cond do
      uses_cynos and flies_capitals -> :very_high
      avg_gang_size > 20 -> :high
      avg_gang_size > 10 -> :medium
      true -> :low
    end
  end

  defp calculate_overall_rating(character_stats) do
    # Composite score based on multiple factors
    kd_score = min(30, Map.get(character_stats, :kill_death_ratio, 1.0) * 10)
    efficiency_score = Map.get(character_stats, :isk_efficiency, 50) / 2

    activity_score =
      case calculate_activity_level(
             Map.get(character_stats, :total_kills, 0) +
               Map.get(character_stats, :total_losses, 0)
           ) do
        :very_active -> 20
        :active -> 15
        :moderate -> 10
        :low -> 5
        _ -> 0
      end

    danger_score = Map.get(character_stats, :dangerous_rating, 3) * 5

    total = kd_score + efficiency_score + activity_score + danger_score
    min(100, round(total))
  end

  defp determine_combat_style(character_stats) do
    solo_ratio =
      safe_divide(
        Map.get(character_stats, :solo_kills, 0),
        Map.get(character_stats, :total_kills, 1)
      )

    avg_gang_size = Map.get(character_stats, :avg_gang_size, 1.0)
    ship_diversity = map_size(Map.get(character_stats, :ship_usage, %{}))

    cond do
      solo_ratio > 0.7 -> :solo_hunter
      avg_gang_size > 15 -> :fleet_anchor
      avg_gang_size > 5 -> :small_gang_specialist
      ship_diversity > 10 -> :versatile_pilot
      true -> :opportunist
    end
  end

  defp determine_experience_level(total_activity) do
    cond do
      total_activity > 1000 -> :veteran
      total_activity > 200 -> :experienced
      total_activity > 50 -> :intermediate
      total_activity > 10 -> :novice
      true -> :rookie
    end
  end

  defp identify_strengths(character_stats) do
    initial_strengths = []

    efficiency = Map.get(character_stats, :isk_efficiency, 50)

    efficiency_strengths =
      if efficiency > 75 do
        ["Excellent ISK efficiency (#{efficiency}%)" | initial_strengths]
      else
        initial_strengths
      end

    kd_ratio =
      safe_divide(
        Map.get(character_stats, :total_kills, 0),
        max(Map.get(character_stats, :total_losses, 1), 1)
      )

    kd_strengths =
      if kd_ratio > 3 do
        ["Outstanding K/D ratio (#{kd_ratio})" | efficiency_strengths]
      else
        efficiency_strengths
      end

    solo_ratio = Map.get(character_stats, :solo_ratio, 0.0)

    solo_strengths =
      if solo_ratio > 0.5 do
        ["Strong solo combat skills" | kd_strengths]
      else
        kd_strengths
      end

    dangerous = Map.get(character_stats, :dangerous_rating, 3)

    final_strengths =
      if dangerous >= 4 do
        ["High threat pilot" | solo_strengths]
      else
        solo_strengths
      end

    final_strengths
  end

  defp identify_weaknesses(character_stats) do
    initial_weaknesses = []

    efficiency = Map.get(character_stats, :isk_efficiency, 50)

    efficiency_weaknesses =
      if efficiency < 40 do
        ["Poor target selection (#{efficiency}% efficiency)" | initial_weaknesses]
      else
        initial_weaknesses
      end

    losses = Map.get(character_stats, :total_losses, 0)
    kills = Map.get(character_stats, :total_kills, 0)

    loss_rate_weaknesses =
      if losses > kills * 2 do
        ["High loss rate" | efficiency_weaknesses]
      else
        efficiency_weaknesses
      end

    avg_loss = Map.get(character_stats, :avg_loss_value, 0)

    ship_loss_weaknesses =
      if avg_loss > 500_000_000 do
        ["Loses expensive ships frequently" | loss_rate_weaknesses]
      else
        loss_rate_weaknesses
      end

    # Add identified weaknesses from stats
    identified = Map.get(character_stats, :identified_weaknesses, %{})
    behavioral = Map.get(identified, :behavioral, [])
    technical = Map.get(identified, :technical, [])

    ship_loss_weaknesses ++ behavioral ++ technical
  end

  defp generate_recommendations(character_stats) do
    initial_recommendations = []

    efficiency = Map.get(character_stats, :isk_efficiency, 50)

    efficiency_recommendations =
      if efficiency < 40 do
        ["Focus on softer targets to improve ISK efficiency" | initial_recommendations]
      else
        initial_recommendations
      end

    solo_ratio = Map.get(character_stats, :solo_ratio, 0.0)

    solo_recommendations =
      if solo_ratio < 0.1 do
        ["Practice solo PvP to improve individual combat skills" | efficiency_recommendations]
      else
        efficiency_recommendations
      end

    ship_count = map_size(Map.get(character_stats, :ship_usage, %{}))

    ship_recommendations =
      if ship_count < 3 do
        ["Diversify ship selection for tactical flexibility" | solo_recommendations]
      else
        solo_recommendations
      end

    activity =
      calculate_activity_level(
        Map.get(character_stats, :total_kills, 0) + Map.get(character_stats, :total_losses, 0)
      )

    activity_recommendations =
      if activity in [:low, :inactive] do
        ["Increase activity to maintain combat edge" | ship_recommendations]
      else
        ship_recommendations
      end

    activity_recommendations
  end

  defp classify_pilot_type(character_stats) do
    # Comprehensive pilot classification
    solo_ratio = Map.get(character_stats, :solo_ratio, 0.0)
    efficiency = Map.get(character_stats, :isk_efficiency, 50)
    kills = Map.get(character_stats, :total_kills, 0)
    ship_diversity = map_size(Map.get(character_stats, :ship_usage, %{}))

    cond do
      solo_ratio > 0.8 and efficiency > 70 -> :elite_solo_hunter
      kills > 500 and efficiency > 60 -> :veteran_fighter
      ship_diversity > 15 -> :versatile_combatant
      efficiency < 30 -> :learning_pilot
      solo_ratio < 0.1 -> :fleet_specialist
      true -> :standard_pilot
    end
  end

  defp estimate_timezone(peak_hours) do
    if Enum.empty?(peak_hours) do
      "Unknown"
    else
      # Simple timezone estimation based on peak hours
      avg_hour = Enum.sum(peak_hours) / length(peak_hours)

      cond do
        avg_hour >= 0 and avg_hour < 8 -> "AU TZ"
        avg_hour >= 8 and avg_hour < 16 -> "EU TZ"
        avg_hour >= 16 and avg_hour < 24 -> "US TZ"
        true -> "Unknown"
      end
    end
  end
end
