defmodule EveDmv.Shared.Correlation.TemporalCorrelationAnalyzer do
  @moduledoc """
  Analyzes temporal correlations between activities across systems.

  Provides statistical analysis for:
  - Temporal correlation between activities
  - Lag relationships between systems
  - Synchronized patterns detection
  - Activity dependencies analysis
  - Cross-system correlation metrics
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @doc """
  Analyzes temporal correlations between activities in a timeline.
  """
  def analyze_temporal_correlations(activity_timeline) do
    events = Map.get(activity_timeline, :events, [])

    if length(events) < 2 do
      %{
        correlation_found: false,
        correlation_strength: 0.0,
        patterns: [],
        time_dependencies: [],
        cross_system_correlations: []
      }
    else
      # Group events by various dimensions for analysis
      by_system = group_events_by_system(events)
      by_entity = group_events_by_entity(events)
      by_time_window = group_events_by_time_window(events)

      %{
        correlation_found: detect_correlations(by_system, by_time_window),
        correlation_strength: calculate_overall_correlation_strength(events),
        patterns: identify_correlation_patterns(events),
        time_dependencies: analyze_time_dependencies(by_system),
        cross_system_correlations: analyze_cross_system_correlations(by_system),
        entity_correlations: analyze_entity_correlations(by_entity),
        temporal_clusters: identify_temporal_clusters(events)
      }
    end
  end

  @doc """
  Calculates activity correlation between two activity sets.
  """
  def calculate_activity_correlation(activities1, activities2, options \\ []) do
    window_size = Keyword.get(options, :window_size_minutes, 5)
    lag_minutes = Keyword.get(options, :lag_minutes, 0)

    # Convert to time series
    series1 = create_time_series(activities1, window_size)
    series2 = create_time_series(activities2, window_size)

    # Apply lag if specified
    series2_lagged =
      if lag_minutes > 0 do
        apply_lag_to_series(series2, lag_minutes)
      else
        series2
      end

    # Calculate correlation coefficient
    correlation = calculate_correlation_coefficient(series1, series2_lagged)

    %{
      correlation_coefficient: correlation,
      lag_applied: lag_minutes,
      window_size: window_size,
      sample_size: min(length(series1), length(series2_lagged)),
      significance: calculate_significance(correlation, length(series1)),
      correlation_type: classify_correlation(correlation)
    }
  end

  @doc """
  Identifies lag relationships between system timelines.
  """
  def identify_lag_relationships(system_timelines, options \\ []) do
    max_lag = Keyword.get(options, :max_lag_minutes, 60)
    min_correlation = Keyword.get(options, :min_correlation, 0.5)

    # Test various lag values to find relationships
    lag_relationships =
      for {system1_id, timeline1} <- system_timelines,
          {system2_id, timeline2} <- system_timelines,
          system1_id != system2_id do
        # Test different lag values
        lag_tests = test_lag_values(timeline1, timeline2, max_lag)

        # Find best lag
        best_lag = find_best_lag(lag_tests, min_correlation)

        if best_lag do
          %{
            leading_system: system1_id,
            following_system: system2_id,
            lag_minutes: best_lag.lag_minutes,
            correlation: best_lag.correlation,
            confidence: best_lag.confidence,
            relationship_type: classify_lag_relationship(best_lag)
          }
        end
      end
      |> Enum.filter(&(&1 != nil))
      |> Enum.sort_by(& &1.correlation, :desc)

    %{
      relationships: lag_relationships,
      relationship_count: length(lag_relationships),
      average_lag: calculate_average_lag(lag_relationships),
      strongest_relationship: List.first(lag_relationships)
    }
  end

  @doc """
  Detects synchronized patterns across system timelines.
  """
  def detect_synchronized_patterns(system_timelines, options \\ []) do
    sync_threshold = Keyword.get(options, :sync_threshold_minutes, 2)
    min_systems = Keyword.get(options, :min_systems, 2)

    # Extract all events with system information
    all_events = extract_all_system_events(system_timelines)

    # Find synchronized events
    synchronized_patterns =
      all_events
      |> find_synchronized_events(sync_threshold)
      |> filter_by_system_count(min_systems)
      |> analyze_synchronization_patterns()

    %{
      patterns: synchronized_patterns,
      pattern_count: length(synchronized_patterns),
      synchronization_score: calculate_synchronization_score(synchronized_patterns),
      most_synchronized_systems: find_most_synchronized_systems(synchronized_patterns)
    }
  end

  @doc """
  Analyzes activity dependencies between systems.
  """
  def analyze_activity_dependencies(system_timelines, options \\ []) do
    min_confidence = Keyword.get(options, :min_confidence, 0.6)

    dependencies =
      for {system1_id, timeline1} <- system_timelines,
          {system2_id, timeline2} <- system_timelines,
          system1_id != system2_id do
        dependency = analyze_dependency(timeline1, timeline2)

        if dependency.confidence >= min_confidence do
          %{
            dependent_system: system1_id,
            influencing_system: system2_id,
            dependency_type: dependency.type,
            confidence: dependency.confidence,
            impact_factor: dependency.impact_factor,
            time_offset: dependency.time_offset
          }
        end
      end
      |> Enum.filter(&(&1 != nil))

    # Build dependency graph
    dependency_graph = build_dependency_graph(dependencies)

    %{
      dependencies: dependencies,
      dependency_count: length(dependencies),
      dependency_graph: dependency_graph,
      critical_systems: identify_critical_systems(dependency_graph),
      dependency_chains: find_dependency_chains(dependency_graph)
    }
  end

  # Private helper functions

  defp group_events_by_system(events) do
    Enum.group_by(events, & &1[:system_id])
  end

  defp group_events_by_entity(events) do
    Enum.group_by(events, & &1[:entity_id])
  end

  defp group_events_by_time_window(events, window_minutes \\ 5) do
    window_seconds = window_minutes * 60

    events
    |> Enum.group_by(fn event ->
      timestamp_seconds = DateTime.to_unix(event.timestamp)
      div(timestamp_seconds, window_seconds)
    end)
  end

  defp detect_correlations(_by_system, by_time_window) do
    # Check if multiple systems are active in same time windows
    active_windows =
      by_time_window
      |> Enum.filter(fn {_window, events} ->
        events
        |> Enum.map(& &1[:system_id])
        |> Enum.uniq()
        |> length() > 1
      end)

    # Correlation exists if we have multi-system activity windows
    length(active_windows) > 0
  end

  defp calculate_overall_correlation_strength(events) do
    # Group by time windows and analyze co-occurrence
    windows = group_events_by_time_window(events, 10)

    if map_size(windows) < 2 do
      0.0
    else
      # Calculate based on system diversity in time windows
      window_correlations =
        windows
        |> Enum.map(fn {_window, window_events} ->
          system_count =
            window_events
            |> Enum.map(& &1[:system_id])
            |> Enum.uniq()
            |> length()

          # More systems = stronger correlation
          min(system_count / 5.0, 1.0)
        end)

      # Average correlation across windows
      Enum.sum(window_correlations) / length(window_correlations)
    end
  end

  defp identify_correlation_patterns(events) do
    patterns = []

    # Pattern 1: Cascade pattern (activity spreads from system to system)
    cascade_patterns = identify_cascade_patterns(events)

    # Pattern 2: Burst pattern (simultaneous activity spikes)
    burst_patterns = identify_burst_patterns(events)

    # Pattern 3: Echo pattern (repeated activity patterns)
    echo_patterns = identify_echo_patterns(events)

    patterns ++ cascade_patterns ++ burst_patterns ++ echo_patterns
  end

  defp analyze_time_dependencies(by_system) do
    # Analyze how activity in one system relates to activity in others over time
    _dependencies = []

    system_pairs =
      for {sys1, _} <- by_system,
          {sys2, _} <- by_system,
          sys1 != sys2,
          do: {sys1, sys2}

    Enum.map(system_pairs, fn {sys1, sys2} ->
      events1 = Map.get(by_system, sys1, [])
      events2 = Map.get(by_system, sys2, [])

      %{
        system_pair: {sys1, sys2},
        temporal_overlap: calculate_temporal_overlap(events1, events2),
        lead_lag_relationship: determine_lead_lag(events1, events2),
        causality_score: estimate_causality(events1, events2)
      }
    end)
  end

  defp analyze_cross_system_correlations(by_system) do
    # Calculate pairwise correlations between systems
    system_ids = Map.keys(by_system)

    correlations =
      for sys1 <- system_ids,
          sys2 <- system_ids,
          sys1 < sys2 do
        events1 = Map.get(by_system, sys1, [])
        events2 = Map.get(by_system, sys2, [])

        correlation = calculate_system_correlation(events1, events2)

        %{
          systems: [sys1, sys2],
          correlation: correlation,
          shared_entities: find_shared_entities(events1, events2),
          time_alignment: calculate_time_alignment(events1, events2)
        }
      end

    # Sort by correlation strength
    Enum.sort_by(correlations, & &1.correlation, :desc)
  end

  defp analyze_entity_correlations(by_entity) do
    # Find entities that appear to coordinate activities
    entity_ids = Map.keys(by_entity)

    correlations =
      for entity1 <- entity_ids,
          entity2 <- entity_ids,
          entity1 < entity2 do
        events1 = Map.get(by_entity, entity1, [])
        events2 = Map.get(by_entity, entity2, [])

        if check_entity_interaction(events1, events2) do
          %{
            entities: [entity1, entity2],
            interaction_score: calculate_interaction_score(events1, events2),
            common_systems: find_common_systems(events1, events2),
            temporal_proximity: calculate_temporal_proximity(events1, events2)
          }
        end
      end
      |> Enum.filter(&(&1 != nil))

    Enum.sort_by(correlations, & &1.interaction_score, :desc)
  end

  defp identify_temporal_clusters(events) do
    # Use density-based clustering to find temporal activity clusters
    if length(events) < 3 do
      []
    else
      events
      |> Enum.sort_by(& &1.timestamp, DateTime)
      |> find_density_clusters()
      |> Enum.map(&analyze_cluster/1)
    end
  end

  defp create_time_series(activities, window_minutes) do
    if Enum.empty?(activities) do
      []
    else
      # Get time range
      timestamps = Enum.map(activities, & &1.timestamp)
      start_time = Enum.min(timestamps, DateTime)
      end_time = Enum.max(timestamps, DateTime)

      # Create windows
      windows = create_time_windows(start_time, end_time, window_minutes)

      # Count activities per window
      Enum.map(windows, fn {window_start, window_end} ->
        count =
          Enum.count(activities, fn activity ->
            DateTimeUtils.compare(activity.timestamp, window_start) != :lt and
              DateTimeUtils.compare(activity.timestamp, window_end) == :lt
          end)

        %{window_start: window_start, count: count}
      end)
    end
  end

  defp apply_lag_to_series(series, lag_minutes) do
    # Shift series forward by lag_minutes
    Enum.map(series, fn point ->
      %{point | window_start: DateTimeUtils.add(point.window_start, lag_minutes * 60, :second)}
    end)
  end

  defp calculate_correlation_coefficient(series1, series2) do
    if Enum.empty?(series1) or Enum.empty?(series2) do
      0.0
    else
      # Align series by time window
      aligned = align_time_series(series1, series2)

      if length(aligned) < 2 do
        0.0
      else
        # Calculate Pearson correlation coefficient
        values1 = Enum.map(aligned, & &1.count1)
        values2 = Enum.map(aligned, & &1.count2)

        calculate_pearson_correlation(values1, values2)
      end
    end
  end

  defp calculate_significance(correlation, sample_size) do
    if sample_size < 3 do
      :insufficient_data
    else
      # Simplified significance test
      abs_correlation = abs(correlation)

      cond do
        abs_correlation > 0.8 and sample_size > 10 -> :very_significant
        abs_correlation > 0.6 and sample_size > 5 -> :significant
        abs_correlation > 0.4 -> :moderate
        true -> :weak
      end
    end
  end

  defp classify_correlation(correlation) do
    cond do
      correlation > 0.8 -> :strong_positive
      correlation > 0.5 -> :moderate_positive
      correlation > 0.2 -> :weak_positive
      correlation > -0.2 -> :no_correlation
      correlation > -0.5 -> :weak_negative
      correlation > -0.8 -> :moderate_negative
      true -> :strong_negative
    end
  end

  defp test_lag_values(timeline1, timeline2, max_lag) do
    # Test lag values from 0 to max_lag
    0..max_lag//5
    |> Enum.map(fn lag ->
      correlation = calculate_activity_correlation(timeline1, timeline2, lag_minutes: lag)

      %{
        lag_minutes: lag,
        correlation: correlation.correlation_coefficient,
        confidence: calculate_lag_confidence(correlation)
      }
    end)
  end

  defp find_best_lag(lag_tests, min_correlation) do
    lag_tests
    |> Enum.filter(fn test -> abs(test.correlation) >= min_correlation end)
    |> Enum.max_by(fn test -> abs(test.correlation) end, fn -> nil end)
  end

  defp classify_lag_relationship(lag_data) do
    cond do
      lag_data.lag_minutes == 0 -> :synchronous
      lag_data.lag_minutes <= 5 -> :immediate_response
      lag_data.lag_minutes <= 30 -> :rapid_response
      lag_data.lag_minutes <= 120 -> :delayed_response
      true -> :long_term_influence
    end
  end

  defp calculate_average_lag(relationships) do
    if Enum.empty?(relationships) do
      0.0
    else
      total_lag = Enum.sum(Enum.map(relationships, & &1.lag_minutes))
      Float.round(total_lag / length(relationships), 1)
    end
  end

  defp extract_all_system_events(system_timelines) do
    system_timelines
    |> Enum.flat_map(fn {system_id, timeline} ->
      Enum.map(timeline, fn event ->
        Map.put(event, :system_id, system_id)
      end)
    end)
    |> Enum.sort_by(& &1.timestamp, DateTime)
  end

  defp find_synchronized_events(events, sync_threshold_minutes) do
    sync_threshold_seconds = sync_threshold_minutes * 60

    events
    |> Enum.group_by(fn event ->
      # Group by time buckets
      timestamp_seconds = DateTime.to_unix(event.timestamp)
      div(timestamp_seconds, sync_threshold_seconds)
    end)
    |> Map.values()
  end

  defp filter_by_system_count(event_groups, min_systems) do
    Enum.filter(event_groups, fn group ->
      group
      |> Enum.map(& &1.system_id)
      |> Enum.uniq()
      |> length() >= min_systems
    end)
  end

  defp analyze_synchronization_patterns(synchronized_groups) do
    Enum.map(synchronized_groups, fn group ->
      systems = Enum.map(group, & &1.system_id) |> Enum.uniq()

      %{
        timestamp: List.first(group).timestamp,
        systems: systems,
        event_count: length(group),
        synchronization_quality: calculate_sync_quality(group),
        pattern_type: determine_sync_pattern_type(group)
      }
    end)
  end

  defp calculate_synchronization_score(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      # Average synchronization quality
      qualities = Enum.map(patterns, & &1.synchronization_quality)
      Enum.sum(qualities) / length(qualities)
    end
  end

  defp find_most_synchronized_systems(patterns) do
    patterns
    |> Enum.flat_map(& &1.systems)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
  end

  defp analyze_dependency(timeline1, timeline2) do
    # Analyze if timeline1 depends on timeline2
    if Enum.empty?(timeline1) or Enum.empty?(timeline2) do
      %{type: :none, confidence: 0.0, impact_factor: 0.0, time_offset: 0}
    else
      # Check various dependency indicators
      temporal_dependency = check_temporal_dependency(timeline1, timeline2)
      causal_dependency = check_causal_dependency(timeline1, timeline2)

      %{
        type: determine_dependency_type(temporal_dependency, causal_dependency),
        confidence: calculate_dependency_confidence(temporal_dependency, causal_dependency),
        impact_factor: calculate_impact_factor(timeline1, timeline2),
        time_offset: calculate_time_offset(timeline1, timeline2)
      }
    end
  end

  defp build_dependency_graph(dependencies) do
    # Build adjacency list representation
    dependencies
    |> Enum.reduce(%{}, fn dep, graph ->
      Map.update(
        graph,
        dep.influencing_system,
        [dep.dependent_system],
        &[dep.dependent_system | &1]
      )
    end)
  end

  defp identify_critical_systems(dependency_graph) do
    # Systems that influence many others
    dependency_graph
    |> Enum.map(fn {system, dependents} -> {system, length(dependents)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
  end

  defp find_dependency_chains(dependency_graph) do
    # Find transitive dependency chains
    _chains = []

    # Simple chain detection (would need more sophisticated algorithm for cycles)
    Enum.map(dependency_graph, fn {start_system, _} ->
      find_chains_from(start_system, dependency_graph, [])
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  # Additional helper functions

  defp identify_cascade_patterns(_events) do
    # Implement cascade pattern detection
    []
  end

  defp identify_burst_patterns(_events) do
    # Implement burst pattern detection
    []
  end

  defp identify_echo_patterns(_events) do
    # Implement echo pattern detection
    []
  end

  defp calculate_temporal_overlap(_events1, _events2) do
    # Calculate percentage of time overlap
    # Simplified implementation
    0.5
  end

  defp determine_lead_lag(_events1, _events2) do
    # Determine which system leads/lags
    # Simplified
    :synchronous
  end

  defp estimate_causality(_events1, _events2) do
    # Estimate causal relationship strength
    # Simplified
    0.0
  end

  defp calculate_system_correlation(_events1, _events2) do
    # Calculate correlation between two system event lists
    # Simplified
    0.0
  end

  defp find_shared_entities(events1, events2) do
    entities1 = Enum.map(events1, & &1[:entity_id]) |> Enum.uniq()
    entities2 = Enum.map(events2, & &1[:entity_id]) |> Enum.uniq()

    MapSet.intersection(MapSet.new(entities1), MapSet.new(entities2))
    |> MapSet.to_list()
  end

  defp calculate_time_alignment(_events1, _events2) do
    # Calculate how well aligned the events are in time
    # Simplified
    0.0
  end

  defp check_entity_interaction(events1, events2) do
    # Check if entities interact (simplified)
    not (Enum.empty?(events1) or Enum.empty?(events2))
  end

  defp calculate_interaction_score(_events1, _events2) do
    # Calculate interaction strength
    # Simplified
    0.5
  end

  defp find_common_systems(events1, events2) do
    systems1 = Enum.map(events1, & &1[:system_id]) |> Enum.uniq()
    systems2 = Enum.map(events2, & &1[:system_id]) |> Enum.uniq()

    MapSet.intersection(MapSet.new(systems1), MapSet.new(systems2))
    |> MapSet.to_list()
  end

  defp calculate_temporal_proximity(_events1, _events2) do
    # Calculate how close in time the events are
    # Simplified
    0.5
  end

  defp find_density_clusters(_sorted_events) do
    # Simple density-based clustering
    # Simplified
    []
  end

  defp analyze_cluster(cluster) do
    %{
      events: cluster,
      size: length(cluster),
      duration: 0,
      density: 0.0
    }
  end

  defp create_time_windows(start_time, end_time, window_minutes) do
    window_seconds = window_minutes * 60
    windows = []

    create_windows_recursive(start_time, end_time, window_seconds, windows)
  end

  defp create_windows_recursive(current, end_time, window_seconds, acc) do
    if DateTimeUtils.compare(current, end_time) == :lt do
      window_end = DateTimeUtils.add(current, window_seconds, :second)
      new_window = {current, window_end}
      create_windows_recursive(window_end, end_time, window_seconds, [new_window | acc])
    else
      Enum.reverse(acc)
    end
  end

  defp align_time_series(_series1, _series2) do
    # Align two time series by matching windows
    # Simplified
    []
  end

  defp calculate_pearson_correlation(_values1, _values2) do
    # Calculate Pearson correlation coefficient
    # Simplified
    0.0
  end

  defp calculate_lag_confidence(correlation) do
    # Calculate confidence in lag relationship
    abs(correlation.correlation_coefficient)
  end

  defp calculate_sync_quality(_group) do
    # Calculate synchronization quality
    # Simplified
    0.5
  end

  defp determine_sync_pattern_type(_group) do
    # Determine type of synchronization pattern
    # Simplified
    :burst
  end

  defp check_temporal_dependency(timeline1, timeline2) do
    # Check temporal dependency indicators
    # Simple check based on timeline overlap
    length(timeline1) > 0 and length(timeline2) > 0
  end

  defp check_causal_dependency(_timeline1, _timeline2) do
    # Check causal dependency indicators
    # Simplified
    false
  end

  defp determine_dependency_type(temporal, _causal) do
    if temporal do
      :temporal_dependency
    else
      :no_dependency
    end
  end

  defp calculate_dependency_confidence(_temporal, _causal) do
    # Calculate confidence in dependency
    # Simplified
    0.5
  end

  defp calculate_impact_factor(_timeline1, _timeline2) do
    # Calculate impact factor
    # Simplified
    0.5
  end

  defp calculate_time_offset(_timeline1, _timeline2) do
    # Calculate average time offset
    # Simplified
    0
  end

  defp find_chains_from(system, graph, visited) do
    if system in visited do
      []
    else
      new_visited = [system | visited]
      dependents = Map.get(graph, system, [])

      if Enum.empty?(dependents) do
        [Enum.reverse(new_visited)]
      else
        Enum.flat_map(dependents, fn dep ->
          find_chains_from(dep, graph, new_visited)
        end)
      end
    end
  end
end
