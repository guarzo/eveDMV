defmodule EveDmv.IntelligenceEngine.Plugins.Character.BehavioralPatterns do
  @moduledoc """
  Character behavioral patterns analysis plugin.

  Analyzes individual character behavioral patterns including activity timing,
  engagement preferences, risk tolerance, and tactical patterns. This plugin
  consolidates functionality from behavioral analysis modules.
  """

  use EveDmv.IntelligenceEngine.Plugin

  @impl true
  def analyze(character_id, base_data, opts) when is_integer(character_id) do
    start_time = System.monotonic_time()

    try do
      with {:ok, character_stats} <- get_character_data(base_data, character_id),
           {:ok, killmail_stats} <- get_killmail_stats(base_data, character_id) do
        behavioral_analysis = %{
          activity_patterns: analyze_activity_patterns(character_stats),
          engagement_behavior: analyze_engagement_behavior(character_stats),
          risk_profile: analyze_risk_profile(character_stats),
          tactical_patterns: analyze_tactical_patterns(character_stats),
          social_behavior: analyze_social_behavior(character_stats),
          consistency_metrics: calculate_consistency_metrics(character_stats, killmail_stats),
          behavioral_summary: generate_behavioral_summary(character_stats)
        }

        duration_ms =
          System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        log_plugin_execution(character_id, duration_ms, {:ok, behavioral_analysis})

        {:ok, behavioral_analysis}
      else
        {:error, reason} = error ->
          duration_ms =
            System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

          log_plugin_execution(character_id, duration_ms, error)
          error
      end
    rescue
      exception ->
        handle_plugin_exception(exception, character_id)
    end
  end

  # Batch analysis support
  @impl true
  def analyze(character_ids, base_data, opts) when is_list(character_ids) do
    if supports_batch?() do
      # Parallel batch processing for multiple characters
      character_ids
      |> Enum.map(fn char_id ->
        Task.async(fn -> {char_id, analyze(char_id, base_data, opts)} end)
      end)
      |> Enum.map(&Task.await(&1, 30_000))
      |> merge_batch_results()
      |> then(&{:ok, &1})
    else
      {:error, :batch_not_supported}
    end
  end

  @impl true
  def plugin_info do
    %{
      name: "Behavioral Patterns Analyzer",
      description:
        "Analyzes character behavioral patterns, activity timing, and tactical preferences",
      version: "2.0.0",
      dependencies: [:eve_database],
      tags: [:character, :behavior, :patterns, :psychology],
      author: "EVE DMV Intelligence Team"
    }
  end

  @impl true
  def supports_batch?, do: true

  @impl true
  def dependencies, do: [EveDmv.Database.CharacterRepository, EveDmv.Database.KillmailRepository]

  @impl true
  def cache_strategy do
    %{
      strategy: :default,
      # 10 minutes for behavioral patterns
      ttl_seconds: 600,
      cache_key_prefix: "behavioral_patterns"
    }
  end

  # Analysis implementation

  defp analyze_activity_patterns(character_stats) do
    activity_data = character_stats.activity_by_hour || %{}
    activity_by_day = character_stats.activity_by_day || %{}

    # Analyze hourly patterns
    peak_hours =
      activity_data
      |> Enum.sort_by(fn {_hour, activity} -> activity end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, activity} -> %{hour: hour, activity_level: activity} end)

    # Analyze daily patterns
    active_days =
      activity_by_day
      |> Enum.filter(fn {_day, activity} -> activity > 0 end)
      |> Enum.map(fn {day, activity} -> %{day: day, activity_level: activity} end)

    # Calculate consistency
    activity_variance = calculate_activity_variance(Map.values(activity_data))
    consistency_rating = calculate_consistency_rating(activity_variance)

    %{
      peak_activity_hours: peak_hours,
      active_days_pattern: active_days,
      prime_timezone: character_stats.prime_timezone,
      activity_consistency: consistency_rating,
      total_active_hours: map_size(activity_data),
      weekend_vs_weekday: analyze_weekend_patterns(activity_by_day),
      session_length_preference: determine_session_length(character_stats),
      activity_trend: calculate_activity_trend(character_stats)
    }
  end

  defp analyze_engagement_behavior(character_stats) do
    engagement_data = character_stats.engagement_patterns || %{}

    # Analyze aggression patterns
    aggression_indicators = %{
      initiation_rate: Map.get(engagement_data, "initiation_rate", 0.0),
      first_strike_preference: Map.get(engagement_data, "first_strike", false),
      opportunistic_behavior: Map.get(engagement_data, "opportunistic", 0.0)
    }

    # Analyze target selection patterns
    target_selection = %{
      preferred_ship_sizes: extract_preferred_targets(character_stats.target_profile || %{}),
      risk_tolerance: assess_target_risk_tolerance(character_stats),
      victim_selection_logic: analyze_victim_patterns(character_stats)
    }

    # Analyze combat duration patterns
    combat_patterns = %{
      avg_engagement_duration: Map.get(engagement_data, "avg_duration_seconds", 0),
      quick_kill_preference: Map.get(engagement_data, "quick_kills", 0.0),
      prolonged_fight_tolerance: Map.get(engagement_data, "long_fights", 0.0)
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
    security_profile = character_stats.security_preferences || %{}

    # Calculate risk tolerance metrics
    high_risk_indicators = [
      character_stats.flies_capitals || false,
      # 1B+ ISK ships
      (character_stats.avg_ship_value || 0) > 1_000_000_000,
      Map.get(security_profile, "nullsec_percentage", 0.0) > 0.5,
      character_stats.uses_cynos || false
    ]

    risk_score = Enum.count(high_risk_indicators, & &1) / length(high_risk_indicators)

    %{
      security_space_preferences: security_profile,
      risk_tolerance_score: risk_score,
      ship_value_comfort: categorize_ship_value_comfort(character_stats.avg_ship_value || 0),
      tactical_risk_taking: assess_tactical_risks(character_stats),
      insurance_behavior: analyze_insurance_patterns(character_stats),
      loss_recovery_patterns: analyze_loss_recovery(character_stats)
    }
  end

  defp analyze_tactical_patterns(character_stats) do
    ship_usage = character_stats.ship_usage || %{}
    target_profile = character_stats.target_profile || %{}

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
    corp_history = character_stats.corporation_history || []
    alliance_activity = character_stats.alliance_activity || %{}

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
      psychological_profile: generate_psychological_profile(character_stats),
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
      # Mon-Fri
      |> Enum.filter(fn {day, _} -> day in [1, 2, 3, 4, 5] end)
      |> Enum.map(fn {_, activity} -> activity end)
      |> average_or_zero()

    weekend_activity =
      activity_by_day
      # Sat-Sun
      |> Enum.filter(fn {day, _} -> day in [6, 7] end)
      |> Enum.map(fn {_, activity} -> activity end)
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
    avg_session = character_stats.avg_session_length_minutes || 60

    cond do
      avg_session < 30 -> :short_sessions
      avg_session < 120 -> :medium_sessions
      avg_session < 300 -> :long_sessions
      true -> :marathon_sessions
    end
  end

  defp calculate_activity_trend(character_stats) do
    # Placeholder - would analyze activity over time
    recent_activity = character_stats.recent_activity_trend || 0.0

    cond do
      recent_activity > 0.1 -> :increasing
      recent_activity < -0.1 -> :decreasing
      true -> :stable
    end
  end

  defp extract_preferred_targets(target_profile) do
    ship_categories = Map.get(target_profile, "ship_categories", %{})

    ship_categories
    |> Enum.sort_by(fn {_category, data} -> Map.get(data, "killed", 0) end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {category, data} ->
      %{category: category, kills: Map.get(data, "killed", 0)}
    end)
  end

  defp assess_target_risk_tolerance(character_stats) do
    avg_victim_value = character_stats.avg_victim_ship_value || 0

    cond do
      avg_victim_value > 5_000_000_000 -> :very_high_risk
      avg_victim_value > 1_000_000_000 -> :high_risk
      avg_victim_value > 100_000_000 -> :moderate_risk
      avg_victim_value > 10_000_000 -> :low_risk
      true -> :very_low_risk
    end
  end

  defp analyze_victim_patterns(character_stats) do
    victim_data = character_stats.victim_analysis || %{}

    %{
      targets_newbies: Map.get(victim_data, "targets_new_players", false),
      ganks_haulers: Map.get(victim_data, "targets_industrials", false),
      hunts_pvpers: Map.get(victim_data, "targets_pvp_pilots", false),
      opportunistic: Map.get(victim_data, "opportunistic_kills", 0.0) > 0.7
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

  defp analyze_engagement_timing(_character_stats) do
    # Placeholder for engagement timing analysis
    %{
      waits_for_advantage: true,
      strike_timing: :calculated,
      patience_level: :moderate
    }
  end

  defp analyze_backup_patterns(character_stats) do
    batphone_prob = character_stats.batphone_probability || "low"

    %{
      calls_for_backup: batphone_prob != "low",
      backup_frequency: batphone_prob,
      escalation_tendency: assess_escalation_tendency(character_stats)
    }
  end

  defp analyze_retreat_behavior(_character_stats) do
    # Placeholder for retreat pattern analysis
    %{
      tactical_retreat_usage: :moderate,
      loss_avoidance: :high,
      knows_when_to_disengage: true
    }
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

  defp assess_tactical_risks(_character_stats) do
    # Placeholder for tactical risk assessment
    %{
      takes_calculated_risks: true,
      risk_reward_balance: :good,
      overextension_tendency: :low
    }
  end

  defp analyze_insurance_patterns(_character_stats) do
    # Placeholder for insurance behavior analysis
    %{uses_insurance: true, insurance_efficiency: :high}
  end

  defp analyze_loss_recovery(_character_stats) do
    # Placeholder for loss recovery analysis
    %{recovery_speed: :fast, learns_from_losses: true}
  end

  defp categorize_ship_roles(ship_usage) do
    # Analyze ship usage to determine preferred roles
    role_counts = %{
      dps: 0,
      tank: 0,
      support: 0,
      ewar: 0,
      logistics: 0
    }

    # This would be implemented with actual ship type analysis
    # For now, return a placeholder
    %{
      primary_role: :dps,
      secondary_role: :tank,
      role_flexibility: :moderate
    }
  end

  defp calculate_group_preference(character_stats) do
    solo_ratio = safe_divide(character_stats.solo_kills || 0, character_stats.total_kills || 1)

    cond do
      solo_ratio > 0.7 -> :strong_solo_preference
      solo_ratio > 0.3 -> :balanced
      true -> :group_oriented
    end
  end

  defp safe_divide(numerator, denominator) when denominator > 0, do: numerator / denominator
  defp safe_divide(_, _), do: 0.0

  # Placeholder implementations for remaining helper functions
  defp analyze_range_preferences(_ship_usage), do: :mixed
  defp assess_support_role_usage(_ship_usage), do: :occasional
  defp calculate_doctrine_compliance(_character_stats), do: 0.75
  defp determine_fleet_position(_character_stats), do: :front_line
  defp analyze_weapon_systems(_ship_usage), do: %{specialization: :moderate}
  defp analyze_defensive_behavior(_character_stats), do: %{defensive_score: 0.6}
  defp assess_coordination_level(_character_stats), do: :good
  defp calculate_corp_loyalty(_corp_history), do: :moderate
  defp assess_alliance_participation(_alliance_activity), do: :active
  defp identify_leadership_signs(_character_stats), do: []
  defp assess_cooperation_behavior(_character_stats), do: :cooperative
  defp analyze_communication_style(_character_stats), do: :tactical
  defp assess_mentor_characteristics(_character_stats), do: :potential
  defp calculate_performance_variance(_character_stats), do: 0.7
  defp calculate_timing_consistency(_character_stats), do: 0.8
  defp calculate_behavior_stability(_character_stats), do: 0.75
  defp calculate_predictability(_character_stats), do: 0.6
  defp assess_adaptation_speed(_character_stats), do: :moderate
  defp identify_primary_traits(_character_stats), do: [:aggressive, :tactical]
  defp determine_behavioral_archetype(_character_stats), do: :hunter
  defp generate_psychological_profile(_character_stats), do: %{type: :analytical}
  defp assess_predictability_rating(_character_stats), do: :moderate
  defp assess_adaptation_capability(_character_stats), do: :good
  defp extract_key_indicators(_character_stats), do: [:aggressive_initiation, :tactical_patience]
  defp assess_escalation_tendency(_character_stats), do: :controlled
end
