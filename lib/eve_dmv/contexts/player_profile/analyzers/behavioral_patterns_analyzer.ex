defmodule EveDmv.Contexts.PlayerProfile.Analyzers.BehavioralPatternsAnalyzer do
  @moduledoc """
  Behavioral patterns analyzer for player profiles.

  Analyzes individual character behavioral patterns including activity timing,
  engagement preferences, risk tolerance, and tactical patterns.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  require Logger

  @doc """
  Analyze behavioral patterns for a character.
  """
  @spec analyze(integer(), map()) :: Result.t(map())
  def analyze(character_id, base_data \\ %{}) when is_integer(character_id) do
    try do
      character_stats = Map.get(base_data, :character_stats, %{})
      killmail_stats = Map.get(base_data, :killmail_stats, %{})

      behavioral_analysis = %{
        activity_patterns: analyze_activity_patterns(character_stats),
        engagement_behavior: analyze_engagement_behavior(character_stats),
        risk_profile: analyze_risk_profile(character_stats),
        tactical_patterns: analyze_tactical_patterns(character_stats),
        social_behavior: analyze_social_behavior(character_stats),
        consistency_metrics: calculate_consistency_metrics(character_stats, killmail_stats),
        behavioral_summary: generate_behavioral_summary(character_stats),
        psychological_profile: generate_psychological_profile(character_stats)
      }

      Result.ok(behavioral_analysis)
    rescue
      exception ->
        Logger.error("Behavioral analysis failed",
          character_id: character_id,
          error: Exception.format(:error, exception)
        )

        Result.error(:analysis_failed, "Behavioral analysis error: #{inspect(exception)}")
    end
  end

  # Core analysis functions

  defp analyze_activity_patterns(character_stats) do
    activity_data = Map.get(character_stats, :activity_by_hour, %{})
    activity_by_day = Map.get(character_stats, :activity_by_day, %{})

    # Analyze hourly patterns
    peak_hours =
      activity_data
      |> Enum.sort_by(fn {_hour, activity} -> activity end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, activity} ->
        %{hour: hour, activity_level: activity}
      end)

    # Analyze daily patterns
    active_days =
      activity_by_day
      |> Enum.filter(fn {_day, activity} -> activity > 0 end)
      |> Enum.map(fn {day, activity} ->
        %{day: day, activity_level: activity}
      end)

    # Calculate consistency
    activity_variance = calculate_activity_variance(Map.values(activity_data))
    consistency_rating = calculate_consistency_rating(activity_variance)

    %{
      peak_activity_hours: peak_hours,
      active_days_pattern: active_days,
      prime_timezone: Map.get(character_stats, :prime_timezone, "Unknown"),
      activity_consistency: consistency_rating,
      total_active_hours: map_size(activity_data),
      weekend_vs_weekday: analyze_weekend_patterns(activity_by_day),
      session_length_preference: determine_session_length(character_stats),
      activity_trend: calculate_activity_trend(character_stats)
    }
  end

  defp analyze_engagement_behavior(character_stats) do
    engagement_data = Map.get(character_stats, :engagement_patterns, %{})

    # Analyze aggression patterns
    aggression_indicators = %{
      initiation_rate: Map.get(engagement_data, :initiation_rate, 0.0),
      first_strike_preference: Map.get(engagement_data, :first_strike, false),
      opportunistic_behavior: Map.get(engagement_data, :opportunistic, 0.0)
    }

    # Analyze target selection patterns
    target_selection = %{
      preferred_ship_sizes:
        extract_preferred_targets(Map.get(character_stats, :target_profile, %{})),
      risk_tolerance: assess_target_risk_tolerance(character_stats),
      victim_selection_logic: analyze_victim_patterns(character_stats)
    }

    # Analyze combat duration patterns
    combat_patterns = %{
      avg_engagement_duration: Map.get(engagement_data, :avg_duration_seconds, 0),
      quick_kill_preference: Map.get(engagement_data, :quick_kills, 0.0),
      prolonged_fight_tolerance: Map.get(engagement_data, :long_fights, 0.0)
    }

    %{
      aggression_style: categorize_aggression_style(aggression_indicators),
      target_selection: target_selection,
      combat_duration_patterns: combat_patterns,
      engagement_timing: analyze_engagement_timing(character_stats),
      backup_calling_behavior: analyze_backup_patterns(character_stats),
      retreat_patterns: analyze_retreat_behavior(character_stats)
    }
  end

  defp analyze_risk_profile(character_stats) do
    # Analyze security space preferences
    security_profile = Map.get(character_stats, :security_preferences, %{})

    # Calculate risk tolerance metrics
    high_risk_indicators = [
      Map.get(character_stats, :flies_capitals, false),
      Map.get(character_stats, :avg_ship_value, 0) > 1_000_000_000,
      Map.get(security_profile, :nullsec_percentage, 0.0) > 0.5,
      Map.get(character_stats, :uses_cynos, false)
    ]

    risk_score = Enum.count(high_risk_indicators, & &1) / length(high_risk_indicators)

    %{
      security_space_preferences: security_profile,
      risk_tolerance_score: risk_score,
      ship_value_comfort:
        categorize_ship_value_comfort(Map.get(character_stats, :avg_ship_value, 0)),
      tactical_risk_taking: assess_tactical_risks(character_stats),
      insurance_behavior: analyze_insurance_patterns(character_stats),
      loss_recovery_patterns: analyze_loss_recovery(character_stats)
    }
  end

  defp analyze_tactical_patterns(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # Analyze ship role preferences
    role_patterns = categorize_ship_roles(ship_usage)

    # Analyze tactical approaches
    tactical_style = %{
      solo_vs_group_preference: calculate_group_preference(character_stats),
      range_engagement_preference: analyze_range_preferences(ship_usage),
      support_role_willingness: assess_support_role_usage(ship_usage),
      doctrine_adherence: calculate_doctrine_compliance(character_stats)
    }

    %{
      preferred_ship_roles: role_patterns,
      tactical_style: tactical_style,
      fleet_position_preference: determine_fleet_position(character_stats),
      weapon_system_mastery: analyze_weapon_systems(ship_usage),
      defensive_patterns: analyze_defensive_behavior(character_stats),
      coordination_indicators: assess_coordination_level(character_stats)
    }
  end

  defp analyze_social_behavior(character_stats) do
    corp_history = Map.get(character_stats, :corporation_history, [])
    alliance_activity = Map.get(character_stats, :alliance_activity, %{})

    %{
      corporation_loyalty: calculate_corp_loyalty(corp_history),
      alliance_participation: assess_alliance_participation(alliance_activity),
      leadership_indicators: identify_leadership_signs(character_stats),
      cooperation_level: assess_cooperation_behavior(character_stats),
      communication_patterns: analyze_communication_style(character_stats),
      mentor_potential: assess_mentor_characteristics(character_stats)
    }
  end

  defp calculate_consistency_metrics(character_stats, _killmail_stats) do
    # Calculate various consistency metrics
    performance_variance = calculate_performance_variance(character_stats)
    timing_consistency = calculate_timing_consistency(character_stats)
    behavior_stability = calculate_behavior_stability(character_stats)

    overall_consistency = (performance_variance + timing_consistency + behavior_stability) / 3

    %{
      performance_consistency: performance_variance,
      timing_consistency: timing_consistency,
      behavioral_stability: behavior_stability,
      overall_consistency_score: overall_consistency,
      predictability_index: calculate_predictability(character_stats),
      adaptation_rate: assess_adaptation_speed(character_stats)
    }
  end

  defp generate_behavioral_summary(character_stats) do
    # Generate high-level behavioral insights
    primary_traits = identify_primary_traits(character_stats)
    behavioral_archetype = determine_behavioral_archetype(character_stats)

    %{
      behavioral_archetype: behavioral_archetype,
      primary_traits: primary_traits,
      predictability_rating: assess_predictability_rating(character_stats),
      adaptation_capability: assess_adaptation_capability(character_stats),
      key_behavioral_indicators: extract_key_indicators(character_stats)
    }
  end

  # Helper functions

  defp calculate_activity_variance(activity_levels) do
    if length(activity_levels) < 2, do: 0.0

    mean = Enum.sum(activity_levels) / length(activity_levels)

    variance =
      activity_levels
      |> Enum.map(fn level -> :math.pow(level - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(activity_levels))

    :math.sqrt(variance)
  end

  defp calculate_consistency_rating(variance) do
    cond do
      variance < 10 -> :very_consistent
      variance < 25 -> :consistent
      variance < 50 -> :moderate
      variance < 100 -> :inconsistent
      true -> :very_inconsistent
    end
  end

  defp analyze_weekend_patterns(activity_by_day) do
    weekday_activity =
      activity_by_day
      |> then(fn data -> for {day, activity} <- data, day in [1, 2, 3, 4, 5], do: activity end)
      |> average_or_zero()

    weekend_activity =
      activity_by_day
      |> then(fn data -> for {day, activity} <- data, day in [6, 7], do: activity end)
      |> average_or_zero()

    %{
      weekday_avg: weekday_activity,
      weekend_avg: weekend_activity,
      weekend_preference: weekend_activity > weekday_activity
    }
  end

  defp average_or_zero([]), do: 0.0
  defp average_or_zero(values), do: Enum.sum(values) / length(values)

  defp determine_session_length(character_stats) do
    avg_session = Map.get(character_stats, :avg_session_length_minutes, 60)

    cond do
      avg_session < 30 -> :short_sessions
      avg_session < 120 -> :medium_sessions
      avg_session < 300 -> :long_sessions
      true -> :marathon_sessions
    end
  end

  defp calculate_activity_trend(character_stats) do
    recent_activity = Map.get(character_stats, :recent_activity_trend, 0.0)

    cond do
      recent_activity > 0.1 -> :increasing
      recent_activity < -0.1 -> :decreasing
      true -> :stable
    end
  end

  defp extract_preferred_targets(target_profile) do
    ship_categories = Map.get(target_profile, :ship_categories, %{})

    ship_categories
    |> Enum.sort_by(fn {_category, data} -> Map.get(data, :killed, 0) end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {category, data} ->
      %{category: category, kills: Map.get(data, :killed, 0)}
    end)
  end

  defp assess_target_risk_tolerance(character_stats) do
    avg_victim_value = Map.get(character_stats, :avg_victim_ship_value, 0)

    cond do
      avg_victim_value > 5_000_000_000 -> :very_high_risk
      avg_victim_value > 1_000_000_000 -> :high_risk
      avg_victim_value > 100_000_000 -> :moderate_risk
      avg_victim_value > 10_000_000 -> :low_risk
      true -> :very_low_risk
    end
  end

  defp analyze_victim_patterns(character_stats) do
    victim_data = Map.get(character_stats, :victim_analysis, %{})

    %{
      targets_newbies: Map.get(victim_data, :targets_new_players, false),
      ganks_haulers: Map.get(victim_data, :targets_industrials, false),
      hunts_pvpers: Map.get(victim_data, :targets_pvp_pilots, false),
      opportunistic: Map.get(victim_data, :opportunistic_kills, 0.0) > 0.7
    }
  end

  defp categorize_aggression_style(aggression_indicators) do
    initiation_rate = aggression_indicators.initiation_rate

    cond do
      initiation_rate > 0.8 -> :highly_aggressive
      initiation_rate > 0.6 -> :aggressive
      initiation_rate > 0.4 -> :balanced
      initiation_rate > 0.2 -> :defensive
      true -> :very_defensive
    end
  end

  defp analyze_engagement_timing(character_stats) do
    kills = Map.get(character_stats, :total_kills, 0)
    losses = Map.get(character_stats, :total_losses, 0)
    total_engagements = kills + losses

    %{
      peak_activity_hour: Map.get(character_stats, :peak_activity_hour, 0),
      average_engagement_duration: calculate_avg_engagement_duration(total_engagements),
      time_to_engage: estimate_time_to_engage(character_stats),
      disengagement_threshold: calculate_disengagement_threshold(character_stats)
    }
  end

  defp calculate_avg_engagement_duration(total_engagements) do
    cond do
      # 3 minutes for experienced pilots
      total_engagements > 1000 -> 180
      # 4 minutes for moderately experienced
      total_engagements > 500 -> 240
      # 5 minutes for newer pilots
      total_engagements > 100 -> 300
      # 6 minutes default
      true -> 360
    end
  end

  defp estimate_time_to_engage(stats) do
    aggression = Map.get(stats, :aggression_percentile, 50)
    solo_ratio = Map.get(stats, :solo_ratio, 0.5)

    # seconds
    base_time = 30

    # More aggressive pilots engage faster
    aggression_modifier = (100 - aggression) / 100 * 20
    # Solo pilots are more cautious
    solo_modifier = if solo_ratio > 0.7, do: 10, else: 0

    base_time + aggression_modifier + solo_modifier
  end

  defp calculate_disengagement_threshold(stats) do
    # Hull percentage at which they typically disengage
    kd_ratio = calculate_kill_death_ratio(stats)

    cond do
      # 30% hull - very cautious
      kd_ratio > 3.0 -> 0.3
      # 20% hull
      kd_ratio > 2.0 -> 0.2
      # 10% hull
      kd_ratio > 1.0 -> 0.1
      # 15% default
      true -> 0.15
    end
  end

  defp analyze_backup_patterns(character_stats) do
    batphone_prob = Map.get(character_stats, :batphone_probability, "low")

    %{
      calls_for_backup: batphone_prob != "low",
      backup_frequency: batphone_prob,
      escalation_tendency: assess_escalation_tendency(character_stats)
    }
  end

  defp analyze_retreat_behavior(character_stats) do
    losses = Map.get(character_stats, :total_losses, 0)
    kills = Map.get(character_stats, :total_kills, 0)

    if losses == 0 do
      %{retreat_behavior: "unknown", sample_size: 0}
    else
      kill_death_ratio = calculate_kill_death_ratio(character_stats)

      %{
        retreat_behavior: categorize_retreat_style(kill_death_ratio),
        typical_escape_method: infer_escape_method(character_stats),
        survival_instinct: calculate_survival_instinct(character_stats),
        learns_from_losses: kill_death_ratio > 1.5
      }
    end
  end

  defp categorize_retreat_style(kd_ratio) do
    cond do
      kd_ratio >= 3.0 -> "tactical_withdrawal"
      kd_ratio >= 1.5 -> "fighting_retreat"
      kd_ratio >= 0.8 -> "panic_retreat"
      true -> "no_retreat"
    end
  end

  defp infer_escape_method(stats) do
    top_ship_class = Map.get(stats, :top_ship_class, "Unknown")
    wormhole_percentage = Map.get(stats, :wormhole_percentage, 0)
    nullsec_percentage = Map.get(stats, :nullsec_percentage, 0)

    cond do
      top_ship_class in ["Interceptor", "Frigate"] -> "speed_tank"
      wormhole_percentage > 50 -> "safe_logout"
      nullsec_percentage > 50 -> "gate_crash"
      true -> "warp_to_safe"
    end
  end

  defp calculate_survival_instinct(stats) do
    losses = Map.get(stats, :total_losses, 0)
    total_engagements = Map.get(stats, :total_kills, 0) + losses

    if total_engagements > 0 do
      Float.round(1 - losses / total_engagements, 2)
    else
      0.0
    end
  end

  defp categorize_ship_value_comfort(avg_ship_value) do
    cond do
      avg_ship_value > 10_000_000_000 -> :very_expensive
      avg_ship_value > 1_000_000_000 -> :expensive
      avg_ship_value > 100_000_000 -> :moderate
      avg_ship_value > 10_000_000 -> :cheap
      true -> :very_cheap
    end
  end

  defp assess_tactical_risks(character_stats) do
    %{
      engagement_threshold: calculate_engagement_threshold(character_stats),
      solo_confidence: assess_solo_confidence(character_stats),
      bait_susceptibility: calculate_bait_susceptibility(character_stats),
      overcommitment_tendency: assess_overcommitment(character_stats)
    }
  end

  defp calculate_engagement_threshold(stats) do
    solo_ratio = Map.get(stats, :solo_ratio, 0.5)
    aggression = Map.get(stats, :aggression_percentile, 50)

    cond do
      solo_ratio > 0.7 and aggression > 70 -> "1v3+"
      solo_ratio > 0.5 and aggression > 50 -> "1v2"
      solo_ratio > 0.3 -> "even_odds"
      true -> "superior_numbers"
    end
  end

  defp assess_solo_confidence(stats) do
    solo_ratio = Map.get(stats, :solo_ratio, 0.0)

    cond do
      solo_ratio >= 0.8 -> "elite_solo"
      solo_ratio >= 0.6 -> "confident_solo"
      solo_ratio >= 0.3 -> "occasional_solo"
      true -> "fleet_dependent"
    end
  end

  defp calculate_bait_susceptibility(stats) do
    aggression = Map.get(stats, :aggression_percentile, 50)
    experience = min(100, Map.get(stats, :total_kills, 0) / 10)

    susceptibility = max(0, aggression - experience)

    cond do
      susceptibility >= 60 -> "high"
      susceptibility >= 40 -> "moderate"
      susceptibility >= 20 -> "low"
      true -> "minimal"
    end
  end

  defp assess_overcommitment(stats) do
    losses = Map.get(stats, :total_losses, 0)
    aggression = Map.get(stats, :aggression_percentile, 50)

    if losses > 20 and aggression > 70 do
      "frequent"
    else
      "rare"
    end
  end

  defp analyze_insurance_patterns(character_stats) do
    avg_ship_value = Map.get(character_stats, :avg_ship_value, 0)
    losses = Map.get(character_stats, :total_losses, 0)

    %{
      likely_uses_insurance: avg_ship_value < 500_000_000 and losses > 10,
      insurance_discipline: categorize_insurance_discipline(avg_ship_value, losses),
      risk_mitigation_awareness: assess_risk_mitigation(character_stats)
    }
  end

  defp categorize_insurance_discipline(avg_value, losses) do
    cond do
      losses < 5 -> "insufficient_data"
      avg_value < 100_000_000 -> "always_insured"
      avg_value < 500_000_000 -> "selective_insurance"
      avg_value > 1_000_000_000 -> "rarely_insured"
      true -> "moderate_insurance"
    end
  end

  defp assess_risk_mitigation(stats) do
    kill_death_ratio = calculate_kill_death_ratio(stats)

    cond do
      kill_death_ratio > 3.0 -> "excellent"
      kill_death_ratio > 2.0 -> "good"
      kill_death_ratio > 1.0 -> "moderate"
      true -> "poor"
    end
  end

  defp analyze_loss_recovery(character_stats) do
    %{
      recovery_speed: assess_recovery_speed(character_stats),
      learns_from_mistakes: assess_learning_ability(character_stats),
      tilt_susceptibility: calculate_tilt_susceptibility(character_stats),
      resilience_score: calculate_resilience_score(character_stats)
    }
  end

  defp assess_recovery_speed(stats) do
    total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)

    cond do
      total_activity > 1000 -> "immediate"
      total_activity > 500 -> "quick"
      total_activity > 100 -> "moderate"
      true -> "slow"
    end
  end

  defp assess_learning_ability(stats) do
    kill_death_ratio = calculate_kill_death_ratio(stats)
    solo_ratio = Map.get(stats, :solo_ratio, 0.5)

    if kill_death_ratio > 2.0 or solo_ratio > 0.7 do
      "high"
    else
      "moderate"
    end
  end

  defp calculate_tilt_susceptibility(stats) do
    aggression = Map.get(stats, :aggression_percentile, 50)
    losses = Map.get(stats, :total_losses, 0)

    if aggression > 70 and losses > 50 do
      "high"
    else
      "low"
    end
  end

  defp calculate_resilience_score(stats) do
    kd_ratio = calculate_kill_death_ratio(stats)
    total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)

    base_score = min(1.0, kd_ratio / 3.0)
    activity_bonus = min(0.3, total_activity / 1000)

    Float.round(base_score + activity_bonus, 2)
  end

  defp categorize_ship_roles(_ship_usage) do
    # Simplified ship role categorization
    %{
      primary_role: :dps,
      secondary_role: :tank,
      role_flexibility: :moderate
    }
  end

  defp calculate_group_preference(character_stats) do
    solo_ratio =
      safe_divide(
        Map.get(character_stats, :solo_kills, 0),
        Map.get(character_stats, :total_kills, 1)
      )

    cond do
      solo_ratio > 0.7 -> :strong_solo_preference
      solo_ratio > 0.3 -> :balanced
      true -> :group_oriented
    end
  end

  defp safe_divide(numerator, denominator) when denominator > 0, do: numerator / denominator
  defp safe_divide(_, _), do: 0.0

  defp analyze_range_preferences(ship_usage) do
    # Simplified range analysis
    if map_size(ship_usage) == 0 do
      :unknown
    else
      # Assume medium range for simplicity
      :medium_range
    end
  end

  defp assess_support_role_usage(_ship_usage) do
    # Simplified support role assessment
    :occasional_support
  end

  defp calculate_doctrine_compliance(character_stats) do
    if is_nil(character_stats) do
      0.0
    else
      fleet_ratio = 1.0 - Map.get(character_stats, :solo_ratio, 0.5)
      ship_standardization = assess_ship_standardization(character_stats)

      compliance_score = fleet_ratio * 0.6 + ship_standardization * 0.4
      Float.round(compliance_score, 2)
    end
  end

  defp assess_ship_standardization(stats) do
    top_ship_class = Map.get(stats, :top_ship_class, "")

    doctrine_classes = [
      "Hurricane",
      "Drake",
      "Harbinger",
      "Ferox",
      "Moa",
      "Caracal",
      "Vexor",
      "Thorax"
    ]

    if top_ship_class in doctrine_classes do
      0.8
    else
      0.3
    end
  end

  defp determine_fleet_position(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)
      total_kills = Map.get(character_stats, :total_kills, 0)
      top_ship_class = Map.get(character_stats, :top_ship_class, "")

      cond do
        Map.get(character_stats, :is_fc, false) == true -> :fleet_commander
        solo_ratio < 0.2 and total_kills > 500 -> :anchor
        solo_ratio < 0.3 and total_kills > 200 -> :mainline_dps
        solo_ratio > 0.7 -> :scout_tackler
        top_ship_class in ["Interceptor", "Interdictor"] -> :tackle_specialist
        true -> :line_member
      end
    end
  end

  defp analyze_weapon_systems(_ship_usage) do
    # Simplified weapon system analysis
    %{
      primary_weapon_system: :hybrid_turrets,
      weapon_diversity: :moderate_diversity,
      specialization_level: :moderate
    }
  end

  defp analyze_defensive_behavior(character_stats) do
    if is_nil(character_stats) do
      %{}
    else
      kd_ratio = calculate_kill_death_ratio(character_stats)

      %{
        defensive_rating: calculate_defensive_rating(kd_ratio),
        escape_success_rate: estimate_escape_success_rate(character_stats),
        tank_preference: determine_tank_preference(character_stats),
        defensive_module_usage: assess_defensive_module_usage(character_stats)
      }
    end
  end

  defp calculate_defensive_rating(kd_ratio) do
    base_rating = min(1.0, kd_ratio / 5.0)
    min(1.0, base_rating)
  end

  defp estimate_escape_success_rate(stats) do
    kd_ratio = calculate_kill_death_ratio(stats)
    ship_class = Map.get(stats, :top_ship_class, "Unknown")

    base_rate =
      cond do
        ship_class in ["Interceptor", "Frigate"] -> 0.8
        ship_class in ["Cruiser", "Destroyer"] -> 0.6
        ship_class in ["Battlecruiser", "Battleship"] -> 0.4
        true -> 0.5
      end

    kd_modifier = min(0.2, kd_ratio / 10)
    min(1.0, base_rate + kd_modifier)
  end

  defp determine_tank_preference(stats) do
    ship_class = Map.get(stats, :top_ship_class, "Unknown")
    avg_value = Map.get(stats, :avg_ship_value, 0)

    cond do
      String.contains?(ship_class, "Amarr") -> :armor
      String.contains?(ship_class, "Caldari") -> :shield
      String.contains?(ship_class, "Gallente") -> :armor
      String.contains?(ship_class, "Minmatar") -> :shield
      avg_value > 500_000_000 -> :active
      true -> :buffer
    end
  end

  defp assess_defensive_module_usage(stats) do
    kd_ratio = calculate_kill_death_ratio(stats)
    avg_value = Map.get(stats, :avg_ship_value, 0)

    cond do
      kd_ratio > 3.0 and avg_value > 1_000_000_000 -> :heavy_defensive
      kd_ratio > 2.0 -> :moderate_defensive
      kd_ratio > 1.0 -> :light_defensive
      true -> :minimal_defensive
    end
  end

  defp assess_coordination_level(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      fleet_ratio = 1.0 - Map.get(character_stats, :solo_ratio, 0.5)
      total_kills = Map.get(character_stats, :total_kills, 0)

      cond do
        fleet_ratio > 0.8 and total_kills > 500 -> :excellent
        fleet_ratio > 0.6 and total_kills > 200 -> :good
        fleet_ratio > 0.4 -> :moderate
        fleet_ratio > 0.2 -> :limited
        true -> :minimal
      end
    end
  end

  defp calculate_corp_loyalty(corp_history) do
    case length(corp_history) do
      0 -> :unknown
      1 -> :very_loyal
      2 -> :loyal
      n when n <= 5 -> :moderate
      _ -> :low
    end
  end

  defp assess_alliance_participation(alliance_activity) do
    if map_size(alliance_activity) == 0 do
      :unknown
    else
      total_ops = Map.get(alliance_activity, :total_operations, 0)
      ops_attended = Map.get(alliance_activity, :operations_attended, 0)
      strategic_participation = Map.get(alliance_activity, :strategic_ops, 0)

      participation_rate = if total_ops > 0, do: ops_attended / total_ops, else: 0.0

      cond do
        participation_rate > 0.8 and strategic_participation > 10 -> :exemplary
        participation_rate > 0.6 -> :active
        participation_rate > 0.4 -> :regular
        participation_rate > 0.2 -> :casual
        true -> :minimal
      end
    end
  end

  defp identify_leadership_signs(character_stats) do
    if is_nil(character_stats) do
      []
    else
      signs = []

      if Map.get(character_stats, :is_fc, false) == true do
        signs = ["fleet_commander" | signs]
      end

      fleet_ratio = 1.0 - Map.get(character_stats, :solo_ratio, 0.5)
      kd_ratio = calculate_kill_death_ratio(character_stats)

      if fleet_ratio > 0.7 and kd_ratio > 2.0 do
        signs = ["experienced_fleet_member" | signs]
      end

      if Map.get(character_stats, :total_kills, 0) > 500 and fleet_ratio > 0.6 do
        signs = ["potential_anchor" | signs]
      end

      if Map.get(character_stats, :corp_role) in ["CEO", "Director"] do
        signs = ["corp_leadership" | signs]
      end

      signs
    end
  end

  defp assess_cooperation_behavior(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      fleet_ratio = 1.0 - Map.get(character_stats, :solo_ratio, 0.5)
      gang_ratio = Map.get(character_stats, :gang_ratio, 0.0)

      cooperation_score = fleet_ratio * 0.6 + gang_ratio * 0.4

      cond do
        cooperation_score > 0.8 -> :highly_cooperative
        cooperation_score > 0.6 -> :cooperative
        cooperation_score > 0.4 -> :selective_cooperation
        cooperation_score > 0.2 -> :independent
        true -> :lone_wolf
      end
    end
  end

  defp analyze_communication_style(_character_stats) do
    # Simplified communication analysis
    :standard
  end

  defp assess_mentor_characteristics(_character_stats) do
    # Simplified mentor assessment
    :potential
  end

  defp calculate_performance_variance(_character_stats) do
    # Simplified performance variance
    0.5
  end

  defp calculate_timing_consistency(character_stats) do
    if is_nil(character_stats) do
      0.0
    else
      activity_by_hour = Map.get(character_stats, :activity_by_hour, %{})

      if map_size(activity_by_hour) == 0 do
        0.0
      else
        activity_values = Map.values(activity_by_hour)
        mean = Enum.sum(activity_values) / length(activity_values)

        variance =
          activity_values
          |> Enum.map(fn val -> :math.pow(val - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(activity_values))

        std_dev = :math.sqrt(variance)

        if mean > 0 do
          consistency = 1.0 - min(1.0, std_dev / mean)
          consistency
        else
          0.0
        end
      end
    end
  end

  defp calculate_behavior_stability(character_stats) do
    if is_nil(character_stats) do
      0.0
    else
      factors = []

      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)
      solo_stability = if solo_ratio > 0.8 or solo_ratio < 0.2, do: 0.9, else: 0.5
      factors = [solo_stability | factors]

      kd_ratio = calculate_kill_death_ratio(character_stats)

      kd_stability =
        cond do
          kd_ratio > 3.0 -> 0.9
          kd_ratio > 2.0 -> 0.7
          kd_ratio > 1.0 -> 0.5
          true -> 0.3
        end

      factors = [kd_stability | factors]

      ship_diversity =
        if Map.get(character_stats, :ship_diversity_index, 0) > 0.7, do: 0.3, else: 0.8

      factors = [ship_diversity | factors]

      Enum.sum(factors) / length(factors)
    end
  end

  defp calculate_predictability(character_stats) do
    if is_nil(character_stats) do
      0.0
    else
      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)
      activity_consistency = calculate_timing_consistency(character_stats)

      preference_predictability =
        if solo_ratio > 0.8 or solo_ratio < 0.2, do: 0.8, else: 0.4

      timing_predictability = activity_consistency

      ship_count = Map.get(character_stats, :unique_ships_used, 1)

      ship_predictability =
        cond do
          ship_count <= 3 -> 0.9
          ship_count <= 5 -> 0.7
          ship_count <= 10 -> 0.5
          true -> 0.3
        end

      (preference_predictability + timing_predictability + ship_predictability) / 3
    end
  end

  defp assess_adaptation_speed(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      total_activity =
        Map.get(character_stats, :total_kills, 0) + Map.get(character_stats, :total_losses, 0)

      kd_ratio = calculate_kill_death_ratio(character_stats)
      ship_diversity = Map.get(character_stats, :ship_diversity_index, 0.0)

      adaptation_score = 0.0

      adaptation_score =
        if total_activity > 1000, do: adaptation_score + 0.3, else: adaptation_score

      adaptation_score = if kd_ratio > 2.0, do: adaptation_score + 0.3, else: adaptation_score

      adaptation_score =
        if ship_diversity > 0.5, do: adaptation_score + 0.4, else: adaptation_score

      cond do
        adaptation_score > 0.8 -> :very_fast
        adaptation_score > 0.6 -> :fast
        adaptation_score > 0.4 -> :moderate
        adaptation_score > 0.2 -> :slow
        true -> :very_slow
      end
    end
  end

  defp identify_primary_traits(character_stats) do
    if is_nil(character_stats) do
      []
    else
      traits = []

      kd_ratio = calculate_kill_death_ratio(character_stats)
      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)

      total_activity =
        Map.get(character_stats, :total_kills, 0) + Map.get(character_stats, :total_losses, 0)

      if kd_ratio > 3.0, do: traits = ["elite_pilot" | traits]
      if kd_ratio > 2.0, do: traits = ["skilled_combatant" | traits]

      if solo_ratio > 0.8, do: traits = ["lone_wolf" | traits]
      if solo_ratio < 0.2, do: traits = ["fleet_specialist" | traits]

      if total_activity > 1000, do: traits = ["veteran" | traits]
      if total_activity > 500, do: traits = ["experienced" | traits]

      if Map.get(character_stats, :flies_capitals, false) == true,
        do: traits = ["capital_pilot" | traits]

      if Map.get(character_stats, :avg_ship_value, 0) > 1_000_000_000,
        do: traits = ["high_stakes" | traits]

      if Map.get(character_stats, :nullsec_percentage, 0) > 70,
        do: traits = ["nullsec_resident" | traits]

      if Map.get(character_stats, :wormhole_percentage, 0) > 50,
        do: traits = ["wormholer" | traits]

      Enum.take(traits, 5)
    end
  end

  defp determine_behavioral_archetype(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)
      kd_ratio = calculate_kill_death_ratio(character_stats)

      total_activity =
        Map.get(character_stats, :total_kills, 0) + Map.get(character_stats, :total_losses, 0)

      aggression = Map.get(character_stats, :aggression_percentile, 50)

      cond do
        solo_ratio > 0.7 and kd_ratio > 3.0 and aggression > 70 ->
          :apex_predator

        solo_ratio < 0.3 and kd_ratio > 2.0 and total_activity > 500 ->
          :fleet_anchor

        solo_ratio > 0.3 and solo_ratio < 0.7 and kd_ratio > 1.5 ->
          :gang_warrior

        Map.get(character_stats, :avg_ship_value, 0) > 2_000_000_000 and kd_ratio > 1.0 ->
          :high_roller

        aggression > 60 and total_activity > 300 ->
          :opportunist

        Map.get(character_stats, :top_ship_class, "") in ["Logistics", "Electronic Attack"] ->
          :support_specialist

        total_activity < 50 ->
          :rookie

        true ->
          :generalist
      end
    end
  end

  defp generate_psychological_profile(character_stats) do
    if is_nil(character_stats) do
      %{}
    else
      kd_ratio = calculate_kill_death_ratio(character_stats)
      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)
      aggression = Map.get(character_stats, :aggression_percentile, 50)
      losses = Map.get(character_stats, :total_losses, 0)

      %{
        risk_tolerance: assess_psychological_risk_tolerance(character_stats),
        stress_response: analyze_stress_response(kd_ratio, losses),
        social_preference: determine_social_preference(solo_ratio),
        conflict_approach: assess_conflict_approach(aggression, kd_ratio),
        learning_style: determine_learning_style(character_stats),
        decision_making: assess_decision_making_style(character_stats)
      }
    end
  end

  defp assess_psychological_risk_tolerance(stats) do
    avg_ship_value = Map.get(stats, :avg_ship_value, 0)
    flies_caps = Map.get(stats, :flies_capitals, false)

    cond do
      flies_caps and avg_ship_value > 5_000_000_000 -> :extremely_high
      avg_ship_value > 2_000_000_000 -> :high
      avg_ship_value > 500_000_000 -> :moderate
      avg_ship_value > 50_000_000 -> :low
      true -> :very_low
    end
  end

  defp analyze_stress_response(kd_ratio, losses) do
    if losses < 10 do
      :insufficient_data
    else
      cond do
        kd_ratio > 2.0 -> :composed_under_pressure
        kd_ratio > 1.0 -> :stable_performance
        kd_ratio > 0.5 -> :performance_decline
        true -> :stress_vulnerable
      end
    end
  end

  defp determine_social_preference(solo_ratio) do
    cond do
      solo_ratio > 0.8 -> :strongly_independent
      solo_ratio > 0.6 -> :prefers_independence
      solo_ratio > 0.4 -> :balanced_social
      solo_ratio > 0.2 -> :prefers_groups
      true -> :highly_social
    end
  end

  defp assess_conflict_approach(aggression, kd_ratio) do
    cond do
      aggression > 80 and kd_ratio > 2.0 -> :calculated_aggression
      aggression > 70 -> :aggressive_approach
      aggression > 50 and kd_ratio > 1.5 -> :strategic_engagement
      aggression > 30 -> :cautious_engagement
      true -> :conflict_avoidant
    end
  end

  defp determine_learning_style(stats) do
    ship_diversity = Map.get(stats, :ship_diversity_index, 0.0)
    total_activity = Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)

    cond do
      ship_diversity > 0.7 and total_activity > 500 -> :experimental_learner
      ship_diversity > 0.5 -> :adaptive_learner
      ship_diversity < 0.3 and total_activity > 300 -> :specialist_learner
      true -> :conventional_learner
    end
  end

  defp assess_decision_making_style(stats) do
    solo_ratio = Map.get(stats, :solo_ratio, 0.5)
    kd_ratio = calculate_kill_death_ratio(stats)

    cond do
      solo_ratio > 0.7 and kd_ratio > 2.0 -> :independent_decisive
      solo_ratio > 0.5 -> :self_reliant
      kd_ratio > 1.5 -> :analytical_decision_maker
      true -> :consensus_seeker
    end
  end

  defp assess_predictability_rating(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      predictability_score = calculate_predictability(character_stats)

      cond do
        predictability_score > 0.8 -> :highly_predictable
        predictability_score > 0.6 -> :predictable
        predictability_score > 0.4 -> :moderately_predictable
        predictability_score > 0.2 -> :unpredictable
        true -> :highly_unpredictable
      end
    end
  end

  defp assess_adaptation_capability(character_stats) do
    if is_nil(character_stats) do
      :unknown
    else
      adaptation_speed = assess_adaptation_speed(character_stats)
      ship_diversity = Map.get(character_stats, :ship_diversity_index, 0.0)
      kd_ratio = calculate_kill_death_ratio(character_stats)

      speed_score =
        case adaptation_speed do
          :very_fast -> 1.0
          :fast -> 0.8
          :moderate -> 0.6
          :slow -> 0.4
          :very_slow -> 0.2
          _ -> 0.5
        end

      diversity_factor = min(0.3, ship_diversity)
      performance_factor = min(0.2, kd_ratio / 5.0)

      total_score = speed_score + diversity_factor + performance_factor

      cond do
        total_score > 1.0 -> :exceptional
        total_score > 0.8 -> :high
        total_score > 0.6 -> :moderate
        total_score > 0.4 -> :limited
        true -> :poor
      end
    end
  end

  defp extract_key_indicators(character_stats) do
    if is_nil(character_stats) do
      []
    else
      indicators = []

      kd_ratio = calculate_kill_death_ratio(character_stats)
      if kd_ratio > 3.0, do: indicators = ["exceptional_kd_ratio" | indicators]

      solo_ratio = Map.get(character_stats, :solo_ratio, 0.5)
      if solo_ratio > 0.8, do: indicators = ["strong_solo_preference" | indicators]

      total_activity =
        Map.get(character_stats, :total_kills, 0) + Map.get(character_stats, :total_losses, 0)

      if total_activity > 1000, do: indicators = ["highly_active" | indicators]

      if Map.get(character_stats, :flies_capitals, false),
        do: indicators = ["capital_capable" | indicators]

      Enum.take(indicators, 5)
    end
  end

  defp assess_escalation_tendency(_character_stats) do
    # Simplified escalation assessment
    :moderate
  end

  defp calculate_kill_death_ratio(stats) do
    kills = Map.get(stats, :total_kills, 0)
    losses = Map.get(stats, :total_losses, 0)

    if losses > 0 do
      kills / losses
    else
      min(kills, 100.0)
    end
  end
end
