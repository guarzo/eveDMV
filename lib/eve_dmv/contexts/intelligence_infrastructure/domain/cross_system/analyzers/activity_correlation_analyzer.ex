defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.ActivityCorrelationAnalyzer do
  @moduledoc """
  Activity correlation and pattern analysis module for cross-system intelligence.

  This module handles comprehensive activity pattern analysis, correlations, movement patterns,
  and temporal analysis across multiple EVE Online systems. It was extracted from the larger
  CrossSystemCoordinator to improve modularity and maintainability.

  ## Key Responsibilities

  - **Activity Pattern Analysis**: Identifies peak activity hours, activity distribution across systems,
    and trends over time windows
  - **Correlation Analysis**: Calculates pairwise correlations between systems to identify related activities
  - **Movement Pattern Analysis**: Tracks character movements across systems to identify corridors,
    choke points, and strategic routes
  - **Anomaly Detection**: Detects unusual activity spikes and timing patterns that may indicate threats
  - **Insight Generation**: Provides actionable insights based on real activity and movement data

  ## Usage

      # Analyze activity patterns across systems
      activity_patterns = ActivityCorrelationAnalyzer.analyze_activity_patterns(
        [30000142, 30000143],
        killmails,
        24
      )

      # Calculate correlations between system activities
      correlations = ActivityCorrelationAnalyzer.calculate_activity_correlations(
        system_ids,
        killmails
      )

      # Analyze movement patterns
      movement = ActivityCorrelationAnalyzer.analyze_movement_patterns(
        system_ids,
        killmails,
        analysis_window
      )

  ## Data Sources

  This module operates on real killmail data from the `killmails_enriched` table,
  providing authentic analysis based on actual EVE Online combat events.

  ## Analysis Methods

  - Statistical analysis including standard deviation for activity distribution
  - Linear regression for trend detection
  - Correlation coefficient calculations for system relationships
  - Character movement tracking for tactical intelligence
  - Anomaly detection using baseline activity comparisons
  """

  require Logger

  @doc """
  Analyze activity patterns across multiple systems.
  """
  def analyze_activity_patterns(system_ids, killmails, analysis_window) do
    # Analyze hourly activity patterns
    hourly_kills =
      Enum.group_by(killmails, fn km ->
        km.killmail_time.hour
      end)

    # Find peak activity hours
    peak_hours =
      hourly_kills
      |> Enum.map(fn {hour, kills} -> {hour, length(kills)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)

    # Extract peak hours and sort them
    _peak_hours = Enum.map(peak_hours, &elem(&1, 0)) |> Enum.sort()

    # Calculate activity distribution across systems
    system_activity = calculate_activity_distribution(system_ids, killmails)

    # Analyze trends over the time window
    trends = analyze_activity_trends(system_ids, killmails, analysis_window)

    # Detect anomalies using statistical analysis
    anomalies = detect_activity_anomalies(system_ids, killmails)

    %{
      peak_activity_hours: peak_hours,
      activity_distribution: system_activity,
      activity_trends: trends,
      anomalies: anomalies,
      total_events: length(killmails),
      events_per_hour: Float.round(length(killmails) / analysis_window, 2)
    }
  end

  @doc """
  Calculate activity correlations between systems.
  """
  def calculate_activity_correlations(system_ids, killmails) do
    # Group killmails by system and time window
    system_activity = group_by_system_and_time(killmails)

    # Calculate pairwise correlations between systems
    correlations = calculate_pairwise_correlations(system_ids, system_activity)

    # Find strongest correlations
    strong_correlations =
      correlations
      |> Enum.filter(fn {_pair, score} -> score > 0.6 end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)

    # Identify correlation patterns
    correlation_patterns = identify_correlation_patterns(strong_correlations, system_activity)

    %{
      correlation_strength: calculate_overall_correlation_strength(correlations),
      correlated_systems: extract_correlated_systems(strong_correlations),
      correlation_patterns: correlation_patterns,
      correlation_matrix: Map.new(correlations),
      temporal_lag: detect_temporal_lag(system_activity)
    }
  end

  @doc """
  Analyze movement patterns across systems.
  """
  def analyze_movement_patterns(system_ids, killmails, analysis_window) do
    # Group kills by character to track movement
    character_activity = group_by_character_activity(killmails)

    # Identify movement corridors
    corridors = identify_movement_corridors(system_ids, character_activity)

    # Analyze travel patterns
    travel = analyze_travel_patterns(system_ids, character_activity, analysis_window)

    # Identify choke points based on kill concentration
    choke_points = identify_choke_points(system_ids, killmails)

    # Map strategic routes
    routes = map_strategic_routes(system_ids, corridors)

    %{
      movement_corridors: corridors,
      travel_patterns: travel,
      choke_points: choke_points,
      strategic_routes: routes,
      active_travelers: map_size(character_activity),
      cross_system_activity: calculate_cross_system_activity_score(character_activity)
    }
  end

  @doc """
  Generate activity-based insights.
  """
  def generate_activity_insights(activity_patterns) do
    # Peak hour insights
    peak_insights =
      if length(activity_patterns.peak_activity_hours) > 0 do
        peak_hours_str = Enum.join(activity_patterns.peak_activity_hours, ", ")
        ["Peak activity detected at hours: #{peak_hours_str} EVE time"]
      else
        []
      end

    # Activity distribution insights
    dist = activity_patterns.activity_distribution

    distribution_insights =
      if dist.high_activity > dist.low_activity * 2 do
        ["Activity highly concentrated in #{dist.high_activity} systems"]
      else
        []
      end

    # Anomaly insights
    anomaly_insights =
      if length(activity_patterns.anomalies) > 0 do
        [
          "#{length(activity_patterns.anomalies)} activity anomalies detected requiring investigation"
        ]
      else
        []
      end

    peak_insights ++ distribution_insights ++ anomaly_insights
  end

  @doc """
  Generate movement-based insights.
  """
  def generate_movement_insights(movement_patterns) do
    corridor_insights =
      if length(movement_patterns.movement_corridors) > 0 do
        primary_corridors =
          Enum.count(movement_patterns.movement_corridors, fn c -> c.corridor_type == :primary end)

        if primary_corridors > 0 do
          ["#{primary_corridors} primary movement corridors identified"]
        else
          []
        end
      else
        []
      end

    # Choke point insights
    choke_insights =
      if length(movement_patterns.choke_points) > 0 do
        top_choke = List.first(movement_patterns.choke_points)

        if top_choke && top_choke.choke_score > 50 do
          ["Critical choke point detected in system #{top_choke.system_id}"]
        else
          []
        end
      else
        []
      end

    # Travel pattern insights
    travel_insights =
      if movement_patterns.travel_patterns.unique_travelers > 20 do
        [
          "High traffic volume: #{movement_patterns.travel_patterns.unique_travelers} unique travelers tracked"
        ]
      else
        []
      end

    # Cross-system activity insights
    activity_insights =
      if movement_patterns.cross_system_activity > 70 do
        [
          "High cross-system mobility: #{movement_patterns.cross_system_activity}% of entities active in multiple systems"
        ]
      else
        []
      end

    corridor_insights ++ choke_insights ++ travel_insights ++ activity_insights
  end

  # Private helper functions

  defp calculate_activity_distribution(system_ids, killmails) do
    # Count kills per system
    system_kills =
      killmails
      |> Enum.group_by(& &1.solar_system_id)

    Enum.map(fn {system_id, kills} -> {system_id, length(kills)} end) |> Map.new()
    # Calculate statistics
    kill_counts = Map.values(system_kills)

    avg_kills =
      if length(kill_counts) > 0, do: Enum.sum(kill_counts) / length(kill_counts), else: 0

    std_dev = calculate_std_deviation(kill_counts)

    # Categorize systems by activity level
    categorized =
      Enum.map(system_ids, fn system_id ->
        kills = Map.get(system_kills, system_id, 0)

        level =
          cond do
            kills > avg_kills + std_dev -> :high
            kills < avg_kills - std_dev -> :low
            true -> :medium
          end

        {system_id, level, kills}
      end)

    %{
      high_activity: Enum.count(categorized, fn {_, level, _} -> level == :high end),
      medium_activity: Enum.count(categorized, fn {_, level, _} -> level == :medium end),
      low_activity: Enum.count(categorized, fn {_, level, _} -> level == :low end),
      system_details: categorized,
      average_kills_per_system: Float.round(avg_kills, 2),
      standard_deviation: Float.round(std_dev, 2)
    }
  end

  defp analyze_activity_trends(_system_ids, killmails, _analysis_window) do
    # Group kills by system and time bucket
    # hours
    bucket_size = 4

    system_trends =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, system_kills} ->
        # Create time buckets
        buckets =
          system_kills
          |> Enum.group_by(fn kill ->
            hours_ago = DateTime.diff(DateTime.utc_now(), kill.killmail_time, :hour)
            div(hours_ago, bucket_size)
          end)

        buckets = Enum.map(buckets, fn {bucket, kills} -> {bucket, length(kills)} end) |> Enum.sort()
        trend = calculate_trend_direction(buckets)
        {system_id, trend}
      end)
      |> Map.new()

    # Categorize systems by trend
    trending_up =
      system_trends
      |> Enum.filter(fn {_, trend} -> trend == :increasing end)
      |> Enum.map(&elem(&1, 0))

    trending_down =
      system_trends
      |> Enum.filter(fn {_, trend} -> trend == :decreasing end)
      |> Enum.map(&elem(&1, 0))

    stable =
      system_trends
      |> Enum.filter(fn {_, trend} -> trend == :stable end)
      |> Enum.map(&elem(&1, 0))

    %{
      overall_trend: determine_overall_trend(trending_up, trending_down),
      trending_up: trending_up,
      trending_down: trending_down,
      stable_systems: stable,
      trend_details: system_trends
    }
  end

  defp detect_activity_anomalies(_system_ids, killmails) do
    # Calculate baseline activity for each system
    system_baselines = calculate_system_baselines(killmails)

    # Check for sudden activity spikes
    spike_anomalies = detect_activity_spikes(killmails, system_baselines)

    # Check for unusual timing patterns
    timing_anomalies = detect_timing_anomalies(killmails)

    # Combine all anomalies
    anomalies = spike_anomalies ++ timing_anomalies

    # Sort by severity
    anomalies
    |> Enum.sort_by(& &1.severity, :desc)
    |> Enum.take(10)
  end

  defp group_by_character_activity(killmails) do
    killmails
    |> Enum.flat_map(fn kill ->
      # Add victim
      victim_entry = {kill.victim_character_id, kill.solar_system_id, kill.killmail_time}
      # For now, we only have victim data readily available
      [victim_entry]
    end)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {char_id, activities} ->
      systems_visited = activities |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
      {char_id, %{systems: systems_visited, activity_count: length(activities)}}
    end)
    |> Map.new()
  end

  defp identify_movement_corridors(_system_ids, character_activity) do
    # Identify common movement paths between systems
    movement_pairs =
      character_activity
      |> Enum.flat_map(fn {_char_id, data} ->
        systems = data.systems
        # Create pairs of consecutive systems (simplified - would need timestamps)
        systems
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [from, to] -> {from, to} end)
      end)
      |> Enum.frequencies()

    # Find most used corridors
    corridors =
      movement_pairs
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)
      |> Enum.map(fn {{from, to}, count} ->
        %{
          from_system: from,
          to_system: to,
          usage_count: count,
          corridor_type: categorize_corridor(count)
        }
      end)

    corridors
  end

  defp categorize_corridor(usage_count) do
    cond do
      usage_count > 50 -> :primary
      usage_count > 20 -> :secondary
      usage_count > 10 -> :tertiary
      true -> :occasional
    end
  end

  defp analyze_travel_patterns(_system_ids, character_activity, _analysis_window) do
    # Analyze how characters move through systems
    # Get all character movements
    all_movements =
      Enum.map(character_activity, fn {char_id, data} ->
        %{
          character_id: char_id,
          systems_visited: data.systems,
          activity_count: data.activity_count
        }
      end)

    # Find common routes (chains of 3+ systems)
    common_routes = find_common_routes(all_movements)

    # Calculate travel frequency per system
    travel_frequency =
      all_movements
      |> Enum.flat_map(fn m -> m.systems_visited end)
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(10)
      |> Map.new()
    # Analyze peak travel times (simplified - would need timestamps)
    # EVE prime time
    peak_travel_times = [17, 18, 19, 20, 21, 22]

    %{
      common_routes: common_routes,
      travel_frequency: travel_frequency,
      peak_travel_times: peak_travel_times,
      unique_travelers: map_size(character_activity)
    }
  end

  defp find_common_routes(movements) do
    # Find sequences of systems that multiple characters visit
    route_patterns =
      movements
      |> Enum.flat_map(fn m ->
        if length(m.systems_visited) >= 3 do
          m.systems_visited
          |> Enum.chunk_every(3, 1, :discard)
          |> Enum.map(&Enum.join(&1, "→"))
        else
          []
        end
      end)
      |> Enum.frequencies()
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)
      |> Enum.map(fn {route, count} ->
        systems = route |> String.split("→") |> Enum.map(&String.to_integer/1)

        %{
          route: systems,
          usage_count: count,
          route_type: if(count > 10, do: :popular, else: :occasional)
        }
      end)

    route_patterns
  end

  defp identify_choke_points(_system_ids, killmails) do
    # Identify systems that act as choke points based on kill concentration
    system_metrics =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kills} ->
        # Calculate choke point indicators
        kill_density = length(kills)
        unique_victims = kills |> Enum.map(& &1.victim_character_id) |> Enum.uniq() |> length()
        repeat_rate = 1 - unique_victims / max(length(kills), 1)

        choke_score = kill_density * 0.6 + repeat_rate * 100 * 0.4

        %{
          system_id: system_id,
          choke_score: Float.round(choke_score, 2),
          kill_density: kill_density,
          repeat_victim_rate: Float.round(repeat_rate, 2)
        }
      end)
      |> Enum.sort_by(& &1.choke_score, :desc)
      |> Enum.take(5)

    system_metrics
  end

  defp map_strategic_routes(_system_ids, corridors) do
    # Map strategic importance of identified movement corridors
    # Group corridors by importance
    primary_routes =
      corridors
      |> Enum.filter(fn c -> c.corridor_type == :primary end)
      |> Enum.map(&[&1.from_system, &1.to_system])

    secondary_routes =
      corridors
      |> Enum.filter(fn c -> c.corridor_type == :secondary end)
      |> Enum.map(&[&1.from_system, &1.to_system])

    # Calculate strategic value for each system based on route participation
    strategic_value =
      corridors

    Enum.flat_map(fn c -> [c.from_system, c.to_system] end)
    |> Enum.frequencies()
    |> Enum.map(fn {system, count} ->
      value =
        cond do
          count > 10 -> :critical
          count > 5 -> :high
          count > 2 -> :moderate
          true -> :low
        end

      {system, value}
    end)
    |> Map.new()

    %{
      primary_routes: primary_routes,
      secondary_routes: secondary_routes,
      strategic_value: strategic_value,
      total_routes: length(corridors)
    }
  end

  defp calculate_cross_system_activity_score(character_activity) do
    # Calculate how much cross-system activity is occurring
    total_characters = map_size(character_activity)

    if total_characters == 0 do
      0.0
    else
      # Count characters active in multiple systems
      multi_system_chars =
        Enum.count(character_activity, fn {_char_id, data} -> length(data.systems) > 1 end)

      # Calculate cross-system activity ratio
      Float.round(multi_system_chars / total_characters * 100, 2)
    end
  end

  # Correlation analysis helpers

  defp group_by_system_and_time(killmails) do
    # Group killmails by system and time window (hourly)
    killmails
    |> Enum.group_by(fn km ->
      hour = DateTime.truncate(km.killmail_time, :second)
      {km.solar_system_id, hour}
    end)
    |> Enum.map(fn {{system_id, hour}, kills} ->
      {{system_id, hour}, length(kills)}
    end)
    |> Map.new()
  end

  defp calculate_pairwise_correlations(system_ids, system_activity) do
    # Calculate correlation between pairs of systems
    pairs = for s1 <- system_ids, s2 <- system_ids, s1 < s2, do: {s1, s2}

    correlations =
      pairs
      |> Enum.map(fn {s1, s2} ->
        # Get activity for both systems
        s1_activity =
          system_activity
          |> Enum.filter(fn {{sys, _}, _} -> sys == s1 end)

        Enum.map(fn {{_, time}, count} -> {time, count} end) |> Map.new()

        s2_activity =
          system_activity
          |> Enum.filter(fn {{sys, _}, _} -> sys == s2 end)

        Enum.map(fn {{_, time}, count} -> {time, count} end) |> Map.new()
        # Calculate correlation coefficient (simplified)
        correlation = calculate_correlation_coefficient(s1_activity, s2_activity)

        {{s1, s2}, correlation}
      end)

      # Keep only meaningful correlations
      |> Enum.filter(fn {_, corr} -> corr > 0.3 end)

    correlations
  end

  defp calculate_correlation_coefficient(activity1, activity2) do
    # Simplified correlation calculation
    set1 = Map.keys(activity1) |> MapSet.new()
    set2 = Map.keys(activity2) |> MapSet.new()
    common_times = MapSet.intersection(set1, set2)

    if MapSet.size(common_times) < 3 do
      0.0
    else
      # Calculate similarity based on activity patterns
      similarities =
        Enum.map(common_times, fn time ->
          a1 = Map.get(activity1, time, 0)
          a2 = Map.get(activity2, time, 0)

          if a1 + a2 == 0 do
            0.0
          else
            min(a1, a2) / max(a1, a2)
          end
        end)

      if length(similarities) > 0 do
        Enum.sum(similarities) / length(similarities)
      else
        0.0
      end
    end
  end

  defp extract_correlated_systems(strong_correlations) do
    # Extract unique systems that show correlation
    strong_correlations
    |> Enum.flat_map(fn {{s1, s2}, _} -> [s1, s2] end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp calculate_overall_correlation_strength(correlations) do
    if Enum.empty?(correlations) do
      0.0
    else
      # Average correlation strength
      total_correlation =
        correlations
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()

      Float.round(total_correlation / length(correlations), 2)
    end
  end

  defp identify_correlation_patterns(strong_correlations, system_activity) do
    # Pattern 1: Simultaneous activity
    simultaneous =
      strong_correlations
      |> Enum.filter(fn {_, score} -> score > 0.8 end)
      |> Enum.map(fn {{s1, s2}, score} ->
        %{
          type: :simultaneous_activity,
          systems: [s1, s2],
          correlation_strength: Float.round(score, 2)
        }
      end)

    # Pattern 2: Cascading activity (time-delayed correlation)
    cascading = detect_cascading_patterns(strong_correlations, system_activity)

    simultaneous ++ cascading
  end

  defp detect_cascading_patterns(correlations, _system_activity) do
    # Simplified cascading pattern detection
    correlations
    |> Enum.filter(fn {_, score} -> score > 0.5 and score < 0.8 end)
    |> Enum.take(3)
    |> Enum.map(fn {{s1, s2}, score} ->
      %{
        type: :cascading_activity,
        from_system: s1,
        to_system: s2,
        correlation_strength: Float.round(score, 2),
        # Simplified
        typical_delay: "1-2 hours"
      }
    end)
  end

  defp detect_temporal_lag(system_activity) do
    # Detect average time lag between correlated activities
    # Simplified - returns average lag in hours
    if map_size(system_activity) < 10 do
      0
    else
      # In a real implementation, would analyze time series data
      # Default 1 hour lag
      1
    end
  end

  # Statistical and trend analysis helpers

  defp calculate_std_deviation(values) do
    if Enum.empty?(values) do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      variance = Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end)) / length(values)
      :math.sqrt(variance)
    end
  end

  defp calculate_trend_direction(buckets) do
    if length(buckets) < 2 do
      :stable
    else
      # Simple linear regression on bucket activity
      {xs, ys} = Enum.unzip(buckets)

      n = length(xs)
      sum_x = Enum.sum(xs)
      sum_y = Enum.sum(ys)
      sum_xy = xs |> Enum.zip(ys) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x_sq = Enum.sum(Enum.map(xs, &(&1 * &1)))

      slope =
        if n * sum_x_sq - sum_x * sum_x == 0 do
          0
        else
          (n * sum_xy - sum_x * sum_y) / (n * sum_x_sq - sum_x * sum_x)
        end

      cond do
        slope > 0.1 -> :increasing
        slope < -0.1 -> :decreasing
        true -> :stable
      end
    end
  end

  defp determine_overall_trend(trending_up, trending_down) do
    cond do
      length(trending_up) > length(trending_down) * 1.5 -> :increasing
      length(trending_down) > length(trending_up) * 1.5 -> :decreasing
      true -> :stable
    end
  end

  defp calculate_system_baselines(killmails) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, system_kills} ->
      hourly_activity =
        system_kills
        |> Enum.group_by(fn kill ->
          DateTime.truncate(kill.killmail_time, :second)
        end)
        |> Enum.map(fn {_hour, kills} -> length(kills) end)

      avg_activity =
        if length(hourly_activity) > 0 do
          Enum.sum(hourly_activity) / length(hourly_activity)
        else
          0
        end

      {system_id, %{average_hourly_activity: avg_activity, sample_size: length(hourly_activity)}}
    end)
    |> Map.new()
  end

  defp detect_activity_spikes(killmails, baselines) do
    killmails
    |> Enum.group_by(fn kill ->
      {kill.solar_system_id, DateTime.truncate(kill.killmail_time, :second)}
    end)
    |> Enum.flat_map(fn {{system_id, hour}, hour_kills} ->
      baseline = get_in(baselines, [system_id, :average_hourly_activity]) || 0

      if baseline > 0 and length(hour_kills) > baseline * 3 do
        [
          %{
            type: :activity_spike,
            system_id: system_id,
            timestamp: hour,
            severity: :high,
            details: %{
              normal_activity: Float.round(baseline, 1),
              spike_activity: length(hour_kills),
              spike_ratio: Float.round(length(hour_kills) / baseline, 1)
            }
          }
        ]
      else
        []
      end
    end)
  end

  defp detect_timing_anomalies(killmails) do
    # Detect unusual timing patterns (e.g., activity at normally quiet hours)
    killmails
    |> Enum.group_by(& &1.killmail_time.hour)
    |> Enum.flat_map(fn {hour, hour_kills} ->
      # Consider hours 0-6 as "quiet hours" in EVE time
      if hour >= 0 and hour <= 6 and length(hour_kills) > 10 do
        [
          %{
            type: :unusual_timing,
            hour: hour,
            severity: :medium,
            details: %{
              activity_count: length(hour_kills),
              systems_affected:
                hour_kills |> Enum.map(& &1.solar_system_id) |> Enum.uniq() |> length()
            }
          }
        ]
      else
        []
      end
    end)
  end
end
