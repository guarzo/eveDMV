defmodule EveDmv.Intelligence.PatternAnalysis do
  @moduledoc """
  Advanced pattern analysis module for behavioral intelligence.

  Provides sophisticated pattern recognition and analysis capabilities
  for character behavioral assessment, including activity rhythm,
  engagement patterns, risk progression, and anomaly detection.
  """

  @doc """
  Analyze activity rhythm patterns in character behavior.

  Examines timing, frequency, and consistency of character activities.
  """
  def analyze_activity_rhythm(stats) do
    # Analyze patterns in activity timing and frequency
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

    %{
      consistency_score: calculate_activity_consistency(stats),
      peak_activity_period: determine_peak_activity_period(stats),
      activity_variance: calculate_activity_variance(total_activity),
      engagement_frequency: calculate_engagement_frequency(stats)
    }
  end

  @doc """
  Analyze combat engagement patterns.

  Examines aggression levels, target selection, and tactical preferences.
  """
  def analyze_engagement_patterns(stats) do
    # Analyze combat engagement patterns
    %{
      aggression_index: calculate_aggression_index(stats),
      target_selection: analyze_target_selection_patterns(stats),
      tactical_preferences: identify_tactical_preferences(stats),
      risk_tolerance: assess_risk_tolerance(stats)
    }
  end

  @doc """
  Analyze risk progression over time.

  Examines how risk factors have evolved and security incident patterns.
  """
  def analyze_risk_progression(stats, vetting) do
    # Analyze how risk factors have evolved over time
    %{
      risk_trajectory: determine_risk_trajectory(stats, vetting),
      security_incidents: count_security_incidents(vetting),
      improvement_trend: assess_improvement_trend(stats),
      stability_score: calculate_stability_score(stats)
    }
  end

  @doc """
  Analyze social interaction patterns.

  Examines cooperation, leadership, and network influence indicators.
  """
  def analyze_social_patterns(stats) do
    # Analyze social interaction patterns
    %{
      cooperation_index: calculate_cooperation_index(stats),
      leadership_indicators: identify_leadership_indicators(stats),
      network_centrality: assess_network_centrality(stats),
      social_influence: calculate_social_influence_score(stats)
    }
  end

  @doc """
  Analyze operational behavior patterns.

  Examines operational tempo, mission types, and strategic thinking.
  """
  def analyze_operational_patterns(stats) do
    # Analyze operational behavior patterns
    %{
      operational_tempo: calculate_operational_tempo(stats),
      mission_types: categorize_mission_types(stats),
      resource_efficiency: assess_resource_efficiency(stats),
      strategic_thinking: assess_strategic_thinking(stats)
    }
  end

  @doc """
  Detect behavioral anomalies in character data.

  Identifies unusual patterns and inconsistencies in behavior.
  """
  def detect_behavioral_anomalies(stats) do
    anomalies =
      []
      |> check_activity_anomalies(stats)
      |> check_ratio_anomalies(stats)
      |> check_pattern_inconsistencies(stats)

    %{
      anomalies_detected: anomalies,
      anomaly_count: length(anomalies),
      severity: categorize_anomaly_severity(anomalies)
    }
  end

  # Private helper functions

  defp calculate_activity_consistency(stats) do
    # Simple consistency calculation based on kill/loss ratio stability
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0

    if kills + losses > 0 do
      variance = abs(kills - losses) / (kills + losses)
      max(0.0, 1.0 - variance)
    else
      0.5
    end
  end

  defp determine_peak_activity_period(stats) do
    # Analyze activity patterns based on available stats
    # In practice, this would use temporal analysis of killmail timestamps
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

    cond do
      # High activity suggests multi-timezone operations
      total_activity > 1000 -> "Multi-timezone active"
      # Medium activity in single region
      total_activity > 500 -> "Regional prime time"
      # Low activity suggests casual play
      total_activity > 100 -> "Weekend warrior"
      true -> "Sporadic activity"
    end
  end

  defp calculate_activity_variance(total_activity) do
    # Simple variance calculation
    if total_activity > 100, do: 0.2, else: 0.5
  end

  defp calculate_engagement_frequency(stats) do
    # Calculate engagement frequency per day
    total_engagements = (stats.total_kills || 0) + (stats.total_losses || 0)
    # Assume 30-day analysis period
    total_engagements / 30.0
  end

  defp calculate_aggression_index(stats) do
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0

    if kills + losses > 0 do
      kills / (kills + losses)
    else
      0.0
    end
  end

  defp analyze_target_selection_patterns(stats) do
    # Analyze what types of targets they prefer
    %{
      preferred_targets: determine_preferred_targets(stats),
      avoidance_patterns: determine_avoided_targets(stats),
      target_size_preference: analyze_target_size_preference(stats),
      opportunistic_rating: calculate_opportunistic_rating(stats)
    }
  end

  defp determine_preferred_targets(stats) do
    # Based on ship classes and engagement patterns
    cond do
      stats.top_ship_class in ["Interceptor", "Frigate"] ->
        ["frigates", "destroyers"]

      stats.top_ship_class in ["Cruiser", "Heavy Assault Cruiser"] ->
        ["cruisers", "battlecruisers"]

      stats.top_ship_class in ["Battleship", "Marauder"] ->
        ["battleships", "capitals"]

      # Solo pilots prefer smaller targets
      stats.solo_ratio > 0.7 ->
        ["frigates", "cruisers"]

      true ->
        ["all_sizes"]
    end
  end

  defp determine_avoided_targets(stats) do
    # What they tend to avoid
    kill_death_ratio = calculate_kill_death_ratio(stats)

    cond do
      kill_death_ratio < 1.0 -> ["organized_fleets", "capitals"]
      stats.solo_ratio > 0.8 -> ["large_gangs", "capitals"]
      stats.avg_ship_value < 100_000_000 -> ["expensive_targets"]
      true -> []
    end
  end

  defp analyze_target_size_preference(stats) do
    # Preference for target sizes
    cond do
      stats.top_ship_class in ["Battleship", "Battlecruiser"] ->
        :larger_targets

      stats.top_ship_class in ["Interceptor", "Frigate", "Destroyer"] ->
        :smaller_targets

      true ->
        :similar_size
    end
  end

  defp calculate_opportunistic_rating(stats) do
    # How opportunistic vs. selective they are
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

    cond do
      # High activity = opportunistic
      total_activity > 1000 -> 0.8
      total_activity > 500 -> 0.6
      total_activity > 100 -> 0.4
      # Low activity = selective
      true -> 0.2
    end
  end

  defp identify_tactical_preferences(stats) do
    # Identify tactical combat preferences
    %{
      combat_style: determine_combat_style(stats),
      engagement_range: determine_preferred_range(stats),
      mobility_preference: assess_mobility_preference(stats),
      positioning_skill: evaluate_positioning_skill(stats)
    }
  end

  defp determine_combat_style(stats) do
    cond do
      stats.solo_ratio > 0.7 and stats.avg_damage_ratio > 0.8 -> "aggressive_solo"
      stats.solo_ratio > 0.5 -> "hit_and_run"
      stats.fleet_ratio > 0.7 -> "fleet_anchor"
      stats.gang_ratio > 0.5 -> "small_gang_specialist"
      true -> "opportunistic"
    end
  end

  defp determine_preferred_range(stats) do
    # Based on ship preferences
    cond do
      stats.top_ship_class in ["Bomber", "Attack Battlecruiser"] -> "long"
      stats.top_ship_class in ["Cruiser", "Battlecruiser"] -> "medium"
      stats.top_ship_class in ["Frigate", "Destroyer"] -> "short"
      true -> "flexible"
    end
  end

  defp assess_mobility_preference(stats) do
    # How much they value mobility
    if stats.top_ship_class in ["Interceptor", "Frigate", "Cruiser"] do
      :high_mobility
    else
      :low_mobility
    end
  end

  defp evaluate_positioning_skill(stats) do
    # Estimate positioning skill from survival
    kd_ratio = calculate_kill_death_ratio(stats)
    solo_ratio = stats.solo_ratio || 0.5

    score = kd_ratio * 0.6 + solo_ratio * 0.4

    cond do
      score > 2.0 -> :expert
      score > 1.5 -> :skilled
      score > 1.0 -> :competent
      true -> :learning
    end
  end

  defp assess_risk_tolerance(stats) do
    # Risk tolerance based on loss patterns
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0

    if losses > 0 do
      min(1.0, kills / losses)
    else
      0.8
    end
  end

  defp determine_risk_trajectory(stats, vetting) do
    # Analyze if risk is increasing, decreasing, or stable
    recent_kd = calculate_kill_death_ratio(stats)
    security_flags = if is_map(vetting), do: Map.get(vetting, :security_flags, []), else: []

    cond do
      length(security_flags) > 3 -> :increasing
      recent_kd < 1.0 and stats.total_losses > 50 -> :increasing
      recent_kd > 2.0 and Enum.empty?(security_flags) -> :decreasing
      true -> :stable
    end
  end

  defp count_security_incidents(vetting) do
    # Count security-related incidents in vetting data
    if is_map(vetting) and Map.has_key?(vetting, :security_flags) do
      security_flags = Map.get(vetting, :security_flags, [])
      length(security_flags)
    else
      0
    end
  end

  defp assess_improvement_trend(stats) do
    # Assess if pilot is improving over time
    kd_ratio = calculate_kill_death_ratio(stats)
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

    cond do
      total_activity < 50 -> :insufficient_data
      kd_ratio > 2.0 -> :positive
      kd_ratio > 1.5 -> :stable_positive
      kd_ratio > 1.0 -> :stable
      kd_ratio > 0.5 -> :needs_improvement
      true -> :negative
    end
  end

  defp calculate_stability_score(stats) do
    # Calculate behavioral stability (0.0 to 1.0)
    factors = [
      consistency_factor(stats),
      activity_regularity_factor(stats),
      performance_stability_factor(stats)
    ]

    # Average of all factors
    Enum.sum(factors) / length(factors)
  end

  defp consistency_factor(stats) do
    # How consistent their behavior is
    solo_ratio = stats.solo_ratio || 0.5

    # More extreme ratios (very solo or very fleet) = more consistent
    if solo_ratio > 0.8 or solo_ratio < 0.2 do
      0.9
    else
      0.5
    end
  end

  defp activity_regularity_factor(stats) do
    # Based on total activity
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

    cond do
      # Very active = regular
      total_activity > 1000 -> 0.9
      total_activity > 500 -> 0.7
      total_activity > 100 -> 0.5
      true -> 0.3
    end
  end

  defp performance_stability_factor(stats) do
    # Based on K/D ratio stability
    kd_ratio = calculate_kill_death_ratio(stats)

    cond do
      # Consistently good
      kd_ratio > 3.0 -> 0.9
      kd_ratio > 2.0 -> 0.7
      kd_ratio > 1.0 -> 0.5
      true -> 0.3
    end
  end

  defp calculate_cooperation_index(stats) do
    # Calculate cooperation based on fleet participation
    fleet_ratio = stats.fleet_ratio || 0.0
    gang_ratio = stats.gang_ratio || 0.0
    solo_ratio = stats.solo_ratio || 1.0

    # Fleet and gang participation indicates cooperation
    cooperation_score = fleet_ratio * 0.8 + gang_ratio * 0.6 + solo_ratio * 0.1

    # Normalize to 0-1 range
    min(1.0, cooperation_score)
  end

  defp identify_leadership_indicators(stats) do
    # Analyze leadership potential based on activity patterns
    fleet_ratio = stats.fleet_ratio || 0.0
    total_kills = stats.total_kills || 0
    kd_ratio = calculate_kill_death_ratio(stats)

    # High fleet participation + good performance suggests leadership
    leadership_score =
      cond do
        fleet_ratio > 0.7 and kd_ratio > 2.0 -> 0.4
        fleet_ratio > 0.5 and kd_ratio > 1.5 -> 0.3
        fleet_ratio > 0.3 and total_kills > 200 -> 0.2
        true -> 0.1
      end

    # Experience factor
    has_command_experience = total_kills > 500 and fleet_ratio > 0.6

    %{
      leadership_score: min(1.0, leadership_score),
      command_experience: has_command_experience
    }
  end

  defp assess_network_centrality(stats) do
    # Estimate network centrality based on activity patterns
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)
    fleet_ratio = stats.fleet_ratio || 0.0
    gang_ratio = stats.gang_ratio || 0.0

    # Activity level contributes to centrality
    activity_score =
      cond do
        total_activity > 1000 -> 0.3
        total_activity > 500 -> 0.2
        total_activity > 100 -> 0.1
        true -> 0.05
      end

    # Mixed participation suggests bridge role
    activity_score
    |> add_bridge_role_bonus(fleet_ratio, gang_ratio)
    |> min(1.0)
  end

  defp add_bridge_role_bonus(score, fleet_ratio, gang_ratio)
       when fleet_ratio > 0.3 and gang_ratio > 0.3 do
    score + 0.3
  end

  defp add_bridge_role_bonus(score, _fleet_ratio, _gang_ratio), do: score

  defp calculate_social_influence_score(stats) do
    # Calculate social influence based on performance and participation
    kd_ratio = calculate_kill_death_ratio(stats)
    total_kills = stats.total_kills || 0
    fleet_ratio = stats.fleet_ratio || 0.0

    # Performance influence
    performance_influence = min(0.4, kd_ratio * 0.2)

    # Experience influence
    experience_influence = min(0.3, total_kills / 1000.0)

    # Fleet leadership influence
    leadership_influence = fleet_ratio * 0.3

    performance_influence + experience_influence + leadership_influence
  end

  defp calculate_operational_tempo(stats) do
    # Calculate operational tempo based on activity frequency
    total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

    cond do
      total_activity > 100 -> :high
      total_activity > 50 -> :medium
      total_activity > 10 -> :low
      true -> :minimal
    end
  end

  defp categorize_mission_types(stats) do
    # Categorize mission types based on kill patterns
    total_kills = stats.total_kills || 0
    total_losses = stats.total_losses || 0
    solo_ratio = stats.solo_ratio || 0.5

    total_activity = total_kills + total_losses

    if total_activity == 0 do
      %{pve: 0.7, pvp: 0.2, exploration: 0.1}
    else
      # High K/D with losses suggests PvP focus
      pvp_ratio =
        if total_losses > 0 do
          min(0.9, total_kills / (total_kills + total_losses))
        else
          0.3
        end

      # Solo players often do exploration
      exploration_ratio = if solo_ratio > 0.7, do: 0.2, else: 0.05

      # Remainder is PvE
      pve_ratio = 1.0 - pvp_ratio - exploration_ratio

      %{
        pve: max(0.0, pve_ratio),
        pvp: pvp_ratio,
        exploration: exploration_ratio
      }
    end
  end

  defp assess_resource_efficiency(stats) do
    # Assess resource efficiency based on kill/death patterns
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0
    avg_ship_value = stats.avg_ship_value || 50_000_000

    if losses > 0 do
      # Efficiency based on K/D ratio and ship value usage
      kd_ratio = kills / losses

      # Lower value ships with good K/D = efficient
      value_efficiency =
        cond do
          avg_ship_value < 10_000_000 -> 0.4
          avg_ship_value < 50_000_000 -> 0.3
          avg_ship_value < 200_000_000 -> 0.2
          true -> 0.1
        end

      # K/D efficiency
      performance_efficiency = min(0.6, kd_ratio * 0.3)

      value_efficiency + performance_efficiency
    else
      # No losses = perfect efficiency (up to a point)
      if kills > 0, do: 0.9, else: 0.5
    end
  end

  defp assess_strategic_thinking(stats) do
    # Assess strategic vs tactical thinking
    total_kills = stats.total_kills || 0
    solo_ratio = stats.solo_ratio || 0.5
    kd_ratio = calculate_kill_death_ratio(stats)

    # High K/D with experience indicates strategy
    base_strategy_score =
      cond do
        total_kills > 500 and kd_ratio > 2.0 -> 0.4
        total_kills > 200 and kd_ratio > 1.5 -> 0.3
        true -> 0.1
      end

    # Solo players need more strategy
    base_strategy_score
    |> add_solo_strategy_bonus(solo_ratio)
  end

  defp add_solo_strategy_bonus(score, solo_ratio) when solo_ratio > 0.7, do: score + 0.2
  defp add_solo_strategy_bonus(score, _solo_ratio), do: score

  defp check_activity_anomalies(anomalies, stats) do
    activity_score = (stats.total_kills || 0) + (stats.total_losses || 0)

    if activity_score > 1000 do
      ["unusually_high_activity" | anomalies]
    else
      anomalies
    end
  end

  defp check_ratio_anomalies(anomalies, stats) do
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0

    if losses > 0 and kills / losses > 10 do
      ["unusually_high_kill_ratio" | anomalies]
    else
      anomalies
    end
  end

  defp check_pattern_inconsistencies(anomalies, _stats) do
    # Placeholder for pattern inconsistency checks
    anomalies
  end

  defp categorize_anomaly_severity(anomalies) do
    count = length(anomalies)

    cond do
      count >= 3 -> :high
      count >= 2 -> :medium
      count >= 1 -> :low
      true -> :none
    end
  end

  defp calculate_kill_death_ratio(stats) do
    kills = stats.total_kills || 0
    losses = stats.total_losses || 0

    if losses > 0 do
      kills / losses
    else
      # If no losses, return kills as the ratio (capped at 100 for sanity)
      min(kills, 100.0)
    end
  end
end
