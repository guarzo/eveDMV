defmodule EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.AffiliationAnalyzer do
  @moduledoc """
  Analyzes participant affiliations to determine sides in a battle.

  Uses multiple signals to group participants:
  - Corporation/Alliance membership
  - Damage patterns (who shoots whom)
  - Temporal clustering (who arrives together)
  - Fleet composition patterns
  """

  @doc """
  Analyze affiliations and group participants into sides.
  """
  def analyze_affiliations(participants) do
    # Build affiliation graph
    graph = build_affiliation_graph(participants)

    # Detect sides using graph clustering
    sides = detect_sides(graph, participants)

    # Enhance participants with affiliation data
    Enum.map(participants, fn participant ->
      side = find_participant_side(participant, sides)

      participant
      |> Map.put(:affiliation, side)
      |> Map.put(:affiliation_strength, calculate_affiliation_strength(participant, side, sides))
      |> Map.put(:is_third_party, third_party?(participant, sides))
    end)
  end

  defp build_affiliation_graph(participants) do
    # Create a graph where edges represent "fighting together" relationships
    edges =
      participants
      |> build_corporation_edges()
      |> add_alliance_edges(participants)
      |> add_damage_pattern_edges(participants)
      |> add_temporal_edges(participants)

    %{
      nodes: Enum.map(participants, & &1.character_id),
      edges: edges
    }
  end

  defp build_corporation_edges(participants) do
    # Characters in same corporation are affiliated
    participants
    |> Enum.group_by(& &1.corporation_id)
    |> Enum.flat_map(fn {_corp_id, members} ->
      for p1 <- members, p2 <- members, p1.character_id != p2.character_id do
        {p1.character_id, p2.character_id, :corporation, 1.0}
      end
    end)
  end

  defp add_alliance_edges(edges, participants) do
    alliance_edges =
      participants
      |> Enum.reject(&is_nil(&1.alliance_id))
      |> Enum.group_by(& &1.alliance_id)
      |> Enum.flat_map(fn {_alliance_id, members} ->
        for p1 <- members, p2 <- members, p1.character_id != p2.character_id do
          {p1.character_id, p2.character_id, :alliance, 0.8}
        end
      end)

    edges ++ alliance_edges
  end

  defp add_damage_pattern_edges(edges, participants) do
    # Analyze who shoots whom to determine affiliations
    damage_edges =
      participants
      |> analyze_damage_patterns()
      |> Enum.map(fn {char1, char2, relationship} ->
        weight =
          case relationship do
            # They don't shoot each other
            :friendly -> 0.7
            # They actively shoot each other
            :hostile -> -0.9
          end

        {char1, char2, :damage_pattern, weight}
      end)

    edges ++ damage_edges
  end

  defp add_temporal_edges(edges, participants) do
    # Characters appearing at similar times might be coordinated
    temporal_edges =
      for {p1, i} <- Enum.with_index(participants),
          {p2, j} <- Enum.with_index(participants),
          i < j,
          similar_appearance_times?(p1, p2) do
        {p1.character_id, p2.character_id, :temporal, 0.3}
      end

    edges ++ temporal_edges
  end

  defp detect_sides(graph, participants) do
    # Use graph clustering to detect sides
    # For now, use a simple approach based on positive edge weights

    # Build adjacency list with positive edges only
    adjacency =
      graph.edges
      |> Enum.filter(fn {_, _, _, weight} -> weight > 0 end)
      |> Enum.reduce(%{}, fn {from, to, _type, weight}, acc ->
        acc
        |> Map.update(from, [{to, weight}], &[{to, weight} | &1])
        |> Map.update(to, [{from, weight}], &[{from, weight} | &1])
      end)

    # Find connected components
    components = find_connected_components(graph.nodes, adjacency)

    # Convert components to sides
    components
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "side_#{index + 1}",
        members: MapSet.new(members),
        strength: calculate_side_strength(members, participants),
        cohesion: calculate_side_cohesion(members, adjacency)
      }
    end)
    |> identify_third_parties()
  end

  defp find_connected_components(nodes, adjacency) do
    nodes
    |> Enum.reduce({[], MapSet.new()}, fn node, {components, visited} ->
      if MapSet.member?(visited, node) do
        {components, visited}
      else
        component = explore_component(node, adjacency, MapSet.new())
        {[MapSet.to_list(component) | components], MapSet.union(visited, component)}
      end
    end)
    |> elem(0)
  end

  defp explore_component(node, adjacency, visited) do
    if MapSet.member?(visited, node) do
      visited
    else
      visited = MapSet.put(visited, node)

      neighbors =
        Map.get(adjacency, node, [])
        |> Enum.map(&elem(&1, 0))

      Enum.reduce(neighbors, visited, fn neighbor, acc ->
        explore_component(neighbor, adjacency, acc)
      end)
    end
  end

  defp identify_third_parties(sides) do
    # Small sides might be third parties
    total_members =
      Enum.reduce(sides, 0, fn side, acc ->
        acc + MapSet.size(side.members)
      end)

    Enum.map(sides, fn side ->
      size_ratio = MapSet.size(side.members) / max(total_members, 1)
      is_third_party = size_ratio < 0.1 && MapSet.size(side.members) < 5

      Map.put(side, :is_third_party, is_third_party)
    end)
  end

  defp find_participant_side(participant, sides) do
    side =
      Enum.find(sides, fn side ->
        MapSet.member?(side.members, participant.character_id)
      end)

    if side do
      if side.is_third_party do
        :third_party
      else
        # Convert to atom safely - side.id is generated internally as "side_N"
        String.to_existing_atom(side.id)
      end
    else
      :unknown
    end
  end

  defp calculate_affiliation_strength(_participant, side, sides) do
    # How strongly affiliated is this participant with their side?
    side_data =
      Enum.find(sides, fn s ->
        # Convert to atom safely - s.id is generated internally as "side_N"
        String.to_existing_atom(s.id) == side || (s.is_third_party && side == :third_party)
      end)

    if side_data do
      # Base strength on cohesion and participant's connection to side
      side_data.cohesion * 0.5 + 0.5
    else
      0.0
    end
  end

  defp third_party?(participant, sides) do
    side =
      Enum.find(sides, fn side ->
        MapSet.member?(side.members, participant.character_id)
      end)

    side && side.is_third_party
  end

  defp analyze_damage_patterns(participants) do
    # Analyze who damages whom to determine relationships
    participants
    |> Enum.flat_map(fn participant ->
      if participant.participant_type == :victim do
        # This participant was killed - mark hostile relationships with attackers
        participant[:killmail_ids]
        |> Enum.flat_map(fn _km_id ->
          # In real implementation, would look up attackers for this killmail
          # For now, return empty list
          []
        end)
      else
        []
      end
    end)
  end

  defp similar_appearance_times?(p1, p2) do
    # Check if participants appear at similar times
    times1 = p1[:killmail_times] || []
    times2 = p2[:killmail_times] || []

    # Find overlapping time windows
    Enum.any?(times1, fn t1 ->
      Enum.any?(times2, fn t2 ->
        DateTime.diff(t1, t2, :minute) <= 5
      end)
    end)
  end

  defp calculate_side_strength(members, participants) do
    # Calculate combined strength of a side
    side_participants = Enum.filter(participants, &(&1.character_id in members))

    total_damage = Enum.reduce(side_participants, 0, &(&1[:total_damage_done] + &2))
    member_count = length(members)

    # Normalize strength
    total_damage / 1_000_000 + member_count * 10
  end

  defp calculate_side_cohesion(members, adjacency) do
    # Calculate how well-connected members of a side are
    if length(members) < 2 do
      1.0
    else
      # Count internal connections
      internal_edges =
        members
        |> Enum.flat_map(fn member ->
          Map.get(adjacency, member, [])
          |> Enum.filter(fn {neighbor, _} -> neighbor in members end)
        end)
        |> length()

      # Maximum possible edges
      max_edges = length(members) * (length(members) - 1)

      if max_edges > 0 do
        internal_edges / max_edges
      else
        0.0
      end
    end
  end
end
