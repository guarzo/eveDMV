defmodule EveDmv.Contexts.Intelligence.Core.LouvainCommunityDetection do
  @moduledoc """
  Implements the Louvain algorithm for community detection in character networks.

  The Louvain method is a greedy optimization algorithm that attempts to optimize
  the modularity of a partition of the network. It works in two phases:

  1. Local optimization: nodes are moved between communities to maximize modularity
  2. Network aggregation: communities become nodes in a coarser network

  These phases are repeated until no further improvement is possible.
  """

  alias EveDmv.Database.CharacterRepository

  @doc """
  Detect communities in a network using the Louvain algorithm.

  Returns a list of communities with their members and metadata.
  """
  def detect_communities(network_data) do
    # Initialize each node in its own community
    initial_partition = initialize_partition(network_data)

    # Build weighted adjacency matrix
    adjacency = build_weighted_adjacency(network_data)

    # Calculate total weight of all edges
    total_weight = calculate_total_weight(adjacency)

    # Phase 1: Optimize modularity by moving nodes
    {optimized_partition, modularity} =
      optimize_modularity(
        initial_partition,
        adjacency,
        total_weight,
        0
      )

    # Check if we should continue to phase 2
    if modularity > 0.0 and map_size(optimized_partition) < MapSet.size(network_data.nodes) do
      # Phase 2: Build coarse network and recurse
      coarse_network = build_coarse_network(optimized_partition, adjacency)
      coarse_communities = detect_communities(coarse_network)

      # Map coarse communities back to original nodes
      expand_communities(coarse_communities, optimized_partition)
    else
      # Convert partition to community structure with metadata
      partition_to_communities(optimized_partition, network_data, adjacency)
    end
  end

  # Initialize each node in its own community
  defp initialize_partition(network_data) do
    network_data.nodes
    |> MapSet.to_list()
    |> Enum.with_index()
    |> Map.new(fn {node, idx} -> {node, idx} end)
  end

  # Build weighted adjacency matrix from edges
  defp build_weighted_adjacency(network_data) do
    network_data.edges
    |> Map.values()
    |> Enum.reduce(%{}, fn edge, adj ->
      [node1, node2] = edge.participants
      weight = calculate_edge_weight(edge)

      adj
      |> Map.update(node1, %{node2 => weight}, &Map.put(&1, node2, weight))
      |> Map.update(node2, %{node1 => weight}, &Map.put(&1, node1, weight))
    end)
  end

  # Calculate edge weight based on interaction strength
  defp calculate_edge_weight(edge) do
    base_weight = length(edge.interactions)
    recency_weight = calculate_recency_weight(edge.last_seen)
    consistency_weight = calculate_consistency_weight(edge)

    base_weight * recency_weight * consistency_weight
  end

  defp calculate_recency_weight(last_seen) do
    days_ago = DateTime.diff(DateTime.utc_now(), last_seen, :day)
    # Exponential decay over 30 days
    :math.exp(-days_ago / 30.0)
  end

  defp calculate_consistency_weight(edge) do
    # Regular interactions score higher
    time_span = max(1, DateTime.diff(edge.last_seen, edge.first_seen, :day))
    interaction_rate = length(edge.interactions) / time_span

    min(2.0, 1.0 + interaction_rate / 10.0)
  end

  # Calculate total weight of all edges
  defp calculate_total_weight(adjacency) do
    adjacency
    |> Map.values()
    |> Enum.flat_map(&Map.values/1)
    |> Enum.sum()
    # Each edge counted twice
    |> Kernel./(2.0)
  end

  # Main optimization loop
  defp optimize_modularity(partition, adjacency, total_weight, iteration) do
    # Limit iterations to prevent infinite loops
    if iteration >= 100 do
      {partition, calculate_modularity(partition, adjacency, total_weight)}
    else
      # Try to move each node to improve modularity
      {new_partition, improved} =
        partition
        |> Map.keys()
        |> Enum.reduce({partition, false}, fn node, {current_partition, any_improved} ->
          {best_community, best_gain} =
            find_best_community(
              node,
              current_partition,
              adjacency,
              total_weight
            )

          current_community = Map.get(current_partition, node)

          if best_community != current_community and best_gain > 0.0001 do
            {Map.put(current_partition, node, best_community), true}
          else
            {current_partition, any_improved}
          end
        end)

      if improved do
        # Continue optimization
        optimize_modularity(new_partition, adjacency, total_weight, iteration + 1)
      else
        # No improvement, return result
        {new_partition, calculate_modularity(new_partition, adjacency, total_weight)}
      end
    end
  end

  # Find best community for a node
  defp find_best_community(node, partition, adjacency, total_weight) do
    current_community = Map.get(partition, node)
    node_degree = get_node_degree(node, adjacency)

    # Get neighboring communities
    neighbor_communities =
      Map.get(adjacency, node, %{})
      |> Map.keys()
      |> Enum.map(&Map.get(partition, &1))
      |> Enum.uniq()

    # Test each neighboring community
    neighbor_communities
    |> Enum.map(fn community ->
      # Calculate modularity gain from moving node to this community
      context = %{
        partition: partition,
        adjacency: adjacency,
        total_weight: total_weight,
        node_degree: node_degree
      }

      gain = calculate_modularity_gain(node, current_community, community, context)

      {community, gain}
    end)
    |> Enum.max_by(&elem(&1, 1), fn -> {current_community, 0.0} end)
  end

  # Calculate degree of a node (sum of edge weights)
  defp get_node_degree(node, adjacency) do
    Map.get(adjacency, node, %{})
    |> Map.values()
    |> Enum.sum()
  end

  # Calculate modularity gain from moving a node between communities
  defp calculate_modularity_gain(node, from_community, to_community, context) do
    %{
      partition: partition,
      adjacency: adjacency,
      total_weight: total_weight,
      node_degree: node_degree
    } = context

    # Sum of weights from node to nodes in target community
    weight_to_community =
      Map.get(adjacency, node, %{})
      |> Enum.filter(fn {neighbor, _weight} ->
        Map.get(partition, neighbor) == to_community
      end)
      |> Enum.map(&elem(&1, 1))
      |> Enum.sum()

    # Sum of weights from node to nodes in current community
    weight_from_community =
      if from_community == to_community do
        weight_to_community
      else
        Map.get(adjacency, node, %{})
        |> Enum.filter(fn {neighbor, _weight} ->
          Map.get(partition, neighbor) == from_community
        end)
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()
      end

    # Degrees of communities
    to_degree = calculate_community_degree(to_community, partition, adjacency)
    from_degree = calculate_community_degree(from_community, partition, adjacency)

    # Modularity gain formula
    gain_to =
      (weight_to_community - to_degree * node_degree / (2.0 * total_weight)) / total_weight

    gain_from =
      (weight_from_community - (from_degree - node_degree) * node_degree / (2.0 * total_weight)) /
        total_weight

    if from_community == to_community do
      0.0
    else
      2.0 * (gain_to - gain_from)
    end
  end

  # Calculate total degree of a community
  defp calculate_community_degree(community, partition, adjacency) do
    partition
    |> Enum.filter(fn {_node, comm} -> comm == community end)
    |> Enum.map(fn {node, _} -> get_node_degree(node, adjacency) end)
    |> Enum.sum()
  end

  # Calculate modularity of current partition
  defp calculate_modularity(partition, adjacency, total_weight) do
    communities = partition |> Map.values() |> Enum.uniq()

    communities
    |> Enum.map(fn community ->
      nodes_in_community =
        partition
        |> Enum.filter(fn {_node, c} -> c == community end)
        |> Enum.map(&elem(&1, 0))

      # Internal edges weight
      internal_weight =
        nodes_in_community
        |> Enum.flat_map(fn node ->
          Map.get(adjacency, node, %{})
          |> Enum.filter(fn {neighbor, _} -> neighbor in nodes_in_community end)
          |> Enum.map(&elem(&1, 1))
        end)
        |> Enum.sum()
        |> Kernel./(2.0)

      # Community degree
      community_degree =
        nodes_in_community
        |> Enum.map(&get_node_degree(&1, adjacency))
        |> Enum.sum()

      # Modularity contribution
      internal_weight / total_weight - :math.pow(community_degree / (2.0 * total_weight), 2)
    end)
    |> Enum.sum()
  end

  # Build coarse network where each community becomes a node
  defp build_coarse_network(partition, adjacency) do
    # Group nodes by community
    communities =
      partition
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

    # Create super-nodes for each community
    coarse_nodes =
      communities
      |> Map.keys()
      |> MapSet.new()

    # Create edges between communities
    coarse_edges =
      adjacency
      |> Enum.flat_map(fn {node, neighbors} ->
        node_community = Map.get(partition, node)

        neighbors
        |> Enum.map(fn {neighbor, weight} ->
          neighbor_community = Map.get(partition, neighbor)

          if node_community != neighbor_community do
            edge_key =
              if node_community < neighbor_community,
                do: {node_community, neighbor_community},
                else: {neighbor_community, node_community}

            {edge_key, weight}
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {{c1, c2}, weights} ->
        {Enum.min([c1, c2]) <> "_" <> Enum.max([c1, c2]),
         %{
           participants: [c1, c2],
           interactions: Enum.map(weights, fn w -> %{weight: w} end),
           interaction_count: length(weights),
           first_seen: DateTime.utc_now(),
           last_seen: DateTime.utc_now()
         }}
      end)
      |> Map.new()

    %{nodes: coarse_nodes, edges: coarse_edges}
  end

  # Expand coarse communities back to original nodes
  defp expand_communities(_coarse_communities, original_partition) do
    # Implementation depends on how we track the hierarchy
    # For now, return the partition converted to communities
    partition_to_communities(original_partition, nil, nil)
  end

  # Convert partition to community structure with metadata
  defp partition_to_communities(partition, network_data, adjacency) do
    partition
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
    |> Enum.map(fn {community_id, members} ->
      # Get character data for enrichment
      character_data = get_character_data(members)

      %{
        community_id: "community_#{community_id}",
        member_count: length(members),
        members: members,
        cohesion_score: calculate_final_cohesion(members, adjacency),
        activity_level: calculate_activity_level(members, network_data),
        dominant_corporation: find_dominant_corporation(character_data),
        dominant_alliance: find_dominant_alliance(character_data),
        community_type: classify_community_type(members, character_data, adjacency)
      }
    end)
    |> Enum.sort_by(& &1.member_count, :desc)
  end

  # Get character data for enrichment
  defp get_character_data(character_ids) do
    case CharacterRepository.get_characters_by_ids(character_ids) do
      {:ok, characters} -> characters
      _ -> []
    end
  end

  # Calculate final cohesion score for a community
  defp calculate_final_cohesion(members, adjacency) do
    if length(members) < 2 or is_nil(adjacency) do
      1.0
    else
      # Count internal edges
      internal_edges =
        members
        |> Enum.flat_map(fn member ->
          Map.get(adjacency, member, %{})
          |> Enum.filter(fn {neighbor, _} -> neighbor in members end)
        end)
        |> length()
        # Each edge counted twice
        |> Kernel./(2)

      # Maximum possible edges
      max_edges = length(members) * (length(members) - 1) / 2

      if max_edges > 0 do
        Float.round(internal_edges / max_edges, 3)
      else
        0.0
      end
    end
  end

  # Calculate activity level based on recent interactions
  defp calculate_activity_level(members, network_data) do
    if is_nil(network_data) do
      :unknown
    else
      # Count recent interactions involving community members
      recent_interactions =
        network_data.edges
        |> Map.values()
        |> Enum.filter(fn edge ->
          Enum.any?(edge.participants, &(&1 in members))
        end)
        |> Enum.flat_map(& &1.interactions)
        |> Enum.count(fn interaction ->
          DateTime.diff(DateTime.utc_now(), interaction.timestamp, :day) <= 30
        end)

      cond do
        recent_interactions >= 100 -> :very_active
        recent_interactions >= 50 -> :active
        recent_interactions >= 20 -> :moderate
        recent_interactions >= 5 -> :low
        true -> :inactive
      end
    end
  end

  # Find dominant corporation in community
  defp find_dominant_corporation(character_data) do
    character_data
    |> Enum.frequencies_by(& &1.corporation_id)
    |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0} end)
    |> then(fn
      {corp_id, count} when count > length(character_data) / 2 ->
        %{
          corporation_id: corp_id,
          corporation_name: get_corporation_name(corp_id, character_data),
          percentage: Float.round(count / length(character_data) * 100, 1)
        }

      _ ->
        nil
    end)
  end

  # Find dominant alliance in community
  defp find_dominant_alliance(character_data) do
    character_data
    |> Enum.filter(& &1.alliance_id)
    |> Enum.frequencies_by(& &1.alliance_id)
    |> Enum.max_by(&elem(&1, 1), fn -> {nil, 0} end)
    |> then(fn
      {alliance_id, count} when count > length(character_data) / 2 ->
        %{
          alliance_id: alliance_id,
          alliance_name: get_alliance_name(alliance_id, character_data),
          percentage: Float.round(count / length(character_data) * 100, 1)
        }

      _ ->
        nil
    end)
  end

  # Classify community type based on composition
  defp classify_community_type(members, character_data, adjacency) do
    corp_diversity = character_data |> Enum.map(& &1.corporation_id) |> Enum.uniq() |> length()
    cohesion = calculate_final_cohesion(members, adjacency)

    cond do
      # Single corporation community
      corp_diversity == 1 -> :corporation_group
      # Alliance-based community
      find_dominant_alliance(character_data) != nil -> :alliance_group
      # Tight-knit cross-corp group
      cohesion > 0.7 and corp_diversity > 1 -> :coalition
      # Loose association
      cohesion < 0.3 -> :loose_network
      # Default
      true -> :mixed_group
    end
  end

  defp get_corporation_name(corp_id, character_data) do
    character_data
    |> Enum.find(&(&1.corporation_id == corp_id))
    |> case do
      nil -> "Unknown"
      char -> char.corporation_name || "Unknown"
    end
  end

  defp get_alliance_name(alliance_id, character_data) do
    character_data
    |> Enum.find(&(&1.alliance_id == alliance_id))
    |> case do
      nil -> "Unknown"
      char -> char.alliance_name || "Unknown"
    end
  end
end
