defmodule EveDmv.Intelligence.HomeDefenseAnalyzer do
  @moduledoc """
  Analyzes wormhole corporation home defense capabilities.

  Provides comprehensive analysis of timezone coverage, member activity patterns,
  rage rolling participation, response times, and overall defensive readiness.
  """

  require Logger
  alias EveDmv.Intelligence.{CharacterStats, HomeDefenseAnalytics}

  @doc """
  Perform comprehensive home defense analysis for a corporation.

  Returns {:ok, analytics_record} or {:error, reason}
  """
  def analyze_corporation(corporation_id, options \\ []) do
    Logger.info("Starting home defense analysis for corporation #{corporation_id}")

    # Set analysis period (default to last 90 days)
    period_days = Keyword.get(options, :period_days, 90)
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -period_days * 24 * 60 * 60, :second)

    requested_by = Keyword.get(options, :requested_by)

    with {:ok, corp_info} <- get_corporation_info(corporation_id),
         {:ok, members} <- get_corporation_members(corporation_id),
         {:ok, timezone_coverage} <- analyze_timezone_coverage(members, start_date, end_date),
         {:ok, rolling_participation} <-
           analyze_rolling_participation(corporation_id, start_date, end_date),
         {:ok, response_metrics} <-
           analyze_response_metrics(corporation_id, start_date, end_date),
         {:ok, member_activity_patterns} <-
           analyze_member_activity_patterns(members, start_date, end_date),
         {:ok, defensive_capabilities} <- analyze_defensive_capabilities(corporation_id, members),
         {:ok, coverage_gaps} <-
           identify_coverage_gaps(timezone_coverage, response_metrics, member_activity_patterns) do
      scores =
        calculate_defense_scores(
          timezone_coverage,
          rolling_participation,
          response_metrics,
          member_activity_patterns,
          defensive_capabilities
        )

      analytics_data = %{
        corporation_id: corporation_id,
        corporation_name: corp_info.corporation_name,
        alliance_id: corp_info.alliance_id,
        alliance_name: corp_info.alliance_name,
        home_system_id: corp_info.home_system_id,
        home_system_name: corp_info.home_system_name,
        analysis_period_start: start_date,
        analysis_period_end: end_date,
        analysis_requested_by: requested_by,
        overall_defense_score: scores.overall_defense_score,
        timezone_coverage_score: scores.timezone_coverage_score,
        response_time_score: scores.response_time_score,
        rolling_competency_score: scores.rolling_competency_score,
        member_participation_score: scores.member_participation_score,
        timezone_coverage: timezone_coverage,
        rolling_participation: rolling_participation,
        response_metrics: response_metrics,
        member_activity_patterns: member_activity_patterns,
        defensive_capabilities: defensive_capabilities,
        coverage_gaps: coverage_gaps,
        total_members_analyzed: length(members),
        active_members_count: count_active_members(members),
        critical_gaps_count: count_critical_gaps(coverage_gaps),
        data_completeness_percent:
          calculate_data_completeness([timezone_coverage, rolling_participation, response_metrics])
      }

      # Create or update analytics record
      case HomeDefenseAnalytics.get_by_corporation(corporation_id) do
        {:ok, [existing]} ->
          HomeDefenseAnalytics.update_analysis(existing, analytics_data)

        {:ok, []} ->
          HomeDefenseAnalytics.create(analytics_data)

        {:error, _} ->
          HomeDefenseAnalytics.create(analytics_data)
      end
    else
      {:error, reason} ->
        Logger.error(
          "Home defense analysis failed for corporation #{corporation_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Corporation information retrieval
  defp get_corporation_info(corporation_id) do
    # This would integrate with ESI to get corporation details
    # For now, using placeholder data
    {:ok,
     %{
       corporation_name: "Corporation #{corporation_id}",
       alliance_id: nil,
       alliance_name: nil,
       home_system_id: 31_000_142,
       home_system_name: "J123456"
     }}
  end

  # Get corporation members
  defp get_corporation_members(corporation_id) do
    # Get all characters associated with this corporation
    case Ash.read(CharacterStats, domain: EveDmv.Api) do
      {:ok, all_stats} ->
        members = Enum.filter(all_stats, fn stats -> stats.corporation_id == corporation_id end)
        {:ok, members}

      {:error, reason} ->
        Logger.warning("Could not load character stats: #{inspect(reason)}")
        {:ok, []}
    end
  rescue
    error ->
      Logger.error("Error getting corporation members: #{inspect(error)}")
      {:ok, []}
  end

  # Timezone coverage analysis
  defp analyze_timezone_coverage(members, _start_date, _end_date) do
    # Analyze member activity patterns across 24-hour period
    coverage_by_hour = generate_hourly_coverage(members)
    timezone_distribution = calculate_timezone_distribution(members)
    critical_gaps = identify_timezone_gaps(coverage_by_hour)
    peak_strength_hours = identify_peak_hours(coverage_by_hour)

    coverage = %{
      "coverage_by_hour" => coverage_by_hour,
      "timezone_distribution" => timezone_distribution,
      "critical_gaps" => critical_gaps,
      "peak_strength_hours" => peak_strength_hours
    }

    {:ok, coverage}
  end

  # Rolling participation analysis
  defp analyze_rolling_participation(_corporation_id, _start_date, _end_date) do
    # Analyze rage rolling operations and member participation
    # This would integrate with killmail data and corp activity logs

    participation = %{
      # Placeholder
      "total_rolling_ops" => 20,
      "member_participation" => %{},
      "rolling_efficiency" => %{
        "avg_time_per_hole" => 180.0,
        "success_rate" => 0.92,
        "incidents" => 1,
        "collateral_damage" => 5_000_000
      },
      "hole_types_rolled" => %{
        "static_c5" => 15,
        "wandering_holes" => 5
      }
    }

    {:ok, participation}
  end

  # Response metrics analysis
  defp analyze_response_metrics(corporation_id, start_date, end_date) do
    # Analyze response times to threats and home defense battles
    home_system_battles = get_home_system_battles(corporation_id, start_date, end_date)

    response_times = calculate_response_times(home_system_battles)
    defense_success_rate = calculate_defense_success_rate(home_system_battles)

    metrics = %{
      "threat_responses" => %{
        "avg_response_time_seconds" => response_times.avg_response_time,
        "fastest_response_seconds" => response_times.fastest,
        "slowest_response_seconds" => response_times.slowest,
        "response_rate" => response_times.response_rate
      },
      "home_defense_battles" => %{
        "total_defenses" => length(home_system_battles),
        "successful_defenses" => defense_success_rate.successful,
        "failed_defenses" => defense_success_rate.failed,
        "evaded_threats" => defense_success_rate.evaded,
        "success_rate" => defense_success_rate.success_rate
      },
      "escalation_patterns" => %{
        "batphone_calls" => 3,
        "alliance_support" => 2,
        "successful_escalations" => 4,
        "avg_escalation_time" => 360
      },
      "threat_types_faced" => categorize_threat_types(home_system_battles)
    }

    {:ok, metrics}
  end

  # Member activity patterns analysis
  defp analyze_member_activity_patterns(members, _start_date, _end_date) do
    active_members = Enum.filter(members, &member_active?/1)

    activity_by_timezone = calculate_activity_by_timezone(active_members)
    role_coverage = calculate_role_coverage(active_members)
    engagement_readiness = assess_engagement_readiness(active_members)

    patterns = %{
      "active_members" => length(active_members),
      "total_members" => length(members),
      "activity_by_timezone" => activity_by_timezone,
      "role_coverage" => role_coverage,
      "engagement_readiness" => engagement_readiness
    }

    {:ok, patterns}
  end

  # Defensive capabilities analysis
  defp analyze_defensive_capabilities(corporation_id, members) do
    fleet_compositions = analyze_fleet_doctrines(members)
    infrastructure = assess_infrastructure_strength(corporation_id)
    intel_network = evaluate_intel_capabilities(corporation_id)

    capabilities = %{
      "fleet_compositions" => fleet_compositions,
      "infrastructure" => infrastructure,
      "intel_network" => intel_network
    }

    {:ok, capabilities}
  end

  # Coverage gaps identification
  defp identify_coverage_gaps(timezone_coverage, response_metrics, member_activity_patterns) do
    critical_weaknesses =
      find_critical_weaknesses(timezone_coverage, response_metrics, member_activity_patterns)

    improvement_priorities = generate_improvement_priorities(timezone_coverage, response_metrics)
    threat_preparedness = assess_threat_preparedness(member_activity_patterns, response_metrics)

    gaps = %{
      "critical_weaknesses" => critical_weaknesses,
      "improvement_priorities" => improvement_priorities,
      "threat_preparedness" => threat_preparedness
    }

    {:ok, gaps}
  end

  # Helper functions for timezone coverage
  defp generate_hourly_coverage(members) do
    # Generate coverage statistics for each hour of the day
    0..23
    |> Enum.map(fn hour ->
      pilots_online = estimate_pilots_online_at_hour(members, hour)
      fc_available = has_fc_coverage_at_hour(members, hour)
      logi_available = has_logi_coverage_at_hour(members, hour)

      {Integer.to_string(hour),
       %{
         "pilots_online" => pilots_online,
         "fc_available" => fc_available,
         "logi_available" => logi_available
       }}
    end)
    |> Enum.into(%{})
  end

  defp calculate_timezone_distribution(members) do
    # Categorize members by timezone
    timezones = ["US_TZ", "EU_TZ", "AU_TZ"]

    timezones
    |> Enum.map(fn tz ->
      tz_members = filter_members_by_timezone(members, tz)
      active_members = Enum.filter(tz_members, &member_active?/1)

      {tz,
       %{
         "member_count" => length(tz_members),
         "active_count" => length(active_members)
       }}
    end)
    |> Enum.into(%{})
  end

  defp identify_timezone_gaps(coverage_by_hour) do
    # Find hours with critical coverage gaps
    coverage_by_hour
    |> Enum.filter(fn {_hour, data} ->
      data["pilots_online"] < 3 or not data["fc_available"]
    end)
    |> Enum.map(fn {hour, data} ->
      severity = if data["pilots_online"] < 2, do: "critical", else: "high"

      %{
        "hour" => hour,
        "pilots_online" => data["pilots_online"],
        "severity" => severity,
        "description" => describe_coverage_gap(data)
      }
    end)
  end

  defp identify_peak_hours(coverage_by_hour) do
    # Find hours with strongest coverage
    coverage_by_hour
    |> Enum.filter(fn {_hour, data} -> data["pilots_online"] >= 8 end)
    |> Enum.map(fn {hour, _data} -> String.to_integer(hour) end)
    |> Enum.sort()
  end

  # Helper functions for response metrics
  defp get_home_system_battles(_corporation_id, _start_date, _end_date) do
    # Get battles that occurred in the corporation's home system
    # This would filter killmails by home system and date range
    # Placeholder implementation
    []
  end

  defp calculate_response_times(_battles) do
    # Calculate response time statistics
    # Placeholder implementation
    %{
      avg_response_time: 180,
      fastest: 45,
      slowest: 420,
      response_rate: 0.85
    }
  end

  defp calculate_defense_success_rate(battles) do
    # Calculate home defense success metrics
    # Placeholder implementation
    total = length(battles)

    %{
      successful: max(0, total - 2),
      failed: min(2, total),
      evaded: 0,
      success_rate: if(total > 0, do: (total - 2) / total, else: 0.0)
    }
  end

  defp categorize_threat_types(_battles) do
    # Categorize threats by type and size
    # Placeholder implementation
    %{
      "solo_hunters" => 8,
      "small_gangs" => 4,
      "eviction_scouts" => 1,
      "major_threats" => 0
    }
  end

  # Helper functions for member analysis
  defp member_active?(member) do
    # Determine if a member is considered active
    member.total_kills + member.total_losses > 5
  end

  defp estimate_pilots_online_at_hour(members, hour) do
    # Estimate how many pilots are typically online at a given hour
    # This would use actual activity data in production
    active_members = Enum.filter(members, &member_active?/1)

    case hour do
      # Prime time
      h when h in 18..23 -> round(length(active_members) * 0.6)
      # Afternoon
      h when h in 14..17 -> round(length(active_members) * 0.4)
      # Morning
      h when h in 6..13 -> round(length(active_members) * 0.3)
      # Off hours
      _ -> round(length(active_members) * 0.2)
    end
  end

  defp has_fc_coverage_at_hour(_members, hour) do
    # Determine if FC coverage exists at given hour
    # This would check actual FC availability
    # Simplified: assume FC coverage during prime time
    hour in 16..23
  end

  defp has_logi_coverage_at_hour(_members, hour) do
    # Determine if logistics coverage exists at given hour
    # Slightly broader than FC coverage
    hour in 15..24 or hour in 0..1
  end

  defp filter_members_by_timezone(members, timezone) do
    # Filter members by their primary timezone
    # This would use actual timezone data from EVE characters
    case timezone do
      "US_TZ" -> Enum.take(members, div(length(members), 2))
      "EU_TZ" -> Enum.take(members, div(length(members), 3))
      "AU_TZ" -> Enum.take(members, div(length(members), 5))
      _ -> []
    end
  end

  defp calculate_activity_by_timezone(_members) do
    # Calculate activity statistics by timezone
    %{
      "US_TZ" => %{"peak_online" => 15, "avg_online" => 12, "min_online" => 6},
      "EU_TZ" => %{"peak_online" => 12, "avg_online" => 9, "min_online" => 4},
      "AU_TZ" => %{"peak_online" => 8, "avg_online" => 5, "min_online" => 2}
    }
  end

  defp calculate_role_coverage(_members) do
    # Calculate coverage by role type
    %{
      "fleet_commanders" => %{"total" => 5, "active" => 4, "coverage_hours" => 16},
      "logistics_pilots" => %{"total" => 12, "active" => 10, "coverage_hours" => 18},
      "tackle_specialists" => %{"total" => 18, "active" => 15, "coverage_hours" => 20},
      "dps_pilots" => %{"total" => 35, "active" => 28, "coverage_hours" => 22}
    }
  end

  defp assess_engagement_readiness(members) do
    # Assess how ready members are for combat
    total = length(members)

    %{
      "always_ready" => round(total * 0.15),
      "usually_ready" => round(total * 0.35),
      "sometimes_ready" => round(total * 0.30),
      "rarely_ready" => round(total * 0.20)
    }
  end

  # Helper functions for defensive capabilities
  defp analyze_fleet_doctrines(_members) do
    # Analyze available fleet compositions
    %{
      "home_defense_doctrine" => %{
        "ships" => ["Guardian", "Damnation", "Legion", "Cerberus"],
        "pilot_requirement" => 8,
        "effectiveness_rating" => 0.85
      },
      "rapid_response" => %{
        "ships" => ["Interceptor", "Assault Frigate", "Heavy Interdictor"],
        "pilot_requirement" => 3,
        "effectiveness_rating" => 0.92
      }
    }
  end

  defp assess_infrastructure_strength(_corporation_id) do
    # Assess defensive infrastructure
    %{
      "citadels" => 2,
      "weapon_timers" => 3,
      "tethering_points" => 6,
      "safe_spots" => 20
    }
  end

  defp evaluate_intel_capabilities(_corporation_id) do
    # Evaluate intelligence network capabilities
    %{
      "scout_coverage" => 0.75,
      "chain_monitoring" => true,
      "wanderer_integration" => true,
      "alert_systems" => ["discord", "in_game"]
    }
  end

  # Helper functions for coverage gaps
  defp find_critical_weaknesses(timezone_coverage, response_metrics, _member_activity_patterns) do
    weaknesses = []

    # Check for timezone gaps
    gaps = timezone_coverage["critical_gaps"] || []

    timezone_weaknesses =
      Enum.map(gaps, fn gap ->
        %{
          "type" => "timezone_gap",
          "description" => "Coverage gap at hour #{gap["hour"]}",
          "severity" => gap["severity"],
          "recommendation" => suggest_timezone_improvement(gap)
        }
      end)

    # Check for response time issues
    response_weaknesses =
      if response_metrics["threat_responses"]["avg_response_time_seconds"] > 300 do
        [
          %{
            "type" => "slow_response",
            "description" => "Response time exceeds 5 minutes",
            "severity" => "medium",
            "recommendation" => "Improve alert systems and pre-positioning"
          }
        ]
      else
        []
      end

    weaknesses ++ timezone_weaknesses ++ response_weaknesses
  end

  defp generate_improvement_priorities(timezone_coverage, _response_metrics) do
    # Generate prioritized improvement recommendations
    [
      %{
        "area" => "timezone_coverage",
        "current_score" => calculate_timezone_score(timezone_coverage),
        "target_score" => 85,
        "action_items" => ["Recruit timezone-specific pilots", "Improve shift scheduling"]
      }
    ]
  end

  defp assess_threat_preparedness(_member_activity_patterns, _response_metrics) do
    # Assess preparedness for different threat types
    %{
      "eviction_readiness" => 0.7,
      "small_gang_response" => 0.85,
      "solo_hunter_deterrence" => 0.9
    }
  end

  # Scoring calculations
  defp calculate_defense_scores(
         timezone_coverage,
         rolling_participation,
         response_metrics,
         member_activity_patterns,
         _defensive_capabilities
       ) do
    timezone_score = calculate_timezone_score(timezone_coverage)
    response_score = calculate_response_score(response_metrics)
    rolling_score = calculate_rolling_score(rolling_participation)
    participation_score = calculate_participation_score(member_activity_patterns)

    overall_score =
      calculate_overall_defense_score(
        timezone_score,
        response_score,
        rolling_score,
        participation_score
      )

    %{
      timezone_coverage_score: timezone_score,
      response_time_score: response_score,
      rolling_competency_score: rolling_score,
      member_participation_score: participation_score,
      overall_defense_score: overall_score
    }
  end

  defp calculate_timezone_score(timezone_coverage) do
    # Score based on timezone coverage quality
    gaps = length(timezone_coverage["critical_gaps"] || [])
    peak_hours = length(timezone_coverage["peak_strength_hours"] || [])

    base_score = 100
    gap_penalty = gaps * 15
    peak_bonus = min(20, peak_hours * 3)

    max(0, min(100, base_score - gap_penalty + peak_bonus))
  end

  defp calculate_response_score(response_metrics) do
    # Score based on response time and success rate
    threat_responses = response_metrics["threat_responses"] || %{}
    avg_response = threat_responses["avg_response_time_seconds"] || 300
    response_rate = threat_responses["response_rate"] || 0.5

    # Better score for faster response times
    time_score = max(0, 100 - (avg_response - 60) / 3)
    rate_score = response_rate * 100

    round((time_score + rate_score) / 2)
  end

  defp calculate_rolling_score(rolling_participation) do
    # Score based on rolling efficiency and participation
    efficiency = rolling_participation["rolling_efficiency"] || %{}
    success_rate = efficiency["success_rate"] || 0.5
    ops_count = rolling_participation["total_rolling_ops"] || 0

    base_score = success_rate * 80
    activity_bonus = min(20, ops_count)

    round(base_score + activity_bonus)
  end

  defp calculate_participation_score(member_activity_patterns) do
    # Score based on member participation rates
    active = member_activity_patterns["active_members"] || 0
    total = member_activity_patterns["total_members"] || 1

    participation_rate = active / total
    round(participation_rate * 100)
  end

  defp calculate_overall_defense_score(
         timezone_score,
         response_score,
         rolling_score,
         participation_score
       ) do
    # Weighted average of all scores
    weights = %{
      timezone: 0.3,
      response: 0.25,
      rolling: 0.2,
      participation: 0.25
    }

    weighted_score =
      timezone_score * weights.timezone +
        response_score * weights.response +
        rolling_score * weights.rolling +
        participation_score * weights.participation

    round(weighted_score)
  end

  # Utility functions
  defp describe_coverage_gap(data) do
    cond do
      not data["fc_available"] -> "No FC available"
      not data["logi_available"] -> "No logistics support"
      data["pilots_online"] < 3 -> "Insufficient pilot count"
      true -> "General coverage weakness"
    end
  end

  defp suggest_timezone_improvement(gap) do
    case gap["severity"] do
      "critical" -> "Urgent: Recruit pilots for this timezone"
      "high" -> "Recruit additional pilots or improve scheduling"
      _ -> "Consider coverage improvement"
    end
  end

  defp count_active_members(members) do
    Enum.count(members, &member_active?/1)
  end

  defp count_critical_gaps(coverage_gaps) do
    critical_weaknesses = coverage_gaps["critical_weaknesses"] || []
    Enum.count(critical_weaknesses, fn w -> w["severity"] in ["critical", "high"] end)
  end

  defp calculate_data_completeness(data_sections) do
    # Calculate percentage of data sections that have meaningful content
    non_empty_sections =
      Enum.count(data_sections, fn section ->
        case section do
          map when is_map(map) -> map_size(map) > 0
          _ -> false
        end
      end)

    round(non_empty_sections / length(data_sections) * 100)
  end
end
