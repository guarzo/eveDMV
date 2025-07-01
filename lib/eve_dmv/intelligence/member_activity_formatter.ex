defmodule EveDmv.Intelligence.MemberActivityFormatter do
  @moduledoc """
  Formatting and display utilities for member activity analysis.

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
    low_engagement_count = count_low_engagement_members(member_analyses)
    declining_trend_count = count_declining_members(member_analyses)

    recommendations = []

    recommendations =
      if high_risk_count > 0 do
        ["Immediate attention needed for #{high_risk_count} high-risk members" | recommendations]
      else
        recommendations
      end

    recommendations =
      if low_engagement_count > length(member_analyses) * 0.3 do
        [
          "Review engagement programs - #{low_engagement_count} members show low engagement"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if declining_trend_count > 0 do
        [
          "Monitor #{declining_trend_count} members showing declining activity trends"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if Enum.empty?(recommendations) do
        ["Member activity levels appear healthy across the corporation"]
      else
        recommendations
      end

    %{
      immediate_actions: filter_immediate_actions(recommendations),
      monitoring_suggestions: filter_monitoring_suggestions(recommendations),
      strategic_initiatives: generate_strategic_initiatives(member_analyses)
    }
  end

  @doc """
  Generate risk summary for corporation overview.
  """
  def generate_risk_summary(member_analyses) do
    total_members = length(member_analyses)

    risk_distribution = categorize_risk_levels(member_analyses)
    engagement_distribution = categorize_engagement_levels(member_analyses)

    %{
      total_members: total_members,
      high_risk_members: risk_distribution.high,
      medium_risk_members: risk_distribution.medium,
      low_risk_members: risk_distribution.low,
      high_engagement_members: engagement_distribution.high,
      medium_engagement_members: engagement_distribution.medium,
      low_engagement_members: engagement_distribution.low,
      overall_health_score: calculate_overall_health_score(member_analyses),
      trend_indicators: analyze_overall_trends(member_analyses)
    }
  end

  @doc """
  Calculate overall engagement metrics for corporation.
  """
  def calculate_engagement_metrics(member_analyses) do
    if Enum.empty?(member_analyses) do
      %{
        average_engagement: 0,
        median_engagement: 0,
        engagement_distribution: %{},
        participation_metrics: %{},
        activity_metrics: %{}
      }
    else
      engagement_scores = Enum.map(member_analyses, & &1.engagement_score)

      %{
        average_engagement: average(engagement_scores),
        median_engagement: median(engagement_scores),
        engagement_distribution: calculate_distribution_percentages(engagement_scores),
        participation_metrics: aggregate_participation_metrics(member_analyses),
        activity_metrics: aggregate_activity_metrics(member_analyses)
      }
    end
  end

  @doc """
  Determine primary concern for a member requiring attention.
  """
  def determine_primary_concern(member_analysis) do
    burnout_risk = member_analysis.burnout_risk_score || 0
    disengagement_risk = member_analysis.disengagement_risk_score || 0
    engagement_score = member_analysis.engagement_score || 50

    cond do
      burnout_risk > 60 -> "Burnout Risk"
      disengagement_risk > 60 -> "Disengagement Risk"
      engagement_score < 30 -> "Low Engagement"
      member_analysis.activity_trend[:direction] == :declining -> "Declining Activity"
      true -> "General Monitoring"
    end
  end

  @doc """
  Recommend specific leadership action for a member.
  """
  def recommend_leadership_action(member_analysis) do
    primary_concern = determine_primary_concern(member_analysis)

    case primary_concern do
      "Burnout Risk" ->
        "Schedule private conversation about workload and expectations"

      "Disengagement Risk" ->
        "Reach out to understand satisfaction and engagement barriers"

      "Low Engagement" ->
        "Invite to leadership activities and provide mentorship opportunities"

      "Declining Activity" ->
        "Check in on personal circumstances and corp satisfaction"

      _ ->
        "Regular check-in and continued monitoring"
    end
  end

  @doc """
  Format engagement status with color coding hints.
  """
  def format_engagement_status(engagement_score) when is_nil(engagement_score),
    do: %{status: "Unknown", color: "gray"}

  def format_engagement_status(engagement_score) do
    {status, color} =
      cond do
        engagement_score >= 80 -> {"Highly Engaged", "green"}
        engagement_score >= 60 -> {"Engaged", "blue"}
        engagement_score >= 40 -> {"Moderately Engaged", "yellow"}
        engagement_score >= 20 -> {"Low Engagement", "orange"}
        true -> {"Disengaged", "red"}
      end

    %{status: status, score: engagement_score, color: color}
  end

  @doc """
  Format overall risk level for a member.
  """
  def format_risk_level(member_analysis) do
    burnout_risk = member_analysis.burnout_risk_score || 0
    disengagement_risk = member_analysis.disengagement_risk_score || 0
    overall_risk = max(burnout_risk, disengagement_risk)

    {level, color} =
      cond do
        overall_risk >= 70 -> {"High Risk", "red"}
        overall_risk >= 50 -> {"Medium Risk", "yellow"}
        overall_risk >= 30 -> {"Low Risk", "blue"}
        true -> {"Minimal Risk", "green"}
      end

    %{level: level, score: overall_risk, color: color}
  end

  @doc """
  Format activity summary string.
  """
  def format_activity_summary(member_analysis) do
    kills = member_analysis.total_pvp_kills || 0
    losses = member_analysis.total_pvp_losses || 0
    fleet_ops = member_analysis.fleet_participations || 0

    "#{kills}K/#{losses}L, #{fleet_ops} fleet ops"
  end

  @doc """
  Format relative time (e.g., "2 days ago").
  """
  def format_relative_time(nil), do: "Unknown"

  def format_relative_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 3600 ->
        minutes = div(diff, 60)
        "#{minutes} minutes ago"

      diff when diff < 86_400 ->
        hours = div(diff, 3600)
        "#{hours} hours ago"

      diff when diff < 2_592_000 ->
        days = div(diff, 86_400)
        "#{days} days ago"

      _ ->
        "Over a month ago"
    end
  end

  @doc """
  Format trend direction with appropriate indicators.
  """
  def format_trend_direction(%{direction: direction, confidence: confidence}) do
    icon =
      case direction do
        :increasing -> "↗️"
        :declining -> "↘️"
        :stable -> "→"
        _ -> "?"
      end

    confidence_text =
      case confidence do
        :high -> "High Confidence"
        :medium -> "Medium Confidence"
        :low -> "Low Confidence"
        _ -> "Unknown"
      end

    "#{icon} #{String.capitalize(Atom.to_string(direction))} (#{confidence_text})"
  end

  @doc """
  Format warning indicators for display.
  """
  def format_warning_indicators(warning_indicators) when is_list(warning_indicators) do
    Enum.map(warning_indicators, fn indicator ->
      %{
        type: indicator.type,
        severity: indicator.severity,
        message: format_warning_message(indicator),
        action_required: indicator.action_required || false
      }
    end)
  end

  def format_warning_indicators(_), do: []

  # Helper functions

  defp requires_attention?(analysis) do
    (analysis.burnout_risk_score || 0) > 50 or
      (analysis.disengagement_risk_score || 0) > 50 or
      (analysis.engagement_score || 100) < 40
  end

  defp count_high_risk_members(analyses) do
    Enum.count(analyses, fn analysis ->
      max(analysis.burnout_risk_score || 0, analysis.disengagement_risk_score || 0) > 60
    end)
  end

  defp count_low_engagement_members(analyses) do
    Enum.count(analyses, fn analysis ->
      (analysis.engagement_score || 100) < 40
    end)
  end

  defp count_declining_members(analyses) do
    Enum.count(analyses, fn analysis ->
      trend = analysis.activity_trend || %{}
      trend[:direction] == :declining and trend[:confidence] in [:medium, :high]
    end)
  end

  defp filter_immediate_actions(recommendations) do
    Enum.filter(recommendations, fn rec ->
      String.contains?(String.downcase(rec), ["immediate", "urgent", "high-risk"])
    end)
  end

  defp filter_monitoring_suggestions(recommendations) do
    Enum.filter(recommendations, fn rec ->
      String.contains?(String.downcase(rec), ["monitor", "watch", "track"])
    end)
  end

  defp generate_strategic_initiatives(member_analyses) do
    initiatives = []

    low_engagement_ratio =
      count_low_engagement_members(member_analyses) / max(length(member_analyses), 1)

    high_risk_ratio = count_high_risk_members(member_analyses) / max(length(member_analyses), 1)

    initiatives =
      if low_engagement_ratio > 0.3 do
        ["Implement corp-wide engagement improvement program" | initiatives]
      else
        initiatives
      end

    initiatives =
      if high_risk_ratio > 0.2 do
        ["Develop burnout prevention and early intervention protocols" | initiatives]
      else
        initiatives
      end

    # Check for timezone isolation issues
    timezone_issues = analyze_timezone_distribution(member_analyses)

    initiatives =
      if timezone_issues.has_isolation_issues do
        ["Address timezone coverage gaps to improve member integration" | initiatives]
      else
        initiatives
      end

    if Enum.empty?(initiatives) do
      ["Maintain current engagement and monitoring practices"]
    else
      initiatives
    end
  end

  defp categorize_risk_levels(analyses) do
    Enum.reduce(analyses, %{high: 0, medium: 0, low: 0}, fn analysis, acc ->
      max_risk = max(analysis.burnout_risk_score || 0, analysis.disengagement_risk_score || 0)

      cond do
        max_risk >= 60 -> %{acc | high: acc.high + 1}
        max_risk >= 30 -> %{acc | medium: acc.medium + 1}
        true -> %{acc | low: acc.low + 1}
      end
    end)
  end

  defp categorize_engagement_levels(analyses) do
    Enum.reduce(analyses, %{high: 0, medium: 0, low: 0}, fn analysis, acc ->
      engagement = analysis.engagement_score || 0

      cond do
        engagement >= 70 -> %{acc | high: acc.high + 1}
        engagement >= 40 -> %{acc | medium: acc.medium + 1}
        true -> %{acc | low: acc.low + 1}
      end
    end)
  end

  defp calculate_overall_health_score(analyses) when analyses == [], do: 50

  defp calculate_overall_health_score(analyses) do
    engagement_scores = Enum.map(analyses, &(&1.engagement_score || 0))
    avg_engagement = average(engagement_scores)

    risk_scores =
      Enum.map(analyses, fn analysis ->
        max(analysis.burnout_risk_score || 0, analysis.disengagement_risk_score || 0)
      end)

    avg_risk = average(risk_scores)

    # Health score is engagement minus risk, normalized
    health_score = avg_engagement - avg_risk * 0.5
    max(0, min(100, round(health_score)))
  end

  defp analyze_overall_trends(analyses) do
    declining_count = count_declining_members(analyses)
    total_count = length(analyses)

    %{
      declining_members_ratio: if(total_count > 0, do: declining_count / total_count, else: 0),
      trend_confidence: calculate_trend_confidence(analyses),
      concerning_trends: declining_count > total_count * 0.2
    }
  end

  defp calculate_trend_confidence(analyses) do
    high_confidence_trends =
      Enum.count(analyses, fn analysis ->
        trend = analysis.activity_trend || %{}
        trend[:confidence] == :high
      end)

    if length(analyses) > 0 do
      high_confidence_trends / length(analyses)
    else
      0.0
    end
  end

  defp calculate_distribution_percentages(scores) do
    total = length(scores)

    if total == 0 do
      %{"0-20" => 0, "21-40" => 0, "41-60" => 0, "61-80" => 0, "81-100" => 0}
    else
      Enum.reduce(
        scores,
        %{"0-20" => 0, "21-40" => 0, "41-60" => 0, "61-80" => 0, "81-100" => 0},
        fn score, acc ->
          range =
            cond do
              score <= 20 -> "0-20"
              score <= 40 -> "21-40"
              score <= 60 -> "41-60"
              score <= 80 -> "61-80"
              true -> "81-100"
            end

          Map.update(acc, range, 1, &(&1 + 1))
        end
      )
      |> Enum.map(fn {range, count} -> {range, round(count / total * 100)} end)
      |> Map.new()
    end
  end

  defp aggregate_participation_metrics(analyses) do
    total_analyses = length(analyses)

    if total_analyses == 0 do
      %{avg_fleet_participation: 0, avg_home_defense: 0, avg_chain_ops: 0}
    else
      %{
        avg_fleet_participation: average(Enum.map(analyses, &(&1.fleet_participations || 0))),
        avg_home_defense: average(Enum.map(analyses, &(&1.home_defense_participations || 0))),
        avg_chain_ops: average(Enum.map(analyses, &(&1.chain_operations_participations || 0)))
      }
    end
  end

  defp aggregate_activity_metrics(analyses) do
    total_analyses = length(analyses)

    if total_analyses == 0 do
      %{avg_kills: 0, avg_losses: 0, avg_activity_score: 0}
    else
      %{
        avg_kills: average(Enum.map(analyses, &(&1.total_pvp_kills || 0))),
        avg_losses: average(Enum.map(analyses, &(&1.total_pvp_losses || 0))),
        avg_activity_score: average(Enum.map(analyses, &(&1.engagement_score || 0)))
      }
    end
  end

  defp analyze_timezone_distribution(analyses) do
    # Simplified timezone analysis
    timezone_data =
      Enum.reduce(analyses, %{}, fn analysis, acc ->
        tz = analysis.timezone_analysis[:primary_timezone] || "Unknown"
        Map.update(acc, tz, 1, &(&1 + 1))
      end)

    total_members = length(analyses)
    # Less than 15% in same timezone considered isolated
    isolation_threshold = 0.15

    isolated_timezones =
      Enum.filter(timezone_data, fn {_tz, count} ->
        count / total_members < isolation_threshold
      end)

    %{
      has_isolation_issues: length(isolated_timezones) > 0,
      timezone_distribution: timezone_data,
      isolated_timezone_count: length(isolated_timezones)
    }
  end

  defp format_warning_message(%{type: type, details: details}) do
    base_message =
      case type do
        :burnout_risk -> "Member showing signs of potential burnout"
        :disengagement_risk -> "Member showing declining engagement"
        :activity_decline -> "Member activity declining significantly"
        :participation_drop -> "Member participation in corp activities dropping"
        :timezone_isolation -> "Member in isolated timezone"
        _ -> "Member requires attention"
      end

    if details && String.length(details) > 0 do
      "#{base_message}: #{details}"
    else
      base_message
    end
  end

  defp average([]), do: 0
  defp average(list), do: Enum.sum(list) / length(list)

  defp median([]), do: 0

  defp median(list) do
    sorted = Enum.sort(list)
    length = length(sorted)

    if rem(length, 2) == 0 do
      # Even number of elements
      mid1 = Enum.at(sorted, div(length, 2) - 1)
      mid2 = Enum.at(sorted, div(length, 2))
      (mid1 + mid2) / 2
    else
      # Odd number of elements
      Enum.at(sorted, div(length, 2))
    end
  end
end
