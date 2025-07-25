defmodule EveDmv.Intelligence.EngagementCalculator do
  @moduledoc """
  Member engagement scoring and calculation utilities extracted from member_activity_analyzer.ex

  This module consolidates all engagement calculation logic into reusable functions
  that can be used across different intelligence analysis modules.
  """

  @doc """
  Calculate overall engagement score from member data.

  This is the primary function that combines different engagement factors
  into a single score from 0-100.
  """
  def calculate_overall_score(member_data) do
    killmail_score = calculate_killmail_engagement(member_data)
    participation_score = calculate_fleet_engagement(member_data)
    communication_score = calculate_communication_engagement(member_data)

    # Weight the different components
    # Killmail activity: 50%
    # Fleet participation: 35%
    # Communication: 15%
    weighted_score =
      killmail_score * 0.5 + participation_score * 0.35 + communication_score * 0.15

    min(100, max(0, round(weighted_score)))
  end

  @doc """
  Calculate engagement score based on killmail activity.

  Considers kills, losses, and kill/death ratio.
  Returns a score from 0-100.
  """
  def calculate_killmail_engagement(member_data) do
    kills = Map.get(member_data, :total_kills, 0)
    losses = Map.get(member_data, :total_losses, 0)
    total_activity = kills + losses

    # Base score from total activity (max 60 points)
    base_score = min(total_activity * 1.5, 60)

    # Bonus for good kill/death ratio (max 40 points)
    kd_bonus = calculate_kd_bonus(kills, losses)

    round(base_score + kd_bonus)
  end

  @doc """
  Calculate engagement score based on fleet participation.

  Considers different types of fleet operations with appropriate weights.
  Returns a score from 0-100.
  """
  def calculate_fleet_engagement(member_data) do
    home_defense = Map.get(member_data, :home_defense_participations, 0)
    chain_ops = Map.get(member_data, :chain_operations_participations, 0)
    fleet_ops = Map.get(member_data, :fleet_participations, 0)

    # Weight different types of participation
    # Home defense is most valuable (3x weight)
    # Chain operations are important (2x weight)
    # Regular fleet ops have base weight
    weighted_participation = home_defense * 3 + chain_ops * 2 + fleet_ops

    # Convert to 0-100 score with diminishing returns
    min(weighted_participation * 2.5, 100)
  end

  @doc """
  Calculate engagement score based on communication activity.

  This is a placeholder for future communication metrics.
  Returns a score from 0-100.
  """
  def calculate_communication_engagement(member_data) do
    # Placeholder implementation for communication scoring
    # In the future, this could include:
    # - Discord activity
    # - In-game chat participation
    # - Forum contributions
    # - Voice comms participation

    communication_activity = Map.get(member_data, :communication_activity, 0)
    min(communication_activity * 10, 100)
  end

  @doc """
  Calculate average engagement across multiple member analyses.

  Takes a list of member analysis records and returns the average engagement score.
  """
  def calculate_average_engagement(member_analyses) when is_list(member_analyses) do
    if length(member_analyses) > 0 do
      total_engagement =
        member_analyses
        |> Enum.map(&Map.get(&1, :engagement_score, 0))
        |> Enum.sum()

      total_engagement / length(member_analyses)
    else
      0.0
    end
  end

  @doc """
  Count active members based on engagement threshold.

  Returns the number of members with engagement scores above the threshold (default: 30).
  """
  def count_active_members(member_analyses, threshold \\ 30) when is_list(member_analyses) do
    Enum.count(member_analyses, fn analysis ->
      Map.get(analysis, :engagement_score, 0) > threshold
    end)
  end

  @doc """
  Calculate percentage of at-risk members.

  Members are considered at-risk if their burnout or disengagement score exceeds 50.
  """
  def calculate_at_risk_percentage(member_analyses) when is_list(member_analyses) do
    if length(member_analyses) > 0 do
      at_risk_count =
        Enum.count(member_analyses, fn analysis ->
          burnout_risk = Map.get(analysis, :burnout_risk_score, 0)
          disengagement_risk = Map.get(analysis, :disengagement_risk_score, 0)
          max(burnout_risk, disengagement_risk) > 50
        end)

      at_risk_count / length(member_analyses) * 100
    else
      0.0
    end
  end

  @doc """
  Calculate percentage of high-performing members.

  High performers are defined as members with engagement scores above 75.
  """
  def calculate_high_performers_percentage(member_analyses, threshold \\ 75)
      when is_list(member_analyses) do
    if length(member_analyses) > 0 do
      high_performer_count =
        Enum.count(member_analyses, fn analysis ->
          Map.get(analysis, :engagement_score, 0) > threshold
        end)

      high_performer_count / length(member_analyses) * 100
    else
      0.0
    end
  end

  # Private helper functions

  defp calculate_kd_bonus(kills, losses) do
    cond do
      losses == 0 and kills > 0 ->
        # Perfect K/D ratio bonus
        min(kills * 2, 40)

      losses > 0 ->
        ratio = kills / losses
        # Scale ratio to 0-40 points
        min(ratio * 15, 40)

      true ->
        # No activity
        0
    end
  end
end
