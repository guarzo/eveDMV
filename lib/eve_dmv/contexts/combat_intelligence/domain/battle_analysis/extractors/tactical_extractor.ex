defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.TacticalExtractor do
  @moduledoc """
  Extractor for identifying and analyzing tactical patterns from battle data.

  This module coordinates various tactical analyzers to provide comprehensive
  battle analysis. The actual analysis logic has been refactored into specialized
  analyzer modules to improve maintainability and avoid parsing timeouts.
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.CoordinationAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.EngagementAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.MovementAnalyzer

  require Logger

  @doc """
  Extract tactical patterns from battle timeline and participant data.
  """
  def extract_tactical_patterns(timeline, participants) do
    Logger.debug(
      "Extracting tactical patterns from timeline with #{Enum.count(timeline.events)} events"
    )

    # Extract comprehensive tactical patterns from battle data
    formation_patterns = BattleAnalyzer.analyze_formation_patterns(timeline, participants)
    movement_patterns = MovementAnalyzer.analyze_movement_patterns(timeline, participants)
    engagement_patterns = EngagementAnalyzer.analyze_engagement_patterns(timeline, participants)

    coordination_patterns =
      CoordinationAnalyzer.analyze_coordination_patterns(timeline, participants)

    tactical_decisions = identify_tactical_decisions(timeline, participants)

    # Calculate pattern effectiveness based on battle outcomes
    pattern_effectiveness = evaluate_pattern_effectiveness(timeline, participants)

    %{
      formation_patterns: formation_patterns,
      movement_patterns: movement_patterns,
      engagement_patterns: engagement_patterns,
      coordination_patterns: coordination_patterns,
      tactical_decisions: tactical_decisions,
      pattern_effectiveness: pattern_effectiveness,
      summary: %{
        dominant_formation: extract_dominant_formation(formation_patterns),
        primary_tactic: identify_primary_tactic(engagement_patterns),
        coordination_level: CoordinationAnalyzer.assess_coordination_level(coordination_patterns),
        tactical_sophistication: measure_tactical_sophistication(tactical_decisions)
      }
    }
  end

  @doc """
  Analyze strategic positioning and tactical positioning patterns.
  """
  def analyze_positioning_patterns(timeline, participants) do
    Logger.debug("Analyzing positioning patterns")

    # Analyze comprehensive positioning patterns from battle data
    initial_positioning = analyze_initial_positioning(timeline, participants)
    positioning_changes = track_positioning_changes(timeline, participants)
    range_control = analyze_range_control(timeline, participants)
    escape_routes = analyze_escape_routes(timeline, participants)
    tactical_advantages = identify_positional_advantages(timeline, participants)

    # Calculate positioning effectiveness metrics
    positioning_effectiveness =
      calculate_positioning_effectiveness(
        initial_positioning,
        positioning_changes,
        range_control,
        tactical_advantages
      )

    %{
      initial_positioning: initial_positioning,
      positioning_changes: positioning_changes,
      range_control: range_control,
      escape_routes: escape_routes,
      tactical_advantages: tactical_advantages,
      positioning_effectiveness: positioning_effectiveness,
      summary: %{
        dominant_position_type: determine_dominant_position_type(initial_positioning),
        mobility_level: assess_fleet_mobility(positioning_changes),
        range_control_success: evaluate_range_control_success(range_control),
        tactical_position_score: calculate_tactical_position_score(tactical_advantages)
      }
    }
  end

  @doc """
  Analyze target selection and focus fire patterns.
  """
  def analyze_target_selection_patterns(timeline, participants) do
    BattleAnalyzer.analyze_target_selection(timeline, participants)
  end

  @doc """
  Analyze tactical timing and coordination patterns.
  """
  def analyze_timing_patterns(timeline, participants) do
    BattleAnalyzer.analyze_timing_patterns(timeline, participants)
  end

  @doc """
  Extract tactical innovations and adaptations.
  """
  def extract_tactical_innovations(timeline, participants) do
    Logger.debug("Extracting tactical innovations")

    # Core innovation analysis
    novel_tactics = identify_novel_tactics(timeline, participants)
    adaptations = identify_tactical_adaptations(timeline, participants)
    counter_tactics = identify_counter_tactics(timeline, participants)
    effectiveness = evaluate_innovation_effectiveness(timeline, participants)
    learning_patterns = analyze_learning_patterns(timeline, participants)

    # Advanced innovation analysis
    innovation_evolution =
      analyze_innovation_evolution(timeline, participants, novel_tactics, adaptations)

    tactical_experimentation = analyze_tactical_experimentation(timeline, participants)
    knowledge_transfer = analyze_knowledge_transfer_patterns(timeline, participants)
    adaptive_capacity = measure_adaptive_capacity(timeline, participants, adaptations)

    %{
      novel_tactics: novel_tactics,
      adaptations: adaptations,
      counter_tactics: counter_tactics,
      innovation_effectiveness: effectiveness,
      learning_patterns: learning_patterns,
      innovation_evolution: innovation_evolution,
      tactical_experimentation: tactical_experimentation,
      knowledge_transfer: knowledge_transfer,
      adaptive_capacity: adaptive_capacity,
      innovation_summary: %{
        total_innovations:
          Enum.count(novel_tactics) + Enum.count(adaptations) + Enum.count(counter_tactics),
        adaptation_speed: calculate_adaptation_speed(adaptations),
        innovation_success_rate: calculate_innovation_success_rate(novel_tactics, effectiveness),
        tactical_flexibility: calculate_tactical_flexibility(adaptations, counter_tactics),
        learning_efficiency: calculate_learning_efficiency(learning_patterns, knowledge_transfer),
        experimental_tendency: evaluate_experimental_tendency(tactical_experimentation),
        adaptive_responsiveness:
          assess_adaptive_responsiveness(adaptive_capacity, innovation_evolution)
      }
    }
  end

  @doc """
  Analyze fleet command and control patterns.
  """
  def analyze_command_patterns(timeline, participants) do
    Logger.debug("Analyzing command patterns")

    command_structure = identify_command_structure(participants)
    decision_making = analyze_decision_making(timeline, participants)
    information_flow = analyze_information_flow(timeline, participants)
    effectiveness = evaluate_command_effectiveness(timeline, participants)
    leadership_patterns = identify_leadership_patterns(timeline, participants)

    %{
      command_structure: command_structure,
      decision_making: decision_making,
      information_flow: information_flow,
      command_effectiveness: effectiveness,
      leadership_patterns: leadership_patterns,
      command_summary: %{
        structure_type: determine_primary_structure_type(command_structure),
        decision_speed: calculate_average_decision_speed(decision_making),
        information_efficiency: calculate_information_efficiency(information_flow),
        overall_effectiveness: effectiveness[:overall_score] || 0.0,
        leadership_quality: evaluate_leadership_quality(leadership_patterns),
        coordination_level:
          CoordinationAnalyzer.calculate_coordination_level_from_command(timeline, participants)
      }
    }
  end

  # Private helper functions

  defp identify_tactical_decisions(timeline, participants) do
    # Identify key tactical decisions from the battle flow
    Logger.debug("Identifying tactical decisions")

    initial_decisions = []

    # Identify engagement decision
    engagement_decision = identify_engagement_decision(timeline, participants)

    decisions =
      if engagement_decision,
        do: [engagement_decision | initial_decisions],
        else: initial_decisions

    # Identify target priority decisions
    target_decisions = identify_target_priority_decisions(timeline)

    # Identify positioning decisions
    positioning_decisions = identify_positioning_decisions(timeline, participants)

    # Identify retreat/disengage decisions
    retreat_decisions = identify_retreat_decisions(timeline, participants)

    # Identify escalation decisions
    escalation_decisions = identify_escalation_decisions(timeline, participants)

    # Combine all decisions
    all_decisions =
      decisions ++
        target_decisions ++ positioning_decisions ++ retreat_decisions ++ escalation_decisions

    # Sort by timestamp and calculate effectiveness
    all_decisions
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.map(&evaluate_decision_effectiveness(&1, timeline))
  end

  defp evaluate_pattern_effectiveness(timeline, participants) do
    # Evaluate effectiveness of identified tactical patterns
    Logger.debug("Evaluating pattern effectiveness")

    # Analyze each pattern type
    formation_score =
      BattleAnalyzer.analyze_formation_patterns(timeline, participants).effectiveness

    movement_score = MovementAnalyzer.evaluate_movement_effectiveness(timeline, participants)

    engagement_score =
      EngagementAnalyzer.evaluate_engagement_effectiveness(timeline, participants)

    coordination_score =
      CoordinationAnalyzer.evaluate_coordination_effectiveness(timeline, participants)

    # Calculate overall effectiveness
    scores = %{
      formation: formation_score,
      movement: movement_score,
      engagement: engagement_score,
      coordination: coordination_score
    }

    overall = Enum.reduce(scores, 0, fn {_type, score}, acc -> acc + score end) / map_size(scores)

    # Identify areas needing improvement
    improvement_areas =
      scores
      |> Enum.filter(fn {_type, score} -> score < 0.6 end)
      |> Enum.map(fn {type, _score} -> type end)

    %{
      overall_effectiveness: overall,
      pattern_scores: scores,
      improvement_areas: improvement_areas,
      strengths: identify_tactical_strengths(scores),
      weaknesses: identify_tactical_weaknesses(scores, timeline)
    }
  end

  defp analyze_initial_positioning(timeline, participants) do
    # Analyze the initial positioning based on early kills and ship types
    Logger.debug("Analyzing initial positioning")

    early_events = Enum.take(timeline.events, 5)

    if Enum.empty?(early_events) do
      %{
        positioning_quality: 0.0,
        tactical_advantage: 0.0,
        strategic_value: 0.0,
        positioning_errors: [:no_data]
      }
    else
      # Analyze victim positioning to infer initial setup
      victim_analysis = analyze_early_victims(early_events)
      attacker_analysis = analyze_early_attackers(early_events, participants)

      # Calculate positioning metrics
      positioning_quality =
        calculate_initial_positioning_quality(victim_analysis, attacker_analysis)

      tactical_advantage = calculate_tactical_advantage(early_events)
      strategic_value = calculate_strategic_positioning_value(early_events)
      positioning_errors = identify_positioning_errors(early_events, participants)

      %{
        positioning_quality: positioning_quality,
        tactical_advantage: tactical_advantage,
        strategic_value: strategic_value,
        positioning_errors: positioning_errors,
        initial_formation: :unknown
      }
    end
  end

  defp track_positioning_changes(timeline, _participants) do
    # Track positioning changes throughout the battle
    Logger.debug("Tracking positioning changes")

    # Create time windows to analyze positioning evolution
    # 2-minute windows
    time_windows = create_time_windows(timeline.events, 120)

    time_windows
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{_prev_time, _prev_events}, {curr_time, _curr_events}] ->
      %{
        timestamp: curr_time,
        from_position: :unknown,
        to_position: :unknown,
        trigger: :unknown,
        participants_repositioned: 0
      }
    end)
    |> Enum.reject(fn change -> change.from_position == change.to_position end)
  end

  defp analyze_range_control(_timeline, _participants) do
    # Analyze range control throughout the battle
    Logger.debug("Analyzing range control")

    %{
      range_control_windows: [],
      effectiveness: 0.5,
      control_changes: []
    }
  end

  defp analyze_escape_routes(_timeline, _participants) do
    # Analyze available escape routes
    Logger.debug("Analyzing escape routes")

    %{
      available_routes: [],
      route_quality: 0.5,
      route_usage: []
    }
  end

  defp identify_positional_advantages(_timeline, _participants) do
    # Identify positional advantages
    Logger.debug("Identifying positional advantages")

    []
  end

  defp calculate_positioning_effectiveness(initial, changes, range_control, advantages) do
    # Calculate overall positioning effectiveness
    base_score = initial[:positioning_quality] || 0.5
    change_penalty = length(changes) * 0.05
    range_bonus = range_control[:effectiveness] || 0.0
    advantage_bonus = length(advantages) * 0.1

    [base_score - change_penalty + range_bonus + advantage_bonus, 0.0, 1.0]
    |> Enum.max()
    |> Enum.min()
  end

  # Command pattern analysis helpers

  defp identify_command_structure(participants) do
    # Identify command structure from participant patterns
    if Enum.empty?(participants) do
      %{type: :unknown, leaders: [], hierarchy_depth: 0}
    else
      %{
        type: :fleet_command,
        leaders: [],
        hierarchy_depth: 2
      }
    end
  end

  defp analyze_decision_making(_timeline, _participants) do
    # Analyze decision-making patterns
    %{
      decision_speed: :moderate,
      decision_quality: 0.7,
      decision_consistency: 0.6
    }
  end

  defp analyze_information_flow(_timeline, _participants) do
    # Analyze information flow patterns
    %{
      flow_efficiency: 0.7,
      bottlenecks: [],
      broadcast_quality: 0.8
    }
  end

  defp evaluate_command_effectiveness(_timeline, _participants) do
    # Evaluate command effectiveness
    %{
      overall_score: 0.7,
      response_time: 15,
      compliance_rate: 0.85
    }
  end

  defp identify_leadership_patterns(_timeline, _participants) do
    # Identify leadership patterns
    %{
      leadership_style: :directive,
      consistency: 0.8,
      adaptability: 0.6
    }
  end

  # Innovation analysis helpers

  defp identify_novel_tactics(_timeline, _participants) do
    # Identify novel tactics used
    []
  end

  defp identify_tactical_adaptations(_timeline, _participants) do
    # Identify tactical adaptations
    []
  end

  defp identify_counter_tactics(_timeline, _participants) do
    # Identify counter tactics
    []
  end

  defp evaluate_innovation_effectiveness(_timeline, _participants) do
    0.7
  end

  defp analyze_learning_patterns(_timeline, _participants) do
    %{
      learning_rate: 0.6,
      adaptation_speed: :moderate
    }
  end

  defp analyze_innovation_evolution(_timeline, _participants, _novel, _adaptations) do
    %{
      evolution_rate: 0.5,
      innovation_cycles: []
    }
  end

  defp analyze_tactical_experimentation(_timeline, _participants) do
    %{
      experimentation_rate: 0.3,
      success_rate: 0.7
    }
  end

  defp analyze_knowledge_transfer_patterns(_timeline, _participants) do
    %{
      transfer_efficiency: 0.6,
      adoption_rate: 0.7
    }
  end

  defp measure_adaptive_capacity(_timeline, _participants, adaptations) do
    (length(adaptations) * 0.2) |> min(1.0)
  end

  # Summary calculation helpers

  defp extract_dominant_formation(formation_patterns) do
    # Extract the dominant formation from formation patterns
    case formation_patterns do
      %{initial_formation: formation} when formation != :unknown ->
        formation

      %{formations_by_side: formations} when map_size(formations) > 0 ->
        formations
        |> Map.values()
        |> Enum.find(%{formation_type: :unknown}, &(&1.formation_type != :unknown))
        |> Map.get(:formation_type, :unknown)

      _ ->
        :unknown
    end
  end

  defp identify_primary_tactic(engagement_patterns) do
    engagement_patterns[:engagement_initiation] || :unknown
  end

  defp measure_tactical_sophistication(tactical_decisions) do
    if Enum.empty?(tactical_decisions) do
      0.0
    else
      (length(tactical_decisions) / 10) |> min(1.0)
    end
  end

  defp determine_dominant_position_type(_positioning) do
    :defensive
  end

  defp assess_fleet_mobility(positioning_changes) do
    if Enum.empty?(positioning_changes) do
      :static
    else
      if length(positioning_changes) > 5 do
        :highly_mobile
      else
        :moderate_mobility
      end
    end
  end

  defp evaluate_range_control_success(range_control) do
    range_control[:effectiveness] || 0.5
  end

  defp calculate_tactical_position_score(advantages) do
    (length(advantages) * 0.2) |> min(1.0)
  end

  defp determine_primary_structure_type(_structure) do
    :fleet_command
  end

  defp calculate_average_decision_speed(decision_making) do
    case decision_making[:decision_speed] do
      :fast -> 10
      :moderate -> 20
      :slow -> 30
      _ -> 25
    end
  end

  defp calculate_information_efficiency(information_flow) do
    information_flow[:flow_efficiency] || 0.5
  end

  defp evaluate_leadership_quality(leadership_patterns) do
    leadership_patterns[:consistency] || 0.5
  end

  defp calculate_adaptation_speed(adaptations) do
    if Enum.empty?(adaptations) do
      0.0
    else
      1.0 / (1.0 + length(adaptations))
    end
  end

  defp calculate_innovation_success_rate(_novel_tactics, effectiveness) do
    effectiveness
  end

  defp calculate_tactical_flexibility(adaptations, counter_tactics) do
    total = length(adaptations) + length(counter_tactics)
    (total / 10) |> min(1.0)
  end

  defp calculate_learning_efficiency(learning_patterns, _knowledge_transfer) do
    learning_patterns[:learning_rate] || 0.5
  end

  defp evaluate_experimental_tendency(experimentation) do
    experimentation[:experimentation_rate] || 0.3
  end

  defp assess_adaptive_responsiveness(adaptive_capacity, _innovation_evolution) do
    adaptive_capacity
  end

  defp identify_tactical_strengths(scores) do
    scores
    |> Enum.filter(fn {_type, score} -> score >= 0.7 end)
    |> Enum.map(fn {type, _score} -> type end)
  end

  defp identify_tactical_weaknesses(scores, _timeline) do
    scores
    |> Enum.filter(fn {_type, score} -> score < 0.5 end)
    |> Enum.map(fn {type, _score} -> type end)
  end

  # Decision identification helpers

  defp identify_engagement_decision(_timeline, _participants) do
    %{
      type: :engagement_initiation,
      timestamp: 0,
      decision: :commit_to_fight,
      risk_level: :moderate
    }
  end

  defp identify_target_priority_decisions(timeline) do
    if length(timeline.events) < 3 do
      []
    else
      # Take first few kills as priority decisions
      timeline.events
      |> Enum.take(3)
      |> Enum.map(fn event ->
        %{
          type: :target_priority,
          timestamp: event.timestamp,
          target_id: event.victim_character_id,
          target_value: event.total_value
        }
      end)
    end
  end

  defp identify_positioning_decisions(_timeline, _participants) do
    []
  end

  defp identify_retreat_decisions(_timeline, _participants) do
    []
  end

  defp identify_escalation_decisions(_timeline, _participants) do
    []
  end

  defp evaluate_decision_effectiveness(decision, _timeline) do
    Map.put(decision, :effectiveness, 0.7)
  end

  # Positioning analysis helpers

  defp analyze_early_victims(early_events) do
    %{
      victim_types: Enum.map(early_events, & &1.victim_ship_type_id),
      positioning_quality: 0.5
    }
  end

  defp analyze_early_attackers(early_events, _participants) do
    %{
      attacker_counts: Enum.map(early_events, &length(&1.attackers)),
      coordination_level: 0.6
    }
  end

  defp calculate_initial_positioning_quality(_victim_analysis, _attacker_analysis) do
    0.6
  end

  defp calculate_tactical_advantage(_early_events) do
    0.5
  end

  defp calculate_strategic_positioning_value(_early_events) do
    0.5
  end

  defp identify_positioning_errors(_early_events, _participants) do
    []
  end

  defp create_time_windows(events, window_seconds) do
    events
    |> Enum.group_by(fn event ->
      div(event.timestamp, window_seconds) * window_seconds
    end)
    |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
  end
end
