defmodule EveDmv.Contexts.CorporationAnalysis.Formatters.MemberActivityDisplayFormatter do
  @moduledoc """
  Formatting and display utilities for member activity analysis within Corporation Analysis context.

  This module handles all presentation logic, report generation,
  and data formatting for member activity intelligence.
  """

  @doc """
  Format member summaries for corporation reports.
  """
  def format_member_summaries(member_analyses) do
    Enum.map(member_analyses, fn analysis ->
      %{
        character_id: analysis.character_id,
        character_name: analysis.character_name,
        engagement_status: format_engagement_status(analysis.engagement_score),
        risk_level: format_risk_level(analysis),
        activity_summary: format_activity_summary(analysis),
        last_activity: format_relative_time(analysis.activity_period_end),
        requires_attention: requires_attention?(analysis)
      }
    end)
  end

  @doc """
  Generate leadership recommendations based on analysis data.
  """
  def generate_leadership_recommendations(member_analyses) do
    high_risk_count = count_high_risk_members(member_analyses)
    declining_count = count_declining_members(member_analyses)
    inactive_count = count_inactive_members(member_analyses)

    recommendations = []

    recommendations =
      if high_risk_count > 0 do
        [
          %{
            priority: :high,
            category: :member_retention,
            title: "Address High-Risk Members",
            description: "#{high_risk_count} members show signs of disengagement",
            action: "Schedule one-on-one conversations with at-risk members"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if declining_count > 2 do
        [
          %{
            priority: :medium,
            category: :member_engagement,
            title: "Member Activity Declining",
            description: "#{declining_count} members showing declining participation",
            action: "Review corporation activities and member interests"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if inactive_count > 5 do
        [
          %{
            priority: :low,
            category: :member_cleanup,
            title: "Inactive Member Review",
            description: "#{inactive_count} members have been inactive for extended periods",
            action: "Consider member activity review and potential cleanup"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  @doc """
  Create detailed corporation activity report.
  """
  def generate_activity_report(member_analyses, options \\ []) do
    include_individual_details = Keyword.get(options, :include_individuals, false)

    %{
      summary: generate_report_summary(member_analyses),
      engagement_overview: format_engagement_overview(member_analyses),
      risk_analysis: format_risk_analysis(member_analyses),
      trends: format_activity_trends(member_analyses),
      recommendations: generate_leadership_recommendations(member_analyses),
      member_details:
        if(include_individual_details, do: format_member_summaries(member_analyses), else: [])
    }
  end

  @doc """
  Format activity data for dashboard display.
  """
  def format_dashboard_data(member_analyses) do
    %{
      total_members: length(member_analyses),
      active_members: count_active_members(member_analyses),
      at_risk_members: count_high_risk_members(member_analyses),
      engagement_distribution: calculate_engagement_distribution(member_analyses),
      activity_trend: calculate_activity_trend(member_analyses)
    }
  end

  # Private formatting functions

  defp format_engagement_status(engagement_score) do
    cond do
      engagement_score >= 80 -> :highly_engaged
      engagement_score >= 60 -> :engaged
      engagement_score >= 40 -> :moderately_engaged
      engagement_score >= 20 -> :disengaged
      true -> :inactive
    end
  end

  defp format_risk_level(analysis) do
    risk_factors = [
      analysis.burnout_risk > 0.7,
      analysis.engagement_score < 30,
      analysis.activity_decline > 0.5,
      analysis.social_isolation_risk > 0.6
    ]

    risk_count = Enum.count(risk_factors, & &1)

    case risk_count do
      0 -> :low
      1 -> :moderate
      2 -> :high
      _ -> :critical
    end
  end

  defp format_activity_summary(analysis) do
    fleet_ops = analysis.fleet_participation_count || 0
    solo_activity = analysis.solo_activity_count || 0

    %{
      fleet_operations: fleet_ops,
      solo_activity: solo_activity,
      total_activity: fleet_ops + solo_activity,
      participation_trend: format_trend(analysis.participation_trend),
      peak_activity_day: analysis.peak_activity_day || "Unknown"
    }
  end

  defp format_relative_time(nil), do: "Never"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)

    cond do
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 2_592_000 -> "#{div(diff_seconds, 86400)} days ago"
      true -> "Over a month ago"
    end
  end

  defp requires_attention?(analysis) do
    analysis.burnout_risk > 0.6 or
      analysis.engagement_score < 25 or
      analysis.activity_decline > 0.8 or
      analysis.social_isolation_risk > 0.7
  end

  defp count_high_risk_members(member_analyses) do
    Enum.count(member_analyses, &(format_risk_level(&1) in [:high, :critical]))
  end

  defp count_declining_members(member_analyses) do
    Enum.count(member_analyses, &(&1.activity_decline > 0.3))
  end

  defp count_inactive_members(member_analyses) do
    Enum.count(member_analyses, &(&1.engagement_score < 10))
  end

  defp count_active_members(member_analyses) do
    Enum.count(member_analyses, &(&1.engagement_score >= 40))
  end

  defp generate_report_summary(member_analyses) do
    total_members = length(member_analyses)
    active_members = count_active_members(member_analyses)
    at_risk_members = count_high_risk_members(member_analyses)

    activity_rate = if total_members > 0, do: active_members / total_members * 100, else: 0

    %{
      total_members: total_members,
      active_members: active_members,
      activity_percentage: Float.round(activity_rate, 1),
      at_risk_members: at_risk_members,
      health_status: determine_corporation_health(activity_rate, at_risk_members, total_members)
    }
  end

  defp format_engagement_overview(member_analyses) do
    engagement_groups =
      member_analyses
      |> Enum.group_by(&format_engagement_status(&1.engagement_score))
      |> Enum.map(fn {status, members} ->
        {status,
         %{count: length(members), percentage: length(members) / length(member_analyses) * 100}}
      end)
      |> Enum.into(%{})

    %{
      distribution: engagement_groups,
      average_engagement: calculate_average_engagement(member_analyses),
      engagement_trend: calculate_engagement_trend(member_analyses)
    }
  end

  defp format_risk_analysis(member_analyses) do
    %{
      burnout_risk: format_burnout_analysis(member_analyses),
      retention_risk: format_retention_analysis(member_analyses),
      leadership_gaps: identify_leadership_gaps(member_analyses)
    }
  end

  defp format_activity_trends(member_analyses) do
    %{
      participation_trend: calculate_participation_trend(member_analyses),
      seasonal_patterns: identify_seasonal_patterns(member_analyses),
      peak_activity_periods: identify_peak_periods(member_analyses)
    }
  end

  defp calculate_engagement_distribution(member_analyses) do
    member_analyses
    |> Enum.group_by(&format_engagement_status(&1.engagement_score))
    |> Enum.map(fn {status, members} ->
      {status, length(members)}
    end)
    |> Enum.into(%{})
  end

  defp calculate_activity_trend(member_analyses) do
    if length(member_analyses) > 0 do
      avg_trend =
        member_analyses
        |> Enum.map(&(&1.activity_decline || 0))
        |> Enum.sum()
        |> Kernel./(length(member_analyses))

      cond do
        avg_trend < -0.1 -> :improving
        avg_trend > 0.1 -> :declining
        true -> :stable
      end
    else
      :stable
    end
  end

  defp format_trend(trend_value) when is_number(trend_value) do
    cond do
      trend_value > 0.1 -> :increasing
      trend_value < -0.1 -> :decreasing
      true -> :stable
    end
  end

  defp format_trend(_), do: :unknown

  defp determine_corporation_health(activity_rate, at_risk_count, total_members) do
    risk_percentage = if total_members > 0, do: at_risk_count / total_members * 100, else: 0

    cond do
      activity_rate >= 70 and risk_percentage < 10 -> :excellent
      activity_rate >= 50 and risk_percentage < 20 -> :good
      activity_rate >= 30 and risk_percentage < 30 -> :fair
      activity_rate >= 15 -> :concerning
      true -> :critical
    end
  end

  defp calculate_average_engagement(member_analyses) do
    if length(member_analyses) > 0 do
      total_engagement = Enum.sum(Enum.map(member_analyses, &(&1.engagement_score || 0)))
      Float.round(total_engagement / length(member_analyses), 1)
    else
      0.0
    end
  end

  defp calculate_engagement_trend(member_analyses) do
    # Simplified trend calculation based on recent vs historical engagement
    recent_engagements = Enum.map(member_analyses, &(&1.engagement_score || 0))

    if length(recent_engagements) > 0 do
      avg_engagement = Enum.sum(recent_engagements) / length(recent_engagements)

      cond do
        avg_engagement >= 60 -> :improving
        avg_engagement >= 40 -> :stable
        true -> :declining
      end
    else
      :stable
    end
  end

  defp format_burnout_analysis(member_analyses) do
    high_burnout_risk = Enum.count(member_analyses, &(&1.burnout_risk > 0.7))

    moderate_burnout_risk =
      Enum.count(member_analyses, &(&1.burnout_risk > 0.4 and &1.burnout_risk <= 0.7))

    %{
      high_risk_count: high_burnout_risk,
      moderate_risk_count: moderate_burnout_risk,
      total_at_risk: high_burnout_risk + moderate_burnout_risk,
      average_burnout_risk: calculate_average_burnout_risk(member_analyses)
    }
  end

  defp format_retention_analysis(member_analyses) do
    likely_to_leave = Enum.count(member_analyses, &(&1.retention_risk > 0.8))
    at_retention_risk = Enum.count(member_analyses, &(&1.retention_risk > 0.5))

    %{
      likely_departures: likely_to_leave,
      retention_concerns: at_retention_risk,
      retention_strategies_needed: likely_to_leave > 0
    }
  end

  defp identify_leadership_gaps(member_analyses) do
    potential_leaders = Enum.count(member_analyses, &(&1.leadership_potential > 0.7))
    current_leaders = Enum.count(member_analyses, &(&1.current_leadership_role == true))

    %{
      potential_leaders_available: potential_leaders,
      current_leaders: current_leaders,
      leadership_development_needed: potential_leaders < 3,
      succession_planning_required: current_leaders < 2
    }
  end

  defp calculate_participation_trend(member_analyses) do
    trends = Enum.map(member_analyses, &(&1.participation_trend || 0))

    if length(trends) > 0 do
      avg_trend = Enum.sum(trends) / length(trends)

      cond do
        avg_trend > 0.1 -> :increasing
        avg_trend < -0.1 -> :decreasing
        true -> :stable
      end
    else
      :stable
    end
  end

  defp identify_seasonal_patterns(_member_analyses) do
    # Placeholder for seasonal pattern analysis
    %{
      summer_activity: :normal,
      winter_activity: :normal,
      weekend_patterns: :normal
    }
  end

  defp identify_peak_periods(_member_analyses) do
    # Placeholder for peak period identification
    %{
      peak_hours: ["19:00", "20:00", "21:00"],
      peak_days: ["Saturday", "Sunday"],
      optimal_operation_times: ["Weekend evenings"]
    }
  end

  defp calculate_average_burnout_risk(member_analyses) do
    if length(member_analyses) > 0 do
      total_risk = Enum.sum(Enum.map(member_analyses, &(&1.burnout_risk || 0)))
      Float.round(total_risk / length(member_analyses), 3)
    else
      0.0
    end
  end
end
