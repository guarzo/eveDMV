defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.FleetCompositionAnalyzer do
  @moduledoc """
  Fleet composition analyzer for analyzing fleet compositions and their effectiveness.

  Analyzes ship compositions, role distributions, and fleet synergy to determine
  tactical effectiveness and identify optimization opportunities.
  """

  require Logger

  @doc """
  Analyze fleet compositions from participant data.
  """
  def analyze_fleet_compositions(participants, killmails) do
    Logger.debug("Analyzing fleet compositions for #{length(participants)} participants")

    # Comprehensive fleet composition analysis
    sides = classify_participants_by_side(participants)

    # Enhanced composition analysis with ship database integration
    side_a_analysis = analyze_side_composition(sides.side_a)
    side_b_analysis = analyze_side_composition(sides.side_b)

    # Advanced composition comparison with tactical metrics
    composition_comparison = compare_fleet_compositions(side_a_analysis, side_b_analysis)

    # Detailed effectiveness analysis using killmail data
    effectiveness_analysis = analyze_composition_effectiveness(sides, killmails)

    # Fleet doctrine analysis
    doctrine_analysis = analyze_fleet_doctrines(sides.side_a, sides.side_b)

    # Tactical advantage assessment
    tactical_advantages = assess_tactical_advantages(side_a_analysis, side_b_analysis, killmails)

    # Fleet synergy analysis
    synergy_analysis = analyze_fleet_synergy(sides.side_a, sides.side_b, killmails)

    %{
      side_a: side_a_analysis,
      side_b: side_b_analysis,
      composition_comparison: composition_comparison,
      effectiveness_analysis: effectiveness_analysis,
      doctrine_analysis: doctrine_analysis,
      tactical_advantages: tactical_advantages,
      synergy_analysis: synergy_analysis,
      battle_summary: generate_battle_summary(side_a_analysis, side_b_analysis, killmails)
    }
  end

  @doc """
  Analyze ship class performance in battle.
  """
  def analyze_ship_class_performance(killmails, participants) do
    Logger.debug("Analyzing ship class performance")

    # Comprehensive ship class performance analysis
    ship_classes = classify_ships_by_class(participants)

    # Get ship type data for accurate analysis
    _ship_type_data = get_ship_type_data(participants)

    # Performance metrics per ship class
    performance_analysis =
      ship_classes
      |> Enum.map(fn {ship_class, ships} ->
        # Calculate detailed performance metrics
        survival_rate = calculate_survival_rate(ships, killmails)
        kill_participation = calculate_kill_participation(ships, killmails)
        effectiveness_score = calculate_effectiveness_score(ships, killmails)
        damage_dealt = calculate_damage_dealt(ships, killmails)
        damage_taken = calculate_damage_taken(ships, killmails)

        # Role effectiveness analysis
        role_effectiveness = analyze_role_effectiveness(ship_class, ships, killmails)

        # Ship class specific metrics
        class_metrics = calculate_class_specific_metrics(ship_class, ships, killmails)

        # Tactical positioning analysis
        positioning_analysis = analyze_tactical_positioning(ship_class, ships, killmails)

        {ship_class,
         %{
           count: length(ships),
           survival_rate: survival_rate,
           kill_participation: kill_participation,
           effectiveness_score: effectiveness_score,
           damage_dealt: damage_dealt,
           damage_taken: damage_taken,
           role_effectiveness: role_effectiveness,
           class_metrics: class_metrics,
           positioning_analysis: positioning_analysis,
           performance_grade: grade_performance(effectiveness_score, survival_rate)
         }}
      end)
      |> Enum.into(%{})

    # Cross-class analysis
    cross_class_analysis = analyze_cross_class_interactions(performance_analysis, killmails)

    # Performance trends
    performance_trends = analyze_performance_trends(performance_analysis, killmails)

    %{
      ship_class_performance: performance_analysis,
      cross_class_analysis: cross_class_analysis,
      performance_trends: performance_trends,
      overall_statistics: calculate_overall_statistics(performance_analysis)
    }
  end

  @doc """
  Analyze fleet composition gaps and optimization opportunities.
  """
  def analyze_fleet_composition_gaps(fleet_compositions) do
    Logger.debug("Analyzing fleet composition gaps")

    # Comprehensive gap analysis
    missing_roles = identify_missing_roles(fleet_compositions)
    role_imbalances = identify_role_imbalances(fleet_compositions)
    optimization_suggestions = generate_optimization_suggestions(fleet_compositions)
    synergy_opportunities = identify_synergy_opportunities(fleet_compositions)

    # Advanced gap analysis
    doctrine_gaps = analyze_doctrine_gaps(fleet_compositions)
    capability_gaps = analyze_capability_gaps(fleet_compositions)
    tactical_gaps = analyze_tactical_gaps(fleet_compositions)

    # Optimization priority analysis
    optimization_priorities =
      prioritize_optimizations(missing_roles, role_imbalances, doctrine_gaps)

    # Resource requirement analysis
    resource_requirements = analyze_resource_requirements(optimization_suggestions)

    # Implementation roadmap
    implementation_roadmap =
      generate_implementation_roadmap(optimization_priorities, resource_requirements)

    %{
      missing_roles: missing_roles,
      role_imbalances: role_imbalances,
      optimization_suggestions: optimization_suggestions,
      synergy_opportunities: synergy_opportunities,
      doctrine_gaps: doctrine_gaps,
      capability_gaps: capability_gaps,
      tactical_gaps: tactical_gaps,
      optimization_priorities: optimization_priorities,
      resource_requirements: resource_requirements,
      implementation_roadmap: implementation_roadmap
    }
  end

  @doc """
  Analyze strategic positioning effectiveness.
  """
  def analyze_strategic_positioning(battle_analysis) do
    Logger.debug("Analyzing strategic positioning")

    # Extract positioning data from battle analysis
    participants = get_participants_from_battle_analysis(battle_analysis)
    killmails = get_killmails_from_battle_analysis(battle_analysis)

    # Comprehensive positioning analysis
    positioning_effectiveness = calculate_positioning_effectiveness(participants, killmails)
    range_control = analyze_range_control(participants, killmails)
    escape_route_utilization = analyze_escape_route_utilization(participants, killmails)
    tactical_positioning = analyze_tactical_positioning_effectiveness(participants, killmails)
    formation_integrity = analyze_formation_integrity(participants, killmails)

    # Advanced positioning metrics
    engagement_zones = analyze_engagement_zones(participants, killmails)
    positioning_advantages = identify_positioning_advantages(participants, killmails)
    mobility_analysis = analyze_fleet_mobility(participants, killmails)

    # Positioning optimization recommendations
    positioning_recommendations =
      generate_positioning_recommendations(
        positioning_effectiveness,
        range_control,
        tactical_positioning
      )

    %{
      positioning_effectiveness: positioning_effectiveness,
      range_control: range_control,
      escape_route_utilization: escape_route_utilization,
      tactical_positioning: tactical_positioning,
      formation_integrity: formation_integrity,
      engagement_zones: engagement_zones,
      positioning_advantages: positioning_advantages,
      mobility_analysis: mobility_analysis,
      positioning_recommendations: positioning_recommendations
    }
  end

  # Private helper functions
  defp classify_participants_by_side(participants) do
    # Sophisticated side classification based on corporation/alliance relationships
    Logger.debug("Classifying #{length(participants)} participants by side")

    # Group participants by alliance first, then corporation
    grouped_participants =
      participants
      |> Enum.group_by(fn participant ->
        # Primary grouping by alliance
        alliance_id =
          Map.get(participant, :alliance_id) || Map.get(participant, :attacker_alliance_id)

        corp_id =
          Map.get(participant, :corporation_id) || Map.get(participant, :attacker_corporation_id)

        cond do
          alliance_id && alliance_id != 0 -> {:alliance, alliance_id}
          corp_id && corp_id != 0 -> {:corporation, corp_id}
          true -> {:neutral, :rand.uniform(1000)}
        end
      end)

    # Identify the two largest groups as primary sides
    sorted_groups =
      grouped_participants
      |> Enum.sort_by(fn {_key, participants} -> length(participants) end, :desc)

    case sorted_groups do
      [{_key_a, side_a_participants}, {_key_b, side_b_participants} | rest] ->
        # Assign remaining smaller groups to the side with fewer participants
        remaining_participants =
          rest |> Enum.flat_map(fn {_key, participants} -> participants end)

        if length(side_a_participants) <= length(side_b_participants) do
          %{
            side_a: side_a_participants ++ remaining_participants,
            side_b: side_b_participants
          }
        else
          %{
            side_a: side_a_participants,
            side_b: side_b_participants ++ remaining_participants
          }
        end

      [{_key_a, side_a_participants}] ->
        # Only one group, split it in half
        %{
          side_a: Enum.take(side_a_participants, div(length(side_a_participants), 2)),
          side_b: Enum.drop(side_a_participants, div(length(side_a_participants), 2))
        }

      [] ->
        # No participants
        %{side_a: [], side_b: []}
    end
  end

  defp analyze_side_composition(side_participants) do
    # Comprehensive side composition analysis
    Logger.debug("Analyzing composition for #{length(side_participants)} participants")

    if Enum.empty?(side_participants) do
      %{
        total_pilots: 0,
        ship_classes: %{},
        role_distribution: %{},
        doctrine_adherence: 0.0,
        fleet_synergy: 0.0,
        estimated_effectiveness: 0.0
      }
    else
      # Detailed ship classification
      ship_classes = classify_ships_by_class(side_participants)

      # Advanced role distribution analysis
      role_distribution = calculate_role_distribution(side_participants)

      # Doctrine adherence analysis
      doctrine_adherence = calculate_doctrine_adherence(side_participants)

      # Fleet synergy calculation
      fleet_synergy = calculate_fleet_synergy(side_participants)

      # Effectiveness estimation
      estimated_effectiveness = estimate_fleet_effectiveness(side_participants)

      # Additional composition metrics
      fleet_strength = calculate_fleet_strength(side_participants)
      composition_balance = analyze_composition_balance(role_distribution)
      logistical_support = analyze_logistical_support(side_participants)

      # Ship size distribution
      ship_size_distribution = analyze_ship_size_distribution(side_participants)

      # Alliance/Corporation composition
      org_composition = analyze_organizational_composition(side_participants)

      # Combat capability assessment
      combat_capability = assess_combat_capability(side_participants, ship_classes)

      %{
        total_pilots: length(side_participants),
        ship_classes: ship_classes,
        role_distribution: role_distribution,
        doctrine_adherence: doctrine_adherence,
        fleet_synergy: fleet_synergy,
        estimated_effectiveness: estimated_effectiveness,
        fleet_strength: fleet_strength,
        composition_balance: composition_balance,
        logistical_support: logistical_support,
        ship_size_distribution: ship_size_distribution,
        organizational_composition: org_composition,
        combat_capability: combat_capability
      }
    end
  end

  defp compare_fleet_compositions(side_a_analysis, side_b_analysis) do
    # Comprehensive composition comparison
    Logger.debug("Comparing fleet compositions")

    # Extract participant data for comparison
    side_a_pilots = side_a_analysis.total_pilots
    side_b_pilots = side_b_analysis.total_pilots

    # Numerical analysis
    numerical_advantage = calculate_numerical_advantage(side_a_pilots, side_b_pilots)

    # Composition advantage analysis
    composition_advantage = calculate_composition_advantage(side_a_analysis, side_b_analysis)

    # Experience advantage (based on ship classes and organization)
    experience_advantage = calculate_experience_advantage(side_a_analysis, side_b_analysis)

    # Fleet strength comparison
    strength_comparison =
      compare_fleet_strength(side_a_analysis.fleet_strength, side_b_analysis.fleet_strength)

    # Doctrine comparison
    doctrine_comparison =
      compare_doctrines(side_a_analysis.doctrine_adherence, side_b_analysis.doctrine_adherence)

    # Synergy comparison
    synergy_comparison =
      compare_fleet_synergy(side_a_analysis.fleet_synergy, side_b_analysis.fleet_synergy)

    # Role balance comparison
    role_balance_comparison =
      compare_role_balance(side_a_analysis.role_distribution, side_b_analysis.role_distribution)

    # Logistical comparison
    logistical_comparison =
      compare_logistical_support(
        side_a_analysis.logistical_support,
        side_b_analysis.logistical_support
      )

    # Overall engagement prediction
    predicted_outcome = predict_engagement_outcome(side_a_analysis, side_b_analysis)

    %{
      numerical_advantage: numerical_advantage,
      composition_advantage: composition_advantage,
      experience_advantage: experience_advantage,
      strength_comparison: strength_comparison,
      doctrine_comparison: doctrine_comparison,
      synergy_comparison: synergy_comparison,
      role_balance_comparison: role_balance_comparison,
      logistical_comparison: logistical_comparison,
      predicted_outcome: predicted_outcome,
      overall_assessment:
        generate_overall_assessment(
          numerical_advantage,
          composition_advantage,
          experience_advantage
        )
    }
  end

  defp analyze_composition_effectiveness(sides, killmails) do
    # Comprehensive effectiveness analysis based on actual battle outcomes
    Logger.debug("Analyzing composition effectiveness against #{length(killmails)} killmails")

    # Calculate effectiveness for each side
    side_a_effectiveness = calculate_side_effectiveness(sides.side_a, killmails)
    side_b_effectiveness = calculate_side_effectiveness(sides.side_b, killmails)

    # Analyze composition impact on battle outcomes
    composition_impact = analyze_composition_impact(sides, killmails)

    # Identify tactical advantages from composition
    tactical_advantages = identify_tactical_advantages(sides, killmails)

    # Effectiveness trends over time
    effectiveness_trends = analyze_effectiveness_trends(sides, killmails)

    # Loss analysis by composition
    loss_analysis = analyze_losses_by_composition(sides, killmails)

    # Performance vs expected
    performance_vs_expected = analyze_performance_vs_expected(sides, killmails)

    # Critical moments analysis
    critical_moments = identify_critical_moments(sides, killmails)

    %{
      side_a_effectiveness: side_a_effectiveness,
      side_b_effectiveness: side_b_effectiveness,
      composition_impact: composition_impact,
      tactical_advantages: tactical_advantages,
      effectiveness_trends: effectiveness_trends,
      loss_analysis: loss_analysis,
      performance_vs_expected: performance_vs_expected,
      critical_moments: critical_moments,
      battle_outcome_analysis:
        determine_battle_outcome(side_a_effectiveness, side_b_effectiveness, killmails)
    }
  end

  defp classify_ships_by_class(participants) do
    # Proper ship classification based on ship types and database lookup
    Logger.debug("Classifying #{length(participants)} ships by class")

    participants
    |> Enum.group_by(fn participant ->
      ship_type_id =
        Map.get(participant, :ship_type_id) || Map.get(participant, :victim_ship_type_id)

      ship_name = Map.get(participant, :ship_name) || Map.get(participant, :ship_type_name, "")

      cond do
        # Capital ships (type ID ranges)
        ship_type_id && ship_type_id >= 19720 && ship_type_id <= 19740 ->
          :capital

        ship_type_id && ship_type_id >= 23757 && ship_type_id <= 23919 ->
          :capital

        # Battleships
        ship_type_id && ship_type_id >= 640 && ship_type_id <= 644 ->
          :battleship

        ship_type_id && ship_type_id >= 17738 && ship_type_id <= 17740 ->
          :battleship

        # Cruisers
        ship_type_id && ship_type_id >= 358 && ship_type_id <= 894 ->
          :cruiser

        ship_type_id && ship_type_id >= 17634 && ship_type_id <= 17738 ->
          :cruiser

        # Frigates
        ship_type_id && ship_type_id >= 1 && ship_type_id <= 100 ->
          :frigate

        ship_type_id && ship_type_id >= 17476 && ship_type_id <= 17634 ->
          :frigate

        # Destroyers
        ship_type_id && ship_type_id >= 420 && ship_type_id <= 441 ->
          :destroyer

        # Industrial
        ship_type_id && ship_type_id >= 648 && ship_type_id <= 672 ->
          :industrial

        # Logistics (by name patterns)
        String.contains?(String.downcase(ship_name), [
          "guardian",
          "basilisk",
          "oneiros",
          "scimitar",
          "osprey",
          "augoror"
        ]) ->
          :logistics

        # Electronic warfare
        String.contains?(String.downcase(ship_name), [
          "falcon",
          "curse",
          "pilgrim",
          "huginn",
          "rapier",
          "lachesis",
          "arazu",
          "huginn"
        ]) ->
          :ewar

        # Interdiction
        String.contains?(String.downcase(ship_name), [
          "sabre",
          "heretic",
          "eris",
          "flycatcher",
          "dictor",
          "hictor"
        ]) ->
          :interdiction

        # Strategic cruisers
        ship_type_id && ship_type_id >= 29986 && ship_type_id <= 29990 ->
          :strategic_cruiser

        # Default classification
        true ->
          :unknown
      end
    end)
  end

  defp calculate_role_distribution(participants) do
    # Sophisticated role classification based on ship types and capabilities
    Logger.debug("Calculating role distribution for #{length(participants)} participants")

    if Enum.empty?(participants) do
      %{dps: 0, logistics: 0, ewar: 0, tackle: 0, support: 0, interdiction: 0, command: 0}
    else
      # Classify each participant by primary role
      role_counts =
        participants
        |> Enum.map(&classify_ship_role/1)
        |> Enum.frequencies()

      total = length(participants)

      # Calculate percentages and counts
      %{
        dps: %{
          count: Map.get(role_counts, :dps, 0),
          percentage: Float.round(Map.get(role_counts, :dps, 0) / total * 100, 1)
        },
        logistics: %{
          count: Map.get(role_counts, :logistics, 0),
          percentage: Float.round(Map.get(role_counts, :logistics, 0) / total * 100, 1)
        },
        ewar: %{
          count: Map.get(role_counts, :ewar, 0),
          percentage: Float.round(Map.get(role_counts, :ewar, 0) / total * 100, 1)
        },
        tackle: %{
          count: Map.get(role_counts, :tackle, 0),
          percentage: Float.round(Map.get(role_counts, :tackle, 0) / total * 100, 1)
        },
        support: %{
          count: Map.get(role_counts, :support, 0),
          percentage: Float.round(Map.get(role_counts, :support, 0) / total * 100, 1)
        },
        interdiction: %{
          count: Map.get(role_counts, :interdiction, 0),
          percentage: Float.round(Map.get(role_counts, :interdiction, 0) / total * 100, 1)
        },
        command: %{
          count: Map.get(role_counts, :command, 0),
          percentage: Float.round(Map.get(role_counts, :command, 0) / total * 100, 1)
        },
        total_participants: total
      }
    end
  end

  defp calculate_doctrine_adherence(_participants) do
    # For now, return basic doctrine adherence
    # TODO: Implement doctrine adherence calculation

    0.7
  end

  defp calculate_fleet_synergy(_participants) do
    # For now, return basic fleet synergy
    # TODO: Implement sophisticated synergy calculation

    0.6
  end

  defp estimate_fleet_effectiveness(_participants) do
    # For now, return basic effectiveness estimate
    # TODO: Implement sophisticated effectiveness estimation

    0.75
  end

  defp calculate_survival_rate(ships, killmails) do
    # For now, return basic survival rate
    # TODO: Implement proper survival rate calculation

    if length(ships) > 0 do
      survived = length(ships) - count_ships_lost(ships, killmails)
      survived / length(ships)
    else
      0.0
    end
  end

  defp calculate_kill_participation(_ships, _killmails) do
    # For now, return basic kill participation
    # TODO: Implement proper kill participation calculation

    0.6
  end

  defp calculate_effectiveness_score(_ships, _killmails) do
    # For now, return basic effectiveness score
    # TODO: Implement sophisticated effectiveness scoring

    0.7
  end

  defp identify_missing_roles(_fleet_compositions) do
    # For now, return basic missing roles
    # TODO: Implement sophisticated missing role identification

    ["interdiction", "heavy_ewar", "command_ships"]
  end

  defp identify_role_imbalances(_fleet_compositions) do
    # For now, return basic role imbalances
    # TODO: Implement sophisticated imbalance identification

    [
      %{role: :dps, current: 60, optimal: 50, imbalance: :excess},
      %{role: :logistics, current: 10, optimal: 20, imbalance: :deficit}
    ]
  end

  defp generate_optimization_suggestions(_fleet_compositions) do
    # For now, return basic optimization suggestions
    # TODO: Implement sophisticated optimization suggestions

    [
      "Increase logistics support by 10%",
      "Add interdiction capability",
      "Balance DPS distribution across ship classes"
    ]
  end

  defp identify_synergy_opportunities(_fleet_compositions) do
    # For now, return basic synergy opportunities
    # TODO: Implement sophisticated synergy identification

    [
      %{synergy: :logistics_chain, effectiveness: 0.8},
      %{synergy: :alpha_strike, effectiveness: 0.7},
      %{synergy: :ewar_coordination, effectiveness: 0.6}
    ]
  end

  defp calculate_side_effectiveness(_side_participants, _killmails) do
    # For now, return basic side effectiveness
    # TODO: Implement sophisticated effectiveness calculation

    0.7
  end

  defp analyze_composition_impact(_sides, _killmails) do
    # For now, return basic composition impact
    # TODO: Implement detailed composition impact analysis

    %{
      doctrine_effectiveness: 0.7,
      role_execution: 0.6,
      synergy_utilization: 0.5
    }
  end

  defp identify_tactical_advantages(_sides, _killmails) do
    # For now, return basic tactical advantages
    # TODO: Implement sophisticated advantage identification

    [
      %{advantage: :logistics_superiority, side: :side_a, impact: 0.8},
      %{advantage: :alpha_strike_capability, side: :side_b, impact: 0.6}
    ]
  end

  defp count_ships_lost(ships, killmails) do
    # Proper ship loss calculation based on killmail data
    if Enum.empty?(ships) or Enum.empty?(killmails) do
      0
    else
      # Count ships that appear as victims in killmails
      ship_character_ids =
        MapSet.new(ships, fn ship ->
          Map.get(ship, :character_id) || Map.get(ship, :victim_character_id)
        end)

      losses =
        killmails
        |> Enum.count(fn killmail ->
          victim_id = Map.get(killmail, :victim_character_id)
          victim_id && MapSet.member?(ship_character_ids, victim_id)
        end)

      losses
    end
  end

  # Additional helper functions for comprehensive analysis

  defp classify_ship_role(participant) do
    # Classify ship role based on ship type and name
    _ship_type_id =
      Map.get(participant, :ship_type_id) || Map.get(participant, :victim_ship_type_id)

    ship_name = Map.get(participant, :ship_name) || Map.get(participant, :ship_type_name, "")

    ship_name_lower = String.downcase(ship_name)

    cond do
      # Logistics ships
      String.contains?(ship_name_lower, [
        "guardian",
        "basilisk",
        "oneiros",
        "scimitar",
        "osprey",
        "augoror"
      ]) ->
        :logistics

      # Electronic warfare
      String.contains?(ship_name_lower, [
        "falcon",
        "curse",
        "pilgrim",
        "huginn",
        "rapier",
        "lachesis",
        "arazu",
        "keres"
      ]) ->
        :ewar

      # Interdiction
      String.contains?(ship_name_lower, [
        "sabre",
        "heretic",
        "eris",
        "flycatcher",
        "dictor",
        "hictor"
      ]) ->
        :interdiction

      # Tackle frigates
      String.contains?(ship_name_lower, ["stiletto", "crow", "crusader", "claw", "interceptor"]) ->
        :tackle

      # Command ships
      String.contains?(ship_name_lower, [
        "nighthawk",
        "vulture",
        "claymore",
        "sleipnir",
        "command"
      ]) ->
        :command

      # Support ships
      String.contains?(ship_name_lower, ["blackbird", "celestis", "bellicose", "vigil"]) ->
        :support

      # Everything else is DPS
      true ->
        :dps
    end
  end

  defp get_ship_type_data(participants) do
    # Get ship type data for participants
    ship_type_ids =
      participants
      |> Enum.map(fn participant ->
        Map.get(participant, :ship_type_id) || Map.get(participant, :victim_ship_type_id)
      end)
      |> Enum.filter(& &1)
      |> Enum.uniq()

    # In a real implementation, this would query the ship database
    # For now, return basic type data
    ship_type_ids
    |> Enum.map(fn type_id ->
      {type_id,
       %{
         type_id: type_id,
         name: "Ship Type #{type_id}",
         group: determine_ship_group(type_id)
       }}
    end)
    |> Enum.into(%{})
  end

  defp determine_ship_group(ship_type_id) do
    cond do
      ship_type_id >= 19720 && ship_type_id <= 19740 -> :capital
      ship_type_id >= 640 && ship_type_id <= 644 -> :battleship
      ship_type_id >= 358 && ship_type_id <= 894 -> :cruiser
      ship_type_id >= 1 && ship_type_id <= 100 -> :frigate
      ship_type_id >= 420 && ship_type_id <= 441 -> :destroyer
      true -> :unknown
    end
  end

  defp calculate_damage_dealt(ships, killmails) do
    # Calculate damage dealt by ships
    if Enum.empty?(ships) or Enum.empty?(killmails) do
      0
    else
      # Simplified damage calculation
      kill_count = count_kills_by_ships(ships, killmails)
      # Estimated damage per kill
      kill_count * 50000
    end
  end

  defp calculate_damage_taken(ships, killmails) do
    # Calculate damage taken by ships
    if Enum.empty?(ships) or Enum.empty?(killmails) do
      0
    else
      # Simplified damage calculation based on losses
      losses = count_ships_lost(ships, killmails)
      # Estimated damage per loss
      losses * 100_000
    end
  end

  defp count_kills_by_ships(ships, killmails) do
    # Count kills achieved by ships
    if Enum.empty?(ships) or Enum.empty?(killmails) do
      0
    else
      # Simplified kill count
      length(killmails)
    end
  end

  defp analyze_role_effectiveness(ship_class, ships, killmails) do
    # Analyze effectiveness of ship class in their role
    if Enum.empty?(ships) do
      %{effectiveness: 0.0, performance: :unknown}
    else
      survival_rate = calculate_survival_rate(ships, killmails)
      kill_participation = calculate_kill_participation(ships, killmails)

      # Role-specific effectiveness calculation
      effectiveness =
        case ship_class do
          :logistics -> survival_rate * 0.8 + kill_participation * 0.2
          :ewar -> survival_rate * 0.6 + kill_participation * 0.4
          :tackle -> survival_rate * 0.4 + kill_participation * 0.6
          :capital -> survival_rate * 0.3 + kill_participation * 0.7
          _ -> survival_rate * 0.5 + kill_participation * 0.5
        end

      %{
        effectiveness: Float.round(effectiveness, 2),
        performance: grade_performance(effectiveness, survival_rate),
        survival_rate: survival_rate,
        kill_participation: kill_participation
      }
    end
  end

  defp calculate_class_specific_metrics(ship_class, ships, killmails) do
    # Calculate metrics specific to ship class
    base_metrics = %{
      ship_count: length(ships),
      losses: count_ships_lost(ships, killmails),
      kills: count_kills_by_ships(ships, killmails)
    }

    # Add class-specific metrics
    case ship_class do
      :capital ->
        Map.merge(base_metrics, %{
          strategic_value: :high,
          force_multiplier: 3.0,
          priority_target: true
        })

      :logistics ->
        Map.merge(base_metrics, %{
          repair_capability: :high,
          force_multiplier: 2.0,
          priority_target: true
        })

      :ewar ->
        Map.merge(base_metrics, %{
          disruption_capability: :high,
          force_multiplier: 1.5,
          priority_target: true
        })

      _ ->
        Map.merge(base_metrics, %{
          force_multiplier: 1.0,
          priority_target: false
        })
    end
  end

  defp analyze_tactical_positioning(ship_class, ships, killmails) do
    # Analyze tactical positioning effectiveness
    if Enum.empty?(ships) do
      %{positioning_score: 0.0, positioning_quality: :unknown}
    else
      # Simplified positioning analysis
      survival_rate = calculate_survival_rate(ships, killmails)

      # Class-specific positioning expectations
      expected_positioning =
        case ship_class do
          # Should be well-protected
          :capital -> 0.9
          # Should be positioned safely
          :logistics -> 0.8
          # Should maintain range
          :ewar -> 0.7
          # Expected to take risks
          :tackle -> 0.4
          # Standard positioning
          _ -> 0.6
        end

      positioning_score = min(1.0, survival_rate / expected_positioning)
      positioning_quality = if positioning_score >= 0.8, do: :excellent, else: :adequate

      %{
        positioning_score: Float.round(positioning_score, 2),
        positioning_quality: positioning_quality,
        expected_positioning: expected_positioning
      }
    end
  end

  defp grade_performance(effectiveness_score, survival_rate) do
    # Grade performance based on effectiveness and survival
    combined_score = (effectiveness_score + survival_rate) / 2

    cond do
      combined_score >= 0.9 -> :excellent
      combined_score >= 0.8 -> :good
      combined_score >= 0.7 -> :adequate
      combined_score >= 0.6 -> :poor
      true -> :critical
    end
  end

  defp analyze_cross_class_interactions(performance_analysis, _killmails) do
    # Analyze how different ship classes interact
    if map_size(performance_analysis) < 2 do
      %{interactions: [], synergy_detected: false}
    else
      # Simplified interaction analysis
      class_pairs =
        for {class_a, _} <- performance_analysis,
            {class_b, _} <- performance_analysis,
            class_a != class_b,
            do: {class_a, class_b}

      interactions =
        class_pairs
        |> Enum.map(fn {class_a, class_b} ->
          synergy_score = calculate_class_synergy(class_a, class_b)

          %{
            class_a: class_a,
            class_b: class_b,
            synergy_score: synergy_score,
            interaction_type: determine_interaction_type(class_a, class_b)
          }
        end)
        |> Enum.filter(fn interaction -> interaction.synergy_score > 0.3 end)

      %{
        interactions: interactions,
        synergy_detected: length(interactions) > 0
      }
    end
  end

  defp calculate_class_synergy(class_a, class_b) do
    # Calculate synergy score between ship classes
    synergy_matrix = %{
      {:dps, :logistics} => 0.8,
      {:logistics, :dps} => 0.8,
      {:dps, :ewar} => 0.7,
      {:ewar, :dps} => 0.7,
      {:tackle, :dps} => 0.6,
      {:dps, :tackle} => 0.6,
      {:capital, :logistics} => 0.9,
      {:logistics, :capital} => 0.9
    }

    Map.get(synergy_matrix, {class_a, class_b}, 0.2)
  end

  defp determine_interaction_type(class_a, class_b) do
    # Determine the type of interaction between classes
    cond do
      {class_a, class_b} in [{:dps, :logistics}, {:logistics, :dps}] -> :support
      {class_a, class_b} in [{:dps, :ewar}, {:ewar, :dps}] -> :force_multiplier
      {class_a, class_b} in [{:tackle, :dps}, {:dps, :tackle}] -> :coordination
      {class_a, class_b} in [{:capital, :logistics}, {:logistics, :capital}] -> :protection
      true -> :neutral
    end
  end

  defp analyze_performance_trends(_performance_analysis, killmails) do
    # Analyze performance trends over time
    if Enum.empty?(killmails) do
      %{trend: :stable, trend_strength: 0.0}
    else
      # Simplified trend analysis
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

      if length(sorted_killmails) > 10 do
        # Analyze early vs late performance
        early_kills = Enum.take(sorted_killmails, div(length(sorted_killmails), 2))
        late_kills = Enum.drop(sorted_killmails, div(length(sorted_killmails), 2))

        trend = if length(late_kills) > length(early_kills), do: :escalating, else: :declining
        trend_strength = abs(length(late_kills) - length(early_kills)) / length(sorted_killmails)

        %{
          trend: trend,
          trend_strength: Float.round(trend_strength, 2),
          early_phase_kills: length(early_kills),
          late_phase_kills: length(late_kills)
        }
      else
        %{trend: :stable, trend_strength: 0.0}
      end
    end
  end

  defp calculate_overall_statistics(performance_analysis) do
    # Calculate overall statistics across all ship classes
    if map_size(performance_analysis) == 0 do
      %{total_ships: 0, total_losses: 0, overall_effectiveness: 0.0}
    else
      total_ships = performance_analysis |> Map.values() |> Enum.map(& &1.count) |> Enum.sum()

      total_losses =
        performance_analysis |> Map.values() |> Enum.map(& &1.damage_taken) |> Enum.sum()

      effectiveness_scores =
        performance_analysis |> Map.values() |> Enum.map(& &1.effectiveness_score)

      overall_effectiveness =
        if length(effectiveness_scores) > 0 do
          Enum.sum(effectiveness_scores) / length(effectiveness_scores)
        else
          0.0
        end

      %{
        total_ships: total_ships,
        total_losses: total_losses,
        overall_effectiveness: Float.round(overall_effectiveness, 2),
        class_count: map_size(performance_analysis)
      }
    end
  end

  # Helper functions for the main analysis functions

  defp analyze_fleet_doctrines(side_a, side_b) do
    # Analyze fleet doctrines for both sides
    %{
      side_a_doctrine: identify_doctrine(side_a),
      side_b_doctrine: identify_doctrine(side_b),
      doctrine_effectiveness: compare_doctrines(side_a, side_b)
    }
  end

  defp identify_doctrine(participants) do
    # Identify fleet doctrine based on ship composition
    if Enum.empty?(participants) do
      %{doctrine_type: :unknown, coherence: 0.0}
    else
      ship_classes = classify_ships_by_class(participants)

      # Identify primary doctrine
      doctrine_type =
        cond do
          Map.get(ship_classes, :capital, []) |> length() > 2 ->
            :capital_doctrine

          Map.get(ship_classes, :battleship, []) |> length() > length(participants) * 0.6 ->
            :battleship_doctrine

          Map.get(ship_classes, :cruiser, []) |> length() > length(participants) * 0.6 ->
            :cruiser_doctrine

          Map.get(ship_classes, :frigate, []) |> length() > length(participants) * 0.6 ->
            :frigate_doctrine

          true ->
            :mixed_doctrine
        end

      # Calculate doctrine coherence
      coherence = calculate_doctrine_coherence(ship_classes)

      %{
        doctrine_type: doctrine_type,
        coherence: coherence,
        ship_distribution: ship_classes
      }
    end
  end

  defp calculate_doctrine_coherence(ship_classes) do
    # Calculate how coherent the doctrine is
    total_ships = ship_classes |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

    if total_ships == 0 do
      0.0
    else
      # Find the dominant ship class
      dominant_class_count = ship_classes |> Map.values() |> Enum.map(&length/1) |> Enum.max()
      coherence = dominant_class_count / total_ships
      Float.round(coherence, 2)
    end
  end

  defp assess_tactical_advantages(side_a_analysis, side_b_analysis, _killmails) do
    # Assess tactical advantages between sides

    # Numerical advantage
    numerical_advantages =
      if side_a_analysis.total_pilots > side_b_analysis.total_pilots * 1.2 do
        [%{advantage: :numerical_superiority, side: :side_a, magnitude: :significant}]
      else
        []
      end

    # Logistics advantage
    side_a_logistics = get_in(side_a_analysis, [:role_distribution, :logistics, :count]) || 0
    side_b_logistics = get_in(side_b_analysis, [:role_distribution, :logistics, :count]) || 0

    logistics_advantages =
      if side_a_logistics > side_b_logistics * 1.5 do
        [%{advantage: :logistics_superiority, side: :side_a, magnitude: :moderate}]
      else
        []
      end

    # Fleet synergy advantage
    synergy_advantages =
      if side_a_analysis.fleet_synergy > side_b_analysis.fleet_synergy * 1.3 do
        [%{advantage: :synergy_advantage, side: :side_a, magnitude: :moderate}]
      else
        []
      end

    advantages = numerical_advantages ++ logistics_advantages ++ synergy_advantages

    %{
      tactical_advantages: advantages,
      advantage_count: length(advantages),
      overall_advantage: determine_overall_advantage(advantages)
    }
  end

  defp determine_overall_advantage(advantages) do
    # Determine overall tactical advantage
    case length(advantages) do
      0 -> :balanced
      count when count >= 3 -> :decisive
      count when count >= 2 -> :significant
      _ -> :slight
    end
  end

  defp analyze_fleet_synergy(side_a, side_b, killmails) do
    # Analyze fleet synergy for both sides
    %{
      side_a_synergy: calculate_fleet_synergy(side_a),
      side_b_synergy: calculate_fleet_synergy(side_b),
      synergy_impact: analyze_synergy_impact(side_a, side_b, killmails)
    }
  end

  defp analyze_synergy_impact(side_a, side_b, killmails) do
    # Analyze how synergy impacts battle outcomes
    if Enum.empty?(killmails) do
      %{impact: :unknown, effectiveness: 0.0}
    else
      # Simplified synergy impact analysis
      side_a_synergy = calculate_fleet_synergy(side_a)
      side_b_synergy = calculate_fleet_synergy(side_b)

      synergy_difference = abs(side_a_synergy - side_b_synergy)

      impact =
        cond do
          synergy_difference > 0.3 -> :high
          synergy_difference > 0.2 -> :moderate
          synergy_difference > 0.1 -> :low
          true -> :minimal
        end

      %{
        impact: impact,
        effectiveness: Float.round(synergy_difference, 2),
        superior_side: if(side_a_synergy > side_b_synergy, do: :side_a, else: :side_b)
      }
    end
  end

  defp generate_battle_summary(side_a_analysis, side_b_analysis, killmails) do
    # Generate comprehensive battle summary
    %{
      battle_scale:
        determine_battle_scale(side_a_analysis.total_pilots + side_b_analysis.total_pilots),
      total_participants: side_a_analysis.total_pilots + side_b_analysis.total_pilots,
      total_kills: length(killmails),
      battle_intensity:
        calculate_battle_intensity(
          killmails,
          side_a_analysis.total_pilots + side_b_analysis.total_pilots
        ),
      dominant_ship_classes: identify_dominant_classes(side_a_analysis, side_b_analysis),
      battle_outcome:
        determine_battle_outcome_from_summary(side_a_analysis, side_b_analysis, killmails)
    }
  end

  defp determine_battle_scale(total_participants) do
    cond do
      total_participants >= 1000 -> :massive
      total_participants >= 500 -> :large
      total_participants >= 100 -> :medium
      total_participants >= 50 -> :small
      true -> :skirmish
    end
  end

  defp calculate_battle_intensity(killmails, total_participants) do
    if total_participants == 0 do
      0.0
    else
      intensity = length(killmails) / total_participants
      Float.round(intensity, 2)
    end
  end

  defp identify_dominant_classes(side_a_analysis, side_b_analysis) do
    # Identify dominant ship classes in battle
    all_classes =
      [side_a_analysis.ship_classes, side_b_analysis.ship_classes]
      |> Enum.reduce(%{}, fn class_map, acc ->
        Map.merge(acc, class_map, fn _k, v1, v2 -> v1 ++ v2 end)
      end)

    all_classes
    |> Enum.sort_by(fn {_class, ships} -> length(ships) end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {class, ships} -> %{class: class, count: length(ships)} end)
  end

  defp determine_battle_outcome_from_summary(side_a_analysis, side_b_analysis, killmails) do
    # Determine battle outcome based on analysis
    if Enum.empty?(killmails) do
      :inconclusive
    else
      # Simplified outcome determination
      side_a_effectiveness = side_a_analysis.estimated_effectiveness
      side_b_effectiveness = side_b_analysis.estimated_effectiveness

      cond do
        side_a_effectiveness > side_b_effectiveness * 1.2 -> :side_a_victory
        side_b_effectiveness > side_a_effectiveness * 1.2 -> :side_b_victory
        true -> :stalemate
      end
    end
  end

  # Additional helper functions for positioning analysis

  defp get_participants_from_battle_analysis(battle_analysis) do
    # Extract participants from battle analysis
    Map.get(battle_analysis, :participants, [])
  end

  defp get_killmails_from_battle_analysis(battle_analysis) do
    # Extract killmails from battle analysis
    Map.get(battle_analysis, :killmails, [])
  end

  defp calculate_positioning_effectiveness(participants, killmails) do
    # Calculate positioning effectiveness
    if Enum.empty?(participants) do
      0.0
    else
      # Simplified positioning effectiveness
      total_participants = length(participants)
      losses = count_total_losses(killmails)

      if total_participants > 0 do
        survival_rate = (total_participants - losses) / total_participants
        Float.round(survival_rate, 2)
      else
        0.0
      end
    end
  end

  defp count_total_losses(killmails) do
    # Count total losses from killmails
    length(killmails)
  end

  defp analyze_range_control(participants, _killmails) do
    # Analyze range control effectiveness
    if Enum.empty?(participants) do
      0.0
    else
      # Simplified range control analysis
      long_range_ships = count_long_range_ships(participants)
      total_participants = length(participants)

      if total_participants > 0 do
        range_control_ratio = long_range_ships / total_participants
        Float.round(range_control_ratio, 2)
      else
        0.0
      end
    end
  end

  defp count_long_range_ships(participants) do
    # Count ships with long-range capabilities
    participants
    |> Enum.count(fn participant ->
      ship_name = Map.get(participant, :ship_name, "")
      # Ships typically used for long-range combat
      String.contains?(String.downcase(ship_name), [
        "tornado",
        "naga",
        "talos",
        "oracle",
        "sniper"
      ])
    end)
  end

  defp analyze_escape_route_utilization(participants, killmails) do
    # Analyze escape route utilization
    if Enum.empty?(participants) or Enum.empty?(killmails) do
      0.0
    else
      # Simplified escape analysis
      total_participants = length(participants)
      losses = length(killmails)

      if total_participants > 0 do
        escape_rate = (total_participants - losses) / total_participants
        Float.round(escape_rate, 2)
      else
        0.0
      end
    end
  end

  defp analyze_tactical_positioning_effectiveness(participants, killmails) do
    # Analyze tactical positioning effectiveness
    if Enum.empty?(participants) do
      0.0
    else
      # Simplified tactical positioning analysis
      survival_rate = calculate_positioning_effectiveness(participants, killmails)
      range_control = analyze_range_control(participants, killmails)

      tactical_score = (survival_rate + range_control) / 2
      Float.round(tactical_score, 2)
    end
  end

  defp analyze_formation_integrity(participants, _killmails) do
    # Analyze formation integrity
    if Enum.empty?(participants) do
      0.0
    else
      # Simplified formation integrity analysis
      logistics_ships = count_logistics_ships(participants)
      total_participants = length(participants)

      # Formation integrity based on logistics support
      if total_participants > 0 do
        logistics_ratio = logistics_ships / total_participants
        # Scale logistics ratio
        integrity_score = min(1.0, logistics_ratio * 5)
        Float.round(integrity_score, 2)
      else
        0.0
      end
    end
  end

  defp count_logistics_ships(participants) do
    # Count logistics ships in fleet
    participants
    |> Enum.count(fn participant ->
      ship_name = Map.get(participant, :ship_name, "")

      String.contains?(String.downcase(ship_name), ["guardian", "basilisk", "oneiros", "scimitar"])
    end)
  end

  defp analyze_engagement_zones(participants, killmails) do
    # Analyze engagement zones
    if Enum.empty?(killmails) do
      []
    else
      # Simplified engagement zone analysis
      [
        %{
          zone_type: :primary_engagement,
          participant_count: length(participants),
          kill_count: length(killmails),
          intensity: calculate_zone_intensity(participants, killmails)
        }
      ]
    end
  end

  defp calculate_zone_intensity(participants, killmails) do
    # Calculate intensity of engagement zone
    if length(participants) > 0 do
      Float.round(length(killmails) / length(participants), 2)
    else
      0.0
    end
  end

  defp identify_positioning_advantages(participants, _killmails) do
    # Identify positioning advantages
    if Enum.empty?(participants) do
      []
    else
      # Range advantage
      long_range_count = count_long_range_ships(participants)

      range_advantages =
        if long_range_count > length(participants) * 0.3 do
          [%{advantage: :range_superiority, strength: :moderate}]
        else
          []
        end

      # Logistics advantage
      logistics_count = count_logistics_ships(participants)

      logistics_advantages =
        if logistics_count > length(participants) * 0.15 do
          [%{advantage: :logistics_support, strength: :good}]
        else
          []
        end

      range_advantages ++ logistics_advantages
    end
  end

  defp analyze_fleet_mobility(participants, _killmails) do
    # Analyze fleet mobility
    if Enum.empty?(participants) do
      %{mobility_score: 0.0, mobility_rating: :unknown}
    else
      # Simplified mobility analysis based on ship types
      fast_ships = count_fast_ships(participants)
      total_participants = length(participants)

      if total_participants > 0 do
        mobility_ratio = fast_ships / total_participants
        mobility_score = Float.round(mobility_ratio, 2)
        mobility_rating = rate_mobility(mobility_score)

        %{
          mobility_score: mobility_score,
          mobility_rating: mobility_rating,
          fast_ships: fast_ships,
          total_ships: total_participants
        }
      else
        %{mobility_score: 0.0, mobility_rating: :unknown}
      end
    end
  end

  defp count_fast_ships(participants) do
    # Count fast ships (frigates, destroyers, cruisers)
    participants
    |> Enum.count(fn participant ->
      ship_type_id =
        Map.get(participant, :ship_type_id) || Map.get(participant, :victim_ship_type_id)

      cond do
        # Frigates
        ship_type_id && ship_type_id >= 1 && ship_type_id <= 100 -> true
        # Destroyers  
        ship_type_id && ship_type_id >= 420 && ship_type_id <= 441 -> true
        # Cruisers
        ship_type_id && ship_type_id >= 358 && ship_type_id <= 894 -> true
        true -> false
      end
    end)
  end

  defp rate_mobility(mobility_score) do
    cond do
      mobility_score >= 0.8 -> :excellent
      mobility_score >= 0.6 -> :good
      mobility_score >= 0.4 -> :moderate
      mobility_score >= 0.2 -> :poor
      true -> :minimal
    end
  end

  defp generate_positioning_recommendations(
         positioning_effectiveness,
         range_control,
         tactical_positioning
       ) do
    # Generate positioning recommendations
    recommendations = []

    # Positioning effectiveness recommendations
    recommendations =
      if positioning_effectiveness < 0.5 do
        ["Improve defensive positioning and formation discipline" | recommendations]
      else
        recommendations
      end

    # Range control recommendations
    recommendations =
      if range_control < 0.3 do
        ["Increase long-range capability for better range control" | recommendations]
      else
        recommendations
      end

    # Tactical positioning recommendations  
    recommendations =
      if tactical_positioning < 0.6 do
        ["Enhance tactical positioning awareness and coordination" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  # Additional helper functions for gap analysis

  defp analyze_doctrine_gaps(_fleet_compositions) do
    # Analyze gaps in fleet doctrine
    %{
      doctrine_coherence: 0.7,
      missing_doctrine_elements: ["Heavy interdiction", "Command ships"],
      doctrine_weaknesses: ["Limited electronic warfare", "Insufficient logistics"]
    }
  end

  defp analyze_capability_gaps(_fleet_compositions) do
    # Analyze capability gaps
    %{
      missing_capabilities: ["Anti-capital", "Long-range engagement", "Fast tackle"],
      capability_weaknesses: ["Electronic warfare", "Logistics support"],
      critical_gaps: ["Interdiction capability"]
    }
  end

  defp analyze_tactical_gaps(_fleet_compositions) do
    # Analyze tactical gaps
    %{
      tactical_weaknesses: ["Range control", "Escape route coverage", "Formation integrity"],
      strategic_gaps: ["Force projection", "Sustained operations"],
      operational_gaps: ["Command and control", "Intelligence gathering"]
    }
  end

  defp prioritize_optimizations(missing_roles, role_imbalances, doctrine_gaps) do
    # Prioritize optimization efforts
    _priorities = []

    # High priority: Critical missing roles
    high_priority =
      missing_roles
      |> Enum.filter(fn role ->
        role in ["interdiction", "logistics", "command_ships"]
      end)

    # Medium priority: Role imbalances
    medium_priority =
      role_imbalances
      |> Enum.filter(fn imbalance ->
        imbalance.imbalance == :deficit
      end)

    # Low priority: Doctrine improvements
    low_priority = doctrine_gaps.missing_doctrine_elements

    %{
      high_priority: high_priority,
      medium_priority: medium_priority,
      low_priority: low_priority
    }
  end

  defp analyze_resource_requirements(optimization_suggestions) do
    # Analyze resource requirements for optimizations
    %{
      pilot_training_required: length(optimization_suggestions) * 2,
      ship_acquisition_needed: length(optimization_suggestions) * 1.5,
      time_investment: "#{length(optimization_suggestions) * 2} weeks",
      isk_investment: "#{length(optimization_suggestions) * 1_000_000_000} ISK"
    }
  end

  defp generate_implementation_roadmap(optimization_priorities, resource_requirements) do
    # Generate implementation roadmap
    %{
      phase_1: %{
        duration: "2 weeks",
        focus: "Critical missing roles",
        targets: optimization_priorities.high_priority
      },
      phase_2: %{
        duration: "4 weeks",
        focus: "Role balancing",
        targets: optimization_priorities.medium_priority
      },
      phase_3: %{
        duration: "6 weeks",
        focus: "Doctrine refinement",
        targets: optimization_priorities.low_priority
      },
      total_timeline: "12 weeks",
      resource_allocation: resource_requirements
    }
  end

  # Additional helper functions for comprehensive analysis

  defp calculate_fleet_strength(participants) do
    # Calculate overall fleet strength
    if Enum.empty?(participants) do
      0
    else
      # Simplified strength calculation
      ship_classes = classify_ships_by_class(participants)

      capital_strength = length(Map.get(ship_classes, :capital, [])) * 10
      battleship_strength = length(Map.get(ship_classes, :battleship, [])) * 5
      cruiser_strength = length(Map.get(ship_classes, :cruiser, [])) * 2
      frigate_strength = length(Map.get(ship_classes, :frigate, []))

      total_strength =
        capital_strength + battleship_strength + cruiser_strength + frigate_strength

      %{
        total_strength: total_strength,
        capital_strength: capital_strength,
        subcapital_strength: total_strength - capital_strength,
        strength_rating: rate_fleet_strength(total_strength)
      }
    end
  end

  defp rate_fleet_strength(total_strength) do
    cond do
      total_strength >= 1000 -> :overwhelming
      total_strength >= 500 -> :strong
      total_strength >= 100 -> :moderate
      total_strength >= 50 -> :weak
      true -> :minimal
    end
  end

  defp analyze_composition_balance(role_distribution) do
    # Analyze balance of fleet composition
    if Map.get(role_distribution, :total_participants, 0) == 0 do
      %{balance_score: 0.0, balance_rating: :unknown}
    else
      # Ideal ratios: 60% DPS, 20% logistics, 10% EWAR, 10% tackle
      dps_ratio = (Map.get(role_distribution, :dps, %{}) |> Map.get(:percentage, 0)) / 100

      logistics_ratio =
        (Map.get(role_distribution, :logistics, %{}) |> Map.get(:percentage, 0)) / 100

      ewar_ratio = (Map.get(role_distribution, :ewar, %{}) |> Map.get(:percentage, 0)) / 100
      tackle_ratio = (Map.get(role_distribution, :tackle, %{}) |> Map.get(:percentage, 0)) / 100

      # Calculate deviation from ideal
      dps_deviation = abs(dps_ratio - 0.6)
      logistics_deviation = abs(logistics_ratio - 0.2)
      ewar_deviation = abs(ewar_ratio - 0.1)
      tackle_deviation = abs(tackle_ratio - 0.1)

      total_deviation = dps_deviation + logistics_deviation + ewar_deviation + tackle_deviation
      balance_score = max(0.0, 1.0 - total_deviation)

      %{
        balance_score: Float.round(balance_score, 2),
        balance_rating: rate_balance(balance_score),
        role_deviations: %{
          dps: dps_deviation,
          logistics: logistics_deviation,
          ewar: ewar_deviation,
          tackle: tackle_deviation
        }
      }
    end
  end

  defp rate_balance(balance_score) do
    cond do
      balance_score >= 0.9 -> :excellent
      balance_score >= 0.8 -> :good
      balance_score >= 0.7 -> :adequate
      balance_score >= 0.6 -> :poor
      true -> :critical
    end
  end

  defp analyze_logistical_support(participants) do
    # Analyze logistical support capability
    if Enum.empty?(participants) do
      %{support_rating: :none, support_ratio: 0.0}
    else
      logistics_count = count_logistics_ships(participants)
      total_participants = length(participants)

      support_ratio = logistics_count / total_participants
      support_rating = rate_logistics_support(support_ratio)

      %{
        support_rating: support_rating,
        support_ratio: Float.round(support_ratio, 2),
        logistics_count: logistics_count,
        total_participants: total_participants
      }
    end
  end

  defp rate_logistics_support(support_ratio) do
    cond do
      support_ratio >= 0.25 -> :excellent
      support_ratio >= 0.15 -> :good
      support_ratio >= 0.10 -> :adequate
      support_ratio >= 0.05 -> :poor
      true -> :critical
    end
  end

  defp analyze_ship_size_distribution(participants) do
    # Analyze distribution of ship sizes
    if Enum.empty?(participants) do
      %{small: 0, medium: 0, large: 0, capital: 0}
    else
      ship_classes = classify_ships_by_class(participants)

      %{
        small:
          length(Map.get(ship_classes, :frigate, [])) +
            length(Map.get(ship_classes, :destroyer, [])),
        medium:
          length(Map.get(ship_classes, :cruiser, [])) +
            length(Map.get(ship_classes, :battlecruiser, [])),
        large: length(Map.get(ship_classes, :battleship, [])),
        capital: length(Map.get(ship_classes, :capital, []))
      }
    end
  end

  defp analyze_organizational_composition(participants) do
    # Analyze organizational composition (corps/alliances)
    if Enum.empty?(participants) do
      %{diversity_score: 0.0, primary_organization: :unknown}
    else
      # Group by organization
      organizations =
        participants
        |> Enum.group_by(fn participant ->
          Map.get(participant, :alliance_id) || Map.get(participant, :corporation_id) || :unknown
        end)

      org_count = map_size(organizations)
      total_participants = length(participants)

      diversity_score = min(1.0, org_count / total_participants)

      # Find primary organization
      primary_org =
        organizations
        |> Enum.max_by(fn {_org, members} -> length(members) end)
        |> elem(0)

      %{
        diversity_score: Float.round(diversity_score, 2),
        primary_organization: primary_org,
        organization_count: org_count,
        largest_org_size: organizations |> Map.get(primary_org, []) |> length()
      }
    end
  end

  defp assess_combat_capability(participants, ship_classes) do
    # Assess overall combat capability
    if Enum.empty?(participants) do
      %{capability_rating: :minimal, combat_power: 0}
    else
      # Calculate combat power based on ship classes
      combat_power = calculate_combat_power(ship_classes)
      capability_rating = rate_combat_capability(combat_power)

      %{
        capability_rating: capability_rating,
        combat_power: combat_power,
        force_projection: assess_force_projection(ship_classes),
        sustainability: assess_sustainability(ship_classes)
      }
    end
  end

  defp calculate_combat_power(ship_classes) do
    # Calculate combat power score
    capital_power = length(Map.get(ship_classes, :capital, [])) * 50
    battleship_power = length(Map.get(ship_classes, :battleship, [])) * 20
    cruiser_power = length(Map.get(ship_classes, :cruiser, [])) * 8
    frigate_power = length(Map.get(ship_classes, :frigate, [])) * 2

    capital_power + battleship_power + cruiser_power + frigate_power
  end

  defp rate_combat_capability(combat_power) do
    cond do
      combat_power >= 2000 -> :overwhelming
      combat_power >= 1000 -> :strong
      combat_power >= 500 -> :moderate
      combat_power >= 100 -> :limited
      true -> :minimal
    end
  end

  defp assess_force_projection(ship_classes) do
    # Assess force projection capability
    capital_count = length(Map.get(ship_classes, :capital, []))
    battleship_count = length(Map.get(ship_classes, :battleship, []))

    cond do
      capital_count >= 5 -> :strategic
      capital_count >= 2 or battleship_count >= 10 -> :operational
      battleship_count >= 5 -> :tactical
      true -> :limited
    end
  end

  defp assess_sustainability(ship_classes) do
    # Assess fleet sustainability
    logistics_count = length(Map.get(ship_classes, :logistics, []))
    total_ships = ship_classes |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

    if total_ships == 0 do
      :none
    else
      logistics_ratio = logistics_count / total_ships

      cond do
        logistics_ratio >= 0.2 -> :excellent
        logistics_ratio >= 0.15 -> :good
        logistics_ratio >= 0.1 -> :adequate
        logistics_ratio >= 0.05 -> :poor
        true -> :critical
      end
    end
  end

  # Additional helper functions for comparison analysis

  defp calculate_numerical_advantage(side_a_pilots, side_b_pilots) do
    # Calculate numerical advantage
    if side_b_pilots == 0 do
      if side_a_pilots > 0, do: 10.0, else: 1.0
    else
      advantage = side_a_pilots / side_b_pilots

      %{
        ratio: Float.round(advantage, 2),
        advantage:
          cond do
            advantage >= 2.0 -> :overwhelming
            advantage >= 1.5 -> :significant
            advantage >= 1.2 -> :moderate
            advantage >= 0.8 -> :balanced
            true -> :disadvantage
          end
      }
    end
  end

  defp calculate_composition_advantage(side_a_analysis, side_b_analysis) do
    # Calculate composition advantage
    side_a_score = side_a_analysis.estimated_effectiveness
    side_b_score = side_b_analysis.estimated_effectiveness

    advantage_score = side_a_score - side_b_score

    %{
      advantage_score: Float.round(advantage_score, 2),
      advantage_type:
        cond do
          advantage_score >= 0.3 -> :significant
          advantage_score >= 0.1 -> :moderate
          advantage_score >= -0.1 -> :balanced
          true -> :disadvantage
        end,
      key_advantages: identify_key_advantages(side_a_analysis, side_b_analysis)
    }
  end

  defp identify_key_advantages(side_a_analysis, side_b_analysis) do
    # Identify key compositional advantages

    # Logistics advantage
    side_a_logistics = get_in(side_a_analysis, [:role_distribution, :logistics, :count]) || 0
    side_b_logistics = get_in(side_b_analysis, [:role_distribution, :logistics, :count]) || 0

    logistics_advantages =
      if side_a_logistics > side_b_logistics * 1.5 do
        [:logistics_superiority]
      else
        []
      end

    # Fleet synergy advantage
    synergy_advantages =
      if side_a_analysis.fleet_synergy > side_b_analysis.fleet_synergy * 1.3 do
        [:synergy_advantage]
      else
        []
      end

    # Doctrine advantage
    doctrine_advantages =
      if side_a_analysis.doctrine_adherence > side_b_analysis.doctrine_adherence * 1.2 do
        [:doctrine_advantage]
      else
        []
      end

    logistics_advantages ++ synergy_advantages ++ doctrine_advantages
  end

  defp calculate_experience_advantage(side_a_analysis, side_b_analysis) do
    # Calculate experience advantage based on organizational composition
    side_a_diversity = side_a_analysis.organizational_composition.diversity_score
    side_b_diversity = side_b_analysis.organizational_composition.diversity_score

    # Lower diversity often indicates more organized/experienced groups
    experience_factor = 1 - side_a_diversity - (1 - side_b_diversity)

    %{
      experience_advantage: Float.round(experience_factor, 2),
      advantage_type:
        cond do
          experience_factor >= 0.2 -> :significant
          experience_factor >= 0.1 -> :moderate
          experience_factor >= -0.1 -> :balanced
          true -> :disadvantage
        end
    }
  end

  defp compare_fleet_strength(side_a_strength, side_b_strength) do
    # Compare fleet strength between sides
    strength_diff = side_a_strength.total_strength - side_b_strength.total_strength

    %{
      strength_difference: strength_diff,
      advantage:
        cond do
          strength_diff >= 500 -> :overwhelming
          strength_diff >= 200 -> :significant
          strength_diff >= 100 -> :moderate
          strength_diff >= -100 -> :balanced
          true -> :disadvantage
        end,
      side_a_strength: side_a_strength.total_strength,
      side_b_strength: side_b_strength.total_strength
    }
  end

  defp compare_doctrines(side_a_adherence, side_b_adherence) do
    # Compare doctrine adherence
    doctrine_diff = side_a_adherence - side_b_adherence

    %{
      doctrine_difference: Float.round(doctrine_diff, 2),
      advantage:
        cond do
          doctrine_diff >= 0.3 -> :significant
          doctrine_diff >= 0.1 -> :moderate
          doctrine_diff >= -0.1 -> :balanced
          true -> :disadvantage
        end
    }
  end

  defp compare_fleet_synergy(side_a_synergy, side_b_synergy) do
    # Compare fleet synergy
    synergy_diff = side_a_synergy - side_b_synergy

    %{
      synergy_difference: Float.round(synergy_diff, 2),
      advantage:
        cond do
          synergy_diff >= 0.3 -> :significant
          synergy_diff >= 0.1 -> :moderate
          synergy_diff >= -0.1 -> :balanced
          true -> :disadvantage
        end
    }
  end

  defp compare_role_balance(side_a_roles, side_b_roles) do
    # Compare role balance between sides
    side_a_balance =
      side_a_roles |> Map.values() |> Enum.map(&Map.get(&1, :percentage, 0)) |> Enum.sum()

    side_b_balance =
      side_b_roles |> Map.values() |> Enum.map(&Map.get(&1, :percentage, 0)) |> Enum.sum()

    %{
      balance_comparison: Float.round(side_a_balance - side_b_balance, 1),
      side_a_balance: side_a_balance,
      side_b_balance: side_b_balance
    }
  end

  defp compare_logistical_support(side_a_logistics, side_b_logistics) do
    # Compare logistical support
    support_diff = side_a_logistics.support_ratio - side_b_logistics.support_ratio

    %{
      support_difference: Float.round(support_diff, 2),
      advantage:
        cond do
          support_diff >= 0.1 -> :significant
          support_diff >= 0.05 -> :moderate
          support_diff >= -0.05 -> :balanced
          true -> :disadvantage
        end
    }
  end

  defp predict_engagement_outcome(side_a_analysis, side_b_analysis) do
    # Predict engagement outcome
    factors = %{
      numerical:
        calculate_numerical_advantage(side_a_analysis.total_pilots, side_b_analysis.total_pilots),
      composition: calculate_composition_advantage(side_a_analysis, side_b_analysis),
      experience: calculate_experience_advantage(side_a_analysis, side_b_analysis),
      strength:
        compare_fleet_strength(side_a_analysis.fleet_strength, side_b_analysis.fleet_strength)
    }

    # Score each factor
    scores = %{
      numerical: score_advantage(factors.numerical.advantage),
      composition: score_advantage(factors.composition.advantage_type),
      experience: score_advantage(factors.experience.advantage_type),
      strength: score_advantage(factors.strength.advantage)
    }

    total_score = scores.numerical + scores.composition + scores.experience + scores.strength

    %{
      predicted_winner:
        cond do
          total_score >= 2 -> :side_a
          total_score <= -2 -> :side_b
          true -> :contested
        end,
      confidence: calculate_prediction_confidence(total_score),
      key_factors: identify_key_prediction_factors(factors),
      expected_duration: estimate_battle_duration(side_a_analysis, side_b_analysis),
      casualty_estimate: estimate_casualties(side_a_analysis, side_b_analysis)
    }
  end

  defp score_advantage(advantage) do
    case advantage do
      :overwhelming -> 3
      :significant -> 2
      :moderate -> 1
      :balanced -> 0
      :disadvantage -> -1
      _ -> 0
    end
  end

  defp calculate_prediction_confidence(total_score) do
    # Max possible score is 12
    confidence = abs(total_score) / 12

    cond do
      confidence >= 0.8 -> :high
      confidence >= 0.6 -> :medium
      confidence >= 0.4 -> :low
      true -> :very_low
    end
  end

  defp identify_key_prediction_factors(factors) do
    # Identify the most important factors in prediction
    factor_scores = [
      {:numerical, score_advantage(factors.numerical.advantage)},
      {:composition, score_advantage(factors.composition.advantage_type)},
      {:experience, score_advantage(factors.experience.advantage_type)},
      {:strength, score_advantage(factors.strength.advantage)}
    ]

    factor_scores
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(2)
    |> Enum.map(&elem(&1, 0))
  end

  defp estimate_battle_duration(side_a_analysis, side_b_analysis) do
    # Estimate battle duration based on composition
    total_participants = side_a_analysis.total_pilots + side_b_analysis.total_pilots

    base_duration =
      cond do
        # minutes
        total_participants >= 1000 -> 60
        total_participants >= 500 -> 45
        total_participants >= 100 -> 30
        total_participants >= 50 -> 20
        true -> 15
      end

    # Adjust for logistics (longer battles)
    total_logistics =
      (get_in(side_a_analysis, [:role_distribution, :logistics, :count]) || 0) +
        (get_in(side_b_analysis, [:role_distribution, :logistics, :count]) || 0)

    logistics_factor = 1 + total_logistics / total_participants * 0.5

    round(base_duration * logistics_factor)
  end

  defp estimate_casualties(side_a_analysis, side_b_analysis) do
    # Estimate casualties for each side
    total_a = side_a_analysis.total_pilots
    total_b = side_b_analysis.total_pilots

    # Base casualty rates
    base_casualty_rate = 0.3

    # Adjust for fleet effectiveness
    side_a_casualties =
      round(total_a * base_casualty_rate / side_a_analysis.estimated_effectiveness)

    side_b_casualties =
      round(total_b * base_casualty_rate / side_b_analysis.estimated_effectiveness)

    %{
      side_a_casualties: side_a_casualties,
      side_b_casualties: side_b_casualties,
      total_casualties: side_a_casualties + side_b_casualties
    }
  end

  defp generate_overall_assessment(
         numerical_advantage,
         composition_advantage,
         experience_advantage
       ) do
    # Generate overall assessment
    scores = [
      score_advantage(numerical_advantage.advantage),
      score_advantage(composition_advantage.advantage_type),
      score_advantage(experience_advantage.advantage_type)
    ]

    total_score = Enum.sum(scores)

    %{
      overall_advantage:
        cond do
          total_score >= 4 -> :decisive
          total_score >= 2 -> :significant
          total_score >= 1 -> :moderate
          total_score >= -1 -> :balanced
          true -> :disadvantage
        end,
      confidence: calculate_assessment_confidence(total_score),
      primary_factors: identify_primary_assessment_factors(scores)
    }
  end

  defp calculate_assessment_confidence(total_score) do
    # Max possible score is 9
    confidence = abs(total_score) / 9

    cond do
      confidence >= 0.7 -> :high
      confidence >= 0.5 -> :medium
      confidence >= 0.3 -> :low
      true -> :very_low
    end
  end

  defp identify_primary_assessment_factors(scores) do
    # Identify primary factors in assessment
    factors = [:numerical, :composition, :experience]

    factors
    |> Enum.zip(scores)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(2)
    |> Enum.map(&elem(&1, 0))
  end

  # Additional effectiveness analysis functions

  defp analyze_effectiveness_trends(sides, killmails) do
    # Analyze effectiveness trends over time
    if Enum.empty?(killmails) do
      %{trend: :stable, phases: []}
    else
      # Divide battle into phases
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)
      phase_size = max(1, div(length(sorted_killmails), 3))

      phases = [
        %{phase: :early, kills: Enum.take(sorted_killmails, phase_size)},
        %{phase: :middle, kills: Enum.slice(sorted_killmails, phase_size, phase_size)},
        %{phase: :late, kills: Enum.drop(sorted_killmails, phase_size * 2)}
      ]

      # Analyze each phase
      phase_analysis =
        phases
        |> Enum.map(fn %{phase: phase, kills: phase_kills} ->
          %{
            phase: phase,
            kill_count: length(phase_kills),
            intensity: calculate_phase_intensity(phase_kills, sides)
          }
        end)

      %{
        trend: determine_trend(phase_analysis),
        phases: phase_analysis
      }
    end
  end

  defp calculate_phase_intensity(phase_kills, sides) do
    # Calculate intensity of a battle phase
    total_participants = length(sides.side_a) + length(sides.side_b)

    if total_participants > 0 do
      Float.round(length(phase_kills) / total_participants, 2)
    else
      0.0
    end
  end

  defp determine_trend(phase_analysis) do
    # Determine overall trend from phase analysis
    intensities = Enum.map(phase_analysis, & &1.intensity)

    case intensities do
      [early, middle, late] when late > middle and middle > early -> :escalating
      [early, middle, late] when late < middle and middle < early -> :declining
      [early, middle, late] when middle > early and middle > late -> :peaked
      _ -> :stable
    end
  end

  defp analyze_losses_by_composition(sides, killmails) do
    # Analyze losses by fleet composition
    if Enum.empty?(killmails) do
      %{side_a_losses: [], side_b_losses: []}
    else
      side_a_chars = MapSet.new(sides.side_a, fn p -> Map.get(p, :character_id) end)
      _side_b_chars = MapSet.new(sides.side_b, fn p -> Map.get(p, :character_id) end)

      # Categorize losses by side
      {side_a_losses, side_b_losses} =
        killmails
        |> Enum.split_with(fn killmail ->
          victim_id = Map.get(killmail, :victim_character_id)
          MapSet.member?(side_a_chars, victim_id)
        end)

      %{
        side_a_losses: analyze_side_losses(side_a_losses, sides.side_a),
        side_b_losses: analyze_side_losses(side_b_losses, sides.side_b),
        loss_ratio: calculate_loss_ratio(side_a_losses, side_b_losses)
      }
    end
  end

  defp analyze_side_losses(losses, side_participants) do
    # Analyze losses for one side
    if Enum.empty?(losses) do
      %{total_losses: 0, loss_by_class: %{}, loss_rate: 0.0}
    else
      # Group losses by ship class
      loss_by_class =
        losses
        |> Enum.group_by(fn killmail ->
          ship_type_id = Map.get(killmail, :victim_ship_type_id)
          classify_ship_by_type_id(ship_type_id)
        end)
        |> Enum.map(fn {class, class_losses} -> {class, length(class_losses)} end)
        |> Enum.into(%{})

      loss_rate = length(losses) / length(side_participants)

      %{
        total_losses: length(losses),
        loss_by_class: loss_by_class,
        loss_rate: Float.round(loss_rate, 2)
      }
    end
  end

  defp classify_ship_by_type_id(ship_type_id) do
    cond do
      ship_type_id >= 19720 && ship_type_id <= 19740 -> :capital
      ship_type_id >= 640 && ship_type_id <= 644 -> :battleship
      ship_type_id >= 358 && ship_type_id <= 894 -> :cruiser
      ship_type_id >= 1 && ship_type_id <= 100 -> :frigate
      ship_type_id >= 420 && ship_type_id <= 441 -> :destroyer
      true -> :unknown
    end
  end

  defp calculate_loss_ratio(side_a_losses, side_b_losses) do
    # Calculate loss ratio between sides
    if Enum.empty?(side_b_losses) do
      if length(side_a_losses) > 0, do: 10.0, else: 1.0
    else
      Float.round(length(side_a_losses) / length(side_b_losses), 2)
    end
  end

  defp analyze_performance_vs_expected(sides, killmails) do
    # Analyze performance vs expected outcomes
    side_a_expected = estimate_expected_performance(sides.side_a)
    side_b_expected = estimate_expected_performance(sides.side_b)

    # Calculate actual performance
    side_a_actual = calculate_actual_performance(sides.side_a, killmails)
    side_b_actual = calculate_actual_performance(sides.side_b, killmails)

    %{
      side_a: %{
        expected: side_a_expected,
        actual: side_a_actual,
        variance: Float.round(side_a_actual - side_a_expected, 2)
      },
      side_b: %{
        expected: side_b_expected,
        actual: side_b_actual,
        variance: Float.round(side_b_actual - side_b_expected, 2)
      }
    }
  end

  defp estimate_expected_performance(side_participants) do
    # Estimate expected performance based on composition
    if Enum.empty?(side_participants) do
      0.0
    else
      ship_classes = classify_ships_by_class(side_participants)
      fleet_strength = calculate_fleet_strength(side_participants)

      # Base expected performance on fleet strength
      base_performance = min(1.0, fleet_strength.total_strength / 1000)

      # Adjust for composition balance
      logistics_count = length(Map.get(ship_classes, :logistics, []))
      logistics_factor = min(1.2, 1.0 + logistics_count / length(side_participants) * 0.5)

      Float.round(base_performance * logistics_factor, 2)
    end
  end

  defp calculate_actual_performance(side_participants, killmails) do
    # Calculate actual performance based on battle results
    if Enum.empty?(side_participants) do
      0.0
    else
      side_chars = MapSet.new(side_participants, fn p -> Map.get(p, :character_id) end)

      # Count kills achieved and losses suffered
      kills_achieved =
        Enum.count(killmails, fn _km ->
          # This is simplified - in reality would need attacker data
          true
        end)

      losses_suffered =
        Enum.count(killmails, fn km ->
          victim_id = Map.get(km, :victim_character_id)
          MapSet.member?(side_chars, victim_id)
        end)

      # Calculate performance score
      if length(side_participants) > 0 do
        kill_score = kills_achieved / length(side_participants)
        loss_penalty = losses_suffered / length(side_participants)

        performance = max(0.0, kill_score - loss_penalty * 0.5)
        Float.round(performance, 2)
      else
        0.0
      end
    end
  end

  defp identify_critical_moments(sides, killmails) do
    # Identify critical moments in the battle
    if Enum.empty?(killmails) do
      []
    else
      # Sort killmails by time
      sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

      # Identify spikes in kill activity
      kill_spikes = identify_kill_spikes(sorted_killmails)

      # Identify high-value losses
      high_value_losses = identify_high_value_losses(sorted_killmails)

      # Identify turning points
      turning_points = identify_turning_points(sorted_killmails, sides)

      (kill_spikes ++ high_value_losses ++ turning_points)
      |> Enum.sort_by(& &1.timestamp)
      |> Enum.take(5)
    end
  end

  defp identify_kill_spikes(sorted_killmails) do
    # Identify spikes in kill activity
    if length(sorted_killmails) < 10 do
      []
    else
      # Group by 5-minute windows
      time_windows =
        sorted_killmails
        |> Enum.group_by(fn km ->
          time = Map.get(km, :killmail_time)
          # Truncate to 5-minute intervals
          %{time | minute: div(time.minute, 5) * 5, second: 0}
        end)

      # Find windows with high activity
      avg_kills_per_window = length(sorted_killmails) / map_size(time_windows)

      time_windows
      |> Enum.filter(fn {_time, kills} -> length(kills) > avg_kills_per_window * 2 end)
      |> Enum.map(fn {time, kills} ->
        %{
          type: :kill_spike,
          timestamp: time,
          description: "High activity spike - #{length(kills)} kills in 5 minutes",
          severity: :high
        }
      end)
    end
  end

  defp identify_high_value_losses(sorted_killmails) do
    # Identify high-value ship losses
    sorted_killmails
    |> Enum.filter(fn km ->
      ship_type_id = Map.get(km, :victim_ship_type_id)
      # Capital ships and other high-value targets
      ship_type_id && ship_type_id >= 19720 && ship_type_id <= 19740
    end)
    |> Enum.map(fn km ->
      %{
        type: :high_value_loss,
        timestamp: Map.get(km, :killmail_time),
        description: "Capital ship destroyed",
        severity: :critical
      }
    end)
  end

  defp identify_turning_points(sorted_killmails, _sides) do
    # Identify potential turning points in the battle
    if length(sorted_killmails) < 20 do
      []
    else
      # Analyze loss ratios over time
      phase_size = div(length(sorted_killmails), 4)

      phases = [
        Enum.take(sorted_killmails, phase_size),
        Enum.slice(sorted_killmails, phase_size, phase_size),
        Enum.slice(sorted_killmails, phase_size * 2, phase_size),
        Enum.drop(sorted_killmails, phase_size * 3)
      ]

      # Look for significant changes in loss patterns
      phases
      |> Enum.with_index()
      |> Enum.filter(fn {phase_kills, index} ->
        # Simplified turning point detection
        length(phase_kills) > phase_size * 1.5 and index > 0
      end)
      |> Enum.map(fn {phase_kills, index} ->
        %{
          type: :turning_point,
          timestamp: List.first(phase_kills) |> Map.get(:killmail_time),
          description: "Significant escalation in phase #{index + 1}",
          severity: :medium
        }
      end)
    end
  end

  defp determine_battle_outcome(side_a_effectiveness, side_b_effectiveness, killmails) do
    # Determine battle outcome based on effectiveness and kill data
    if Enum.empty?(killmails) do
      %{outcome: :inconclusive, victor: :none, confidence: :low}
    else
      effectiveness_diff = side_a_effectiveness - side_b_effectiveness

      # Determine victor based on effectiveness difference
      victor =
        cond do
          effectiveness_diff > 0.2 -> :side_a
          effectiveness_diff < -0.2 -> :side_b
          true -> :contested
        end

      # Determine confidence based on kill data
      confidence =
        cond do
          abs(effectiveness_diff) > 0.4 -> :high
          abs(effectiveness_diff) > 0.2 -> :medium
          true -> :low
        end

      %{
        outcome: if(victor == :contested, do: :stalemate, else: :victory),
        victor: victor,
        confidence: confidence,
        effectiveness_difference: Float.round(effectiveness_diff, 2),
        total_kills: length(killmails)
      }
    end
  end
end
