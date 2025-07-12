defmodule EveDmv.Contexts.BattleAnalysis.Domain.MultiSystemBattleCorrelator do
  @moduledoc """
  Sophisticated algorithm for correlating battles across multiple wormhole systems.

  This module implements advanced correlation techniques specifically designed for wormhole
  PvP analysis, where battles often span multiple connected systems as participants 
  chase each other through wormhole chains.

  ## Algorithm Components

  1. **Temporal Clustering**: Groups killmails by time proximity
  2. **Participant Overlap Analysis**: Identifies shared participants across systems
  3. **System Adjacency Scoring**: Uses wormhole connection patterns
  4. **Combat Flow Analysis**: Tracks pursuit and engagement patterns
  5. **Multi-System Battle Merge**: Combines correlated battles into coherent narratives
  """

  require Logger
  alias EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractor

  # Correlation parameters optimized for wormhole PvP
  # Wormhole chases can be longer
  @max_multi_system_gap_minutes 30
  # 30% shared participants
  @min_participant_overlap_ratio 0.3
  # Minimum correlation to merge
  @min_correlation_score 0.6

  @doc """
  Correlates battles across multiple systems to identify multi-system engagements.

  This is the main entry point for sophisticated wormhole battle analysis.
  Takes detected single-system battles and correlates them into multi-system battles.

  ## Parameters
  - battles: List of single-system battles from BattleDetectionService
  - options: Correlation options
    - :max_time_gap - Maximum time gap between related battles (default: 30 minutes)
    - :min_overlap - Minimum participant overlap ratio (default: 0.3)
    - :system_connections - Map of known wormhole connections for proximity scoring

  ## Returns
  {:ok, correlated_battles} where each battle may span multiple systems
  """
  def correlate_multi_system_battles(battle_or_battles, options \\ [])

  def correlate_multi_system_battles(battle, options) when is_map(battle) do
    correlate_multi_system_battles([battle], options)
  end

  def correlate_multi_system_battles(battles, options) when is_list(battles) do
    max_time_gap = Keyword.get(options, :max_time_gap, @max_multi_system_gap_minutes)
    min_overlap = Keyword.get(options, :min_overlap, @min_participant_overlap_ratio)
    system_connections = Keyword.get(options, :system_connections, %{})

    # Ensure battles is a proper list
    battles_list =
      case battles do
        b when is_list(b) -> b
        b when is_map(b) -> [b]
        _ -> []
      end

    Logger.info("Correlating #{length(battles_list)} battles across multiple systems")

    Logger.debug(
      "Battles type: #{inspect(is_list(battles_list))}, battles: #{inspect(battles_list, limit: 1)}"
    )

    start_time = System.monotonic_time(:millisecond)

    # Step 1: Create temporal clusters of battles
    temporal_clusters = temporal_clustering(battles_list, max_time_gap)
    Logger.debug("Temporal clusters: #{inspect(length(temporal_clusters))} clusters")

    # Step 2: Analyze participant overlap within temporal clusters
    overlap_groups = analyze_participant_overlap(temporal_clusters, min_overlap)
    Logger.debug("Overlap groups: #{inspect(length(overlap_groups))} groups")

    # Step 3: Score system adjacency using wormhole connection data
    adjacency_scored = score_system_adjacency(overlap_groups, system_connections)
    Logger.debug("Adjacency scored: #{inspect(length(adjacency_scored))} scored groups")

    # Step 4: Apply sophisticated correlation algorithm
    correlated_battles = apply_correlation_algorithm(adjacency_scored)
    Logger.debug("Correlated results: #{inspect(length(correlated_battles))} results")

    # Step 5: Merge correlated battles into multi-system narratives
    final_battles = merge_correlated_battles(correlated_battles)
    Logger.debug("Final battles: #{inspect(length(final_battles))} battles")

    end_time = System.monotonic_time(:millisecond)
    duration_ms = end_time - start_time

    Logger.info("""
    Multi-system correlation completed in #{duration_ms}ms:
    - Input battles: #{length(battles_list)}
    - Output battles: #{length(final_battles)}
    - Multi-system battles: #{count_multi_system_battles(final_battles)}
    """)

    {:ok, final_battles}
  end

  @doc """
  Analyzes combat flow patterns across systems to identify pursuit scenarios.

  This advanced analysis identifies patterns where one group pursues another
  through multiple systems, creating complex multi-system narratives.
  """
  def analyze_combat_flow_patterns(correlated_battles) do
    flow_analyzed =
      Enum.map(correlated_battles, fn battle ->
        if Map.get(battle.metadata, :is_multi_system, false) do
          flow_pattern = detect_flow_pattern(battle)
          put_in(battle, [:metadata, :combat_flow], flow_pattern)
        else
          battle
        end
      end)

    {:ok, flow_analyzed}
  end

  # Private correlation algorithm implementation

  defp temporal_clustering(battles, max_time_gap) do
    # Sort battles by start time
    sorted_battles = Enum.sort_by(battles, &get_battle_start_time/1)

    # Group battles within temporal windows
    Enum.reduce(sorted_battles, [], fn battle, clusters ->
      add_to_temporal_cluster(battle, clusters, max_time_gap)
    end)
    |> Enum.reverse()
  end

  defp add_to_temporal_cluster(battle, [], _max_time_gap) do
    [[battle]]
  end

  defp add_to_temporal_cluster(battle, [current_cluster | rest], max_time_gap) do
    cluster_end_time = get_cluster_end_time(current_cluster)
    battle_start_time = get_battle_start_time(battle)

    time_gap_minutes = NaiveDateTime.diff(battle_start_time, cluster_end_time, :second) / 60

    if time_gap_minutes <= max_time_gap do
      # Add to current cluster
      [[battle | current_cluster] | rest]
    else
      # Start new cluster
      [[battle], current_cluster | rest]
    end
  end

  defp analyze_participant_overlap(temporal_clusters, min_overlap) do
    result =
      Enum.flat_map(temporal_clusters, fn cluster ->
        if length(cluster) > 1 do
          # Analyze overlap between all pairs in cluster
          overlap_analysis = calculate_pairwise_overlaps(cluster)
          group_by_overlap_threshold(cluster, overlap_analysis, min_overlap)
        else
          # Single battle cluster - no overlap to analyze
          # Keep it as a list of lists for consistency
          [cluster]
        end
      end)

    Logger.debug(
      "Overlap analysis result: #{inspect(length(result))} groups, each is list: #{inspect(Enum.all?(result, &is_list/1))}"
    )

    result
  end

  defp calculate_pairwise_overlaps(battles) do
    # Calculate participant overlap for all battle pairs
    for battle_a <- battles,
        battle_b <- battles,
        battle_a != battle_b do
      participants_a = extract_all_participants(battle_a)
      participants_b = extract_all_participants(battle_b)

      overlap_ratio = calculate_overlap_ratio(participants_a, participants_b)

      %{
        battle_a: battle_a,
        battle_b: battle_b,
        overlap_ratio: overlap_ratio,
        shared_participants: MapSet.intersection(participants_a, participants_b)
      }
    end
  end

  defp calculate_overlap_ratio(participants_a, participants_b) do
    intersection = MapSet.intersection(participants_a, participants_b)
    union = MapSet.union(participants_a, participants_b)

    if MapSet.size(union) > 0 do
      MapSet.size(intersection) / MapSet.size(union)
    else
      0.0
    end
  end

  defp group_by_overlap_threshold(battles, overlap_analysis, min_overlap) do
    # Create graph of battles connected by sufficient overlap
    connections =
      overlap_analysis
      |> Enum.filter(&(&1.overlap_ratio >= min_overlap))
      |> Enum.map(&{&1.battle_a, &1.battle_b})

    # Find connected components (groups of battles that should be correlated)
    find_connected_components(battles, connections)
  end

  defp find_connected_components(battles, connections) do
    # Simple connected components algorithm
    battle_graph = build_graph(battles, connections)
    find_components(battle_graph, MapSet.new(), [])
  end

  defp build_graph(battles, connections) do
    # Build adjacency list representation
    initial_graph = battles |> Enum.map(&{&1, []}) |> Map.new()

    Enum.reduce(connections, initial_graph, fn {battle_a, battle_b}, graph ->
      graph
      |> Map.update(battle_a, [battle_b], &[battle_b | &1])
      |> Map.update(battle_b, [battle_a], &[battle_a | &1])
    end)
  end

  defp find_components(graph, visited, components) do
    case find_unvisited_battle(graph, visited) do
      nil ->
        components

      start_battle ->
        component = depth_first_search(graph, start_battle, MapSet.new())
        new_visited = MapSet.union(visited, component)
        find_components(graph, new_visited, [MapSet.to_list(component) | components])
    end
  end

  defp find_unvisited_battle(graph, visited) do
    graph
    |> Map.keys()
    |> Enum.find(&(not MapSet.member?(visited, &1)))
  end

  defp depth_first_search(graph, battle, visited) do
    if MapSet.member?(visited, battle) do
      visited
    else
      new_visited = MapSet.put(visited, battle)
      neighbors = Map.get(graph, battle, [])

      Enum.reduce(neighbors, new_visited, fn neighbor, acc ->
        depth_first_search(graph, neighbor, acc)
      end)
    end
  end

  defp score_system_adjacency(battle_groups, system_connections) do
    Logger.debug("Scoring adjacency for #{inspect(length(battle_groups))} groups")
    Logger.debug("First group type check: #{inspect(List.first(battle_groups) |> is_list())}")

    Enum.map(battle_groups, fn group ->
      if is_list(group) do
        Logger.debug("Processing group type: list, size: #{inspect(length(group))}")

        if length(group) > 1 do
          # Calculate system adjacency scores for multi-battle groups
          adjacency_scores = calculate_system_adjacency_scores(group, system_connections)
          {group, adjacency_scores}
        else
          # Single battle group - no adjacency to score
          {group, %{}}
        end
      else
        Logger.error("ERROR: Group is not a list! Type: #{inspect(group)}")
        # Try to recover by wrapping in a list
        {[group], %{}}
      end
    end)
  end

  defp calculate_system_adjacency_scores(battles, system_connections) do
    # For each pair of battles, calculate how "close" their systems are
    # in the wormhole network topology
    for battle_a <- battles,
        battle_b <- battles,
        battle_a != battle_b do
      system_a = get_primary_system(battle_a)
      system_b = get_primary_system(battle_b)

      distance = calculate_system_distance(system_a, system_b, system_connections)

      %{
        battle_a: battle_a,
        battle_b: battle_b,
        system_distance: distance,
        # Closer systems have higher scores
        adjacency_score: 1.0 / (1.0 + distance)
      }
    end
  end

  defp calculate_system_distance(system_a, system_b, system_connections) do
    if system_a == system_b do
      0
    else
      # Use known wormhole connections or fall back to heuristic
      case Map.get(system_connections, {system_a, system_b}) do
        nil ->
          # No known connection - use heuristic based on system IDs
          # This is a fallback when we don't have wormhole mapping data
          estimate_wormhole_distance(system_a, system_b)

        distance ->
          distance
      end
    end
  end

  defp estimate_wormhole_distance(system_a, system_b) do
    # Heuristic: assume connected systems are within 1-3 jumps
    # This is a simplification - in production we'd use actual wormhole mapping
    cond do
      # Likely adjacent
      abs(system_a - system_b) < 1000 -> 1
      # Possibly connected
      abs(system_a - system_b) < 5000 -> 2
      # Distant systems
      true -> 3
    end
  end

  defp apply_correlation_algorithm(adjacency_scored_groups) do
    Logger.debug("Applying correlation to #{inspect(length(adjacency_scored_groups))} groups")

    Enum.map(adjacency_scored_groups, fn {group, adjacency_scores} ->
      # Ensure group is a list
      group_list = ensure_list(group)

      Logger.debug(
        "Correlation group type: #{inspect(is_list(group_list))}, size: #{inspect(length(group_list))}"
      )

      if length(group_list) > 1 do
        # Calculate overall correlation score for the group
        correlation_score = calculate_group_correlation_score(group_list, adjacency_scores)

        if correlation_score >= @min_correlation_score do
          {:correlate, group_list, correlation_score}
        else
          {:separate, group_list}
        end
      else
        {:separate, group_list}
      end
    end)
  end

  defp calculate_group_correlation_score(_battles, adjacency_scores) do
    if Enum.empty?(adjacency_scores) do
      0.0
    else
      # Weighted average of adjacency scores
      total_score = Enum.sum(Enum.map(adjacency_scores, & &1.adjacency_score))
      count = length(adjacency_scores)
      total_score / count
    end
  end

  defp merge_correlated_battles(correlation_results) do
    Enum.flat_map(correlation_results, fn
      {:correlate, battles, correlation_score} ->
        [merge_battles_into_multi_system(battles, correlation_score)]

      {:separate, battles} ->
        battles
    end)
  end

  defp merge_battles_into_multi_system(battles, correlation_score) do
    # Merge multiple single-system battles into one multi-system battle
    all_killmails = Enum.flat_map(battles, & &1.killmails)
    systems_involved = battles |> Enum.map(&get_primary_system/1) |> Enum.uniq()

    # Create comprehensive metadata for multi-system battle
    metadata = create_multi_system_metadata(battles, correlation_score)

    # Generate battle ID that reflects multi-system nature
    battle_id = generate_multi_system_battle_id(battles)

    %{
      battle_id: battle_id,
      killmails: all_killmails,
      metadata: metadata,
      systems_involved: systems_involved,
      # Keep reference to original single-system battles
      sub_battles: battles
    }
  end

  defp create_multi_system_metadata(battles, correlation_score) do
    # Ensure battles is a list
    battles_list = ensure_list(battles)
    base_metadata = create_merged_metadata(battles_list)

    Map.merge(base_metadata, %{
      is_multi_system: true,
      correlation_score: correlation_score,
      systems_count: length(battles_list),
      battle_flow: analyze_battle_flow(battles_list),
      engagement_type: classify_multi_system_engagement(battles_list)
    })
  end

  defp ensure_list(battles) when is_list(battles), do: battles
  defp ensure_list(battle) when is_map(battle), do: [battle]
  defp ensure_list(_), do: []

  defp create_merged_metadata(battles) do
    all_killmails = Enum.flat_map(battles, & &1.killmails)

    # Calculate comprehensive statistics across all battles
    %{
      killmail_count: length(all_killmails),
      duration_minutes: calculate_multi_system_duration(battles),
      unique_participants: count_unique_participants_across_battles(battles),
      systems_involved: battles |> Enum.map(&get_primary_system/1) |> Enum.uniq(),
      battle_phases: identify_battle_phases(battles),
      total_isk_destroyed: Enum.sum(Enum.map(battles, &get_battle_isk_value/1))
    }
  end

  defp analyze_battle_flow(battles) do
    # Analyze temporal and spatial flow of the multi-system battle
    sorted_battles = Enum.sort_by(battles, &get_battle_start_time/1)

    flow_events =
      Enum.with_index(sorted_battles)
      |> Enum.map(fn {battle, index} ->
        %{
          sequence: index + 1,
          system_id: get_primary_system(battle),
          start_time: get_battle_start_time(battle),
          participants: extract_all_participants(battle) |> MapSet.size(),
          battle_type: battle.metadata.battle_type
        }
      end)

    %{
      events: flow_events,
      pattern: detect_flow_pattern_from_events(flow_events)
    }
  end

  defp detect_flow_pattern(battle) do
    # Analyze the flow pattern of a multi-system battle
    events = battle.metadata.battle_flow.events

    cond do
      length(events) <= 1 ->
        :single_system

      shows_pursuit_pattern?(events) ->
        :pursuit

      shows_running_battle_pattern?(events) ->
        :running_battle

      shows_staged_engagement_pattern?(events) ->
        :staged_engagement

      true ->
        :complex_multi_system
    end
  end

  defp detect_flow_pattern_from_events(events) do
    cond do
      length(events) <= 1 ->
        :single_system

      shows_pursuit_pattern?(events) ->
        :pursuit

      shows_running_battle_pattern?(events) ->
        :running_battle

      shows_staged_engagement_pattern?(events) ->
        :staged_engagement

      true ->
        :complex_multi_system
    end
  end

  defp shows_pursuit_pattern?(events) do
    # Pursuit: decreasing participant count over time suggests chase scenario
    participant_counts = Enum.map(events, & &1.participants)

    # Check if participant count generally decreases
    decreasing_trend = calculate_trend(participant_counts) < -0.1

    # Check if there are multiple systems involved
    systems = events |> Enum.map(& &1.system_id) |> Enum.uniq()
    multiple_systems = length(systems) > 1

    decreasing_trend and multiple_systems
  end

  defp shows_running_battle_pattern?(events) do
    # Running battle: participants stay similar across systems
    participant_counts = Enum.map(events, & &1.participants)

    # Check for stable participant count (low variance)
    variance = calculate_variance(participant_counts)
    stable_participants = variance < 2.0

    # Check for multiple systems
    systems = events |> Enum.map(& &1.system_id) |> Enum.uniq()
    multiple_systems = length(systems) > 1

    stable_participants and multiple_systems
  end

  defp shows_staged_engagement_pattern?(events) do
    # Staged: increasing participant count suggests reinforcement
    participant_counts = Enum.map(events, & &1.participants)

    # Check if participant count generally increases
    increasing_trend = calculate_trend(participant_counts) > 0.1

    # Check for multiple systems
    systems = events |> Enum.map(& &1.system_id) |> Enum.uniq()
    multiple_systems = length(systems) > 1

    increasing_trend and multiple_systems
  end

  defp classify_multi_system_engagement(battles) do
    systems_count = battles |> Enum.map(&get_primary_system/1) |> Enum.uniq() |> length()
    total_participants = count_unique_participants_across_battles(battles)

    cond do
      systems_count >= 4 -> :extended_chase
      systems_count == 3 -> :complex_engagement
      systems_count == 2 and total_participants > 20 -> :major_running_battle
      systems_count == 2 -> :two_system_engagement
      true -> :single_system
    end
  end

  # Utility functions

  defp get_battle_start_time(battle) do
    case battle do
      %{metadata: %{start_time: start_time}} -> start_time
      %{start_time: start_time} -> start_time
      %{killmails: [first | _]} -> first.killmail_time
      _ -> ~N[1970-01-01 00:00:00]
    end
  end

  defp get_cluster_end_time(cluster) do
    cluster
    |> Enum.map(&get_battle_start_time/1)
    |> Enum.max()
  end

  defp get_primary_system(battle) do
    case battle do
      %{metadata: %{primary_system: system}} -> system
      %{system_id: system} -> system
      %{killmails: [first | _]} -> first.solar_system_id
      _ -> nil
    end
  end

  defp extract_all_participants(battle) do
    battle.killmails
    |> Enum.flat_map(&ParticipantExtractor.extract_participants/1)
    |> MapSet.new()
  end

  defp count_unique_participants_across_battles(battles) do
    battles
    |> Enum.flat_map(fn battle ->
      battle.killmails
      |> Enum.flat_map(&ParticipantExtractor.extract_participants/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_multi_system_duration(battles) do
    all_times =
      battles
      |> Enum.flat_map(& &1.killmails)
      |> Enum.map(& &1.killmail_time)

    case all_times do
      [] ->
        0

      [_single] ->
        1

      multiple ->
        start_time = Enum.min(multiple)
        end_time = Enum.max(multiple)
        NaiveDateTime.diff(end_time, start_time, :second) / 60
    end
  end

  defp identify_battle_phases(battles) do
    # For now, return simple phase identification
    # This will be enhanced with the tactical phase detection algorithm
    Enum.with_index(battles)
    |> Enum.map(fn {battle, index} ->
      %{
        phase: index + 1,
        system: get_primary_system(battle),
        type: battle.metadata.battle_type,
        duration: battle.metadata.duration_minutes
      }
    end)
  end

  defp get_battle_isk_value(battle) do
    Map.get(battle.metadata, :isk_destroyed, 0)
  end

  defp generate_multi_system_battle_id(battles) do
    systems = battles |> Enum.map(&get_primary_system/1) |> Enum.sort()
    first_battle = Enum.min_by(battles, &get_battle_start_time/1)

    timestamp =
      first_battle
      |> get_battle_start_time()
      |> NaiveDateTime.to_string()
      |> String.replace([" ", ":", "-"], "")

    system_str = systems |> Enum.join("_")
    "multi_battle_#{system_str}_#{timestamp}"
  end

  defp count_multi_system_battles(battles) do
    Enum.count(battles, &(Map.get(&1, :systems_involved, []) |> length() > 1))
  end

  defp calculate_trend(values) do
    # Simple linear trend calculation
    if length(values) < 2 do
      0
    else
      n = length(values)
      indices = 1..n |> Enum.to_list()

      sum_x = Enum.sum(indices)
      sum_y = Enum.sum(values)
      sum_xy = indices |> Enum.zip(values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x2 = indices |> Enum.map(&(&1 * &1)) |> Enum.sum()

      # Linear regression slope
      (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    end
  end

  defp calculate_variance(values) do
    if length(values) < 2 do
      0
    else
      mean = Enum.sum(values) / length(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean, 2)) |> Enum.sum()
      variance_sum / length(values)
    end
  end
end
