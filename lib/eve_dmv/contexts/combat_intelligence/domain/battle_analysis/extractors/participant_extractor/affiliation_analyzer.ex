defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.
            AffiliationAnalyzer do
  @moduledoc """
  Analyzes participant affiliations and relationships in battles.

  Handles corporation, alliance, and coalition identification, as well as
  relationship mapping between different groups.
  """

  require Logger

  @doc """
  Group participants by their affiliations.
  """
  def group_participants_by_affiliation(participants) do
    by_corporation = group_by_corporation(participants)
    by_alliance = group_by_alliance(participants)

    # Analyze cooperation between alliances to identify potential coalitions
    cooperation_matrix = analyze_alliance_cooperation(participants)
    coalitions = identify_potential_coalitions(cooperation_matrix)

    # Group by security status as well
    by_security = group_by_security_status(participants)

    %{
      corporations: %{
        groups: by_corporation,
        total: map_size(by_corporation),
        npc_count: count_npc_corporations(by_corporation),
        strength_distribution: calculate_corporation_strengths(by_corporation)
      },
      alliances: %{
        groups: by_alliance,
        total: map_size(by_alliance),
        strength_distribution: calculate_alliance_strengths(by_alliance)
      },
      coalitions: coalitions,
      security_standings: by_security,
      analysis: %{
        fragmentation_level: calculate_fragmentation_level(by_corporation, by_alliance),
        dominant_corporation: find_strongest_group(by_corporation),
        dominant_alliance: find_strongest_group(by_alliance),
        diversity_score: calculate_affiliation_diversity_score(by_corporation, by_alliance)
      }
    }
  end

  @doc """
  Group participants by corporation.
  """
  def group_by_corporation(participants) do
    participants
    |> Enum.group_by(& &1.corporation_id)
    |> Enum.map(fn {corp_id, corp_participants} ->
      {corp_id,
       %{
         name: List.first(corp_participants).corporation_name,
         member_count: length(corp_participants),
         members: corp_participants,
         alliance_id: List.first(corp_participants).alliance_id
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Group participants by alliance.
  """
  def group_by_alliance(participants) do
    participants
    |> Enum.filter(& &1.alliance_id)
    |> Enum.group_by(& &1.alliance_id)
    |> Enum.map(fn {alliance_id, alliance_participants} ->
      {alliance_id,
       %{
         name: List.first(alliance_participants).alliance_name,
         member_count: length(alliance_participants),
         members: alliance_participants,
         corporations: Enum.uniq_by(alliance_participants, & &1.corporation_id)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Identify coalitions based on cooperation patterns.
  """
  def identify_coalitions(participants) do
    # Identify coalitions based on alliance cooperation patterns and shared engagement patterns
    if Enum.empty?(participants) do
      %{}
    else
      # Group participants by alliance
      alliances =
        participants
        |> Enum.filter(&Map.get(&1, :alliance_id))
        |> Enum.group_by(&Map.get(&1, :alliance_id))

      if map_size(alliances) < 2 do
        # Need at least 2 alliances for coalition analysis
        %{}
      else
        alliance_ids = Map.keys(alliances)

        # Calculate cooperation matrix between alliances
        cooperation_scores =
          for alliance_a <- alliance_ids,
              alliance_b <- alliance_ids,
              alliance_a != alliance_b,
              into: %{} do
            score = calculate_alliance_cooperation_score(alliance_a, alliance_b, participants)
            {{alliance_a, alliance_b}, score}
          end

        # Find strongly cooperating alliances (cooperation score > 0.7)
        strong_cooperations =
          cooperation_scores
          |> Enum.filter(fn {_pair, score} -> score > 0.7 end)
          |> Enum.map(fn {{a, b}, score} -> {a, b, score} end)

        # Build coalition groups using graph clustering
        coalitions = build_coalition_clusters(strong_cooperations, alliance_ids)

        # Add coalition metadata
        coalitions
        |> Enum.with_index(1)
        |> Enum.map(fn {alliance_list, index} ->
          coalition_participants = get_coalition_participants(alliance_list, alliances)
          total_strength = length(coalition_participants)

          {"coalition_#{index}",
           %{
             alliances: alliance_list,
             participant_count: total_strength,
             alliance_count: length(alliance_list),
             participants: coalition_participants,
             average_cooperation:
               calculate_average_cooperation(alliance_list, cooperation_scores),
             formation_type: classify_coalition_type(alliance_list, cooperation_scores)
           }}
        end)
        |> Enum.into(%{})
      end
    end
  end

  defp get_coalition_participants(alliance_list, alliances) do
    alliance_list
    |> Enum.flat_map(fn alliance_id -> Map.get(alliances, alliance_id, []) end)
  end

  defp calculate_diversity_score(sizes, total) do
    sizes
    |> Enum.map(fn size ->
      if size > 0 do
        p = size / total
        -p * :math.log(p)
      else
        0
      end
    end)
    |> Enum.sum()
  end

  @doc """
  Identify neutral parties in the battle.
  """
  def identify_neutral_parties(participants) do
    # Identify neutral parties based on their engagement patterns and affiliations
    if Enum.empty?(participants) do
      []
    else
      # Group participants by affiliation (alliance or corporation)
      affiliation_groups =
        Enum.group_by(participants, fn p ->
          Map.get(p, :alliance_id) || Map.get(p, :corporation_id)
        end)

      # Find affiliations that have members on both sides of the conflict
      neutral_affiliations =
        Enum.filter(affiliation_groups, fn {_affiliation_id, members} ->
          participant_types = Enum.map(members, &Map.get(&1, :participant_type)) |> Enum.uniq()

          # Neutral if they have both attackers and victims in their ranks
          length(participant_types) > 1 and :attacker in participant_types and
            :victim in participant_types
        end)
        |> Enum.map(fn {affiliation_id, members} ->
          attackers = Enum.filter(members, &(Map.get(&1, :participant_type) == :attacker))
          victims = Enum.filter(members, &(Map.get(&1, :participant_type) == :victim))

          %{
            affiliation_id: affiliation_id,
            affiliation_type: determine_affiliation_type(affiliation_id, members),
            affiliation_name: get_affiliation_name(members),
            total_members: length(members),
            attackers: length(attackers),
            victims: length(victims),
            neutrality_score: calculate_neutrality_score(attackers, victims),
            neutrality_reason: determine_neutrality_reason(attackers, victims),
            members: members
          }
        end)

      # Also identify individual neutral characters (those with very high security status in low-sec fights)
      individual_neutrals =
        Enum.filter(participants, fn participant ->
          security_status = Map.get(participant, :security_status, 0.0)
          participant_type = Map.get(participant, :participant_type)

          # High security status players in PvP might be neutral logistics or tackled innocents
          security_status >= 3.0 and participant_type == :victim
        end)
        |> Enum.map(fn participant ->
          %{
            type: :individual,
            character_id: Map.get(participant, :character_id),
            character_name: Map.get(participant, :character_name),
            security_status: Map.get(participant, :security_status, 0.0),
            neutrality_reason: "High security status victim (likely neutral/innocent)",
            participant: participant
          }
        end)

      # Combine affiliation-based and individual neutrals
      affiliation_neutrals = Enum.map(neutral_affiliations, &Map.put(&1, :type, :affiliation))

      affiliation_neutrals ++ individual_neutrals
    end
  end

  @doc """
  Build a comprehensive relationship map between participants.
  """
  def build_relationship_map(participants) do
    # Build a comprehensive relationship map based on engagement patterns
    if Enum.empty?(participants) do
      %{allies: %{}, enemies: %{}, neutrals: %{}}
    else
      # Group participants by their affiliations
      affiliation_groups =
        participants
        |> Enum.filter(&(Map.get(&1, :alliance_id) || Map.get(&1, :corporation_id)))
        |> Enum.group_by(fn p ->
          {Map.get(p, :alliance_id) || Map.get(p, :corporation_id), get_affiliation_name([p])}
        end)

      if map_size(affiliation_groups) < 2 do
        # Need at least 2 affiliations for relationship analysis
        %{allies: %{}, enemies: %{}, neutrals: %{}}
      else
        affiliation_keys = Map.keys(affiliation_groups)

        # Calculate relationships between all affiliation pairs
        relationships =
          for {id_a, name_a} <- affiliation_keys,
              {id_b, name_b} <- affiliation_keys,
              id_a != id_b,
              into: %{} do
            participants_a = Map.get(affiliation_groups, {id_a, name_a}, [])
            participants_b = Map.get(affiliation_groups, {id_b, name_b}, [])

            relationship = determine_relationship(participants_a, participants_b)

            {{id_a, name_a}, {id_b, name_b}}
            {{id_a, name_a}, Map.put(relationship, :affiliation_name, name_b)}
          end

        # Group relationships by type
        grouped_relationships =
          relationships
          |> Enum.group_by(fn {_key, relationship} ->
            Map.get(relationship, :relationship_type, :unknown)
          end)

        # Build the final relationship map
        %{
          allies:
            build_relationship_section(
              Map.get(grouped_relationships, :allied, []),
              affiliation_groups
            ),
          enemies:
            build_relationship_section(
              Map.get(grouped_relationships, :hostile, []),
              affiliation_groups
            ),
          neutrals:
            build_relationship_section(
              Map.get(grouped_relationships, :neutral, []),
              affiliation_groups
            ),
          analysis: %{
            total_affiliations: length(affiliation_keys),
            alliance_count: count_alliances(affiliation_groups),
            corporation_count: count_corporations(affiliation_groups),
            relationship_complexity: assess_relationship_complexity(grouped_relationships)
          }
        }
      end
    end
  end

  @doc """
  Calculate metrics for affiliations.
  """
  def calculate_affiliation_metrics(corporations, alliances, coalitions) do
    %{
      corporation_count: map_size(corporations),
      alliance_count: map_size(alliances),
      coalition_count: map_size(coalitions),
      average_corporation_size: calculate_average_group_size(corporations),
      average_alliance_size: calculate_average_group_size(alliances),
      fragmentation_score: calculate_fragmentation_score(corporations, alliances)
    }
  end

  @doc """
  Find the dominant affiliation in a group.
  """
  def find_dominant_affiliation(affiliation_groups) do
    if map_size(affiliation_groups) == 0 do
      nil
    else
      {id, data} =
        affiliation_groups
        |> Enum.max_by(fn {_id, group} -> Map.get(group, :member_count, 0) end)

      %{id: id, name: Map.get(data, :name), member_count: Map.get(data, :member_count)}
    end
  end

  @doc """
  Calculate diversity of affiliations.
  """
  def calculate_affiliation_diversity(corporations, alliances) do
    corp_diversity = calculate_group_diversity(corporations)
    alliance_diversity = calculate_group_diversity(alliances)
    (corp_diversity + alliance_diversity) / 2.0
  end

  # Private functions

  defp analyze_alliance_cooperation(participants) do
    # Build cooperation scores between alliances based on shared battles
    alliances = group_by_alliance(participants)
    alliance_ids = Map.keys(alliances)

    if length(alliance_ids) < 2 do
      %{}
    else
      for alliance_a <- alliance_ids,
          alliance_b <- alliance_ids,
          alliance_a < alliance_b,
          into: %{} do
        score = calculate_cooperation_score(alliance_a, alliance_b, participants)
        {{alliance_a, alliance_b}, score}
      end
    end
  end

  defp calculate_cooperation_score(alliance_a, alliance_b, participants) do
    # Calculate how often these alliances fight together vs against each other
    a_participants = Enum.filter(participants, &(&1.alliance_id == alliance_a))
    b_participants = Enum.filter(participants, &(&1.alliance_id == alliance_b))

    a_attackers = Enum.count(a_participants, &(&1.participant_type == :attacker))
    a_victims = Enum.count(a_participants, &(&1.participant_type == :victim))
    b_attackers = Enum.count(b_participants, &(&1.participant_type == :attacker))
    b_victims = Enum.count(b_participants, &(&1.participant_type == :victim))

    # High score if both are primarily attackers or both primarily victims
    if (a_attackers > a_victims and b_attackers > b_victims) or
         (a_victims > a_attackers and b_victims > b_attackers) do
      0.8
    else
      0.2
    end
  end

  defp identify_potential_coalitions(cooperation_matrix) do
    # Simple clustering to identify groups of cooperating alliances
    cooperation_matrix
    |> Enum.filter(fn {_pair, score} -> score > 0.6 end)
    |> Enum.reduce(%{}, fn {{alliance_a, alliance_b}, _score}, coalitions ->
      # Find or create coalition for these alliances
      coalition_key = find_coalition_key(coalitions, alliance_a, alliance_b)

      if coalition_key do
        # Add to existing coalition
        Map.update!(coalitions, coalition_key, &Enum.uniq([alliance_a, alliance_b | &1]))
      else
        # Create new coalition
        Map.put(coalitions, "coalition_#{map_size(coalitions) + 1}", [alliance_a, alliance_b])
      end
    end)
  end

  defp find_coalition_key(coalitions, alliance_a, alliance_b) do
    Enum.find_value(coalitions, fn {key, members} ->
      if alliance_a in members or alliance_b in members, do: key
    end)
  end

  defp group_by_security_status(participants) do
    participants
    |> Enum.group_by(fn participant ->
      security = Map.get(participant, :security_status, 0.0)

      cond do
        security < -5.0 -> :outlaw
        security < -2.0 -> :criminal
        security < 0.0 -> :suspect
        security >= 5.0 -> :high_sec_citizen
        true -> :neutral
      end
    end)
    |> Enum.map(fn {status, members} ->
      {status, %{count: length(members), members: members}}
    end)
    |> Enum.into(%{})
  end

  defp count_npc_corporations(corporation_groups) do
    corporation_groups
    |> Enum.count(fn {corp_id, _data} -> npc_corporation?(corp_id) end)
  end

  defp npc_corporation?(corp_id) when is_nil(corp_id), do: true
  defp npc_corporation?(corp_id) when corp_id < 2_000_000, do: true
  defp npc_corporation?(_corp_id), do: false

  defp calculate_corporation_strengths(by_corporation) do
    Enum.map(by_corporation, fn {_corp_id, data} ->
      Map.get(data, :member_count, 0)
    end)
    |> Enum.frequencies()
  end

  defp calculate_alliance_strengths(by_alliance) do
    Enum.map(by_alliance, fn {_alliance_id, data} ->
      Map.get(data, :member_count, 0)
    end)
    |> Enum.frequencies()
  end

  defp find_strongest_group(strength_map) do
    if map_size(strength_map) == 0 do
      nil
    else
      {id, data} =
        Enum.max_by(strength_map, fn {_id, data} -> Map.get(data, :member_count, 0) end)

      %{id: id, name: Map.get(data, :name), strength: Map.get(data, :member_count)}
    end
  end

  defp calculate_fragmentation_level(by_corporation, by_alliance) do
    total_corps = map_size(by_corporation)
    total_alliances = map_size(by_alliance)

    cond do
      total_corps <= 2 -> :unified
      total_alliances >= total_corps * 0.8 -> :highly_fragmented
      total_alliances >= total_corps * 0.5 -> :fragmented
      total_alliances >= total_corps * 0.3 -> :moderately_fragmented
      true -> :consolidated
    end
  end

  defp calculate_affiliation_diversity_score(by_corporation, by_alliance) do
    corp_sizes = Map.values(by_corporation) |> Enum.map(&Map.get(&1, :member_count, 0))
    alliance_sizes = Map.values(by_alliance) |> Enum.map(&Map.get(&1, :member_count, 0))

    corp_diversity = calculate_size_diversity(corp_sizes)
    alliance_diversity = calculate_size_diversity(alliance_sizes)

    (corp_diversity + alliance_diversity) / 2.0
  end

  defp calculate_size_diversity(sizes) when sizes == [], do: 0.0

  defp calculate_size_diversity(sizes) do
    total = Enum.sum(sizes)

    if total == 0 do
      0.0
    else
      # Shannon diversity index
      sizes
      |> Enum.map(fn size ->
        if size > 0 do
          proportion = size / total
          -proportion * :math.log(proportion)
        else
          0
        end
      end)
      |> Enum.sum()
      |> normalize_diversity_score()
    end
  end

  defp normalize_diversity_score(raw_score) do
    # Normalize to 0-1 range
    min(1.0, raw_score / :math.log(10))
  end

  defp calculate_alliance_cooperation_score(alliance_a, alliance_b, participants) do
    # Calculate cooperation based on shared engagement patterns
    a_participants = Enum.filter(participants, &(Map.get(&1, :alliance_id) == alliance_a))
    b_participants = Enum.filter(participants, &(Map.get(&1, :alliance_id) == alliance_b))

    # Check if alliances were on the same side (both attackers or both victims)
    a_types = Enum.map(a_participants, &Map.get(&1, :participant_type)) |> Enum.uniq()
    b_types = Enum.map(b_participants, &Map.get(&1, :participant_type)) |> Enum.uniq()

    base_cooperation =
      case {a_types, b_types} do
        # Strong cooperation if both attacking
        {[:attacker], [:attacker]} -> 0.8
        # Moderate cooperation if both victims
        {[:victim], [:victim]} -> 0.6
        # No cooperation if on different sides
        _ -> 0.0
      end

    # Bonus for similar security status (indicates similar space usage)
    a_avg_sec =
      a_participants |> Enum.map(&Map.get(&1, :security_status, 0.0)) |> average_or_zero()

    b_avg_sec =
      b_participants |> Enum.map(&Map.get(&1, :security_status, 0.0)) |> average_or_zero()

    security_similarity = 1.0 - min(abs(a_avg_sec - b_avg_sec) / 10.0, 1.0)
    security_bonus = security_similarity * 0.2

    min(1.0, base_cooperation + security_bonus)
  end

  defp build_coalition_clusters(cooperations, alliance_ids) do
    # Simple clustering: start with each alliance and merge based on strong cooperation
    initial_clusters = Enum.map(alliance_ids, &[&1])

    Enum.reduce(cooperations, initial_clusters, fn {alliance_a, alliance_b, _score}, clusters ->
      merge_clusters_containing(clusters, alliance_a, alliance_b)
    end)
    # Only return actual coalitions (2+ alliances)
    |> Enum.filter(&(length(&1) > 1))
  end

  defp merge_clusters_containing(clusters, alliance_a, alliance_b) do
    cluster_a_idx = Enum.find_index(clusters, &(alliance_a in &1))
    cluster_b_idx = Enum.find_index(clusters, &(alliance_b in &1))

    case {cluster_a_idx, cluster_b_idx} do
      {idx_a, idx_b} when idx_a != nil and idx_b != nil and idx_a != idx_b ->
        # Merge the two clusters
        cluster_a = Enum.at(clusters, idx_a)
        cluster_b = Enum.at(clusters, idx_b)
        merged_cluster = Enum.uniq(cluster_a ++ cluster_b)

        clusters
        # Delete higher index first
        |> List.delete_at(max(idx_a, idx_b))
        |> List.delete_at(min(idx_a, idx_b))
        |> List.insert_at(0, merged_cluster)

      _ ->
        # Alliances already in same cluster or one not found
        clusters
    end
  end

  defp calculate_average_cooperation(alliance_list, cooperation_scores) do
    if length(alliance_list) < 2 do
      0.0
    else
      pairs = for a <- alliance_list, b <- alliance_list, a != b, do: {a, b}
      scores = Enum.map(pairs, &Map.get(cooperation_scores, &1, 0.0))

      if Enum.empty?(scores), do: 0.0, else: Enum.sum(scores) / length(scores)
    end
  end

  defp classify_coalition_type(alliance_list, cooperation_scores) do
    avg_cooperation = calculate_average_cooperation(alliance_list, cooperation_scores)

    case {length(alliance_list), avg_cooperation} do
      {count, coop} when count >= 4 and coop >= 0.9 -> :major_coalition
      {count, coop} when count >= 3 and coop >= 0.8 -> :alliance_bloc
      {count, coop} when count >= 2 and coop >= 0.7 -> :tactical_partnership
      _ -> :loose_cooperation
    end
  end

  defp average_or_zero([]), do: 0.0
  defp average_or_zero(list), do: Enum.sum(list) / length(list)

  defp determine_affiliation_type(affiliation_id, members) do
    # Determine if this is an alliance or corporation
    first_member = List.first(members)

    if Map.get(first_member, :alliance_id) == affiliation_id do
      :alliance
    else
      :corporation
    end
  end

  defp get_affiliation_name(members) do
    first_member = List.first(members)

    # Try to get alliance name first, then corporation name
    Map.get(first_member, :alliance_name) ||
      Map.get(first_member, :corporation_name) ||
      "Unknown"
  end

  defp calculate_neutrality_score(attackers, victims) do
    total = length(attackers) + length(victims)

    if total == 0 do
      0.0
    else
      # Perfect neutrality (50/50 split) gets score of 1.0
      attacker_ratio = length(attackers) / total
      _victim_ratio = length(victims) / total

      # Calculate how close to 50/50 split this is
      deviation_from_neutral = abs(0.5 - attacker_ratio)
      # Scale to 0-1
      neutrality_score = 1.0 - deviation_from_neutral * 2.0

      Float.round(max(0.0, neutrality_score), 2)
    end
  end

  defp determine_neutrality_reason(attackers, victims) do
    attacker_count = length(attackers)
    victim_count = length(victims)
    total = attacker_count + victim_count

    cond do
      total <= 2 ->
        "Small affiliation with mixed engagement"

      attacker_count == victim_count ->
        "Perfectly balanced losses and attacks - likely internal conflict or opportunistic engagement"

      attacker_count > victim_count ->
        "More attackers than victims - possibly caught in crossfire or switching sides"

      victim_count > attacker_count ->
        "More victims than attackers - possibly targeted but fought back"

      true ->
        "Mixed engagement patterns indicate neutral or opportunistic behavior"
    end
  end

  defp determine_relationship(participants_a, participants_b) do
    # Analyze engagement patterns between two affiliations
    a_types = Enum.map(participants_a, &Map.get(&1, :participant_type)) |> Enum.frequencies()
    b_types = Enum.map(participants_b, &Map.get(&1, :participant_type)) |> Enum.frequencies()

    a_attackers = Map.get(a_types, :attacker, 0)
    a_victims = Map.get(a_types, :victim, 0)
    b_attackers = Map.get(b_types, :attacker, 0)
    b_victims = Map.get(b_types, :victim, 0)

    # Determine relationship based on who attacked whom
    relationship_type =
      cond do
        # Both groups were attackers - likely allies
        a_attackers > 0 and b_attackers > 0 and a_victims == 0 and b_victims == 0 ->
          :allied

        # Both groups were victims - likely allies under attack
        a_victims > 0 and b_victims > 0 and a_attackers == 0 and b_attackers == 0 ->
          :allied

        # One side all attackers, other all victims - clear hostility
        (a_attackers > 0 and a_victims == 0 and b_victims > 0 and b_attackers == 0) or
            (b_attackers > 0 and b_victims == 0 and a_victims > 0 and a_attackers == 0) ->
          :hostile

        # Mixed patterns - neutral or complex relationship
        true ->
          :neutral
      end

    # Calculate relationship strength
    total_a = a_attackers + a_victims
    total_b = b_attackers + b_victims

    strength =
      case relationship_type do
        :allied ->
          # Strength based on how much they fought on the same side
          same_side_ratio =
            if total_a > 0 and total_b > 0 do
              shared_side_count = min(a_attackers, b_attackers) + min(a_victims, b_victims)
              shared_side_count / max(total_a, total_b)
            else
              0.0
            end

          Float.round(same_side_ratio, 2)

        :hostile ->
          # Strength based on how much they fought against each other
          opposition_ratio =
            if total_a > 0 and total_b > 0 do
              (min(a_attackers, b_victims) + min(b_attackers, a_victims)) / max(total_a, total_b)
            else
              0.0
            end

          Float.round(opposition_ratio, 2)

        :neutral ->
          # Neutral relationships have lower strength
          0.3
      end

    %{
      relationship_type: relationship_type,
      strength: strength,
      participants_a_count: total_a,
      participants_b_count: total_b,
      engagement_summary: %{
        a_role: determine_primary_role(a_attackers, a_victims),
        b_role: determine_primary_role(b_attackers, b_victims),
        interaction_pattern:
          describe_interaction_pattern(a_attackers, a_victims, b_attackers, b_victims)
      }
    }
  end

  defp build_relationship_section(relationships, affiliation_groups) do
    relationships
    |> Enum.map(fn {{affiliation_key, name}, relationship_data} ->
      participants = Map.get(affiliation_groups, affiliation_key, [])

      {name,
       Map.merge(relationship_data, %{
         affiliation_id: elem(affiliation_key, 0),
         participant_count: length(participants),
         affiliation_type:
           if(elem(affiliation_key, 0) in Enum.map(participants, &Map.get(&1, :alliance_id)),
             do: :alliance,
             else: :corporation
           )
       })}
    end)
    |> Enum.into(%{})
  end

  defp count_alliances(affiliation_groups) do
    affiliation_groups
    |> Map.keys()
    |> Enum.count(fn {affiliation_id, _name} ->
      # Check if this ID appears in any participant's alliance_id field
      Map.values(affiliation_groups)
      |> List.flatten()
      |> Enum.any?(&(Map.get(&1, :alliance_id) == affiliation_id))
    end)
  end

  defp count_corporations(affiliation_groups) do
    length(Map.keys(affiliation_groups)) - count_alliances(affiliation_groups)
  end

  defp assess_relationship_complexity(grouped_relationships) do
    ally_count = length(Map.get(grouped_relationships, :allied, []))
    enemy_count = length(Map.get(grouped_relationships, :hostile, []))
    neutral_count = length(Map.get(grouped_relationships, :neutral, []))

    total_relationships = ally_count + enemy_count + neutral_count

    case {total_relationships, neutral_count} do
      {total, neutral} when total <= 4 and neutral == 0 -> :simple
      {total, neutral} when total <= 8 and neutral <= 2 -> :moderate
      {total, neutral} when neutral > total / 2 -> :highly_complex
      _ -> :complex
    end
  end

  defp determine_primary_role(attackers, victims) do
    cond do
      attackers > 0 and victims == 0 -> :pure_aggressor
      victims > 0 and attackers == 0 -> :pure_defender
      attackers > victims -> :primarily_aggressor
      victims > attackers -> :primarily_defender
      true -> :mixed_role
    end
  end

  defp describe_interaction_pattern(a_attackers, a_victims, b_attackers, b_victims) do
    cond do
      # Clear aggressor vs defender
      a_attackers > 0 and a_victims == 0 and b_victims > 0 and b_attackers == 0 ->
        "Group A attacked Group B"

      b_attackers > 0 and b_victims == 0 and a_victims > 0 and a_attackers == 0 ->
        "Group B attacked Group A"

      # Both attacking together
      a_attackers > a_victims and b_attackers > b_victims ->
        "Allied attack formation"

      # Both defending together
      a_victims > a_attackers and b_victims > b_attackers ->
        "Allied defense formation"

      # Complex engagement
      true ->
        "Complex multi-directional engagement"
    end
  end

  defp calculate_average_group_size(groups) do
    sizes = Map.values(groups) |> Enum.map(&Map.get(&1, :member_count, 0))

    if Enum.empty?(sizes) do
      0.0
    else
      Enum.sum(sizes) / length(sizes)
    end
  end

  defp calculate_fragmentation_score(corporations, alliances) do
    corp_count = map_size(corporations)
    alliance_count = map_size(alliances)

    if corp_count == 0 do
      0.0
    else
      # Higher score means more fragmented (many small groups)
      1.0 - alliance_count / corp_count
    end
  end

  defp calculate_group_diversity(groups) do
    sizes = Map.values(groups) |> Enum.map(&Map.get(&1, :member_count, 0))

    if Enum.empty?(sizes) do
      0.0
    else
      total = Enum.sum(sizes)

      if total == 0 do
        0.0
      else
        # Shannon diversity index normalized to 0-1
        calculate_diversity_score(sizes, total)
        |> (fn h -> h / :math.log(length(sizes)) end).()
        |> min(1.0)
      end
    end
  end
end
