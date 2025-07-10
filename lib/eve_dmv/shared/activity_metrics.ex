defmodule EveDmv.Shared.ActivityMetrics do
  @moduledoc """
  Shared activity metric calculations for characters and corporations.

  Provides consistent activity scoring, engagement calculations, and
  timezone analysis used across the application.
  """

  @doc """
  Calculate activity score based on kills, losses, and recency.
  """
  def calculate_activity_score(kills, losses, last_activity) do
    # Base score from total activity
    total_activity = kills + losses
    base_score = :math.log(total_activity + 1) * 10

    # Kill/Death ratio bonus (capped to prevent extreme values)
    kd_ratio = if losses == 0, do: kills, else: kills / losses
    kd_bonus = :math.tanh(kd_ratio / 2) * 20

    # Recency multiplier
    days_inactive = days_since(last_activity)
    recency_multiplier = calculate_recency_multiplier(days_inactive)

    # Final score
    (base_score + kd_bonus) * recency_multiplier
  end

  @doc """
  Calculate engagement level category.
  """
  def categorize_engagement_level(activity_data) do
    %{
      kills: kills,
      losses: losses,
      last_activity: last_activity
    } = activity_data

    total_activity = kills + losses
    days_inactive = days_since(last_activity)

    cond do
      days_inactive > 30 -> :inactive
      total_activity >= 100 -> :very_high
      total_activity >= 50 -> :high
      total_activity >= 20 -> :medium
      total_activity >= 5 -> :low
      true -> :inactive
    end
  end

  @doc """
  Analyze timezone patterns from hourly activity data.
  """
  def analyze_timezone_patterns(hourly_activity) do
    # Find peak hours
    sorted_hours =
      hourly_activity
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(4)
      |> Enum.map(fn {hour, _count} -> hour end)
      |> Enum.sort()

    # Estimate primary timezone based on peak activity
    primary_tz = estimate_timezone(sorted_hours)

    # Calculate activity concentration
    total_activity =
      hourly_activity
      |> Enum.map(fn {_hour, count} -> count end)
      |> Enum.sum()

    peak_activity =
      sorted_hours
      |> Enum.map(fn hour -> Map.get(Map.new(hourly_activity), hour, 0) end)
      |> Enum.sum()

    concentration = if total_activity > 0, do: peak_activity / total_activity, else: 0

    %{
      peak_hours: sorted_hours,
      primary_timezone: primary_tz,
      activity_concentration: concentration,
      coverage_score: calculate_timezone_coverage(hourly_activity)
    }
  end

  @doc """
  Calculate activity trend from time series data.
  """
  def calculate_activity_trend(daily_activity) when is_list(daily_activity) do
    return_empty = %{trend: :stable, growth_rate: 0.0, volatility: 0.0}

    if length(daily_activity) < 7 do
      return_empty
    else
      # Split into two halves for comparison
      midpoint = div(length(daily_activity), 2)
      {recent, older} = Enum.split(daily_activity, midpoint)

      recent_avg = average_activity(recent)
      older_avg = average_activity(older)

      # Calculate growth rate
      growth_rate =
        if older_avg > 0 do
          (recent_avg - older_avg) / older_avg * 100
        else
          0.0
        end

      # Calculate volatility
      volatility = calculate_volatility(daily_activity)

      # Determine trend
      trend =
        cond do
          growth_rate > 20 -> :growing
          growth_rate < -20 -> :declining
          volatility > 0.5 -> :volatile
          true -> :stable
        end

      %{
        trend: trend,
        growth_rate: Float.round(growth_rate, 1),
        volatility: Float.round(volatility, 2)
      }
    end
  end

  @doc """
  Calculate member participation rate.
  """
  def calculate_participation_rate(active_members, total_members, time_window_days \\ 30) do
    if total_members > 0 do
      rate = active_members / total_members * 100

      %{
        rate: Float.round(rate, 1),
        active_members: active_members,
        total_members: total_members,
        time_window_days: time_window_days,
        classification: classify_participation_rate(rate)
      }
    else
      %{
        rate: 0.0,
        active_members: 0,
        total_members: 0,
        time_window_days: time_window_days,
        classification: :no_data
      }
    end
  end

  @doc """
  Calculate ISK efficiency.
  """
  def calculate_isk_efficiency(isk_destroyed, isk_lost) do
    total = isk_destroyed + isk_lost

    if total > 0 do
      efficiency = isk_destroyed / total * 100

      %{
        efficiency: Float.round(efficiency, 1),
        isk_destroyed: isk_destroyed,
        isk_lost: isk_lost,
        net_isk: isk_destroyed - isk_lost,
        rating: rate_isk_efficiency(efficiency)
      }
    else
      %{
        efficiency: 0.0,
        isk_destroyed: 0,
        isk_lost: 0,
        net_isk: 0,
        rating: :no_data
      }
    end
  end

  # Private helper functions

  defp days_since(nil), do: 999

  defp days_since(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _} -> days_since(dt)
      _ -> 999
    end
  end

  defp days_since(%DateTime{} = datetime) do
    DateTime.diff(DateTime.utc_now(), datetime, :day)
  end

  defp days_since(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> days_since()
  end

  defp calculate_recency_multiplier(days_inactive) do
    cond do
      days_inactive <= 7 -> 1.0
      days_inactive <= 14 -> 0.8
      days_inactive <= 30 -> 0.6
      days_inactive <= 60 -> 0.4
      days_inactive <= 90 -> 0.2
      true -> 0.1
    end
  end

  defp estimate_timezone(peak_hours) when is_list(peak_hours) do
    # Simple timezone estimation based on peak hours
    avg_peak = Enum.sum(peak_hours) / length(peak_hours)

    cond do
      avg_peak >= 0 and avg_peak < 8 -> "AU TZ"
      avg_peak >= 8 and avg_peak < 14 -> "RU TZ"
      avg_peak >= 14 and avg_peak < 20 -> "EU TZ"
      avg_peak >= 20 or avg_peak < 2 -> "US TZ"
      true -> "Mixed TZ"
    end
  end

  defp calculate_timezone_coverage(hourly_activity) do
    active_hours =
      hourly_activity
      |> Enum.filter(fn {_hour, count} -> count > 0 end)
      |> length()

    # Coverage score: percentage of hours with activity
    active_hours / 24 * 100
  end

  defp average_activity(activity_list) do
    if length(activity_list) > 0 do
      total =
        activity_list
        |> Enum.map(fn item ->
          Map.get(item, :total_activity, 0) || Map.get(item, "total_activity", 0)
        end)
        |> Enum.sum()

      total / length(activity_list)
    else
      0.0
    end
  end

  defp calculate_volatility(activity_list) do
    values =
      Enum.map(activity_list, fn item ->
        Map.get(item, :total_activity, 0) || Map.get(item, "total_activity", 0)
      end)

    if length(values) > 1 do
      mean = Enum.sum(values) / length(values)

      variance =
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values))

      std_dev = :math.sqrt(variance)

      # Coefficient of variation
      if mean > 0, do: std_dev / mean, else: 0.0
    else
      0.0
    end
  end

  defp classify_participation_rate(rate) do
    cond do
      rate >= 80 -> :excellent
      rate >= 60 -> :good
      rate >= 40 -> :average
      rate >= 20 -> :poor
      true -> :critical
    end
  end

  defp rate_isk_efficiency(efficiency) do
    cond do
      efficiency >= 90 -> :elite
      efficiency >= 75 -> :excellent
      efficiency >= 60 -> :good
      efficiency >= 50 -> :average
      efficiency >= 40 -> :below_average
      true -> :poor
    end
  end
end
