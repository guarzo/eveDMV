defmodule EveDmv.Shared.Strategic.TemporalAnalyzer do
  @moduledoc """
  Analyzes temporal patterns and activity consistency in strategic data.

  Responsible for:
  - Temporal distribution analysis
  - Activity consistency calculations
  - Time window pattern detection
  - Peak activity identification
  """

  require Logger

  @doc """
  Analyzes temporal distribution of activities.
  """
  def analyze_temporal_distribution(strategic_data) do
    killmails = extract_killmails(strategic_data)

    daily_distribution = calculate_daily_distribution(killmails)
    hourly_distribution = calculate_hourly_distribution(killmails)
    weekly_pattern = analyze_weekly_pattern(killmails)

    %{
      daily_activity: daily_distribution,
      hourly_activity: hourly_distribution,
      weekly_pattern: weekly_pattern,
      peak_times: identify_peak_times(hourly_distribution),
      consistency_score: calculate_consistency_score(daily_distribution),
      activity_gaps: identify_activity_gaps(daily_distribution)
    }
  end

  @doc """
  Calculates activity consistency metrics.
  """
  def calculate_activity_consistency(temporal_data) do
    daily_counts = Map.values(temporal_data.daily_activity)

    if length(daily_counts) < 3 do
      %{
        consistency_score: 0.0,
        variance: 0.0,
        standard_deviation: 0.0,
        coefficient_of_variation: 0.0,
        assessment: :insufficient_data
      }
    else
      mean = Enum.sum(daily_counts) / length(daily_counts)
      variance = calculate_variance(daily_counts, mean)
      std_dev = :math.sqrt(variance)
      cv = if mean > 0, do: std_dev / mean, else: 0.0

      %{
        consistency_score: calculate_consistency_from_cv(cv),
        variance: Float.round(variance, 2),
        standard_deviation: Float.round(std_dev, 2),
        coefficient_of_variation: Float.round(cv, 3),
        assessment: assess_consistency(cv)
      }
    end
  end

  @doc """
  Identifies temporal clusters of activity.
  """
  def identify_temporal_clusters(strategic_data, options \\ []) do
    min_cluster_size = Keyword.get(options, :min_cluster_size, 5)
    time_window_hours = Keyword.get(options, :time_window_hours, 2)

    killmails =
      extract_killmails(strategic_data)
      |> Enum.sort_by(& &1.timestamp, DateTime)

    clusters = find_temporal_clusters(killmails, time_window_hours, min_cluster_size)

    %{
      cluster_count: length(clusters),
      clusters: Enum.map(clusters, &analyze_cluster/1),
      average_cluster_size: calculate_average_cluster_size(clusters),
      cluster_intensity: calculate_cluster_intensity(clusters, length(killmails))
    }
  end

  @doc """
  Analyzes time windows for pattern detection.
  """
  def analyze_time_windows(strategic_data, window_size_hours) do
    killmails = extract_killmails(strategic_data)
    windows = create_time_windows(killmails, window_size_hours)

    windows
    |> Enum.map(&analyze_window/1)
    |> identify_window_patterns()
  end

  # Private functions

  defp extract_killmails(strategic_data) do
    case strategic_data.scope do
      :single_system ->
        strategic_data.killmails

      :multi_system ->
        strategic_data.killmail_data
        |> Enum.flat_map(& &1.killmails)
    end
  end

  defp calculate_daily_distribution(killmails) do
    killmails
    |> Enum.group_by(fn km -> DateTime.to_date(km.timestamp) end)
    |> Enum.map(fn {date, kms} -> {date, length(kms)} end)
    |> Map.new()
  end

  defp calculate_hourly_distribution(killmails) do
    killmails
    |> Enum.group_by(fn km -> km.timestamp.hour end)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Map.new()
  end

  defp analyze_weekly_pattern(killmails) do
    killmails
    |> Enum.group_by(fn km -> Date.day_of_week(DateTime.to_date(km.timestamp)) end)
    |> Enum.map(fn {day, kms} ->
      {day_name(day), length(kms)}
    end)
    |> Map.new()
  end

  defp day_name(1), do: :monday
  defp day_name(2), do: :tuesday
  defp day_name(3), do: :wednesday
  defp day_name(4), do: :thursday
  defp day_name(5), do: :friday
  defp day_name(6), do: :saturday
  defp day_name(7), do: :sunday

  defp identify_peak_times(hourly_distribution) do
    if map_size(hourly_distribution) == 0 do
      []
    else
      avg_activity = Enum.sum(Map.values(hourly_distribution)) / 24

      hourly_distribution
      |> Enum.filter(fn {_hour, count} -> count > avg_activity * 1.5 end)
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, count} ->
        %{
          hour: hour,
          activity_count: count,
          relative_intensity: Float.round(count / avg_activity, 2)
        }
      end)
    end
  end

  defp calculate_consistency_score(daily_distribution) do
    values = Map.values(daily_distribution)

    if length(values) < 2 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      variance = calculate_variance(values, mean)
      cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 1.0

      # Convert CV to consistency score (0-1, where 1 is most consistent)
      max(0.0, min(1.0, 1.0 - cv))
    end
  end

  defp calculate_variance(values, mean) do
    squared_diffs = Enum.map(values, fn v -> :math.pow(v - mean, 2) end)
    Enum.sum(squared_diffs) / length(values)
  end

  defp identify_activity_gaps(daily_distribution) do
    if map_size(daily_distribution) < 2 do
      []
    else
      dates = Map.keys(daily_distribution) |> Enum.sort(Date)

      dates
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [d1, d2] ->
        gap_days = Date.diff(d2, d1)

        if gap_days > 1 do
          %{
            start_date: d1,
            end_date: d2,
            gap_days: gap_days - 1
          }
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  defp calculate_consistency_from_cv(cv) do
    cond do
      cv <= 0.2 -> 1.0
      cv <= 0.5 -> 0.8
      cv <= 1.0 -> 0.6
      cv <= 2.0 -> 0.4
      true -> 0.2
    end
  end

  defp assess_consistency(cv) do
    cond do
      cv <= 0.2 -> :highly_consistent
      cv <= 0.5 -> :consistent
      cv <= 1.0 -> :moderate
      cv <= 2.0 -> :inconsistent
      true -> :highly_inconsistent
    end
  end

  defp find_temporal_clusters([], _, _), do: []

  defp find_temporal_clusters([first | rest], time_window_hours, min_cluster_size) do
    {cluster, remaining} = build_cluster([first], rest, time_window_hours)

    if length(cluster) >= min_cluster_size do
      [cluster | find_temporal_clusters(remaining, time_window_hours, min_cluster_size)]
    else
      find_temporal_clusters(remaining, time_window_hours, min_cluster_size)
    end
  end

  defp build_cluster(cluster, [], _), do: {cluster, []}

  defp build_cluster(cluster, [next | rest], time_window_hours) do
    last_time = List.last(cluster).timestamp

    if DateTime.diff(next.timestamp, last_time, :hour) <= time_window_hours do
      build_cluster(cluster ++ [next], rest, time_window_hours)
    else
      {cluster, [next | rest]}
    end
  end

  defp analyze_cluster(cluster) do
    start_time = List.first(cluster).timestamp
    end_time = List.last(cluster).timestamp

    %{
      size: length(cluster),
      start_time: start_time,
      end_time: end_time,
      duration_hours: DateTime.diff(end_time, start_time, :hour),
      intensity: length(cluster) / max(1, DateTime.diff(end_time, start_time, :hour)),
      participants: count_unique_participants(cluster)
    }
  end

  defp count_unique_participants(killmails) do
    attackers =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.character_id)
      |> Enum.reject(&is_nil/1)

    victims =
      killmails
      |> Enum.map(& &1.victim.character_id)
      |> Enum.reject(&is_nil/1)

    (attackers ++ victims)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_average_cluster_size(clusters) do
    if length(clusters) == 0 do
      0.0
    else
      total_size = Enum.sum(Enum.map(clusters, & &1.size))
      Float.round(total_size / length(clusters), 1)
    end
  end

  defp calculate_cluster_intensity(clusters, total_killmails) do
    if total_killmails == 0 do
      0.0
    else
      clustered_kills = Enum.sum(Enum.map(clusters, & &1.size))
      Float.round(clustered_kills / total_killmails, 2)
    end
  end

  defp create_time_windows(killmails, window_size_hours) do
    if length(killmails) == 0 do
      []
    else
      sorted_killmails = Enum.sort_by(killmails, & &1.timestamp, DateTime)

      start_time = List.first(sorted_killmails).timestamp
      end_time = List.last(sorted_killmails).timestamp

      create_windows_between(start_time, end_time, window_size_hours, sorted_killmails)
    end
  end

  defp create_windows_between(start_time, end_time, window_hours, killmails) do
    window_seconds = window_hours * 3600

    Stream.unfold(start_time, fn current ->
      if DateTime.compare(current, end_time) == :lt do
        window_end = DateTime.add(current, window_seconds, :second)

        window_kills =
          Enum.filter(killmails, fn km ->
            DateTime.compare(km.timestamp, current) in [:gt, :eq] &&
              DateTime.compare(km.timestamp, window_end) == :lt
          end)

        window = %{
          start_time: current,
          end_time: window_end,
          killmails: window_kills,
          kill_count: length(window_kills)
        }

        {window, window_end}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  defp analyze_window(window) do
    %{
      start_time: window.start_time,
      end_time: window.end_time,
      activity_level: classify_window_activity(window.kill_count),
      kill_count: window.kill_count,
      unique_entities: count_unique_participants(window.killmails)
    }
  end

  defp classify_window_activity(kill_count) do
    cond do
      kill_count >= 20 -> :very_high
      kill_count >= 10 -> :high
      kill_count >= 5 -> :medium
      kill_count >= 1 -> :low
      true -> :none
    end
  end

  defp identify_window_patterns(analyzed_windows) do
    %{
      windows: analyzed_windows,
      high_activity_windows:
        Enum.filter(analyzed_windows, &(&1.activity_level in [:high, :very_high])),
      activity_pattern: detect_activity_pattern(analyzed_windows),
      periodicity: detect_periodicity(analyzed_windows)
    }
  end

  defp detect_activity_pattern(windows) do
    activity_levels = Enum.map(windows, & &1.activity_level)

    cond do
      Enum.all?(activity_levels, &(&1 in [:high, :very_high])) -> :sustained_high
      Enum.all?(activity_levels, &(&1 in [:low, :none])) -> :sustained_low
      has_burst_pattern?(activity_levels) -> :burst
      has_cyclic_pattern?(activity_levels) -> :cyclic
      true -> :irregular
    end
  end

  defp has_burst_pattern?(activity_levels) do
    # Simple burst detection - high activity followed by low
    activity_levels
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.any?(fn chunk ->
      match?(
        [low1, high, low2]
        when low1 in [:low, :none] and
               high in [:high, :very_high] and
               low2 in [:low, :none],
        chunk
      )
    end)
  end

  defp has_cyclic_pattern?(activity_levels) do
    # Simple cyclic detection - repeating pattern
    if length(activity_levels) >= 6 do
      first_half = Enum.take(activity_levels, div(length(activity_levels), 2))

      second_half =
        Enum.take(Enum.drop(activity_levels, div(length(activity_levels), 2)), length(first_half))

      first_half == second_half
    else
      false
    end
  end

  defp detect_periodicity(windows) do
    # Simplified periodicity detection
    high_activity_times =
      windows
      |> Enum.filter(&(&1.activity_level in [:high, :very_high]))
      |> Enum.map(& &1.start_time)

    if length(high_activity_times) >= 2 do
      intervals =
        high_activity_times
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1, :hour) end)

      if length(intervals) > 0 do
        avg_interval = Enum.sum(intervals) / length(intervals)

        %{
          detected: true,
          average_interval_hours: Float.round(avg_interval, 1),
          consistency: calculate_interval_consistency(intervals, avg_interval)
        }
      else
        %{detected: false}
      end
    else
      %{detected: false}
    end
  end

  defp calculate_interval_consistency(intervals, avg_interval) do
    variance =
      intervals
      |> Enum.map(fn i -> :math.pow(i - avg_interval, 2) end)
      |> Enum.sum()
      |> Kernel./(length(intervals))

    cv = if avg_interval > 0, do: :math.sqrt(variance) / avg_interval, else: 1.0

    cond do
      cv <= 0.1 -> :very_consistent
      cv <= 0.3 -> :consistent
      cv <= 0.5 -> :moderate
      true -> :inconsistent
    end
  end
end
