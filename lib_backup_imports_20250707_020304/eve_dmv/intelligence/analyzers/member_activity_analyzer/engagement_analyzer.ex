defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.EngagementAnalyzer do
  require Logger
  @moduledoc """
  Engagement calculation and analysis module for member activity analyzer.

  Handles all engagement score calculations, engagement grouping,
  and engagement distribution analysis for EVE Online members.
  """


  @doc """
  Calculate engagement score for a member based on their activity data.

  The engagement score is calculated using multiple factors including
  kills, losses, fleet participation, and communication activity.
  """
  def calculate_engagement_score(member_data) when is_map(member_data) do
    # Extract relevant metrics
    pvp_score = calculate_pvp_engagement(member_data)
    fleet_score = calculate_fleet_engagement(member_data)
    communication_score = calculate_communication_engagement(member_data)
    consistency_score = calculate_consistency_score(member_data)

    # Weight the different components
    weighted_score =
      pvp_score * 0.4 +
        fleet_score * 0.3 +
        communication_score * 0.1 +
        consistency_score * 0.2

    # Normalize to 0-100 scale
    min(100, max(0, weighted_score))
  end

  @doc """
  Calculate engagement metrics for a list of member activities.

  Provides comprehensive engagement analysis including average scores,
  distribution, and member groupings.
  """
  def calculate_member_engagement(member_activities) when is_list(member_activities) do
    if member_activities == [] do
      create_empty_engagement_result()
    else
      member_engagement_data = calculate_individual_member_scores(member_activities)
      avg_engagement = calculate_average_engagement_score(member_engagement_data)
      grouped_members = group_members_by_engagement(member_engagement_data)
      distribution = create_engagement_distribution(grouped_members)

      build_engagement_result(avg_engagement, grouped_members, distribution)
    end
  end

  @doc """
  Calculate engagement score using specific PvP data.
  """
  def calculate_pvp_engagement(member_data) do
    kills = Map.get(member_data, :total_pvp_kills, 0)
    losses = Map.get(member_data, :total_pvp_losses, 0)

    # Activity level
    total_activity = kills + losses
    activity_score = min(50, total_activity * 2)

    # Kill/Death ratio bonus
    kd_ratio = if losses > 0, do: kills / losses, else: kills
    kd_bonus = min(25, kd_ratio * 10)

    # Solo activity bonus
    solo_kills = Map.get(member_data, :solo_kills, 0)
    solo_bonus = min(25, solo_kills * 5)

    activity_score + kd_bonus + solo_bonus
  end

  @doc """
  Calculate engagement score for fleet participation.
  """
  def calculate_fleet_engagement(member_data) do
    fleet_count = Map.get(member_data, :fleet_participations, 0)
    strategic_ops = Map.get(member_data, :strategic_op_participations, 0)
    home_defense = Map.get(member_data, :home_defense_participations, 0)

    # Base fleet score
    base_score = min(40, fleet_count * 3)

    # Strategic ops bonus
    strategic_bonus = min(30, strategic_ops * 10)

    # Home defense bonus
    defense_bonus = min(30, home_defense * 8)

    base_score + strategic_bonus + defense_bonus
  end

  @doc """
  Calculate engagement score for communication activity.
  """
  def calculate_communication_engagement(member_data) do
    discord_activity = Map.get(member_data, :discord_messages, 0)
    forum_activity = Map.get(member_data, :forum_posts, 0)

    # Communication score (capped at 100)
    discord_score = min(50, discord_activity * 2)
    forum_score = min(50, forum_activity * 5)

    discord_score + forum_score
  end

  @doc """
  Calculate consistency score based on activity patterns.
  """
  def calculate_consistency_score(member_data) do
    activity_patterns = Map.get(member_data, :activity_patterns, %{})

    # Check for consistent daily/weekly activity
    daily_consistency = Map.get(activity_patterns, :daily_consistency, 0)
    weekly_consistency = Map.get(activity_patterns, :weekly_consistency, 0)

    # Average the consistency metrics
    (daily_consistency + weekly_consistency) / 2
  end

  @doc """
  Group members by engagement level.
  """
  def group_members_by_engagement(member_engagement_data) do
    member_engagement_data
    |> Enum.group_by(fn {_member_id, score} ->
      classify_engagement_level(score)
    end)
    |> Enum.into(%{}, fn {level, members} ->
      {level,
       Enum.map(members, fn {member_id, score} ->
         %{member_id: member_id, score: score}
       end)}
    end)
  end

  @doc """
  Classify activity level based on activity score.
  """
  def classify_activity_level(activity_score) when is_number(activity_score) do
    cond do
      activity_score >= 80 -> :highly_active
      activity_score >= 60 -> :active
      activity_score >= 30 -> :moderate
      activity_score >= 10 -> :low
      true -> :inactive
    end
  end

  # Private helper functions

  defp create_empty_engagement_result do
    %{
      average_engagement: 0,
      total_members: 0,
      engagement_distribution: %{
        highly_engaged: 0,
        engaged: 0,
        moderate: 0,
        low_engagement: 0,
        disengaged: 0
      },
      grouped_members: %{}
    }
  end

  defp calculate_individual_member_scores(member_activities) do
    Enum.map(member_activities, fn member ->
      {member.character_id, calculate_engagement_score(member)}
    end)
  end

  defp calculate_average_engagement_score(member_engagement_data) do
    if length(member_engagement_data) > 0 do
      total = Enum.sum(Enum.map(member_engagement_data, fn {_id, score} -> score end))
      Float.round(total / length(member_engagement_data), 2)
    else
      0.0
    end
  end

  defp classify_engagement_level(score) do
    cond do
      score >= 80 -> :highly_engaged
      score >= 60 -> :engaged
      score >= 40 -> :moderate
      score >= 20 -> :low_engagement
      true -> :disengaged
    end
  end


  defp create_engagement_distribution(grouped_members) do
    %{
      highly_engaged: length(Map.get(grouped_members, :highly_engaged, [])),
      engaged: length(Map.get(grouped_members, :engaged, [])),
      moderate: length(Map.get(grouped_members, :moderate, [])),
      low_engagement: length(Map.get(grouped_members, :low_engagement, [])),
      disengaged: length(Map.get(grouped_members, :disengaged, []))
    }
  end

  defp build_engagement_result(avg_engagement, grouped_members, distribution) do
    total_members =
      Enum.sum(Enum.map(distribution, fn {_level, count} -> count end))

    %{
      average_engagement: avg_engagement,
      total_members: total_members,
      engagement_distribution: distribution,
      grouped_members: grouped_members,
      engagement_insights: generate_engagement_insights(distribution, total_members)
    }
  end

  defp generate_engagement_insights(distribution, total_members) do
    if total_members > 0 do
      highly_engaged_pct = distribution.highly_engaged / total_members * 100
      at_risk_pct = (distribution.low_engagement + distribution.disengaged) / total_members * 100

      %{
        highly_engaged_percentage: Float.round(highly_engaged_pct, 1),
        at_risk_percentage: Float.round(at_risk_pct, 1),
        health_status: determine_health_status(highly_engaged_pct, at_risk_pct)
      }
    else
      %{
        highly_engaged_percentage: 0.0,
        at_risk_percentage: 0.0,
        health_status: :no_data
      }
    end
  end

  defp determine_health_status(highly_engaged_pct, at_risk_pct) do
    cond do
      highly_engaged_pct > 40 and at_risk_pct < 20 -> :excellent
      highly_engaged_pct > 25 and at_risk_pct < 35 -> :good
      highly_engaged_pct > 15 and at_risk_pct < 50 -> :fair
      true -> :poor
    end
  end
end
