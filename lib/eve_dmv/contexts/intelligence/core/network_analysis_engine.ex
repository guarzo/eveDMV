defmodule EveDmv.Contexts.Intelligence.Core.NetworkAnalysisEngine do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Social network analysis engine for EVE Online character relationships.

  Implements graph algorithms to analyze:
  - Character associations and alliances
  - Fleet composition patterns
  - Corporation/alliance relationships
  - Influence networks
  - Community detection
  """

  alias EveDmv.Contexts.Intelligence.Core.LouvainCommunityDetection
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Intelligence.Cache.IntelligenceCache
  alias EveDmv.Platform.Database.KillmailRepository
  alias EveDmv.StaticData.ShipTypes

  require Logger

  @cache_ttl :timer.hours(6)
  @min_interactions_threshold 3

  @doc """
  Analyze the social network of a character.
  """
  @spec analyze_network(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_network(character_id, opts \\ []) do
    cache_key = {:network_analysis, character_id, opts}

    case IntelligenceCache.get_or_compute(
           cache_key,
           fn ->
             perform_network_analysis(character_id, opts)
           end,
           ttl: @cache_ttl
         ) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get the influence score of a character within their network.
  """
  @spec get_influence_score(integer()) :: {:ok, float()} | {:error, term()}
  def get_influence_score(character_id) do
    case analyze_network(character_id) do
      {:ok, analysis} -> {:ok, analysis.influence_metrics.influence_score}
      error -> error
    end
  end

  @doc """
  Identify key associates of a character.
  """
  @spec get_key_associates(integer(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_key_associates(character_id, limit \\ 10) do
    case analyze_network(character_id) do
      {:ok, analysis} ->
        associates =
          analysis.direct_network
          |> Enum.sort_by(& &1.interaction_strength, :desc)
          |> Enum.take(limit)

        {:ok, associates}

      error ->
        error
    end
  end

  @doc """
  Analyze fleet composition patterns.
  """
  @spec analyze_fleet_patterns(integer()) :: {:ok, map()} | {:error, term()}
  def analyze_fleet_patterns(character_id) do
    case analyze_network(character_id) do
      {:ok, analysis} -> {:ok, analysis.fleet_patterns}
      error -> error
    end
  end

  # Private Functions

  defp perform_network_analysis(character_id, opts) do
    time_range = Keyword.get(opts, :time_range_days, 90)

    with {:ok, killmails} <- get_character_killmails(character_id, time_range),
         {:ok, network_data} <- build_network_graph(character_id, killmails) do
      analysis = %{
        character_id: character_id,
        direct_network: analyze_direct_connections(network_data),
        extended_network: analyze_extended_network(network_data),
        communities: detect_communities(network_data),
        influence_metrics: calculate_influence_metrics(character_id, network_data),
        fleet_patterns: analyze_fleet_compositions(killmails),
        relationship_strength: analyze_relationship_strengths(network_data),
        network_evolution: analyze_network_evolution(killmails),
        key_brokers: identify_network_brokers(network_data),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    end
  end

  defp get_character_killmails(character_id, days) do
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-days * 24 * 60 * 60, :second)

    case KillmailRepository.get_by_character(character_id, start_date: start_date, limit: 1000) do
      {:ok, killmails} -> {:ok, killmails}
      {:error, _reason} -> {:error, :repository_error}
    end
  end

  defp build_network_graph(character_id, killmails) do
    # Build adjacency list representation of the network
    network =
      killmails
      |> Enum.reduce(%{nodes: MapSet.new([character_id]), edges: %{}}, fn km, acc ->
        process_killmail_for_network(km, character_id, acc)
      end)

    {:ok, network}
  end

  defp process_killmail_for_network(killmail, character_id, network)
       when is_map(killmail) and is_map(network) do
    # Extract all participants
    participants = extract_participants(killmail)

    # Filter to relevant participants (exclude NPC, self)
    relevant_participants =
      participants
      |> Enum.filter(fn p ->
        is_map(p) && is_integer(Map.get(p, :character_id)) &&
          Map.get(p, :character_id) != character_id
      end)
      |> Enum.map(&Map.get(&1, :character_id))

    # Add nodes
    updated_nodes =
      Enum.reduce(relevant_participants, network.nodes, fn pid, nodes ->
        MapSet.put(nodes, pid)
      end)

    killmail_time = Map.get(killmail, :killmail_time, DateTime.utc_now())

    # Add edges (connections between character and participants)
    updated_edges =
      Enum.reduce(relevant_participants, network.edges, fn pid, edges ->
        edge_key = create_edge_key(character_id, pid)

        edge_data =
          Map.get(edges, edge_key, %{
            participants: [character_id, pid],
            interactions: [],
            first_seen: killmail_time,
            last_seen: killmail_time
          })

        updated_edge = %{
          edge_data
          | interactions: [create_interaction(killmail) | edge_data.interactions],
            last_seen: max_datetime(edge_data.last_seen, killmail_time)
        }

        Map.put(edges, edge_key, updated_edge)
      end)

    %{network | nodes: updated_nodes, edges: updated_edges}
  end

  defp extract_participants(killmail) when is_map(killmail) do
    # Extract all participants from killmail
    attackers = Map.get(killmail, :attackers, [])
    victim = Map.get(killmail, :victim, %{})

    # Ensure attackers is a list
    attackers_list = if is_list(attackers), do: attackers, else: []

    all_participants = [victim | attackers_list]

    # Filter and structure participant data
    all_participants
    |> Enum.filter(fn p -> is_map(p) && Map.get(p, :character_id) end)
    |> Enum.map(fn participant ->
      %{
        character_id: participant.character_id,
        character_name: Map.get(participant, :character_name),
        corporation_id: Map.get(participant, :corporation_id),
        alliance_id: Map.get(participant, :alliance_id),
        ship_type_id: Map.get(participant, :ship_type_id)
      }
    end)
  end

  defp extract_participants(_), do: []

  defp create_edge_key(id1, id2) do
    # Create consistent edge key regardless of order
    if id1 < id2, do: {id1, id2}, else: {id2, id1}
  end

  defp create_interaction(killmail) when is_map(killmail) do
    attackers = Map.get(killmail, :attackers, [])
    participant_count = if is_list(attackers), do: length(attackers) + 1, else: 1

    %{
      killmail_id: killmail.killmail_id,
      timestamp: killmail.killmail_time,
      solar_system_id: killmail.solar_system_id,
      ship_value: Map.get(killmail, :total_value, 0),
      participant_count: participant_count
    }
  end

  defp max_datetime(%DateTime{} = dt1, %DateTime{} = dt2) do
    if DateTimeUtils.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end

  defp max_datetime(dt1, _dt2) when is_struct(dt1, DateTime), do: dt1
  defp max_datetime(_dt1, dt2) when is_struct(dt2, DateTime), do: dt2
  defp max_datetime(_dt1, _dt2), do: DateTime.utc_now()

  defp analyze_direct_connections(network_data) do
    # Analyze direct connections (1-degree)
    network_data.edges
    |> Map.values()
    |> Enum.map(fn edge ->
      %{
        characters: edge.participants,
        interaction_count: length(edge.interactions),
        interaction_strength: calculate_interaction_strength(edge),
        relationship_type: classify_relationship(edge),
        time_span_days: DateTimeUtils.diff(edge.last_seen, edge.first_seen, :day),
        average_fleet_size: calculate_average_fleet_size(edge.interactions),
        shared_systems: count_shared_systems(edge.interactions)
      }
    end)
    |> Enum.filter(&(&1.interaction_count >= @min_interactions_threshold))
    |> Enum.sort_by(& &1.interaction_strength, :desc)
  end

  defp calculate_interaction_strength(edge) do
    # Multi-factor interaction strength calculation
    interaction_count = length(edge.interactions)

    # Recency factor (more recent = stronger)
    days_since_last = DateTimeUtils.diff(DateTime.utc_now(), edge.last_seen, :day)
    # Exponential decay over 30 days
    recency_factor = :math.exp(-days_since_last / 30.0)

    # Consistency factor (regular interactions = stronger)
    time_span = max(1, DateTimeUtils.diff(edge.last_seen, edge.first_seen, :day))

    consistency_factor =
      if time_span > 0 do
        interaction_count / time_span
      else
        interaction_count
      end

    # Value factor (higher value engagements = stronger)
    total_value =
      edge.interactions
      |> Enum.map(& &1.ship_value)
      |> Enum.sum()

    # Log scale of millions
    value_factor = :math.log10(max(1, total_value / 1_000_000))

    # Combine factors
    strength =
      interaction_count * recency_factor * (1 + consistency_factor) * (1 + value_factor / 10)

    Float.round(strength, 2)
  end

  defp classify_relationship(edge) do
    interactions = edge.interactions
    fleet_sizes = Enum.map(interactions, & &1.participant_count)

    avg_fleet_size =
      if length(fleet_sizes) > 0 do
        Enum.sum(fleet_sizes) / length(fleet_sizes)
      else
        0.0
      end

    # Classify based on patterns
    cond do
      length(interactions) >= 20 and avg_fleet_size < 5 -> :close_associate
      length(interactions) >= 10 and avg_fleet_size < 10 -> :frequent_wingman
      avg_fleet_size > 20 -> :fleet_member
      length(interactions) >= 5 -> :occasional_ally
      true -> :acquaintance
    end
  end

  defp calculate_average_fleet_size(interactions) when is_list(interactions) do
    if Enum.empty?(interactions) do
      0.0
    else
      total =
        interactions
        |> Enum.map(& &1.participant_count)
        |> Enum.sum()

      interaction_count = length(interactions)

      if interaction_count > 0 do
        Float.round(total / interaction_count, 1)
      else
        0.0
      end
    end
  end

  defp calculate_average_fleet_size(_), do: 0.0

  defp count_shared_systems(interactions) do
    interactions
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> length()
  end

  defp analyze_extended_network(network_data) do
    # Analyze the broader network structure
    node_count = MapSet.size(network_data.nodes)
    edge_count = map_size(network_data.edges)

    # Calculate network density
    max_edges =
      if node_count > 1 do
        node_count * (node_count - 1) / 2
      else
        0
      end

    density = if max_edges > 0, do: edge_count / max_edges, else: 0

    # Calculate degree distribution
    degree_distribution = calculate_degree_distribution(network_data)

    %{
      total_nodes: node_count,
      total_edges: edge_count,
      network_density: Float.round(density, 4),
      average_degree: calculate_average_degree(degree_distribution),
      degree_distribution: degree_distribution,
      clustering_coefficient: calculate_clustering_coefficient(network_data),
      network_diameter: estimate_network_diameter(network_data)
    }
  end

  defp calculate_degree_distribution(network_data) do
    # Count connections per node
    network_data.edges
    |> Map.values()
    |> Enum.flat_map(& &1.participants)
    |> Enum.frequencies()
  end

  defp calculate_average_degree(degree_distribution) do
    node_count = map_size(degree_distribution)

    if node_count == 0 do
      0.0
    else
      total_degree = degree_distribution |> Map.values() |> Enum.sum()
      Float.round(total_degree / node_count, 2)
    end
  end

  defp calculate_clustering_coefficient(network_data) do
    # Calculate the local clustering coefficient for all nodes
    nodes = MapSet.to_list(network_data.nodes)

    if length(nodes) < 3 do
      # Need at least 3 nodes for triangles
      0.0
    else
      # Build adjacency map for faster lookups
      adjacency = build_adjacency_map(network_data.edges)

      # Calculate clustering coefficient for each node
      node_coefficients =
        nodes
        |> Enum.map(fn node ->
          neighbors = Map.get(adjacency, node, MapSet.new()) |> MapSet.to_list()
          calculate_node_clustering_coefficient(neighbors, network_data.edges)
        end)
        # Only consider nodes with non-zero coefficient
        |> Enum.filter(&(&1 > 0))

      # Global clustering coefficient is the average
      if Enum.empty?(node_coefficients) do
        0.0
      else
        coefficient_count = length(node_coefficients)

        if coefficient_count > 0 do
          avg = Enum.sum(node_coefficients) / coefficient_count
          Float.round(avg, 3)
        else
          0.0
        end
      end
    end
  end

  defp build_adjacency_map(edges) do
    edges
    |> Map.values()
    |> Enum.reduce(%{}, fn edge, acc ->
      [char1, char2] = edge.participants

      acc
      |> Map.update(char1, MapSet.new([char2]), &MapSet.put(&1, char2))
      |> Map.update(char2, MapSet.new([char1]), &MapSet.put(&1, char1))
    end)
  end

  defp calculate_node_clustering_coefficient(neighbors, edges) do
    if length(neighbors) < 2 do
      # Need at least 2 neighbors to form triangles
      0.0
    else
      # Count triangles (connections between neighbors)
      possible_triangles = combination_pairs(neighbors)

      actual_triangles =
        Enum.count(possible_triangles, fn {n1, n2} ->
          # Check if these two neighbors are connected
          edge_exists?(edges, n1, n2)
        end)

      # Local clustering coefficient = actual triangles / possible triangles
      neighbor_count = length(neighbors)

      max_triangles =
        if neighbor_count > 1 do
          neighbor_count * (neighbor_count - 1) / 2
        else
          0
        end

      if max_triangles > 0 do
        actual_triangles / max_triangles
      else
        0.0
      end
    end
  end

  defp combination_pairs(list) do
    for i <- 0..(length(list) - 2),
        j <- (i + 1)..(length(list) - 1) do
      {Enum.at(list, i), Enum.at(list, j)}
    end
  end

  defp edge_exists?(edges, node1, node2) do
    key1 = create_edge_key(node1, node2)
    Map.has_key?(edges, key1)
  end

  defp estimate_network_diameter(network_data) do
    # Calculate actual network diameter using BFS
    nodes = MapSet.to_list(network_data.nodes)

    if length(nodes) < 2 do
      0
    else
      # Build adjacency map for BFS
      adjacency = build_adjacency_map(network_data.edges)

      # Calculate shortest paths from a sample of nodes
      # For large networks, sample to avoid O(n²) complexity
      sample_size = min(length(nodes), 10)
      sampled_nodes = Enum.take_random(nodes, sample_size)

      max_distance =
        sampled_nodes
        |> Enum.map(fn start_node ->
          bfs_max_distance(start_node, adjacency)
        end)
        |> Enum.max(fn -> 0 end)

      max_distance
    end
  end

  defp bfs_max_distance(start_node, adjacency) do
    # BFS to find the maximum distance from start_node
    visited = MapSet.new([start_node])
    queue = :queue.from_list([{start_node, 0}])
    max_dist = 0

    bfs_loop(queue, visited, adjacency, max_dist)
  end

  defp bfs_loop(queue, visited, adjacency, max_dist) do
    case :queue.out(queue) do
      {{:value, {node, dist}}, rest_queue} ->
        neighbors = Map.get(adjacency, node, MapSet.new())

        {new_queue, new_visited, new_max} =
          MapSet.to_list(neighbors)
          |> Enum.reduce({rest_queue, visited, max(max_dist, dist)}, fn neighbor, {q, v, m} ->
            if MapSet.member?(v, neighbor) do
              {q, v, m}
            else
              {
                :queue.in({neighbor, dist + 1}, q),
                MapSet.put(v, neighbor),
                max(m, dist + 1)
              }
            end
          end)

        bfs_loop(new_queue, new_visited, adjacency, new_max)

      {:empty, _} ->
        max_dist
    end
  end

  defp detect_communities(network_data) do
    # Use proper Louvain algorithm for community detection
    LouvainCommunityDetection.detect_communities(network_data)
  end

  defp calculate_influence_metrics(character_id, network_data) do
    # Calculate various centrality metrics
    degree_centrality = calculate_degree_centrality(character_id, network_data)
    eigenvector = calculate_eigenvector_centrality(character_id, network_data)

    # Combine into influence score (eigenvector weighted more heavily)
    influence_score = (degree_centrality * 0.4 + eigenvector * 0.6) * 100

    %{
      influence_score: Float.round(influence_score, 1),
      degree_centrality: Float.round(degree_centrality, 3),
      eigenvector_centrality: Float.round(eigenvector, 3),
      influence_rank: categorize_influence(influence_score)
    }
  end

  defp calculate_degree_centrality(character_id, network_data) do
    # Degree centrality = number of connections / possible connections
    connections =
      network_data.edges
      |> Map.values()
      |> Enum.count(fn edge -> character_id in edge.participants end)

    total_nodes = MapSet.size(network_data.nodes)

    if total_nodes > 1 do
      connections / (total_nodes - 1)
    else
      0.0
    end
  end

  defp calculate_eigenvector_centrality(character_id, network_data) do
    # Improved eigenvector centrality calculation
    # Based on connections to well-connected nodes

    adjacency = build_adjacency_map(network_data.edges)
    node_connections = Map.get(adjacency, character_id, MapSet.new())

    if MapSet.size(node_connections) == 0 do
      0.0
    else
      # Calculate weighted eigenvector centrality
      # Score based on neighbor importance and interaction strength
      neighbor_scores =
        node_connections
        |> MapSet.to_list()
        |> Enum.map(fn neighbor_id ->
          neighbor_degree = Map.get(adjacency, neighbor_id, MapSet.new()) |> MapSet.size()
          edge_key = create_edge_key(character_id, neighbor_id)

          case Map.get(network_data.edges, edge_key) do
            nil ->
              0.0

            edge when is_map(edge) ->
              interaction_strength = calculate_interaction_strength(edge)
              # Neighbor importance * interaction strength
              neighbor_degree / MapSet.size(network_data.nodes) * interaction_strength
          end
        end)
        |> Enum.sum()

      # Normalize to 0-1 range
      min(1.0, neighbor_scores / 10.0)
    end
  end

  defp categorize_influence(score) do
    cond do
      score >= 80 -> :network_leader
      score >= 60 -> :key_influencer
      score >= 40 -> :active_member
      score >= 20 -> :regular_member
      true -> :peripheral_member
    end
  end

  defp analyze_fleet_compositions(killmails) when is_list(killmails) do
    # Analyze fleet patterns
    fleets =
      killmails
      |> Enum.filter(fn km ->
        is_map(km) && is_integer(Map.get(km, :participant_count, 0)) &&
          Map.get(km, :participant_count, 0) >= 5
      end)
      |> Enum.map(&analyze_single_fleet/1)

    if Enum.empty?(fleets) do
      %{
        average_fleet_size: 0,
        common_compositions: [],
        preferred_roles: [],
        coordination_level: :none
      }
    else
      %{
        average_fleet_size: calculate_average_fleet_size_from_fleets(fleets),
        common_compositions: identify_common_compositions(fleets),
        preferred_roles: identify_preferred_roles(fleets),
        coordination_level: assess_fleet_coordination(fleets)
      }
    end
  end

  defp analyze_single_fleet(killmail) when is_map(killmail) do
    attackers = Map.get(killmail, :attackers, [])
    attackers_list = if is_list(attackers), do: attackers, else: []
    victim = Map.get(killmail, :victim, %{})

    participants = [victim | attackers_list]

    ship_types =
      participants
      |> Enum.filter(&is_map/1)
      |> Enum.map(&Map.get(&1, :ship_type_id))
      |> Enum.filter(&is_integer/1)

    %{
      killmail_id: Map.get(killmail, :killmail_id),
      timestamp: Map.get(killmail, :killmail_time),
      fleet_size: Map.get(killmail, :participant_count, 0),
      ship_types: ship_types,
      ship_classes: classify_ship_types(ship_types),
      has_logi: detect_logistics_presence(ship_types),
      has_ewar: detect_ewar_presence(ship_types)
    }
  end

  defp calculate_average_fleet_size_from_fleets(fleets)
       when is_list(fleets) and length(fleets) > 0 do
    total_size =
      fleets
      |> Enum.map(fn f -> Map.get(f, :fleet_size, 0) end)
      |> Enum.sum()

    Float.round(total_size / length(fleets), 1)
  end

  defp calculate_average_fleet_size_from_fleets(_), do: 0.0

  defp identify_common_compositions(fleets) do
    # Group fleets by composition patterns
    fleets
    |> Enum.map(& &1.ship_classes)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_comp, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {composition, count} ->
      %{
        composition: composition,
        frequency: count,
        percentage: Float.round(count / length(fleets) * 100, 1)
      }
    end)
  end

  defp identify_preferred_roles(fleets) do
    # Count ship class occurrences
    all_classes =
      fleets
      |> Enum.flat_map(& &1.ship_classes)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_class, count} -> count end, :desc)
      |> Enum.take(5)

    all_classes
  end

  defp assess_fleet_coordination(fleets) do
    # Assess coordination based on fleet patterns
    logi_percentage = Enum.count(fleets, & &1.has_logi) / length(fleets)
    ewar_percentage = Enum.count(fleets, & &1.has_ewar) / length(fleets)

    cond do
      logi_percentage > 0.7 and ewar_percentage > 0.5 -> :highly_coordinated
      logi_percentage > 0.5 or ewar_percentage > 0.3 -> :coordinated
      logi_percentage > 0.2 -> :basic_coordination
      true -> :minimal_coordination
    end
  end

  defp classify_ship_types(ship_type_ids) when is_list(ship_type_ids) do
    # Simplified ship classification
    ship_type_ids
    |> Enum.filter(&is_integer/1)
    |> Enum.map(&classify_single_ship/1)
    |> Enum.frequencies()
  end

  defp classify_single_ship(ship_type_id) when is_integer(ship_type_id) do
    # Use proper EVE static data classification
    cond do
      ShipTypes.is_ship_class?(ship_type_id, :capital) or
          ShipTypes.is_ship_class?(ship_type_id, :supercapital) ->
        :capital

      ShipTypes.logistics?(ship_type_id) ->
        :logistics

      ShipTypes.ewar?(ship_type_id) ->
        :ewar

      ShipTypes.tackle_ship?(ship_type_id) ->
        :tackle

      ShipTypes.dps_ship?(ship_type_id) ->
        :dps

      true ->
        :support
    end
  end

  defp detect_logistics_presence(ship_type_ids) when is_list(ship_type_ids) do
    ship_type_ids
    |> Enum.filter(&is_integer/1)
    |> Enum.any?(&ShipTypes.logistics?/1)
  end

  defp detect_ewar_presence(ship_type_ids) when is_list(ship_type_ids) do
    ship_type_ids
    |> Enum.filter(&is_integer/1)
    |> Enum.any?(&ShipTypes.ewar?/1)
  end

  defp analyze_relationship_strengths(network_data) do
    # Analyze distribution of relationship strengths
    strengths =
      network_data.edges
      |> Map.values()
      |> Enum.map(&calculate_interaction_strength/1)

    if Enum.empty?(strengths) do
      %{average: 0, distribution: %{}}
    else
      %{
        average: Float.round(Enum.sum(strengths) / length(strengths), 2),
        maximum: Enum.max(strengths),
        distribution: categorize_strength_distribution(strengths)
      }
    end
  end

  defp categorize_strength_distribution(strengths) do
    strengths
    |> Enum.map(&categorize_single_strength/1)
    |> Enum.frequencies()
  end

  defp categorize_single_strength(strength) do
    cond do
      strength >= 50 -> :very_strong
      strength >= 20 -> :strong
      strength >= 10 -> :moderate
      strength >= 5 -> :weak
      true -> :very_weak
    end
  end

  defp analyze_network_evolution(killmails) do
    # Analyze how the network has evolved over time
    if length(killmails) < 20 do
      %{trend: :insufficient_data}
    else
      sorted = Enum.sort_by(killmails, & &1.killmail_time)
      midpoint = div(length(sorted), 2)

      first_half = Enum.take(sorted, midpoint)
      second_half = Enum.drop(sorted, midpoint)

      first_network = build_period_network(first_half)
      second_network = build_period_network(second_half)

      %{
        trend: determine_network_trend(first_network, second_network),
        growth_rate: calculate_network_growth_rate(first_network, second_network),
        stability: assess_network_stability(first_network, second_network)
      }
    end
  end

  defp build_period_network(killmails) when is_list(killmails) and length(killmails) > 0 do
    participants =
      killmails
      |> Enum.flat_map(&extract_participants/1)
      |> Enum.filter(&is_map/1)
      |> Enum.map(&Map.get(&1, :character_id))
      |> Enum.filter(&is_integer/1)
      |> Enum.uniq()

    first_km = List.first(killmails)
    last_km = List.last(killmails)

    %{
      node_count: length(participants),
      edge_count: length(killmails),
      period_start: if(is_map(first_km), do: Map.get(first_km, :killmail_time), else: nil),
      period_end: if(is_map(last_km), do: Map.get(last_km, :killmail_time), else: nil)
    }
  end

  defp build_period_network(_),
    do: %{
      node_count: 0,
      edge_count: 0,
      period_start: nil,
      period_end: nil
    }

  defp determine_network_trend(first_network, second_network) do
    growth = second_network.node_count - first_network.node_count

    cond do
      growth > 10 -> :expanding
      growth > 0 -> :growing
      growth < -10 -> :contracting
      growth < 0 -> :shrinking
      true -> :stable
    end
  end

  defp calculate_network_growth_rate(first_network, second_network) do
    if first_network.node_count > 0 do
      growth = (second_network.node_count - first_network.node_count) / first_network.node_count
      Float.round(growth * 100, 1)
    else
      0.0
    end
  end

  defp assess_network_stability(_first_network, _second_network) do
    # Simplified stability assessment
    # Would need to track specific relationships over time
    :moderate
  end

  defp identify_network_brokers(network_data) do
    # Identify nodes that connect different parts of the network
    # Simplified version - would need full betweenness calculation

    high_degree_nodes =
      network_data.edges
      |> Map.values()
      |> Enum.flat_map(& &1.participants)
      |> Enum.frequencies()
      |> Enum.filter(fn {_node, degree} -> degree >= 5 end)
      |> Enum.sort_by(fn {_node, degree} -> degree end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {node_id, degree} ->
        %{
          character_id: node_id,
          connection_count: degree,
          broker_score: calculate_broker_score(node_id, network_data),
          broker_type: classify_broker_type(degree)
        }
      end)

    high_degree_nodes
  end

  defp calculate_broker_score(node_id, network_data) do
    # Calculate broker score based on actual network position
    # Count how many edges this node participates in
    edge_count =
      network_data.edges
      |> Map.values()
      |> Enum.count(fn edge -> node_id in edge.participants end)

    # Calculate normalized broker score (0.0 - 1.0)
    max_edges = MapSet.size(network_data.nodes) - 1

    if max_edges > 0 do
      score = edge_count / max_edges
      Float.round(score, 2)
    else
      0.0
    end
  end

  defp classify_broker_type(degree) do
    cond do
      degree >= 20 -> :hub
      degree >= 10 -> :connector
      degree >= 5 -> :bridge
      true -> :link
    end
  end
end
