defmodule EveDmv.Shared.Strategic.CorrelationEngine do
  @moduledoc """
  Handles cross-system correlations and clustering for strategic analysis.

  Responsible for:
  - System correlation analysis
  - Graph algorithms for connectivity
  - Activity clustering
  - Relationship detection
  """

  require Logger

  @doc """
  Analyzes correlations between systems based on activity patterns.
  """
  def analyze_system_correlations(strategic_data, options \\ []) do
    correlation_threshold = Keyword.get(options, :correlation_threshold, 0.7)

    case strategic_data.scope do
      :multi_system ->
        system_pairs = generate_system_pairs(strategic_data.killmail_data)
        correlations = calculate_correlations(system_pairs, strategic_data.killmail_data)

        %{
          correlation_matrix: build_correlation_matrix(correlations),
          strong_correlations: filter_strong_correlations(correlations, correlation_threshold),
          system_clusters: identify_system_clusters(correlations, correlation_threshold),
          connectivity_graph: build_connectivity_graph(correlations, correlation_threshold)
        }

      :single_system ->
        %{
          correlation_matrix: %{},
          strong_correlations: [],
          system_clusters: [],
          connectivity_graph: %{nodes: [strategic_data.system_id], edges: []}
        }
    end
  end

  @doc """
  Performs graph analysis on system connections.
  """
  def analyze_graph_connectivity(connectivity_graph) do
    %{
      node_count: length(connectivity_graph.nodes),
      edge_count: length(connectivity_graph.edges),
      average_degree: calculate_average_degree(connectivity_graph),
      connected_components: find_connected_components(connectivity_graph),
      central_nodes: identify_central_nodes(connectivity_graph),
      bridge_nodes: identify_bridge_nodes(connectivity_graph)
    }
  end

  @doc """
  Clusters systems based on activity patterns.
  """
  def cluster_systems_by_activity(strategic_data, options \\ []) do
    min_cluster_size = Keyword.get(options, :min_cluster_size, 2)

    case strategic_data.scope do
      :multi_system ->
        activity_vectors = build_activity_vectors(strategic_data.killmail_data)
        clusters = perform_clustering(activity_vectors, min_cluster_size)

        %{
          cluster_count: length(clusters),
          clusters: Enum.map(clusters, &analyze_cluster/1),
          outliers: identify_outliers(activity_vectors, clusters),
          cluster_quality: assess_cluster_quality(clusters)
        }

      :single_system ->
        %{
          cluster_count: 1,
          clusters: [%{systems: [strategic_data.system_id], size: 1, cohesion: 1.0}],
          outliers: [],
          cluster_quality: 1.0
        }
    end
  end

  @doc """
  Detects relationships between entities across systems.
  """
  def detect_cross_system_relationships(strategic_data) do
    killmails = extract_all_killmails(strategic_data)

    entity_movements = track_entity_movements(killmails)
    shared_engagements = find_shared_engagements(killmails)
    coordination_patterns = detect_coordination_patterns(entity_movements, shared_engagements)

    %{
      entity_movements: entity_movements,
      shared_engagements: shared_engagements,
      coordination_patterns: coordination_patterns,
      relationship_strength: calculate_relationship_strengths(coordination_patterns)
    }
  end

  # Private functions

  defp generate_system_pairs(killmail_data) do
    system_ids = Enum.map(killmail_data, & &1.system_id)

    for s1 <- system_ids, s2 <- system_ids, s1 < s2, do: {s1, s2}
  end

  defp calculate_correlations(system_pairs, killmail_data) do
    killmail_map = Map.new(killmail_data, fn data -> {data.system_id, data.killmails} end)

    Enum.map(system_pairs, fn {s1, s2} ->
      kills1 = Map.get(killmail_map, s1, [])
      kills2 = Map.get(killmail_map, s2, [])

      correlation = calculate_activity_correlation(kills1, kills2)

      %{
        systems: {s1, s2},
        correlation: correlation,
        shared_entities: find_shared_entities(kills1, kills2),
        temporal_overlap: calculate_temporal_overlap(kills1, kills2)
      }
    end)
  end

  defp calculate_activity_correlation(kills1, kills2) do
    # Time-based correlation
    time_windows = create_hourly_windows(kills1 ++ kills2)

    activity1 = count_kills_by_window(kills1, time_windows)
    activity2 = count_kills_by_window(kills2, time_windows)

    if length(activity1) > 2 do
      calculate_pearson_correlation(activity1, activity2)
    else
      0.0
    end
  end

  defp create_hourly_windows(killmails) do
    if length(killmails) == 0 do
      []
    else
      min_time = Enum.min_by(killmails, & &1.timestamp).timestamp
      max_time = Enum.max_by(killmails, & &1.timestamp).timestamp

      hours_diff = div(DateTime.diff(max_time, min_time, :second), 3600)

      Enum.map(0..hours_diff, fn h ->
        DateTime.add(min_time, h * 3600, :second)
      end)
    end
  end

  defp count_kills_by_window(killmails, windows) do
    kill_times =
      MapSet.new(killmails, fn km ->
        DateTime.truncate(km.timestamp, :second)
        |> DateTime.add(-rem(km.timestamp.minute, 60) * 60 - km.timestamp.second, :second)
      end)

    Enum.map(windows, fn window ->
      if MapSet.member?(kill_times, window), do: 1, else: 0
    end)
  end

  defp calculate_pearson_correlation(series1, series2) do
    n = length(series1)

    if n < 2 do
      0.0
    else
      sum1 = Enum.sum(series1)
      sum2 = Enum.sum(series2)
      sum1_sq = Enum.sum(Enum.map(series1, &(&1 * &1)))
      sum2_sq = Enum.sum(Enum.map(series2, &(&1 * &1)))

      sum_product =
        Enum.zip(series1, series2)
        |> Enum.map(fn {a, b} -> a * b end)
        |> Enum.sum()

      numerator = n * sum_product - sum1 * sum2
      denominator = :math.sqrt((n * sum1_sq - sum1 * sum1) * (n * sum2_sq - sum2 * sum2))

      if denominator > 0 do
        Float.round(numerator / denominator, 3)
      else
        0.0
      end
    end
  end

  defp find_shared_entities(kills1, kills2) do
    entities1 = extract_entities(kills1)
    entities2 = extract_entities(kills2)

    MapSet.intersection(entities1, entities2)
    |> MapSet.to_list()
  end

  defp extract_entities(killmails) do
    attackers =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.character_id)
      |> Enum.reject(&is_nil/1)

    victims =
      killmails
      |> Enum.map(& &1.victim.character_id)
      |> Enum.reject(&is_nil/1)

    MapSet.new(attackers ++ victims)
  end

  defp calculate_temporal_overlap(kills1, kills2) do
    if length(kills1) == 0 || length(kills2) == 0 do
      0.0
    else
      times1 =
        MapSet.new(kills1, fn km ->
          {DateTime.to_date(km.timestamp), km.timestamp.hour}
        end)

      times2 =
        MapSet.new(kills2, fn km ->
          {DateTime.to_date(km.timestamp), km.timestamp.hour}
        end)

      overlap = MapSet.intersection(times1, times2) |> MapSet.size()
      total = MapSet.union(times1, times2) |> MapSet.size()

      if total > 0 do
        Float.round(overlap / total, 3)
      else
        0.0
      end
    end
  end

  defp build_correlation_matrix(correlations) do
    Enum.reduce(correlations, %{}, fn corr, matrix ->
      {s1, s2} = corr.systems

      matrix
      |> Map.put({s1, s2}, corr.correlation)
      |> Map.put({s2, s1}, corr.correlation)
    end)
  end

  defp filter_strong_correlations(correlations, threshold) do
    correlations
    |> Enum.filter(&(&1.correlation >= threshold))
    |> Enum.sort_by(& &1.correlation, :desc)
  end

  defp identify_system_clusters(correlations, threshold) do
    strong_correlations = filter_strong_correlations(correlations, threshold)

    graph = build_correlation_graph(strong_correlations)
    connected_components = find_connected_components(graph)

    Enum.map(connected_components, fn component ->
      %{
        systems: component,
        size: length(component),
        internal_correlations: count_internal_correlations(component, strong_correlations),
        average_correlation: calculate_average_correlation(component, strong_correlations)
      }
    end)
  end

  defp build_correlation_graph(correlations) do
    nodes =
      correlations
      |> Enum.flat_map(fn corr ->
        {s1, s2} = corr.systems
        [s1, s2]
      end)
      |> Enum.uniq()

    edges = Enum.map(correlations, & &1.systems)

    %{nodes: nodes, edges: edges}
  end

  defp build_connectivity_graph(correlations, threshold) do
    strong_correlations = filter_strong_correlations(correlations, threshold)
    build_correlation_graph(strong_correlations)
  end

  defp find_connected_components(graph) do
    visited = MapSet.new()

    graph.nodes
    |> Enum.reduce({[], visited}, fn node, {components, visited} ->
      if MapSet.member?(visited, node) do
        {components, visited}
      else
        component = explore_component(node, graph, MapSet.new())
        new_visited = MapSet.union(visited, MapSet.new(component))
        {[component | components], new_visited}
      end
    end)
    |> elem(0)
  end

  defp explore_component(node, graph, visited) do
    if MapSet.member?(visited, node) do
      []
    else
      visited = MapSet.put(visited, node)
      neighbors = find_neighbors(node, graph.edges)

      [
        node
        | Enum.flat_map(neighbors, fn n ->
            explore_component(n, graph, visited)
          end)
      ]
      |> Enum.uniq()
    end
  end

  defp find_neighbors(node, edges) do
    edges
    |> Enum.flat_map(fn {s1, s2} ->
      cond do
        s1 == node -> [s2]
        s2 == node -> [s1]
        true -> []
      end
    end)
    |> Enum.uniq()
  end

  defp calculate_average_degree(graph) do
    if length(graph.nodes) == 0 do
      0.0
    else
      degree_sum =
        graph.nodes
        |> Enum.map(fn node -> length(find_neighbors(node, graph.edges)) end)
        |> Enum.sum()

      Float.round(degree_sum / length(graph.nodes), 2)
    end
  end

  defp identify_central_nodes(graph) do
    graph.nodes
    |> Enum.map(fn node ->
      degree = length(find_neighbors(node, graph.edges))
      {node, degree}
    end)
    |> Enum.sort_by(fn {_node, degree} -> degree end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {node, degree} ->
      %{system_id: node, degree: degree, centrality_score: degree / max(1, length(graph.edges))}
    end)
  end

  defp identify_bridge_nodes(graph) do
    # Simplified bridge detection - nodes whose removal disconnects the graph
    graph.nodes
    |> Enum.filter(fn node ->
      removed_graph = remove_node_from_graph(graph, node)
      component_count = length(find_connected_components(removed_graph))
      component_count > 1
    end)
  end

  defp remove_node_from_graph(graph, node) do
    %{
      nodes: Enum.reject(graph.nodes, &(&1 == node)),
      edges: Enum.reject(graph.edges, fn {s1, s2} -> s1 == node || s2 == node end)
    }
  end

  defp count_internal_correlations(systems, correlations) do
    system_set = MapSet.new(systems)

    Enum.count(correlations, fn corr ->
      {s1, s2} = corr.systems
      MapSet.member?(system_set, s1) && MapSet.member?(system_set, s2)
    end)
  end

  defp calculate_average_correlation(systems, correlations) do
    system_set = MapSet.new(systems)

    internal_correlations =
      correlations
      |> Enum.filter(fn corr ->
        {s1, s2} = corr.systems
        MapSet.member?(system_set, s1) && MapSet.member?(system_set, s2)
      end)
      |> Enum.map(& &1.correlation)

    if length(internal_correlations) > 0 do
      Float.round(Enum.sum(internal_correlations) / length(internal_correlations), 3)
    else
      0.0
    end
  end

  defp build_activity_vectors(killmail_data) do
    Map.new(killmail_data, fn data ->
      vector = %{
        kill_count: data.kill_count,
        unique_attackers: count_unique_attackers(data.killmails),
        unique_victims: count_unique_victims(data.killmails),
        time_spread: calculate_time_spread(data.killmails),
        peak_hour_concentration: calculate_peak_concentration(data.killmails)
      }

      {data.system_id, vector}
    end)
  end

  defp count_unique_attackers(killmails) do
    killmails
    |> Enum.flat_map(& &1.attackers)
    |> Enum.map(& &1.character_id)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_victims(killmails) do
    killmails
    |> Enum.map(& &1.victim.character_id)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_time_spread(killmails) do
    if length(killmails) < 2 do
      0
    else
      min_time = Enum.min_by(killmails, & &1.timestamp).timestamp
      max_time = Enum.max_by(killmails, & &1.timestamp).timestamp
      DateTime.diff(max_time, min_time, :hour)
    end
  end

  defp calculate_peak_concentration(killmails) do
    if length(killmails) == 0 do
      0.0
    else
      hourly_counts =
        killmails
        |> Enum.group_by(& &1.timestamp.hour)
        |> Enum.map(fn {_hour, kms} -> length(kms) end)

      max_count = Enum.max(hourly_counts)
      Float.round(max_count / length(killmails), 3)
    end
  end

  defp perform_clustering(activity_vectors, min_cluster_size) do
    # Simple clustering based on activity similarity
    systems = Map.keys(activity_vectors)

    if length(systems) < min_cluster_size do
      []
    else
      # Group systems with similar activity levels
      systems
      |> Enum.group_by(fn system ->
        vector = activity_vectors[system]
        classify_activity_level(vector.kill_count)
      end)
      |> Map.values()
      |> Enum.filter(&(length(&1) >= min_cluster_size))
      |> Enum.map(fn cluster_systems ->
        %{
          systems: cluster_systems,
          vectors: Map.take(activity_vectors, cluster_systems)
        }
      end)
    end
  end

  defp classify_activity_level(kill_count) do
    cond do
      kill_count >= 50 -> :very_high
      kill_count >= 20 -> :high
      kill_count >= 10 -> :medium
      kill_count >= 1 -> :low
      true -> :none
    end
  end

  defp analyze_cluster(cluster) do
    vectors = Map.values(cluster.vectors)

    %{
      systems: cluster.systems,
      size: length(cluster.systems),
      average_activity: calculate_average_activity(vectors),
      cohesion: calculate_cluster_cohesion(vectors),
      profile: determine_cluster_profile(vectors)
    }
  end

  defp calculate_average_activity(vectors) do
    if length(vectors) == 0 do
      0.0
    else
      total_kills = Enum.sum(Enum.map(vectors, & &1.kill_count))
      Float.round(total_kills / length(vectors), 1)
    end
  end

  defp calculate_cluster_cohesion(vectors) do
    # Simplified cohesion based on variance
    if length(vectors) < 2 do
      1.0
    else
      kill_counts = Enum.map(vectors, & &1.kill_count)
      mean = Enum.sum(kill_counts) / length(kill_counts)

      variance =
        kill_counts
        |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(kill_counts))

      cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 0
      max(0.0, min(1.0, 1.0 - cv))
    end
  end

  defp determine_cluster_profile(vectors) do
    avg_kills = calculate_average_activity(vectors)

    cond do
      avg_kills >= 30 -> :high_conflict_zone
      avg_kills >= 15 -> :active_combat_area
      avg_kills >= 5 -> :moderate_activity
      true -> :quiet_space
    end
  end

  defp identify_outliers(activity_vectors, clusters) do
    clustered_systems =
      clusters
      |> Enum.flat_map(& &1.systems)
      |> MapSet.new()

    activity_vectors
    |> Map.keys()
    |> Enum.reject(&MapSet.member?(clustered_systems, &1))
    |> Enum.map(fn system ->
      %{
        system_id: system,
        activity_vector: activity_vectors[system],
        outlier_reason: determine_outlier_reason(activity_vectors[system])
      }
    end)
  end

  defp determine_outlier_reason(vector) do
    cond do
      vector.kill_count == 0 -> :no_activity
      vector.kill_count < 5 -> :insufficient_activity
      vector.time_spread < 2 -> :brief_activity
      true -> :unique_pattern
    end
  end

  defp assess_cluster_quality(clusters) do
    if length(clusters) == 0 do
      0.0
    else
      cohesion_scores = Enum.map(clusters, & &1.cohesion)
      Float.round(Enum.sum(cohesion_scores) / length(cohesion_scores), 3)
    end
  end

  defp extract_all_killmails(strategic_data) do
    case strategic_data.scope do
      :single_system -> strategic_data.killmails
      :multi_system -> Enum.flat_map(strategic_data.killmail_data, & &1.killmails)
    end
  end

  defp track_entity_movements(killmails) do
    killmails
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.group_by(fn km ->
      # Group by pilot
      pilot_ids =
        [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
        |> Enum.reject(&is_nil/1)

      # Return first pilot found for simplicity
      List.first(pilot_ids)
    end)
    |> Enum.reject(fn {pilot_id, _} -> is_nil(pilot_id) end)
    |> Enum.map(fn {pilot_id, pilot_kills} ->
      systems =
        pilot_kills
        |> Enum.map(& &1.solar_system_id)
        |> Enum.uniq()

      %{
        pilot_id: pilot_id,
        systems_visited: systems,
        movement_count: length(systems) - 1,
        timespan: calculate_pilot_timespan(pilot_kills)
      }
    end)
    |> Enum.filter(&(&1.movement_count > 0))
  end

  defp calculate_pilot_timespan(pilot_kills) do
    if length(pilot_kills) < 2 do
      0
    else
      first = Enum.min_by(pilot_kills, & &1.timestamp).timestamp
      last = Enum.max_by(pilot_kills, & &1.timestamp).timestamp
      DateTime.diff(last, first, :hour)
    end
  end

  defp find_shared_engagements(killmails) do
    killmails
    |> Enum.map(fn km ->
      participants =
        [km.victim.character_id | Enum.map(km.attackers, & &1.character_id)]
        |> Enum.reject(&is_nil/1)
        |> MapSet.new()

      %{
        killmail_id: km.killmail_id,
        timestamp: km.timestamp,
        system_id: km.solar_system_id,
        participants: participants
      }
    end)
    |> find_engagement_overlaps()
  end

  defp find_engagement_overlaps(engagements) do
    engagements
    |> Enum.with_index()
    |> Enum.flat_map(fn {e1, i} ->
      engagements
      |> Enum.drop(i + 1)
      |> Enum.map(fn e2 ->
        shared = MapSet.intersection(e1.participants, e2.participants)

        if MapSet.size(shared) >= 2 do
          %{
            engagements: [e1.killmail_id, e2.killmail_id],
            shared_participants: MapSet.to_list(shared),
            time_diff: abs(DateTime.diff(e1.timestamp, e2.timestamp, :minute)),
            same_system: e1.system_id == e2.system_id
          }
        else
          nil
        end
      end)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp detect_coordination_patterns(entity_movements, shared_engagements) do
    # Find entities that move together
    movement_patterns =
      entity_movements
      |> Enum.flat_map(fn movement ->
        entity_movements
        |> Enum.filter(&(&1.pilot_id != movement.pilot_id))
        |> Enum.map(fn other ->
          shared_systems =
            MapSet.intersection(
              MapSet.new(movement.systems_visited),
              MapSet.new(other.systems_visited)
            )
            |> MapSet.size()

          if shared_systems >= 2 do
            %{
              entities: [movement.pilot_id, other.pilot_id],
              shared_systems: shared_systems,
              pattern_type: :movement_coordination
            }
          else
            nil
          end
        end)
      end)
      |> Enum.reject(&is_nil/1)

    # Find repeated engagement patterns
    engagement_patterns =
      shared_engagements
      |> Enum.group_by(& &1.shared_participants)
      |> Enum.filter(fn {_participants, engagements} -> length(engagements) >= 2 end)
      |> Enum.map(fn {participants, engagements} ->
        %{
          entities: participants,
          engagement_count: length(engagements),
          pattern_type: :repeated_engagement
        }
      end)

    movement_patterns ++ engagement_patterns
  end

  defp calculate_relationship_strengths(coordination_patterns) do
    coordination_patterns
    |> Enum.group_by(& &1.entities)
    |> Enum.map(fn {entities, patterns} ->
      strength =
        patterns
        |> Enum.map(fn p ->
          case p.pattern_type do
            :movement_coordination -> p.shared_systems * 0.3
            :repeated_engagement -> p.engagement_count * 0.5
            _ -> 0.1
          end
        end)
        |> Enum.sum()

      %{
        entities: entities,
        relationship_strength: min(1.0, strength),
        pattern_count: length(patterns)
      }
    end)
    |> Enum.sort_by(& &1.relationship_strength, :desc)
  end
end
