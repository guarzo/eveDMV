defmodule EveDmv.Intelligence.Analyzers.MemberActivityPatternAnalyzer.TrendAnalyzer do
  alias EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer.ActivityHelpers

  require Logger
  @moduledoc """
  Specialized analyzer for activity trend analysis.

  This module focuses on identifying trends, seasonal variations,
  and behavioral changes in member activity over time.
  """


  @doc """
  Analyze activity trends over time for member activities.

  Examines activity patterns to identify trends, seasonal variations,
  and behavioral changes over time.

  ## Parameters
  - `member_activities` - List of member activity records
  - `days` - Number of days to analyze

  ## Returns
  - Map containing trend analysis results

  ## Examples
      iex> analyze_activity_trends(member_activities, 30)
      %{trend_direction: :increasing, growth_rate: 15.3, activity_peaks: [5, 12]}
  """
  def analyze_activity_trends(member_activities, days)
      when is_list(member_activities) and is_integer(days) do
    if Enum.empty?(member_activities) or days <= 0 do
      create_empty_trend_result()
    else
      activity_series = extract_activity_series(member_activities, days)

      if length(activity_series) >= 2 do
        perform_advanced_trend_analysis(activity_series, member_activities, days)
      else
        perform_simple_trend_analysis(member_activities, days)
      end
    end
  end

  def analyze_activity_trends(_, _), do: create_empty_trend_result()

  @doc """
  Calculate trend direction from activity data series.

  Analyzes activity data to determine if the trend is increasing,
  decreasing, stable, or volatile.

  ## Parameters
  - `activity_data` - List of activity values over time

  ## Returns
  - Atom representing trend direction (:increasing, :decreasing, :stable, :volatile)

  ## Examples
      iex> calculate_trend_direction([10, 12, 15, 18, 20])
      :increasing

      iex> calculate_trend_direction([20, 18, 15, 12, 10])
      :decreasing
  """
  def calculate_trend_direction(activity_data) when is_list(activity_data) do
    if length(activity_data) < 2 do
      :stable
    else
      # Calculate variance to determine volatility first
      mean = Enum.sum(activity_data) / length(activity_data)

      variance =
        Enum.sum(Enum.map(activity_data, fn x -> :math.pow(x - mean, 2) end)) /
          length(activity_data)

      std_deviation = :math.sqrt(variance)

      # Check for volatility first - high variance relative to mean
      if std_deviation > mean * 0.6 and mean > 0 do
        :volatile
      else
        # Calculate overall trend (first vs last half)
        mid_point = div(length(activity_data), 2)
        first_half = Enum.take(activity_data, mid_point)
        second_half = Enum.drop(activity_data, mid_point)

        first_avg =
          if length(first_half) > 0, do: Enum.sum(first_half) / length(first_half), else: 0

        second_avg =
          if length(second_half) > 0, do: Enum.sum(second_half) / length(second_half), else: 0

        change_percent = if first_avg > 0, do: (second_avg - first_avg) / first_avg * 100, else: 0

        cond do
          change_percent > 10 -> :increasing
          change_percent < -10 -> :decreasing
          true -> :stable
        end
      end
    end
  end

  def calculate_trend_direction(_), do: :stable

  @doc """
  Calculate days since last activity for a member.

  Determines how many days have passed since the member's last recorded activity.
  Useful for identifying inactive members and calculating engagement metrics.

  ## Parameters
  - `last_activity` - DateTime of last activity (or nil if no activity)
  - `current_time` - Current DateTime to compare against

  ## Returns
  - Integer number of days since last activity (999 if no activity recorded)

  ## Examples
      iex> days_since_last_activity(~U[2023-01-01 00:00:00Z], ~U[2023-01-15 00:00:00Z])
      14

      iex> days_since_last_activity(nil, ~U[2023-01-15 00:00:00Z])
      999
  """
  def days_since_last_activity(last_activity, current_time) do
    if last_activity do
      DateTime.diff(current_time, last_activity, :day)
    else
      # Very old if no activity recorded
      999
    end
  end

  @doc """
  Analyze trend patterns from activity data.
  """
  def analyze_trend_patterns(activity_data) do
    # Analyze trend patterns from activity data
    hourly_activity = Map.get(activity_data, :hourly_activity, %{})
    daily_activity = Map.get(activity_data, :daily_activity, %{})

    trend_analysis = %{
      hourly_trends: analyze_hourly_trends(hourly_activity),
      daily_trends: analyze_daily_trends(daily_activity),
      activity_regularity: calculate_activity_regularity(hourly_activity, daily_activity)
    }

    {:ok, trend_analysis}
  end

  # Private helper functions

  defp create_empty_trend_result do
    %{
      trend_direction: :stable,
      trend_strength: 0.0,
      activity_change_percent: 0.0,
      growth_rate: 0.0,
      member_count: 0
    }
  end

  defp perform_advanced_trend_analysis(activity_series, member_activities, days) do
    {trend_direction, growth_rate} = calculate_trend_from_series(activity_series)
    activity_peaks = ActivityHelpers.identify_activity_peaks(activity_series)
    seasonal_patterns = analyze_seasonal_patterns(member_activities, days)

    %{
      trend_direction: trend_direction,
      growth_rate: Float.round(growth_rate, 2),
      activity_peaks: activity_peaks,
      seasonal_patterns: seasonal_patterns
    }
  end

  defp perform_simple_trend_analysis(member_activities, days) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days, :day)
    recent_activities = filter_recent_activities(member_activities, cutoff_date)

    activity_metrics = calculate_activity_metrics(member_activities, recent_activities)

    {trend_direction, trend_strength} =
      determine_trend_direction(activity_metrics.activity_change_percent)

    %{
      trend_direction: trend_direction,
      trend_strength: Float.round(abs(trend_strength), 2),
      activity_change_percent: Float.round(activity_metrics.activity_change_percent, 1),
      growth_rate: Float.round(activity_metrics.activity_change_percent, 2),
      member_count: length(member_activities)
    }
  end

  defp calculate_activity_metrics(member_activities, recent_activities) do
    total_recent_activity =
      Enum.sum(Enum.map(recent_activities, &Map.get(&1, :killmail_count, 0)))

    total_historical_activity =
      Enum.sum(Enum.map(member_activities, &Map.get(&1, :killmail_count, 0)))

    activity_change_percent =
      calculate_activity_change_percent(
        total_recent_activity,
        recent_activities,
        total_historical_activity,
        member_activities
      )

    %{
      total_recent_activity: total_recent_activity,
      total_historical_activity: total_historical_activity,
      activity_change_percent: activity_change_percent
    }
  end

  defp determine_trend_direction(activity_change_percent) do
    cond do
      activity_change_percent > 20 -> {:increasing, activity_change_percent}
      activity_change_percent < -20 -> {:decreasing, activity_change_percent}
      abs(activity_change_percent) > 10 -> {:volatile, activity_change_percent}
      true -> {:stable, activity_change_percent}
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

    {trend_direction, growth_rate}
  end

  defp analyze_seasonal_patterns(member_activities, _days) do
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

  defp determine_season(month) do
    case month do
      m when m in [3, 4, 5] -> "spring"
      m when m in [6, 7, 8] -> "summer"
      m when m in [9, 10, 11] -> "fall"
      _ -> "winter"
    end
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

  defp analyze_hourly_trends(hourly_activity) do
    if map_size(hourly_activity) > 0 do
      values = Map.values(hourly_activity)

      %{
        peak_hours: identify_peak_hours(hourly_activity),
        activity_spread: calculate_activity_spread(values),
        variance: calculate_variance(values)
      }
    else
      %{peak_hours: [], activity_spread: 0.0, variance: 0.0}
    end
  end

  defp analyze_daily_trends(daily_activity) do
    if map_size(daily_activity) > 0 do
      values = Map.values(daily_activity)

      %{
        most_active_days: identify_most_active_days(daily_activity),
        activity_consistency: calculate_daily_consistency(values),
        trend_direction: calculate_trend_direction(values)
      }
    else
      %{most_active_days: [], activity_consistency: 0.0, trend_direction: :stable}
    end
  end

  defp calculate_activity_regularity(hourly_activity, daily_activity) do
    hourly_regularity =
      if map_size(hourly_activity) > 0,
        do: calculate_regularity(Map.values(hourly_activity)),
        else: 0.0

    daily_regularity =
      if map_size(daily_activity) > 0,
        do: calculate_regularity(Map.values(daily_activity)),
        else: 0.0

    (hourly_regularity + daily_regularity) / 2
  end

  defp identify_peak_hours(hourly_activity) do
    if map_size(hourly_activity) > 0 do
      avg_activity = Enum.sum(Map.values(hourly_activity)) / map_size(hourly_activity)

      Enum.filter(hourly_activity, fn {_hour, activity} -> activity > avg_activity * 1.2 end)
      |> Enum.map(fn {hour, _activity} -> hour end)
      |> Enum.sort()
    else
      []
    end
  end

  defp identify_most_active_days(daily_activity) do
    if map_size(daily_activity) > 0 do
      avg_activity = Enum.sum(Map.values(daily_activity)) / map_size(daily_activity)

      Enum.filter(daily_activity, fn {_day, activity} -> activity > avg_activity * 1.2 end)
      |> Enum.map(fn {day, _activity} -> day end)
      |> Enum.sort()
    else
      []
    end
  end

  defp calculate_activity_spread(values) do
    if length(values) > 0 do
      max_val = Enum.max(values)
      min_val = Enum.min(values)
      if max_val > 0, do: (max_val - min_val) / max_val, else: 0.0
    else
      0.0
    end
  end

  defp calculate_variance(values) do
    if length(values) > 0 do
      mean = Enum.sum(values) / length(values)
      Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end)) / length(values)
    else
      0.0
    end
  end

  defp calculate_daily_consistency(values) do
    if length(values) > 1 do
      variance = calculate_variance(values)
      mean = Enum.sum(values) / length(values)
      if mean > 0, do: 1.0 - variance / (mean * mean), else: 0.0
    else
      0.0
    end
  end

  defp calculate_regularity(values) do
    if length(values) > 1 do
      variance = calculate_variance(values)
      mean = Enum.sum(values) / length(values)
      if mean > 0, do: max(0.0, 1.0 - variance / (mean * mean)), else: 0.0
    else
      0.0
    end
  end
end
