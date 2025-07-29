defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.Core do
  @moduledoc """
  Core participant extraction functionality.

  Handles the fundamental participant extraction and enrichment operations,
  including basic data gathering and participant metric calculations.
  """

  require Logger

  @doc """
  Extract participants from a single killmail.
  """
  def extract_participants_from_killmail(killmail) do
    victim = extract_victim(killmail)
    attackers = extract_attackers(killmail)

    [victim | attackers]
  end

  @doc """
  Enrich participant data with additional information.
  """
  def enrich_participant_data(participant) do
    participant
    |> add_experience_estimation()
    |> add_threat_assessment()
    |> add_historical_performance()
    |> add_specializations()
    |> add_activity_patterns()
  end

  @doc """
  Calculate comprehensive metrics for a participant.
  """
  def calculate_participant_metrics(participant) do
    participant
    |> Map.put(:combat_score, calculate_combat_score(participant))
    |> Map.put(:efficiency_rating, calculate_efficiency_rating(participant))
    |> Map.put(:threat_level, assess_threat_level(participant))
    |> Map.put(:experience_score, calculate_experience_score(participant))
  end

  @doc """
  Classify participants into sides based on their roles.
  """
  def classify_participants_by_side(participants) do
    # Group participants by their engagement type (attacker/victim)
    attackers = Enum.filter(participants, &(&1.participant_type == :attacker))
    victims = Enum.filter(participants, &(&1.participant_type == :victim))

    # Attempt to identify distinct sides based on affiliations
    # This is complex as EVE battles can have multiple parties
    sides = identify_battle_sides(attackers, victims)

    # Add neutral/third parties
    neutrals = identify_neutral_participants(participants, sides)

    %{
      primary: Map.get(sides, :side_a, []),
      secondary: Map.get(sides, :side_b, []),
      neutrals: neutrals,
      unaligned: find_unaligned_participants(participants, sides, neutrals),
      analysis: %{
        side_count: map_size(sides),
        has_third_parties: not Enum.empty?(neutrals),
        complexity:
          assess_conflict_complexity(
            Map.get(sides, :side_a, []),
            Map.get(sides, :side_b, []),
            neutrals
          )
      }
    }
  end

  # Private functions

  defp extract_victim(killmail) do
    victim = Map.get(killmail, :victim, %{})

    %{
      character_id: Map.get(victim, :character_id),
      character_name: Map.get(victim, :character_name),
      corporation_id: Map.get(victim, :corporation_id),
      corporation_name: Map.get(victim, :corporation_name),
      alliance_id: Map.get(victim, :alliance_id),
      alliance_name: Map.get(victim, :alliance_name),
      ship_type_id: Map.get(victim, :ship_type_id),
      ship_name: determine_ship_name(Map.get(victim, :ship_type_id)),
      ship_class: classify_ship_class_by_type_id(Map.get(victim, :ship_type_id)),
      damage_taken: Map.get(victim, :damage_taken),
      participant_type: :victim,
      final_blow: false,
      security_status: Map.get(victim, :security_status, 0.0),
      killmail_id: Map.get(killmail, :killmail_id),
      killmail_time: Map.get(killmail, :killmail_time),
      position: Map.get(victim, :position),
      items_value: Map.get(victim, :items) |> calculate_items_value()
    }
  end

  defp extract_attackers(killmail) do
    attackers = Map.get(killmail, :attackers, [])

    Enum.map(attackers, fn attacker ->
      %{
        character_id: Map.get(attacker, :character_id),
        character_name: Map.get(attacker, :character_name),
        corporation_id: Map.get(attacker, :corporation_id),
        corporation_name: Map.get(attacker, :corporation_name),
        alliance_id: Map.get(attacker, :alliance_id),
        alliance_name: Map.get(attacker, :alliance_name),
        ship_type_id: Map.get(attacker, :ship_type_id),
        ship_name: determine_ship_name(Map.get(attacker, :ship_type_id)),
        ship_class: classify_ship_class_by_type_id(Map.get(attacker, :ship_type_id)),
        weapon_type_id: Map.get(attacker, :weapon_type_id),
        damage_done: Map.get(attacker, :damage_done),
        participant_type: :attacker,
        final_blow: Map.get(attacker, :final_blow, false),
        security_status: Map.get(attacker, :security_status, 0.0),
        killmail_id: Map.get(killmail, :killmail_id),
        killmail_time: Map.get(killmail, :killmail_time)
      }
    end)
  end

  defp identify_battle_sides(attackers, victims) do
    # Group attackers by their affiliations
    attacker_affiliations = get_unique_affiliations(attackers)
    victim_affiliations = get_unique_affiliations(victims)

    # Simple two-side identification
    # In reality, EVE battles can be more complex with multiple parties
    if not Enum.empty?(attacker_affiliations) and not Enum.empty?(victim_affiliations) do
      %{
        side_a: attackers,
        side_b: victims
      }
    else
      %{}
    end
  end

  defp identify_neutral_participants(participants, _sides) do
    # Identify participants that don't clearly belong to either side
    # This is a simplified implementation
    Enum.filter(participants, fn participant ->
      # High security status victims might be neutrals
      Map.get(participant, :security_status, 0.0) >= 3.0 and
        Map.get(participant, :participant_type) == :victim
    end)
  end

  defp find_unaligned_participants(participants, sides, neutrals) do
    side_a = Map.get(sides, :side_a, [])
    side_b = Map.get(sides, :side_b, [])

    all_assigned = side_a ++ side_b ++ neutrals
    assigned_ids = Enum.map(all_assigned, &Map.get(&1, :character_id))

    Enum.filter(participants, fn p ->
      Map.get(p, :character_id) not in assigned_ids
    end)
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
    side_a_count = length(side_a)
    side_b_count = length(side_b)
    neutral_count = length(neutrals)

    total_participants = side_a_count + side_b_count + neutral_count

    cond do
      total_participants <= 5 -> :small_skirmish
      total_participants <= 20 -> :medium_engagement
      total_participants <= 50 -> :large_battle
      neutral_count > 0 -> :complex_multi_party
      abs(side_a_count - side_b_count) > 20 -> :asymmetric_conflict
      true -> :major_fleet_battle
    end
  end

  defp add_experience_estimation(participant) do
    Map.put(participant, :estimated_experience, estimate_experience_level(participant))
  end

  defp add_threat_assessment(participant) do
    Map.put(participant, :threat_rating, estimate_threat_rating(participant))
  end

  defp add_historical_performance(participant) do
    Map.put(participant, :historical_performance, get_historical_performance(participant))
  end

  defp add_specializations(participant) do
    Map.put(participant, :specializations, identify_specializations(participant))
  end

  defp add_activity_patterns(participant) do
    Map.put(participant, :activity_patterns, analyze_activity_patterns(participant))
  end

  defp estimate_experience_level(participant) do
    # Estimate experience based on security status, ship type, and behavior
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)

    security_factor = calculate_security_experience_factor(security_status)
    ship_factor = calculate_ship_experience_factor(ship_class)

    base_experience = (security_factor + ship_factor) / 2.0

    %{
      level: categorize_experience_level(base_experience),
      score: base_experience,
      factors: %{
        security_status: security_factor,
        ship_choice: ship_factor
      }
    }
  end

  defp calculate_security_experience_factor(security_status) do
    cond do
      # Outlaw, very experienced
      security_status < -5.0 -> 0.9
      # Criminal, experienced
      security_status < -2.0 -> 0.7
      # Suspect, moderate experience
      security_status < 0.0 -> 0.5
      # High-sec dweller, less PvP experience
      security_status > 4.0 -> 0.2
      # Mixed experience
      true -> 0.4
    end
  end

  defp calculate_ship_experience_factor(ship_class) do
    case ship_class do
      # Capital pilots are typically experienced
      :capital -> 0.9
      # Battleship pilots have significant experience
      :battleship -> 0.7
      # Cruiser pilots have moderate experience
      :cruiser -> 0.5
      # Frigate pilots vary widely
      :frigate -> 0.4
      # Unknown or special ships
      _ -> 0.3
    end
  end

  defp categorize_experience_level(score) do
    cond do
      score >= 0.8 -> :veteran
      score >= 0.6 -> :experienced
      score >= 0.4 -> :intermediate
      score >= 0.2 -> :novice
      true -> :rookie
    end
  end

  defp estimate_threat_rating(participant) do
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_potential = estimate_damage_potential(participant)
    participant_type = Map.get(participant, :participant_type)

    base_threat = calculate_base_threat(ship_class)
    damage_modifier = if participant_type == :attacker, do: 1.2, else: 0.8

    threat_score = base_threat * damage_modifier * damage_potential

    %{
      rating: categorize_threat_level(threat_score),
      score: threat_score,
      factors: %{
        ship_class: ship_class,
        damage_potential: damage_potential,
        role: participant_type
      }
    }
  end

  defp calculate_base_threat(ship_class) do
    case ship_class do
      :capital -> 1.0
      :battleship -> 0.8
      :cruiser -> 0.6
      :frigate -> 0.4
      _ -> 0.3
    end
  end

  defp estimate_damage_potential(participant) do
    damage_done = Map.get(participant, :damage_done, 0)

    cond do
      damage_done > 50_000 -> 1.0
      damage_done > 20_000 -> 0.8
      damage_done > 10_000 -> 0.6
      damage_done > 5000 -> 0.4
      true -> 0.2
    end
  end

  defp categorize_threat_level(score) do
    cond do
      score >= 0.9 -> :critical
      score >= 0.7 -> :high
      score >= 0.5 -> :moderate
      score >= 0.3 -> :low
      true -> :minimal
    end
  end

  defp get_historical_performance(participant) do
    # Placeholder for historical data lookup
    # In a real implementation, this would query historical killmail data
    %{
      total_kills: 0,
      total_losses: 0,
      kill_death_ratio: 0.0,
      average_damage_per_kill: 0.0,
      preferred_ship_classes: [],
      active_time_zones: [],
      last_seen: Map.get(participant, :killmail_time)
    }
  end

  defp identify_specializations(participant) do
    ship_class = Map.get(participant, :ship_class, :unknown)
    weapon_type = Map.get(participant, :weapon_type_id)

    []
    |> (fn specs -> if ship_class == :frigate, do: [:tackle | specs], else: specs end).()
    |> (fn specs -> if ship_class == :capital, do: [:capital_warfare | specs], else: specs end).()
    |> (fn specs ->
      if weapon_type && rem(weapon_type || 0, 7) == 0,
        do: [:electronic_warfare | specs],
        else: specs
    end).()
  end

  defp analyze_activity_patterns(_participant) do
    # Analyze when and how the participant typically operates
    # Placeholder implementation
    %{
      # UTC hour
      peak_activity_hour: 20,
      typical_fleet_size: :medium,
      preferred_space: :lowsec,
      engagement_style: :aggressive
    }
  end

  defp calculate_combat_score(participant) do
    damage_done = Map.get(participant, :damage_done, 0)
    damage_taken = Map.get(participant, :damage_taken, 0)
    final_blow = Map.get(participant, :final_blow, false)

    base_score = damage_done * 0.7 + damage_taken * 0.3
    final_blow_bonus = if final_blow, do: 5000, else: 0

    base_score + final_blow_bonus
  end

  defp calculate_efficiency_rating(participant) do
    damage_done = Map.get(participant, :damage_done, 0)
    ship_value = estimate_ship_value(Map.get(participant, :ship_type_id))

    if ship_value > 0 do
      damage_done / ship_value
    else
      0.0
    end
  end

  defp assess_threat_level(participant) do
    threat_rating = Map.get(participant, :threat_rating, %{})
    Map.get(threat_rating, :rating, :unknown)
  end

  defp calculate_experience_score(participant) do
    estimated_experience = Map.get(participant, :estimated_experience, %{})
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)

    experience_base = Map.get(estimated_experience, :score, 0.5)

    # Additional factors
    pvp_indicator = if security_status < 0, do: 0.2, else: 0.0

    ship_complexity =
      case ship_class do
        :capital -> 0.3
        :battleship -> 0.2
        :cruiser -> 0.1
        _ -> 0.0
      end

    (experience_base + pvp_indicator + ship_complexity) * 100
  end

  defp determine_ship_name(ship_type_id) when is_nil(ship_type_id), do: "Unknown Ship"
  defp determine_ship_name(_ship_type_id), do: "Ship"

  defp classify_ship_class_by_type_id(ship_type_id) when is_nil(ship_type_id), do: :unknown
  defp classify_ship_class_by_type_id(ship_type_id) when ship_type_id < 1000, do: :frigate
  defp classify_ship_class_by_type_id(ship_type_id) when ship_type_id < 2000, do: :cruiser
  defp classify_ship_class_by_type_id(ship_type_id) when ship_type_id < 3000, do: :battleship
  defp classify_ship_class_by_type_id(_ship_type_id), do: :capital

  defp calculate_items_value(nil), do: 0.0

  defp calculate_items_value(items) when is_list(items) do
    # Placeholder - would calculate actual ISK value of dropped items
    length(items) * 1_000_000.0
  end

  defp calculate_items_value(_), do: 0.0

  defp estimate_ship_value(nil), do: 1_000_000.0

  defp estimate_ship_value(ship_type_id) do
    # Placeholder - would look up actual ship values
    ship_type_id * 10_000.0
  end
end
