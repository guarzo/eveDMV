defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.ActivityHelpers do
  @moduledoc """
  Helper functions for member activity calculations and analysis.

  Provides utility functions for fleet participation metrics, communication patterns,
  and general activity calculations used across the member activity analyzer.
  """

  alias EveDmv.Intelligence.Analyzers.CommunicationPatternAnalyzer
  alias EveDmv.Intelligence.Calculators.FleetParticipationCalculator
  alias EveDmv.Intelligence.MemberActivityIntelligence
  alias EveDmv.Utils.TimeUtils
  require Logger

  # Helper functions to safely create field atoms
  defp opportunities_field(:fleet), do: :fleet_opportunities
  defp opportunities_field(:home_defense), do: :home_defense_opportunities
  defp opportunities_field(:strategic), do: :strategic_opportunities

  defp participated_field(:fleet), do: :fleet_participated
  defp participated_field(:home_defense), do: :home_defense_participated
  defp participated_field(:strategic), do: :strategic_participated

  @doc """
  Calculate fleet participation metrics for given fleet data.

  Analyzes fleet participation patterns including frequency, consistency,
  and role distribution.
  """
  def calculate_fleet_participation_metrics(fleet_data) when is_list(fleet_data) do
    FleetParticipationCalculator.calculate_metrics(fleet_data)
  end

  @doc """
  Analyze communication patterns from communication data.

  Examines Discord, forum, and in-game communication patterns
  to assess member engagement and social integration.
  """
  def analyze_communication_patterns(communication_data) do
    CommunicationPatternAnalyzer.analyze_communication_patterns(communication_data)
  end

  @doc """
  Get the latest analysis record for a character.
  """
  def get_latest_analysis(character_id) do
    case MemberActivityIntelligence.get_by_character(character_id) do
      {:ok, analysis} -> {:ok, analysis}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Record new member activity and update analysis.
  """
  def record_member_activity(character_id, activity_type, activity_data \\ %{}) do
    case get_latest_analysis(character_id) do
      {:ok, analysis} ->
        MemberActivityIntelligence.record_activity(analysis, activity_type, activity_data)

      {:error, reason} ->
        Logger.info(
          "No existing analysis found for character #{character_id}, creating new analysis: #{inspect(reason)}"
        )

        # Create analysis for the last 30 days
        end_date = DateTime.utc_now()
        start_date = DateTime.add(end_date, -30, :day)

        # This would typically call back to the main analyzer
        # but we avoid circular dependencies by returning an instruction
        {:create_analysis_needed,
         %{
           character_id: character_id,
           start_date: start_date,
           end_date: end_date
         }}
    end
  end

  @doc """
  Calculate member activity score based on various metrics.

  Combines kill/loss data, recent activity, and participation metrics
  into a single activity score.
  """
  def calculate_member_activity_score(member) do
    # Calculate activity score based on kills, losses, and recent activity
    total_activity = (member.total_kills || 0) + (member.total_losses || 0)
    base_score = min(80, total_activity * 2)

    # Recent activity bonus
    recent_bonus =
      case member.last_killmail_date do
        nil ->
          0

        last_date ->
          days_ago = TimeUtils.days_since(last_date)
          max(0, 20 - days_ago)
      end

    min(100, base_score + recent_bonus)
  end

  @doc """
  Extract activity time series data from member activities.

  Converts member activity records into a time series format
  suitable for trend analysis.
  """
  def extract_activity_series(member_activities, _days) do
    # Extract activity history from member data
    Enum.flat_map(member_activities, fn member ->
      activity_history = Map.get(member, :activity_history, [])

      Enum.map(activity_history, fn day_data ->
        Map.get(day_data, :killmails, 0) + Map.get(day_data, :fleet_ops, 0)
      end)
    end)
  end

  @doc """
  Filter activities by date range.
  """
  def filter_recent_activities(member_activities, cutoff_date) do
    Enum.filter(member_activities, fn member ->
      case Map.get(member, :last_seen) do
        nil -> false
        last_seen -> DateTime.compare(last_seen, cutoff_date) != :lt
      end
    end)
  end

  @doc """
  Calculate activity change percentage between periods.
  """
  def calculate_activity_change_percent(
        total_recent_activity,
        recent_activities,
        total_historical_activity,
        member_activities
      ) do
    if total_historical_activity > 0 do
      (total_recent_activity / max(1, length(recent_activities)) -
         total_historical_activity / max(1, length(member_activities))) /
        (total_historical_activity / max(1, length(member_activities))) * 100
    else
      0.0
    end
  end

  @doc """
  Determine the current season based on month.
  """
  def determine_season(month) do
    case month do
      m when m in [3, 4, 5] -> "spring"
      m when m in [6, 7, 8] -> "summer"
      m when m in [9, 10, 11] -> "fall"
      _ -> "winter"
    end
  end

  @doc """
  Calculate simple trend from activity series data.
  """
  def calculate_trend_from_series(activity_series) do
    # Simple trend calculation: compare first half vs second half
    mid_point = div(length(activity_series), 2)
    first_half = Enum.take(activity_series, mid_point)
    second_half = Enum.drop(activity_series, mid_point)

    first_avg = if length(first_half) > 0, do: Enum.sum(first_half) / length(first_half), else: 0

    second_avg =
      if length(second_half) > 0, do: Enum.sum(second_half) / length(second_half), else: 0

    growth_rate = if first_avg > 0, do: (second_avg - first_avg) / first_avg * 100, else: 0

    trend_direction =
      cond do
        growth_rate > 20 -> :increasing
        growth_rate < -20 -> :decreasing
        true -> :stable
      end

    {trend_direction, growth_rate}
  end

  @doc """
  Identify activity peaks in a time series.
  """
  def identify_activity_peaks(activity_series) do
    # Simple peak detection - find values above average
    if length(activity_series) > 2 do
      avg = Enum.sum(activity_series) / length(activity_series)

      activity_series
      |> Enum.with_index()
      |> Enum.filter(fn {value, _index} -> value > avg * 1.2 end)
      |> Enum.map(fn {_value, index} -> index end)
    else
      []
    end
  end

  @doc """
  Create empty engagement result structure.
  """
  def create_empty_engagement_result do
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

  @doc """
  Create empty trend result structure.
  """
  def create_empty_trend_result do
    %{
      trend_direction: :insufficient_data,
      activity_change_percent: 0.0,
      activity_peaks: [],
      seasonal_patterns: %{},
      trend_confidence: 0.0,
      prediction: %{
        next_7_days: :uncertain,
        confidence: 0.0
      }
    }
  end

  @doc """
  Build activity patterns from raw activity data.
  """
  def build_activity_patterns(activity_data) do
    %{
      daily_average: calculate_daily_average(activity_data),
      weekly_pattern: analyze_weekly_pattern(activity_data),
      peak_hours: identify_peak_hours(activity_data),
      consistency_score: calculate_consistency_score(activity_data)
    }
  end

  @doc """
  Build participation metrics from participation data.
  """
  def build_participation_metrics(participation_data) do
    %{
      fleet_participation_rate: calculate_participation_rate(participation_data, :fleet),
      home_defense_rate: calculate_participation_rate(participation_data, :home_defense),
      strategic_op_rate: calculate_participation_rate(participation_data, :strategic),
      overall_participation: calculate_overall_participation(participation_data)
    }
  end

  # Private helper functions

  defp calculate_daily_average(activity_data) do
    total_days = Map.get(activity_data, :period_days, 30)
    total_activity = Map.get(activity_data, :total_activity, 0)

    if total_days > 0 do
      Float.round(total_activity / total_days, 2)
    else
      0.0
    end
  end

  defp analyze_weekly_pattern(activity_data) do
    # Simplified weekly pattern analysis
    Map.get(activity_data, :weekly_pattern, %{
      most_active_day: "Unknown",
      least_active_day: "Unknown",
      weekend_activity: 0.0,
      weekday_activity: 0.0
    })
  end

  defp identify_peak_hours(activity_data) do
    # Return peak activity hours
    Map.get(activity_data, :peak_hours, [])
  end

  defp calculate_consistency_score(activity_data) do
    # Calculate how consistent the member's activity is
    variance = Map.get(activity_data, :activity_variance, 0)

    # Lower variance = higher consistency
    if variance > 0 do
      min(100, 100 / (1 + variance))
    else
      100.0
    end
  end

  defp calculate_participation_rate(participation_data, type) do
    opportunities = Map.get(participation_data, opportunities_field(type), 0)
    participated = Map.get(participation_data, participated_field(type), 0)

    if opportunities > 0 do
      Float.round(participated / opportunities * 100, 1)
    else
      0.0
    end
  end

  defp calculate_overall_participation(participation_data) do
    total_opportunities =
      Map.get(participation_data, :fleet_opportunities, 0) +
        Map.get(participation_data, :home_defense_opportunities, 0) +
        Map.get(participation_data, :strategic_opportunities, 0)

    total_participated =
      Map.get(participation_data, :fleet_participated, 0) +
        Map.get(participation_data, :home_defense_participated, 0) +
        Map.get(participation_data, :strategic_participated, 0)

    if total_opportunities > 0 do
      Float.round(total_participated / total_opportunities * 100, 1)
    else
      0.0
    end
  end
end
