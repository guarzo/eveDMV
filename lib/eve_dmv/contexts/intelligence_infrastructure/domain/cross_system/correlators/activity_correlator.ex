defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Correlators.ActivityCorrelator do
  @moduledoc """
  Correlator for activity patterns across multiple systems.
  """

  alias EveDmv.Repo
  import Ecto.Query
  require Logger

  @doc """
  Correlate activity patterns across systems.
  """
  def correlate_activities(system_ids, _options) do
    Logger.debug("Correlating activities across #{length(system_ids)} systems")

    %{
      correlation_strength: calculate_correlation_strength(system_ids),
      correlated_patterns: identify_correlated_patterns(system_ids),
      activity_synchronization: analyze_activity_synchronization(system_ids),
      temporal_correlations: analyze_temporal_correlations(system_ids)
    }
  end

  defp calculate_correlation_strength(system_ids) do
    Logger.debug("Calculating correlation strength for #{length(system_ids)} systems")

    if length(system_ids) < 2 do
      0.0
    else
      # Get activity data for all systems
      activity_data = fetch_systems_activity_data(system_ids)
      
      # Calculate pairwise correlations between systems
      correlations = calculate_pairwise_correlations(activity_data)
      
      # Calculate overall correlation strength
      if Enum.empty?(correlations) do
        0.0
      else
        # Use average correlation strength
        total_correlation = correlations |> Enum.map(&abs/1) |> Enum.sum()
        average_correlation = total_correlation / length(correlations)
        
        # Adjust for system count (more systems = potentially stronger network effect)
        system_factor = min(1.0, length(system_ids) / 10)
        
        min(1.0, average_correlation * (1 + system_factor * 0.2))
      end
    end
  end

  defp identify_correlated_patterns(system_ids) do
    Logger.debug("Identifying correlated patterns for #{length(system_ids)} systems")

    if length(system_ids) < 2 do
      %{
        synchronization_level: 0.0,
        synchronized_systems: [],
        synchronization_patterns: []
      }
    else
      # Get activity data for pattern analysis
      activity_data = fetch_systems_activity_data(system_ids)
      
      # Identify synchronized systems
      synchronized_systems = identify_synchronized_systems(activity_data)
      
      # Analyze synchronization patterns
      patterns = analyze_synchronization_patterns(activity_data)
      
      # Calculate overall synchronization level
      sync_level = calculate_synchronization_level(synchronized_systems, system_ids)
      
      %{
        synchronization_level: sync_level,
        synchronized_systems: synchronized_systems,
        synchronization_patterns: patterns,
        pattern_details: %{
          temporal_clusters: identify_temporal_clusters(activity_data),
          activity_waves: detect_activity_waves(activity_data),
          correlation_matrix: build_correlation_matrix(activity_data)
        }
      }
    end
  end

  defp analyze_temporal_correlations(system_ids) do
    Logger.debug("Analyzing temporal correlations for #{length(system_ids)} systems")

    if length(system_ids) < 2 do
      %{
        temporal_correlation_strength: 0.0,
        peak_correlation_times: [],
        correlation_lag: 0,
        lag_analysis: %{}
      }
    else
      # Get hourly activity data for all systems
      hourly_data = fetch_hourly_activity_data(system_ids)
      
      # Calculate temporal correlations with different lags
      lag_analysis = analyze_cross_correlation_lags(hourly_data)
      
      # Find peak correlation times
      peak_times = identify_peak_correlation_times(hourly_data)
      
      # Calculate overall temporal correlation strength
      temporal_strength = calculate_temporal_correlation_strength(lag_analysis)
      
      # Find optimal lag
      optimal_lag = find_optimal_lag(lag_analysis)
      
      %{
        temporal_correlation_strength: temporal_strength,
        peak_correlation_times: peak_times,
        correlation_lag: optimal_lag,
        lag_analysis: lag_analysis,
        temporal_patterns: %{
          daily_cycles: analyze_daily_cycles(hourly_data),
          weekly_patterns: analyze_weekly_patterns(system_ids),
          activity_cascades: detect_activity_waves(hourly_data)
        }
      }
    end
  end

  defp analyze_activity_synchronization(system_ids) do
    # Analyze how synchronized activity is across systems
    if length(system_ids) < 2 do
      %{
        synchronization_score: 0.0,
        synchronized_activities: [],
        desynchronized_activities: []
      }
    else
      # Get activity data
      activity_data = fetch_systems_activity_data(system_ids)
      
      # Analyze synchronization patterns
      sync_patterns = analyze_sync_patterns(activity_data)
      
      # Calculate synchronization score
      sync_score = calculate_sync_score(sync_patterns)
      
      # Identify synchronized and desynchronized activities
      synchronized = identify_synchronized_activities(sync_patterns)
      desynchronized = identify_desynchronized_activities(sync_patterns)
      
      %{
        synchronization_score: sync_score,
        synchronized_activities: synchronized,
        desynchronized_activities: desynchronized,
        synchronization_patterns: sync_patterns
      }
    end
  end

  # Helper functions for activity correlation analysis
  
  defp fetch_systems_activity_data(system_ids) do
    # Fetch activity data for all systems
    start_time = DateTime.add(DateTime.utc_now(), -48 * 3600, :second)
    
    query = from k in "killmails_enriched",
      where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
      select: %{
        killmail_id: k.killmail_id,
        solar_system_id: k.solar_system_id,
        killmail_time: k.killmail_time,
        attacker_count: k.attacker_count,
        total_value: k.total_value
      },
      order_by: [desc: k.killmail_time],
      limit: 5000
    
    killmails = Repo.all(query)
    
    # Group by system
    killmails
    |> Enum.group_by(& &1.solar_system_id)
  rescue
    error ->
      Logger.error("Failed to fetch systems activity data: #{inspect(error)}")
      %{}
  end
  
  defp fetch_hourly_activity_data(system_ids) do
    # Fetch hourly activity data for correlation analysis
    start_time = DateTime.add(DateTime.utc_now(), -168 * 3600, :second) # 1 week
    
    query = from k in "killmails_enriched",
      where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
      group_by: [k.solar_system_id, fragment("date_trunc('hour', ?)", k.killmail_time)],
      select: %{
        system_id: k.solar_system_id,
        hour: fragment("date_trunc('hour', ?)", k.killmail_time),
        kill_count: count(k.killmail_id),
        total_value: sum(k.total_value)
      },
      order_by: [k.solar_system_id, fragment("date_trunc('hour', ?)", k.killmail_time)]
    
    results = Repo.all(query)
    
    # Group by system
    results
    |> Enum.group_by(& &1.system_id)
    |> Enum.map(fn {system_id, hours} ->
      hourly_data = 
        hours
        |> Enum.map(fn h -> {h.hour, h.kill_count} end)
        |> Map.new()
      
      {system_id, hourly_data}
    end)
    |> Map.new()
  rescue
    error ->
      Logger.error("Failed to fetch hourly activity data: #{inspect(error)}")
      %{}
  end
  
  defp calculate_pairwise_correlations(activity_data) do
    # Calculate correlation coefficients between system pairs
    systems = Map.keys(activity_data)
    
    if length(systems) < 2 do
      []
    else
      for s1 <- systems, s2 <- systems, s1 < s2 do
        data1 = Map.get(activity_data, s1, [])
        data2 = Map.get(activity_data, s2, [])
        
        correlation = calculate_correlation_coefficient(data1, data2)
        {{s1, s2}, correlation}
      end
    end
  end
  
  defp calculate_correlation_coefficient(data1, data2) do
    # Calculate Pearson correlation coefficient
    if length(data1) < 3 or length(data2) < 3 do
      0.0
    else
      # Extract activity counts
      values1 = data1 |> Enum.map(& &1.attacker_count || 1)
      values2 = data2 |> Enum.map(& &1.attacker_count || 1)
      
      # Align data by time (simplified)
      min_length = min(length(values1), length(values2))
      aligned1 = Enum.take(values1, min_length)
      aligned2 = Enum.take(values2, min_length)
      
      # Calculate correlation
      mean1 = Enum.sum(aligned1) / length(aligned1)
      mean2 = Enum.sum(aligned2) / length(aligned2)
      
      numerator = 
        Enum.zip(aligned1, aligned2)
        |> Enum.map(fn {x, y} -> (x - mean1) * (y - mean2) end)
        |> Enum.sum()
      
      denominator1 = 
        aligned1
        |> Enum.map(fn x -> (x - mean1) * (x - mean1) end)
        |> Enum.sum()
      
      denominator2 = 
        aligned2
        |> Enum.map(fn y -> (y - mean2) * (y - mean2) end)
        |> Enum.sum()
      
      denominator = :math.sqrt(denominator1 * denominator2)
      
      if denominator > 0 do
        Float.round(numerator / denominator, 3)
      else
        0.0
      end
    end
  end
  
  defp identify_synchronized_systems(activity_data) do
    # Identify systems with synchronized activity
    correlations = calculate_pairwise_correlations(activity_data)
    
    # Find systems with high correlation (>0.7)
    synchronized_pairs = 
      correlations
      |> Enum.filter(fn {_pair, correlation} -> correlation > 0.7 end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
    
    # Extract unique systems
    synchronized_pairs
    |> Enum.flat_map(fn {{s1, s2}, _} -> [s1, s2] end)
    |> Enum.uniq()
  end
  
  defp analyze_synchronization_patterns(activity_data) do
    # Analyze different types of synchronization patterns
    correlations = calculate_pairwise_correlations(activity_data)
    
    # Group by correlation strength
    strong_sync = correlations |> Enum.filter(fn {_, r} -> r > 0.8 end)
    moderate_sync = correlations |> Enum.filter(fn {_, r} -> r > 0.5 and r <= 0.8 end)
    weak_sync = correlations |> Enum.filter(fn {_, r} -> r > 0.3 and r <= 0.5 end)
    
    %{
      strong_synchronization: strong_sync,
      moderate_synchronization: moderate_sync,
      weak_synchronization: weak_sync,
      synchronization_clusters: identify_sync_clusters(strong_sync)
    }
  end
  
  defp identify_sync_clusters(strong_correlations) do
    # Find clusters of strongly synchronized systems
    if length(strong_correlations) == 0 do
      []
    else
      # Group systems that are all correlated with each other
      systems = 
        strong_correlations
        |> Enum.flat_map(fn {{s1, s2}, _} -> [s1, s2] end)
        |> Enum.uniq()
      
      # Find fully connected clusters
      clusters = find_connected_components(systems, strong_correlations)
      
      clusters
      |> Enum.map(fn cluster ->
        %{
          systems: cluster,
          size: length(cluster),
          avg_correlation: calculate_cluster_avg_correlation(cluster, strong_correlations)
        }
      end)
    end
  end
  
  defp calculate_synchronization_level(synchronized_systems, system_ids) do
    # Calculate overall synchronization level
    if length(system_ids) == 0 do
      0.0
    else
      sync_ratio = length(synchronized_systems) / length(system_ids)
      Float.round(sync_ratio, 2)
    end
  end
  
  defp identify_temporal_clusters(activity_data) do
    # Identify temporal clustering of activity
    all_activities = 
      activity_data
      |> Enum.flat_map(fn {_system, activities} -> activities end)
      |> Enum.sort_by(& &1.killmail_time)
    
    # Group activities by time windows
    time_clusters = 
      all_activities
      |> Enum.chunk_by(fn activity ->
        activity.killmail_time |> DateTime.truncate(:hour)
      end)
      |> Enum.filter(fn cluster -> length(cluster) > 3 end)
      |> Enum.map(fn cluster ->
        %{
          time_window: List.first(cluster).killmail_time,
          activity_count: length(cluster),
          systems_involved: cluster |> Enum.map(& &1.solar_system_id) |> Enum.uniq(),
          total_value: cluster |> Enum.map(& &1.total_value || 0) |> Enum.sum()
        }
      end)
    
    time_clusters
  end
  
  defp detect_activity_waves(activity_data) do
    # Detect waves of activity propagating across systems
    if map_size(activity_data) < 2 do
      []
    else
      # Find temporal sequences of activity
      activity_timeline = 
        activity_data
        |> Enum.flat_map(fn {system, activities} ->
          activities |> Enum.map(fn a -> Map.put(a, :system_id, system) end)
        end)
        |> Enum.sort_by(& &1.killmail_time)
      
      # Group into potential waves
      waves = 
        activity_timeline
        |> Enum.chunk_every(10, 5, :discard)
        |> Enum.map(fn chunk ->
          systems = chunk |> Enum.map(& &1.system_id) |> Enum.uniq()
          time_span = calculate_time_span(chunk)
          
          %{
            systems: systems,
            start_time: List.first(chunk).killmail_time,
            end_time: List.last(chunk).killmail_time,
            duration_minutes: time_span.minutes,
            activity_count: length(chunk),
            propagation_speed: calculate_propagation_speed(chunk)
          }
        end)
        |> Enum.filter(fn wave -> length(wave.systems) > 1 end)
      
      waves
    end
  end
  
  defp build_correlation_matrix(correlations) do
    # Build correlation matrix from pairwise correlations
    if length(correlations) == 0 do
      %{}
    else
      # Get all systems
      all_systems = 
        correlations
        |> Enum.flat_map(fn {{s1, s2}, _} -> [s1, s2] end)
        |> Enum.uniq()
        |> Enum.sort()
      
      # Build matrix
      matrix = 
        for s1 <- all_systems, s2 <- all_systems, into: %{} do
          correlation = cond do
            s1 == s2 -> 1.0
            s1 < s2 -> 
              correlations
              |> Enum.find(fn {{sys1, sys2}, _} -> sys1 == s1 and sys2 == s2 end)
              |> case do
                nil -> 0.0
                {_, corr} -> corr
              end
            s1 > s2 -> 
              correlations
              |> Enum.find(fn {{sys1, sys2}, _} -> sys1 == s2 and sys2 == s1 end)
              |> case do
                nil -> 0.0
                {_, corr} -> corr
              end
          end
          
          {{s1, s2}, correlation}
        end
      
      %{
        systems: all_systems,
        matrix: matrix,
        size: length(all_systems)
      }
    end
  end
  
  defp analyze_cross_correlation_lags(hourly_data) do
    # Analyze cross-correlation with time lags
    if map_size(hourly_data) < 2 do
      %{}
    else
      systems = Map.keys(hourly_data)
      
      lag_analysis = 
        for s1 <- systems, s2 <- systems, s1 < s2, into: %{} do
          data1 = Map.get(hourly_data, s1, %{})
          data2 = Map.get(hourly_data, s2, %{})
          
          # Calculate cross-correlation for different lags
          lags = -12..12 # -12 to +12 hours
          
          correlations = 
            Enum.map(lags, fn lag ->
              correlation = calculate_lagged_correlation(data1, data2, lag)
              {lag, correlation}
            end)
          
          {{s1, s2}, correlations}
        end
      
      lag_analysis
    end
  end
  
  defp identify_peak_correlation_times(hourly_data) do
    # Find times when correlation peaks
    if map_size(hourly_data) < 2 do
      []
    else
      # Get all time points
      all_times = 
        hourly_data
        |> Enum.flat_map(fn {_system, hours} -> Map.keys(hours) end)
        |> Enum.uniq()
        |> Enum.sort()
      
      # Calculate correlation for each time point
      time_correlations = 
        all_times
        |> Enum.map(fn time ->
          # Get activity for all systems at this time
          activity_at_time = 
            hourly_data
            |> Enum.map(fn {system, hours} ->
              activity = Map.get(hours, time, 0)
              {system, activity}
            end)
          
          # Calculate variance in activity levels
          activities = Enum.map(activity_at_time, &elem(&1, 1))
          variance = calculate_variance(activities)
          
          %{
            time: time,
            variance: variance,
            total_activity: Enum.sum(activities),
            active_systems: Enum.count(activities, &(&1 > 0))
          }
        end)
      
      # Find peaks (high activity with low variance = synchronized)
      time_correlations
      |> Enum.filter(fn tc -> tc.total_activity > 5 and tc.variance < 10 end)
      |> Enum.sort_by(& &1.total_activity, :desc)
      |> Enum.take(5)
      |> Enum.map(& &1.time)
    end
  end
  
  defp calculate_temporal_correlation_strength(lag_analysis) do
    # Calculate overall temporal correlation strength
    if map_size(lag_analysis) == 0 do
      0.0
    else
      # Find maximum correlations across all lags
      max_correlations = 
        lag_analysis
        |> Enum.map(fn {_pair, correlations} ->
          correlations
          |> Enum.map(&elem(&1, 1))
          |> Enum.max()
        end)
      
      if length(max_correlations) > 0 do
        avg_max = Enum.sum(max_correlations) / length(max_correlations)
        Float.round(avg_max, 2)
      else
        0.0
      end
    end
  end
  
  defp find_optimal_lag(lag_analysis) do
    # Find the most common optimal lag
    if map_size(lag_analysis) == 0 do
      0
    else
      optimal_lags = 
        lag_analysis
        |> Enum.map(fn {_pair, correlations} ->
          correlations
          |> Enum.max_by(&elem(&1, 1))
          |> elem(0)
        end)
      
      # Find most common lag
      optimal_lags
      |> Enum.frequencies()
      |> Enum.max_by(&elem(&1, 1))
      |> elem(0)
    end
  end
  
  defp analyze_daily_cycles(hourly_data) do
    # Analyze daily activity cycles
    if map_size(hourly_data) == 0 do
      []
    else
      # Extract hourly patterns across all systems
      hourly_patterns = 
        0..23
        |> Enum.map(fn hour ->
          # Get activity for this hour across all systems
          total_activity = 
            hourly_data
            |> Enum.map(fn {_system, hours} ->
              # Sum activity for this hour across all days
              hours
              |> Enum.filter(fn {time, _} -> time.hour == hour end)
              |> Enum.map(&elem(&1, 1))
              |> Enum.sum()
            end)
            |> Enum.sum()
          
          {hour, total_activity}
        end)
      
      # Find peak hours
      peak_hours = 
        hourly_patterns
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(3)
        |> Enum.map(&elem(&1, 0))
      
      # Calculate cycle strength
      activities = Enum.map(hourly_patterns, &elem(&1, 1))
      cycle_strength = calculate_cycle_strength(activities)
      
      [%{
        type: :daily_cycle,
        peak_hours: peak_hours,
        cycle_strength: cycle_strength,
        pattern: categorize_daily_pattern(peak_hours)
      }]
    end
  end
  
  defp analyze_weekly_patterns(system_ids) do
    # Analyze weekly activity patterns
    if length(system_ids) == 0 do
      []
    else
      # Get weekly data
      start_time = DateTime.add(DateTime.utc_now(), -14 * 24 * 3600, :second)
      
      query = from k in "killmails_enriched",
        where: k.solar_system_id in ^system_ids and k.killmail_time >= ^start_time,
        group_by: fragment("EXTRACT(DOW FROM ?)", k.killmail_time),
        select: %{
          day_of_week: fragment("EXTRACT(DOW FROM ?)", k.killmail_time),
          kill_count: count(k.killmail_id)
        }
      
      daily_activity = Repo.all(query)
      
      # Find peak days
      peak_days = 
        daily_activity
        |> Enum.sort_by(& &1.kill_count, :desc)
        |> Enum.take(3)
        |> Enum.map(& &1.day_of_week)
      
      [%{
        type: :weekly_pattern,
        peak_days: peak_days,
        activity_distribution: daily_activity
      }]
    end
  rescue
    error ->
      Logger.error("Failed to analyze weekly patterns: #{inspect(error)}")
      []
  end
  
  # Additional helper functions
  
  defp analyze_sync_patterns(activity_data) do
    # Analyze synchronization patterns
    correlations = calculate_pairwise_correlations(activity_data)
    
    %{
      correlation_count: length(correlations),
      avg_correlation: calculate_avg_correlation(correlations),
      sync_clusters: identify_sync_clusters(correlations |> Enum.filter(fn {_, r} -> r > 0.8 end))
    }
  end
  
  defp calculate_sync_score(sync_patterns) do
    # Calculate synchronization score
    if sync_patterns.correlation_count == 0 do
      0.0
    else
      base_score = sync_patterns.avg_correlation
      cluster_bonus = length(sync_patterns.sync_clusters) * 0.1
      
      Float.round(min(1.0, base_score + cluster_bonus), 2)
    end
  end
  
  defp identify_synchronized_activities(sync_patterns) do
    # Identify specific synchronized activities
    sync_patterns.sync_clusters
    |> Enum.map(fn cluster ->
      %{
        type: :coordinated_activity,
        systems: cluster.systems,
        correlation_strength: cluster.avg_correlation,
        activity_type: :pvp_engagement
      }
    end)
  end
  
  defp identify_desynchronized_activities(sync_patterns) do
    # Identify activities that are not synchronized
    # This would be systems with low correlation
    [%{
      type: :independent_activity,
      systems: [],
      reason: :insufficient_correlation
    }]
  end
  
  defp calculate_avg_correlation(correlations) do
    if length(correlations) == 0 do
      0.0
    else
      total = correlations |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      Float.round(total / length(correlations), 2)
    end
  end
  
  defp find_connected_components(systems, correlations) do
    # Find connected components in the correlation graph
    # Simplified implementation
    correlation_map = 
      correlations
      |> Enum.map(fn {{s1, s2}, _} -> {s1, s2} end)
      |> Enum.group_by(&elem(&1, 0))
      |> Enum.map(fn {s, pairs} -> {s, Enum.map(pairs, &elem(&1, 1))} end)
      |> Map.new()
    
    # Find clusters using simple traversal
    visited = MapSet.new()
    clusters = []
    
    systems
    |> Enum.reduce({visited, clusters}, fn system, {v, c} ->
      if MapSet.member?(v, system) do
        {v, c}
      else
        cluster = find_cluster(system, correlation_map, MapSet.new())
        {MapSet.union(v, cluster), [MapSet.to_list(cluster) | c]}
      end
    end)
    |> elem(1)
    |> Enum.filter(fn cluster -> length(cluster) > 1 end)
  end
  
  defp find_cluster(system, correlation_map, visited) do
    if MapSet.member?(visited, system) do
      visited
    else
      new_visited = MapSet.put(visited, system)
      neighbors = Map.get(correlation_map, system, [])
      
      neighbors
      |> Enum.reduce(new_visited, fn neighbor, acc ->
        find_cluster(neighbor, correlation_map, acc)
      end)
    end
  end
  
  defp calculate_cluster_avg_correlation(cluster, correlations) do
    # Calculate average correlation within a cluster
    pairs = for s1 <- cluster, s2 <- cluster, s1 < s2, do: {s1, s2}
    
    cluster_correlations = 
      correlations
      |> Enum.filter(fn {{s1, s2}, _} -> {s1, s2} in pairs end)
      |> Enum.map(&elem(&1, 1))
    
    if length(cluster_correlations) > 0 do
      Float.round(Enum.sum(cluster_correlations) / length(cluster_correlations), 2)
    else
      0.0
    end
  end
  
  defp calculate_time_span(activities) do
    if length(activities) == 0 do
      %{minutes: 0}
    else
      times = Enum.map(activities, & &1.killmail_time)
      first = Enum.min(times)
      last = Enum.max(times)
      
      %{
        minutes: DateTime.diff(last, first, :minute)
      }
    end
  end
  
  defp calculate_propagation_speed(activities) do
    # Calculate how fast activity propagates across systems
    if length(activities) < 2 do
      0.0
    else
      unique_systems = activities |> Enum.map(& &1.system_id) |> Enum.uniq() |> length()
      time_span = calculate_time_span(activities)
      
      if time_span.minutes > 0 do
        Float.round(unique_systems / time_span.minutes, 2)
      else
        0.0
      end
    end
  end
  
  defp calculate_lagged_correlation(data1, data2, lag) do
    # Calculate correlation with time lag
    # Simplified implementation
    times1 = Map.keys(data1) |> Enum.sort()
    times2 = Map.keys(data2) |> Enum.sort()
    
    if length(times1) < 3 or length(times2) < 3 do
      0.0
    else
      # Apply lag and calculate correlation
      lagged_times2 = 
        times2
        |> Enum.map(fn time -> DateTime.add(time, lag * 3600, :second) end)
      
      # Find overlapping times
      overlapping_times = 
        times1
        |> Enum.filter(fn t1 -> 
          Enum.any?(lagged_times2, fn t2 -> abs(DateTime.diff(t1, t2, :minute)) < 30 end)
        end)
      
      if length(overlapping_times) < 3 do
        0.0
      else
        # Calculate correlation for overlapping times
        values1 = Enum.map(overlapping_times, fn t -> Map.get(data1, t, 0) end)
        values2 = Enum.map(overlapping_times, fn t -> 
          # Find closest lagged time
          closest_lagged = Enum.min_by(lagged_times2, fn t2 -> abs(DateTime.diff(t, t2, :minute)) end)
          original_time = DateTime.add(closest_lagged, -lag * 3600, :second)
          Map.get(data2, original_time, 0)
        end)
        
        calculate_simple_correlation(values1, values2)
      end
    end
  end
  
  defp calculate_simple_correlation(values1, values2) do
    # Simple correlation calculation
    if length(values1) != length(values2) or length(values1) < 2 do
      0.0
    else
      mean1 = Enum.sum(values1) / length(values1)
      mean2 = Enum.sum(values2) / length(values2)
      
      numerator = 
        Enum.zip(values1, values2)
        |> Enum.map(fn {x, y} -> (x - mean1) * (y - mean2) end)
        |> Enum.sum()
      
      variance1 = Enum.map(values1, fn x -> (x - mean1) * (x - mean1) end) |> Enum.sum()
      variance2 = Enum.map(values2, fn y -> (y - mean2) * (y - mean2) end) |> Enum.sum()
      
      denominator = :math.sqrt(variance1 * variance2)
      
      if denominator > 0 do
        Float.round(numerator / denominator, 3)
      else
        0.0
      end
    end
  end
  
  defp calculate_variance(values) do
    if length(values) < 2 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      variance = Enum.map(values, fn x -> (x - mean) * (x - mean) end) |> Enum.sum()
      variance / length(values)
    end
  end
  
  defp calculate_cycle_strength(activities) do
    # Calculate how strong the daily cycle is
    if length(activities) < 4 do
      0.0
    else
      variance = calculate_variance(activities)
      mean = Enum.sum(activities) / length(activities)
      
      if mean > 0 do
        coefficient_of_variation = :math.sqrt(variance) / mean
        Float.round(coefficient_of_variation, 2)
      else
        0.0
      end
    end
  end
  
  defp categorize_daily_pattern(peak_hours) do
    # Categorize the daily activity pattern
    cond do
      Enum.all?(peak_hours, fn h -> h >= 16 and h <= 23 end) -> :evening_peak
      Enum.all?(peak_hours, fn h -> h >= 8 and h <= 16 end) -> :day_peak
      Enum.all?(peak_hours, fn h -> h >= 0 and h <= 8 end) -> :night_peak
      true -> :distributed
    end
  end
end
