defmodule EveDmv.Contexts.CorporationAnalysis.Analyzers.ParticipationAnalyzer do
  @moduledoc """
  Member participation pattern analysis for Corporation Analysis context.

  Analyzes different types of member participation in EVE Online activities,
  including fleet operations, home defense, chain operations, and solo activities.
  Provides insights into participation patterns, rates, and metrics to help
  understand member engagement and contribution patterns.

  ## Participation Categories

  - **Fleet Operations**: Organized fleet activities with multiple participants
  - **Home Defense**: Defensive operations within corporation systems
  - **Chain Operations**: Wormhole chain activities across multiple systems
  - **Solo Activities**: Individual activities without fleet participation
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Contexts.CorporationAnalysis.Infrastructure.ParticipationDataProvider

  require Logger

  @doc """
  Analyze participation patterns for a member within corporation context.

  Returns comprehensive participation analysis including activity categorization,
  participation rates, and engagement metrics.
  """
  def analyze(character_id, base_data \\ %{}, opts \\ []) when is_integer(character_id) do
    try do
      period_start = get_period_start(opts, base_data)
      period_end = get_period_end(opts, base_data)

      with {:ok, participation_data} <- get_participation_data(base_data, character_id, period_start, period_end),
           {:ok, fleet_activities} <- analyze_fleet_participation(participation_data),
           {:ok, home_defense} <- analyze_home_defense_participation(participation_data),
           {:ok, chain_operations} <- analyze_chain_operations(participation_data),
           {:ok, solo_activities} <- analyze_solo_activities(participation_data) do

        analysis = %{
          character_id: character_id,
          analysis_period_start: period_start,
          analysis_period_end: period_end,

          # Activity counts
          fleet_participation_count: fleet_activities.participation_count,
          home_defense_count: home_defense.participation_count,
          chain_operations_count: chain_operations.participation_count,
          solo_activity_count: solo_activities.activity_count,

          # Participation rates
          fleet_participation_rate: fleet_activities.participation_rate,
          home_defense_rate: home_defense.participation_rate,
          chain_operations_rate: chain_operations.participation_rate,
          solo_activity_rate: solo_activities.activity_rate,

          # Activity patterns
          primary_activity_type: determine_primary_activity_type(fleet_activities, home_defense, chain_operations, solo_activities),
          activity_distribution: calculate_activity_distribution(fleet_activities, home_defense, chain_operations, solo_activities),
          engagement_pattern: determine_engagement_pattern(fleet_activities, solo_activities),

          # Detailed metrics
          fleet_readiness_score: fleet_activities.readiness_score,
          home_system_identification: home_defense.home_systems,
          chain_activity_scope: chain_operations.activity_scope,
          solo_capability_assessment: solo_activities.capability_assessment,

          # Trends and insights
          participation_trend: calculate_participation_trend(participation_data),
          consistency_score: calculate_consistency_score(participation_data),
          peak_activity_periods: identify_peak_activity_periods(participation_data),

          # Comparative metrics
          corp_participation_percentile: calculate_corp_percentile(character_id, fleet_activities, base_data)
        }

        Result.ok(analysis)
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception -> Result.error(:analysis_failed, "Participation analysis error: #{inspect(exception)}")
    end
  end

  @doc """
  Analyze corporation-wide participation patterns.

  Provides aggregate participation analysis for all corporation members,
  identifying participation trends and engagement patterns.
  """
  def analyze_corporation_participation(corporation_id, base_data \\ %{}, opts \\ []) when is_integer(corporation_id) do
    try do
      period_start = get_period_start(opts, base_data)
      period_end = get_period_end(opts, base_data)

      with {:ok, member_participations} <- get_corporation_member_participations(base_data, corporation_id, period_start, period_end) do

        analysis = %{
          corporation_id: corporation_id,
          analysis_period_start: period_start,
          analysis_period_end: period_end,
          total_members_analyzed: length(member_participations),

          # Aggregate participation metrics
          average_fleet_participation: calculate_average_fleet_participation(member_participations),
          total_fleet_operations: calculate_total_fleet_operations(member_participations),
          total_home_defense_ops: calculate_total_home_defense_ops(member_participations),
          total_chain_operations: calculate_total_chain_operations(member_participations),

          # Participation distribution
          high_participation_members: count_high_participation_members(member_participations),
          moderate_participation_members: count_moderate_participation_members(member_participations),
          low_participation_members: count_low_participation_members(member_participations),
          inactive_members: count_inactive_members(member_participations),

          # Corporation insights
          participation_health_score: calculate_participation_health_score(member_participations),
          most_active_operation_type: determine_most_active_operation_type(member_participations),
          participation_trends: analyze_corporation_participation_trends(member_participations),

          # Recommendations
          improvement_areas: identify_participation_improvement_areas(member_participations),
          engagement_recommendations: generate_engagement_recommendations(member_participations)
        }

        Result.ok(analysis)
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception -> Result.error(:corp_analysis_failed, "Corporation participation analysis error: #{inspect(exception)}")
    end
  end

  @doc """
  Generate participation report for corporation leadership.

  Creates comprehensive participation report with insights,
  trends, and actionable recommendations.
  """
  def generate_participation_report(corporation_id, base_data \\ %{}, opts \\ []) do
    try do
      include_member_details = Keyword.get(opts, :include_member_details, false)

      with {:ok, corp_analysis} <- analyze_corporation_participation(corporation_id, base_data, opts),
           {:ok, member_analyses} <- get_member_participation_analyses(base_data, corporation_id, opts) do

        report = %{
          corporation_summary: corp_analysis,
          participation_overview: format_participation_overview(corp_analysis),
          activity_breakdown: format_activity_breakdown(corp_analysis),
          member_engagement_analysis: format_member_engagement_analysis(member_analyses),
          trends_and_patterns: format_trends_and_patterns(corp_analysis),
          leadership_recommendations: format_leadership_recommendations(corp_analysis),
          member_details: if(include_member_details, do: format_member_participation_details(member_analyses), else: [])
        }

        Result.ok(report)
      else
        {:error, _reason} = error -> error
      end
    rescue
      exception -> Result.error(:report_generation_failed, "Participation report generation error: #{inspect(exception)}")
    end
  end

  # Private implementation functions

  defp get_participation_data(base_data, character_id, period_start, period_end) do
    case Map.get(base_data, :participation_data) do
      nil -> ParticipationDataProvider.get_participation_data(character_id, period_start, period_end)
      data -> {:ok, data}
    end
  end

  defp get_corporation_member_participations(base_data, corporation_id, period_start, period_end) do
    case Map.get(base_data, :member_participations) do
      nil -> ParticipationDataProvider.get_corporation_member_participations(corporation_id, period_start, period_end)
      participations -> {:ok, participations}
    end
  end

  defp get_member_participation_analyses(base_data, corporation_id, opts) do
    case Map.get(base_data, :member_analyses) do
      nil ->
        # Generate individual analyses for each member
        with {:ok, members} <- ParticipationDataProvider.get_corporation_members(corporation_id) do
          analyses =
            members
            |> Enum.map(fn member ->
              case analyze(member.character_id, base_data, opts) do
                {:ok, analysis} -> analysis
                {:error, _} -> nil
              end
            end)
            |> Enum.filter(&(&1 != nil))

          {:ok, analyses}
        end
      analyses -> {:ok, analyses}
    end
  end

  defp analyze_fleet_participation(participation_data) do
    fleet_activities = filter_fleet_activities(participation_data)

    participation_count = length(fleet_activities)
    participation_rate = calculate_participation_rate(fleet_activities, participation_data.total_opportunities)
    readiness_score = calculate_fleet_readiness_score(fleet_activities)

    {:ok, %{
      participation_count: participation_count,
      participation_rate: participation_rate,
      readiness_score: readiness_score,
      activities: fleet_activities
    }}
  end

  defp analyze_home_defense_participation(participation_data) do
    home_defense_activities = filter_home_defense_activities(participation_data)

    participation_count = length(home_defense_activities)
    participation_rate = calculate_participation_rate(home_defense_activities, participation_data.defensive_opportunities)
    home_systems = identify_home_systems(home_defense_activities)

    {:ok, %{
      participation_count: participation_count,
      participation_rate: participation_rate,
      home_systems: home_systems,
      activities: home_defense_activities
    }}
  end

  defp analyze_chain_operations(participation_data) do
    chain_activities = filter_chain_activities(participation_data)

    participation_count = length(chain_activities)
    participation_rate = calculate_participation_rate(chain_activities, participation_data.chain_opportunities)
    activity_scope = calculate_chain_activity_scope(chain_activities)

    {:ok, %{
      participation_count: participation_count,
      participation_rate: participation_rate,
      activity_scope: activity_scope,
      activities: chain_activities
    }}
  end

  defp analyze_solo_activities(participation_data) do
    solo_activities = filter_solo_activities(participation_data)

    activity_count = length(solo_activities)
    activity_rate = calculate_activity_rate(solo_activities, participation_data.total_activities)
    capability_assessment = assess_solo_capability(solo_activities)

    {:ok, %{
      activity_count: activity_count,
      activity_rate: activity_rate,
      capability_assessment: capability_assessment,
      activities: solo_activities
    }}
  end

  defp filter_fleet_activities(participation_data) do
    participation_data.activities
    |> Enum.filter(&(&1.activity_type == :fleet_operation))
  end

  defp filter_home_defense_activities(participation_data) do
    participation_data.activities
    |> Enum.filter(&(&1.activity_type == :home_defense))
  end

  defp filter_chain_activities(participation_data) do
    participation_data.activities
    |> Enum.filter(&(&1.activity_type == :chain_operation))
  end

  defp filter_solo_activities(participation_data) do
    participation_data.activities
    |> Enum.filter(&(&1.activity_type == :solo_activity))
  end

  defp calculate_participation_rate(activities, opportunities) when opportunities > 0 do
    Float.round(length(activities) / opportunities * 100, 1)
  end
  defp calculate_participation_rate(_activities, _opportunities), do: 0.0

  defp calculate_activity_rate(activities, total_activities) when total_activities > 0 do
    Float.round(length(activities) / total_activities * 100, 1)
  end
  defp calculate_activity_rate(_activities, _total_activities), do: 0.0

  defp calculate_fleet_readiness_score(fleet_activities) do
    if Enum.empty?(fleet_activities) do
      0.0
    else
      # Score based on response time, consistency, and effectiveness
      avg_response_time = calculate_average_response_time(fleet_activities)
      consistency = calculate_consistency(fleet_activities)
      effectiveness = calculate_effectiveness(fleet_activities)

      readiness = (avg_response_time + consistency + effectiveness) / 3
      Float.round(readiness, 1)
    end
  end

  defp identify_home_systems(home_defense_activities) do
    home_defense_activities
    |> Enum.map(&(&1.system_id))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_system, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {system_id, _count} -> system_id end)
  end

  defp calculate_chain_activity_scope(chain_activities) do
    unique_systems = chain_activities |> Enum.map(&(&1.system_id)) |> Enum.uniq() |> length()
    unique_regions = chain_activities |> Enum.map(&(&1.region_id)) |> Enum.uniq() |> length()

    %{
      unique_systems: unique_systems,
      unique_regions: unique_regions,
      scope_rating: determine_scope_rating(unique_systems, unique_regions)
    }
  end

  defp assess_solo_capability(solo_activities) do
    if Enum.empty?(solo_activities) do
      %{capability_level: :none, assessment: "No solo activity data"}
    else
      success_rate = calculate_solo_success_rate(solo_activities)
      avg_value = calculate_average_activity_value(solo_activities)

      capability_level = cond do
        success_rate >= 80 and avg_value > 100_000_000 -> :expert
        success_rate >= 70 and avg_value > 50_000_000 -> :advanced
        success_rate >= 60 and avg_value > 20_000_000 -> :intermediate
        success_rate >= 40 -> :novice
        true -> :beginner
      end

      %{
        capability_level: capability_level,
        success_rate: success_rate,
        average_value: avg_value,
        assessment: format_capability_assessment(capability_level)
      }
    end
  end

  defp determine_primary_activity_type(fleet, home_defense, chain, solo) do
    activities = %{
      fleet: fleet.participation_count,
      home_defense: home_defense.participation_count,
      chain: chain.participation_count,
      solo: solo.activity_count
    }

    activities
    |> Enum.max_by(fn {_type, count} -> count end)
    |> elem(0)
  end

  defp calculate_activity_distribution(fleet, home_defense, chain, solo) do
    total = fleet.participation_count + home_defense.participation_count +
           chain.participation_count + solo.activity_count

    if total > 0 do
      %{
        fleet: Float.round(fleet.participation_count / total * 100, 1),
        home_defense: Float.round(home_defense.participation_count / total * 100, 1),
        chain: Float.round(chain.participation_count / total * 100, 1),
        solo: Float.round(solo.activity_count / total * 100, 1)
      }
    else
      %{fleet: 0, home_defense: 0, chain: 0, solo: 0}
    end
  end

  defp determine_engagement_pattern(fleet_activities, solo_activities) do
    fleet_count = fleet_activities.participation_count
    solo_count = solo_activities.activity_count
    total = fleet_count + solo_count

    if total == 0 do
      :inactive
    else
      fleet_ratio = fleet_count / total

      cond do
        fleet_ratio >= 0.8 -> :fleet_focused
        fleet_ratio >= 0.6 -> :fleet_preferred
        fleet_ratio >= 0.4 -> :mixed_engagement
        fleet_ratio >= 0.2 -> :solo_preferred
        true -> :solo_focused
      end
    end
  end

  defp calculate_participation_trend(participation_data) do
    # Simplified trend calculation based on recent vs historical data
    recent_activities = count_recent_activities(participation_data, 7)
    historical_avg = calculate_historical_average(participation_data)

    if historical_avg > 0 do
      trend_value = (recent_activities - historical_avg) / historical_avg

      cond do
        trend_value > 0.2 -> :increasing
        trend_value < -0.2 -> :decreasing
        true -> :stable
      end
    else
      :stable
    end
  end

  defp calculate_consistency_score(participation_data) do
    # Calculate consistency based on activity distribution over time
    activities_by_week = group_activities_by_week(participation_data.activities)

    if map_size(activities_by_week) < 2 do
      0.5  # Not enough data
    else
      weekly_counts = Map.values(activities_by_week)
      mean = Enum.sum(weekly_counts) / length(weekly_counts)
      variance = calculate_variance(weekly_counts, mean)

      # Convert variance to consistency score (lower variance = higher consistency)
      consistency = max(0, 1 - (variance / (mean + 1)))
      Float.round(consistency, 2)
    end
  end

  defp identify_peak_activity_periods(participation_data) do
    activities_by_hour = group_activities_by_hour(participation_data.activities)

    activities_by_hour
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _count} -> format_hour(hour) end)
  end

  defp calculate_corp_percentile(character_id, fleet_activities, base_data) do
    # Compare this member's participation with corporation average
    case Map.get(base_data, :corp_participation_data) do
      nil -> 50  # Default percentile
      corp_data ->
        member_score = fleet_activities.participation_count
        corp_scores = Enum.map(corp_data, &(&1.fleet_participation_count))

        calculate_percentile(member_score, corp_scores)
    end
  end

  # Corporation-wide analysis functions

  defp calculate_average_fleet_participation(member_participations) do
    if Enum.empty?(member_participations) do
      0.0
    else
      total = Enum.sum(Enum.map(member_participations, &(&1.fleet_participation_count)))
      Float.round(total / length(member_participations), 1)
    end
  end

  defp calculate_total_fleet_operations(member_participations) do
    Enum.sum(Enum.map(member_participations, &(&1.fleet_participation_count)))
  end

  defp calculate_total_home_defense_ops(member_participations) do
    Enum.sum(Enum.map(member_participations, &(&1.home_defense_count)))
  end

  defp calculate_total_chain_operations(member_participations) do
    Enum.sum(Enum.map(member_participations, &(&1.chain_operations_count)))
  end

  defp count_high_participation_members(member_participations) do
    Enum.count(member_participations, &(&1.fleet_participation_count >= 10))
  end

  defp count_moderate_participation_members(member_participations) do
    Enum.count(member_participations, &(&1.fleet_participation_count >= 5 and &1.fleet_participation_count < 10))
  end

  defp count_low_participation_members(member_participations) do
    Enum.count(member_participations, &(&1.fleet_participation_count >= 1 and &1.fleet_participation_count < 5))
  end

  defp count_inactive_members(member_participations) do
    Enum.count(member_participations, &(&1.fleet_participation_count == 0))
  end

  defp calculate_participation_health_score(member_participations) do
    if Enum.empty?(member_participations) do
      0.0
    else
      high_count = count_high_participation_members(member_participations)
      moderate_count = count_moderate_participation_members(member_participations)
      total_count = length(member_participations)

      health_score = (high_count * 1.0 + moderate_count * 0.6) / total_count * 100
      Float.round(health_score, 1)
    end
  end

  defp determine_most_active_operation_type(member_participations) do
    totals = %{
      fleet: calculate_total_fleet_operations(member_participations),
      home_defense: calculate_total_home_defense_ops(member_participations),
      chain: calculate_total_chain_operations(member_participations)
    }

    totals
    |> Enum.max_by(fn {_type, count} -> count end)
    |> elem(0)
  end

  defp analyze_corporation_participation_trends(member_participations) do
    # Simplified trend analysis
    %{
      overall_trend: :stable,  # Would calculate from historical data
      participation_growth: 0,  # Would calculate growth rate
      member_retention: calculate_member_retention_rate(member_participations)
    }
  end

  defp identify_participation_improvement_areas(member_participations) do
    areas = []

    inactive_ratio = count_inactive_members(member_participations) / length(member_participations)
    low_participation_ratio = count_low_participation_members(member_participations) / length(member_participations)

    areas = if inactive_ratio > 0.3, do: [:member_activation | areas], else: areas
    areas = if low_participation_ratio > 0.4, do: [:engagement_programs | areas], else: areas

    if Enum.empty?(areas), do: [:maintain_current_programs], else: areas
  end

  defp generate_engagement_recommendations(member_participations) do
    inactive_count = count_inactive_members(member_participations)
    low_participation_count = count_low_participation_members(member_participations)

    recommendations = []

    recommendations = if inactive_count > 0 do
      ["Implement outreach program for #{inactive_count} inactive members" | recommendations]
    else
      recommendations
    end

    recommendations = if low_participation_count > 2 do
      ["Create mentorship program for #{low_participation_count} low-participation members" | recommendations]
    else
      recommendations
    end

    if Enum.empty?(recommendations) do
      ["Continue current engagement strategies"]
    else
      recommendations
    end
  end

  # Helper functions

  defp get_period_start(opts, base_data) do
    Keyword.get(opts, :period_start) ||
    Map.get(base_data, :period_start) ||
    DateTime.add(DateTime.utc_now(), -30, :day)
  end

  defp get_period_end(opts, base_data) do
    Keyword.get(opts, :period_end) ||
    Map.get(base_data, :period_end) ||
    DateTime.utc_now()
  end

  defp calculate_average_response_time(fleet_activities) do
    # Simplified response time calculation
    # Would analyze actual response times from activity data
    75.0  # Placeholder
  end

  defp calculate_consistency(fleet_activities) do
    # Simplified consistency calculation
    # Would analyze participation regularity
    80.0  # Placeholder
  end

  defp calculate_effectiveness(fleet_activities) do
    # Simplified effectiveness calculation
    # Would analyze success rates and outcomes
    70.0  # Placeholder
  end

  defp determine_scope_rating(unique_systems, unique_regions) do
    cond do
      unique_systems > 20 and unique_regions > 3 -> :extensive
      unique_systems > 10 and unique_regions > 2 -> :broad
      unique_systems > 5 -> :moderate
      unique_systems > 1 -> :limited
      true -> :minimal
    end
  end

  defp calculate_solo_success_rate(solo_activities) do
    if Enum.empty?(solo_activities) do
      0.0
    else
      successful = Enum.count(solo_activities, &(&1.successful == true))
      Float.round(successful / length(solo_activities) * 100, 1)
    end
  end

  defp calculate_average_activity_value(solo_activities) do
    if Enum.empty?(solo_activities) do
      0
    else
      total_value = Enum.sum(Enum.map(solo_activities, &(&1.isk_value || 0)))
      trunc(total_value / length(solo_activities))
    end
  end

  defp format_capability_assessment(capability_level) do
    case capability_level do
      :expert -> "Expert solo operator with high success rate and value"
      :advanced -> "Advanced solo capabilities with consistent performance"
      :intermediate -> "Intermediate solo skills with moderate success"
      :novice -> "Developing solo capabilities"
      :beginner -> "Limited solo experience"
      :none -> "No solo activity recorded"
    end
  end

  defp count_recent_activities(participation_data, days) do
    cutoff = DateTime.add(DateTime.utc_now(), -days, :day)

    participation_data.activities
    |> Enum.count(&(DateTime.compare(&1.timestamp, cutoff) == :gt))
  end

  defp calculate_historical_average(participation_data) do
    # Simplified historical average calculation
    total_days = DateTime.diff(participation_data.period_end, participation_data.period_start, :day)
    if total_days > 0 do
      length(participation_data.activities) / total_days
    else
      0
    end
  end

  defp group_activities_by_week(activities) do
    activities
    |> Enum.group_by(fn activity ->
      Date.beginning_of_week(DateTime.to_date(activity.timestamp))
    end)
    |> Enum.map(fn {week, activities} -> {week, length(activities)} end)
    |> Map.new()
  end

  defp group_activities_by_hour(activities) do
    activities
    |> Enum.group_by(&(&1.timestamp.hour))
    |> Enum.map(fn {hour, activities} -> {hour, length(activities)} end)
    |> Map.new()
  end

  defp calculate_variance(values, mean) do
    if Enum.empty?(values) do
      0
    else
      sum_squared_diffs = Enum.sum(Enum.map(values, &((&1 - mean) * (&1 - mean))))
      sum_squared_diffs / length(values)
    end
  end

  defp format_hour(hour) do
    "#{String.pad_leading(Integer.to_string(hour), 2, "0")}:00"
  end

  defp calculate_percentile(value, values) do
    if Enum.empty?(values) do
      50
    else
      sorted_values = Enum.sort(values)
      position = Enum.find_index(sorted_values, &(&1 >= value)) || length(sorted_values)
      trunc(position / length(sorted_values) * 100)
    end
  end

  defp calculate_member_retention_rate(member_participations) do
    # Simplified retention rate calculation
    # Would compare with historical member data
    active_members = Enum.count(member_participations, &(&1.fleet_participation_count > 0))
    total_members = length(member_participations)

    if total_members > 0 do
      Float.round(active_members / total_members * 100, 1)
    else
      0.0
    end
  end

  # Report formatting functions

  defp format_participation_overview(corp_analysis) do
    %{
      total_members: corp_analysis.total_members_analyzed,
      participation_health: corp_analysis.participation_health_score,
      most_active_operation: corp_analysis.most_active_operation_type,
      high_participation_percentage: Float.round(corp_analysis.high_participation_members / corp_analysis.total_members_analyzed * 100, 1)
    }
  end

  defp format_activity_breakdown(corp_analysis) do
    %{
      fleet_operations: corp_analysis.total_fleet_operations,
      home_defense: corp_analysis.total_home_defense_ops,
      chain_operations: corp_analysis.total_chain_operations,
      average_member_participation: corp_analysis.average_fleet_participation
    }
  end

  defp format_member_engagement_analysis(member_analyses) do
    %{
      engagement_distribution: calculate_engagement_distribution(member_analyses),
      participation_consistency: calculate_participation_consistency(member_analyses),
      top_performers: identify_top_performers(member_analyses)
    }
  end

  defp format_trends_and_patterns(corp_analysis) do
    corp_analysis.participation_trends
  end

  defp format_leadership_recommendations(corp_analysis) do
    corp_analysis.engagement_recommendations
  end

  defp format_member_participation_details(member_analyses) do
    member_analyses
    |> Enum.map(fn analysis ->
      %{
        character_id: analysis.character_id,
        primary_activity: analysis.primary_activity_type,
        participation_score: calculate_member_participation_score(analysis),
        engagement_pattern: analysis.engagement_pattern,
        consistency: analysis.consistency_score
      }
    end)
    |> Enum.sort_by(&(&1.participation_score), :desc)
  end

  defp calculate_engagement_distribution(member_analyses) do
    member_analyses
    |> Enum.map(&(&1.engagement_pattern))
    |> Enum.frequencies()
  end

  defp calculate_participation_consistency(member_analyses) do
    if Enum.empty?(member_analyses) do
      0.0
    else
      avg_consistency =
        member_analyses
        |> Enum.map(&(&1.consistency_score))
        |> Enum.sum()
        |> Kernel./(length(member_analyses))

      Float.round(avg_consistency, 2)
    end
  end

  defp identify_top_performers(member_analyses) do
    member_analyses
    |> Enum.sort_by(&calculate_member_participation_score/1, :desc)
    |> Enum.take(5)
    |> Enum.map(fn analysis ->
      %{
        character_id: analysis.character_id,
        score: calculate_member_participation_score(analysis),
        specialty: analysis.primary_activity_type
      }
    end)
  end

  defp calculate_member_participation_score(analysis) do
    base_score = analysis.fleet_participation_count * 3 +
                analysis.home_defense_count * 2 +
                analysis.chain_operations_count * 2 +
                analysis.solo_activity_count * 1

    consistency_bonus = analysis.consistency_score * 10

    trunc(base_score + consistency_bonus)
  end
end