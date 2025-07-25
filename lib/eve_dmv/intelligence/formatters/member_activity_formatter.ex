defmodule EveDmv.Intelligence.Formatters.MemberActivityFormatter do
  @moduledoc """
  Formatting utilities for member activity analysis data.

  Provides functions to format and summarize member activity analysis results
  for display in reports and dashboards.
  """

  @doc """
  Generate a risk summary from member analyses.
  """
  def generate_risk_summary(member_analyses) when is_list(member_analyses) do
    total_members = length(member_analyses)

    if total_members == 0 do
      %{
        total_members: 0,
        high_risk_members: 0,
        medium_risk_members: 0,
        low_risk_members: 0,
        risk_percentage: 0.0,
        overall_risk_level: :unknown
      }
    else
      high_risk = Enum.count(member_analyses, &(Map.get(&1, :risk_level, :low) == :high))
      medium_risk = Enum.count(member_analyses, &(Map.get(&1, :risk_level, :low) == :medium))
      low_risk = total_members - high_risk - medium_risk

      risk_percentage = (high_risk + medium_risk) / total_members * 100

      overall_risk_level =
        cond do
          risk_percentage > 30 -> :high
          risk_percentage > 15 -> :medium
          true -> :low
        end

      %{
        total_members: total_members,
        high_risk_members: high_risk,
        medium_risk_members: medium_risk,
        low_risk_members: low_risk,
        risk_percentage: Float.round(risk_percentage, 1),
        overall_risk_level: overall_risk_level
      }
    end
  end

  @doc """
  Calculate engagement metrics from member analyses.
  """
  def calculate_engagement_metrics(member_analyses) when is_list(member_analyses) do
    if Enum.empty?(member_analyses) do
      %{
        average_activity_score: 0.0,
        total_active_members: 0,
        inactive_members: 0,
        engagement_rate: 0.0,
        activity_trend: :stable
      }
    else
      activity_scores = Enum.map(member_analyses, &Map.get(&1, :activity_score, 0))
      average_activity = Enum.sum(activity_scores) / length(activity_scores)

      active_members = Enum.count(member_analyses, &(Map.get(&1, :activity_score, 0) > 50))
      inactive_members = length(member_analyses) - active_members
      engagement_rate = active_members / length(member_analyses) * 100

      %{
        average_activity_score: Float.round(average_activity, 1),
        total_active_members: active_members,
        inactive_members: inactive_members,
        engagement_rate: Float.round(engagement_rate, 1),
        activity_trend: determine_activity_trend(member_analyses)
      }
    end
  end

  @doc """
  Generate leadership recommendations based on member analyses.
  """
  def generate_leadership_recommendations(member_analyses) when is_list(member_analyses) do
    initial_recommendations = []

    high_risk_count = Enum.count(member_analyses, &(Map.get(&1, :risk_level, :low) == :high))
    inactive_count = Enum.count(member_analyses, &(Map.get(&1, :activity_score, 0) < 20))

    recommendations_with_risk =
      if high_risk_count > 0 do
        [
          "Review #{high_risk_count} high-risk member(s) for potential security concerns"
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    recommendations_with_inactive =
      if inactive_count > length(member_analyses) * 0.3 do
        [
          "Consider member engagement initiatives - #{inactive_count} inactive members detected"
          | recommendations_with_risk
        ]
      else
        recommendations_with_risk
      end

    final_recommendations =
      if Enum.empty?(recommendations_with_inactive) do
        ["Corporation member activity levels are within normal parameters"]
      else
        recommendations_with_inactive
      end

    final_recommendations
  end

  @doc """
  Format member summaries for display.
  """
  def format_member_summaries(member_analyses) when is_list(member_analyses) do
    Enum.map(member_analyses, fn member ->
      %{
        character_id: Map.get(member, :character_id, 0),
        character_name: Map.get(member, :character_name, "Unknown"),
        activity_score: Map.get(member, :activity_score, 0),
        risk_level: Map.get(member, :risk_level, :low),
        last_activity: Map.get(member, :last_activity, DateTime.utc_now()),
        summary: format_member_summary(member)
      }
    end)
  end

  @doc """
  Determine the primary concern for a member.
  """
  def determine_primary_concern(member) when is_map(member) do
    risk_level = Map.get(member, :risk_level, :low)
    activity_score = Map.get(member, :activity_score, 0)

    cond do
      risk_level == :high -> "security_risk"
      activity_score < 20 -> "low_activity"
      activity_score < 40 -> "declining_engagement"
      true -> "none"
    end
  end

  @doc """
  Recommend leadership action for a member.
  """
  def recommend_leadership_action(member) when is_map(member) do
    primary_concern = determine_primary_concern(member)

    case primary_concern do
      "security_risk" -> "immediate_review"
      "low_activity" -> "engagement_outreach"
      "declining_engagement" -> "check_in_recommended"
      "none" -> "monitor"
    end
  end

  # Private helper functions

  defp determine_activity_trend(member_analyses) do
    # Simplified trend analysis - could be enhanced with historical data
    avg_activity =
      member_analyses
      |> Enum.map(&Map.get(&1, :activity_score, 0))
      |> Enum.sum()
      |> Kernel./(length(member_analyses))

    cond do
      avg_activity > 70 -> :increasing
      avg_activity < 30 -> :declining
      true -> :stable
    end
  end

  defp format_member_summary(member) do
    activity_score = Map.get(member, :activity_score, 0)
    risk_level = Map.get(member, :risk_level, :low)

    activity_desc =
      case activity_score do
        score when score > 80 -> "Very Active"
        score when score > 60 -> "Active"
        score when score > 40 -> "Moderate"
        score when score > 20 -> "Low Activity"
        _ -> "Inactive"
      end

    risk_desc =
      case risk_level do
        :high -> "High Risk"
        :medium -> "Medium Risk"
        :low -> "Low Risk"
      end

    "#{activity_desc}, #{risk_desc}"
  end
end
