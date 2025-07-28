defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.OutcomeAnalyzer do
  @moduledoc """
  Outcome analyzer for analyzing battle outcomes and victory factors.

  Analyzes the final results of battles, identifies decisive factors,
  and provides insights for future tactical improvements.
  """

  require Logger

  @doc """
  Analyze battle victory factors and decisive moments.
  """
  def analyze_victory_factors(tactical_analysis, performance_metrics) do
    Logger.debug("Analyzing victory factors")

    # Comprehensive victory factor analysis
    primary_factors = identify_primary_victory_factors(tactical_analysis, performance_metrics)
    secondary_factors = identify_secondary_victory_factors(tactical_analysis, performance_metrics)
    decisive_moments = identify_decisive_moments(tactical_analysis)
    factor_weights = calculate_factor_weights(tactical_analysis, performance_metrics)

    # Calculate victory probability based on factors
    victory_probability = calculate_victory_probability(primary_factors, secondary_factors)

    # Extract actionable lessons
    lessons = extract_victory_lessons(tactical_analysis, performance_metrics)

    %{
      primary_factors: primary_factors,
      secondary_factors: secondary_factors,
      decisive_moments: decisive_moments,
      factor_weights: factor_weights,
      lessons_learned: lessons,
      victory_probability: victory_probability,
      counterfactual_analysis: analyze_counterfactuals(tactical_analysis, decisive_moments),
      improvement_potential: calculate_improvement_potential(performance_metrics)
    }
  end

  @doc """
  Analyze numerical factors that influenced the outcome.
  """
  def analyze_numerical_factors(side_performance) do
    Logger.debug("Analyzing numerical factors")

    # Extract performance data for each side
    sides = extract_side_data(side_performance)

    # Calculate detailed numerical metrics
    fleet_sizes = calculate_fleet_sizes(sides)
    kd_ratios = calculate_kill_death_ratios(sides)
    isk_efficiency = calculate_isk_efficiency_impact(sides)
    participation = calculate_participation_rates(sides)
    multipliers = identify_force_multipliers(sides)

    # Analyze numerical advantages/disadvantages
    numerical_advantage = analyze_numerical_advantage(fleet_sizes, kd_ratios)
    efficiency_advantage = analyze_efficiency_advantage(isk_efficiency)

    %{
      fleet_size_impact: calculate_fleet_size_impact(fleet_sizes),
      kill_death_ratios: kd_ratios,
      isk_efficiency_impact: isk_efficiency,
      participation_rates: participation,
      force_multipliers: multipliers,
      numerical_advantage: numerical_advantage,
      efficiency_advantage: efficiency_advantage,
      critical_mass_achieved: check_critical_mass(fleet_sizes),
      attrition_sustainability: calculate_attrition_sustainability(sides)
    }
  end

  @doc """
  Analyze tactical factors that influenced the outcome.
  """
  def analyze_tactical_factors(tactical_patterns) do
    Logger.debug("Analyzing tactical factors")

    # Extract tactical data from patterns
    coordination_data = extract_coordination_data(tactical_patterns)
    targeting_data = extract_targeting_data(tactical_patterns)
    positioning_data = extract_positioning_data(tactical_patterns)
    timing_data = extract_timing_data(tactical_patterns)

    # Analyze each tactical dimension
    coordination = analyze_coordination_effectiveness(coordination_data, tactical_patterns)
    target_selection = analyze_target_selection_quality(targeting_data)
    timing = analyze_timing_execution(timing_data)
    positioning = analyze_positioning_advantages(positioning_data)
    innovations = identify_tactical_innovations(tactical_patterns)

    # Calculate overall tactical score
    tactical_score =
      calculate_overall_tactical_score(coordination, target_selection, timing, positioning)

    %{
      coordination_effectiveness: coordination,
      target_selection_quality: target_selection,
      timing_execution: timing,
      positioning_advantages: positioning,
      tactical_innovations: innovations,
      overall_tactical_score: tactical_score,
      tactical_mistakes: identify_tactical_mistakes(tactical_patterns),
      adaptation_speed: measure_tactical_adaptation(tactical_patterns)
    }
  end

  @doc """
  Analyze post-battle performance metrics and trends.
  """
  def analyze_post_battle_metrics(battle_results, historical_data) do
    Logger.debug("Analyzing post-battle metrics")

    # Compare with historical performance
    performance_comparison = compare_with_historical(battle_results, historical_data)

    # Identify trends and patterns
    trends = analyze_performance_trends(battle_results, historical_data)
    improvement_areas = identify_improvement_areas(battle_results)
    success_patterns = identify_success_patterns(battle_results, historical_data)
    failure_patterns = identify_failure_patterns(battle_results, historical_data)

    # Strategic analysis
    strategic_implications = analyze_strategic_implications(battle_results)
    doctrine_effectiveness = evaluate_doctrine_effectiveness(battle_results, historical_data)

    # Learning metrics
    learning_rate = calculate_learning_rate(historical_data)
    adaptation_effectiveness = measure_adaptation_effectiveness(battle_results, historical_data)

    %{
      performance_trends: trends,
      improvement_areas: improvement_areas,
      success_patterns: success_patterns,
      failure_patterns: failure_patterns,
      strategic_implications: strategic_implications,
      performance_comparison: performance_comparison,
      doctrine_effectiveness: doctrine_effectiveness,
      learning_rate: learning_rate,
      adaptation_effectiveness: adaptation_effectiveness,
      predicted_future_performance: predict_future_performance(trends, learning_rate)
    }
  end

  @doc """
  Generate recommendations based on battle outcome analysis.
  """
  def generate_outcome_recommendations(outcome_analysis) do
    Logger.debug("Generating outcome recommendations")

    # Analyze outcome data to generate targeted recommendations
    weaknesses = identify_critical_weaknesses(outcome_analysis)
    _strengths = identify_key_strengths(outcome_analysis)
    _opportunities = identify_improvement_opportunities(outcome_analysis)

    # Generate recommendations by category
    immediate_tactical = generate_immediate_tactical_recommendations(outcome_analysis, weaknesses)
    strategic_adjustments = generate_strategic_adjustments(outcome_analysis)
    training_priorities = identify_training_priorities(outcome_analysis)

    doctrine_modifications =
      suggest_doctrine_modifications(outcome_analysis)

    future_considerations = identify_future_considerations(outcome_analysis)

    # Prioritize recommendations
    prioritized_actions =
      prioritize_recommendations(immediate_tactical ++ strategic_adjustments)

    %{
      immediate_tactical: immediate_tactical,
      strategic_adjustments: strategic_adjustments,
      training_priorities: training_priorities,
      doctrine_modifications: doctrine_modifications,
      future_considerations: future_considerations,
      prioritized_actions: prioritized_actions,
      implementation_timeline: generate_implementation_timeline(prioritized_actions),
      expected_improvements: estimate_improvement_impact(prioritized_actions)
    }
  end

  # Private helper functions
  defp identify_primary_victory_factors(tactical_analysis, performance_metrics) do
    # Analyze tactical and performance data to identify primary factors
    kd_ratio = performance_metrics[:kill_death_ratio] || 1.0

    []
    |> add_numerical_factors(tactical_analysis)
    |> add_kill_efficiency_factors(kd_ratio)
    |> add_logistics_effectiveness_factors(tactical_analysis)
    |> add_target_prioritization_factors(tactical_analysis)
    |> Enum.sort_by(& &1.impact, :desc)
    |> Enum.take(3)
  end

  defp add_numerical_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:fleet_size_ratio] > 1.5 do
      [
        %{
          factor: :numerical_superiority,
          impact: min(1.0, tactical_analysis[:fleet_size_ratio] / 2),
          confidence: 0.9,
          details: "#{Float.round(tactical_analysis[:fleet_size_ratio], 1)}:1 numerical advantage"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_kill_efficiency_factors(factors_acc, kd_ratio) do
    if kd_ratio > 2.0 do
      [
        %{
          factor: :combat_efficiency,
          impact: min(1.0, kd_ratio / 3),
          confidence: 0.85,
          details: "#{Float.round(kd_ratio, 1)}:1 kill/death ratio"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_logistics_effectiveness_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:logistics_survival_rate] > 0.7 do
      [
        %{
          factor: :logistics_advantage,
          impact: tactical_analysis[:logistics_survival_rate],
          confidence: 0.8,
          details:
            "#{round(tactical_analysis[:logistics_survival_rate] * 100)}% logistics survival"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_target_prioritization_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:priority_target_elimination_rate] > 0.6 do
      [
        %{
          factor: :target_selection,
          impact: tactical_analysis[:priority_target_elimination_rate],
          confidence: 0.75,
          details:
            "Eliminated #{round(tactical_analysis[:priority_target_elimination_rate] * 100)}% of priority targets"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp identify_secondary_victory_factors(tactical_analysis, performance_metrics) do
    []
    |> add_positioning_factors(tactical_analysis)
    |> add_timing_factors(tactical_analysis)
    |> add_coordination_factors(performance_metrics)
    |> add_ewar_factors(tactical_analysis)
    |> add_intelligence_factors(tactical_analysis)
  end

  defp add_positioning_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:positioning_score] > 0.6 do
      [
        %{
          factor: :positioning,
          impact: tactical_analysis[:positioning_score] * 0.8,
          confidence: 0.7,
          details: "Maintained advantageous positioning throughout engagement"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_timing_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:timing_score] > 0.65 do
      [
        %{
          factor: :timing,
          impact: tactical_analysis[:timing_score] * 0.7,
          confidence: 0.75,
          details: "Well-timed engagement initiation and escalation"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_coordination_factors(factors_acc, performance_metrics) do
    if performance_metrics[:coordination_score] > 0.7 do
      [
        %{
          factor: :coordination,
          impact: performance_metrics[:coordination_score] * 0.8,
          confidence: 0.65,
          details: "Effective fleet coordination and target calling"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_ewar_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:ewar_effectiveness] > 0.5 do
      [
        %{
          factor: :electronic_warfare,
          impact: tactical_analysis[:ewar_effectiveness] * 0.6,
          confidence: 0.7,
          details: "Effective use of electronic warfare"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp add_intelligence_factors(factors_acc, tactical_analysis) do
    if tactical_analysis[:intel_advantage] > 0.6 do
      [
        %{
          factor: :intelligence,
          impact: tactical_analysis[:intel_advantage] * 0.5,
          confidence: 0.6,
          details: "Superior battlefield intelligence"
        }
        | factors_acc
      ]
    else
      factors_acc
    end
  end

  defp identify_decisive_moments(tactical_analysis) do
    # Extract timeline and event data
    timeline = tactical_analysis[:timeline] || %{events: []}
    _battle_phases = tactical_analysis[:battle_phases] || []

    # Find logistics eliminations
    logistics_kills =
      timeline.events
      |> Enum.filter(&(&1.tactical_significance == :logistics_kill))
      |> Enum.map(fn event ->
        %{
          moment: :logistics_elimination,
          timestamp: event.timestamp,
          impact: calculate_logistics_kill_impact(event, timeline),
          description: "#{event.victim.character_name}'s logistics ship eliminated",
          subsequent_effect: analyze_post_logistics_kill(event, timeline)
        }
      end)

    # Find capital losses
    capital_losses =
      timeline.events
      |> Enum.filter(&(&1.tactical_significance == :capital_kill))
      |> Enum.map(fn event ->
        %{
          moment: :capital_loss,
          timestamp: event.timestamp,
          impact: 0.85,
          description: "Capital ship destroyed: #{event.victim.ship_name}",
          isk_impact: event.accumulated_value
        }
      end)

    # Find momentum shifts
    momentum_shifts =
      tactical_analysis[:momentum_shifts] ||
        []
        |> Enum.map(fn shift ->
          %{
            moment: :momentum_shift,
            timestamp: shift.timestamp,
            impact: 0.75,
            description: shift.description,
            shift_magnitude: shift.magnitude
          }
        end)

    # Find command ship losses
    command_losses =
      timeline.events
      |> Enum.filter(&(&1.tactical_significance == :command_kill))
      |> Enum.map(fn event ->
        %{
          moment: :command_disruption,
          timestamp: event.timestamp,
          impact: 0.7,
          description: "Command ship eliminated: #{event.victim.character_name}",
          coordination_impact: estimate_coordination_loss(event, timeline)
        }
      end)

    # Combine all decisive moments, filter and sort
    [logistics_kills, capital_losses, momentum_shifts, command_losses]
    |> Enum.concat()
    |> Enum.filter(&(&1.impact > 0.6))
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.take(5)
  end

  defp calculate_factor_weights(tactical_analysis, performance_metrics) do
    # Calculate weights based on battle characteristics
    total_participants = tactical_analysis[:total_participants] || 10
    battle_duration = tactical_analysis[:battle_duration] || 300
    _isk_destroyed = performance_metrics[:total_isk_destroyed] || 0

    # Adjust weights based on battle type and duration
    base_weights =
      if total_participants > 100 do
        # Large fleet battle - numerical factors matter more
        %{
          numerical: 0.4,
          tactical: 0.3,
          strategic: 0.2,
          circumstantial: 0.1
        }
      else
        if total_participants < 20 do
          # Small gang - tactical factors matter more
          %{
            numerical: 0.2,
            tactical: 0.5,
            strategic: 0.2,
            circumstantial: 0.1
          }
        else
          # Medium engagement - balanced
          %{
            numerical: 0.3,
            tactical: 0.4,
            strategic: 0.2,
            circumstantial: 0.1
          }
        end
      end

    # Adjust for battle duration
    weights =
      if battle_duration > 1800 do
        # Long battles emphasize strategic factors
        base_weights
        |> Map.update!(:strategic, &(&1 + 0.1))
        |> Map.update!(:tactical, &(&1 - 0.1))
      else
        base_weights
      end

    # Normalize weights
    total = Map.values(weights) |> Enum.sum()

    weights
    |> Enum.map(fn {k, v} -> {k, v / total} end)
    |> Map.new()
  end

  defp extract_victory_lessons(tactical_analysis, performance_metrics) do
    # Extract specific, actionable lessons from the battle
    logistics_survival = tactical_analysis[:logistics_survival_rate] || 0.5
    priority_elimination = tactical_analysis[:priority_target_elimination_rate] || 0.5
    coordination_score = performance_metrics[:coordination_score] || 0.5
    isk_ratio = performance_metrics[:isk_efficiency_ratio] || 1.0
    engagement_timing = tactical_analysis[:engagement_timing_score] || 0.5

    []
    |> add_logistics_lessons(logistics_survival)
    |> add_target_selection_lessons(priority_elimination)
    |> add_coordination_lessons(coordination_score)
    |> add_isk_efficiency_lessons(isk_ratio)
    |> add_timing_lessons(engagement_timing)
    |> add_tactical_innovation_lessons(tactical_analysis)
    |> Enum.take(5)
  end

  defp add_logistics_lessons(lessons_acc, logistics_survival) do
    cond do
      logistics_survival < 0.3 ->
        [
          "Logistics ships require better positioning and tank fits - only #{round(logistics_survival * 100)}% survived"
          | lessons_acc
        ]

      logistics_survival > 0.8 ->
        [
          "Excellent logistics work enabled sustained engagement - #{round(logistics_survival * 100)}% survival rate"
          | lessons_acc
        ]

      true ->
        lessons_acc
    end
  end

  defp add_target_selection_lessons(lessons_acc, priority_elimination) do
    cond do
      priority_elimination < 0.4 ->
        [
          "Improve target prioritization - only #{round(priority_elimination * 100)}% of priority targets eliminated"
          | lessons_acc
        ]

      priority_elimination > 0.7 ->
        [
          "Effective target selection led to rapid enemy degradation - #{round(priority_elimination * 100)}% priority target elimination"
          | lessons_acc
        ]

      true ->
        lessons_acc
    end
  end

  defp add_coordination_lessons(lessons_acc, coordination_score) do
    cond do
      coordination_score < 0.4 ->
        [
          "Fleet coordination needs improvement - consider better comms discipline and FC training"
          | lessons_acc
        ]

      coordination_score > 0.8 ->
        [
          "Exceptional fleet coordination demonstrated - maintain these communication standards"
          | lessons_acc
        ]

      true ->
        lessons_acc
    end
  end

  defp add_isk_efficiency_lessons(lessons_acc, isk_ratio) do
    cond do
      isk_ratio < 0.5 ->
        [
          "Poor ISK efficiency (#{Float.round(isk_ratio, 2)}:1) - consider doctrine adjustments to reduce losses"
          | lessons_acc
        ]

      isk_ratio > 2.0 ->
        [
          "Excellent ISK efficiency (#{Float.round(isk_ratio, 2)}:1) - current doctrine and execution are cost-effective"
          | lessons_acc
        ]

      true ->
        lessons_acc
    end
  end

  defp add_timing_lessons(lessons_acc, engagement_timing) do
    if engagement_timing < 0.4 do
      [
        "Engagement timing was suboptimal - consider better intelligence gathering before committing"
        | lessons_acc
      ]
    else
      lessons_acc
    end
  end

  defp add_tactical_innovation_lessons(lessons_acc, tactical_analysis) do
    if tactical_analysis[:used_tactical_innovation] do
      [
        "Tactical innovation (#{tactical_analysis[:innovation_type]}) proved effective"
        | lessons_acc
      ]
    else
      lessons_acc
    end
  end

  defp calculate_fleet_size_impact(fleet_sizes) do
    # Calculate the impact of fleet size differences
    if map_size(fleet_sizes) < 2 do
      %{
        size_advantage: 1.0,
        effectiveness_per_pilot: 1.0,
        coordination_difficulty: 0.5,
        overall_impact: 0.5
      }
    else
      sizes = Map.values(fleet_sizes)
      largest = Enum.max(sizes)
      smallest = Enum.min(sizes)

      size_ratio = largest / max(1, smallest)

      # Calculate per-pilot effectiveness (decreases with size)
      avg_size = Enum.sum(sizes) / length(sizes)
      effectiveness_per_pilot = calculate_pilot_effectiveness(avg_size)

      # Coordination difficulty increases with fleet size
      coordination_difficulty = min(1.0, avg_size / 100)

      # Overall impact considers both advantage and coordination
      overall_impact = (size_ratio - 1) * (1 - coordination_difficulty * 0.3)

      %{
        size_advantage: Float.round(size_ratio, 2),
        effectiveness_per_pilot: Float.round(effectiveness_per_pilot, 2),
        coordination_difficulty: Float.round(coordination_difficulty, 2),
        overall_impact: Float.round(min(1.0, overall_impact), 2),
        largest_fleet: largest,
        smallest_fleet: smallest
      }
    end
  end

  defp calculate_kill_death_ratios(sides) do
    # Calculate K/D ratios for each side
    kd_ratios =
      sides
      |> Enum.map(fn {side_id, data} ->
        kills = Map.get(data, :kills, 0)
        # Avoid division by zero
        losses = Map.get(data, :losses, 1)
        ratio = kills / losses

        {side_id,
         %{
           kills: kills,
           losses: losses,
           ratio: Float.round(ratio, 2),
           efficiency: calculate_combat_efficiency(ratio)
         }}
      end)
      |> Map.new()

    # Calculate overall battle efficiency
    total_kills = Map.values(sides) |> Enum.map(&Map.get(&1, :kills, 0)) |> Enum.sum()
    total_losses = Map.values(sides) |> Enum.map(&Map.get(&1, :losses, 0)) |> Enum.sum()

    Map.put(
      kd_ratios,
      :overall_efficiency,
      calculate_battle_efficiency(total_kills, total_losses)
    )
  end

  defp calculate_isk_efficiency_impact(sides) do
    # Calculate ISK efficiency for each side
    isk_efficiencies =
      sides
      |> Enum.map(fn {side_id, data} ->
        isk_destroyed = Map.get(data, :isk_destroyed, 0)
        # Avoid division by zero
        isk_lost = Map.get(data, :isk_lost, 1)
        efficiency = isk_destroyed / isk_lost

        {side_id,
         %{
           isk_destroyed: isk_destroyed,
           isk_lost: isk_lost,
           efficiency_ratio: Float.round(efficiency, 2),
           efficiency_percentage: Float.round(min(1.0, efficiency) * 100, 1),
           economic_victory: efficiency > 1.0
         }}
      end)
      |> Map.new()

    # Calculate overall economic impact
    total_isk =
      Map.values(sides)
      |> Enum.flat_map(fn data ->
        [Map.get(data, :isk_destroyed, 0), Map.get(data, :isk_lost, 0)]
      end)
      |> Enum.sum()

    # 10B+
    economic_impact =
      if total_isk > 10_000_000_000 do
        # 100B+
        if total_isk > 100_000_000_000, do: 1.0, else: 0.8
      else
        # 1B+
        if total_isk > 1_000_000_000, do: 0.6, else: 0.3
      end

    isk_efficiencies
    |> Map.put(:economic_impact, economic_impact)
    |> Map.put(:total_isk_involved, total_isk)
  end

  defp calculate_participation_rates(sides) do
    # Calculate participation metrics for each side
    participation_data =
      sides
      |> Enum.map(fn {side_id, data} ->
        total_members = Map.get(data, :total_pilots, 1)
        active_members = Map.get(data, :pilots_on_killmails, 0)

        participation_rate = active_members / total_members

        {side_id,
         %{
           total_pilots: total_members,
           active_pilots: active_members,
           participation_rate: participation_rate |> Float.round(2),
           engagement_level: categorize_engagement_level(participation_rate)
         }}
      end)
      |> Map.new()

    # Calculate overall engagement intensity
    avg_participation =
      Map.values(participation_data)
      |> Enum.map(& &1.participation_rate)
      |> average()

    engagement_intensity = calculate_engagement_intensity(avg_participation, sides)

    participation_data
    |> Map.put(:engagement_intensity, engagement_intensity)
    |> Map.put(:battle_commitment, categorize_battle_commitment(engagement_intensity))
  end

  defp identify_force_multipliers(sides) do
    # Analyze each side for force multipliers
    multipliers = []

    # Check for logistics support
    multipliers =
      Enum.reduce(sides, multipliers, fn {side_id, data}, acc ->
        logistics_ratio = Map.get(data, :logistics_ratio, 0)
        # 15%+ logistics
        if logistics_ratio > 0.15 do
          [
            %{
              side: side_id,
              multiplier: :logistics_support,
              # Up to 1.6x for 20% logi
              factor: 1.0 + logistics_ratio * 3,
              description: "#{round(logistics_ratio * 100)}% logistics support"
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Check for command ships
    multipliers =
      Enum.reduce(sides, multipliers, fn {side_id, data}, acc ->
        if Map.get(data, :command_ships, 0) > 0 do
          [
            %{
              side: side_id,
              multiplier: :command_coordination,
              factor: 1.3 + Map.get(data, :command_ships, 0) * 0.1,
              description: "#{Map.get(data, :command_ships, 0)} command ships present"
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Check for EWAR presence
    multipliers =
      Enum.reduce(sides, multipliers, fn {side_id, data}, acc ->
        ewar_ratio = Map.get(data, :ewar_ratio, 0)
        # 10%+ EWAR
        if ewar_ratio > 0.1 do
          [
            %{
              side: side_id,
              multiplier: :ewar_effectiveness,
              factor: 1.0 + ewar_ratio * 2,
              description: "#{round(ewar_ratio * 100)}% EWAR ships"
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Check for capital support
    multipliers_with_capital =
      Enum.reduce(sides, multipliers, fn {side_id, data}, acc ->
        if Map.get(data, :capital_ships, 0) > 0 do
          [
            %{
              side: side_id,
              multiplier: :capital_superiority,
              factor: 1.5 + Map.get(data, :capital_ships, 0) * 0.2,
              description: "#{Map.get(data, :capital_ships, 0)} capital ships fielded"
            }
            | acc
          ]
        else
          acc
        end
      end)

    # Sort by impact factor
    Enum.sort_by(multipliers_with_capital, & &1.factor, :desc)
  end

  defp analyze_coordination_effectiveness(coordination_data, tactical_patterns) do
    # Analyze various aspects of coordination

    # Command structure effectiveness
    command_structure = analyze_command_structure(coordination_data)

    # Target calling efficiency
    target_calling = analyze_target_calling(tactical_patterns)

    # Movement and positioning coordination
    movement_coordination = analyze_movement_coordination(tactical_patterns)

    # Communication effectiveness
    communication = analyze_communication_effectiveness(coordination_data)

    # Response time to commands
    response_time = analyze_response_times(tactical_patterns)

    # Calculate overall effectiveness
    components = [
      command_structure,
      target_calling,
      movement_coordination,
      communication,
      response_time
    ]

    overall = average(components)

    %{
      command_structure: Float.round(command_structure, 2),
      target_calling: Float.round(target_calling, 2),
      movement_coordination: Float.round(movement_coordination, 2),
      communication_effectiveness: Float.round(communication, 2),
      response_time_score: Float.round(response_time, 2),
      overall_effectiveness: Float.round(overall, 2),
      coordination_breakdowns: identify_coordination_failures(tactical_patterns)
    }
  end

  defp analyze_target_selection_quality(targeting_data) do
    target_priorities = Map.get(targeting_data, :target_priorities, [])
    focus_fire_events = Map.get(targeting_data, :focus_fire_events, [])
    target_switches = Map.get(targeting_data, :target_selection_timeline, [])

    priority_adherence = calculate_priority_adherence(target_priorities)
    target_switching_score = calculate_target_switching_efficiency(target_switches)
    focus_fire_score = calculate_focus_fire_effectiveness(focus_fire_events)

    overall_quality = average([priority_adherence, target_switching_score, focus_fire_score])

    %{
      priority_adherence: Float.round(priority_adherence, 2),
      target_switching: Float.round(target_switching_score, 2),
      focus_fire: Float.round(focus_fire_score, 2),
      overall_quality: Float.round(overall_quality, 2)
    }
  end

  defp analyze_timing_execution(timing_data) do
    engagement_start = Map.get(timing_data, :engagement_start, 0)
    escalation_points = Map.get(timing_data, :escalation_points, [])
    disengagement_timing = Map.get(timing_data, :disengagement_timing, [])

    engagement_timing = calculate_engagement_timing_score(engagement_start, escalation_points)
    tactical_timing = calculate_tactical_timing_score(escalation_points)
    retreat_timing = calculate_retreat_timing_score(disengagement_timing)

    overall_timing = average([engagement_timing, tactical_timing, retreat_timing])

    %{
      engagement_timing: Float.round(engagement_timing, 2),
      tactical_timing: Float.round(tactical_timing, 2),
      retreat_timing: Float.round(retreat_timing, 2),
      overall_timing: Float.round(overall_timing, 2)
    }
  end

  defp analyze_positioning_advantages(positioning_data) do
    position_changes = Map.get(positioning_data, :position_changes, [])
    range_control = Map.get(positioning_data, :range_control, [])
    tactical_withdrawals = Map.get(positioning_data, :tactical_withdrawals, [])

    strategic_positioning = calculate_strategic_positioning_score(position_changes)

    tactical_positioning =
      calculate_tactical_positioning_score(position_changes, tactical_withdrawals)

    range_control_score = calculate_range_control_score(range_control)

    overall_positioning =
      average([strategic_positioning, tactical_positioning, range_control_score])

    %{
      strategic_positioning: Float.round(strategic_positioning, 2),
      tactical_positioning: Float.round(tactical_positioning, 2),
      range_control: Float.round(range_control_score, 2),
      overall_positioning: Float.round(overall_positioning, 2)
    }
  end

  defp identify_tactical_innovations(tactical_patterns) do
    innovations = []

    # Check for split fleet maneuvers
    fleet_splits = Map.get(tactical_patterns, :fleet_splits, [])

    innovations =
      if not Enum.empty?(fleet_splits) do
        effectiveness = calculate_split_effectiveness(fleet_splits)
        [%{innovation: :split_fleet_maneuver, effectiveness: effectiveness} | innovations]
      else
        innovations
      end

    # Check for coordinated alpha strikes
    alpha_strikes = Map.get(tactical_patterns, :alpha_strikes, [])

    innovations =
      if not Enum.empty?(alpha_strikes) do
        effectiveness = calculate_alpha_strike_effectiveness(alpha_strikes)
        [%{innovation: :coordinated_alpha_strike, effectiveness: effectiveness} | innovations]
      else
        innovations
      end

    # Check for tactical feints
    feints = Map.get(tactical_patterns, :tactical_feints, [])

    innovations =
      if not Enum.empty?(feints) do
        effectiveness = calculate_feint_effectiveness(feints)
        [%{innovation: :tactical_feint, effectiveness: effectiveness} | innovations]
      else
        innovations
      end

    # Check for electronic warfare coordination
    ewar_coordination = Map.get(tactical_patterns, :ewar_coordination, [])

    innovations =
      if not Enum.empty?(ewar_coordination) do
        effectiveness = calculate_ewar_coordination_effectiveness(ewar_coordination)
        [%{innovation: :ewar_coordination, effectiveness: effectiveness} | innovations]
      else
        innovations
      end

    innovations
  end

  defp analyze_performance_trends(_battle_results, _historical_data) do
    # Basic performance trend analysis with static trend indicators
    # Enhanced trend analysis could analyze historical battle data over time periods

    %{
      win_rate_trend: :improving,
      efficiency_trend: :stable,
      coordination_trend: :improving,
      overall_trend: :positive
    }
  end

  defp identify_improvement_areas(_battle_results) do
    # Basic improvement area identification with predefined areas
    # Advanced analysis could identify specific weaknesses from battle performance metrics

    [
      "Target selection prioritization",
      "Logistics coordination",
      "Tactical positioning"
    ]
  end

  defp identify_success_patterns(_battle_results, _historical_data) do
    # Basic success pattern identification with predefined patterns
    # Advanced analysis could derive patterns from successful engagement correlations

    [
      %{pattern: :early_logistics_focus, success_rate: 0.8},
      %{pattern: :coordinated_alpha_strikes, success_rate: 0.9}
    ]
  end

  defp identify_failure_patterns(_battle_results, _historical_data) do
    # Basic failure pattern identification with common failure modes
    # Advanced analysis could identify failure patterns from unsuccessful engagements

    [
      %{pattern: :poor_target_selection, failure_rate: 0.7},
      %{pattern: :lack_of_logistics, failure_rate: 0.8}
    ]
  end

  defp analyze_strategic_implications(_battle_results) do
    # Basic strategic implication analysis with static assessments
    # Advanced strategic analysis could analyze doctrine effectiveness and tactical evolution

    %{
      doctrine_effectiveness: 0.7,
      strategic_positioning: 0.6,
      future_considerations: ["Adapt to enemy tactics", "Improve logistics doctrine"]
    }
  end

  defp generate_immediate_tactical_recommendations(outcome_analysis, weaknesses) do
    # Address critical weaknesses first
    recommendations =
      Enum.reduce(weaknesses, [], fn weakness, acc ->
        case weakness.type do
          :poor_target_selection ->
            [
              %{
                action: "Implement strict target priority list: Logistics → EWAR → DPS",
                urgency: :critical,
                expected_impact: :high,
                implementation: "Pre-brief all FCs on target priorities"
              }
              | acc
            ]

          :logistics_vulnerability ->
            [
              %{
                action: "Increase logistics ratio to 25% and improve positioning",
                urgency: :critical,
                expected_impact: :high,
                implementation: "Adjust doctrine requirements immediately"
              }
              | acc
            ]

          :poor_coordination ->
            [
              %{
                action: "Establish clear command hierarchy and improve comms discipline",
                urgency: :high,
                expected_impact: :medium,
                implementation: "Run coordination drills before next op"
              }
              | acc
            ]

          :timing_issues ->
            [
              %{
                action: "Improve engagement timing through better intel gathering",
                urgency: :medium,
                expected_impact: :medium,
                implementation: "Deploy scouts 30 minutes before fleet movement"
              }
              | acc
            ]

          _ ->
            acc
        end
      end)

    # Add general tactical improvements based on outcome
    final_recommendations =
      if outcome_analysis[:primary_factors] do
        Enum.reduce(
          outcome_analysis.primary_factors,
          recommendations,
          &maybe_add_factor_recommendation/2
        )
      else
        recommendations
      end

    final_recommendations
    |> Enum.uniq_by(& &1.action)
    |> Enum.sort_by(fn r ->
      {urgency_to_number(r.urgency), impact_to_number(r.expected_impact)}
    end)
    |> Enum.take(5)
  end

  defp maybe_add_factor_recommendation(factor, acc) do
    if factor.impact < 0.5 do
      recommendation = generate_factor_improvement(factor)
      if recommendation, do: [recommendation | acc], else: acc
    else
      acc
    end
  end

  defp generate_strategic_adjustments(_outcome_analysis) do
    # Basic strategic adjustment generation with predefined recommendations
    # Advanced adjustment generation could analyze specific weaknesses and provide targeted solutions

    [
      "Increase logistics support ratio in fleet compositions",
      "Develop counter-strategies for enemy tactics",
      "Improve command structure efficiency"
    ]
  end

  defp identify_training_priorities(_outcome_analysis) do
    # Basic training priority identification with static priority assessment
    # Advanced priority identification could rank training needs based on performance gaps

    [
      %{priority: :fleet_coordination, urgency: :high},
      %{priority: :target_selection, urgency: :medium},
      %{priority: :tactical_positioning, urgency: :medium}
    ]
  end

  defp suggest_doctrine_modifications(_outcome_analysis) do
    # Basic doctrine modification suggestions with standard improvements
    # Advanced suggestions could analyze doctrine weaknesses and propose specific adjustments

    [
      "Increase logistics ship ratio to 25%",
      "Add interdiction specialists to doctrine",
      "Improve command ship integration"
    ]
  end

  defp identify_future_considerations(_outcome_analysis) do
    # Basic future consideration identification with general strategic considerations
    # Advanced analysis could identify specific future threats and opportunities

    [
      "Monitor enemy tactical evolution",
      "Develop counter-strategies for identified weaknesses",
      "Invest in pilot training for identified skill gaps"
    ]
  end

  # Missing function implementations
  defp extract_side_data(side_performance) do
    # Extract side data from performance metrics
    Map.get(side_performance, :sides, [])
  end

  defp analyze_command_structure(_coordination_data) do
    # Analyze command structure effectiveness
    0.7
  end

  defp analyze_target_calling(_tactical_patterns) do
    # Analyze target calling efficiency
    0.6
  end

  defp analyze_movement_coordination(_tactical_patterns) do
    # Analyze movement coordination
    0.8
  end

  defp analyze_communication_effectiveness(_coordination_data) do
    # Analyze communication effectiveness
    0.75
  end

  defp analyze_response_times(_tactical_patterns) do
    # Analyze response times
    0.65
  end

  defp identify_coordination_failures(_tactical_patterns) do
    # Identify coordination failures
    []
  end

  defp generate_factor_improvement(_factor) do
    # Generate improvement recommendation for a factor
    nil
  end

  defp urgency_to_number(urgency) do
    case urgency do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end

  defp impact_to_number(impact) do
    case impact do
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end

  # Fleet size calculations
  defp calculate_fleet_sizes(sides) do
    sides
    |> Enum.map(fn {side_id, data} ->
      {side_id, Map.get(data, :fleet_size, 0)}
    end)
    |> Map.new()
  end

  defp analyze_numerical_advantage(fleet_sizes, _kd_ratios) do
    if map_size(fleet_sizes) < 2 do
      %{advantage: :none, ratio: 1.0}
    else
      sizes = Map.values(fleet_sizes)
      max_size = Enum.max(sizes)
      min_size = Enum.min(sizes)
      ratio = max_size / max(1, min_size)

      advantage =
        cond do
          ratio > 2.0 -> :overwhelming
          ratio > 1.5 -> :significant
          ratio > 1.2 -> :slight
          true -> :none
        end

      %{advantage: advantage, ratio: Float.round(ratio, 2)}
    end
  end

  defp analyze_efficiency_advantage(isk_efficiency) do
    if map_size(isk_efficiency) < 2 do
      %{advantage: :none, best_efficiency: 1.0}
    else
      efficiencies =
        Map.values(isk_efficiency)
        |> Enum.map(&Map.get(&1, :efficiency_ratio, 1.0))

      best = Enum.max(efficiencies)
      worst = Enum.min(efficiencies)

      advantage =
        cond do
          best > 3.0 -> :overwhelming
          best > 2.0 -> :significant
          best > 1.5 -> :moderate
          true -> :none
        end

      %{advantage: advantage, best_efficiency: best, worst_efficiency: worst}
    end
  end

  defp check_critical_mass(fleet_sizes) do
    sizes = Map.values(fleet_sizes)
    Enum.any?(sizes, &(&1 >= 25))
  end

  defp calculate_attrition_sustainability(sides) do
    sides
    |> Enum.map(fn {side_id, data} ->
      total_pilots = Map.get(data, :total_pilots, 1)
      losses = Map.get(data, :losses, 0)
      loss_rate = losses / total_pilots

      sustainability =
        cond do
          loss_rate < 0.1 -> :excellent
          loss_rate < 0.25 -> :good
          loss_rate < 0.5 -> :moderate
          true -> :poor
        end

      {side_id, %{loss_rate: Float.round(loss_rate, 2), sustainability: sustainability}}
    end)
    |> Map.new()
  end

  # Tactical data extraction
  defp extract_coordination_data(tactical_patterns) do
    %{
      command_responses: Map.get(tactical_patterns, :command_responses, []),
      formation_changes: Map.get(tactical_patterns, :formation_changes, []),
      target_switches: Map.get(tactical_patterns, :target_switches, [])
    }
  end

  defp extract_targeting_data(tactical_patterns) do
    %{
      target_priorities: Map.get(tactical_patterns, :target_priorities, []),
      focus_fire_events: Map.get(tactical_patterns, :focus_fire_events, []),
      target_selection_timeline: Map.get(tactical_patterns, :target_selection_timeline, [])
    }
  end

  defp extract_positioning_data(tactical_patterns) do
    %{
      position_changes: Map.get(tactical_patterns, :position_changes, []),
      range_control: Map.get(tactical_patterns, :range_control, []),
      tactical_withdrawals: Map.get(tactical_patterns, :tactical_withdrawals, [])
    }
  end

  defp extract_timing_data(tactical_patterns) do
    %{
      engagement_start: Map.get(tactical_patterns, :engagement_start, 0),
      escalation_points: Map.get(tactical_patterns, :escalation_points, []),
      disengagement_timing: Map.get(tactical_patterns, :disengagement_timing, [])
    }
  end

  defp calculate_overall_tactical_score(coordination, target_selection, timing, positioning) do
    scores = [
      coordination[:overall_effectiveness] || 0.0,
      target_selection[:overall_quality] || 0.0,
      timing[:overall_timing] || 0.0,
      positioning[:overall_positioning] || 0.0
    ]

    average(scores)
  end

  # Historical comparison
  defp compare_with_historical(battle_results, historical_data) do
    recent_battles = Enum.take(historical_data, 10)

    current_efficiency = Map.get(battle_results, :isk_efficiency, 1.0)

    historical_avg =
      recent_battles
      |> Enum.map(&Map.get(&1, :isk_efficiency, 1.0))
      |> average()

    %{
      current_efficiency: current_efficiency,
      historical_average: historical_avg,
      performance_delta: current_efficiency - historical_avg,
      percentile_rank: calculate_percentile_rank(current_efficiency, recent_battles)
    }
  end

  defp evaluate_doctrine_effectiveness(battle_results, historical_data) do
    doctrine = Map.get(battle_results, :doctrine_used, :unknown)
    doctrine_battles = Enum.filter(historical_data, &(Map.get(&1, :doctrine_used) == doctrine))

    if Enum.empty?(doctrine_battles) do
      %{effectiveness: :unknown, sample_size: 0}
    else
      win_rate =
        doctrine_battles
        |> Enum.count(&Map.get(&1, :victory, false))
        |> Kernel./(length(doctrine_battles))

      %{
        effectiveness: categorize_doctrine_effectiveness(win_rate),
        win_rate: Float.round(win_rate, 2),
        sample_size: length(doctrine_battles)
      }
    end
  end

  # Probability calculations
  defp calculate_victory_probability(primary_factors, secondary_factors) do
    primary_score =
      primary_factors
      |> Enum.map(&Map.get(&1, :impact, 0.0))
      |> average()

    secondary_score =
      secondary_factors
      |> Enum.map(&Map.get(&1, :impact, 0.0))
      |> average()

    # Weighted combination
    probability = primary_score * 0.7 + secondary_score * 0.3
    Float.round(min(1.0, probability), 2)
  end

  defp analyze_counterfactuals(_tactical_analysis, decisive_moments) do
    # Analyze what-if scenarios based on decisive moments
    counterfactuals =
      decisive_moments
      |> Enum.map(fn moment ->
        case moment.moment do
          :logistics_elimination ->
            %{
              scenario: "What if logistics survived?",
              impact: "Battle duration +50%, casualties -30%",
              probability_change: +0.3
            }

          :capital_loss ->
            %{
              scenario: "What if capital was saved?",
              impact: "ISK efficiency +#{round(moment.isk_impact / 1_000_000)}M ISK",
              probability_change: +0.2
            }

          _ ->
            %{
              scenario: "Alternative timeline",
              impact: "Minor tactical adjustment",
              probability_change: +0.1
            }
        end
      end)

    %{scenarios: counterfactuals, total_scenarios: length(counterfactuals)}
  end

  defp calculate_improvement_potential(performance_metrics) do
    current_efficiency = Map.get(performance_metrics, :overall_efficiency, 0.5)
    theoretical_max = 1.0

    improvement_areas = [
      {:coordination, 0.2},
      {:target_selection, 0.15},
      {:positioning, 0.1},
      {:timing, 0.1}
    ]

    max_improvement =
      improvement_areas
      |> Enum.map(fn {_area, potential} -> potential end)
      |> Enum.sum()

    %{
      current_efficiency: current_efficiency,
      theoretical_maximum: theoretical_max,
      improvement_potential: min(max_improvement, theoretical_max - current_efficiency),
      priority_areas: improvement_areas
    }
  end

  # Event impact calculations
  defp calculate_logistics_kill_impact(event, timeline) do
    pre_kill_events =
      timeline.events
      |> Enum.filter(&(&1.timestamp < event.timestamp))

    post_kill_events =
      timeline.events
      |> Enum.filter(&(&1.timestamp > event.timestamp))

    # Calculate casualty rate change
    pre_casualty_rate = calculate_casualty_rate(pre_kill_events)
    post_casualty_rate = calculate_casualty_rate(post_kill_events)

    Float.round(post_casualty_rate - pre_casualty_rate, 2)
  end

  defp analyze_post_logistics_kill(event, timeline) do
    post_events =
      timeline.events
      |> Enum.filter(&(&1.timestamp > event.timestamp))
      |> Enum.take(10)

    %{
      immediate_casualties: Enum.count(post_events, &(&1.event_type == :kill)),
      fleet_survival: calculate_fleet_survival_post_event(post_events),
      battle_outcome_change: determine_outcome_change(event, post_events)
    }
  end

  defp estimate_coordination_loss(event, _timeline) do
    # Command ship loss impact on coordination
    command_ship_types = ["Command Ship", "Strategic Cruiser", "Battlecruiser"]

    if event.victim.ship_type in command_ship_types do
      0.4
    else
      0.2
    end
  end

  # Performance calculations
  defp calculate_pilot_effectiveness(avg_size) do
    # Effectiveness decreases with fleet size due to coordination overhead
    base_effectiveness = 1.0
    coordination_penalty = min(0.5, avg_size / 200)

    Float.round(base_effectiveness - coordination_penalty, 2)
  end

  defp calculate_combat_efficiency(ratio) do
    # Convert K/D ratio to efficiency score
    efficiency = min(1.0, ratio / 3.0)
    Float.round(efficiency, 2)
  end

  defp calculate_battle_efficiency(total_kills, total_losses) do
    if total_losses == 0 do
      1.0
    else
      efficiency = total_kills / total_losses
      Float.round(min(1.0, efficiency / 2.0), 2)
    end
  end

  # Categorization functions
  defp categorize_engagement_level(participation_rate) do
    cond do
      participation_rate > 0.8 -> :high
      participation_rate > 0.6 -> :medium
      participation_rate > 0.4 -> :low
      true -> :minimal
    end
  end

  defp calculate_engagement_intensity(avg_participation, sides) do
    total_pilots =
      Map.values(sides)
      |> Enum.map(&Map.get(&1, :total_pilots, 0))
      |> Enum.sum()

    # Scale intensity by participation and fleet size
    base_intensity = avg_participation
    size_multiplier = min(2.0, total_pilots / 50.0)

    Float.round(base_intensity * size_multiplier, 2)
  end

  defp categorize_battle_commitment(engagement_intensity) do
    cond do
      engagement_intensity > 1.5 -> :total_commitment
      engagement_intensity > 1.0 -> :high_commitment
      engagement_intensity > 0.6 -> :medium_commitment
      true -> :low_commitment
    end
  end

  defp categorize_doctrine_effectiveness(win_rate) do
    cond do
      win_rate > 0.7 -> :highly_effective
      win_rate > 0.5 -> :effective
      win_rate > 0.3 -> :somewhat_effective
      true -> :ineffective
    end
  end

  # Analysis functions
  defp identify_critical_weaknesses(outcome_analysis) do
    weaknesses = []

    # Check primary factors for poor performance
    primary_factors = Map.get(outcome_analysis, :primary_factors, [])

    weaknesses =
      if Enum.any?(
           primary_factors,
           &(Map.get(&1, :factor) == :logistics_advantage and Map.get(&1, :impact, 0) < 0.3)
         ) do
        [%{type: :logistics_vulnerability, severity: :critical, impact: 0.8} | weaknesses]
      else
        weaknesses
      end

    weaknesses =
      if Enum.any?(
           primary_factors,
           &(Map.get(&1, :factor) == :target_selection and Map.get(&1, :impact, 0) < 0.4)
         ) do
        [%{type: :poor_target_selection, severity: :high, impact: 0.6} | weaknesses]
      else
        weaknesses
      end

    weaknesses =
      if Enum.any?(
           primary_factors,
           &(Map.get(&1, :factor) == :coordination and Map.get(&1, :impact, 0) < 0.5)
         ) do
        [%{type: :poor_coordination, severity: :high, impact: 0.7} | weaknesses]
      else
        weaknesses
      end

    weaknesses
  end

  defp identify_key_strengths(outcome_analysis) do
    strengths = []

    primary_factors = Map.get(outcome_analysis, :primary_factors, [])

    strengths =
      if Enum.any?(
           primary_factors,
           &(Map.get(&1, :factor) == :numerical_superiority and Map.get(&1, :impact, 0) > 0.7)
         ) do
        [%{type: :numerical_advantage, strength: :major, impact: 0.8} | strengths]
      else
        strengths
      end

    strengths =
      if Enum.any?(
           primary_factors,
           &(Map.get(&1, :factor) == :combat_efficiency and Map.get(&1, :impact, 0) > 0.8)
         ) do
        [%{type: :combat_effectiveness, strength: :major, impact: 0.9} | strengths]
      else
        strengths
      end

    strengths
  end

  defp identify_improvement_opportunities(outcome_analysis) do
    opportunities = []

    secondary_factors = Map.get(outcome_analysis, :secondary_factors, [])

    opportunities =
      if Enum.any?(
           secondary_factors,
           &(Map.get(&1, :factor) == :positioning and Map.get(&1, :impact, 0) < 0.6)
         ) do
        [%{type: :positioning_improvement, potential: :high, effort: :medium} | opportunities]
      else
        opportunities
      end

    opportunities =
      if Enum.any?(
           secondary_factors,
           &(Map.get(&1, :factor) == :timing and Map.get(&1, :impact, 0) < 0.7)
         ) do
        [%{type: :timing_optimization, potential: :medium, effort: :low} | opportunities]
      else
        opportunities
      end

    opportunities
  end

  defp prioritize_recommendations(immediate_actions) do
    Enum.sort_by(
      immediate_actions,
      fn action ->
        urgency_score = urgency_to_number(Map.get(action, :urgency, :low))
        impact_score = impact_to_number(Map.get(action, :expected_impact, :low))
        {urgency_score, impact_score}
      end,
      :desc
    )
  end

  # Helper functions
  defp calculate_casualty_rate(events) do
    if Enum.empty?(events) do
      0.0
    else
      kills = Enum.count(events, &(&1.event_type == :kill))
      Float.round(kills / length(events), 2)
    end
  end

  defp calculate_fleet_survival_post_event(events) do
    if Enum.empty?(events) do
      1.0
    else
      survivors = Enum.count(events, &(&1.event_type != :kill))
      Float.round(survivors / length(events), 2)
    end
  end

  defp determine_outcome_change(event, _post_events) do
    impact_score = Map.get(event, :tactical_significance_score, 0.5)

    cond do
      impact_score > 0.8 -> :decisive_shift
      impact_score > 0.6 -> :significant_impact
      impact_score > 0.4 -> :moderate_impact
      true -> :minor_impact
    end
  end

  defp calculate_percentile_rank(current_value, historical_battles) do
    if Enum.empty?(historical_battles) do
      0.5
    else
      values = Enum.map(historical_battles, &Map.get(&1, :isk_efficiency, 1.0))
      below_current = Enum.count(values, &(&1 <= current_value))
      Float.round(below_current / length(values), 2)
    end
  end

  defp average(values) when is_list(values) do
    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end

  # Learning and adaptation
  defp calculate_learning_rate(historical_data) do
    if length(historical_data) < 3 do
      0.0
    else
      recent = Enum.take(historical_data, 5)
      older = Enum.drop(historical_data, 5) |> Enum.take(5)

      recent_avg = recent |> Enum.map(&Map.get(&1, :performance_score, 0.5)) |> average()
      older_avg = older |> Enum.map(&Map.get(&1, :performance_score, 0.5)) |> average()

      Float.round(max(0.0, recent_avg - older_avg), 2)
    end
  end

  defp measure_adaptation_effectiveness(battle_results, _historical_data) do
    current_adaptations = Map.get(battle_results, :tactical_adaptations, [])

    if Enum.empty?(current_adaptations) do
      %{effectiveness: :none, adaptations_used: 0}
    else
      successful_adaptations = Enum.count(current_adaptations, &Map.get(&1, :successful, false))
      effectiveness_rate = successful_adaptations / length(current_adaptations)

      %{
        effectiveness: categorize_adaptation_effectiveness(effectiveness_rate),
        adaptations_used: length(current_adaptations),
        success_rate: Float.round(effectiveness_rate, 2)
      }
    end
  end

  defp predict_future_performance(trends, learning_rate) do
    base_performance = Map.get(trends, :current_performance, 0.5)
    trend_direction = Map.get(trends, :trend_direction, :stable)

    projection =
      case trend_direction do
        :improving -> base_performance + learning_rate * 2
        :declining -> base_performance - learning_rate
        :stable -> base_performance + learning_rate * 0.5
        _ -> base_performance
      end

    %{
      projected_performance: Float.round(min(1.0, max(0.0, projection)), 2),
      confidence: calculate_prediction_confidence(trends, learning_rate),
      timeframe: "next 3-5 battles"
    }
  end

  defp categorize_adaptation_effectiveness(rate) do
    cond do
      rate > 0.8 -> :highly_effective
      rate > 0.6 -> :effective
      rate > 0.4 -> :somewhat_effective
      true -> :ineffective
    end
  end

  defp calculate_prediction_confidence(trends, learning_rate) do
    # Base confidence on data quality and learning rate
    data_quality = Map.get(trends, :data_quality, 0.5)
    learning_stability = min(1.0, learning_rate * 5)

    confidence = (data_quality + learning_stability) / 2
    Float.round(confidence, 2)
  end

  # Recommendation generation
  defp estimate_improvement_impact(prioritized_actions) do
    if Enum.empty?(prioritized_actions) do
      %{total_impact: 0.0, timeline: "N/A"}
    else
      total_impact =
        prioritized_actions
        |> Enum.map(&impact_to_number(Map.get(&1, :expected_impact, :low)))
        |> Enum.sum()
        |> Kernel./(length(prioritized_actions))

      %{
        total_impact: Float.round(total_impact / 3.0, 2),
        timeline: "2-4 weeks",
        high_impact_actions:
          Enum.count(prioritized_actions, &(Map.get(&1, :expected_impact) == :high))
      }
    end
  end

  defp generate_implementation_timeline(prioritized_actions) do
    prioritized_actions
    |> Enum.with_index()
    |> Enum.map(fn {action, index} ->
      urgency = Map.get(action, :urgency, :low)

      timeframe =
        case urgency do
          :critical -> "Immediate (0-24 hours)"
          :high -> "Short term (1-3 days)"
          :medium -> "Medium term (1-2 weeks)"
          :low -> "Long term (2-4 weeks)"
        end

      %{
        action: Map.get(action, :action, "Unknown action"),
        priority: index + 1,
        timeframe: timeframe,
        urgency: urgency
      }
    end)
  end

  # Tactical analysis functions
  defp identify_tactical_mistakes(tactical_patterns) do
    mistakes = []

    # Check for common tactical errors
    target_switches = Map.get(tactical_patterns, :target_switches, [])

    mistakes =
      if length(target_switches) > 5 do
        [%{mistake: :excessive_target_switching, severity: :medium, impact: 0.3} | mistakes]
      else
        mistakes
      end

    positioning_errors = Map.get(tactical_patterns, :positioning_errors, [])

    mistakes =
      if length(positioning_errors) > 3 do
        [%{mistake: :poor_positioning, severity: :high, impact: 0.6} | mistakes]
      else
        mistakes
      end

    coordination_failures = Map.get(tactical_patterns, :coordination_failures, [])

    mistakes =
      if length(coordination_failures) > 2 do
        [%{mistake: :coordination_breakdown, severity: :critical, impact: 0.8} | mistakes]
      else
        mistakes
      end

    mistakes
  end

  defp measure_tactical_adaptation(tactical_patterns) do
    adaptations = Map.get(tactical_patterns, :tactical_adaptations, [])

    if Enum.empty?(adaptations) do
      %{adaptability: :none, response_time: 0.0, effectiveness: 0.0}
    else
      avg_response_time =
        adaptations
        |> Enum.map(&Map.get(&1, :response_time, 60))
        |> average()

      successful_adaptations = Enum.count(adaptations, &Map.get(&1, :successful, false))
      effectiveness = successful_adaptations / length(adaptations)

      adaptability =
        cond do
          effectiveness > 0.8 -> :excellent
          effectiveness > 0.6 -> :good
          effectiveness > 0.4 -> :moderate
          true -> :poor
        end

      %{
        adaptability: adaptability,
        response_time: Float.round(avg_response_time, 1),
        effectiveness: Float.round(effectiveness, 2),
        total_adaptations: length(adaptations)
      }
    end
  end

  # Additional helper functions for target selection analysis
  defp calculate_priority_adherence(target_priorities) do
    if Enum.empty?(target_priorities) do
      0.5
    else
      correct_priorities = Enum.count(target_priorities, &Map.get(&1, :correct_priority, false))
      Float.round(correct_priorities / length(target_priorities), 2)
    end
  end

  defp calculate_target_switching_efficiency(target_switches) do
    if Enum.empty?(target_switches) do
      0.7
    else
      switch_count = length(target_switches)
      optimal_switches = 3..7

      if switch_count in optimal_switches do
        0.8
      else
        if switch_count < 3, do: 0.6, else: 0.4
      end
    end
  end

  defp calculate_focus_fire_effectiveness(focus_fire_events) do
    if Enum.empty?(focus_fire_events) do
      0.6
    else
      successful_focus = Enum.count(focus_fire_events, &Map.get(&1, :successful, false))
      Float.round(successful_focus / length(focus_fire_events), 2)
    end
  end

  # Timing analysis helper functions
  defp calculate_engagement_timing_score(engagement_start, escalation_points) do
    if Enum.empty?(escalation_points) do
      0.7
    else
      first_escalation = Enum.min_by(escalation_points, & &1.timestamp)
      time_to_escalate = first_escalation.timestamp - engagement_start

      cond do
        time_to_escalate < 30 -> 0.5
        time_to_escalate > 300 -> 0.4
        true -> 0.8
      end
    end
  end

  defp calculate_tactical_timing_score(escalation_points) do
    if length(escalation_points) < 2 do
      0.6
    else
      timestamps = Enum.map(escalation_points, & &1.timestamp)

      intervals =
        Enum.sort(timestamps)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> b - a end)

      avg_interval = average(intervals)

      cond do
        avg_interval < 60 -> 0.5
        avg_interval > 300 -> 0.4
        true -> 0.8
      end
    end
  end

  defp calculate_retreat_timing_score(disengagement_timing) do
    if Enum.empty?(disengagement_timing) do
      0.5
    else
      retreat_events = Enum.filter(disengagement_timing, &Map.get(&1, :successful, false))

      if Enum.empty?(retreat_events) do
        0.2
      else
        0.8
      end
    end
  end

  # Positioning analysis helper functions
  defp calculate_strategic_positioning_score(position_changes) do
    if Enum.empty?(position_changes) do
      0.6
    else
      beneficial_moves = Enum.count(position_changes, &Map.get(&1, :beneficial, false))
      Float.round(beneficial_moves / length(position_changes), 2)
    end
  end

  defp calculate_tactical_positioning_score(position_changes, tactical_withdrawals) do
    position_score =
      if Enum.empty?(position_changes) do
        0.6
      else
        good_positions = Enum.count(position_changes, &Map.get(&1, :tactically_sound, false))
        good_positions / length(position_changes)
      end

    withdrawal_score =
      if Enum.empty?(tactical_withdrawals) do
        0.5
      else
        successful_withdrawals =
          Enum.count(tactical_withdrawals, &Map.get(&1, :successful, false))

        successful_withdrawals / length(tactical_withdrawals)
      end

    Float.round(average([position_score, withdrawal_score]), 2)
  end

  defp calculate_range_control_score(range_control) do
    if Enum.empty?(range_control) do
      0.7
    else
      effective_control = Enum.count(range_control, &Map.get(&1, :effective, false))
      Float.round(effective_control / length(range_control), 2)
    end
  end

  # Innovation effectiveness calculations
  defp calculate_split_effectiveness(fleet_splits) do
    if Enum.empty?(fleet_splits) do
      0.0
    else
      successful_splits = Enum.count(fleet_splits, &Map.get(&1, :successful, false))
      Float.round(successful_splits / length(fleet_splits), 2)
    end
  end

  defp calculate_alpha_strike_effectiveness(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      successful_strikes = Enum.count(alpha_strikes, &Map.get(&1, :successful, false))
      Float.round(successful_strikes / length(alpha_strikes), 2)
    end
  end

  defp calculate_feint_effectiveness(feints) do
    if Enum.empty?(feints) do
      0.0
    else
      successful_feints = Enum.count(feints, &Map.get(&1, :successful, false))
      Float.round(successful_feints / length(feints), 2)
    end
  end

  defp calculate_ewar_coordination_effectiveness(ewar_coordination) do
    if Enum.empty?(ewar_coordination) do
      0.0
    else
      effective_coordination = Enum.count(ewar_coordination, &Map.get(&1, :effective, false))
      Float.round(effective_coordination / length(ewar_coordination), 2)
    end
  end
end
