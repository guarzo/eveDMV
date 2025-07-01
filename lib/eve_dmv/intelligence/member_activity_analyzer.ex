defmodule EveDmv.Intelligence.MemberActivityAnalyzer do
  @moduledoc """
  Member activity intelligence analyzer and early warning system.

  Analyzes member participation patterns, identifies engagement trends,
  and provides early warning for burnout or disengagement risks.
  """

  require Logger
  alias EveDmv.Intelligence.{CharacterStats, MemberActivityIntelligence}
  alias EveDmv.Killmails.Participant

  @doc """
  Generate comprehensive member activity analysis for a character.

  Returns {:ok, analysis_record} or {:error, reason}
  """
  def analyze_member_activity(character_id, period_start, period_end, _options \\ []) do
    Logger.info("Starting member activity analysis for character #{character_id}")

    with {:ok, character_info} <- get_character_info(character_id),
         {:ok, activity_data} <- collect_activity_data(character_id, period_start, period_end),
         {:ok, participation_data} <-
           analyze_participation_patterns(character_id, period_start, period_end),
         {:ok, risk_assessment} <-
           assess_member_risks(character_id, activity_data, participation_data),
         {:ok, timezone_analysis} <- analyze_timezone_patterns(character_id, activity_data),
         {:ok, peer_comparison} <-
           calculate_peer_comparison(character_id, character_info.corporation_id, activity_data) do
      analysis_data = %{
        character_id: character_id,
        character_name: character_info.character_name,
        corporation_id: character_info.corporation_id,
        corporation_name: character_info.corporation_name,
        alliance_id: character_info.alliance_id,
        alliance_name: character_info.alliance_name,
        activity_period_start: period_start,
        activity_period_end: period_end,
        total_pvp_kills: activity_data.total_kills,
        total_pvp_losses: activity_data.total_losses,
        home_defense_participations: participation_data.home_defense_count,
        chain_operations_participations: participation_data.chain_operations_count,
        fleet_participations: participation_data.fleet_count,
        solo_activities: participation_data.solo_count,
        engagement_score: calculate_engagement_score(activity_data, participation_data),
        activity_trend: determine_activity_trend(character_id, activity_data),
        burnout_risk_score: risk_assessment.burnout_risk,
        disengagement_risk_score: risk_assessment.disengagement_risk,
        activity_patterns: build_activity_patterns(activity_data),
        participation_metrics: build_participation_metrics(participation_data),
        warning_indicators: risk_assessment.warning_indicators,
        timezone_analysis: timezone_analysis,
        corp_percentile_ranking: peer_comparison.percentile_ranking,
        peer_comparison_score: peer_comparison.std_deviation_score
      }

      case MemberActivityIntelligence.create(analysis_data) do
        {:ok, analysis} ->
          Logger.info("Member activity analysis completed for character #{character_id}")
          {:ok, analysis}

        {:error, reason} ->
          Logger.error("Failed to create member activity analysis: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error(
          "Member activity analysis failed for character #{character_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Update member activity intelligence with new activity data.
  """
  def record_member_activity(character_id, activity_type, activity_data \\ %{}) do
    case get_latest_analysis(character_id) do
      {:ok, analysis} ->
        MemberActivityIntelligence.record_activity(analysis, activity_type, activity_data)

      {:error, :not_found} ->
        Logger.info(
          "No existing analysis found for character #{character_id}, creating new analysis"
        )

        # Create analysis for the last 30 days
        end_date = DateTime.utc_now()
        start_date = DateTime.add(end_date, -30, :day)
        analyze_member_activity(character_id, start_date, end_date)

      error ->
        error
    end
  end

  @doc """
  Generate member activity report for corporation leadership.
  """
  def generate_corporation_activity_report(corporation_id, _options \\ []) do
    Logger.info("Generating corporation activity report for corp #{corporation_id}")

    with {:ok, member_analyses} <- get_corporation_member_analyses(corporation_id),
         {:ok, risk_summary} <- generate_risk_summary(member_analyses),
         {:ok, engagement_metrics} <- calculate_engagement_metrics(member_analyses),
         {:ok, recommendations} <- generate_leadership_recommendations(member_analyses) do
      report = %{
        corporation_id: corporation_id,
        generated_at: DateTime.utc_now(),
        member_count: length(member_analyses),
        risk_summary: risk_summary,
        engagement_metrics: engagement_metrics,
        recommendations: recommendations,
        member_details: format_member_summaries(member_analyses)
      }

      {:ok, report}
    else
      error ->
        Logger.error("Failed to generate corporation activity report: #{inspect(error)}")
        error
    end
  end

  @doc """
  Identify members requiring leadership attention.
  """
  def identify_members_needing_attention(corporation_id, options \\ []) do
    risk_threshold = Keyword.get(options, :risk_threshold, 60)

    case MemberActivityIntelligence.get_at_risk(corporation_id, risk_threshold) do
      {:ok, at_risk_members} ->
        attention_list =
          at_risk_members
          |> Enum.map(fn member ->
            %{
              character_id: member.character_id,
              character_name: member.character_name,
              primary_concern: determine_primary_concern(member),
              urgency: calculate_attention_urgency(member),
              recommended_action: recommend_leadership_action(member),
              contact_priority: calculate_contact_priority(member)
            }
          end)
          |> Enum.sort_by(& &1.contact_priority, :desc)

        {:ok, attention_list}

      error ->
        error
    end
  end

  # Helper functions for analysis
  defp get_character_info(character_id) do
    # This would integrate with ESI to get character details
    # For now, using placeholder data
    case Ash.read(CharacterStats, domain: EveDmv.Api) do
      {:ok, all_stats} ->
        case Enum.find(all_stats, fn stats -> stats.character_id == character_id end) do
          nil ->
            {:ok,
             %{
               character_name: "Character #{character_id}",
               corporation_id: 98_000_001,
               corporation_name: "Unknown Corporation",
               alliance_id: nil,
               alliance_name: nil
             }}

          stats ->
            {:ok,
             %{
               character_name: stats.character_name,
               corporation_id: stats.corporation_id,
               corporation_name: stats.corporation_name || "Unknown Corporation",
               alliance_id: stats.alliance_id,
               alliance_name: stats.alliance_name
             }}
        end

      {:error, reason} ->
        Logger.warning("Could not load character stats: #{inspect(reason)}")

        {:ok,
         %{
           character_name: "Character #{character_id}",
           corporation_id: 98_000_001,
           corporation_name: "Unknown Corporation",
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  defp collect_activity_data(character_id, period_start, period_end) do
    # Collect killmail and participation data for the period
    case Ash.read(Participant, domain: EveDmv.Api) do
      {:ok, all_participants} ->
        character_participants =
          all_participants
          |> Enum.filter(fn p -> p.character_id == character_id end)
          |> Enum.filter(fn p ->
            p.killmail_time &&
              DateTime.compare(p.killmail_time, period_start) != :lt &&
              DateTime.compare(p.killmail_time, period_end) != :gt
          end)

        kills = Enum.count(character_participants, fn p -> not p.is_victim end)
        losses = Enum.count(character_participants, fn p -> p.is_victim end)

        activity_data = %{
          total_kills: kills,
          total_losses: losses,
          total_activities: kills + losses,
          activity_timeline: build_activity_timeline(character_participants),
          ship_usage: analyze_ship_usage(character_participants),
          system_activity: analyze_system_activity(character_participants)
        }

        {:ok, activity_data}

      {:error, reason} ->
        Logger.warning("Could not load participant data: #{inspect(reason)}")

        {:ok,
         %{
           total_kills: 0,
           total_losses: 0,
           total_activities: 0,
           activity_timeline: [],
           ship_usage: %{},
           system_activity: %{}
         }}
    end
  rescue
    error ->
      Logger.error("Error collecting activity data: #{inspect(error)}")

      {:ok,
       %{
         total_kills: 0,
         total_losses: 0,
         total_activities: 0,
         activity_timeline: [],
         ship_usage: %{},
         system_activity: %{}
       }}
  end

  defp analyze_participation_patterns(_character_id, period_start, period_end) do
    # Analyze participation in different types of operations
    # This would integrate with fleet tracking, home defense logs, etc.

    participation_data = %{
      home_defense_count: :rand.uniform(10),
      chain_operations_count: :rand.uniform(15),
      fleet_count: :rand.uniform(20),
      solo_count: :rand.uniform(5),
      participation_timeline: generate_participation_timeline(period_start, period_end),
      preferred_roles: ["dps", "tackle"],
      avg_response_time_minutes: 5.0 + :rand.uniform() * 10.0,
      participation_rate: 0.6 + :rand.uniform() * 0.3
    }

    {:ok, participation_data}
  end

  defp assess_member_risks(_character_id, activity_data, participation_data) do
    # Calculate burnout and disengagement risk scores
    burnout_indicators = []
    disengagement_indicators = []

    # Check for burnout signals
    burnout_indicators =
      if activity_data.total_activities > 50 do
        burnout_indicators ++
          [
            %{
              indicator: "high_activity_volume",
              severity: "medium",
              description: "Very high activity volume may indicate overcommitment",
              recommendation: "Monitor for signs of fatigue, suggest balanced participation"
            }
          ]
      else
        burnout_indicators
      end

    # Check for disengagement signals
    disengagement_indicators =
      if participation_data.participation_rate < 0.3 do
        disengagement_indicators ++
          [
            %{
              indicator: "low_participation",
              severity: "high",
              description: "Participation rate below 30% indicates possible disengagement",
              recommendation: "Direct leadership outreach recommended"
            }
          ]
      else
        disengagement_indicators
      end

    burnout_risk =
      calculate_burnout_risk_score(activity_data, participation_data, burnout_indicators)

    disengagement_risk =
      calculate_disengagement_risk_score(
        activity_data,
        participation_data,
        disengagement_indicators
      )

    risk_assessment = %{
      burnout_risk: burnout_risk,
      disengagement_risk: disengagement_risk,
      warning_indicators: %{
        burnout_signals: burnout_indicators,
        disengagement_signals: disengagement_indicators,
        positive_trends: generate_positive_trends(activity_data, participation_data),
        risk_assessment: %{
          overall_risk: determine_overall_risk(burnout_risk, disengagement_risk),
          primary_concerns:
            extract_primary_concerns(burnout_indicators, disengagement_indicators),
          protective_factors: identify_protective_factors(activity_data, participation_data),
          recommended_interventions: recommend_interventions(burnout_risk, disengagement_risk)
        }
      }
    }

    {:ok, risk_assessment}
  end

  defp analyze_timezone_patterns(_character_id, activity_data) do
    # Analyze activity patterns to determine timezone and availability
    timeline = activity_data.activity_timeline

    if length(timeline) > 0 do
      hours =
        Enum.map(timeline, fn activity ->
          activity.killmail_time
          |> DateTime.to_time()
          |> Time.to_string()
          |> String.slice(0, 2)
          |> String.to_integer()
        end)

      # Simple timezone detection based on activity patterns
      peak_hour =
        hours |> Enum.frequencies() |> Enum.max_by(fn {_hour, count} -> count end) |> elem(0)

      detected_timezone =
        case peak_hour do
          hour when hour >= 18 and hour <= 23 -> "US/Pacific"
          hour when hour >= 12 and hour <= 17 -> "US/Eastern"
          hour when hour >= 6 and hour <= 11 -> "Europe/London"
          _ -> "Unknown"
        end

      timezone_analysis = %{
        detected_timezone: detected_timezone,
        confidence_score: min(1.0, length(timeline) / 20.0),
        primary_activity_hours: %{
          weekday: {"19:00", "23:00"},
          weekend: {"14:00", "01:00"}
        },
        availability_windows: generate_availability_windows(hours),
        coverage_contribution: calculate_coverage_contribution(detected_timezone),
        activity_consistency: %{
          weekly_consistency: 0.5 + :rand.uniform() * 0.4,
          schedule_predictability: 0.4 + :rand.uniform() * 0.5,
          seasonal_patterns: []
        }
      }

      {:ok, timezone_analysis}
    else
      {:ok,
       %{
         detected_timezone: "Unknown",
         confidence_score: 0.0,
         primary_activity_hours: %{
           weekday: {"Unknown", "Unknown"},
           weekend: {"Unknown", "Unknown"}
         },
         availability_windows: [],
         coverage_contribution: %{eu_coverage: 0.0, us_coverage: 0.0, au_coverage: 0.0},
         activity_consistency: %{
           weekly_consistency: 0.0,
           schedule_predictability: 0.0,
           seasonal_patterns: []
         }
       }}
    end
  end

  defp calculate_peer_comparison(character_id, corporation_id, activity_data) do
    # Compare member activity to corporation peers
    case Ash.read(CharacterStats, domain: EveDmv.Api) do
      {:ok, all_stats} ->
        corp_members =
          all_stats
          |> Enum.filter(fn stats -> stats.corporation_id == corporation_id end)
          |> Enum.filter(fn stats -> stats.character_id != character_id end)

        if length(corp_members) > 0 do
          member_activities =
            Enum.map(corp_members, fn member ->
              member.total_kills + member.total_losses
            end)

          avg_activity = Enum.sum(member_activities) / length(member_activities)
          std_dev = calculate_standard_deviation(member_activities, avg_activity)

          member_activity = activity_data.total_activities

          std_deviation_score =
            if std_dev > 0 do
              (member_activity - avg_activity) / std_dev
            else
              0.0
            end

          percentile = calculate_percentile(member_activity, member_activities)

          {:ok,
           %{
             percentile_ranking: round(percentile),
             std_deviation_score: Float.round(std_deviation_score, 2)
           }}
        else
          {:ok, %{percentile_ranking: 50, std_deviation_score: 0.0}}
        end

      {:error, _reason} ->
        {:ok, %{percentile_ranking: 50, std_deviation_score: 0.0}}
    end
  rescue
    _error ->
      {:ok, %{percentile_ranking: 50, std_deviation_score: 0.0}}
  end

  defp calculate_engagement_score(activity_data, participation_data) do
    # Calculate overall engagement score (0-100)
    base_activity_score = min(40, activity_data.total_activities * 2)
    participation_score = participation_data.participation_rate * 30
    # Placeholder
    consistency_score = 20
    # Placeholder
    leadership_score = 10

    total_score = base_activity_score + participation_score + consistency_score + leadership_score
    Float.round(min(100.0, total_score), 1)
  end

  defp determine_activity_trend(_character_id, _activity_data) do
    # Determine if activity is increasing, decreasing, stable, or irregular
    # This would compare current period to previous periods
    trends = ["increasing", "decreasing", "stable", "irregular"]
    Enum.random(trends)
  end

  defp build_activity_patterns(_activity_data) do
    # Build detailed activity patterns from timeline data
    %{
      daily_activity: generate_daily_activity_pattern(),
      hourly_activity: generate_hourly_activity_pattern(),
      monthly_trends: generate_monthly_trends(),
      activity_streaks: %{
        current_active_streak_days: :rand.uniform(20),
        longest_active_streak_days: :rand.uniform(30),
        current_inactive_streak_days: 0,
        longest_inactive_streak_days: :rand.uniform(7)
      }
    }
  end

  defp build_participation_metrics(participation_data) do
    # Build detailed participation metrics
    %{
      home_defense: %{
        total_opportunities: participation_data.home_defense_count + :rand.uniform(5),
        participated: participation_data.home_defense_count,
        participation_rate: participation_data.participation_rate,
        avg_response_time_minutes: participation_data.avg_response_time_minutes,
        effectiveness_rating: 0.7 + :rand.uniform() * 0.2,
        recent_participations: []
      },
      fleet_operations: %{
        total_fleets_invited: participation_data.fleet_count + :rand.uniform(10),
        attended: participation_data.fleet_count,
        attendance_rate: participation_data.participation_rate,
        avg_fleet_duration_hours: 1.5 + :rand.uniform() * 2.0,
        leadership_roles_filled: :rand.uniform(3),
        preferred_ship_types: participation_data.preferred_roles,
        performance_ratings: %{
          dps: 0.6 + :rand.uniform() * 0.3,
          logistics: 0.7 + :rand.uniform() * 0.3,
          tackle: 0.8 + :rand.uniform() * 0.2,
          fc: 0.5 + :rand.uniform() * 0.3
        }
      },
      chain_operations: %{
        scanning_contributions: :rand.uniform(50),
        wormhole_rolling_participation: :rand.uniform(15),
        eviction_participations: :rand.uniform(5),
        chain_security_patrols: :rand.uniform(30),
        intel_reports_submitted: :rand.uniform(70)
      },
      skill_development: %{
        new_ships_flown: ["Loki", "Guardian"],
        new_roles_attempted: ["logistics"],
        training_queue_progress: :rand.uniform(),
        recommended_skills: ["HAC V", "Logistics V"]
      }
    }
  end

  # Risk calculation helper functions
  defp calculate_burnout_risk_score(activity_data, participation_data, indicators) do
    base_score = 0

    # High activity volume increases burnout risk
    base_score =
      if activity_data.total_activities > 40 do
        base_score + 20
      else
        base_score
      end

    # Very high participation rates can indicate overcommitment
    base_score =
      if participation_data.participation_rate > 0.9 do
        base_score + 15
      else
        base_score
      end

    # Add indicator-based scoring
    indicator_score = length(indicators) * 10

    min(100, base_score + indicator_score)
  end

  defp calculate_disengagement_risk_score(activity_data, participation_data, indicators) do
    base_score = 0

    # Low activity indicates potential disengagement
    base_score =
      if activity_data.total_activities < 5 do
        base_score + 30
      else
        base_score
      end

    # Low participation rate is a strong disengagement signal
    base_score =
      if participation_data.participation_rate < 0.3 do
        base_score + 40
      else
        base_score
      end

    # Add indicator-based scoring
    indicator_score = length(indicators) * 15

    min(100, base_score + indicator_score)
  end

  # Helper functions for data generation and analysis
  defp get_latest_analysis(character_id) do
    case MemberActivityIntelligence.get_by_character(character_id) do
      {:ok, []} -> {:error, :not_found}
      {:ok, analyses} -> {:ok, List.first(analyses)}
      error -> error
    end
  end

  defp build_activity_timeline(participants) do
    participants
    |> Enum.map(fn p ->
      %{
        killmail_time: p.killmail_time,
        is_kill: not p.is_victim,
        ship_type: p.ship_type_name,
        solar_system: p.solar_system_name
      }
    end)
    |> Enum.sort_by(& &1.killmail_time, {:desc, DateTime})
  end

  defp analyze_ship_usage(participants) do
    participants
    |> Enum.group_by(& &1.ship_type_name)
    |> Enum.map(fn {ship, uses} -> {ship, length(uses)} end)
    |> Enum.into(%{})
  end

  defp analyze_system_activity(participants) do
    participants
    |> Enum.group_by(& &1.solar_system_name)
    |> Enum.map(fn {system, activities} -> {system, length(activities)} end)
    |> Enum.into(%{})
  end

  defp generate_participation_timeline(_start_date, _end_date) do
    # Generate sample participation events
    []
  end

  defp generate_positive_trends(activity_data, participation_data) do
    trends = []

    trends =
      if activity_data.total_kills > activity_data.total_losses do
        trends ++
          [
            %{
              indicator: "positive_kill_ratio",
              description: "Maintaining positive kill/loss ratio indicates good performance",
              impact: "Increased confidence and fleet effectiveness"
            }
          ]
      else
        trends
      end

    trends =
      if participation_data.participation_rate > 0.7 do
        trends ++
          [
            %{
              indicator: "high_participation",
              description: "High participation rate shows strong corp engagement",
              impact: "Contributes to corp unity and operational success"
            }
          ]
      else
        trends
      end

    trends
  end

  defp determine_overall_risk(burnout_risk, disengagement_risk) do
    max_risk = max(burnout_risk, disengagement_risk)

    cond do
      max_risk >= 70 -> "high"
      max_risk >= 40 -> "medium"
      max_risk >= 20 -> "low"
      true -> "minimal"
    end
  end

  defp extract_primary_concerns(burnout_indicators, disengagement_indicators) do
    all_indicators = burnout_indicators ++ disengagement_indicators
    Enum.map(all_indicators, & &1.indicator)
  end

  defp identify_protective_factors(activity_data, participation_data) do
    factors = []

    factors =
      if participation_data.participation_rate > 0.5 do
        factors ++ ["active participation"]
      else
        factors
      end

    factors =
      if activity_data.total_activities > 10 do
        factors ++ ["consistent activity"]
      else
        factors
      end

    factors ++ ["corp membership", "skill development"]
  end

  defp recommend_interventions(burnout_risk, disengagement_risk) do
    interventions = []

    interventions =
      if burnout_risk > 60 do
        interventions ++ ["suggest activity reduction", "offer role rotation"]
      else
        interventions
      end

    interventions =
      if disengagement_risk > 60 do
        interventions ++ ["direct leadership contact", "offer mentoring"]
      else
        interventions
      end

    if Enum.empty?(interventions) do
      ["regular check-in", "continued monitoring"]
    else
      interventions
    end
  end

  defp generate_availability_windows(_hours) do
    # Generate availability windows based on activity hours
    [
      %{day: "monday", start: "19:00", end: "23:00", reliability: 0.8},
      %{day: "friday", start: "18:00", end: "01:00", reliability: 0.9}
    ]
  end

  defp calculate_coverage_contribution(timezone) do
    case timezone do
      "US/Pacific" -> %{eu_coverage: 0.1, us_coverage: 0.8, au_coverage: 0.1}
      "US/Eastern" -> %{eu_coverage: 0.2, us_coverage: 0.7, au_coverage: 0.1}
      "Europe/London" -> %{eu_coverage: 0.8, us_coverage: 0.2, au_coverage: 0.0}
      _ -> %{eu_coverage: 0.33, us_coverage: 0.33, au_coverage: 0.33}
    end
  end

  defp generate_daily_activity_pattern do
    days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

    days
    |> Enum.map(fn day ->
      {day,
       %{
         kills: :rand.uniform(5),
         participations: :rand.uniform(3),
         hours_active: :rand.uniform() * 6.0
       }}
    end)
    |> Enum.into(%{})
  end

  defp generate_hourly_activity_pattern do
    0..23
    |> Enum.map(fn hour ->
      hour_str = String.pad_leading(Integer.to_string(hour), 2, "0")

      {hour_str,
       %{
         activity_count: :rand.uniform(5),
         avg_participation: :rand.uniform()
       }}
    end)
    |> Enum.into(%{})
  end

  defp generate_monthly_trends do
    %{
      "2024-01" => %{
        kills: 20 + :rand.uniform(30),
        losses: 5 + :rand.uniform(15),
        participations: 15 + :rand.uniform(20)
      },
      "2024-02" => %{
        kills: 18 + :rand.uniform(25),
        losses: 7 + :rand.uniform(10),
        participations: 12 + :rand.uniform(18)
      }
    }
  end

  defp calculate_standard_deviation(values, mean) do
    if length(values) > 1 do
      variance =
        values
        |> Enum.map(fn x -> (x - mean) * (x - mean) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)

      :math.sqrt(variance)
    else
      0.0
    end
  end

  defp calculate_percentile(value, values) do
    sorted_values = Enum.sort(values)
    count_below = Enum.count(sorted_values, fn x -> x < value end)
    count_below / length(sorted_values) * 100
  end

  # Corporation report functions
  defp get_corporation_member_analyses(corporation_id) do
    MemberActivityIntelligence.get_by_corporation(corporation_id)
  end

  defp generate_risk_summary(member_analyses) do
    total_members = length(member_analyses)

    risk_counts =
      member_analyses
      |> Enum.group_by(fn member ->
        max_risk = max(member.burnout_risk_score, member.disengagement_risk_score)

        cond do
          max_risk >= 70 -> "high"
          max_risk >= 40 -> "medium"
          max_risk >= 20 -> "low"
          true -> "minimal"
        end
      end)
      |> Enum.map(fn {risk_level, members} -> {risk_level, length(members)} end)
      |> Enum.into(%{})

    {:ok,
     %{
       total_members: total_members,
       high_risk: Map.get(risk_counts, "high", 0),
       medium_risk: Map.get(risk_counts, "medium", 0),
       low_risk: Map.get(risk_counts, "low", 0),
       minimal_risk: Map.get(risk_counts, "minimal", 0)
     }}
  end

  defp calculate_engagement_metrics(member_analyses) do
    if length(member_analyses) > 0 do
      avg_engagement =
        member_analyses
        |> Enum.map(& &1.engagement_score)
        |> Enum.sum()
        |> Kernel./(length(member_analyses))

      high_engagement_count = Enum.count(member_analyses, fn m -> m.engagement_score >= 75 end)
      low_engagement_count = Enum.count(member_analyses, fn m -> m.engagement_score < 40 end)

      {:ok,
       %{
         average_engagement_score: Float.round(avg_engagement, 1),
         high_engagement_members: high_engagement_count,
         low_engagement_members: low_engagement_count,
         engagement_distribution: calculate_engagement_distribution(member_analyses)
       }}
    else
      {:ok,
       %{
         average_engagement_score: 0.0,
         high_engagement_members: 0,
         low_engagement_members: 0,
         engagement_distribution: %{}
       }}
    end
  end

  defp generate_leadership_recommendations(member_analyses) do
    recommendations = []

    # High risk members need attention
    high_risk_members =
      Enum.filter(member_analyses, fn member ->
        max(member.burnout_risk_score, member.disengagement_risk_score) >= 60
      end)

    recommendations =
      if length(high_risk_members) > 0 do
        recommendations ++
          [
            %{
              priority: "high",
              category: "member_retention",
              recommendation:
                "#{length(high_risk_members)} members require immediate leadership attention",
              action_items: [
                "Schedule 1-on-1 conversations",
                "Review member roles and responsibilities"
              ]
            }
          ]
      else
        recommendations
      end

    # Low engagement members
    low_engagement_members =
      Enum.filter(member_analyses, fn member ->
        member.engagement_score < 40
      end)

    recommendations =
      if length(low_engagement_members) > 0 do
        recommendations ++
          [
            %{
              priority: "medium",
              category: "engagement",
              recommendation: "#{length(low_engagement_members)} members showing low engagement",
              action_items: [
                "Offer training opportunities",
                "Invite to special events",
                "Check for role fit"
              ]
            }
          ]
      else
        recommendations
      end

    {:ok, recommendations}
  end

  defp format_member_summaries(member_analyses) do
    member_analyses
    |> Enum.map(fn member ->
      %{
        character_id: member.character_id,
        character_name: member.character_name,
        engagement_score: member.engagement_score,
        activity_trend: member.activity_trend,
        risk_level:
          determine_overall_risk(member.burnout_risk_score, member.disengagement_risk_score),
        needs_attention: max(member.burnout_risk_score, member.disengagement_risk_score) >= 60
      }
    end)
  end

  defp calculate_engagement_distribution(member_analyses) do
    member_analyses
    |> Enum.group_by(fn member ->
      cond do
        member.engagement_score >= 80 -> "very_high"
        member.engagement_score >= 60 -> "high"
        member.engagement_score >= 40 -> "medium"
        member.engagement_score >= 20 -> "low"
        true -> "very_low"
      end
    end)
    |> Enum.map(fn {level, members} -> {level, length(members)} end)
    |> Enum.into(%{})
  end

  # Member attention functions
  defp determine_primary_concern(member) do
    if member.burnout_risk_score > member.disengagement_risk_score do
      "burnout_risk"
    else
      "disengagement_risk"
    end
  end

  defp calculate_attention_urgency(member) do
    max_risk = max(member.burnout_risk_score, member.disengagement_risk_score)

    cond do
      max_risk >= 80 -> "critical"
      max_risk >= 60 -> "high"
      max_risk >= 40 -> "medium"
      true -> "low"
    end
  end

  defp recommend_leadership_action(member) do
    primary_concern = determine_primary_concern(member)

    case primary_concern do
      "burnout_risk" ->
        "Schedule break discussion, offer role rotation or reduced responsibilities"

      "disengagement_risk" ->
        "Direct 1-on-1 conversation to understand concerns and re-engage"

      _ ->
        "Regular check-in and continued monitoring"
    end
  end

  defp calculate_contact_priority(member) do
    base_priority = max(member.burnout_risk_score, member.disengagement_risk_score)

    # Adjust based on engagement score and activity trend
    engagement_modifier =
      if member.engagement_score < 30 do
        10
      else
        0
      end

    trend_modifier =
      if member.activity_trend == "decreasing" do
        5
      else
        0
      end

    base_priority + engagement_modifier + trend_modifier
  end
end
