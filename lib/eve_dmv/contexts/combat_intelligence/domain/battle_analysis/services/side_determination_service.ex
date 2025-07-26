defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Services.SideDeterminationService do
  @moduledoc """
  Service for determining which side participants belong to in a battle.

  Uses alliance and corporation relationships, attack patterns, and kill/death
  relationships to group participants into opposing sides.
  """

  require Logger

  @doc """
  Classify participants into sides based on their relationships and combat patterns.

  Returns a map with :side_a and :side_b lists of participants, or :unknown for
  participants that couldn't be clearly assigned.
  """
  def classify_participants(participants, killmails) do
    # Build relationship graph from killmails
    relationship_graph = build_relationship_graph(killmails)

    # Group by alliance/corporation affiliations
    affiliation_groups = group_by_affiliations(participants)

    # Analyze attack patterns to determine opposing sides
    opposing_groups = analyze_attack_patterns(relationship_graph, affiliation_groups)

    # Assign final sides
    assign_sides(opposing_groups, participants)
  end

  @doc """
  Determine which side a specific participant is on based on their affiliations.
  """
  def determine_participant_side(participant, battle_context) do
    alliance_id = Map.get(participant, :alliance_id)
    corporation_id = Map.get(participant, :corporation_id)
    character_id = Map.get(participant, :character_id)

    cond do
      # Check if part of a known alliance group
      alliance_id && alliance_id != 0 ->
        determine_by_alliance(alliance_id, battle_context)

      # Check corporation if no alliance
      corporation_id && corporation_id != 0 ->
        determine_by_corporation(corporation_id, battle_context)

      # Try to determine by character relationships
      character_id ->
        determine_by_character_relationships(character_id, battle_context)

      # Cannot determine
      true ->
        :unknown
    end
  end

  @doc """
  Build a relationship graph from killmail data showing who killed whom.
  """
  def build_relationship_graph(killmails) do
    killmails
    |> Enum.reduce(%{kills: %{}, deaths: %{}, alliances: %{}, corporations: %{}}, fn killmail,
                                                                                     acc ->
      victim_alliance = Map.get(killmail, :victim_alliance_id)
      victim_corp = Map.get(killmail, :victim_corporation_id)
      victim_char = Map.get(killmail, :victim_character_id)

      attackers = Map.get(killmail, :attackers, [])

      # Track deaths
      acc =
        if victim_char do
          acc
          |> update_in([:deaths, victim_char], &[killmail | &1 || []])
          |> put_in([:alliances, victim_char], victim_alliance)
          |> put_in([:corporations, victim_char], victim_corp)
        else
          acc
        end

      # Track kills for each attacker
      Enum.reduce(attackers, acc, fn attacker, inner_acc ->
        attacker_char = Map.get(attacker, :character_id)
        attacker_alliance = Map.get(attacker, :alliance_id)
        attacker_corp = Map.get(attacker, :corporation_id)

        if attacker_char do
          inner_acc
          |> update_in([:kills, attacker_char], &[{victim_char, killmail} | &1 || []])
          |> put_in([:alliances, attacker_char], attacker_alliance)
          |> put_in([:corporations, attacker_char], attacker_corp)
        else
          inner_acc
        end
      end)
    end)
  end

  @doc """
  Group participants by their alliance and corporation affiliations.
  """
  def group_by_affiliations(participants) do
    participants
    |> Enum.group_by(fn participant ->
      alliance_id = Map.get(participant, :alliance_id)
      corp_id = Map.get(participant, :corporation_id)

      cond do
        alliance_id && alliance_id != 0 -> {:alliance, alliance_id}
        corp_id && corp_id != 0 -> {:corporation, corp_id}
        true -> {:unaffiliated, Map.get(participant, :character_id)}
      end
    end)
    |> Enum.map(fn {key, members} ->
      %{
        affiliation: key,
        members: members,
        member_ids: Enum.map(members, &Map.get(&1, :character_id))
      }
    end)
  end

  @doc """
  Analyze attack patterns to determine which groups are opposing each other.
  """
  def analyze_attack_patterns(relationship_graph, affiliation_groups) do
    # Calculate hostility matrix between groups
    hostility_matrix = calculate_hostility_matrix(relationship_graph, affiliation_groups)

    # Cluster groups into opposing sides based on hostility
    cluster_into_sides(hostility_matrix, affiliation_groups)
  end

  defp calculate_hostility_matrix(relationship_graph, affiliation_groups) do
    # For each pair of groups, calculate hostility score
    for group_a <- affiliation_groups,
        group_b <- affiliation_groups,
        group_a != group_b do
      # Count kills between groups
      kills_a_to_b =
        count_kills_between_groups(
          group_a.member_ids,
          group_b.member_ids,
          relationship_graph.kills
        )

      kills_b_to_a =
        count_kills_between_groups(
          group_b.member_ids,
          group_a.member_ids,
          relationship_graph.kills
        )

      total_hostility = kills_a_to_b + kills_b_to_a

      {{group_a.affiliation, group_b.affiliation}, total_hostility}
    end
    |> Map.new()
  end

  defp count_kills_between_groups(group_a_members, group_b_members, kills_map) do
    group_a_members
    |> Enum.map(fn member_id ->
      kills = Map.get(kills_map, member_id, [])

      Enum.count(kills, fn {victim_id, _} ->
        victim_id in group_b_members
      end)
    end)
    |> Enum.sum()
  end

  defp cluster_into_sides(hostility_matrix, affiliation_groups) do
    # Simple clustering: groups that don't attack each other are on same side
    # Groups that attack each other are on opposite sides

    # Start with first group as side A
    if Enum.empty?(affiliation_groups) do
      %{side_a: [], side_b: []}
    else
      [first_group | rest] = affiliation_groups

      # Recursively assign groups to sides
      initial_sides = %{
        side_a: [first_group],
        side_b: [],
        unassigned: rest
      }

      assign_groups_to_sides(initial_sides, hostility_matrix)
    end
  end

  defp assign_groups_to_sides(%{unassigned: []} = sides, _hostility_matrix) do
    Map.take(sides, [:side_a, :side_b])
  end

  defp assign_groups_to_sides(%{unassigned: [group | rest]} = sides, hostility_matrix) do
    # Calculate average hostility to each side
    hostility_to_a =
      calculate_average_hostility_to_side(
        group,
        sides.side_a,
        hostility_matrix
      )

    hostility_to_b =
      calculate_average_hostility_to_side(
        group,
        sides.side_b,
        hostility_matrix
      )

    # Assign to side with lower hostility (allies)
    updated_sides =
      cond do
        Enum.empty?(sides.side_b) and hostility_to_a > 0 ->
          # First hostile group goes to side B
          %{sides | side_b: [group | sides.side_b], unassigned: rest}

        hostility_to_a <= hostility_to_b ->
          %{sides | side_a: [group | sides.side_a], unassigned: rest}

        true ->
          %{sides | side_b: [group | sides.side_b], unassigned: rest}
      end

    assign_groups_to_sides(updated_sides, hostility_matrix)
  end

  defp calculate_average_hostility_to_side(group, side_groups, hostility_matrix) do
    if Enum.empty?(side_groups) do
      0
    else
      total_hostility =
        Enum.sum(
          for side_group <- side_groups do
            key1 = {group.affiliation, side_group.affiliation}
            key2 = {side_group.affiliation, group.affiliation}

            Map.get(hostility_matrix, key1, 0) + Map.get(hostility_matrix, key2, 0)
          end
        )

      total_hostility / length(side_groups)
    end
  end

  defp assign_sides(opposing_groups, participants) do
    # Map affiliation groups back to participants
    side_a_affiliations =
      Enum.flat_map(opposing_groups.side_a, fn group ->
        [group.affiliation]
      end)

    side_b_affiliations =
      Enum.flat_map(opposing_groups.side_b, fn group ->
        [group.affiliation]
      end)

    # Assign participants to sides
    grouped =
      Enum.group_by(participants, fn participant ->
        alliance_id = Map.get(participant, :alliance_id)
        corp_id = Map.get(participant, :corporation_id)

        affiliation =
          cond do
            alliance_id && alliance_id != 0 -> {:alliance, alliance_id}
            corp_id && corp_id != 0 -> {:corporation, corp_id}
            true -> {:unaffiliated, Map.get(participant, :character_id)}
          end

        cond do
          affiliation in side_a_affiliations -> :side_a
          affiliation in side_b_affiliations -> :side_b
          true -> :unknown
        end
      end)

    %{
      side_a: Map.get(grouped, :side_a, []),
      side_b: Map.get(grouped, :side_b, []),
      unknown: Map.get(grouped, :unknown, [])
    }
  end

  defp determine_by_alliance(alliance_id, battle_context) do
    # Check if alliance is in side A alliances
    if alliance_id in Map.get(battle_context, :side_a_alliances, []) do
      :side_a
    else
      if alliance_id in Map.get(battle_context, :side_b_alliances, []) do
        :side_b
      else
        :unknown
      end
    end
  end

  defp determine_by_corporation(corporation_id, battle_context) do
    # Check if corporation is in side A corporations
    if corporation_id in Map.get(battle_context, :side_a_corporations, []) do
      :side_a
    else
      if corporation_id in Map.get(battle_context, :side_b_corporations, []) do
        :side_b
      else
        :unknown
      end
    end
  end

  defp determine_by_character_relationships(character_id, battle_context) do
    # Look at who this character killed and who killed them
    kills = Map.get(battle_context.relationship_graph.kills, character_id, [])
    deaths = Map.get(battle_context.relationship_graph.deaths, character_id, [])

    # Count kills against each side
    side_a_kills =
      Enum.count(kills, fn {victim_id, _} ->
        victim_id in battle_context.side_a_members
      end)

    side_b_kills =
      Enum.count(kills, fn {victim_id, _} ->
        victim_id in battle_context.side_b_members
      end)

    # Character likely on opposite side of their victims
    cond do
      side_a_kills > side_b_kills -> :side_b
      side_b_kills > side_a_kills -> :side_a
      true -> :unknown
    end
  end
end
