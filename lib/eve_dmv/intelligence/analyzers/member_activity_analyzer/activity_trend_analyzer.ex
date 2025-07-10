defmodule EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.ActivityTrendAnalyzer do
  @moduledoc """
  Activity trend analysis module for member activity analyzer.

  Analyzes activity patterns over time including trend detection,
  seasonal patterns, peak identification, and predictive insights.
  """

  alias EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.ActivityHelpers
  require Logger

  @doc """
  Analyze activity trends over a specified period.

  Provides comprehensive trend analysis including direction, volatility,
  seasonal patterns, and activity peaks.
  """
  def analyze_trends(member_activities, days) when is_list(member_activities) do
    {:ok, analyze_activity_trends(member_activities, days)}
  end

  def analyze_activity_trends(member_activities, days) when is_list(member_activities) do
    if Enum.empty?(member_activities) do
      create_empty_trend_result()
    else
      activity_series = extract_activity_series(member_activities, days)

      if length(activity_series) > 7 do
        perform_advanced_trend_analysis(activity_series, member_activities, days)
      else
        perform_simple_trend_analysis(member_activities, days)
      end
    end
  end

  @doc """
  Calculate trend direction from activity data.

  Determines if activity is increasing, decreasing, stable, or volatile.
  """
  def calculate_trend_direction(activity_data) when is_list(activity_data) do
    if length(activity_data) < 2 do
      {:stable, 0.0}
    else
      trend_info = calculate_trend_from_series(activity_data)
      {trend_info.direction, trend_info.change_percent}
    end
  end

  @doc """
  Determine trend direction based on activity change percentage.
  """
  def determine_trend_direction(activity_change_percent) do
    cond do
      activity_change_percent > 20 -> {:increasing, activity_change_percent}
      activity_change_percent < -20 -> {:decreasing, activity_change_percent}
      abs(activity_change_percent) > 10 -> {:volatile, activity_change_percent}
      true -> {:stable, activity_change_percent}
    end
  end

  @doc """
  Analyze seasonal patterns in member activities.
  """
  def analyze_seasonal_patterns(member_activities, _days) do
    # Basic seasonal pattern analysis
    current_month = DateTime.utc_now().month

    %{
      current_season: determine_season(current_month),
      activity_by_season: %{
        "spring" => Enum.count(member_activities) * 0.25,
        "summer" => Enum.count(member_activities) * 0.30,
        "fall" => Enum.count(member_activities) * 0.25,
        "winter" => Enum.count(member_activities) * 0.20
      }
    }
  end

  # Private helper functions

  defp create_empty_trend_result do
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

  defp perform_advanced_trend_analysis(activity_series, member_activities, days) do
    {_trend_direction, _growth_rate} = calculate_trend_from_series(activity_series)
    peaks = ActivityHelpers.identify_activity_peaks(activity_series)
    seasonal = analyze_seasonal_patterns(member_activities, days)

    # Recent activity analysis
    recent_cutoff = DateTime.add(DateTime.utc_now(), -7, :day)
    recent_activities = filter_recent_activities(member_activities, recent_cutoff)
    metrics = calculate_activity_metrics(member_activities, recent_activities)

    {trend, change_percent} = determine_trend_direction(metrics.activity_change_percent)

    %{
      trend_direction: trend,
      activity_change_percent: change_percent,
      activity_peaks: peaks,
      seasonal_patterns: seasonal,
      trend_confidence: calculate_trend_confidence(activity_series),
      volatility_score: calculate_volatility_score(activity_series),
      prediction: generate_activity_prediction(trend, change_percent, activity_series),
      detailed_metrics: metrics
    }
  end

  defp perform_simple_trend_analysis(member_activities, days) do
    # Simple analysis for limited data
    recent_cutoff = DateTime.add(DateTime.utc_now(), -7, :day)
    recent_activities = filter_recent_activities(member_activities, recent_cutoff)

    activity_change =
      if length(recent_activities) > 0 and length(member_activities) > 0 do
        (length(recent_activities) / min(7, days) -
           length(member_activities) / days) * 100
      else
        0.0
      end

    {trend, _} = determine_trend_direction(activity_change)

    %{
      trend_direction: trend,
      activity_change_percent: activity_change,
      activity_peaks: [],
      seasonal_patterns: %{},
      trend_confidence: 30.0,
      prediction: %{
        next_7_days: :insufficient_data,
        confidence: 0.0
      }
    }
  end

  defp calculate_activity_metrics(member_activities, recent_activities) do
    total_historical_activity =
      Enum.sum(
        Enum.map(member_activities, fn m ->
          Map.get(m, :total_activity, 0)
        end)
      )

    total_recent_activity =
      Enum.sum(
        Enum.map(recent_activities, fn m ->
          Map.get(m, :total_activity, 0)
        end)
      )

    avg_daily_historical =
      if length(member_activities) > 0 do
        total_historical_activity / length(member_activities)
      else
        0.0
      end

    avg_daily_recent =
      if length(recent_activities) > 0 do
        total_recent_activity / length(recent_activities)
      else
        0.0
      end

    activity_change_percent =
      calculate_activity_change_percent(
        total_recent_activity,
        recent_activities,
        total_historical_activity,
        member_activities
      )

    %{
      total_historical_activity: total_historical_activity,
      total_recent_activity: total_recent_activity,
      avg_daily_historical: Float.round(avg_daily_historical, 2),
      avg_daily_recent: Float.round(avg_daily_recent, 2),
      activity_change_percent: Float.round(activity_change_percent, 2)
    }
  end

  defp determine_season(month) do
    case month do
      m when m in [3, 4, 5] -> "spring"
      m when m in [6, 7, 8] -> "summer"
      m when m in [9, 10, 11] -> "fall"
      _ -> "winter"
    end
  end

  defp extract_activity_series(member_activities, _days) do
    # Extract activity history from member data
    Enum.flat_map(member_activities, fn member ->
      activity_history = Map.get(member, :activity_history, [])

      Enum.map(activity_history, fn day_data ->
        Map.get(day_data, :killmails, 0) + Map.get(day_data, :fleet_ops, 0)
      end)
    end)
  end

  defp calculate_trend_from_series(activity_series) do
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

    %{direction: trend_direction, change_percent: growth_rate}
  end

  defp filter_recent_activities(member_activities, cutoff_date) do
    Enum.filter(member_activities, fn member ->
      case Map.get(member, :last_seen) do
        nil -> false
        last_seen -> DateTime.compare(last_seen, cutoff_date) != :lt
      end
    end)
  end

  defp calculate_activity_change_percent(
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

  defp calculate_trend_confidence(activity_series) do
    # Confidence based on data volume and consistency
    data_points = length(activity_series)

    base_confidence = min(50, data_points * 2)

    # Add consistency bonus
    if data_points > 7 do
      variance = calculate_variance(activity_series)
      mean = Enum.sum(activity_series) / data_points
      cv = if mean > 0, do: variance / mean, else: 1.0

      consistency_bonus = max(0, 50 - cv * 100)
      min(100, base_confidence + consistency_bonus)
    else
      base_confidence
    end
  end

  defp calculate_volatility_score(activity_series) do
    if length(activity_series) > 2 do
      variance = calculate_variance(activity_series)
      mean = Enum.sum(activity_series) / length(activity_series)

      if mean > 0 do
        coefficient_of_variation = variance / mean
        min(100, coefficient_of_variation * 100)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_variance(series) do
    mean = Enum.sum(series) / length(series)

    squared_diffs =
      series
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()

    squared_diffs / length(series)
  end

  defp generate_activity_prediction(trend, change_percent, activity_series) do
    confidence = calculate_prediction_confidence(trend, activity_series)

    next_7_days_prediction =
      case trend do
        :increasing when change_percent > 30 -> :high_activity
        :increasing -> :moderate_increase
        :decreasing when change_percent < -30 -> :low_activity
        :decreasing -> :moderate_decrease
        :volatile -> :unpredictable
        _ -> :stable_activity
      end

    %{
      next_7_days: next_7_days_prediction,
      confidence: confidence,
      recommendation: generate_prediction_recommendation(next_7_days_prediction)
    }
  end

  defp calculate_prediction_confidence(trend, activity_series) do
    data_confidence = min(50, length(activity_series) * 3)

    trend_confidence =
      case trend do
        :stable -> 40
        :increasing -> 30
        :decreasing -> 30
        :volatile -> 10
        _ -> 20
      end

    min(100, data_confidence + trend_confidence)
  end

  defp generate_prediction_recommendation(prediction) do
    case prediction do
      :high_activity -> "Member showing strong engagement - consider for leadership roles"
      :moderate_increase -> "Positive trend - maintain current engagement strategies"
      :low_activity -> "Risk of disengagement - immediate intervention recommended"
      :moderate_decrease -> "Declining activity - schedule check-in with member"
      :unpredictable -> "Inconsistent patterns - monitor closely"
      :stable_activity -> "Consistent engagement - no action required"
      _ -> "Continue monitoring"
    end
  end
end
