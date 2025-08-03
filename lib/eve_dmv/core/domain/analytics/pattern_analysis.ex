defmodule EveDmv.Core.Domain.Analytics.PatternAnalysis do
  @moduledoc """
  Statistical pattern analysis for character behavior.

  Provides comprehensive analysis of player behavioral patterns
  including activity rhythms, engagement styles, and anomaly detection.

  This module consolidates pattern analysis functionality that was previously
  scattered across multiple contexts during the namespace consolidation.
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Utils.DateHelper

  require Logger

  @doc """
  Analyze activity rhythm patterns from character stats.

  Returns activity pattern classification and metrics based on statistical
  analysis of combat activity timing patterns.

  ## Parameters

  - `stats` - Character statistics map containing killmail and activity data

  ## Returns

  Map containing:
  - `:pattern_type` - Classification of activity pattern (:regular, :sporadic, :bursty, :inactive)
  - `:peak_hours` - List of hours (0-23) when character is most active
  - `:consistency_score` - Float 0.0-1.0 indicating consistency of activity
  - `:timezone_estimate` - Estimated timezone offset from UTC

  ## Examples

      iex> stats = %{killmails: [...], activity_data: [...]}
      iex> PatternAnalysis.analyze_activity_rhythm(stats)
      %{
        pattern_type: :regular,
        peak_hours: [18, 19, 20, 21],
        consistency_score: 0.75,
        timezone_estimate: -5
      }
  """
  @spec analyze_activity_rhythm(map()) :: map()
  def analyze_activity_rhythm(stats) do
    killmails = Map.get(stats, :killmails, [])

    if Enum.empty?(killmails) do
      %{
        pattern_type: :inactive,
        peak_hours: [],
        consistency_score: 0.0,
        timezone_estimate: 0
      }
    else
      hourly_activity = calculate_hourly_activity(killmails)
      weekly_consistency = calculate_weekly_consistency(killmails)

      %{
        pattern_type: classify_activity_pattern(hourly_activity, weekly_consistency),
        peak_hours: find_peak_activity_hours(hourly_activity),
        consistency_score: weekly_consistency,
        timezone_estimate: estimate_timezone(hourly_activity)
      }
    end
  end

  @doc """
  Analyze engagement patterns and combat behavior.

  Examines how the character engages in combat, including aggression levels,
  risk tolerance, and fleet vs solo preferences.

  ## Parameters

  - `stats` - Character statistics map containing combat data

  ## Returns

  Map containing:
  - `:engagement_style` - Classification (:aggressive, :cautious, :opportunistic, :support)
  - `:aggression_level` - Float 0.0-1.0 indicating aggression
  - `:risk_tolerance` - Float 0.0-1.0 indicating willingness to take risks
  - `:fleet_preference` - Float 0.0-1.0, closer to 1.0 means prefers fleets
  """
  @spec analyze_engagement_patterns(map()) :: map()
  def analyze_engagement_patterns(stats) do
    killmails = Map.get(stats, :killmails, [])
    losses = Map.get(stats, :losses, [])

    if Enum.empty?(killmails) and Enum.empty?(losses) do
      %{
        engagement_style: :unknown,
        aggression_level: 0.0,
        risk_tolerance: 0.0,
        fleet_preference: 0.5
      }
    else
      aggression = calculate_aggression_level(killmails, losses)
      risk_tolerance = calculate_risk_tolerance(killmails, losses)
      fleet_pref = calculate_fleet_preference(killmails, losses)

      %{
        engagement_style: classify_engagement_style(aggression, risk_tolerance, fleet_pref),
        aggression_level: aggression,
        risk_tolerance: risk_tolerance,
        fleet_preference: fleet_pref
      }
    end
  end

  @doc """
  Analyze social patterns based on combat data.

  Examines corporation affiliations, alliance relationships, and
  cooperation patterns in combat scenarios.

  ## Parameters

  - `stats` - Character statistics containing affiliation and combat data

  ## Returns

  Map containing social pattern analysis results.
  """
  @spec analyze_social_patterns(map()) :: map()
  def analyze_social_patterns(stats) do
    killmails = Map.get(stats, :killmails, [])

    if Enum.empty?(killmails) do
      %{
        cooperation_level: 0.0,
        loyalty_score: 0.0,
        social_connections: 0,
        group_activity_preference: 0.5
      }
    else
      %{
        cooperation_level: calculate_cooperation_level(killmails),
        loyalty_score: calculate_loyalty_score(stats),
        social_connections: count_unique_associates(killmails),
        group_activity_preference: calculate_group_preference(killmails)
      }
    end
  end

  @doc """
  Analyze operational patterns in combat behavior.

  Examines ship preferences, system preferences, and tactical patterns.

  ## Parameters

  - `stats` - Character statistics containing operational data

  ## Returns

  Map containing operational pattern analysis.
  """
  @spec analyze_operational_patterns(map()) :: map()
  def analyze_operational_patterns(stats) do
    killmails = Map.get(stats, :killmails, [])

    if Enum.empty?(killmails) do
      %{
        ship_specialization: :unknown,
        tactical_patterns: [],
        operational_range: :local,
        adaptability_score: 0.0
      }
    else
      %{
        ship_specialization: analyze_ship_specialization(killmails),
        tactical_patterns: identify_tactical_patterns(killmails),
        operational_range: classify_operational_range(killmails),
        adaptability_score: calculate_adaptability(killmails)
      }
    end
  end

  @doc """
  Analyze risk progression patterns over time.

  Examines how the character's risk-taking behavior has evolved,
  incorporating vetting data when available.

  ## Parameters

  - `stats` - Character statistics
  - `vetting` - Optional vetting data for additional context

  ## Returns

  Map containing risk progression analysis.
  """
  @spec analyze_risk_progression(map(), map() | nil) :: map()
  def analyze_risk_progression(stats, vetting \\ nil) do
    killmails = Map.get(stats, :killmails, [])

    if Enum.empty?(killmails) do
      %{
        risk_trend: :stable,
        experience_level: :novice,
        progression_rate: 0.0,
        threat_evolution: :static
      }
    else
      sorted_kills = Enum.sort_by(killmails, & &1.killmail_time)

      %{
        risk_trend: analyze_risk_trend(sorted_kills),
        experience_level: assess_experience_level(sorted_kills, vetting),
        progression_rate: calculate_progression_rate(sorted_kills),
        threat_evolution: classify_threat_evolution(sorted_kills)
      }
    end
  end

  @doc """
  Detect behavioral anomalies in character patterns.

  Identifies unusual patterns that deviate from the character's
  normal behavior profile.

  ## Parameters

  - `stats` - Character statistics for anomaly detection

  ## Returns

  Map containing anomaly detection results.
  """
  @spec detect_behavioral_anomalies(map()) :: map()
  def detect_behavioral_anomalies(stats) do
    killmails = Map.get(stats, :killmails, [])

    if length(killmails) < 10 do
      %{
        anomalies_detected: false,
        anomaly_types: [],
        confidence_score: 0.0,
        risk_indicators: []
      }
    else
      anomalies = []

      # Check for activity spikes
      anomalies = check_activity_anomalies(killmails, anomalies)

      # Check for behavior changes
      anomalies = check_behavior_changes(killmails, anomalies)

      # Check for risk pattern changes
      anomalies = check_risk_anomalies(killmails, anomalies)

      %{
        anomalies_detected: not Enum.empty?(anomalies),
        anomaly_types: Enum.map(anomalies, & &1.type),
        confidence_score: calculate_anomaly_confidence(anomalies),
        risk_indicators: extract_risk_indicators(anomalies)
      }
    end
  end

  # Private helper functions for statistical analysis

  defp calculate_hourly_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTime.to_time()
      |> Map.get(:hour)
    end)
    |> Enum.into(%{}, fn {hour, kills} -> {hour, length(kills)} end)
    |> Map.merge(for(h <- 0..23, do: {h, 0}, into: %{}), fn _k, v1, _v2 -> v1 end)
  end

  defp calculate_weekly_consistency(killmails) do
    if length(killmails) < 7 do
      0.0
    else
      # Group by week and calculate variance
      weekly_counts =
        killmails
        |> Enum.group_by(fn km ->
          {DateHelper.get_year(km.killmail_time), DateHelper.get_week_of_year(km.killmail_time)}
        end)
        |> Enum.map(fn {_week, kills} -> length(kills) end)

      if length(weekly_counts) < 2 do
        0.5
      else
        mean = Enum.sum(weekly_counts) / length(weekly_counts)

        variance =
          weekly_counts
          |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(weekly_counts))

        # Convert variance to consistency score (lower variance = higher consistency)
        max(0.0, min(1.0, 1.0 - variance / (mean + 1)))
      end
    end
  end

  defp classify_activity_pattern(hourly_activity, consistency) do
    total_kills = Map.values(hourly_activity) |> Enum.sum()

    cond do
      total_kills == 0 -> :inactive
      consistency > 0.7 -> :regular
      consistency < 0.3 -> :sporadic
      true -> :bursty
    end
  end

  defp find_peak_activity_hours(hourly_activity) do
    max_activity = Map.values(hourly_activity) |> Enum.max()
    # Find hours with at least 70% of peak activity
    threshold = max(1, max_activity * 0.7)

    hourly_activity
    |> Enum.filter(fn {_hour, count} -> count >= threshold end)
    |> Enum.map(fn {hour, _count} -> hour end)
    |> Enum.sort()
  end

  defp estimate_timezone(hourly_activity) do
    # Find the hour with peak activity and estimate timezone
    {peak_hour, _} = Enum.max_by(hourly_activity, fn {_hour, count} -> count end)

    # Assume peak activity around 20:00 local time
    # This is a rough estimation
    estimated_offset = peak_hour - 20

    cond do
      estimated_offset > 12 -> estimated_offset - 24
      estimated_offset < -12 -> estimated_offset + 24
      true -> estimated_offset
    end
  end

  defp calculate_aggression_level(killmails, losses) do
    if Enum.empty?(killmails) and Enum.empty?(losses) do
      0.0
    else
      kill_count = length(killmails)
      loss_count = length(losses)
      total_engagements = kill_count + loss_count

      if total_engagements == 0 do
        0.0
      else
        # Higher kill ratio indicates more aggressive behavior
        base_aggression = kill_count / total_engagements

        # Adjust for engagement frequency (more engagements = more aggressive)
        frequency_factor = min(1.0, total_engagements / 100.0)

        min(1.0, base_aggression * (0.8 + 0.2 * frequency_factor))
      end
    end
  end

  defp calculate_risk_tolerance(killmails, losses) do
    all_engagements = killmails ++ losses

    if Enum.empty?(all_engagements) do
      0.0
    else
      # Analyze ship values and engagement contexts
      high_value_engagements =
        all_engagements
        |> Enum.filter(fn engagement ->
          ship_value = Map.get(engagement, :ship_value, 0)
          # 100M ISK threshold
          ship_value > 100_000_000
        end)
        |> length()

      total_engagements = length(all_engagements)

      # Calculate risk tolerance based on high-value ship usage
      high_value_ratio = high_value_engagements / total_engagements

      # Scale to 0.0-1.0 range
      min(1.0, high_value_ratio * 2.0)
    end
  end

  defp calculate_fleet_preference(killmails, losses) do
    all_engagements = killmails ++ losses

    if Enum.empty?(all_engagements) do
      # Neutral preference when no data
      0.5
    else
      fleet_engagements =
        all_engagements
        |> Enum.filter(fn engagement ->
          participant_count = Map.get(engagement, :participant_count, 1)
          # More than 3 participants = fleet engagement
          participant_count > 3
        end)
        |> length()

      total_engagements = length(all_engagements)
      fleet_engagements / total_engagements
    end
  end

  defp classify_engagement_style(aggression, risk_tolerance, fleet_preference) do
    cond do
      aggression > 0.7 and risk_tolerance > 0.6 -> :aggressive
      aggression < 0.3 and fleet_preference > 0.7 -> :support
      risk_tolerance < 0.3 -> :cautious
      true -> :opportunistic
    end
  end

  defp calculate_cooperation_level(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Calculate average participants per killmail
      total_participants =
        killmails
        |> Enum.map(fn km -> Map.get(km, :participant_count, 1) end)
        |> Enum.sum()

      avg_participants = total_participants / length(killmails)

      # Scale to 0.0-1.0 where higher participation = higher cooperation
      min(1.0, (avg_participants - 1) / 10.0)
    end
  end

  defp calculate_loyalty_score(stats) do
    # Analyze corporation/alliance stability
    affiliations = Map.get(stats, :affiliations, [])

    if Enum.empty?(affiliations) do
      0.5
    else
      # Count unique corporations/alliances
      unique_corps = affiliations |> Enum.map(& &1.corporation_id) |> Enum.uniq() |> length()
      unique_alliances = affiliations |> Enum.map(& &1.alliance_id) |> Enum.uniq() |> length()

      # Lower number of affiliations = higher loyalty
      affiliation_changes = unique_corps + unique_alliances
      max(0.0, min(1.0, 1.0 - (affiliation_changes - 1) / 5.0))
    end
  end

  defp count_unique_associates(killmails) do
    killmails
    |> Enum.flat_map(fn km -> Map.get(km, :participants, []) end)
    |> Enum.map(fn p -> Map.get(p, :character_id) end)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_group_preference(killmails) do
    calculate_fleet_preference(killmails, [])
  end

  defp analyze_ship_specialization(killmails) do
    ship_types =
      killmails
      |> Enum.map(fn km -> Map.get(km, :ship_type_id) end)
      |> Enum.frequencies()

    if Enum.empty?(ship_types) do
      :unknown
    else
      {_ship_id, max_count} = Enum.max_by(ship_types, fn {_ship, count} -> count end)
      total_kills = length(killmails)
      specialization_ratio = max_count / total_kills

      cond do
        specialization_ratio > 0.5 -> :specialist
        specialization_ratio > 0.3 -> :focused
        true -> :generalist
      end
    end
  end

  defp identify_tactical_patterns(killmails) do
    # Analyze common tactical patterns based on ship types, engagement sizes, etc.
    initial_patterns = []

    # Check for common patterns
    patterns_with_alpha =
      if has_pattern?(:alpha_strike, killmails),
        do: [:alpha_strike | initial_patterns],
        else: initial_patterns

    patterns_with_hit_run =
      if has_pattern?(:hit_and_run, killmails),
        do: [:hit_and_run | patterns_with_alpha],
        else: patterns_with_alpha

    final_patterns =
      if has_pattern?(:sustained_engagement, killmails),
        do: [:sustained_engagement | patterns_with_hit_run],
        else: patterns_with_hit_run

    final_patterns
  end

  defp has_pattern?(pattern_type, killmails) do
    case pattern_type do
      :alpha_strike ->
        # Quick, high-damage engagements
        quick_kills =
          Enum.filter(killmails, fn km ->
            # Less than 1 minute
            Map.get(km, :engagement_duration, 300) < 60
          end)

        length(quick_kills) / length(killmails) > 0.4

      :hit_and_run ->
        # Solo or small group engagements with quick disengagement
        small_engagements =
          Enum.filter(killmails, fn km ->
            Map.get(km, :participant_count, 1) <= 3
          end)

        length(small_engagements) / length(killmails) > 0.6

      :sustained_engagement ->
        # Longer engagements with larger groups
        long_engagements =
          Enum.filter(killmails, fn km ->
            # More than 5 minutes
            Map.get(km, :engagement_duration, 0) > 300
          end)

        length(long_engagements) / length(killmails) > 0.3

      _ ->
        false
    end
  end

  defp classify_operational_range(killmails) do
    systems =
      killmails
      |> Enum.map(fn km -> Map.get(km, :system_id) end)
      |> Enum.uniq()

    system_count = length(systems)

    cond do
      system_count <= 3 -> :local
      system_count <= 10 -> :regional
      system_count <= 25 -> :roaming
      true -> :nomadic
    end
  end

  defp calculate_adaptability(killmails) do
    if length(killmails) < 10 do
      0.0
    else
      # Analyze diversity in ships, systems, and engagement types
      ship_diversity = calculate_diversity(killmails, :ship_type_id)
      system_diversity = calculate_diversity(killmails, :system_id)

      (ship_diversity + system_diversity) / 2.0
    end
  end

  defp calculate_diversity(killmails, field) do
    values = Enum.map(killmails, fn km -> Map.get(km, field) end)
    unique_values = Enum.uniq(values) |> length()
    total_values = length(values)

    if total_values == 0 do
      0.0
    else
      min(1.0, unique_values / (total_values * 0.3))
    end
  end

  defp analyze_risk_trend(sorted_kills) do
    if length(sorted_kills) < 5 do
      :stable
    else
      # Analyze ship values over time to determine risk trend
      recent_kills = Enum.take(sorted_kills, -5)
      early_kills = Enum.take(sorted_kills, 5)

      recent_avg_value = calculate_average_ship_value(recent_kills)
      early_avg_value = calculate_average_ship_value(early_kills)

      cond do
        recent_avg_value > early_avg_value * 1.5 -> :increasing
        recent_avg_value < early_avg_value * 0.7 -> :decreasing
        true -> :stable
      end
    end
  end

  defp calculate_average_ship_value(killmails) do
    if Enum.empty?(killmails) do
      0
    else
      total_value =
        killmails
        |> Enum.map(fn km -> Map.get(km, :ship_value, 0) end)
        |> Enum.sum()

      total_value / length(killmails)
    end
  end

  defp assess_experience_level(killmails, vetting) do
    kill_count = length(killmails)

    # Factor in vetting data if available
    experience_bonus = if vetting && Map.get(vetting, :veteran_status, false), do: 1.5, else: 1.0

    adjusted_kills = kill_count * experience_bonus

    cond do
      adjusted_kills < 10 -> :novice
      adjusted_kills < 50 -> :experienced
      adjusted_kills < 200 -> :veteran
      true -> :elite
    end
  end

  defp calculate_progression_rate(sorted_kills) do
    if length(sorted_kills) < 10 do
      0.0
    else
      # Calculate kills per month over time
      first_kill = List.first(sorted_kills)
      last_kill = List.last(sorted_kills)

      time_span_days =
        abs(DateTimeUtils.diff(last_kill.killmail_time, first_kill.killmail_time, :day))

      if time_span_days < 30 do
        0.0
      else
        kills_per_month = length(sorted_kills) * 30 / time_span_days
        # Normalize to 0.0-1.0
        min(1.0, kills_per_month / 10.0)
      end
    end
  end

  defp classify_threat_evolution(sorted_kills) do
    if length(sorted_kills) < 20 do
      :static
    else
      # Analyze threat level changes over time
      mid_point = div(length(sorted_kills), 2)
      early_kills = Enum.take(sorted_kills, mid_point)
      recent_kills = Enum.drop(sorted_kills, mid_point)

      early_threat = calculate_average_threat_level(early_kills)
      recent_threat = calculate_average_threat_level(recent_kills)

      cond do
        recent_threat > early_threat * 1.3 -> :escalating
        recent_threat < early_threat * 0.7 -> :declining
        true -> :stable
      end
    end
  end

  defp calculate_average_threat_level(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Simple threat calculation based on ship value and engagement size
      total_threat =
        killmails
        |> Enum.map(fn km ->
          ship_value = Map.get(km, :ship_value, 0)
          participants = Map.get(km, :participant_count, 1)
          # Basic threat metric
          ship_value / 1_000_000 + participants
        end)
        |> Enum.sum()

      total_threat / length(killmails)
    end
  end

  defp check_activity_anomalies(killmails, anomalies) do
    # Check for unusual activity spikes
    daily_counts =
      killmails
      |> Enum.group_by(fn km -> DateTime.to_date(km.killmail_time) end)
      |> Enum.map(fn {_date, kills} -> length(kills) end)

    if length(daily_counts) > 7 do
      mean_daily = Enum.sum(daily_counts) / length(daily_counts)
      max_daily = Enum.max(daily_counts)

      if max_daily > mean_daily * 3 do
        [
          %{
            type: :activity_spike,
            severity: :high,
            description: "Unusual activity spike detected"
          }
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp check_behavior_changes(killmails, anomalies) do
    if length(killmails) > 20 do
      mid_point = div(length(killmails), 2)
      early_kills = Enum.take(killmails, mid_point) |> Enum.reverse() |> Enum.take(mid_point)
      recent_kills = Enum.take(killmails, -mid_point)

      early_patterns = analyze_behavior_subset(early_kills)
      recent_patterns = analyze_behavior_subset(recent_kills)

      if patterns_significantly_different?(early_patterns, recent_patterns) do
        [
          %{
            type: :behavior_change,
            severity: :medium,
            description: "Significant behavior pattern change"
          }
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp analyze_behavior_subset(killmails) do
    %{
      avg_ship_value: calculate_average_ship_value(killmails),
      fleet_preference: calculate_fleet_preference(killmails, []),
      system_count: killmails |> Enum.map(& &1.system_id) |> Enum.uniq() |> length()
    }
  end

  defp patterns_significantly_different?(early, recent) do
    ship_value_change =
      abs(early.avg_ship_value - recent.avg_ship_value) / max(early.avg_ship_value, 1)

    fleet_pref_change = abs(early.fleet_preference - recent.fleet_preference)
    system_change = abs(early.system_count - recent.system_count) / max(early.system_count, 1)

    ship_value_change > 0.5 or fleet_pref_change > 0.3 or system_change > 0.4
  end

  defp check_risk_anomalies(killmails, anomalies) do
    recent_kills = Enum.take(killmails, -10)

    high_risk_count =
      recent_kills
      # 500M+ ISK
      |> Enum.filter(fn km -> Map.get(km, :ship_value, 0) > 500_000_000 end)
      |> length()

    if high_risk_count >= 3 do
      [
        %{
          type: :high_risk_behavior,
          severity: :high,
          description: "Multiple high-value ship losses"
        }
        | anomalies
      ]
    else
      anomalies
    end
  end

  defp calculate_anomaly_confidence(anomalies) do
    if Enum.empty?(anomalies) do
      0.0
    else
      # Calculate confidence based on anomaly types and severity
      total_weight =
        anomalies
        |> Enum.map(fn anomaly ->
          case anomaly.severity do
            :high -> 1.0
            :medium -> 0.6
            :low -> 0.3
          end
        end)
        |> Enum.sum()

      min(1.0, total_weight / length(anomalies))
    end
  end

  defp extract_risk_indicators(anomalies) do
    anomalies
    |> Enum.map(fn anomaly ->
      %{
        indicator: anomaly.type,
        risk_level: anomaly.severity,
        description: anomaly.description
      }
    end)
  end
end
