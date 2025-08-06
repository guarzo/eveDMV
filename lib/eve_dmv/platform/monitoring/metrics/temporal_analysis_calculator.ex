defmodule EveDmv.Intelligence.Metrics.TemporalAnalysisCalculator do
  @moduledoc """
  Temporal analysis calculator for character activity patterns.

  This module provides time-based analysis including hourly, daily,
  and weekly activity patterns, peak identification, and timezone estimation.
  """

  @doc """
  Calculate temporal activity patterns from killmail data.

  Returns comprehensive temporal analysis including activity patterns,
  peak hours, consistency metrics, and timezone estimation.
  """
  def calculate_temporal_patterns(killmail_data) do
    # Analyze activity by time periods
    hourly_activity = analyze_hourly_activity(killmail_data)
    daily_activity = analyze_daily_activity(killmail_data)
    weekly_activity = analyze_weekly_activity(killmail_data)

    %{
      hourly_activity: hourly_activity,
      daily_activity: daily_activity,
      weekly_activity: weekly_activity,
      peak_hours: identify_peak_hours(hourly_activity),
      activity_consistency: calculate_activity_consistency(daily_activity),
      timezone_estimate: estimate_timezone(hourly_activity)
    }
  end

  @doc """
  Analyze hourly activity patterns.

  Returns map of hours to activity counts.
  """
  def analyze_hourly_activity(killmail_data) do
    killmail_data
    |> Enum.group_by(fn km ->
      case get_killmail_time(km) do
        %DateTime{} = dt -> dt.hour
        _ -> 0
      end
    end)
    |> Enum.map(fn {hour, killmails} -> {hour, length(killmails)} end)
    |> Enum.into(%{})
  end

  @doc """
  Analyze daily activity patterns.

  Returns map of days of week to activity counts.
  """
  def analyze_daily_activity(killmail_data) do
    killmail_data
    |> Enum.group_by(fn km ->
      case get_killmail_time(km) do
        %DateTime{} = dt -> Date.day_of_week(dt)
        _ -> 1
      end
    end)
    |> Enum.map(fn {day, killmails} -> {day, length(killmails)} end)
    |> Enum.into(%{})
  end

  @doc """
  Analyze weekly activity patterns.

  Returns map of weeks to activity counts.
  """
  def analyze_weekly_activity(killmail_data) do
    killmail_data
    |> Enum.group_by(fn km ->
      case get_killmail_time(km) do
        %DateTime{} = dt -> Date.beginning_of_week(dt)
        _ -> Date.utc_today()
      end
    end)
    |> Enum.map(fn {week, killmails} -> {week, length(killmails)} end)
    |> Enum.into(%{})
  end

  @doc """
  Identify peak hours from hourly activity data.

  Returns list of top 3 most active hours.
  """
  def identify_peak_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _count} -> hour end)
  end

  @doc """
  Calculate activity consistency from daily activity data.

  Returns consistency score from 0.0 to 1.0.
  """
  def calculate_activity_consistency(daily_activity) do
    if map_size(daily_activity) < 2 do
      0.0
    else
      values = Map.values(daily_activity)
      mean = Enum.sum(values) / length(values)

      variance =
        Enum.reduce(values, 0, fn x, acc ->
          acc + :math.pow(x - mean, 2)
        end) / length(values)

      # Lower variance = higher consistency
      if mean > 0 do
        max(0.0, 1.0 - variance / mean)
      else
        0.0
      end
    end
  end

  @doc """
  Estimate timezone from hourly activity patterns.

  Returns estimated timezone region string.
  """
  def estimate_timezone(hourly_activity) do
    # Find peak hour and estimate timezone
    peak_hour =
      hourly_activity
      |> Enum.max_by(fn {_hour, count} -> count end, fn -> {12, 0} end)
      |> elem(0)

    # Simple timezone estimation (very rough)
    cond do
      peak_hour in 18..23 or peak_hour in 0..2 -> "EU"
      peak_hour in 8..14 -> "AU"
      peak_hour in 2..8 -> "US"
      true -> "Unknown"
    end
  end

  @doc """
  Identify vulnerable time patterns from temporal data.

  Returns list of time periods when character may be vulnerable.
  """
  def identify_vulnerable_time_patterns(temporal_patterns) do
    # Find hours with highest loss rates
    hourly_activity = temporal_patterns.hourly_activity || %{}

    # Simple heuristic: times with activity but presumably losses
    vulnerable_hours =
      hourly_activity
      |> Enum.filter(fn {_hour, count} -> count > 0 end)
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, _count} -> "#{hour}:00-#{hour + 1}:00 EVE" end)

    vulnerable_hours
  end

  # Private helper functions

  defp get_killmail_time(killmail) when is_map(killmail) do
    killmail[:killmail_time] || killmail["killmail_time"]
  end
end
