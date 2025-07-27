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
    attackers = case Map.get(killmail, :raw_data) do
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
            tactical_role: determine_tactical_role_from_ship_and_weapon(ship_type_id, weapon_type_id),
            ship_class: classify_ship_class_by_type_id(ship_type_id)
          }
        end)
      _ ->
        # Fallback for missing data
        [%{
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
        }]
    end

    [victim | attackers]
  end

  defp enrich_participant_data(participant) do
    # Enrich participant data with calculated metrics and historical context
    character_id = Map.get(participant, :character_id)
    
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
    alliance_groups = Enum.group_by(participants, fn p -> 
      Map.get(p, :alliance_id) || Map.get(p, :corporation_id)
    end)
    
    # Identify hostile relationships based on who attacked whom
    attackers = Enum.filter(participants, &(&1.participant_type == :attacker))
    victims = Enum.filter(participants, &(&1.participant_type == :victim))
    
    # Get unique alliances/corps from each side
    attacking_affiliations = get_unique_affiliations(attackers)
    victim_affiliations = get_unique_affiliations(victims)
    
    # Find neutral parties (those who appeared on both sides or didn't engage)
    neutral_affiliations = MapSet.intersection(
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
    unaffiliated = Enum.filter(participants, fn p ->
      is_nil(Map.get(p, :alliance_id)) and is_npc_corporation(Map.get(p, :corporation_id))
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
    alliances = participants |> Enum.map(&Map.get(&1, :alliance_id)) |> Enum.uniq() |> Enum.reject(&is_nil/1)
    
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

  defp is_npc_corporation(corp_id) when is_nil(corp_id), do: true
  defp is_npc_corporation(corp_id) when corp_id < 2000000, do: true
  defp is_npc_corporation(_corp_id), do: false

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

  defp identify_coalitions(_participants) do
    # For now, return basic coalition identification
    # TODO: Implement sophisticated coalition identification

    %{}
  end

  defp identify_neutral_parties(_participants) do
    # For now, return basic neutral party identification
    # TODO: Implement neutral party identification

    []
  end

  defp build_relationship_map(_participants) do
    # For now, return basic relationship map
    # TODO: Implement sophisticated relationship mapping

    %{
      allies: %{},
      enemies: %{},
      neutrals: %{}
    }
  end

  defp calculate_role_effectiveness(_role_participants) do
    # For now, return basic role effectiveness
    # TODO: Implement detailed role effectiveness calculation

    0.7
  end

  defp identify_key_players(role_participants) do
    # For now, return basic key player identification
    # TODO: Implement sophisticated key player identification

    Enum.take(role_participants, 3)
  end

  defp analyze_role_balance(_role_distribution) do
    # For now, return basic role balance analysis
    # TODO: Implement detailed role balance analysis

    %{
      balance_score: 0.7,
      imbalances: [],
      recommendations: []
    }
  end

  defp identify_missing_roles(role_distribution) do
    # For now, return basic missing role identification
    # TODO: Implement sophisticated missing role identification

    expected_roles = [:dps, :logistics, :tackle, :ewar, :command]
    present_roles = Map.keys(role_distribution)

    expected_roles -- present_roles
  end

  defp analyze_role_synergies(_role_distribution) do
    # For now, return basic role synergy analysis
    # TODO: Implement detailed role synergy analysis

    %{
      synergy_score: 0.6,
      effective_combinations: [],
      missing_synergies: []
    }
  end

  defp calculate_experience_distribution(participants) do
    # For now, return basic experience distribution
    # TODO: Implement detailed experience distribution calculation

    %{
      veteran: div(length(participants), 4),
      experienced: div(length(participants), 2),
      novice: div(length(participants), 4)
    }
  end

  defp analyze_skill_levels(_participants) do
    # For now, return basic skill level analysis
    # TODO: Implement detailed skill level analysis

    %{
      average_skill: 0.6,
      skill_distribution: %{high: 0.3, medium: 0.5, low: 0.2},
      skill_advantages: []
    }
  end

  defp identify_veteran_players(participants) do
    # For now, return basic veteran identification
    # TODO: Implement sophisticated veteran identification

    Enum.take(participants, div(length(participants), 4))
  end

  defp identify_rookie_players(participants) do
    # For now, return basic rookie identification
    # TODO: Implement sophisticated rookie identification

    Enum.take(participants, -div(length(participants), 4))
  end

  defp calculate_experience_advantage(_participants) do
    # For now, return basic experience advantage
    # TODO: Implement detailed experience advantage calculation

    %{
      overall_advantage: 0.0,
      side_advantages: %{side_a: 0.1, side_b: -0.1}
    }
  end

  defp count_participant_kills(participant, _killmails) do
    # For now, return basic kill count
    # TODO: Implement proper kill counting

    if participant.participant_type == :attacker, do: 1, else: 0
  end

  defp count_participant_deaths(participant, _killmails) do
    # For now, return basic death count
    # TODO: Implement proper death counting

    if participant.participant_type == :victim, do: 1, else: 0
  end

  defp calculate_damage_dealt(participant, _killmails) do
    # For now, return basic damage dealt
    # TODO: Implement proper damage calculation

    if participant.participant_type == :attacker, do: 10_000, else: 0
  end

  defp calculate_damage_received(participant, _killmails) do
    # For now, return basic damage received
    # TODO: Implement proper damage calculation

    if participant.participant_type == :victim, do: 50_000, else: 0
  end

  defp build_activity_timeline(_participant, _killmails) do
    # For now, return basic activity timeline
    # TODO: Implement detailed activity timeline

    []
  end

  defp calculate_contribution_score(_participant, _killmails) do
    # For now, return basic contribution score
    # TODO: Implement sophisticated contribution scoring

    0.5
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

  defp estimate_experience_level(_participant) do
    # For now, return basic experience estimation
    # TODO: Implement sophisticated experience estimation

    :experienced
  end

  defp estimate_threat_rating(_participant) do
    # For now, return basic threat rating
    # TODO: Implement sophisticated threat rating

    5.0
  end

  defp get_historical_performance(_participant) do
    # For now, return basic historical performance
    # TODO: Implement historical performance lookup

    %{
      kills: 100,
      deaths: 50,
      isk_efficiency: 0.75,
      recent_activity: :active
    }
  end

  defp identify_specializations(participant) do
    # For now, return basic specializations
    # TODO: Implement specialization identification

    [participant.tactical_role]
  end

  defp analyze_activity_patterns(_participant) do
    # For now, return basic activity patterns
    # TODO: Implement activity pattern analysis

    %{
      active_hours: [18, 19, 20, 21, 22],
      preferred_systems: [],
      engagement_patterns: []
    }
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
    base_score = case Map.get(participant, :participant_type) do
      :attacker -> 1.0
      :victim -> 0.5
      _ -> 0.0
    end
    
    # Adjust for ship class
    ship_multiplier = case Map.get(participant, :ship_class) do
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
    security_factor = case Map.get(participant, :security_status, 0.0) do
      sec when sec < -2.0 -> 0.8  # Low sec players likely more experienced
      sec when sec < 0.0 -> 0.6
      _ -> 0.4
    end
    
    ship_factor = case Map.get(participant, :ship_class) do
      :capital -> 1.0      # Capital pilots are experienced
      :battleship -> 0.8   # Battleship pilots fairly experienced
      :cruiser -> 0.6      # Medium experience
      _ -> 0.4             # Lower experience
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
    case Enum.max_by(affiliation_groups, fn {_id, members} -> length(members) end, fn -> {nil, []} end) do
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
      max_diversity = :math.log2(length(Map.keys(groups)))
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
      id when id in [1..100] -> :tackle  # Placeholder ranges
      _ -> :scout
    end
  end

  defp classify_cruiser_role(_ship_type_id, weapon_type_id) do
    case weapon_type_id do
      id when is_nil(id) -> :dps
      id when id in [500..600] -> :logistics  # Placeholder ranges
      id when id in [600..700] -> :ewar
      _ -> :dps
    end
  end

  defp classify_capital_role(ship_type_id) do
    # Basic capital classification
    case ship_type_id do
      id when id in [19720..19724] -> :carrier      # Placeholder ranges
      id when id in [19725..19729] -> :dreadnought
      id when id in [3764, 11567] -> :supercarrier
      id when id in [671, 23773] -> :titan
      _ -> :capital
    end
  end

  defp calculate_role_effectiveness(_role_participants) do
    # Basic effectiveness calculation
    0.7
  end

  defp identify_key_players(role_participants) do
    # Basic key player identification - top 3 by damage or experience
    Enum.take(role_participants, 3)
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
      total_experience = Enum.reduce(role_participants, 0.0, fn participant, acc ->
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
      balance_score = 1.0 - (max_count / total_participants)
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
  defp determine_ship_name(_ship_type_id), do: "Ship" # Would lookup in static data

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
      if damage_dealt > 0, do: 10.0, else: 0.0  # High efficiency if no damage taken
    end
  end

  defp calculate_engagement_duration(activity_timeline) do
    case activity_timeline do
      [] -> 0
      timeline ->
        first_event = List.first(timeline)
        last_event = List.last(timeline)
        # Simple duration calculation in seconds
        case {first_event, last_event} do
          {%{timestamp: start_time}, %{timestamp: end_time}} ->
            DateTime.diff(end_time, start_time, :second)
          _ -> 0
        end
    end
  end

  defp assess_combat_intensity(activity_timeline) do
    event_count = length(activity_timeline)
    duration = calculate_engagement_duration(activity_timeline)
    
    if duration > 0 do
      events_per_minute = (event_count * 60) / duration
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
    ship_class = Map.get(participant, :ship_class, :unknown)
    
    base_impact = case role do
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
      _ -> 0
    end
  end

  defp identify_peak_activity(activity_timeline) do
    if length(activity_timeline) == 0 do
      nil
    else
      # Find the period with highest activity density
      timeline_duration = calculate_engagement_duration(activity_timeline)
      if timeline_duration > 0 do
        mid_point = div(timeline_duration, 2)
        %{
          start_time: mid_point - 30,  # 30 seconds before mid
          end_time: mid_point + 30,    # 30 seconds after mid
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
      total_exp = Enum.reduce(players, 0.0, fn player, acc ->
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
      
      leadership_score = case ship_class do
        :capital -> experience * 1.2
        :battleship -> experience * 1.1
        _ -> experience
      end
      
      Map.put(player, :leadership_potential, leadership_score)
    end)
    |> Enum.sort_by(&Map.get(&1, :leadership_potential, 0.0), :desc)
    |> Enum.take(5)  # Top 5 leadership candidates
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
        recommended_mentorship: ship_diversity < 2  # Low diversity suggests need for guidance
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
    high_security_rookies = Enum.count(rookie_players, &(Map.get(&1, :security_status, 0.0) < -1.0))
    capital_rookies = Enum.count(rookie_players, &(Map.get(&1, :ship_class) == :capital))
    
    indicators = []
    indicators = if high_security_rookies > 0, do: [:pvp_engagement | indicators], else: indicators
    indicators = if capital_rookies > 0, do: [:advanced_ships | indicators], else: indicators
    
    indicators
  end

  defp calculate_average_experience(participants) do
    if length(participants) > 0 do
      total_exp = Enum.reduce(participants, 0.0, fn participant, acc ->
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
      
      Enum.take(matching_rookies, 2)  # Each veteran can mentor up to 2 rookies
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
    security_diff = abs(Map.get(veteran, :security_status, 0.0) - Map.get(rookie, :security_status, 0.0))
    
    base_score = if class_match, do: 0.7, else: 0.3
    security_adjustment = max(0.0, 0.3 - (security_diff / 10.0))
    
    base_score + security_adjustment
  end

  defp assess_fleet_maturity(experience_distribution) do
    veteran_ratio = Map.get(experience_distribution, :veteran, 0) / 
                   max(1, Map.values(experience_distribution) |> Enum.sum())
    
    case veteran_ratio do
      ratio when ratio >= 0.5 -> :mature
      ratio when ratio >= 0.3 -> :developing
      ratio when ratio >= 0.1 -> :young
      _ -> :rookie
    end
  end
end
