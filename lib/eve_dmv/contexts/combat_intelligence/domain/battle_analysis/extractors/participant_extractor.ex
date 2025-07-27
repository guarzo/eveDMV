defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor do
  @moduledoc """
  Extractor for identifying and analyzing battle participants from killmail data.

  Processes killmail data to identify all participants in a battle, their roles,
  affiliations, and contributions to the engagement.
  """

  require Logger


  @doc """
  Extract battle participants from killmail data.
  """
  def extract_battle_participants(killmails) do
    Logger.debug("Extracting battle participants from #{length(killmails)} killmails")

    # Extract detailed participant data from killmail information
    participants =
      killmails
      |> Enum.flat_map(&extract_participants_from_killmail/1)
      |> Enum.uniq_by(& &1.character_id)
      |> Enum.map(&enrich_participant_data/1)
      |> Enum.map(&calculate_participant_metrics/1)

    %{
      participants: participants,
      total_count: length(participants),
      sides: classify_participants_by_side(participants),
      affiliations: group_participants_by_affiliation(participants),
      roles: analyze_participant_roles(participants)
    }
  end

  @doc """
  Analyze participant affiliations and relationships.
  """
  def analyze_participant_affiliations(participants) do
    Logger.debug("Analyzing participant affiliations for #{length(participants)} participants")

    # Perform comprehensive affiliation analysis
    corporations = group_by_corporation(participants)
    alliances = group_by_alliance(participants)
    coalitions = identify_coalitions(participants)
    neutral_parties = identify_neutral_parties(participants)
    relationship_map = build_relationship_map(participants)

    # Calculate affiliation strength and coherence metrics
    affiliation_metrics = calculate_affiliation_metrics(corporations, alliances, coalitions)

    %{
      corporations: corporations,
      alliances: alliances,
      coalitions: coalitions,
      neutral_parties: neutral_parties,
      relationship_map: relationship_map,
      metrics: affiliation_metrics,
      summary: %{
        dominant_corporation: find_dominant_affiliation(corporations),
        dominant_alliance: find_dominant_affiliation(alliances),
        coalition_count: length(coalitions),
        affiliation_diversity: calculate_affiliation_diversity(corporations, alliances)
      }
    }
  end

  @doc """
  Analyze participant combat roles and effectiveness.
  """
  def analyze_participant_roles(participants) do
    Logger.debug("Analyzing participant roles")

    # Perform comprehensive role analysis based on ship types and combat patterns
    role_distribution =
      participants
      |> Enum.group_by(&classify_participant_role/1)
      |> Enum.map(fn {role, role_participants} ->
        {role,
         %{
           count: length(role_participants),
           effectiveness: calculate_role_effectiveness(role_participants),
           key_players: identify_key_players(role_participants),
           survival_rate: calculate_role_survival_rate(role_participants),
           average_experience: calculate_average_role_experience(role_participants)
         }}
      end)
      |> Enum.into(%{})

    role_balance = analyze_role_balance(role_distribution)
    missing_roles = identify_missing_roles(role_distribution)
    role_synergies = analyze_role_synergies(role_distribution)

    %{
      role_distribution: role_distribution,
      role_balance: role_balance,
      missing_roles: missing_roles,
      role_synergies: role_synergies,
      summary: %{
        primary_doctrine: identify_primary_doctrine(role_distribution),
        role_diversity: calculate_role_diversity(role_distribution),
        doctrine_coherence: assess_doctrine_coherence(role_distribution),
        tactical_completeness: evaluate_tactical_completeness(role_distribution, missing_roles)
      }
    }
  end

  @doc """
  Analyze participant experience and skill levels.
  """
  def analyze_participant_experience(participants) do
    Logger.debug("Analyzing participant experience")

    # Analyze participant experience based on kill/death history and ship usage patterns
    experience_distribution = calculate_experience_distribution(participants)
    skill_levels = analyze_skill_levels(participants)
    veteran_players = identify_veteran_players(participants)
    rookie_players = identify_rookie_players(participants)
    experience_advantage = calculate_experience_advantage(participants)

    # Calculate additional experience metrics
    experience_gaps = identify_experience_gaps(veteran_players, rookie_players)
    leadership_potential = assess_leadership_potential(veteran_players)
    learning_curve = analyze_rookie_progression(rookie_players)

    %{
      experience_distribution: experience_distribution,
      skill_levels: skill_levels,
      veteran_players: veteran_players,
      rookie_players: rookie_players,
      experience_advantage: experience_advantage,
      experience_gaps: experience_gaps,
      leadership_potential: leadership_potential,
      learning_curve: learning_curve,
      summary: %{
        average_experience_level: calculate_average_experience(participants),
        experience_diversity: measure_experience_diversity(experience_distribution),
        mentorship_opportunities: identify_mentorship_pairs(veteran_players, rookie_players),
        fleet_maturity: assess_fleet_maturity(experience_distribution)
      }
    }
  end

  @doc """
  Track participant activity and contribution throughout the battle.
  """
  def track_participant_activity(participants, killmails) do
    Logger.debug("Tracking participant activity")

    # Track comprehensive participant activity throughout the battle
    participants
    |> Enum.map(fn participant ->
      # Calculate detailed activity metrics
      kills = count_participant_kills(participant, killmails)
      deaths = count_participant_deaths(participant, killmails)
      damage_dealt = calculate_damage_dealt(participant, killmails)
      damage_received = calculate_damage_received(participant, killmails)
      activity_timeline = build_activity_timeline(participant, killmails)

      # Calculate advanced metrics
      isk_efficiency = calculate_isk_efficiency(damage_dealt, damage_received)
      engagement_duration = calculate_engagement_duration(activity_timeline)
      combat_intensity = assess_combat_intensity(activity_timeline)
      tactical_impact = evaluate_tactical_impact(participant, killmails)

      activity = %{
        kills: kills,
        deaths: deaths,
        damage_dealt: damage_dealt,
        damage_received: damage_received,
        activity_timeline: activity_timeline,
        isk_efficiency: isk_efficiency,
        engagement_duration: engagement_duration,
        combat_intensity: combat_intensity,
        tactical_impact: tactical_impact,
        contribution_score: calculate_contribution_score(participant, killmails),
        survival_time: calculate_survival_time(participant, activity_timeline),
        peak_activity_period: identify_peak_activity(activity_timeline)
      }

      Map.put(participant, :activity, activity)
    end)
  end

  # Private helper functions
  defp extract_participants_from_killmail(killmail) do
    # Extract victim as participant
    victim = %{
      character_id: killmail.victim_character_id,
      character_name: killmail.victim_character_name,
      corporation_id: killmail.victim_corporation_id,
      corporation_name: killmail.victim_corporation_name,
      alliance_id: killmail.victim_alliance_id,
      alliance_name: killmail.victim_alliance_name,
      ship_type_id: killmail.victim_ship_type_id,
      ship_name: killmail.victim_ship_name,
      participant_type: :victim,
      tactical_role: determine_tactical_role(killmail.victim_ship_name),
      ship_class: classify_ship_class(killmail.victim_ship_name)
    }

    # Extract detailed attacker information from raw killmail data JSON
    attackers =
      case Map.get(killmail, :raw_data) do
        %{"attackers" => attacker_list} when is_list(attacker_list) ->
          Enum.map(attacker_list, fn attacker ->
            ship_type_id = Map.get(attacker, "ship_type_id")
            weapon_type_id = Map.get(attacker, "weapon_type_id")

            %{
              character_id: Map.get(attacker, "character_id"),
              character_name: Map.get(attacker, "character_name", "Unknown"),
              corporation_id: Map.get(attacker, "corporation_id"),
              corporation_name: Map.get(attacker, "corporation_name", "Unknown Corp"),
              alliance_id: Map.get(attacker, "alliance_id"),
              alliance_name: Map.get(attacker, "alliance_name"),
              ship_type_id: ship_type_id,
              ship_name: determine_ship_name(ship_type_id),
              weapon_type_id: weapon_type_id,
              damage_done: Map.get(attacker, "damage_done", 0),
              final_blow: Map.get(attacker, "final_blow", false),
              security_status: Map.get(attacker, "security_status", 0.0),
              participant_type: :attacker,
              tactical_role:
                determine_tactical_role_from_ship_and_weapon(ship_type_id, weapon_type_id),
              ship_class: classify_ship_class_by_type_id(ship_type_id)
            }
          end)

        _ ->
          # Fallback for missing data
          [
            %{
              character_id: nil,
              character_name: "Unknown Attacker",
              corporation_id: nil,
              corporation_name: "Unknown Corp",
              alliance_id: nil,
              alliance_name: nil,
              ship_type_id: nil,
              ship_name: "Unknown Ship",
              weapon_type_id: nil,
              damage_done: 0,
              final_blow: false,
              security_status: 0.0,
              participant_type: :attacker,
              tactical_role: :unknown,
              ship_class: :unknown
            }
          ]
      end

    [victim | attackers]
  end

  defp enrich_participant_data(participant) do
    # Enrich participant data with calculated metrics and historical context
    _character_id = Map.get(participant, :character_id)

    # Calculate enrichment data based on available information
    experience_level = estimate_experience_level(participant)
    threat_rating = estimate_threat_rating(participant)
    historical_performance = get_historical_performance(participant)
    specializations = identify_specializations(participant)
    activity_patterns = analyze_activity_patterns(participant)

    # Add calculated metrics
    combat_capability = assess_combat_capability(participant)
    strategic_value = evaluate_strategic_value(participant)
    reliability_score = calculate_reliability_score(participant)

    Map.merge(participant, %{
      experience_level: experience_level,
      threat_rating: threat_rating,
      historical_performance: historical_performance,
      specializations: specializations,
      activity_patterns: activity_patterns,
      combat_capability: combat_capability,
      strategic_value: strategic_value,
      reliability_score: reliability_score,
      enrichment_timestamp: DateTime.utc_now(),
      data_completeness: assess_data_completeness(participant)
    })
  end

  defp classify_participants_by_side(participants) do
    # Implement sophisticated side classification based on engagement patterns and affiliations

    # Group by alliance/corporation for better side identification
    _alliance_groups =
      Enum.group_by(participants, fn p ->
        Map.get(p, :alliance_id) || Map.get(p, :corporation_id)
      end)

    # Identify hostile relationships based on who attacked whom
    attackers = Enum.filter(participants, &(&1.participant_type == :attacker))
    victims = Enum.filter(participants, &(&1.participant_type == :victim))

    # Get unique alliances/corps from each side
    attacking_affiliations = get_unique_affiliations(attackers)
    victim_affiliations = get_unique_affiliations(victims)

    # Find neutral parties (those who appeared on both sides or didn't engage)
    neutral_affiliations =
      MapSet.intersection(
        MapSet.new(attacking_affiliations),
        MapSet.new(victim_affiliations)
      )

    # Classify all participants
    {side_a, side_b, neutrals} =
      Enum.reduce(participants, {[], [], []}, fn participant, {a, b, n} ->
        affiliation = get_participant_affiliation(participant)

        cond do
          MapSet.member?(neutral_affiliations, affiliation) ->
            {a, b, [participant | n]}

          affiliation in victim_affiliations ->
            {[participant | a], b, n}

          affiliation in attacking_affiliations ->
            {a, [participant | b], n}

          true ->
            {a, b, [participant | n]}
        end
      end)

    %{
      side_a: Enum.reverse(side_a),
      side_b: Enum.reverse(side_b),
      neutrals: Enum.reverse(neutrals),
      side_analysis: %{
        side_a_affiliations: length(Enum.uniq_by(side_a, &get_participant_affiliation/1)),
        side_b_affiliations: length(Enum.uniq_by(side_b, &get_participant_affiliation/1)),
        neutral_affiliations: length(Enum.uniq_by(neutrals, &get_participant_affiliation/1)),
        conflict_complexity: assess_conflict_complexity(side_a, side_b, neutrals)
      }
    }
  end

  defp get_unique_affiliations(participants) do
    participants
    |> Enum.map(&get_participant_affiliation/1)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  defp get_participant_affiliation(participant) do
    Map.get(participant, :alliance_id) || Map.get(participant, :corporation_id)
  end

  defp assess_conflict_complexity(side_a, side_b, neutrals) do
    total_affiliations =
      length(get_unique_affiliations(side_a)) +
        length(get_unique_affiliations(side_b)) +
        length(get_unique_affiliations(neutrals))

    case total_affiliations do
      n when n <= 2 -> :simple
      n when n <= 5 -> :moderate
      n when n <= 10 -> :complex
      _ -> :very_complex
    end
  end

  defp group_participants_by_affiliation(participants) do
    # Implement detailed affiliation grouping with hierarchical analysis
    by_corporation = Enum.group_by(participants, &Map.get(&1, :corporation_id))
    by_alliance = Enum.group_by(participants, &Map.get(&1, :alliance_id))

    # Identify potential coalitions based on engagement patterns
    alliance_cooperation = analyze_alliance_cooperation(participants)
    potential_coalitions = identify_potential_coalitions(alliance_cooperation)

    # Group by security status similarity (blue/neutral/red standings approximation)
    by_security_bracket = group_by_security_status(participants)

    # Identify unaffiliated and NPC corporation members
    unaffiliated =
      Enum.filter(participants, fn p ->
        is_nil(Map.get(p, :alliance_id)) and npc_corporation?(Map.get(p, :corporation_id))
      end)

    # Calculate affiliation strength metrics
    corporation_strengths = calculate_corporation_strengths(by_corporation)
    alliance_strengths = calculate_alliance_strengths(by_alliance)

    %{
      by_corporation: by_corporation,
      by_alliance: by_alliance,
      by_coalition: potential_coalitions,
      by_security_bracket: by_security_bracket,
      unaffiliated: unaffiliated,
      cooperation_matrix: alliance_cooperation,
      strength_analysis: %{
        strongest_corporation: find_strongest_group(corporation_strengths),
        strongest_alliance: find_strongest_group(alliance_strengths),
        total_corporations: length(Map.keys(by_corporation)),
        total_alliances: length(Map.keys(by_alliance)),
        affiliation_diversity: calculate_affiliation_diversity_score(by_corporation, by_alliance)
      }
    }
  end

  defp analyze_alliance_cooperation(participants) do
    # Analyze which alliances fought together vs against each other
    alliances =
      participants
      |> Enum.map(&Map.get(&1, :alliance_id))
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    # Create cooperation matrix
    for alliance_a <- alliances, alliance_b <- alliances, into: %{} do
      cooperation_score = calculate_cooperation_score(alliance_a, alliance_b, participants)
      {{alliance_a, alliance_b}, cooperation_score}
    end
  end

  defp calculate_cooperation_score(alliance_a, alliance_b, participants) do
    # Simple cooperation scoring based on whether alliances were on same side
    a_members = Enum.filter(participants, &(Map.get(&1, :alliance_id) == alliance_a))
    b_members = Enum.filter(participants, &(Map.get(&1, :alliance_id) == alliance_b))

    # If members from both alliances were attackers or both were victims, they cooperated
    a_types = Enum.map(a_members, &Map.get(&1, :participant_type)) |> Enum.uniq()
    b_types = Enum.map(b_members, &Map.get(&1, :participant_type)) |> Enum.uniq()

    case {a_types, b_types} do
      {[:attacker], [:attacker]} -> 1.0
      {[:victim], [:victim]} -> 1.0
      _ -> -1.0
    end
  end

  defp identify_potential_coalitions(cooperation_matrix) do
    # Group alliances with positive cooperation scores
    cooperation_matrix
    |> Enum.filter(fn {{_a, _b}, score} -> score > 0 end)
    |> Enum.group_by(fn {{alliance_a, _}, _score} -> alliance_a end)
    |> Enum.map(fn {alliance, cooperations} ->
      partners = Enum.map(cooperations, fn {{_, partner}, _} -> partner end)
      {alliance, partners}
    end)
    |> Enum.into(%{})
  end

  defp group_by_security_status(participants) do
    Enum.group_by(participants, fn participant ->
      security = Map.get(participant, :security_status, 0.0)

      cond do
        security >= 5.0 -> :high_sec_residents
        security >= 0.0 -> :low_sec_residents
        security >= -5.0 -> :null_sec_residents
        true -> :outlaw
      end
    end)
  end

  defp npc_corporation?(corp_id) when is_nil(corp_id), do: true
  defp npc_corporation?(corp_id) when corp_id < 2_000_000, do: true
  defp npc_corporation?(_corp_id), do: false

  defp calculate_corporation_strengths(by_corporation) do
    Enum.map(by_corporation, fn {corp_id, members} ->
      {corp_id, length(members)}
    end)
    |> Enum.into(%{})
  end

  defp calculate_alliance_strengths(by_alliance) do
    Enum.map(by_alliance, fn {alliance_id, members} ->
      {alliance_id, length(members)}
    end)
    |> Enum.into(%{})
  end

  defp find_strongest_group(strength_map) do
    case Enum.max_by(strength_map, fn {_id, strength} -> strength end, fn -> {nil, 0} end) do
      {id, _strength} -> id
      _ -> nil
    end
  end

  defp calculate_affiliation_diversity_score(by_corporation, by_alliance) do
    corp_count = length(Map.keys(by_corporation))
    alliance_count = length(Map.keys(by_alliance))

    # Simple diversity score - more corporations and alliances = more diverse
    case corp_count + alliance_count do
      n when n <= 2 -> :low
      n when n <= 10 -> :medium
      n when n <= 20 -> :high
      _ -> :very_high
    end
  end

  defp group_by_corporation(participants) do
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

  defp group_by_alliance(participants) do
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

  defp identify_coalitions(participants) do
    # Identify coalitions based on alliance cooperation patterns and shared engagement patterns
    if Enum.empty?(participants) do
      %{}
    else
      # Group participants by alliance
      alliances = participants
      |> Enum.filter(&Map.get(&1, :alliance_id))
      |> Enum.group_by(&Map.get(&1, :alliance_id))

      if map_size(alliances) < 2 do
        # Need at least 2 alliances for coalition analysis
        %{}
      else
        alliance_ids = Map.keys(alliances)

        # Calculate cooperation matrix between alliances
        cooperation_scores = for alliance_a <- alliance_ids, alliance_b <- alliance_ids, alliance_a != alliance_b, into: %{} do
          score = calculate_alliance_cooperation_score(alliance_a, alliance_b, participants)
          {{alliance_a, alliance_b}, score}
        end

        # Find strongly cooperating alliances (cooperation score > 0.7)
        strong_cooperations = cooperation_scores
        |> Enum.filter(fn {_pair, score} -> score > 0.7 end)
        |> Enum.map(fn {{a, b}, score} -> {a, b, score} end)

        # Build coalition groups using graph clustering
        coalitions = build_coalition_clusters(strong_cooperations, alliance_ids)

        # Add coalition metadata
        coalitions
        |> Enum.with_index(1)
        |> Enum.map(fn {alliance_list, index} ->
          coalition_participants = alliance_list
          |> Enum.flat_map(fn alliance_id -> Map.get(alliances, alliance_id, []) end)

          total_strength = length(coalition_participants)

          {"coalition_#{index}", %{
            alliances: alliance_list,
            participant_count: total_strength,
            alliance_count: length(alliance_list),
            participants: coalition_participants,
            average_cooperation: calculate_average_cooperation(alliance_list, cooperation_scores),
            formation_type: classify_coalition_type(alliance_list, cooperation_scores)
          }}
        end)
        |> Enum.into(%{})
      end
    end
  end

  defp calculate_alliance_cooperation_score(alliance_a, alliance_b, participants) do
    # Calculate cooperation based on shared engagement patterns
    a_participants = Enum.filter(participants, &(Map.get(&1, :alliance_id) == alliance_a))
    b_participants = Enum.filter(participants, &(Map.get(&1, :alliance_id) == alliance_b))

    # Check if alliances were on the same side (both attackers or both victims)
    a_types = Enum.map(a_participants, &Map.get(&1, :participant_type)) |> Enum.uniq()
    b_types = Enum.map(b_participants, &Map.get(&1, :participant_type)) |> Enum.uniq()

    base_cooperation = case {a_types, b_types} do
      {[:attacker], [:attacker]} -> 0.8  # Strong cooperation if both attacking
      {[:victim], [:victim]} -> 0.6      # Moderate cooperation if both victims
      _ -> 0.0                           # No cooperation if on different sides
    end

    # Bonus for similar security status (indicates similar space usage)
    a_avg_sec = a_participants |> Enum.map(&Map.get(&1, :security_status, 0.0)) |> average_or_zero()
    b_avg_sec = b_participants |> Enum.map(&Map.get(&1, :security_status, 0.0)) |> average_or_zero()

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
    |> Enum.filter(&(length(&1) > 1))  # Only return actual coalitions (2+ alliances)
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
        |> List.delete_at(max(idx_a, idx_b))  # Delete higher index first
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

  defp identify_neutral_parties(participants) do
    # Identify neutral parties based on their engagement patterns and affiliations
    if Enum.empty?(participants) do
      []
    else
      # Group participants by affiliation (alliance or corporation)
      affiliation_groups = Enum.group_by(participants, fn p ->
        Map.get(p, :alliance_id) || Map.get(p, :corporation_id)
      end)

      # Find affiliations that have members on both sides of the conflict
      neutral_affiliations = Enum.filter(affiliation_groups, fn {_affiliation_id, members} ->
        participant_types = Enum.map(members, &Map.get(&1, :participant_type)) |> Enum.uniq()

        # Neutral if they have both attackers and victims in their ranks
        length(participant_types) > 1 and :attacker in participant_types and :victim in participant_types
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
      individual_neutrals = Enum.filter(participants, fn participant ->
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
      neutrality_score = 1.0 - (deviation_from_neutral * 2.0)  # Scale to 0-1

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

  defp build_relationship_map(participants) do
    # Build a comprehensive relationship map based on engagement patterns
    if Enum.empty?(participants) do
      %{allies: %{}, enemies: %{}, neutrals: %{}}
    else
      # Group participants by their affiliations
      affiliation_groups = participants
      |> Enum.filter(&(Map.get(&1, :alliance_id) || Map.get(&1, :corporation_id)))
      |> Enum.group_by(fn p ->
        {Map.get(p, :alliance_id) || Map.get(p, :corporation_id),
         get_affiliation_name([p])}
      end)

      if map_size(affiliation_groups) < 2 do
        # Need at least 2 affiliations for relationship analysis
        %{allies: %{}, enemies: %{}, neutrals: %{}}
      else
        affiliation_keys = Map.keys(affiliation_groups)

        # Calculate relationships between all affiliation pairs
        relationships = for {id_a, name_a} <- affiliation_keys,
                           {id_b, name_b} <- affiliation_keys,
                           id_a != id_b, into: %{} do
          participants_a = Map.get(affiliation_groups, {id_a, name_a}, [])
          participants_b = Map.get(affiliation_groups, {id_b, name_b}, [])

          relationship = determine_relationship(participants_a, participants_b)

          {{id_a, name_a}, {id_b, name_b}}
          {{id_a, name_a}, Map.put(relationship, :affiliation_name, name_b)}
        end

        # Group relationships by type
        grouped_relationships = relationships
        |> Enum.group_by(fn {_key, relationship} ->
          Map.get(relationship, :relationship_type, :unknown)
        end)

        # Build the final relationship map
        %{
          allies: build_relationship_section(
            Map.get(grouped_relationships, :allied, []),
            affiliation_groups
          ),
          enemies: build_relationship_section(
            Map.get(grouped_relationships, :hostile, []),
            affiliation_groups
          ),
          neutrals: build_relationship_section(
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

  defp determine_relationship(participants_a, participants_b) do
    # Analyze engagement patterns between two affiliations
    a_types = Enum.map(participants_a, &Map.get(&1, :participant_type)) |> Enum.frequencies()
    b_types = Enum.map(participants_b, &Map.get(&1, :participant_type)) |> Enum.frequencies()

    a_attackers = Map.get(a_types, :attacker, 0)
    a_victims = Map.get(a_types, :victim, 0)
    b_attackers = Map.get(b_types, :attacker, 0)
    b_victims = Map.get(b_types, :victim, 0)

    # Determine relationship based on who attacked whom
    relationship_type = cond do
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

    strength = case relationship_type do
      :allied ->
        # Strength based on how much they fought on the same side
        same_side_ratio = if total_a > 0 and total_b > 0 do
          shared_side_count = min(a_attackers, b_attackers) + min(a_victims, b_victims)
          shared_side_count / max(total_a, total_b)
        else
          0.0
        end
        Float.round(same_side_ratio, 2)

      :hostile ->
        # Strength based on how much they fought against each other
        opposition_ratio = if total_a > 0 and total_b > 0 do
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
        interaction_pattern: describe_interaction_pattern(a_attackers, a_victims, b_attackers, b_victims)
      }
    }
  end

  defp build_relationship_section(relationships, affiliation_groups) do
    relationships
    |> Enum.map(fn {{affiliation_key, name}, relationship_data} ->
      participants = Map.get(affiliation_groups, affiliation_key, [])

      {name, Map.merge(relationship_data, %{
        affiliation_id: elem(affiliation_key, 0),
        participant_count: length(participants),
        affiliation_type: if(elem(affiliation_key, 0) in Enum.map(participants, &Map.get(&1, :alliance_id)), do: :alliance, else: :corporation)
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
      {total, neutral} when total <= 10 and neutral <= 2 -> :moderate
      {total, neutral} when total <= 20 and neutral <= total / 2 -> :complex
      _ -> :very_complex
    end
  end

  defp determine_primary_role(attackers, victims) do
    cond do
      attackers > 0 and victims == 0 -> :aggressor
      victims > 0 and attackers == 0 -> :defender
      attackers > victims -> :primarily_aggressor
      victims > attackers -> :primarily_defender
      attackers == victims and attackers > 0 -> :mixed
      true -> :unknown
    end
  end

  defp describe_interaction_pattern(a_attackers, a_victims, b_attackers, b_victims) do
    cond do
      a_attackers > 0 and b_victims > 0 and a_victims == 0 and b_attackers == 0 ->
        "A attacked B"
      b_attackers > 0 and a_victims > 0 and b_victims == 0 and a_attackers == 0 ->
        "B attacked A"
      a_attackers > 0 and b_attackers > 0 and a_victims == 0 and b_victims == 0 ->
        "Both were aggressors (likely allies)"
      a_victims > 0 and b_victims > 0 and a_attackers == 0 and b_attackers == 0 ->
        "Both were victims (likely allies under attack)"
      a_attackers > 0 and a_victims > 0 and b_attackers > 0 and b_victims > 0 ->
        "Complex multi-sided engagement"
      true ->
        "Unclear engagement pattern"
    end
  end

  defp calculate_role_effectiveness(role_participants) do
    if Enum.empty?(role_participants) do
      0.0
    else
      # Calculate effectiveness based on multiple factors

      # Factor 1: Survival rate (attackers survive, victims don't)
      survival_score = calculate_role_survival_rate(role_participants)

      # Factor 2: Average experience level
      experience_scores = Enum.map(role_participants, &Map.get(&1, :experience_score, 0.0))
      avg_experience = if length(experience_scores) > 0, do: Enum.sum(experience_scores) / length(experience_scores), else: 0.0

      # Factor 3: Ship class effectiveness (higher class ships = more effective)
      ship_effectiveness = Enum.reduce(role_participants, 0.0, fn participant, acc ->
        ship_class = Map.get(participant, :ship_class, :unknown)
        ship_score = case ship_class do
          :titan -> 1.0
          :supercarrier -> 0.95
          :carrier -> 0.9
          :dreadnought -> 0.85
          :battleship -> 0.7
          :battlecruiser -> 0.6
          :cruiser -> 0.5
          :destroyer -> 0.4
          :frigate -> 0.3
          _ -> 0.2
        end
        acc + ship_score
      end) / length(role_participants)

      # Factor 4: Damage output effectiveness
      damage_scores = Enum.map(role_participants, &Map.get(&1, :damage_done, 0))
      avg_damage = if length(damage_scores) > 0, do: Enum.sum(damage_scores) / length(damage_scores), else: 0
      damage_effectiveness = min(avg_damage / 50_000, 1.0)  # Normalize to max 1.0

      # Factor 5: Role specialization bonus
      specialization_bonus = Enum.reduce(role_participants, 0.0, fn participant, acc ->
        specializations = Map.get(participant, :specializations, [])
        tactical_role = Map.get(participant, :tactical_role, :unknown)

        # Bonus if specializations match tactical role
        role_match_bonus = if tactical_role in specializations, do: 0.2, else: 0.0
        acc + role_match_bonus
      end) / length(role_participants)

      # Weighted combination of factors
      effectiveness = (
        survival_score * 0.3 +
        avg_experience * 0.25 +
        ship_effectiveness * 0.2 +
        damage_effectiveness * 0.15 +
        specialization_bonus * 0.1
      )

      # Round to 2 decimal places and ensure between 0.0 and 1.0
      Float.round(max(0.0, min(1.0, effectiveness)), 2)
    end
  end

  defp identify_key_players(role_participants) do
    if Enum.empty?(role_participants) do
      []
    else
      # Calculate key player score for each participant
      scored_participants = Enum.map(role_participants, fn participant ->
        # Factor 1: Experience score (40% weight)
        experience_score = Map.get(participant, :experience_score, 0.0) * 0.4

        # Factor 2: Ship class importance (25% weight)
        ship_class = Map.get(participant, :ship_class, :unknown)
        ship_importance = case ship_class do
          :titan -> 1.0
          :supercarrier -> 0.95
          :carrier -> 0.9
          :dreadnought -> 0.85
          :battleship -> 0.6
          :battlecruiser -> 0.5
          :cruiser -> 0.4
          :destroyer -> 0.3
          :frigate -> 0.2
          _ -> 0.1
        end * 0.25

        # Factor 3: Damage contribution (20% weight)
        damage_done = Map.get(participant, :damage_done, 0)
        damage_score = min(damage_done / 100_000, 1.0) * 0.2

        # Factor 4: Role specialization (10% weight)
        specializations = Map.get(participant, :specializations, [])
        tactical_role = Map.get(participant, :tactical_role, :unknown)
        specialization_score = if tactical_role in specializations, do: 0.1, else: 0.05

        # Factor 5: Final blow bonus (5% weight)
        final_blow_bonus = if Map.get(participant, :final_blow, false), do: 0.05, else: 0.0

        total_score = experience_score + ship_importance + damage_score + specialization_score + final_blow_bonus

        Map.put(participant, :key_player_score, Float.round(total_score, 3))
      end)

      # Sort by score and take top performers
      top_count = min(5, max(1, div(length(role_participants), 3)))  # Top 1/3 or max 5

      scored_participants
      |> Enum.sort_by(&Map.get(&1, :key_player_score, 0.0), :desc)
      |> Enum.take(top_count)
      |> Enum.map(fn participant ->
        %{
          character_id: Map.get(participant, :character_id),
          character_name: Map.get(participant, :character_name, "Unknown"),
          ship_class: Map.get(participant, :ship_class, :unknown),
          tactical_role: Map.get(participant, :tactical_role, :unknown),
          key_player_score: Map.get(participant, :key_player_score, 0.0),
          damage_done: Map.get(participant, :damage_done, 0),
          final_blow: Map.get(participant, :final_blow, false)
        }
      end)
    end
  end

  defp analyze_role_balance(role_distribution) do
    if map_size(role_distribution) == 0 do
      %{balance_score: 0.0, imbalances: [:no_participants], recommendations: [:recruit_participants]}
    else
      # Calculate role balance based on ideal fleet composition
      ideal_ratios = %{
        dps: 0.4,        # 40% DPS
        logistics: 0.15, # 15% Logistics
        tackle: 0.15,    # 15% Tackle
        ewar: 0.1,       # 10% EWAR
        command: 0.05,   # 5% Command
        heavy_dps: 0.15  # 15% Heavy DPS
      }

      total_participants = role_distribution |> Map.values() |> Enum.map(&Map.get(&1, :count, 0)) |> Enum.sum()

      if total_participants == 0 do
        %{balance_score: 0.0, imbalances: [:no_participants], recommendations: [:recruit_participants]}
      else
        # Calculate actual ratios
        actual_ratios = Map.new(role_distribution, fn {role, data} ->
          count = Map.get(data, :count, 0)
          {role, count / total_participants}
        end)

        # Calculate balance deviations and scores
        {balance_scores, imbalances, recommendations} =
          Enum.reduce(ideal_ratios, {[], [], []}, fn {role, ideal_ratio}, {scores, imbal, recomm} ->
            actual_ratio = Map.get(actual_ratios, role, 0.0)
            deviation = abs(ideal_ratio - actual_ratio)

            # Track significant imbalances (>10% deviation)
            {new_imbal, new_recomm} = if deviation > 0.1 do
              cond do
                actual_ratio < ideal_ratio ->
                  {["insufficient_#{role}" | imbal], ["recruit_more_#{role}" | recomm]}
                actual_ratio > ideal_ratio ->
                  {["excess_#{role}" | imbal], ["reduce_#{role}_or_recruit_others" | recomm]}
                true -> {imbal, recomm}
              end
            else
              {imbal, recomm}
            end

            # Score: 1.0 - normalized deviation (perfect balance = 1.0)
            score = max(0.0, 1.0 - (deviation / ideal_ratio))
            {[score | scores], new_imbal, new_recomm}
          end)

        # Overall balance score (average of individual role balance scores)
        balance_score = if length(balance_scores) > 0 do
          Enum.sum(balance_scores) / length(balance_scores)
        else
          0.0
        end

        %{
          balance_score: Float.round(balance_score, 2),
          imbalances: imbalances,
          recommendations: recommendations,
          actual_ratios: actual_ratios,
          ideal_ratios: ideal_ratios
        }
      end
    end
  end

  defp identify_missing_roles(role_distribution) do
    # Define comprehensive role requirements based on fleet size
    total_participants = role_distribution |> Map.values() |> Enum.map(&Map.get(&1, :count, 0)) |> Enum.sum()

    # Scale role requirements based on fleet size
    required_roles = case total_participants do
      n when n >= 50 ->  # Large fleet
        [:dps, :heavy_dps, :logistics, :tackle, :ewar, :command, :anti_frigate, :bomber]
      n when n >= 20 ->  # Medium fleet
        [:dps, :heavy_dps, :logistics, :tackle, :ewar, :command]
      n when n >= 10 ->  # Small fleet
        [:dps, :logistics, :tackle, :ewar]
      n when n >= 5 ->   # Very small gang
        [:dps, :tackle]
      _ ->               # Solo or micro gang
        [:dps]
    end

    present_roles = Map.keys(role_distribution)
    missing_roles = required_roles -- present_roles

    # Add context about why roles are missing
    missing_with_context = Enum.map(missing_roles, fn role ->
      priority = case role do
        :logistics -> :critical   # Fleet survival
        :tackle -> :critical      # Engagement control
        :command -> :high         # Coordination
        :ewar -> :high           # Force multiplication
        :dps -> :medium          # Damage output
        :heavy_dps -> :medium    # Alpha damage
        _ -> :low
      end

      %{role: role, priority: priority, reason: get_role_missing_reason(role, total_participants)}
    end)

    missing_with_context
  end

  defp get_role_missing_reason(role, fleet_size) do
    case role do
      :logistics -> "Fleet lacks repair capability - essential for fleet survival"
      :tackle -> "No tackle capability - cannot control enemy movement"
      :command -> "No fleet coordination - reduces tactical effectiveness"
      :ewar -> "Missing electronic warfare - no force multiplication"
      :dps when fleet_size < 10 -> "Insufficient damage dealers for small gang"
      :heavy_dps when fleet_size >= 20 -> "No alpha damage capability for larger engagements"
      :anti_frigate when fleet_size >= 30 -> "Vulnerable to frigate swarms"
      :bomber when fleet_size >= 50 -> "Missing stealth bombing capability"
      _ -> "Role would improve fleet composition"
    end
  end

  defp analyze_role_synergies(role_distribution) do
    if map_size(role_distribution) == 0 do
      %{synergy_score: 0.0, effective_combinations: [], missing_synergies: []}
    else
      present_roles = Map.keys(role_distribution)

      # Define known effective role combinations with their synergy values
      synergy_combinations = [
        {[:dps, :logistics], "Basic combat sustainability", 0.8},
        {[:tackle, :dps], "Standard engagement control", 0.7},
        {[:ewar, :dps], "Force multiplication", 0.75},
        {[:logistics, :command], "Fleet coordination and repair", 0.85},
        {[:tackle, :ewar, :dps], "Complete engagement control", 0.9},
        {[:heavy_dps, :logistics, :command], "Capital engagement setup", 0.95},
        {[:bomber, :tackle], "Alpha strike coordination", 0.8},
        {[:anti_frigate, :heavy_dps], "Multi-layered damage", 0.7},
        {[:carrier, :logistics, :command], "Capital fleet support", 1.0},
        {[:dreadnought, :command, :logistics], "Siege warfare core", 0.95}
      ]

      # Find which combinations are present
      effective_combinations = Enum.filter(synergy_combinations, fn {required_roles, _name, _score} ->
        Enum.all?(required_roles, &(&1 in present_roles))
      end)
      |> Enum.map(fn {roles, name, score} ->
        # Calculate actual effectiveness based on participant counts
        role_counts = Enum.map(roles, fn role ->
          Map.get(role_distribution, role, %{}) |> Map.get(:count, 0)
        end)

        min_count = Enum.min(role_counts)
        effectiveness_modifier = case min_count do
          n when n >= 5 -> 1.0
          n when n >= 3 -> 0.9
          n when n >= 2 -> 0.8
          1 -> 0.6
          _ -> 0.0
        end

        %{
          roles: roles,
          name: name,
          base_score: score,
          actual_score: Float.round(score * effectiveness_modifier, 2),
          participant_counts: Enum.zip(roles, role_counts) |> Enum.into(%{})
        }
      end)

      # Identify missing synergies
      missing_synergies = Enum.filter(synergy_combinations, fn {required_roles, _name, _score} ->
        missing_roles = required_roles -- present_roles
        length(missing_roles) > 0 and length(missing_roles) <= 2  # Only show if 1-2 roles missing
      end)
      |> Enum.map(fn {required_roles, name, score} ->
        missing_roles = required_roles -- present_roles
        %{
          combination_name: name,
          missing_roles: missing_roles,
          potential_score: score,
          required_roles: required_roles
        }
      end)

      # Calculate overall synergy score
      synergy_score = if length(effective_combinations) > 0 do
        total_score = Enum.sum(Enum.map(effective_combinations, &Map.get(&1, :actual_score, 0)))
        avg_score = total_score / length(effective_combinations)

        # Bonus for multiple synergies
        synergy_bonus = case length(effective_combinations) do
          n when n >= 4 -> 0.2
          n when n >= 3 -> 0.15
          n when n >= 2 -> 0.1
          _ -> 0.0
        end

        min(1.0, avg_score + synergy_bonus)
      else
        0.0
      end

      %{
        synergy_score: Float.round(synergy_score, 2),
        effective_combinations: effective_combinations,
        missing_synergies: missing_synergies,
        synergy_analysis: %{
          total_combinations: length(effective_combinations),
          high_value_combinations: Enum.count(effective_combinations, &(Map.get(&1, :actual_score, 0) >= 0.8)),
          critical_gaps: Enum.filter(missing_synergies, &(Map.get(&1, :potential_score, 0) >= 0.9))
        }
      }
    end
  end

  defp calculate_experience_distribution(participants) do
    # Calculate actual experience distribution based on participant analysis
    experience_groups = Enum.group_by(participants, &Map.get(&1, :experience_level, :unknown))

    %{
      veteran: length(Map.get(experience_groups, :veteran, [])),
      experienced: length(Map.get(experience_groups, :experienced, [])),
      intermediate: length(Map.get(experience_groups, :intermediate, [])),
      novice: length(Map.get(experience_groups, :novice, [])),
      rookie: length(Map.get(experience_groups, :rookie, [])),
      unknown: length(Map.get(experience_groups, :unknown, []))
    }
  end

  defp analyze_skill_levels(participants) do
    # Analyze skill levels based on ship classes and experience
    skill_scores = Enum.map(participants, fn participant ->
      experience = Map.get(participant, :experience_score, 0.0)
      ship_class = Map.get(participant, :ship_class, :unknown)

      # Skill bonus for advanced ship classes
      ship_skill_bonus = case ship_class do
        :titan -> 1.0
        :supercarrier -> 0.9
        :carrier -> 0.8
        :dreadnought -> 0.8
        :battleship -> 0.6
        :battlecruiser -> 0.5
        :cruiser -> 0.4
        :destroyer -> 0.3
        :frigate -> 0.2
        _ -> 0.0
      end

      # Combined skill estimate
      (experience + ship_skill_bonus) / 2.0
    end)

    avg_skill = if length(skill_scores) > 0, do: Enum.sum(skill_scores) / length(skill_scores), else: 0.0

    # Categorize skill levels
    skill_categories = Enum.group_by(participants, fn participant ->
      skill = Map.get(participant, :experience_score, 0.0)
      cond do
        skill >= 0.8 -> :high
        skill >= 0.5 -> :medium
        skill >= 0.2 -> :low
        true -> :very_low
      end
    end)

    total_count = length(participants)
    skill_distribution = if total_count > 0 do
      %{
        high: length(Map.get(skill_categories, :high, [])) / total_count,
        medium: length(Map.get(skill_categories, :medium, [])) / total_count,
        low: length(Map.get(skill_categories, :low, [])) / total_count,
        very_low: length(Map.get(skill_categories, :very_low, [])) / total_count
      }
    else
      %{high: 0.0, medium: 0.0, low: 0.0, very_low: 0.0}
    end

    %{
      average_skill: Float.round(avg_skill, 2),
      skill_distribution: skill_distribution,
      skill_advantages: identify_skill_advantages(participants)
    }
  end

  defp identify_skill_advantages(participants) do
    # Identify participants with notable skill advantages
    participants
    |> Enum.filter(&(Map.get(&1, :experience_score, 0.0) >= 0.8))
    |> Enum.map(fn participant ->
      %{
        character_id: Map.get(participant, :character_id),
        skill_score: Map.get(participant, :experience_score, 0.0),
        specializations: Map.get(participant, :specializations, []),
        ship_class: Map.get(participant, :ship_class, :unknown)
      }
    end)
  end

  defp identify_veteran_players(participants) do
    # Identify veterans based on actual experience level analysis
    participants
    |> Enum.filter(fn participant ->
      experience_level = Map.get(participant, :experience_level, :unknown)
      experience_level in [:veteran, :experienced]
    end)
    |> Enum.sort_by(&Map.get(&1, :experience_score, 0.0), :desc)
  end

  defp identify_rookie_players(participants) do
    # Identify rookies based on actual experience level analysis
    participants
    |> Enum.filter(fn participant ->
      experience_level = Map.get(participant, :experience_level, :unknown)
      experience_level in [:rookie, :novice]
    end)
    |> Enum.sort_by(&Map.get(&1, :experience_score, 0.0), :asc)
  end

  defp calculate_experience_advantage(participants) do
    # Calculate experience advantage based on actual participant data
    veterans = identify_veteran_players(participants)
    rookies = identify_rookie_players(participants)

    # Calculate average experience scores
    veteran_avg = calculate_average_experience_for_group(veterans)
    rookie_avg = calculate_average_experience_for_group(rookies)
    overall_avg = calculate_average_experience(participants)

    # Calculate side-based advantages (simplified - assumes sides exist)
    side_a_participants = Enum.filter(participants, &(Map.get(&1, :participant_type) == :victim))
    side_b_participants = Enum.filter(participants, &(Map.get(&1, :participant_type) == :attacker))

    side_a_avg = calculate_average_experience(side_a_participants)
    side_b_avg = calculate_average_experience(side_b_participants)

    %{
      overall_advantage: veteran_avg - rookie_avg,
      side_advantages: %{
        side_a: side_a_avg - overall_avg,
        side_b: side_b_avg - overall_avg
      },
      veteran_ratio: length(veterans) / max(1, length(participants)),
      rookie_ratio: length(rookies) / max(1, length(participants)),
      experience_spread: veteran_avg - rookie_avg
    }
  end

  defp count_participant_kills(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      # Count killmails where this character was an attacker
      Enum.count(killmails, fn killmail ->
        case Map.get(killmail, :raw_data) do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.any?(attackers, &(Map.get(&1, "character_id") == character_id))

          _ ->
            false
        end
      end)
    end
  end

  defp count_participant_deaths(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      # Count killmails where this character was the victim
      Enum.count(killmails, fn killmail ->
        killmail.victim_character_id == character_id
      end)
    end
  end

  defp calculate_damage_dealt(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      # Sum damage dealt by this character across all killmails
      Enum.reduce(killmails, 0, fn killmail, acc ->
        case Map.get(killmail, :raw_data) do
          %{"attackers" => attackers} when is_list(attackers) ->
            attacker_damage =
              attackers
              |> Enum.filter(&(Map.get(&1, "character_id") == character_id))
              |> Enum.map(&Map.get(&1, "damage_done", 0))
              |> Enum.sum()

            acc + attacker_damage

          _ ->
            acc
        end
      end)
    end
  end

  defp calculate_damage_received(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      # Sum damage received when this character was a victim
      Enum.reduce(killmails, 0, fn killmail, acc ->
        if killmail.victim_character_id == character_id do
          case Map.get(killmail, :raw_data) do
            %{"attackers" => attackers} when is_list(attackers) ->
              total_damage =
                attackers
                |> Enum.map(&Map.get(&1, "damage_done", 0))
                |> Enum.sum()

              acc + total_damage

            _ ->
              acc
          end
        else
          acc
        end
      end)
    end
  end

  defp build_activity_timeline(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      []
    else
      # Build chronological timeline of this character's activity
      activity_events =
        killmails
        |> Enum.filter(fn killmail ->
          # Include killmails where character was victim or attacker
          victim_match = killmail.victim_character_id == character_id

          attacker_match =
            case Map.get(killmail, :raw_data) do
              %{"attackers" => attackers} when is_list(attackers) ->
                Enum.any?(attackers, &(Map.get(&1, "character_id") == character_id))

              _ ->
                false
            end

          victim_match or attacker_match
        end)
        |> Enum.map(fn killmail ->
          event_type = if killmail.victim_character_id == character_id, do: :death, else: :kill

          %{
            timestamp: killmail.killmail_time,
            event_type: event_type,
            system_id: killmail.solar_system_id,
            killmail_id: killmail.killmail_id
          }
        end)
        |> Enum.sort_by(& &1.timestamp, DateTime)

      activity_events
    end
  end

  defp calculate_contribution_score(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0.0
    else
      kills = count_participant_kills(participant, killmails)
      deaths = count_participant_deaths(participant, killmails)
      damage_dealt = calculate_damage_dealt(participant, killmails)

      # Calculate contribution based on kills, survival, and damage
      kill_score = kills * 0.4
      survival_score = if deaths == 0, do: 0.3, else: 0.0
      # Normalize to max 1.0
      damage_score = min(damage_dealt / 100_000, 1.0) * 0.3

      kill_score + survival_score + damage_score
    end
  end

  # Helper functions from previous extractors
  defp determine_tactical_role(ship_name) when is_binary(ship_name) do
    cond do
      ship_name =~ "Logistics" -> :logistics
      ship_name =~ "Command" -> :command
      ship_name =~ "Interceptor" -> :tackle
      ship_name =~ "Dictor" -> :interdiction
      ship_name =~ "Recon" -> :ewar
      ship_name =~ "Covert" -> :stealth
      ship_name =~ "Bomber" -> :bomber
      ship_name =~ "Dreadnought" -> :siege
      ship_name =~ "Carrier" -> :carrier
      true -> :dps
    end
  end

  defp determine_tactical_role(_), do: :unknown

  defp classify_ship_class(ship_name) when is_binary(ship_name) do
    cond do
      ship_name =~ "Frigate" -> :frigate
      ship_name =~ "Destroyer" -> :destroyer
      ship_name =~ "Cruiser" -> :cruiser
      ship_name =~ "Battlecruiser" -> :battlecruiser
      ship_name =~ "Battleship" -> :battleship
      ship_name =~ "Dreadnought" -> :dreadnought
      ship_name =~ "Carrier" -> :carrier
      ship_name =~ "Supercarrier" -> :supercarrier
      ship_name =~ "Titan" -> :titan
      ship_name =~ "Logistics" -> :logistics
      ship_name =~ "Command" -> :command
      true -> :unknown
    end
  end

  defp classify_ship_class(_), do: :unknown

  defp estimate_experience_level(participant) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      :unknown
    else
      # Query historical killmail participation
      try do
        {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
          SELECT
            COUNT(CASE WHEN victim_character_id = $1 THEN 1 END) as deaths,
            COUNT(CASE WHEN raw_data::jsonb ? 'attackers' AND
                           EXISTS(SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') attacker
                                  WHERE attacker->>'character_id' = $1) THEN 1 END) as kills
          FROM killmails_raw
          WHERE killmail_time > NOW() - INTERVAL '90 days'
            AND (victim_character_id = $1 OR
                 (raw_data::jsonb ? 'attackers' AND
                  EXISTS(SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') attacker
                         WHERE attacker->>'character_id' = $1)))
        """, [to_string(character_id)])

        case result.rows do
          [[deaths, kills]] when is_integer(deaths) and is_integer(kills) ->
            total_engagements = deaths + kills
            case total_engagements do
              n when n >= 100 -> :veteran
              n when n >= 20 -> :experienced
              n when n >= 5 -> :intermediate
              n when n >= 1 -> :novice
              _ -> :rookie
            end
          _ -> :unknown
        end
      rescue
        _ -> :unknown
      end
    end
  end

  defp estimate_threat_rating(participant) do
    character_id = Map.get(participant, :character_id)
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)

    if is_nil(character_id) do
      1.0
    else
      # Base threat from security status
      security_threat = case security_status do
        sec when sec < -5.0 -> 9.0
        sec when sec < -2.0 -> 7.0
        sec when sec < 0.0 -> 5.0
        sec when sec < 2.0 -> 3.0
        _ -> 1.0
      end

      # Ship class multiplier
      ship_multiplier = case ship_class do
        :titan -> 2.0
        :supercarrier -> 1.8
        :carrier -> 1.6
        :dreadnought -> 1.5
        :battleship -> 1.3
        :battlecruiser -> 1.2
        :cruiser -> 1.1
        _ -> 1.0
      end

      # Combat activity modifier
      try do
        {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
          SELECT COUNT(*) as recent_kills
          FROM killmails_raw
          WHERE killmail_time > NOW() - INTERVAL '30 days'
            AND raw_data::jsonb ? 'attackers'
            AND EXISTS(SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') attacker
                       WHERE attacker->>'character_id' = $1)
        """, [to_string(character_id)])

        activity_multiplier = case result.rows do
          [[recent_kills]] when recent_kills > 50 -> 1.5
          [[recent_kills]] when recent_kills > 20 -> 1.3
          [[recent_kills]] when recent_kills > 5 -> 1.1
          _ -> 1.0
        end

        min(security_threat * ship_multiplier * activity_multiplier, 10.0)
      rescue
        _ -> security_threat * ship_multiplier
      end
    end
  end

  defp get_historical_performance(participant) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      %{kills: 0, deaths: 0, isk_efficiency: 0.0, recent_activity: :unknown}
    else
      try do
        # Query 90-day performance metrics
        {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
          SELECT
            COUNT(CASE WHEN victim_character_id = $1 THEN 1 END) as deaths,
            COUNT(CASE WHEN raw_data::jsonb ? 'attackers' AND
                           EXISTS(SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') attacker
                                  WHERE attacker->>'character_id' = $1) THEN 1 END) as kills,
            AVG(CASE WHEN raw_data::jsonb ? 'zkb' THEN
                  COALESCE((raw_data->'zkb'->>'totalValue')::bigint, 0)
                ELSE 0 END) as avg_ship_value,
            COUNT(CASE WHEN killmail_time > NOW() - INTERVAL '7 days' THEN 1 END) as recent_activity_count
          FROM killmails_raw
          WHERE killmail_time > NOW() - INTERVAL '90 days'
            AND (victim_character_id = $1 OR
                 (raw_data::jsonb ? 'attackers' AND
                  EXISTS(SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') attacker
                         WHERE attacker->>'character_id' = $1)))
        """, [to_string(character_id)])

        case result.rows do
          [[deaths, kills, avg_ship_value, recent_count]] ->
            isk_efficiency = if deaths > 0 and not is_nil(avg_ship_value) do
              (kills / deaths) * (avg_ship_value / 1_000_000)  # Normalize to millions
            else
              if kills > 0, do: 1.0, else: 0.0
            end

            recent_activity = case recent_count do
              count when count >= 5 -> :very_active
              count when count >= 2 -> :active
              count when count >= 1 -> :moderate
              _ -> :inactive
            end

            %{
              kills: kills || 0,
              deaths: deaths || 0,
              isk_efficiency: Float.round(isk_efficiency, 2),
              recent_activity: recent_activity,
              avg_ship_value: avg_ship_value || 0
            }
          _ ->
            %{kills: 0, deaths: 0, isk_efficiency: 0.0, recent_activity: :unknown}
        end
      rescue
        _ -> %{kills: 0, deaths: 0, isk_efficiency: 0.0, recent_activity: :unknown}
      end
    end
  end

  defp identify_specializations(participant) do
    character_id = Map.get(participant, :character_id)
    base_role = Map.get(participant, :tactical_role, :unknown)

    if is_nil(character_id) do
      [base_role]
    else
      try do
        # Query ship usage patterns to identify specializations
        {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
          SELECT
            victim_ship_name,
            COUNT(*) as usage_count
          FROM killmails_raw
          WHERE killmail_time > NOW() - INTERVAL '90 days'
            AND (victim_character_id = $1 OR
                 (raw_data::jsonb ? 'attackers' AND
                  EXISTS(SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') attacker
                         WHERE attacker->>'character_id' = $1)))
            AND victim_ship_name IS NOT NULL
          GROUP BY victim_ship_name
          ORDER BY usage_count DESC
          LIMIT 10
        """, [to_string(character_id)])

        # Analyze ship patterns to determine specializations
        specializations =
          result.rows
          |> Enum.reduce([base_role], fn [ship_name, _count], acc ->
            cond do
              ship_name =~ ~r/Logistics|Guardian|Basilisk|Oneiros|Scimitar/ -> [:logistics | acc]
              ship_name =~ ~r/Recon|Falcon|Rook|Curse|Pilgrim/ -> [:ewar | acc]
              ship_name =~ ~r/Interceptor|Stiletto|Ares|Malediction|Crow/ -> [:tackle | acc]
              ship_name =~ ~r/Stealth Bomber|Hound|Manticore|Nemesis|Purifier/ -> [:bomber | acc]
              ship_name =~ ~r/Dreadnought|Naglfar|Moros|Phoenix|Revelation/ -> [:siege | acc]
              ship_name =~ ~r/Carrier|Archon|Chimera|Thanatos|Nidhoggur/ -> [:carrier | acc]
              ship_name =~ ~r/Battleship/ -> [:heavy_dps | acc]
              ship_name =~ ~r/Command/ -> [:command | acc]
              true -> acc
            end
          end)
          |> Enum.uniq()
          |> Enum.reject(&(&1 == :unknown))

        if length(specializations) > 0, do: specializations, else: [base_role]
      rescue
        _ -> [base_role]
      end
    end
  end

  defp analyze_activity_patterns(participant) do
    character_id = Map.get(participant, :character_id)

    if character_id do
      # Query actual killmail data for this character from the last 30 days
      {:ok, killmails} =
        Ecto.Adapters.SQL.query(
          Repo,
          """
          SELECT
            DATE_PART('hour', occurred_at) as hour,
            solar_system_id,
            occurred_at
          FROM killmails_raw
          WHERE (victim_character_id = $1 OR raw_data->'attackers' @> $2::jsonb)
            AND occurred_at > NOW() - INTERVAL '30 days'
          ORDER BY occurred_at DESC
          LIMIT 500
          """,
          [character_id, "[{\"character_id\": #{character_id}}]"]
        )

      # Analyze activity patterns from real data
      active_hours =
        killmails.rows
        |> Enum.map(fn [hour, _system, _time] -> trunc(hour) end)
        |> Enum.frequencies()
        |> Map.keys()

      preferred_systems =
        killmails.rows
        |> Enum.map(fn [_hour, system, _time] -> system end)
        |> Enum.frequencies()
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(5)
        |> Enum.map(&elem(&1, 0))

      peak_hour =
        killmails.rows
        |> Enum.map(fn [hour, _system, _time] -> trunc(hour) end)
        |> Enum.frequencies()
        |> Enum.max_by(&elem(&1, 1), fn -> {0, 0} end)
        |> elem(0)

      %{
        active_hours: active_hours,
        preferred_systems: preferred_systems,
        peak_activity_hour: peak_hour,
        total_engagements: length(killmails.rows),
        days_analyzed: 30
      }
    else
      %{
        active_hours: [],
        preferred_systems: [],
        peak_activity_hour: nil,
        total_engagements: 0,
        days_analyzed: 0
      }
    end
  end

  # Helper functions for enhanced implementations

  # Functions needed for calculate_participant_metrics/1
  defp calculate_participant_metrics(participant) do
    # Add comprehensive metrics to participant data
    Map.merge(participant, %{
      combat_score: calculate_combat_score(participant),
      efficiency_rating: calculate_efficiency_rating(participant),
      threat_level: assess_threat_level(participant),
      experience_score: calculate_experience_score(participant)
    })
  end

  defp calculate_combat_score(participant) do
    # Basic combat scoring based on available data
    base_score =
      case Map.get(participant, :participant_type) do
        :attacker -> 1.0
        :victim -> 0.5
        _ -> 0.0
      end

    # Adjust for ship class
    ship_multiplier =
      case Map.get(participant, :ship_class) do
        :capital -> 3.0
        :battleship -> 2.0
        :cruiser -> 1.5
        :frigate -> 1.0
        _ -> 1.0
      end

    base_score * ship_multiplier
  end

  defp calculate_efficiency_rating(participant) do
    damage_dealt = Map.get(participant, :damage_done, 0)

    case damage_dealt do
      0 -> 0.0
      damage when damage >= 100_000 -> 1.0
      damage when damage >= 50_000 -> 0.8
      damage when damage >= 10_000 -> 0.6
      damage when damage >= 1_000 -> 0.4
      _ -> 0.2
    end
  end

  defp assess_threat_level(participant) do
    security = Map.get(participant, :security_status, 0.0)

    case security do
      sec when sec < -5.0 -> :very_high
      sec when sec < 0.0 -> :high
      sec when sec < 5.0 -> :medium
      _ -> :low
    end
  end

  defp calculate_experience_score(participant) do
    # Simple experience estimation based on security status and ship type
    security_factor =
      case Map.get(participant, :security_status, 0.0) do
        # Low sec players likely more experienced
        sec when sec < -2.0 -> 0.8
        sec when sec < 0.0 -> 0.6
        _ -> 0.4
      end

    ship_factor =
      case Map.get(participant, :ship_class) do
        # Capital pilots are experienced
        :capital -> 1.0
        # Battleship pilots fairly experienced
        :battleship -> 0.8
        # Medium experience
        :cruiser -> 0.6
        # Lower experience
        _ -> 0.4
      end

    (security_factor + ship_factor) / 2.0
  end

  # Functions needed for affiliation analysis
  defp calculate_affiliation_metrics(corporations, alliances, coalitions) do
    %{
      corporation_count: length(Map.keys(corporations)),
      alliance_count: length(Map.keys(alliances)),
      coalition_count: length(Map.keys(coalitions)),
      average_corp_size: calculate_average_group_size(corporations),
      average_alliance_size: calculate_average_group_size(alliances),
      fragmentation_score: calculate_fragmentation_score(corporations, alliances)
    }
  end

  defp calculate_average_group_size(groups) do
    if length(Map.keys(groups)) > 0 do
      total_members = groups |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
      total_members / length(Map.keys(groups))
    else
      0.0
    end
  end

  defp calculate_fragmentation_score(corporations, alliances) do
    corp_count = length(Map.keys(corporations))
    alliance_count = length(Map.keys(alliances))

    # Higher fragmentation = more small groups
    case corp_count do
      n when n > alliance_count * 3 -> :high
      n when n > alliance_count * 2 -> :medium
      _ -> :low
    end
  end

  defp find_dominant_affiliation(affiliation_groups) do
    case Enum.max_by(affiliation_groups, fn {_id, members} -> length(members) end, fn ->
           {nil, []}
         end) do
      {id, _members} -> id
      _ -> nil
    end
  end

  defp calculate_affiliation_diversity(corporations, alliances) do
    corp_diversity = calculate_group_diversity(corporations)
    alliance_diversity = calculate_group_diversity(alliances)
    (corp_diversity + alliance_diversity) / 2.0
  end

  defp calculate_group_diversity(groups) do
    if length(Map.keys(groups)) <= 1 do
      0.0
    else
      total_members = groups |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

      # Calculate Shannon diversity
      diversity =
        groups
        |> Map.values()
        |> Enum.map(fn members ->
          proportion = length(members) / total_members
          if proportion > 0, do: -proportion * :math.log2(proportion), else: 0
        end)
        |> Enum.sum()

      # Normalize to 0-1 range
      max_diversity = groups |> Map.keys() |> length() |> :math.log2()
      if max_diversity > 0, do: diversity / max_diversity, else: 0.0
    end
  end

  # Functions needed for role analysis
  defp classify_participant_role(participant) do
    ship_class = Map.get(participant, :ship_class, :unknown)
    ship_type_id = Map.get(participant, :ship_type_id)
    weapon_type_id = Map.get(participant, :weapon_type_id)

    # Classify role based on ship class and weapon type
    case ship_class do
      :frigate -> classify_frigate_role(ship_type_id, weapon_type_id)
      :destroyer -> :anti_frigate
      :cruiser -> classify_cruiser_role(ship_type_id, weapon_type_id)
      :battlecruiser -> :heavy_dps
      :battleship -> :heavy_dps
      :capital -> classify_capital_role(ship_type_id)
      _ -> :unknown
    end
  end

  defp classify_frigate_role(_ship_type_id, weapon_type_id) do
    # Basic classification - would use actual weapon/ship data in production
    case weapon_type_id do
      id when is_nil(id) -> :tackle
      # Placeholder ranges
      id when id in [1..100] -> :tackle
      _ -> :scout
    end
  end

  defp classify_cruiser_role(_ship_type_id, weapon_type_id) do
    case weapon_type_id do
      id when is_nil(id) -> :dps
      # Placeholder ranges
      id when id in [500..600] -> :logistics
      id when id in [600..700] -> :ewar
      _ -> :dps
    end
  end

  defp classify_capital_role(ship_type_id) do
    # Basic capital classification
    case ship_type_id do
      # Placeholder ranges
      id when id in [19_720..19_724] -> :carrier
      id when id in [19_725..19_729] -> :dreadnought
      id when id in [3764, 11_567] -> :supercarrier
      id when id in [671, 23_773] -> :titan
      _ -> :capital
    end
  end

  defp calculate_role_survival_rate(role_participants) do
    if length(role_participants) > 0 do
      survivors = Enum.count(role_participants, &(Map.get(&1, :participant_type) == :attacker))
      survivors / length(role_participants)
    else
      0.0
    end
  end

  defp calculate_average_role_experience(role_participants) do
    if length(role_participants) > 0 do
      total_experience =
        Enum.reduce(role_participants, 0.0, fn participant, acc ->
          acc + Map.get(participant, :experience_score, 0.0)
        end)

      total_experience / length(role_participants)
    else
      0.0
    end
  end

  defp identify_primary_doctrine(role_distribution) do
    # Identify the primary doctrine based on role composition
    dominant_role =
      role_distribution
      |> Enum.max_by(fn {_role, data} -> Map.get(data, :count, 0) end, fn -> {:unknown, %{}} end)
      |> elem(0)

    case dominant_role do
      :heavy_dps -> :battleship_doctrine
      :carrier -> :capital_doctrine
      :dps -> :cruiser_doctrine
      :frigate -> :frigate_swarm
      _ -> :mixed_doctrine
    end
  end

  defp calculate_role_diversity(role_distribution) do
    role_count = length(Map.keys(role_distribution))

    case role_count do
      n when n >= 5 -> :high
      n when n >= 3 -> :medium
      n when n >= 2 -> :low
      _ -> :very_low
    end
  end

  defp assess_doctrine_coherence(role_distribution) do
    # Assess how well the roles work together
    total_participants =
      role_distribution
      |> Map.values()
      |> Enum.map(&Map.get(&1, :count, 0))
      |> Enum.sum()

    if total_participants == 0 do
      0.0
    else
      # Simple coherence based on role balance
      role_counts = Enum.map(role_distribution, fn {_role, data} -> Map.get(data, :count, 0) end)
      max_count = Enum.max(role_counts)
      balance_score = 1.0 - max_count / total_participants
      balance_score
    end
  end

  defp evaluate_tactical_completeness(role_distribution, missing_roles) do
    total_roles = length(Map.keys(role_distribution))
    missing_count = length(missing_roles)

    if total_roles + missing_count > 0 do
      total_roles / (total_roles + missing_count)
    else
      0.0
    end
  end

  # Helper functions for ship classification
  defp determine_ship_name(ship_type_id) when is_nil(ship_type_id), do: "Unknown Ship"
  # Would lookup in static data
  defp determine_ship_name(_ship_type_id), do: "Ship"

  defp determine_tactical_role_from_ship_and_weapon(ship_type_id, weapon_type_id) do
    # Basic role determination - would use actual game data
    case {ship_type_id, weapon_type_id} do
      {nil, _} -> :unknown
      {_, nil} -> classify_by_ship_type(ship_type_id)
      {ship, weapon} -> classify_by_ship_and_weapon(ship, weapon)
    end
  end

  defp classify_by_ship_type(ship_type_id) when ship_type_id < 1000, do: :frigate
  defp classify_by_ship_type(ship_type_id) when ship_type_id < 2000, do: :cruiser
  defp classify_by_ship_type(_ship_type_id), do: :dps

  defp classify_by_ship_and_weapon(_ship_type_id, _weapon_type_id), do: :dps

  defp classify_ship_class_by_type_id(ship_type_id) when is_nil(ship_type_id), do: :unknown
  defp classify_ship_class_by_type_id(ship_type_id) when ship_type_id < 1000, do: :frigate
  defp classify_ship_class_by_type_id(ship_type_id) when ship_type_id < 2000, do: :cruiser
  defp classify_ship_class_by_type_id(ship_type_id) when ship_type_id < 3000, do: :battleship
  defp classify_ship_class_by_type_id(_ship_type_id), do: :capital

  # Placeholder implementations for data completeness
  defp assess_data_completeness(participant) do
    fields = [:character_id, :corporation_id, :ship_type_id, :ship_name]
    present_fields = Enum.count(fields, &(Map.get(participant, &1) != nil))
    present_fields / length(fields)
  end

  defp assess_combat_capability(participant) do
    ship_class = Map.get(participant, :ship_class, :unknown)

    case ship_class do
      :capital -> :very_high
      :battleship -> :high
      :cruiser -> :medium
      :frigate -> :low
      _ -> :unknown
    end
  end

  defp evaluate_strategic_value(participant) do
    # Strategic value based on role and ship type
    role = Map.get(participant, :tactical_role, :unknown)

    case role do
      :carrier -> :critical
      :dreadnought -> :critical
      :logistics -> :high
      :ewar -> :high
      :dps -> :medium
      _ -> :low
    end
  end

  defp calculate_reliability_score(participant) do
    # Basic reliability score based on security status
    security = Map.get(participant, :security_status, 0.0)

    case security do
      sec when sec >= 5.0 -> 0.9
      sec when sec >= 0.0 -> 0.7
      sec when sec >= -2.0 -> 0.5
      _ -> 0.3
    end
  end

  # Functions needed for activity tracking
  defp calculate_isk_efficiency(damage_dealt, damage_received) do
    if damage_received > 0 do
      damage_dealt / damage_received
    else
      # High efficiency if no damage taken
      if damage_dealt > 0, do: 10.0, else: 0.0
    end
  end

  defp calculate_engagement_duration(activity_timeline) do
    case activity_timeline do
      [] ->
        0

      timeline ->
        first_event = List.first(timeline)
        last_event = List.last(timeline)
        # Simple duration calculation in seconds
        case {first_event, last_event} do
          {%{timestamp: start_time}, %{timestamp: end_time}} ->
            DateTime.diff(end_time, start_time, :second)

          _ ->
            0
        end
    end
  end

  defp assess_combat_intensity(activity_timeline) do
    event_count = length(activity_timeline)
    duration = calculate_engagement_duration(activity_timeline)

    if duration > 0 do
      events_per_minute = event_count * 60 / duration

      case events_per_minute do
        rate when rate >= 10 -> :very_high
        rate when rate >= 5 -> :high
        rate when rate >= 2 -> :medium
        rate when rate >= 1 -> :low
        _ -> :very_low
      end
    else
      :unknown
    end
  end

  defp evaluate_tactical_impact(participant, killmails) do
    # Calculate tactical impact based on role and participation
    role = Map.get(participant, :tactical_role, :unknown)
    _ship_class = Map.get(participant, :ship_class, :unknown)

    base_impact =
      case role do
        :carrier -> 0.9
        :dreadnought -> 0.8
        :logistics -> 0.8
        :ewar -> 0.7
        :heavy_dps -> 0.6
        :dps -> 0.5
        _ -> 0.3
      end

    # Adjust for actual participation (simplified)
    participation_factor = if length(killmails) > 0, do: 1.0, else: 0.5

    base_impact * participation_factor
  end

  defp calculate_survival_time(participant, activity_timeline) do
    # Calculate how long participant survived in the engagement
    case {Map.get(participant, :participant_type), activity_timeline} do
      {:victim, timeline} ->
        # Victim survived until death event
        calculate_engagement_duration(timeline)

      {:attacker, timeline} ->
        # Attacker survived the whole engagement
        calculate_engagement_duration(timeline)

      _ ->
        0
    end
  end

  defp identify_peak_activity(activity_timeline) do
    if Enum.empty?(activity_timeline) do
      nil
    else
      # Find the period with highest activity density
      timeline_duration = calculate_engagement_duration(activity_timeline)

      if timeline_duration > 0 do
        mid_point = div(timeline_duration, 2)

        %{
          # 30 seconds before mid
          start_time: mid_point - 30,
          # 30 seconds after mid
          end_time: mid_point + 30,
          intensity: :medium
        }
      else
        nil
      end
    end
  end

  # Functions needed for experience analysis
  defp identify_experience_gaps(veteran_players, rookie_players) do
    veteran_avg = calculate_average_experience_for_group(veteran_players)
    rookie_avg = calculate_average_experience_for_group(rookie_players)

    %{
      experience_gap: veteran_avg - rookie_avg,
      veterans_count: length(veteran_players),
      rookies_count: length(rookie_players),
      gap_severity: classify_gap_severity(veteran_avg - rookie_avg)
    }
  end

  defp calculate_average_experience_for_group(players) do
    if length(players) > 0 do
      total_exp =
        Enum.reduce(players, 0.0, fn player, acc ->
          acc + Map.get(player, :experience_score, 0.0)
        end)

      total_exp / length(players)
    else
      0.0
    end
  end

  defp classify_gap_severity(gap) do
    case gap do
      g when g >= 0.6 -> :very_high
      g when g >= 0.4 -> :high
      g when g >= 0.2 -> :medium
      g when g >= 0.1 -> :low
      _ -> :minimal
    end
  end

  defp assess_leadership_potential(veteran_players) do
    # Assess leadership based on experience and ship types
    Enum.map(veteran_players, fn player ->
      experience = Map.get(player, :experience_score, 0.0)
      ship_class = Map.get(player, :ship_class, :unknown)

      leadership_score =
        case ship_class do
          :capital -> experience * 1.2
          :battleship -> experience * 1.1
          _ -> experience
        end

      Map.put(player, :leadership_potential, leadership_score)
    end)
    |> Enum.sort_by(&Map.get(&1, :leadership_potential, 0.0), :desc)
    # Top 5 leadership candidates
    |> Enum.take(5)
  end

  defp analyze_rookie_progression(rookie_players) do
    if length(rookie_players) > 0 do
      avg_security =
        rookie_players
        |> Enum.map(&Map.get(&1, :security_status, 0.0))
        |> Enum.sum()
        |> Kernel./(length(rookie_players))

      ship_diversity =
        rookie_players
        |> Enum.map(&Map.get(&1, :ship_class))
        |> Enum.uniq()
        |> length()

      %{
        learning_rate: assess_learning_rate(avg_security, ship_diversity),
        progression_indicators: identify_progression_indicators(rookie_players),
        # Low diversity suggests need for guidance
        recommended_mentorship: ship_diversity < 2
      }
    else
      %{learning_rate: :unknown, progression_indicators: [], recommended_mentorship: false}
    end
  end

  defp assess_learning_rate(avg_security, ship_diversity) do
    score = avg_security * 0.3 + ship_diversity * 0.7

    case score do
      s when s >= 2.0 -> :fast
      s when s >= 1.0 -> :moderate
      s when s >= 0.5 -> :slow
      _ -> :very_slow
    end
  end

  defp identify_progression_indicators(rookie_players) do
    # Basic progression indicators
    high_security_rookies =
      Enum.count(rookie_players, &(Map.get(&1, :security_status, 0.0) < -1.0))

    capital_rookies = Enum.count(rookie_players, &(Map.get(&1, :ship_class) == :capital))

    indicators = []

    indicators =
      if high_security_rookies > 0, do: [:pvp_engagement | indicators], else: indicators

    indicators = if capital_rookies > 0, do: [:advanced_ships | indicators], else: indicators

    indicators
  end

  defp calculate_average_experience(participants) do
    if length(participants) > 0 do
      total_exp =
        Enum.reduce(participants, 0.0, fn participant, acc ->
          acc + Map.get(participant, :experience_score, 0.0)
        end)

      total_exp / length(participants)
    else
      0.0
    end
  end

  defp measure_experience_diversity(experience_distribution) do
    # Simple diversity measure based on spread
    levels = Map.keys(experience_distribution)

    case length(levels) do
      n when n >= 4 -> :high
      n when n >= 3 -> :medium
      n when n >= 2 -> :low
      _ -> :very_low
    end
  end

  defp identify_mentorship_pairs(veteran_players, rookie_players) do
    # Simple mentorship pairing based on similar ship classes
    Enum.flat_map(veteran_players, fn veteran ->
      veteran_class = Map.get(veteran, :ship_class)
      matching_rookies = Enum.filter(rookie_players, &(Map.get(&1, :ship_class) == veteran_class))

      # Each veteran can mentor up to 2 rookies
      Enum.take(matching_rookies, 2)
      |> Enum.map(fn rookie ->
        %{
          mentor: Map.get(veteran, :character_id),
          mentee: Map.get(rookie, :character_id),
          compatibility: calculate_mentorship_compatibility(veteran, rookie)
        }
      end)
    end)
  end

  defp calculate_mentorship_compatibility(veteran, rookie) do
    # Simple compatibility based on ship class and security status similarity
    class_match = Map.get(veteran, :ship_class) == Map.get(rookie, :ship_class)

    security_diff =
      abs(Map.get(veteran, :security_status, 0.0) - Map.get(rookie, :security_status, 0.0))

    base_score = if class_match, do: 0.7, else: 0.3
    security_adjustment = max(0.0, 0.3 - security_diff / 10.0)

    base_score + security_adjustment
  end

  defp assess_fleet_maturity(experience_distribution) do
    veteran_ratio =
      Map.get(experience_distribution, :veteran, 0) /
        max(1, Map.values(experience_distribution) |> Enum.sum())

    case veteran_ratio do
      ratio when ratio >= 0.5 -> :mature
      ratio when ratio >= 0.3 -> :developing
      ratio when ratio >= 0.1 -> :young
      _ -> :rookie
    end
  end
end
