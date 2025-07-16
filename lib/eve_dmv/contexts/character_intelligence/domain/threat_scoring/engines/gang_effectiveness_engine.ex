defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.GangEffectivenessEngine do
  @moduledoc """
  Gang effectiveness scoring engine for analyzing fleet coordination and leadership.

  Analyzes fleet role execution, leadership patterns, and gang coordination
  to determine gang effectiveness threat level.
  """

  require Logger

  @doc """
  Calculate gang effectiveness score based on combat data.
  """
  def calculate_gang_effectiveness_score(combat_data) do
    Logger.debug("Calculating gang effectiveness score")

    all_killmails = Map.get(combat_data, :killmails, [])
    attacker_killmails = Map.get(combat_data, :attacker_killmails, [])

    # Fleet role execution effectiveness
    fleet_role_score = analyze_fleet_role_execution(combat_data)

    # Leadership patterns analysis
    leadership_score = analyze_leadership_patterns(attacker_killmails)

    # Gang coordination analysis
    gang_patterns = analyze_gang_patterns(all_killmails)
    coordination_score = gang_patterns.coordination_score

    # Team synergy calculation
    team_synergy = calculate_team_synergy(all_killmails)

    # Weighted gang effectiveness score
    raw_score =
      fleet_role_score * 0.30 +
        leadership_score * 0.25 +
        coordination_score * 0.25 +
        team_synergy * 0.20

    %{
      raw_score: raw_score,
      normalized_score: normalize_to_10_scale(raw_score),
      components: %{
        fleet_role_execution: fleet_role_score,
        leadership_patterns: leadership_score,
        gang_coordination: coordination_score,
        team_synergy: team_synergy
      },
      gang_patterns: gang_patterns,
      insights: generate_gang_effectiveness_insights(raw_score, fleet_role_score, leadership_score, coordination_score)
    }
  end

  @doc """
  Analyze fleet role execution effectiveness.
  """
  def analyze_fleet_role_execution(combat_data) do
    Logger.debug("Analyzing fleet role execution")

    all_killmails = Map.get(combat_data, :killmails, [])
    attacker_killmails = Map.get(combat_data, :attacker_killmails, [])

    if Enum.empty?(all_killmails) do
      0.5
    else
      # Analyze ship role consistency
      ship_roles = extract_character_ship_roles(all_killmails)
      role_consistency = calculate_role_consistency(ship_roles)

      # Analyze engagement timing (good fleet members engage at right times)
      timing_effectiveness = analyze_engagement_timing(attacker_killmails)

      # Analyze support behavior (logistics, EWAR usage)
      support_effectiveness = analyze_support_behavior(ship_roles, attacker_killmails)

      # Analyze target prioritization in fleet context
      target_priority_score = analyze_fleet_target_priority(attacker_killmails)

      # Weighted fleet role execution score
      role_consistency * 0.30 +
        timing_effectiveness * 0.25 +
        support_effectiveness * 0.25 +
        target_priority_score * 0.20
    end
  end

  @doc """
  Analyze leadership patterns in gangs.
  """
  def analyze_leadership_patterns(attacker_killmails) do
    Logger.debug("Analyzing leadership patterns for #{length(attacker_killmails)} killmails")

    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Analyze command ship usage
      command_ship_usage = analyze_command_ship_usage(attacker_killmails)

      # Analyze first aggressor patterns (leaders often engage first)
      first_aggressor_rate = calculate_first_aggressor_rate(attacker_killmails)

      # Analyze fleet composition influence
      composition_influence = analyze_fleet_composition_influence(attacker_killmails)

      # Analyze tactical calling patterns (high-value target selection)
      tactical_calling = analyze_tactical_calling_patterns(attacker_killmails)

      # Weighted leadership score
      command_ship_usage * 0.25 +
        first_aggressor_rate * 0.25 +
        composition_influence * 0.25 +
        tactical_calling * 0.25
    end
  end

  @doc """
  Analyze gang coordination patterns.
  """
  def analyze_gang_patterns(killmails) do
    Logger.debug("Analyzing gang patterns for #{length(killmails)} killmails")

    if Enum.empty?(killmails) do
      %{
        coordination_score: 0.5,
        communication_score: 0.5,
        tactical_execution: 0.5,
        gang_size_analysis: %{average_gang_size: 0, coordination_efficiency: 0.5}
      }
    else
      # Analyze gang size patterns
      gang_sizes = extract_gang_sizes(killmails)
      avg_gang_size = if Enum.empty?(gang_sizes), do: 1, else: Enum.sum(gang_sizes) / length(gang_sizes)

      # Coordination analysis based on engagement patterns
      coordination_score = analyze_coordination_patterns(killmails, gang_sizes)

      # Communication inference from timing and targeting
      communication_score = analyze_communication_patterns(killmails)

      # Tactical execution effectiveness
      tactical_execution = analyze_tactical_execution_effectiveness(killmails, gang_sizes)

      # Gang composition analysis
      composition_analysis = analyze_gang_composition_quality(killmails)

      %{
        coordination_score: coordination_score,
        communication_score: communication_score,
        tactical_execution: tactical_execution,
        gang_size_analysis: %{
          average_gang_size: avg_gang_size,
          coordination_efficiency: calculate_coordination_efficiency(avg_gang_size, coordination_score)
        },
        composition_analysis: composition_analysis
      }
    end
  end

  # Private helper functions

  defp calculate_team_synergy(killmails) do
    if Enum.empty?(killmails) do
      0.5
    else
      # Analyze multi-kill participation (team fights)
      multi_kill_rate = calculate_multi_kill_participation(killmails)

      # Analyze damage distribution (good teams have balanced damage)
      damage_distribution = analyze_damage_distribution_balance(killmails)

      # Analyze role synergy (complementary ship types)
      role_synergy = analyze_role_synergy_in_gangs(killmails)

      multi_kill_rate * 0.4 + damage_distribution * 0.3 + role_synergy * 0.3
    end
  end

  defp extract_character_ship_roles(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      # Extract ship types used by the character
      victim_ships = if km.victim_character_id, do: [km.victim_ship_type_id], else: []
      
      attacker_ships = case km.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.filter(&(&1["character_id"] != nil))
          |> Enum.map(& &1["ship_type_id"])
          |> Enum.filter(&(&1 != nil))
        _ -> []
      end

      victim_ships ++ attacker_ships
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.map(&classify_ship_role/1)
    |> Enum.frequencies()
  end

  defp classify_ship_role(ship_type_id) do
    cond do
      ship_type_id in [11_978, 11_987, 11_985, 12_003] -> :logistics
      ship_type_id in [11_957, 11_958, 11_959, 11_961] -> :ewar
      ship_type_id in [22_470, 22_852, 17_918, 17_920] -> :command
      ship_type_id in 580..700 -> :tackle
      ship_type_id in 620..670 -> :dps
      ship_type_id in 19_720..19_740 -> :capital
      true -> :other
    end
  end

  defp calculate_role_consistency(ship_roles) do
    if map_size(ship_roles) == 0 do
      0.5
    else
      total_usage = ship_roles |> Map.values() |> Enum.sum()
      primary_role_usage = ship_roles |> Map.values() |> Enum.max()
      
      # Good role consistency means specialization in 1-2 roles
      consistency_ratio = primary_role_usage / total_usage
      
      cond do
        consistency_ratio > 0.7 -> 1.0      # High specialization
        consistency_ratio > 0.5 -> 0.8      # Good focus
        consistency_ratio > 0.3 -> 0.6      # Some consistency
        true -> 0.4                         # Jack of all trades
      end
    end
  end

  defp analyze_engagement_timing(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Analyze if character engages at optimal times (within first few aggressors)
      early_engagement_count = 
        Enum.count(attacker_killmails, fn km ->
          analyze_aggressor_position(km) <= 3  # Top 3 aggressors
        end)
      
      early_engagement_rate = early_engagement_count / length(attacker_killmails)
      min(1.0, early_engagement_rate * 1.5)  # Bonus for being early
    end
  end

  defp analyze_aggressor_position(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        # Sort by damage done and find character's position
        sorted_attackers = 
          attackers
          |> Enum.filter(&(&1["damage_done"] != nil))
          |> Enum.sort_by(&(-(&1["damage_done"] || 0)))
        
        character_position = 
          sorted_attackers
          |> Enum.find_index(&(&1["character_id"] == killmail.victim_character_id))
        
        if character_position, do: character_position + 1, else: 999
      _ -> 999
    end
  end

  defp analyze_support_behavior(ship_roles, attacker_killmails) do
    logistics_usage = Map.get(ship_roles, :logistics, 0)
    ewar_usage = Map.get(ship_roles, :ewar, 0)
    total_usage = ship_roles |> Map.values() |> Enum.sum()
    
    if total_usage == 0 do
      0.5
    else
      support_ratio = (logistics_usage + ewar_usage) / total_usage
      
      # Analyze support effectiveness through survival rates and kill participation
      support_effectiveness = if support_ratio > 0 do
        # Support players should have good kill participation but fewer deaths
        calculate_support_effectiveness_metrics(attacker_killmails)
      else
        0.5  # Neutral for non-support players
      end
      
      support_ratio * 0.6 + support_effectiveness * 0.4
    end
  end

  defp calculate_support_effectiveness_metrics(attacker_killmails) do
    # Support effectiveness based on consistent participation
    if length(attacker_killmails) > 5 do
      0.8  # Good participation indicates effective support
    else
      0.6
    end
  end

  defp analyze_fleet_target_priority(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Priority targets: logistics, command ships, high-value targets
      priority_kills = 
        Enum.count(attacker_killmails, fn km ->
          is_priority_target?(km.victim_ship_type_id)
        end)
      
      priority_rate = priority_kills / length(attacker_killmails)
      min(1.0, priority_rate * 2.0)  # Bonus for targeting priority ships
    end
  end

  defp is_priority_target?(ship_type_id) do
    ship_type_id in [
      # Logistics
      11_978, 11_987, 11_985, 12_003,
      # Command ships  
      22_470, 22_852, 17_918, 17_920,
      # Force Recon
      11_957, 11_958, 11_959, 11_961
    ]
  end

  defp analyze_command_ship_usage(attacker_killmails) do
    command_ship_kills = 
      Enum.count(attacker_killmails, fn km ->
        classify_ship_role(km.victim_ship_type_id) == :command
      end)
    
    if length(attacker_killmails) > 0 do
      command_ratio = command_ship_kills / length(attacker_killmails)
      min(1.0, command_ratio * 5.0)  # Strong bonus for command ship usage
    else
      0.5
    end
  end

  defp calculate_first_aggressor_rate(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      first_aggressor_count = 
        Enum.count(attacker_killmails, fn km ->
          analyze_aggressor_position(km) == 1
        end)
      
      first_aggressor_rate = first_aggressor_count / length(attacker_killmails)
      min(1.0, first_aggressor_rate * 3.0)  # Bonus for being first aggressor
    end
  end

  defp analyze_fleet_composition_influence(attacker_killmails) do
    # Analyze if kills show good fleet composition (diverse ship types)
    ship_types_in_kills = 
      attacker_killmails
      |> Enum.map(& &1.victim_ship_type_id)
      |> Enum.uniq()
      |> length()
    
    if length(attacker_killmails) > 0 do
      diversity_ratio = ship_types_in_kills / length(attacker_killmails)
      min(1.0, diversity_ratio * 2.0)
    else
      0.5
    end
  end

  defp analyze_tactical_calling_patterns(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Good tactical calling = high-value targets, priority targets
      high_value_kills = 
        Enum.count(attacker_killmails, fn km ->
          estimate_ship_value(km.victim_ship_type_id) > 100_000_000
        end)
      
      tactical_rate = high_value_kills / length(attacker_killmails)
      min(1.0, tactical_rate * 2.0)
    end
  end

  defp estimate_ship_value(ship_type_id) do
    cond do
      ship_type_id in 580..700 -> 5_000_000          # Frigates
      ship_type_id in 420..450 -> 15_000_000         # Destroyers  
      ship_type_id in 620..650 -> 50_000_000         # Cruisers
      ship_type_id in 540..570 -> 150_000_000        # Battlecruisers
      ship_type_id in 640..670 -> 300_000_000        # Battleships
      ship_type_id in 19_720..19_740 -> 2_000_000_000 # Capitals
      true -> 25_000_000                              # Default
    end
  end

  defp extract_gang_sizes(killmails) do
    killmails
    |> Enum.map(fn km ->
      case km.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          length(attackers)
        _ -> 1
      end
    end)
  end

  defp analyze_coordination_patterns(killmails, gang_sizes) do
    if Enum.empty?(killmails) do
      0.5
    else
      # Larger gangs require better coordination
      avg_gang_size = Enum.sum(gang_sizes) / length(gang_sizes)
      
      # Coordination efficiency decreases with gang size
      base_coordination = cond do
        avg_gang_size <= 5 -> 0.9   # Small gang, easy coordination
        avg_gang_size <= 15 -> 0.7  # Medium gang
        avg_gang_size <= 30 -> 0.5  # Large gang
        true -> 0.3                 # Fleet, hard coordination
      end
      
      # Analyze timing consistency (good coordination = consistent engage times)
      timing_consistency = analyze_engagement_timing_consistency(killmails)
      
      base_coordination * 0.6 + timing_consistency * 0.4
    end
  end

  defp analyze_engagement_timing_consistency(killmails) do
    # Analyze if character consistently engages at similar times in fights
    engagement_positions = 
      killmails
      |> Enum.map(&analyze_aggressor_position/1)
      |> Enum.filter(&(&1 < 10))  # Only consider meaningful positions
    
    if length(engagement_positions) < 2 do
      0.5
    else
      # Calculate variance in engagement positions
      avg_position = Enum.sum(engagement_positions) / length(engagement_positions)
      variance = 
        engagement_positions
        |> Enum.map(&((&1 - avg_position) * (&1 - avg_position)))
        |> Enum.sum()
        |> Kernel./(length(engagement_positions))
      
      # Lower variance = better consistency
      consistency_score = max(0.0, 1.0 - variance / 10.0)
      consistency_score
    end
  end

  defp analyze_communication_patterns(killmails) do
    if Enum.empty?(killmails) do
      0.5
    else
      # Infer communication from synchronized targeting
      synchronized_kills = analyze_synchronized_targeting(killmails)
      
      # Good communication = quick target switches, coordinated focus
      target_focus = analyze_target_focus_patterns(killmails)
      
      synchronized_kills * 0.6 + target_focus * 0.4
    end
  end

  defp analyze_synchronized_targeting(killmails) do
    # Look for patterns where character attacks same targets as gang
    # This is complex to implement without full gang data, so simplified
    0.6  # Placeholder - would need cross-character analysis
  end

  defp analyze_target_focus_patterns(killmails) do
    # Analyze if kills show focused targeting (not scattered)
    if length(killmails) < 3 do
      0.5
    else
      # Look at victim ship types diversity
      ship_types = killmails |> Enum.map(& &1.victim_ship_type_id) |> Enum.uniq()
      focus_ratio = length(ship_types) / length(killmails)
      
      # Lower ratio = better focus
      max(0.0, 1.0 - focus_ratio)
    end
  end

  defp analyze_tactical_execution_effectiveness(killmails, gang_sizes) do
    if Enum.empty?(killmails) do
      0.5
    else
      # Tactical execution = appropriate targets for gang size
      avg_gang_size = Enum.sum(gang_sizes) / length(gang_sizes)
      
      appropriate_targets = 
        Enum.count(killmails, fn km ->
          target_appropriate_for_gang_size?(km.victim_ship_type_id, avg_gang_size)
        end)
      
      execution_rate = appropriate_targets / length(killmails)
      min(1.0, execution_rate * 1.2)
    end
  end

  defp target_appropriate_for_gang_size?(ship_type_id, gang_size) do
    ship_class = classify_ship_class(ship_type_id)
    
    case {ship_class, gang_size} do
      {:frigate, _} -> true                    # Always appropriate
      {:cruiser, size} when size >= 3 -> true # Need small gang for cruisers
      {:battleship, size} when size >= 5 -> true # Need decent gang for BS
      {:capital, size} when size >= 10 -> true   # Need fleet for capitals
      _ -> false
    end
  end

  defp classify_ship_class(ship_type_id) do
    cond do
      ship_type_id in 580..700 -> :frigate
      ship_type_id in 420..450 -> :destroyer
      ship_type_id in 620..650 -> :cruiser
      ship_type_id in 540..570 -> :battlecruiser
      ship_type_id in 640..670 -> :battleship
      ship_type_id in 19_720..19_740 -> :capital
      true -> :other
    end
  end

  defp analyze_gang_composition_quality(killmails) do
    # Analyze if gangs have good composition (mix of roles)
    if Enum.empty?(killmails) do
      %{balance_score: 0.5, role_coverage: 0.5}
    else
      ship_roles = 
        killmails
        |> Enum.flat_map(fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.filter(&(&1["ship_type_id"] != nil))
              |> Enum.map(&classify_ship_role(&1["ship_type_id"]))
            _ -> []
          end
        end)
        |> Enum.frequencies()
      
      role_coverage = calculate_role_coverage(ship_roles)
      balance_score = calculate_composition_balance(ship_roles)
      
      %{
        balance_score: balance_score,
        role_coverage: role_coverage,
        dominant_roles: get_dominant_roles(ship_roles)
      }
    end
  end

  defp calculate_role_coverage(ship_roles) do
    essential_roles = [:dps, :tackle, :logistics]
    covered_roles = 
      essential_roles
      |> Enum.count(&(Map.get(ship_roles, &1, 0) > 0))
    
    covered_roles / length(essential_roles)
  end

  defp calculate_composition_balance(ship_roles) do
    if map_size(ship_roles) == 0 do
      0.5
    else
      total_ships = ship_roles |> Map.values() |> Enum.sum()
      
      # Calculate how balanced the composition is (avoid too much of one role)
      max_role_usage = ship_roles |> Map.values() |> Enum.max()
      balance_ratio = max_role_usage / total_ships
      
      # Good balance = no single role dominates too much
      cond do
        balance_ratio <= 0.4 -> 1.0    # Very balanced
        balance_ratio <= 0.6 -> 0.8    # Good balance
        balance_ratio <= 0.8 -> 0.6    # Some imbalance
        true -> 0.4                    # Poor balance
      end
    end
  end

  defp get_dominant_roles(ship_roles) do
    ship_roles
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(2)
    |> Enum.map(&elem(&1, 0))
  end

  defp calculate_coordination_efficiency(gang_size, coordination_score) do
    # Efficiency decreases with gang size but good coordination compensates
    size_penalty = cond do
      gang_size <= 5 -> 1.0
      gang_size <= 15 -> 0.8
      gang_size <= 30 -> 0.6
      true -> 0.4
    end
    
    coordination_score * size_penalty
  end

  defp calculate_multi_kill_participation(killmails) do
    # Multi-kill = more than one attacker
    multi_kills = 
      Enum.count(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            length(attackers) > 1
          _ -> false
        end
      end)
    
    if length(killmails) > 0 do
      multi_kills / length(killmails)
    else
      0.5
    end
  end

  defp analyze_damage_distribution_balance(killmails) do
    # Good teams have balanced damage contribution
    damage_contributions = 
      killmails
      |> Enum.map(&extract_character_damage_contribution/1)
      |> Enum.filter(&(&1 > 0))
    
    if length(damage_contributions) < 2 do
      0.5
    else
      # Calculate variance in damage contributions
      avg_contribution = Enum.sum(damage_contributions) / length(damage_contributions)
      variance = 
        damage_contributions
        |> Enum.map(&((&1 - avg_contribution) * (&1 - avg_contribution)))
        |> Enum.sum()
        |> Kernel./(length(damage_contributions))
      
      # Lower variance = better balance
      balance_score = max(0.0, 1.0 - variance)
      balance_score
    end
  end

  defp extract_character_damage_contribution(killmail) do
    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_list(attackers) and is_number(total_damage) and total_damage > 0 ->
        character_damage = 
          attackers
          |> Enum.find(&(&1["character_id"] == killmail.victim_character_id))
          |> case do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end
        
        character_damage / total_damage
      _ -> 0.0
    end
  end

  defp analyze_role_synergy_in_gangs(killmails) do
    # Analyze if gangs have complementary roles
    gang_compositions = 
      killmails
      |> Enum.map(&extract_gang_composition/1)
      |> Enum.filter(&(map_size(&1) > 1))
    
    if Enum.empty?(gang_compositions) do
      0.5
    else
      synergy_scores = 
        gang_compositions
        |> Enum.map(&calculate_role_synergy_score/1)
      
      Enum.sum(synergy_scores) / length(synergy_scores)
    end
  end

  defp extract_gang_composition(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.filter(&(&1["ship_type_id"] != nil))
        |> Enum.map(&classify_ship_role(&1["ship_type_id"]))
        |> Enum.frequencies()
      _ -> %{}
    end
  end

  defp calculate_role_synergy_score(composition) do
    # Good synergy = balanced mix of complementary roles
    has_dps = Map.get(composition, :dps, 0) > 0
    has_tackle = Map.get(composition, :tackle, 0) > 0
    has_logistics = Map.get(composition, :logistics, 0) > 0
    has_ewar = Map.get(composition, :ewar, 0) > 0
    
    synergy_elements = Enum.count([has_dps, has_tackle, has_logistics, has_ewar], & &1)
    synergy_elements / 4  # Normalize to 0-1
  end

  defp generate_gang_effectiveness_insights(raw_score, fleet_role_score, leadership_score, coordination_score) do
    insights = []
    
    insights = if raw_score > 0.8 do
      ["Excellent gang effectiveness - strong team player" | insights]
    else
      insights
    end
    
    insights = if fleet_role_score > 0.8 do
      ["Highly effective in fleet roles" | insights]
    else
      insights
    end
    
    insights = if leadership_score > 0.7 do
      ["Shows strong leadership indicators" | insights]
    else
      insights
    end
    
    insights = if coordination_score > 0.8 do
      ["Excellent coordination with gang members" | insights]
    else
      insights
    end
    
    insights
  end

  defp normalize_to_10_scale(score) do
    min(10.0, max(0.0, score * 10))
  end
end
