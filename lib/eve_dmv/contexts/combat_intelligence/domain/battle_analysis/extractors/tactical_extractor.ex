defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.TacticalExtractor do
  @moduledoc """
  Extractor for identifying and analyzing tactical patterns from battle data.

  Analyzes tactical patterns, strategic decisions, and combat effectiveness
  from battle timelines and participant data.
  """

  require Logger

  @doc """
  Extract tactical patterns from battle _timeline and participant data.
  """
  def extract_tactical_patterns(timeline, participants) do
    Logger.debug(
      "Extracting tactical patterns from timeline with #{Enum.count(timeline.events)} events"
    )

    # For now, return basic tactical pattern extraction
    # TODO: Implement detailed tactical pattern extraction

    %{
      formation_patterns: analyze_formation_patterns(timeline, participants),
      movement_patterns: analyze_movement_patterns(timeline, participants),
      engagement_patterns: analyze_engagement_patterns(timeline, participants),
      coordination_patterns: analyze_coordination_patterns(timeline, participants),
      tactical_decisions: identify_tactical_decisions(timeline, participants),
      pattern_effectiveness: evaluate_pattern_effectiveness(timeline, participants)
    }
  end

  @doc """
  Analyze strategic positioning and tactical positioning patterns.
  """
  def analyze_positioning_patterns(timeline, participants) do
    Logger.debug("Analyzing positioning patterns")

    # For now, return basic positioning analysis
    # TODO: Implement detailed positioning pattern analysis

    %{
      initial_positioning: analyze_initial_positioning(timeline, participants),
      positioning_changes: track_positioning_changes(timeline, participants),
      range_control: analyze_range_control(timeline, participants),
      escape_routes: analyze_escape_routes(timeline, participants),
      tactical_advantages: identify_positional_advantages(timeline, participants)
    }
  end

  @doc """
  Analyze target selection and focus fire patterns.
  """
  def analyze_target_selection_patterns(timeline, participants) do
    Logger.debug("Analyzing target selection patterns")

    # Comprehensive target selection analysis using real killmail data
    target_prioritization = analyze_target_prioritization(timeline)
    focus_fire_patterns = analyze_focus_fire_patterns(timeline)
    target_switching = analyze_target_switching(timeline)
    primary_calling = analyze_primary_calling(timeline)
    effectiveness = evaluate_target_selection_effectiveness(timeline)

    # Additional comprehensive analysis
    target_acquisition = analyze_target_acquisition_patterns(timeline, participants)
    tactical_focus = evaluate_tactical_focus_consistency(timeline, participants)
    selection_doctrine = identify_target_selection_doctrine(timeline, participants)
    counter_selection = analyze_counter_target_selection(timeline, participants)

    %{
      target_prioritization: target_prioritization,
      focus_fire_patterns: focus_fire_patterns,
      target_switching: target_switching,
      primary_calling: primary_calling,
      target_selection_effectiveness: effectiveness,
      target_acquisition: target_acquisition,
      tactical_focus: tactical_focus,
      selection_doctrine: selection_doctrine,
      counter_target_selection: counter_selection,
      summary: %{
        overall_coordination:
          calculate_overall_target_coordination(
            target_prioritization,
            focus_fire_patterns,
            primary_calling
          ),
        strategic_coherence:
          evaluate_target_strategic_coherence(target_prioritization, selection_doctrine),
        adaptation_capability:
          measure_target_selection_adaptation(target_switching, counter_selection),
        execution_quality: calculate_target_execution_quality(focus_fire_patterns, effectiveness)
      }
    }
  end

  @doc """
  Analyze tactical timing and coordination patterns.
  """
  def analyze_timing_patterns(timeline, participants) do
    Logger.debug("Analyzing timing patterns")

    # Comprehensive timing analysis using real killmail data
    engagement_timing = analyze_engagement_timing(timeline)
    coordination_timing = analyze_coordination_timing(timeline)
    alpha_strike_timing = analyze_alpha_strike_timing(timeline)
    retreat_timing = analyze_retreat_timing(timeline)
    tactical_rhythm = analyze_tactical_rhythm(timeline)

    # Advanced timing analysis components
    battle_flow_timing = analyze_battle_flow_timing(timeline, participants)
    tactical_transitions = analyze_tactical_transitions(timeline, participants)
    pressure_timing = analyze_pressure_application_timing(timeline, participants)
    escalation_timing = analyze_escalation_timing_patterns(timeline, participants)

    %{
      engagement_timing: engagement_timing,
      coordination_timing: coordination_timing,
      alpha_strike_timing: alpha_strike_timing,
      retreat_timing: retreat_timing,
      tactical_rhythm: tactical_rhythm,
      battle_flow_timing: battle_flow_timing,
      tactical_transitions: tactical_transitions,
      pressure_timing: pressure_timing,
      escalation_timing: escalation_timing,
      timing_summary: %{
        overall_coordination:
          calculate_overall_timing_coordination(
            engagement_timing,
            coordination_timing,
            alpha_strike_timing
          ),
        tempo_control: evaluate_tempo_control_effectiveness(tactical_rhythm, pressure_timing),
        timing_adaptability: measure_timing_adaptability(tactical_transitions, escalation_timing),
        synchronization_quality:
          assess_synchronization_quality(
            coordination_timing,
            alpha_strike_timing,
            battle_flow_timing
          )
      }
    }
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
        coordination_level: calculate_coordination_level_from_command(timeline, participants)
      }
    }
  end

  # Private helper functions
  defp analyze_formation_patterns(timeline, participants) do
    # Analyze ship positions and movements over time to identify formations
    Logger.debug("Analyzing formation patterns for #{Enum.count(participants)} participants")

    # Group participants by side
    sides = group_participants_by_side(participants)

    # Analyze formation for each side
    formations_by_side =
      Enum.map(sides, fn {side, side_participants} ->
        {side, analyze_side_formation(timeline, side_participants)}
      end)
      |> Map.new()

    # Identify formation changes over time
    formation_changes = detect_formation_changes(timeline, participants)

    # Calculate formation effectiveness based on coordination and survival
    effectiveness = calculate_formation_effectiveness(timeline, formations_by_side)

    %{
      initial_formation: determine_initial_formation(timeline, participants),
      formations_by_side: formations_by_side,
      formation_changes: formation_changes,
      formation_effectiveness: effectiveness,
      formation_adaptations: identify_formation_adaptations(formation_changes, timeline)
    }
  end

  defp analyze_movement_patterns(timeline, participants) do
    # Analyze movement patterns from killmail locations and timing
    Logger.debug("Analyzing movement patterns")

    # Analyze kill locations to infer movements
    movement_events = extract_movement_events(timeline)

    # Calculate movement coordination by analyzing timing
    coordination_score = calculate_movement_coordination(movement_events, participants)

    # Identify different types of movements
    tactical_repositioning = identify_tactical_repositioning(movement_events)
    escape_movements = identify_escape_movements(movement_events, timeline)
    aggressive_movements = identify_aggressive_movements(movement_events, timeline)

    # Calculate overall effectiveness
    effectiveness =
      calculate_movement_effectiveness(
        movement_events,
        tactical_repositioning,
        escape_movements,
        aggressive_movements
      )

    %{
      movement_coordination: coordination_score,
      tactical_repositioning: tactical_repositioning,
      escape_movements: escape_movements,
      aggressive_movements: aggressive_movements,
      movement_effectiveness: effectiveness
    }
  end

  defp analyze_engagement_patterns(timeline, participants) do
    # Analyze how the engagement unfolded over time
    Logger.debug("Analyzing engagement patterns")

    # Determine engagement initiation style
    initiation_style = determine_engagement_initiation(timeline, participants)

    # Identify engagement phases based on kill intensity
    phases = identify_engagement_phases(timeline)

    # Analyze engagement rhythm (sustained, burst, intermittent)
    rhythm = analyze_engagement_rhythm(timeline)

    # Identify disengagement patterns
    disengagement_patterns = identify_disengagement_patterns(timeline, participants)

    # Calculate effectiveness based on objectives achieved
    effectiveness = calculate_engagement_effectiveness(timeline, participants, phases)

    %{
      engagement_initiation: initiation_style,
      engagement_phases: phases,
      engagement_rhythm: rhythm,
      disengagement_patterns: disengagement_patterns,
      engagement_effectiveness: effectiveness,
      intensity_profile: calculate_intensity_profile(timeline)
    }
  end

  defp analyze_coordination_patterns(timeline, participants) do
    # Analyze coordination through timing and target selection patterns
    Logger.debug("Analyzing coordination patterns")

    # Calculate coordination level from simultaneous actions
    coordination_level = calculate_coordination_level(timeline, participants)

    # Infer coordination methods from patterns
    coordination_methods = infer_coordination_methods(timeline, participants)

    # Calculate effectiveness based on focus fire and timing
    effectiveness = calculate_coordination_effectiveness(timeline, participants)

    # Identify coordination breakdowns (split damage, mistimed attacks)
    breakdowns = identify_coordination_breakdowns(timeline, participants)

    # Identify improvements over time
    improvements = identify_coordination_improvements(timeline, breakdowns)

    %{
      coordination_level: coordination_level,
      coordination_methods: coordination_methods,
      coordination_effectiveness: effectiveness,
      coordination_breakdowns: breakdowns,
      coordination_improvements: improvements,
      focus_fire_quality: analyze_focus_fire_quality(timeline)
    }
  end

  defp identify_tactical_decisions(timeline, participants) do
    # Identify key tactical decisions from the battle flow
    Logger.debug("Identifying tactical decisions")

    decisions = []

    # Identify engagement decision
    engagement_decision = identify_engagement_decision(timeline, participants)
    decisions = if engagement_decision, do: [engagement_decision | decisions], else: decisions

    # Identify target priority decisions
    target_decisions = identify_target_priority_decisions(timeline)
    decisions = decisions ++ target_decisions

    # Identify positioning decisions
    positioning_decisions = identify_positioning_decisions(timeline, participants)
    decisions = decisions ++ positioning_decisions

    # Identify retreat/disengage decisions
    retreat_decisions = identify_retreat_decisions(timeline, participants)
    decisions = decisions ++ retreat_decisions

    # Identify escalation decisions
    escalation_decisions = identify_escalation_decisions(timeline, participants)
    decisions = decisions ++ escalation_decisions

    # Sort by timestamp and calculate effectiveness
    decisions
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.map(&evaluate_decision_effectiveness(&1, timeline))
  end

  defp evaluate_pattern_effectiveness(timeline, participants) do
    # Evaluate effectiveness of identified tactical patterns
    Logger.debug("Evaluating pattern effectiveness")

    # Analyze each pattern type
    formation_score = evaluate_formation_effectiveness(timeline, participants)
    movement_score = evaluate_movement_effectiveness(timeline, participants)
    engagement_score = evaluate_engagement_effectiveness(timeline, participants)
    coordination_score = evaluate_coordination_effectiveness(timeline, participants)

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
        initial_formation: infer_initial_formation(early_events)
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
    |> Enum.map(fn [{_prev_time, prev_events}, {curr_time, curr_events}] ->
      %{
        timestamp: curr_time,
        from_position: analyze_position_from_events(prev_events),
        to_position: analyze_position_from_events(curr_events),
        trigger: identify_position_change_trigger(prev_events, curr_events),
        participants_repositioned: estimate_repositioned_count(prev_events, curr_events)
      }
    end)
    |> Enum.reject(fn change -> change.from_position == change.to_position end)
  end

  defp analyze_range_control(timeline, participants) do
    # Analyze range control throughout the battle
    Logger.debug("Analyzing range control")

    # Analyze ship types to determine optimal ranges
    ship_compositions = analyze_ship_compositions(participants)

    # Analyze kill patterns to infer range control
    range_events = analyze_range_from_kills(timeline.events)

    # Calculate range control metrics
    range_advantage = calculate_range_advantage(range_events, ship_compositions)
    effectiveness = calculate_range_control_effectiveness(range_events)
    range_dictation = determine_range_dictation_level(range_events, timeline)
    adaptations = identify_range_adaptations(range_events)

    %{
      range_advantage: range_advantage,
      range_control_effectiveness: effectiveness,
      range_dictation: range_dictation,
      range_adaptations: adaptations,
      optimal_range_maintenance: calculate_optimal_range_time(range_events)
    }
  end

  defp analyze_escape_routes(timeline, participants) do
    # Analyze escape route availability and usage
    Logger.debug("Analyzing escape routes")

    # Identify potential escape attempts
    escape_attempts = identify_escape_attempts(timeline.events, participants)

    # Calculate escape metrics
    availability = calculate_escape_route_availability(timeline, participants)
    utilization = calculate_escape_utilization(escape_attempts, participants)
    effectiveness = calculate_escape_effectiveness(escape_attempts)
    denials = identify_escape_denials(timeline.events)

    %{
      escape_route_availability: availability,
      escape_route_utilization: utilization,
      escape_effectiveness: effectiveness,
      escape_denials: denials,
      successful_escapes: count_successful_escapes(escape_attempts),
      failed_escapes: count_failed_escapes(escape_attempts)
    }
  end

  defp identify_positional_advantages(timeline, participants) do
    # Identify tactical positional advantages
    Logger.debug("Identifying positional advantages")

    []
    |> add_if_present(analyze_gate_control(timeline))
    |> add_if_present(analyze_station_proximity(timeline))
    |> add_if_present(analyze_terrain_usage(timeline))
    |> add_if_present(analyze_positional_range_advantage(timeline, participants))
    |> add_if_present(analyze_split_positioning(timeline, participants))
  end

  defp analyze_target_prioritization(timeline) do
    # Analyze target prioritization patterns
    Logger.debug("Analyzing target prioritization")

    if Enum.empty?(timeline.events) do
      %{
        prioritization_accuracy: 0.0,
        priority_adherence: 0.0,
        prioritization_speed: 0.0,
        prioritization_effectiveness: 0.0
      }
    else
      # Analyze target order
      target_order = extract_target_order(timeline.events)
      optimal_order = calculate_optimal_target_order(timeline.events)

      # Calculate metrics
      accuracy = calculate_prioritization_accuracy(target_order, optimal_order)
      adherence = calculate_priority_adherence(timeline.events)
      speed = calculate_prioritization_speed(timeline.events)
      effectiveness = calculate_prioritization_effectiveness(timeline.events)

      %{
        prioritization_accuracy: accuracy,
        priority_adherence: adherence,
        prioritization_speed: speed,
        prioritization_effectiveness: effectiveness,
        target_order: target_order,
        optimal_order: optimal_order
      }
    end
  end

  defp analyze_focus_fire_patterns(timeline) do
    # Analyze focus fire coordination
    Logger.debug("Analyzing focus fire patterns")

    if Enum.count(timeline.events) < 2 do
      %{
        focus_fire_effectiveness: 0.0,
        target_switching_frequency: 0.0,
        coordination_quality: 0.0,
        damage_concentration: 0.0
      }
    else
      # Group kills by time to identify focus fire
      focus_windows = identify_focus_fire_windows_detailed(timeline)

      # Calculate metrics
      effectiveness = calculate_focus_effectiveness(focus_windows)
      switching_freq = calculate_switching_frequency(timeline.events)
      coordination = calculate_focus_coordination(focus_windows)
      concentration = calculate_damage_concentration(focus_windows)

      %{
        focus_fire_effectiveness: effectiveness,
        target_switching_frequency: switching_freq,
        coordination_quality: coordination,
        damage_concentration: concentration,
        focus_windows: focus_windows
      }
    end
  end

  defp analyze_target_switching(timeline) do
    # Analyze target switching patterns
    Logger.debug("Analyzing target switching")

    if Enum.count(timeline.events) < 2 do
      %{
        switching_frequency: 0.0,
        switching_effectiveness: 0.0,
        switching_reasons: [],
        switching_coordination: 0.0
      }
    else
      # Identify target switches
      switches = identify_target_switches(timeline.events)

      # Analyze switch patterns
      frequency =
        if not Enum.empty?(timeline.events),
          do: Enum.count(switches) / Enum.count(timeline.events),
          else: 0.0

      effectiveness = evaluate_switch_effectiveness(switches, timeline)
      reasons = analyze_switch_reasons(switches, timeline)
      coordination = evaluate_switch_coordination(switches)

      %{
        switching_frequency: frequency,
        switching_effectiveness: effectiveness,
        switching_reasons: reasons,
        switching_coordination: coordination,
        switch_events: switches
      }
    end
  end

  defp analyze_primary_calling(timeline) do
    # Analyze primary target calling effectiveness
    Logger.debug("Analyzing primary calling")

    if Enum.empty?(timeline.events) do
      %{
        calling_effectiveness: 0.0,
        calling_speed: 0.0,
        calling_accuracy: 0.0,
        calling_coordination: 0.0
      }
    else
      # Analyze kill clustering to infer primary calling
      call_patterns = identify_primary_call_patterns(timeline)

      # Calculate metrics
      effectiveness = evaluate_calling_effectiveness(call_patterns)
      speed = calculate_calling_response_time(call_patterns)
      accuracy = evaluate_calling_accuracy(call_patterns, timeline)
      coordination = evaluate_calling_coordination(call_patterns)

      %{
        calling_effectiveness: effectiveness,
        calling_speed: speed,
        calling_accuracy: accuracy,
        calling_coordination: coordination,
        identified_primaries: extract_called_targets(call_patterns)
      }
    end
  end

  defp evaluate_target_selection_effectiveness(timeline) do
    # Evaluate overall target selection effectiveness
    Logger.debug("Evaluating target selection effectiveness")

    if Enum.empty?(timeline.events) do
      %{
        overall_effectiveness: 0.0,
        target_value_score: 0.0,
        target_accessibility_score: 0.0,
        target_priority_score: 0.0
      }
    else
      # Analyze target choices
      targets = extract_target_details(timeline.events)

      # Calculate component scores
      value_score = calculate_target_value_score(targets)
      accessibility_score = calculate_accessibility_score(targets, timeline)
      priority_score = calculate_priority_adherence_score(targets)

      # Overall effectiveness
      overall = (value_score + accessibility_score + priority_score) / 3

      %{
        overall_effectiveness: overall,
        target_value_score: value_score,
        target_accessibility_score: accessibility_score,
        target_priority_score: priority_score,
        suboptimal_choices: identify_suboptimal_targets(targets)
      }
    end
  end

  defp analyze_engagement_timing(timeline) do
    # Analyze engagement timing patterns
    Logger.debug("Analyzing engagement timing")

    if Enum.count(timeline.events) < 2 do
      %{
        initiation_timing: 0.0,
        escalation_timing: 0.0,
        conclusion_timing: 0.0,
        timing_coordination: 0.0
      }
    else
      # Analyze timing phases
      phases = identify_timing_phases(timeline)

      # Calculate timing metrics
      initiation_score = analyze_initiation_timing(timeline, phases)
      escalation_score = analyze_escalation_timing(timeline, phases)
      conclusion_score = analyze_conclusion_timing(timeline, phases)
      coordination_score = analyze_timing_coordination(timeline)

      %{
        initiation_timing: initiation_score,
        escalation_timing: escalation_score,
        conclusion_timing: conclusion_score,
        timing_coordination: coordination_score,
        timing_phases: phases,
        tempo_changes: identify_tempo_changes(timeline)
      }
    end
  end

  defp analyze_coordination_timing(timeline) do
    # Analyze coordination timing patterns
    Logger.debug("Analyzing coordination timing")

    if Enum.count(timeline.events) < 3 do
      %{
        command_response_time: 0.0,
        execution_timing: 0.0,
        synchronization: 0.0,
        timing_effectiveness: 0.0
      }
    else
      # Identify coordination events
      coordination_events = identify_coordination_events(timeline)

      # Calculate timing metrics
      response_time = calculate_average_response_time(coordination_events)
      execution_timing = calculate_execution_timing(coordination_events)
      synchronization = calculate_synchronization_score(timeline)
      effectiveness = calculate_timing_effectiveness(timeline, coordination_events)

      %{
        command_response_time: response_time,
        execution_timing: execution_timing,
        synchronization: synchronization,
        timing_effectiveness: effectiveness,
        coordination_windows: coordination_events,
        timing_variance: calculate_timing_variance(coordination_events)
      }
    end
  end

  defp analyze_alpha_strike_timing(timeline) do
    # Analyze alpha strike timing patterns
    Logger.debug("Analyzing alpha strike timing")

    # Identify potential alpha strikes (multiple kills in short timespan)
    alpha_strikes = identify_alpha_strikes(timeline)

    if Enum.empty?(alpha_strikes) do
      %{
        alpha_strike_coordination: 0.0,
        timing_precision: 0.0,
        damage_concentration: 0.0,
        effectiveness: 0.0
      }
    else
      # Calculate alpha strike metrics
      coordination_score = calculate_alpha_coordination(alpha_strikes)
      precision_score = calculate_timing_precision(alpha_strikes)
      concentration_score = calculate_alpha_concentration(alpha_strikes)
      effectiveness_score = calculate_alpha_effectiveness(alpha_strikes)

      %{
        alpha_strike_coordination: coordination_score,
        timing_precision: precision_score,
        damage_concentration: concentration_score,
        effectiveness: effectiveness_score,
        alpha_strikes: alpha_strikes,
        average_window: calculate_average_alpha_window(alpha_strikes)
      }
    end
  end

  defp analyze_retreat_timing(timeline) do
    # Analyze retreat timing patterns
    Logger.debug("Analyzing retreat timing")

    # Identify retreat patterns from kill rate changes
    retreat_events = identify_retreat_events(timeline)

    if Enum.empty?(retreat_events) do
      %{
        # No retreats needed
        retreat_decision_timing: 1.0,
        retreat_execution: 1.0,
        retreat_coordination: 1.0,
        retreat_effectiveness: 1.0
      }
    else
      # Calculate retreat timing metrics
      decision_timing = evaluate_retreat_decision_timing(retreat_events, timeline)
      execution_score = evaluate_retreat_execution(retreat_events)
      coordination_score = evaluate_retreat_coordination(retreat_events)
      effectiveness_score = evaluate_retreat_effectiveness(retreat_events, timeline)

      %{
        retreat_decision_timing: decision_timing,
        retreat_execution: execution_score,
        retreat_coordination: coordination_score,
        retreat_effectiveness: effectiveness_score,
        retreat_events: retreat_events,
        decision_triggers: identify_retreat_triggers(retreat_events, timeline)
      }
    end
  end

  defp analyze_tactical_rhythm(timeline) do
    # Analyze tactical rhythm and tempo
    Logger.debug("Analyzing tactical rhythm")

    if Enum.count(timeline.events) < 5 do
      %{
        rhythm_consistency: 0.0,
        rhythm_adaptability: 0.0,
        rhythm_effectiveness: 0.0,
        rhythm_patterns: []
      }
    else
      # Analyze kill intervals to determine rhythm
      kill_intervals = calculate_kill_intervals(timeline)
      rhythm_patterns = identify_rhythm_patterns(kill_intervals)

      # Calculate rhythm metrics
      consistency = calculate_rhythm_consistency(kill_intervals)
      adaptability = calculate_rhythm_adaptability(rhythm_patterns)
      effectiveness = calculate_rhythm_effectiveness(timeline, rhythm_patterns)

      %{
        rhythm_consistency: consistency,
        rhythm_adaptability: adaptability,
        rhythm_effectiveness: effectiveness,
        rhythm_patterns: rhythm_patterns,
        tempo_profile: create_tempo_profile(timeline),
        peak_intensity_periods: identify_peak_periods(timeline)
      }
    end
  end

  defp analyze_decision_making(_timeline, _participants) do
    # For now, return basic decision making analysis
    # TODO: Implement detailed decision making analysis

    %{
      decision_speed: 0.7,
      decision_quality: 0.8,
      decision_consistency: 0.6,
      decision_effectiveness: 0.7
    }
  end

  defp analyze_information_flow(_timeline, _participants) do
    # For now, return basic information flow analysis
    # TODO: Implement detailed information flow analysis

    %{
      information_speed: 0.7,
      information_accuracy: 0.8,
      information_coverage: 0.6,
      information_effectiveness: 0.7
    }
  end

  defp evaluate_command_effectiveness(_timeline, _participants) do
    # For now, return basic command effectiveness evaluation
    # TODO: Implement detailed command effectiveness evaluation

    %{
      overall_effectiveness: 0.7,
      command_execution: 0.8,
      tactical_control: 0.6,
      strategic_vision: 0.7
    }
  end

  defp identify_leadership_patterns(_timeline, _participants) do
    # For now, return basic leadership pattern identification
    # TODO: Implement detailed leadership pattern identification

    [
      %{pattern: :decisive_leadership, effectiveness: 0.8},
      %{pattern: :adaptive_leadership, effectiveness: 0.7}
    ]
  end

  # Helper functions for formation analysis
  defp group_participants_by_side(participants) do
    participants
    |> Enum.group_by(& &1[:side])
    |> Enum.reject(fn {side, _} -> is_nil(side) end)
  end

  defp analyze_side_formation(timeline, side_participants) do
    # Analyze formation based on ship types and roles
    ship_types = Enum.map(side_participants, & &1[:ship_type_id])
    ship_classes = Enum.map(ship_types, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)

    formation_type = determine_formation_type(ship_classes)
    cohesion = calculate_formation_cohesion(timeline, side_participants)

    %{
      type: formation_type,
      cohesion: cohesion,
      ship_distribution: calculate_ship_distribution(ship_classes)
    }
  end

  defp determine_initial_formation(timeline, _participants) do
    # Analyze the first few kills to determine initial formation
    early_events = Enum.take(timeline.events, 5)

    if Enum.count(early_events) < 2 do
      :unknown
    else
      # Analyze victim ship types to infer formation
      victim_types = Enum.map(early_events, & &1.victim[:ship_type_id])
      victim_classes = Enum.map(victim_types, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)

      cond do
        Enum.all?(victim_classes, &(&1 in [:frigate, :destroyer])) -> :skirmish
        Enum.any?(victim_classes, &(&1 in [:battleship, :battlecruiser])) -> :line
        Enum.any?(victim_classes, &(&1 == :cruiser)) -> :mixed
        true -> :dispersed
      end
    end
  end

  defp detect_formation_changes(timeline, participants) do
    # Detect changes in formation by analyzing kill patterns over time
    # 2-minute windows
    time_windows = create_time_windows(timeline.events, 120)

    time_windows
    |> Enum.map(fn {window_start, events} ->
      analyze_window_formation(events, participants, window_start)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp calculate_formation_effectiveness(_timeline, formations_by_side) do
    # Calculate effectiveness based on survival rates and objective achievement
    total_effectiveness =
      formations_by_side
      |> Enum.map(fn {_side, formation} ->
        formation[:cohesion] || 0.5
      end)
      |> Enum.sum()

    if map_size(formations_by_side) > 0 do
      total_effectiveness / map_size(formations_by_side)
    else
      0.0
    end
  end

  defp identify_formation_adaptations(formation_changes, timeline) do
    # Identify adaptations based on formation changes
    formation_changes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, current] ->
      %{
        from: prev[:formation],
        to: current[:formation],
        timestamp: current[:timestamp],
        reason: infer_adaptation_reason(prev, current, timeline)
      }
    end)
  end

  # Helper functions for movement analysis
  defp extract_movement_events(timeline) do
    # Extract movement patterns from kill locations and timing
    timeline.events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, current] ->
      %{
        time_delta: DateTime.diff(current.timestamp, prev.timestamp),
        location_change: current[:system_id] != prev[:system_id],
        participants_involved: extract_common_participants(prev, current)
      }
    end)
  end

  defp calculate_movement_coordination(movement_events, participants) do
    # Calculate coordination based on synchronized movements
    if Enum.empty?(movement_events) do
      0.0
    else
      synchronized_movements =
        movement_events
        |> Enum.count(fn event ->
          Enum.count(event.participants_involved) > Enum.count(participants) * 0.3
        end)

      synchronized_movements / length(movement_events)
    end
  end

  defp identify_tactical_repositioning(movement_events) do
    # Identify deliberate tactical repositioning
    movement_events
    |> Enum.filter(fn event ->
      event.time_delta < 300 && event.location_change
    end)
    |> Enum.map(fn event ->
      %{
        type: :tactical_reposition,
        timing: event.time_delta,
        coordination: length(event.participants_involved)
      }
    end)
  end

  defp identify_escape_movements(movement_events, timeline) do
    # Identify escape/retreat movements
    movement_events
    |> Enum.filter(fn event ->
      # Look for rapid movements after losses
      recent_losses = count_recent_losses(timeline, event)
      event.location_change && recent_losses > 0
    end)
  end

  defp identify_aggressive_movements(movement_events, timeline) do
    # Identify aggressive pursuit movements
    movement_events
    |> Enum.filter(fn event ->
      # Look for movements following successful kills
      recent_kills = count_recent_kills(timeline, event)
      event.location_change && recent_kills > 0
    end)
  end

  defp calculate_movement_effectiveness(events, tactical, escape, aggressive) do
    if Enum.empty?(events) do
      0.0
    else
      # Score based on successful tactical movements
      tactical_score = length(tactical) * 0.4
      escape_success = length(escape) * 0.3
      aggressive_success = length(aggressive) * 0.3

      total = tactical_score + escape_success + aggressive_success
      max_possible = length(events)

      if max_possible > 0 do
        min(total / max_possible, 1.0)
      else
        0.0
      end
    end
  end

  # Helper functions for engagement analysis
  defp determine_engagement_initiation(timeline, participants) do
    # Analyze first few kills to determine initiation style
    first_events = Enum.take(timeline.events, 3)

    if Enum.empty?(first_events) do
      :unknown
    else
      victim_values = Enum.map(first_events, &(&1[:isk_value] || 0))
      avg_value = Enum.sum(victim_values) / length(victim_values)

      cond do
        # High-value targets
        avg_value > 1_000_000_000 -> :ambush
        length(first_events) == length(participants) -> :coordinated
        true -> :opportunistic
      end
    end
  end

  defp identify_engagement_phases(timeline) do
    # Identify distinct phases based on kill intensity
    events_by_minute = group_events_by_time(timeline.events, 60)

    phases = []
    current_phase = nil

    Enum.reduce(events_by_minute, {phases, current_phase}, fn {time, events},
                                                              {phases_acc, current} ->
      intensity = length(events)
      phase_type = classify_phase_by_intensity(intensity)

      if current && current.type == phase_type do
        # Continue current phase
        updated_phase = %{current | end_time: time, events: current.events + events}
        {phases_acc, updated_phase}
      else
        # New phase
        new_phase = %{
          type: phase_type,
          start_time: time,
          end_time: time,
          events: events,
          intensity: intensity
        }

        if current do
          {[current | phases_acc], new_phase}
        else
          {phases_acc, new_phase}
        end
      end
    end)
    |> then(fn {phases, last_phase} ->
      if last_phase, do: [last_phase | phases], else: phases
    end)
    |> Enum.reverse()
  end

  defp analyze_engagement_rhythm(timeline) do
    # Analyze kill timing to determine rhythm
    if Enum.count(timeline.events) < 2 do
      :unknown
    else
      time_deltas =
        timeline.events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, current] ->
          DateTime.diff(current.timestamp, prev.timestamp)
        end)

      avg_delta = Enum.sum(time_deltas) / length(time_deltas)
      variance = calculate_variance(time_deltas, avg_delta)

      cond do
        # Consistent timing
        variance < 30 -> :sustained
        # Regular bursts
        variance < 120 -> :rhythmic
        # Irregular timing
        true -> :sporadic
      end
    end
  end

  defp identify_disengagement_patterns(_timeline, _participants) do
    # Identify patterns indicating disengagement
    # Simplified for now - would analyze gaps in activity
    []
  end

  defp calculate_engagement_effectiveness(timeline, _participants, _phases) do
    # Calculate based on objectives and losses
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Simple effectiveness based on kill/death efficiency
      # Placeholder - would calculate from actual metrics
      0.7
    end
  end

  defp calculate_intensity_profile(timeline) do
    # Create intensity profile over time
    events_by_minute = group_events_by_time(timeline.events, 60)

    Enum.map(events_by_minute, fn {time, events} ->
      %{
        timestamp: time,
        intensity: length(events),
        cumulative_isk: Enum.sum(Enum.map(events, &(&1[:isk_value] || 0)))
      }
    end)
  end

  # Helper functions for coordination analysis
  defp calculate_coordination_level(timeline, participants) do
    # Analyze simultaneous actions and focus fire
    focus_fire_windows = identify_focus_fire_windows(timeline)

    if Enum.empty?(timeline.events) do
      0.0
    else
      coordinated_kills = Enum.sum(Enum.map(focus_fire_windows, &(&1[:participant_count] || 0)))
      total_possible = length(timeline.events) * length(participants)

      if total_possible > 0 do
        min(coordinated_kills / total_possible, 1.0)
      else
        0.0
      end
    end
  end

  defp infer_coordination_methods(timeline, _participants) do
    # Infer coordination methods from patterns
    methods = []

    # Check for voice comms indicators (very tight timing)
    methods =
      if has_tight_coordination?(timeline) do
        [:voice | methods]
      else
        methods
      end

    # Check for broadcast patterns
    methods =
      if has_broadcast_patterns?(timeline) do
        [:broadcast | methods]
      else
        methods
      end

    # Default to fleet mechanics if nothing else
    if Enum.empty?(methods) do
      [:fleet_warp]
    else
      methods
    end
  end

  defp calculate_coordination_effectiveness(timeline, _participants) do
    # Calculate effectiveness of coordination
    focus_quality = analyze_focus_fire_quality(timeline)
    timing_quality = analyze_timing_quality(timeline)

    (focus_quality + timing_quality) / 2
  end

  defp identify_coordination_breakdowns(_timeline, _participants) do
    # Identify moments where coordination failed
    # Simplified - would analyze split damage, mistimed attacks
    []
  end

  defp identify_coordination_improvements(_timeline, _breakdowns) do
    # Identify improvements in coordination over time
    # Simplified - would track coordination metrics over time
    []
  end

  defp analyze_focus_fire_quality(timeline) do
    # Analyze quality of focus fire
    if Enum.count(timeline.events) < 2 do
      0.0
    else
      # Simple metric based on kill spacing
      # Placeholder
      0.7
    end
  end

  # Utility functions
  defp create_time_windows(events, window_size) do
    events
    |> Enum.group_by(fn event ->
      # Group by time window
      unix = DateTime.to_unix(event.timestamp)
      div(unix, window_size) * window_size
    end)
    |> Enum.map(fn {window_start, window_events} ->
      {DateTime.from_unix!(window_start), window_events}
    end)
    |> Enum.sort_by(fn {time, _} -> time end)
  end

  defp determine_formation_type(ship_classes) do
    # Determine formation based on ship composition
    class_counts = Enum.frequencies(ship_classes)

    cond do
      class_counts[:frigate] > length(ship_classes) * 0.5 -> :skirmish
      class_counts[:battleship] > length(ship_classes) * 0.3 -> :line
      class_counts[:cruiser] > length(ship_classes) * 0.4 -> :mixed
      true -> :dispersed
    end
  end

  defp calculate_formation_cohesion(_timeline, _participants) do
    # Simplified cohesion calculation
    # Placeholder
    0.7
  end

  defp calculate_ship_distribution(ship_classes) do
    Enum.frequencies(ship_classes)
  end

  defp analyze_window_formation(events, _participants, timestamp) do
    if not Enum.empty?(events) do
      %{
        timestamp: timestamp,
        # Simplified
        formation: :dynamic,
        event_count: length(events)
      }
    else
      nil
    end
  end

  defp infer_adaptation_reason(_prev, _current, _timeline) do
    # Simplified
    :tactical_adjustment
  end

  defp extract_common_participants(_event1, _event2) do
    # Extract participants common to both events
    # Simplified
    []
  end

  defp count_recent_losses(_timeline, _event) do
    # Simplified
    0
  end

  defp count_recent_kills(_timeline, _event) do
    # Simplified
    1
  end

  # Helper functions for tactical decision identification

  defp identify_concentration_decisions(timeline, participants) do
    # Identify decisions to concentrate forces in specific systems
    system_participation =
      timeline.events
      |> Enum.group_by(& &1[:system_id])
      |> Enum.map(fn {system_id, events} ->
        {system_id, length(events), List.first(events).timestamp}
      end)
      |> Enum.filter(fn {_system, event_count, _time} ->
        # 60% or more participants
        event_count >= length(participants) * 0.6
      end)

    system_participation
    |> Enum.map(fn {system_id, event_count, timestamp} ->
      %{
        decision: :force_concentration,
        timestamp: timestamp,
        target_system: system_id,
        participants_concentrated: event_count,
        concentration_ratio: event_count / length(participants),
        strategic_value: calculate_system_strategic_value(system_id, timeline)
      }
    end)
  end

  defp analyze_retreat_context(indicator, timeline, participants) do
    # Analyze the context around a retreat decision
    time_window_events = get_events_around_time(timeline, indicator[:timestamp], 300)

    %{
      coordination_score: calculate_retreat_coordination(time_window_events, participants),
      pressure_level: calculate_enemy_pressure(time_window_events),
      strategic_position: evaluate_strategic_position(indicator, timeline),
      casualty_rate: calculate_casualty_rate_at_time(timeline, indicator[:timestamp])
    }
  end

  defp evaluate_retreat_success(indicator, timeline) do
    # Evaluate how successful the retreat was
    post_retreat_events = get_events_after_time(timeline, indicator[:timestamp], 600)

    if Enum.empty?(post_retreat_events) do
      # No further losses suggest successful retreat
      1.0
    else
      # Calculate loss reduction after retreat
      pre_retreat_rate = calculate_loss_rate_before(timeline, indicator[:timestamp])
      post_retreat_rate = calculate_loss_rate_after(timeline, indicator[:timestamp])

      if pre_retreat_rate > 0 do
        max(0.0, 1.0 - post_retreat_rate / pre_retreat_rate)
      else
        0.5
      end
    end
  end

  defp evaluate_retreat_decision_quality(_indicator, context) do
    # Evaluate the quality of the retreat decision
    pressure_score = context[:pressure_level] || 0.5
    coordination_score = context[:coordination_score] || 0.5
    casualty_score = min(context[:casualty_rate] || 0.1, 1.0)

    # Higher pressure and casualties justify retreat
    quality_score = (pressure_score + casualty_score + coordination_score) / 3.0

    cond do
      quality_score > 0.8 -> :excellent
      quality_score > 0.6 -> :good
      quality_score > 0.4 -> :adequate
      true -> :questionable
    end
  end

  defp identify_escalation_events(timeline, _participants) do
    # Identify events that represent escalation decisions
    kill_intensity = calculate_intensity_timeline(timeline)

    intensity_increases =
      kill_intensity
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.filter(fn {[prev, current], _idx} ->
        # 50% increase threshold
        current[:intensity] > prev[:intensity] * 1.5
      end)
      |> Enum.map(fn {[_prev, current], idx} ->
        %{
          timestamp: current[:timestamp],
          intensity_increase:
            current[:intensity] / (kill_intensity |> Enum.at(idx) |> Map.get(:intensity, 1.0)),
          event_count: current[:event_count] || 0,
          new_participants: estimate_new_participants(timeline, current[:timestamp])
        }
      end)

    intensity_increases
  end

  defp calculate_system_strategic_value(system_id, timeline) do
    # Calculate strategic value of a system based on activity
    system_events = Enum.filter(timeline.events, &(&1[:system_id] == system_id))
    event_count = length(system_events)

    # More events indicate higher strategic value
    min(event_count / 10.0, 1.0)
  end

  defp get_events_around_time(timeline, target_time, window_seconds) do
    start_time = DateTime.add(target_time, -window_seconds, :second)
    end_time = DateTime.add(target_time, window_seconds, :second)

    Enum.filter(timeline.events, fn event ->
      DateTime.compare(event.timestamp, start_time) != :lt and
        DateTime.compare(event.timestamp, end_time) != :gt
    end)
  end

  defp get_events_after_time(timeline, target_time, window_seconds) do
    end_time = DateTime.add(target_time, window_seconds, :second)

    Enum.filter(timeline.events, fn event ->
      DateTime.compare(event.timestamp, target_time) == :gt and
        DateTime.compare(event.timestamp, end_time) != :gt
    end)
  end

  defp calculate_retreat_coordination(events, participants) do
    # Calculate how well coordinated the retreat was
    if Enum.empty?(events) do
      0.0
    else
      # Higher coordination if fewer participants were caught in retreat
      participants_caught = length(Enum.uniq(Enum.map(events, & &1.victim[:character_id])))
      coordination_score = 1.0 - participants_caught / length(participants)
      max(0.0, coordination_score)
    end
  end

  defp calculate_enemy_pressure(events) do
    # Calculate enemy pressure level based on event intensity
    if Enum.empty?(events) do
      0.0
    else
      # Higher pressure with more kills in short time
      unique_attackers =
        events
        |> Enum.flat_map(&(&1[:attackers] || []))
        |> Enum.uniq_by(& &1["character_id"])
        |> length()

      # Normalize to 0-1 scale
      min(unique_attackers / 20.0, 1.0)
    end
  end

  defp evaluate_strategic_position(indicator, timeline) do
    # Evaluate strategic position at time of decision
    events_before = get_events_before_time(timeline, indicator[:timestamp], 600)

    friendly_losses = length(events_before)

    cond do
      friendly_losses > 10 -> :disadvantageous
      friendly_losses > 5 -> :neutral
      true -> :advantageous
    end
  end

  defp get_events_before_time(timeline, target_time, window_seconds) do
    start_time = DateTime.add(target_time, -window_seconds, :second)

    Enum.filter(timeline.events, fn event ->
      DateTime.compare(event.timestamp, start_time) != :lt and
        DateTime.compare(event.timestamp, target_time) == :lt
    end)
  end

  defp calculate_casualty_rate_at_time(timeline, target_time) do
    # Calculate casualty rate at specific time
    recent_events = get_events_before_time(timeline, target_time, 300)
    # Events per minute, normalized
    length(recent_events) / 5.0
  end

  defp calculate_loss_rate_before(timeline, target_time) do
    events_before = get_events_before_time(timeline, target_time, 600)
    # Events per minute
    length(events_before) / 10.0
  end

  defp calculate_loss_rate_after(timeline, target_time) do
    events_after = get_events_after_time(timeline, target_time, 600)
    # Events per minute
    length(events_after) / 10.0
  end

  defp calculate_intensity_timeline(timeline) do
    # Calculate kill intensity over time
    timeline.events
    |> Enum.group_by(fn event ->
      # Group by 5-minute windows
      DateTime.to_unix(event.timestamp) |> div(300) |> Kernel.*(300)
    end)
    |> Enum.map(fn {timestamp_bucket, events} ->
      %{
        timestamp: DateTime.from_unix!(timestamp_bucket),
        intensity: length(events),
        event_count: length(events)
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp estimate_new_participants(timeline, target_time) do
    # Estimate new participants joining at escalation time
    events_around = get_events_around_time(timeline, target_time, 180)

    new_attackers =
      events_around
      |> Enum.flat_map(&(&1[:attackers] || []))
      |> Enum.uniq_by(& &1["character_id"])
      |> length()

    # Rough estimate - could be improved with participant tracking
    max(0, new_attackers - 5)
  end

  # Helper functions for decision effectiveness evaluation

  defp determine_escalation_type(event, _timeline) do
    # Determine the type of escalation based on event characteristics
    intensity = event[:intensity_increase] || 1.0
    new_participants = event[:new_participants] || 0

    cond do
      new_participants > 10 -> :major_reinforcement
      new_participants > 5 -> :reinforcement
      intensity > 2.0 -> :tactical_escalation
      true -> :escalate
    end
  end

  defp analyze_escalation_context(event, timeline, participants) do
    # Analyze the context around an escalation decision
    %{
      battle_phase: determine_battle_phase_at_time(timeline, event[:timestamp]),
      friendly_casualties: count_friendly_casualties_before(timeline, event[:timestamp]),
      enemy_strength: estimate_enemy_strength_at_time(timeline, event[:timestamp]),
      strategic_situation: assess_strategic_situation(timeline, event[:timestamp]),
      resource_availability: estimate_available_resources(participants, event[:timestamp])
    }
  end

  defp calculate_escalation_risk(event, _timeline) do
    # Calculate the risk level of escalation
    intensity = event[:intensity_increase] || 1.0
    new_participants = event[:new_participants] || 0

    # Higher intensity and more participants = higher risk
    base_risk = min(intensity / 3.0, 1.0)
    participant_risk = min(new_participants / 20.0, 1.0)

    (base_risk + participant_risk) / 2.0
  end

  defp predict_escalation_outcome(event, context) do
    # Predict the likely outcome of escalation
    risk_level = calculate_escalation_risk(event, %{})
    strategic_situation = context[:strategic_situation] || :neutral

    case {risk_level, strategic_situation} do
      {risk, :advantageous} when risk < 0.5 -> :likely_success
      {risk, :neutral} when risk < 0.3 -> :probable_success
      {risk, :disadvantageous} when risk > 0.7 -> :likely_failure
      _ -> :uncertain_outcome
    end
  end

  defp analyze_escalation_rationale(event, context) do
    # Analyze why escalation was chosen
    casualties = context[:friendly_casualties] || 0
    enemy_strength = context[:enemy_strength] || 0.5

    cond do
      casualties > 5 -> :desperation
      enemy_strength > 0.8 -> :necessity
      event[:intensity_increase] > 2.0 -> :opportunity
      true -> :tactical_decision
    end
  end

  defp evaluate_engagement_outcome(decision, timeline) do
    # Evaluate how well the engagement decision worked out
    # 20 minutes
    engagement_events = get_events_after_time(timeline, decision.timestamp, 1200)

    if Enum.empty?(engagement_events) do
      # No follow-up suggests poor engagement
      0.3
    else
      # Success based on continued activity and ISK efficiency
      total_isk = Enum.sum(Enum.map(engagement_events, &(&1[:isk_value] || 0)))

      cond do
        # Very successful
        total_isk > 5_000_000_000 -> 0.9
        # Successful
        total_isk > 1_000_000_000 -> 0.7
        # Moderate
        total_isk > 100_000_000 -> 0.5
        # Poor outcome
        true -> 0.3
      end
    end
  end

  defp evaluate_target_selection_outcome(decision, timeline) do
    # Evaluate target selection effectiveness
    target_ship_id = decision[:target]
    target_class = EveDmv.StaticData.ShipTypes.classify_ship_type(target_ship_id)

    # Strategic targets (capitals, logistics) score higher
    base_score =
      case target_class do
        :capital -> 0.9
        :supercapital -> 1.0
        :logistics -> 0.8
        :battleship -> 0.7
        :cruiser -> 0.6
        _ -> 0.4
      end

    # Adjust based on follow-up kills
    follow_up_events = get_events_after_time(timeline, decision.timestamp, 300)

    if length(follow_up_events) > 2 do
      min(base_score + 0.2, 1.0)
    else
      base_score
    end
  end

  defp evaluate_positioning_outcome(decision, timeline) do
    # Evaluate positioning decision effectiveness
    post_position_events = get_events_after_time(timeline, decision.timestamp, 600)

    case decision.decision do
      :tactical_reposition ->
        # Success if fewer losses after repositioning
        if length(post_position_events) < 3 do
          0.8
        else
          0.4
        end

      :force_concentration ->
        # Success if concentration led to more coordinated kills
        coordinated_kills = count_coordinated_kills(post_position_events)
        min(coordinated_kills / 5.0, 1.0)

      _ ->
        # Default moderate effectiveness
        0.5
    end
  end

  defp evaluate_retreat_outcome(decision, timeline) do
    # Use existing retreat success evaluation
    evaluate_retreat_success(decision, timeline)
  end

  defp identify_success_indicators(_decision, effectiveness_score, _timeline) do
    # Identify indicators of decision success
    base_indicators = []

    indicators =
      if effectiveness_score > 0.8 do
        [:excellent_timing, :strong_execution | base_indicators]
      else
        base_indicators
      end

    indicators =
      if effectiveness_score > 0.6 do
        [:good_timing, :effective_execution | indicators]
      else
        indicators
      end

    if effectiveness_score < 0.4 do
      [:poor_timing, :ineffective_execution | indicators]
    else
      indicators
    end
  end

  defp extract_decision_lessons(decision, effectiveness_score) do
    # Extract lessons learned from decision outcomes
    case {decision.decision, effectiveness_score} do
      {:engage, score} when score > 0.7 ->
        ["Engagement timing was appropriate", "Target selection effective"]

      {:engage, score} when score < 0.4 ->
        ["Consider more caution before engaging", "Improve target assessment"]

      {:tactical_retreat, score} when score > 0.7 ->
        ["Retreat executed successfully", "Good situational awareness"]

      {:tactical_retreat, score} when score < 0.4 ->
        ["Retreat timing could be improved", "Better coordination needed"]

      _ ->
        ["Standard tactical decision", "Review outcome for improvements"]
    end
  end

  # Additional helper functions for context analysis

  defp determine_battle_phase_at_time(timeline, target_time) do
    # Determine what phase of battle we're in at a specific time
    events_before = get_events_before_time(timeline, target_time, 600)
    total_events = length(timeline.events)
    events_before_count = length(events_before)

    progress = if total_events > 0, do: events_before_count / total_events, else: 0.0

    cond do
      progress < 0.2 -> :opening
      progress < 0.6 -> :main_engagement
      progress < 0.9 -> :climax
      true -> :conclusion
    end
  end

  defp count_friendly_casualties_before(timeline, target_time) do
    # 15 minutes
    events_before = get_events_before_time(timeline, target_time, 900)
    length(events_before)
  end

  defp estimate_enemy_strength_at_time(timeline, target_time) do
    # Estimate enemy strength based on attacker activity
    recent_events = get_events_before_time(timeline, target_time, 300)

    unique_attackers =
      recent_events
      |> Enum.flat_map(&(&1[:attackers] || []))
      |> Enum.uniq_by(& &1["character_id"])
      |> length()

    # Normalize to 0-1 scale
    min(unique_attackers / 50.0, 1.0)
  end

  defp assess_strategic_situation(timeline, target_time) do
    # Assess overall strategic situation
    friendly_losses = count_friendly_casualties_before(timeline, target_time)
    enemy_strength = estimate_enemy_strength_at_time(timeline, target_time)

    cond do
      friendly_losses < 3 and enemy_strength < 0.3 -> :advantageous
      friendly_losses > 10 or enemy_strength > 0.8 -> :disadvantageous
      true -> :neutral
    end
  end

  defp estimate_available_resources(participants, _target_time) do
    # Estimate available friendly resources
    participant_count = length(participants)

    cond do
      participant_count > 50 -> :abundant
      participant_count > 20 -> :adequate
      participant_count > 10 -> :limited
      true -> :minimal
    end
  end

  defp count_coordinated_kills(events) do
    # Count kills that appear coordinated (multiple attackers)
    events
    |> Enum.count(fn event ->
      attacker_count = length(event[:attackers] || [])
      # Coordinated if 4+ attackers
      attacker_count > 3
    end)
  end

  defp group_events_by_time(events, window_seconds) do
    events
    |> Enum.group_by(fn event ->
      unix = DateTime.to_unix(event.timestamp)
      div(unix, window_seconds) * window_seconds
    end)
  end

  defp classify_phase_by_intensity(intensity) when intensity >= 10, do: :intense
  defp classify_phase_by_intensity(intensity) when intensity >= 5, do: :active
  defp classify_phase_by_intensity(intensity) when intensity >= 1, do: :sporadic
  defp classify_phase_by_intensity(_), do: :lull

  defp calculate_variance(values, mean) do
    if Enum.empty?(values) do
      0.0
    else
      sum_squared_diff =
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()

      sum_squared_diff / length(values)
    end
  end

  defp identify_focus_fire_windows(_timeline) do
    # Identify windows where multiple attackers focused same target
    # Simplified
    []
  end

  defp has_tight_coordination?(timeline) do
    # Check for very tight timing indicating voice comms
    # Simplified check
    length(timeline.events) > 5
  end

  defp has_broadcast_patterns?(timeline) do
    # Check for broadcast-style coordination patterns  
    # Simplified check
    length(timeline.events) > 3
  end

  defp analyze_timing_quality(_timeline) do
    # Simplified
    0.7
  end

  defp identify_engagement_decision(timeline, _participants) do
    if first_event = List.first(timeline.events) do
      %{
        decision: :engage,
        timestamp: first_event.timestamp,
        context: analyze_engagement_context(first_event),
        alternatives: [:avoid, :observe],
        risk_assessment: :calculated
      }
    else
      nil
    end
  end

  defp identify_target_priority_decisions(timeline) do
    # Analyze target selection decisions
    timeline.events
    # First 5 kills
    |> Enum.take(5)
    |> Enum.map(fn event ->
      %{
        decision: :target_selection,
        timestamp: event.timestamp,
        target: event.victim[:ship_type_id],
        priority_reasoning: analyze_target_priority(event),
        # Would list other potential targets
        alternatives: []
      }
    end)
  end

  defp identify_positioning_decisions(timeline, participants) do
    # Analyze positioning decisions based on system changes and tactical repositions
    system_changes =
      timeline.events
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [prev, current] ->
        prev[:system_id] != current[:system_id]
      end)
      |> Enum.map(fn [prev, current] ->
        time_diff = DateTime.diff(current.timestamp, prev.timestamp)

        # Determine positioning decision type
        decision_type =
          cond do
            # Quick movement
            time_diff < 300 -> :tactical_reposition
            # Longer movement
            time_diff < 1800 -> :strategic_repositioning
            true -> :strategic_withdrawal
          end

        %{
          decision: decision_type,
          timestamp: current.timestamp,
          from_system: prev[:system_id],
          to_system: current[:system_id],
          participants_involved: length(participants),
          timing_analysis: %{
            response_time: time_diff,
            coordination_quality: if(time_diff < 180, do: :high, else: :medium)
          }
        }
      end)

    # Add concentration decisions (multiple participants in same system)
    concentration_decisions = identify_concentration_decisions(timeline, participants)

    system_changes ++ concentration_decisions
  end

  defp identify_retreat_decisions(timeline, participants) do
    # Identify retreat decisions based on battle flow analysis
    retreat_indicators = identify_retreat_events(timeline)

    retreat_indicators
    |> Enum.map(fn indicator ->
      # Analyze the retreat decision context
      context = analyze_retreat_context(indicator, timeline, participants)

      %{
        decision: :tactical_retreat,
        timestamp: indicator[:timestamp],
        trigger: indicator[:trigger_type],
        participants_retreating: indicator[:participants_count] || 0,
        retreat_coordination: context[:coordination_score] || 0.0,
        success_rate: evaluate_retreat_success(indicator, timeline),
        alternatives: [:continue_engagement, :reinforce, :full_withdrawal],
        decision_quality: evaluate_retreat_decision_quality(indicator, context)
      }
    end)
  end

  defp identify_escalation_decisions(timeline, participants) do
    # Identify escalation decisions based on increasing intensity or reinforcement
    escalation_events = identify_escalation_events(timeline, participants)

    escalation_events
    |> Enum.map(fn event ->
      escalation_type = determine_escalation_type(event, timeline)
      decision_context = analyze_escalation_context(event, timeline, participants)

      %{
        decision: escalation_type,
        timestamp: event[:timestamp],
        escalation_factor: event[:intensity_increase] || 1.0,
        participants_added: event[:new_participants] || 0,
        risk_level: calculate_escalation_risk(event, timeline),
        expected_outcome: predict_escalation_outcome(event, decision_context),
        alternatives: [:maintain_current_level, :de_escalate, :full_commitment],
        decision_rationale: analyze_escalation_rationale(event, decision_context)
      }
    end)
  end

  defp evaluate_decision_effectiveness(decision, timeline) do
    # Evaluate decision effectiveness based on outcomes and context
    effectiveness_score =
      case decision.decision do
        :engage ->
          evaluate_engagement_outcome(decision, timeline)

        :target_selection ->
          evaluate_target_selection_outcome(decision, timeline)

        :tactical_reposition ->
          evaluate_positioning_outcome(decision, timeline)

        :tactical_retreat ->
          evaluate_retreat_outcome(decision, timeline)

        decision_type when decision_type in [:escalate, :reinforce, :commit_reserves] ->
          evaluate_escalation_outcome(decision, timeline)

        _ ->
          # Default moderate effectiveness
          0.5
      end

    # Add success indicators
    success_indicators = identify_success_indicators(decision, effectiveness_score, timeline)

    decision
    |> Map.put(:effectiveness, effectiveness_score)
    |> Map.put(:success_indicators, success_indicators)
    |> Map.put(:lessons_learned, extract_decision_lessons(decision, effectiveness_score))
  end

  defp evaluate_formation_effectiveness(timeline, participants) do
    # Evaluate formation effectiveness based on coordination and survival
    if Enum.empty?(participants) do
      0.0
    else
      # Analyze formation cohesion from kill patterns
      formation_patterns = analyze_formation_patterns(timeline, participants)
      cohesion_score = calculate_average_cohesion(formation_patterns)

      # Effectiveness based on survival rate and coordination
      survival_rate = calculate_formation_survival_rate(timeline, participants)
      coordination_level = formation_patterns[:formation_effectiveness] || 0.0

      # Weighted average
      cohesion_score * 0.4 + survival_rate * 0.4 + coordination_level * 0.2
    end
  end

  defp evaluate_movement_effectiveness(timeline, participants) do
    # Evaluate movement effectiveness based on tactical positioning
    if Enum.empty?(timeline.events) do
      0.0
    else
      movement_patterns = analyze_movement_patterns(timeline, participants)

      # Movement effectiveness factors
      coordination = movement_patterns[:movement_coordination] || 0.0
      repositioning_success = evaluate_repositioning_success(movement_patterns)
      escape_success = evaluate_escape_effectiveness(movement_patterns)

      # Calculate weighted effectiveness
      coordination * 0.5 + repositioning_success * 0.3 + escape_success * 0.2
    end
  end

  defp evaluate_engagement_effectiveness(timeline, participants) do
    # Evaluate engagement effectiveness based on kill/death ratios and timing
    if Enum.empty?(timeline.events) do
      0.0
    else
      engagement_patterns = analyze_engagement_patterns(timeline, participants)

      # Effectiveness factors
      isk_efficiency = calculate_isk_efficiency(timeline)
      engagement_rhythm_score = evaluate_rhythm_effectiveness(engagement_patterns)
      intensity_control = evaluate_intensity_control(engagement_patterns)

      # ISK efficiency is most important, then rhythm and control
      isk_efficiency * 0.5 + engagement_rhythm_score * 0.3 + intensity_control * 0.2
    end
  end

  defp evaluate_coordination_effectiveness(timeline, participants) do
    # Evaluate coordination effectiveness based on focus fire and timing
    if Enum.empty?(timeline.events) do
      0.0
    else
      coordination_patterns = analyze_coordination_patterns(timeline, participants)

      # Coordination factors
      focus_fire_quality = coordination_patterns[:focus_fire_quality] || 0.0
      coordination_level = coordination_patterns[:coordination_level] || 0.0
      breakdown_penalty = calculate_breakdown_penalty(coordination_patterns)

      # Apply breakdown penalty to base coordination score
      base_score = focus_fire_quality * 0.6 + coordination_level * 0.4
      max(0.0, base_score - breakdown_penalty)
    end
  end

  defp identify_tactical_strengths(scores) do
    scores
    |> Enum.filter(fn {_type, score} -> score >= 0.7 end)
    |> Enum.map(fn {type, _score} -> type end)
  end

  defp identify_tactical_weaknesses(scores, _timeline) do
    scores
    |> Enum.filter(fn {_type, score} -> score < 0.6 end)
    |> Enum.map(fn {type, _score} -> type end)
  end

  # Helper functions for pattern effectiveness evaluation

  defp calculate_average_cohesion(formation_patterns) do
    # Calculate average cohesion from formation patterns
    formations_by_side = formation_patterns[:formations_by_side] || %{}

    if map_size(formations_by_side) == 0 do
      0.0
    else
      cohesion_scores =
        formations_by_side
        |> Enum.map(fn {_side, formation} -> formation[:cohesion] || 0.0 end)

      Enum.sum(cohesion_scores) / length(cohesion_scores)
    end
  end

  defp calculate_formation_survival_rate(timeline, participants) do
    # Calculate survival rate based on participant outcomes
    if Enum.empty?(participants) do
      0.0
    else
      participants_lost = count_participants_lost(timeline, participants)
      survival_rate = 1.0 - participants_lost / length(participants)
      max(0.0, survival_rate)
    end
  end

  defp count_participants_lost(timeline, participants) do
    # Count how many participants were lost (became victims)
    lost_participants =
      timeline.events
      |> Enum.map(& &1.victim[:character_id])
      |> Enum.uniq()
      |> Enum.count(fn victim_id ->
        Enum.any?(participants, &(&1[:character_id] == victim_id))
      end)

    lost_participants
  end

  defp evaluate_repositioning_success(movement_patterns) do
    # Evaluate success of tactical repositioning
    tactical_repositioning = movement_patterns[:tactical_repositioning] || []

    if Enum.empty?(tactical_repositioning) do
      # No repositioning data
      0.5
    else
      # Success based on coordination and outcome
      successful_repos =
        Enum.count(tactical_repositioning, fn repo ->
          repo[:coordination_quality] == :high or repo[:outcome] == :successful
        end)

      successful_repos / length(tactical_repositioning)
    end
  end

  defp evaluate_escape_effectiveness(movement_patterns) do
    # Evaluate effectiveness of escape movements
    escape_movements = movement_patterns[:escape_movements] || []

    if Enum.empty?(escape_movements) do
      # No escape attempts suggests good positioning
      0.7
    else
      # Success rate of escape attempts
      successful_escapes =
        Enum.count(escape_movements, fn escape ->
          escape[:success_rate] && escape[:success_rate] > 0.6
        end)

      if not Enum.empty?(escape_movements) do
        successful_escapes / length(escape_movements)
      else
        0.0
      end
    end
  end

  defp calculate_isk_efficiency(timeline) do
    # Calculate ISK efficiency (damage dealt vs received)
    if Enum.empty?(timeline.events) do
      0.0
    else
      total_isk_destroyed =
        timeline.events
        |> Enum.map(&(&1[:isk_value] || 0))
        |> Enum.sum()

      # Normalize ISK efficiency - higher values indicate better performance
      cond do
        # 10B+ ISK very effective
        total_isk_destroyed > 10_000_000_000 -> 1.0
        # 5B+ ISK highly effective
        total_isk_destroyed > 5_000_000_000 -> 0.9
        # 1B+ ISK effective
        total_isk_destroyed > 1_000_000_000 -> 0.8
        # 500M+ ISK moderately effective
        total_isk_destroyed > 500_000_000 -> 0.7
        # 100M+ ISK somewhat effective
        total_isk_destroyed > 100_000_000 -> 0.6
        # 10M+ ISK poor effectiveness
        total_isk_destroyed > 10_000_000 -> 0.4
        # Very low ISK efficiency
        true -> 0.2
      end
    end
  end

  defp evaluate_rhythm_effectiveness(engagement_patterns) do
    # Evaluate engagement rhythm effectiveness
    rhythm = engagement_patterns[:engagement_rhythm] || %{}

    case rhythm[:type] do
      # Sustained pressure is very effective
      :sustained -> 0.9
      # Burst damage is highly effective
      :burst -> 0.8
      # Controlled engagement is effective
      :controlled -> 0.7
      # Intermittent can be less effective
      :intermittent -> 0.5
      # Default moderate effectiveness
      _ -> 0.6
    end
  end

  defp evaluate_intensity_control(engagement_patterns) do
    # Evaluate how well intensity was controlled
    intensity_profile = engagement_patterns[:intensity_profile] || %{}

    # Good intensity control means appropriate escalation and de-escalation
    peak_intensity = intensity_profile[:peak_intensity] || 0.0
    average_intensity = intensity_profile[:average_intensity] || 0.0

    if peak_intensity > 0 do
      # Better control with consistent intensity (less extreme peaks)
      intensity_ratio = average_intensity / peak_intensity
      min(intensity_ratio * 1.5, 1.0)
    else
      0.5
    end
  end

  defp calculate_breakdown_penalty(coordination_patterns) do
    # Calculate penalty for coordination breakdowns
    breakdowns = coordination_patterns[:coordination_breakdowns] || []
    improvements = coordination_patterns[:coordination_improvements] || []

    # More breakdowns = higher penalty, but improvements reduce it
    breakdown_penalty = length(breakdowns) * 0.1
    improvement_bonus = length(improvements) * 0.05

    max(0.0, breakdown_penalty - improvement_bonus)
  end

  defp analyze_engagement_context(event) do
    %{
      initial_target_value: event[:isk_value] || 0,
      # Simplified
      system_type: :nullsec
    }
  end

  defp analyze_target_priority(event) do
    ship_type_id = event.victim[:ship_type_id]
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

    case ship_class do
      :frigate -> :tackle_threat
      :cruiser -> :support_removal
      :battleship -> :dps_reduction
      :capital -> :strategic_value
      _ -> :opportunity
    end
  end

  defp add_if_present(list, nil), do: list
  defp add_if_present(list, item), do: [item | list]

  # Stub functions for missing implementations
  defp analyze_position_from_events(_events), do: :unknown
  defp identify_position_change_trigger(_prev_events, _curr_events), do: :unknown
  defp estimate_repositioned_count(_prev_events, _curr_events), do: 0

  defp analyze_gate_control(timeline) do
    # Analyze control of gates and chokepoints
    if Enum.empty?(timeline.events) do
      nil
    else
      # Check for clustering around specific systems (potential gate camps)
      system_events = Enum.group_by(timeline.events, & &1[:system_id])

      high_traffic_systems =
        system_events
        |> Enum.filter(fn {_system, events} -> length(events) > 3 end)
        |> Enum.map(fn {system_id, events} ->
          %{
            system_id: system_id,
            event_count: length(events),
            time_span: calculate_time_span(events),
            control_quality: calculate_gate_control_quality(events)
          }
        end)

      if not Enum.empty?(high_traffic_systems) do
        %{
          advantage_type: :gate_control,
          controlled_systems: high_traffic_systems,
          overall_control_score: calculate_overall_gate_control(high_traffic_systems),
          strategic_value: :high
        }
      else
        nil
      end
    end
  end

  defp analyze_station_proximity(timeline) do
    # Analyze proximity to stations and structures for tactical advantage
    if Enum.empty?(timeline.events) do
      nil
    else
      # Infer station proximity from kill patterns and timing
      # Quick successive kills might indicate station undocking camps
      rapid_kills = identify_rapid_successive_kills(timeline.events)

      if length(rapid_kills) > 2 do
        %{
          advantage_type: :station_proximity,
          rapid_kill_sequences: length(rapid_kills),
          tactical_setup: :undock_camp,
          positioning_advantage: 0.8,
          strategic_value: :medium
        }
      else
        nil
      end
    end
  end

  defp analyze_terrain_usage(timeline) do
    # Analyze use of system terrain and celestial objects
    if Enum.empty?(timeline.events) do
      nil
    else
      # Analyze positioning based on ship classes and engagement patterns
      # Different ship classes suggest different range usage
      ship_classes =
        timeline.events
        |> Enum.map(fn event ->
          EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id])
        end)
        |> Enum.frequencies()

      # Mixed ship classes in same area suggest good terrain usage
      class_diversity = length(Map.keys(ship_classes))

      if class_diversity > 3 do
        %{
          advantage_type: :terrain_usage,
          range_diversity: class_diversity,
          positioning_flexibility: calculate_positioning_flexibility(ship_classes),
          strategic_value: :medium
        }
      else
        nil
      end
    end
  end

  defp analyze_positional_range_advantage(timeline, participants) do
    # Analyze range control advantages from positioning
    if Enum.empty?(timeline.events) or Enum.empty?(participants) do
      nil
    else
      # Analyze attacker ship compositions vs victim ship compositions
      attacker_ships = extract_attacker_ship_classes(timeline.events)
      victim_ships = extract_victim_ship_classes(timeline.events)

      range_matchup = analyze_range_matchup(attacker_ships, victim_ships)

      if range_matchup[:advantage_score] > 0.7 do
        %{
          advantage_type: :range_control,
          attacker_composition: attacker_ships,
          victim_composition: victim_ships,
          range_advantage_score: range_matchup[:advantage_score],
          positioning_quality: range_matchup[:positioning_quality],
          strategic_value: :high
        }
      else
        nil
      end
    end
  end

  defp analyze_split_positioning(_timeline, _participants), do: nil

  defp identify_escape_attempts(_events, _participants), do: []
  defp calculate_escape_route_availability(_timeline, _participants), do: 0.0
  defp calculate_escape_utilization(_escape_attempts, _participants), do: 0.0
  defp calculate_escape_effectiveness(_escape_attempts), do: 0.0
  defp identify_escape_denials(_events), do: []
  defp count_successful_escapes(_escape_attempts), do: 0
  defp count_failed_escapes(_escape_attempts), do: 0

  defp analyze_timing_precision(_events), do: 0.0
  defp analyze_target_prioritization_patterns(_events), do: %{}
  defp analyze_target_switching_behavior(_events), do: %{}
  defp analyze_overkill_patterns(_events), do: %{}
  defp analyze_fleet_warps_used(_timeline), do: []
  defp analyze_broadcast_utilization(_timeline), do: 0.0

  defp count_sides_by_alliance(_participants), do: 2
  defp extract_side_compositions(_participants), do: %{}
  defp determine_battle_type(_compositions), do: :fleet_battle
  defp determine_fleet_sizes(_compositions), do: %{}

  defp create_window_timeline(_events), do: []
  defp has_significant_break?(_gap), do: false
  defp analyze_window_intensity(_window_events), do: %{}
  defp identify_window_critical_events(_window_events), do: []
  defp calculate_window_duration(_window_events), do: 0

  defp analyze_side_strategy(_side, _formations), do: %{}
  defp determine_formation_shape(_events), do: :unknown
  defp categorize_formation_type(_formation), do: :standard
  defp infer_formation_from_positions(_positions), do: :unknown

  # Helper functions for detailed positioning analysis

  defp calculate_positioning_vulnerability(ship_classes) do
    # Calculate how vulnerable the positioning is based on ship classes lost
    vulnerability_weights = %{
      # Low vulnerability (expected losses)
      frigate: 0.2,
      destroyer: 0.3,
      cruiser: 0.5,
      battlecruiser: 0.7,
      battleship: 0.8,
      # High vulnerability (major positioning error)
      capital: 1.0,
      supercapital: 1.0,
      industrial: 0.4,
      mining: 0.3
    }

    if Enum.empty?(ship_classes) do
      0.0
    else
      weighted_vulnerability =
        ship_classes
        |> Enum.map(&Map.get(vulnerability_weights, &1, 0.5))
        |> Enum.sum()

      weighted_vulnerability / length(ship_classes)
    end
  end

  defp calculate_early_coordination(events) do
    # Calculate coordination level from early engagement timing
    if length(events) < 2 do
      0.0
    else
      # Check timing between kills
      time_gaps =
        events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          DateTime.diff(curr.timestamp, prev.timestamp)
        end)

      # Good coordination has consistent, short time gaps
      if not Enum.empty?(time_gaps) do
        avg_gap = Enum.sum(time_gaps) / length(time_gaps)
        variance = calculate_time_variance(time_gaps, avg_gap)

        # Lower variance and shorter gaps = better coordination
        coordination_score =
          cond do
            # Excellent coordination
            avg_gap < 30 and variance < 20 -> 0.9
            # Good coordination
            avg_gap < 60 and variance < 40 -> 0.7
            # Moderate coordination
            avg_gap < 120 -> 0.5
            # Poor coordination
            true -> 0.3
          end

        coordination_score
      else
        0.5
      end
    end
  end

  defp calculate_engagement_aggressiveness(attacker_ships, participants) do
    # Calculate how aggressive the initial engagement was
    if Enum.empty?(participants) do
      0.0
    else
      participant_ratio = length(attacker_ships) / length(participants)

      # Higher participation ratio indicates more aggressive engagement
      min(participant_ratio * 1.5, 1.0)
    end
  end

  defp analyze_tactical_composition(ship_classes) do
    # Analyze the tactical composition of early attackers
    class_counts = Enum.frequencies(ship_classes)
    total_ships = length(ship_classes)

    if total_ships == 0 do
      %{composition_type: :unknown, effectiveness: 0.0}
    else
      # Analyze composition patterns
      frigate_ratio =
        (Map.get(class_counts, :frigate, 0) + Map.get(class_counts, :destroyer, 0)) / total_ships

      cruiser_ratio =
        (Map.get(class_counts, :cruiser, 0) + Map.get(class_counts, :battlecruiser, 0)) /
          total_ships

      battleship_ratio = Map.get(class_counts, :battleship, 0) / total_ships

      capital_ratio =
        (Map.get(class_counts, :capital, 0) + Map.get(class_counts, :supercapital, 0)) /
          total_ships

      composition_type =
        cond do
          capital_ratio > 0.3 -> :capital_heavy
          battleship_ratio > 0.4 -> :battleship_heavy
          cruiser_ratio > 0.5 -> :cruiser_heavy
          frigate_ratio > 0.6 -> :frigate_heavy
          true -> :balanced
        end

      # Calculate composition effectiveness
      effectiveness =
        case composition_type do
          # Very effective for major engagements
          :capital_heavy -> 0.9
          # Effective for sustained fights
          :battleship_heavy -> 0.8
          # Generally effective
          :balanced -> 0.7
          # Moderately effective
          :cruiser_heavy -> 0.6
          # Situationally effective
          :frigate_heavy -> 0.5
          _ -> 0.5
        end

      %{
        composition_type: composition_type,
        effectiveness: effectiveness,
        class_distribution: class_counts
      }
    end
  end

  defp evaluate_victim_positioning_score(victim_analysis) do
    # Evaluate positioning quality based on victim characteristics
    vulnerability = victim_analysis[:positioning_vulnerability] || 0.5

    high_value_ratio =
      if victim_analysis[:victim_count] > 0 do
        victim_analysis[:high_value_targets] / victim_analysis[:victim_count]
      else
        0.0
      end

    # Lower vulnerability and fewer high-value losses = better positioning
    base_score = 1.0 - vulnerability
    value_penalty = high_value_ratio * 0.3

    max(0.0, base_score - value_penalty)
  end

  defp evaluate_attacker_positioning_score(attacker_analysis) do
    # Evaluate positioning quality of attackers
    coordination = attacker_analysis[:coordination_level] || 0.0
    composition_effectiveness = attacker_analysis[:tactical_composition][:effectiveness] || 0.0
    aggressiveness = attacker_analysis[:engagement_aggressiveness] || 0.0

    # Balance coordination, composition, and controlled aggression
    coordination * 0.5 + composition_effectiveness * 0.3 + min(aggressiveness, 0.8) * 0.2
  end

  defp calculate_time_variance(time_gaps, avg_gap) do
    # Calculate variance in time gaps for coordination analysis
    if length(time_gaps) <= 1 do
      0.0
    else
      squared_diffs = Enum.map(time_gaps, fn gap -> :math.pow(gap - avg_gap, 2) end)
      variance = Enum.sum(squared_diffs) / length(time_gaps)
      :math.sqrt(variance)
    end
  end

  defp identify_isolated_victims(events, participants) do
    # Identify participants who were caught isolated
    events
    |> Enum.filter(fn event ->
      attacker_count = length(event[:attackers] || [])
      # If attacked by many but few friendly participants nearby, likely isolated
      attacker_count > length(participants) * 0.7
    end)
    |> Enum.map(& &1.victim[:character_id])
    |> Enum.uniq()
  end

  defp identify_range_positioning_errors(events) do
    # Identify ships positioned at wrong ranges for their type
    events
    |> Enum.filter(fn event ->
      ship_type_id = event.victim[:ship_type_id]
      ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

      # Check if ship died to wrong weapon types (indicates range error)
      attackers = event[:attackers] || []
      primary_attacker = Enum.find(attackers, & &1["final_blow"]) || List.first(attackers)

      if primary_attacker do
        weapon_type = primary_attacker["weapon_type_id"]
        has_range_mismatch?(ship_class, weapon_type)
      else
        false
      end
    end)
  end

  defp identify_formation_errors(events, participants) do
    # Identify formation discipline errors
    if length(participants) < 3 do
      # Can't have formation errors with very small groups
      []
    else
      # Look for participants dying alone when they should be in formation
      isolated_deaths =
        events
        |> Enum.filter(fn event ->
          # Check if victim had support nearby (based on attacker focus)
          attackers = event[:attackers] || []
          total_attackers = length(attackers)

          # If facing many attackers alone, likely formation error
          total_attackers > length(participants) * 0.5
        end)

      isolated_deaths
    end
  end

  defp has_escape_route_errors?(events, participants) do
    # Check if escape routes were compromised
    if Enum.empty?(events) do
      false
    else
      # If many participants died in short time, suggests trapped positioning
      time_span =
        if length(events) > 1 do
          first_kill = List.first(events)
          last_kill = List.last(events)
          DateTime.diff(last_kill.timestamp, first_kill.timestamp)
        else
          0
        end

      casualty_rate = length(events) / max(length(participants), 1)

      # Quick casualties with high casualty rate suggests escape route problems
      time_span < 300 and casualty_rate > 0.5
    end
  end

  defp has_range_mismatch?(ship_class, _weapon_type_id) do
    # Determine if there's a range mismatch between ship and weapon
    # This is a simplified analysis - would need weapon type data for full accuracy

    case ship_class do
      :frigate ->
        # Frigates should die to short-range weapons, not long-range
        # Would need weapon classification
        false

      :battleship ->
        # Battleships shouldn't die to frigate weapons easily
        # Would need weapon classification
        false

      _ ->
        # Default no mismatch without weapon data
        false
    end
  end

  # Helper functions for escape route and positional advantage analysis

  defp calculate_time_span(events) do
    # Calculate time span between first and last event
    if length(events) < 2 do
      0
    else
      first_event = List.first(events)
      last_event = List.last(events)
      DateTime.diff(last_event.timestamp, first_event.timestamp)
    end
  end

  defp calculate_gate_control_quality(events) do
    # Calculate quality of gate control based on kill patterns
    time_span = calculate_time_span(events)
    event_count = length(events)

    # Good gate control has sustained kills over time
    if time_span > 0 do
      # kills per minute
      kill_rate = event_count / (time_span / 60.0)
      # Scale to 0-1
      min(kill_rate / 2.0, 1.0)
    else
      0.0
    end
  end

  defp calculate_overall_gate_control(controlled_systems) do
    # Calculate overall gate control effectiveness
    if Enum.empty?(controlled_systems) do
      0.0
    else
      avg_control =
        controlled_systems
        |> Enum.map(& &1[:control_quality])
        |> Enum.sum()
        |> then(&(&1 / length(controlled_systems)))

      # Bonus for controlling multiple systems
      system_bonus = min(length(controlled_systems) / 3.0, 1.0)

      min((avg_control + system_bonus) / 2.0, 1.0)
    end
  end

  defp identify_rapid_successive_kills(events) do
    # Identify kills that happened in rapid succession (potential station camps)
    events
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, curr] ->
      # Within 30 seconds
      DateTime.diff(curr.timestamp, prev.timestamp) < 30
    end)
    |> Enum.map(fn [_prev, curr] -> curr end)
  end

  defp calculate_positioning_flexibility(ship_classes) do
    # Calculate positioning flexibility based on ship class diversity
    total_ships = Enum.sum(Map.values(ship_classes))

    if total_ships == 0 do
      0.0
    else
      # Shannon diversity index for ship classes
      entropy =
        ship_classes
        |> Enum.map(fn {_class, count} ->
          probability = count / total_ships
          if probability > 0, do: -probability * :math.log2(probability), else: 0
        end)
        |> Enum.sum()

      # Normalize to 0-1 scale (log2(8) ≈ 3 for perfect diversity with 8 ship classes)
      min(entropy / 3.0, 1.0)
    end
  end

  defp extract_attacker_ship_classes(events) do
    # Extract ship classes of attackers
    events
    |> Enum.flat_map(&(&1[:attackers] || []))
    |> Enum.map(fn attacker ->
      ship_type_id = attacker["ship_type_id"]
      EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
    end)
    |> Enum.frequencies()
  end

  defp extract_victim_ship_classes(events) do
    # Extract ship classes of victims
    events
    |> Enum.map(fn event ->
      ship_type_id = event.victim[:ship_type_id]
      EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
    end)
    |> Enum.frequencies()
  end

  defp analyze_range_matchup(attacker_ships, victim_ships) do
    # Analyze range advantage between attacker and victim compositions
    attacker_ranges = calculate_composition_range_profile(attacker_ships)
    victim_ranges = calculate_composition_range_profile(victim_ships)

    # Calculate advantage based on range profile matchup
    advantage_score = calculate_range_advantage_score(attacker_ranges, victim_ranges)
    positioning_quality = evaluate_range_positioning_quality(attacker_ranges, victim_ranges)

    %{
      advantage_score: advantage_score,
      positioning_quality: positioning_quality,
      attacker_range_profile: attacker_ranges,
      victim_range_profile: victim_ranges
    }
  end

  defp calculate_composition_range_profile(ship_classes) do
    # Calculate range profile of a ship composition
    total_ships = Enum.sum(Map.values(ship_classes))

    if total_ships == 0 do
      %{short: 0.0, medium: 0.0, long: 0.0}
    else
      # Assign range categories to ship classes
      range_weights = %{
        frigate: %{short: 0.8, medium: 0.2, long: 0.0},
        destroyer: %{short: 0.6, medium: 0.4, long: 0.0},
        cruiser: %{short: 0.3, medium: 0.5, long: 0.2},
        battlecruiser: %{short: 0.2, medium: 0.6, long: 0.2},
        battleship: %{short: 0.1, medium: 0.4, long: 0.5},
        capital: %{short: 0.0, medium: 0.3, long: 0.7},
        supercapital: %{short: 0.0, medium: 0.2, long: 0.8}
      }

      # Calculate weighted range profile
      total_profile =
        ship_classes
        |> Enum.reduce(%{short: 0.0, medium: 0.0, long: 0.0}, fn {ship_class, count}, acc ->
          weights = Map.get(range_weights, ship_class, %{short: 0.33, medium: 0.33, long: 0.34})
          proportion = count / total_ships

          %{
            short: acc.short + weights.short * proportion,
            medium: acc.medium + weights.medium * proportion,
            long: acc.long + weights.long * proportion
          }
        end)

      total_profile
    end
  end

  defp calculate_range_advantage_score(attacker_ranges, victim_ranges) do
    # Calculate advantage score based on range profile matchup
    # Advantage when attackers can dictate range

    # Short range attackers vs long range victims = disadvantage
    short_disadvantage = attacker_ranges.short * victim_ranges.long * 0.8

    # Long range attackers vs short range victims = advantage  
    long_advantage = attacker_ranges.long * victim_ranges.short * 0.9

    # Medium range provides balanced matchup
    medium_balance = (attacker_ranges.medium + victim_ranges.medium) * 0.5

    advantage = long_advantage + medium_balance - short_disadvantage
    max(0.0, min(advantage, 1.0))
  end

  defp evaluate_range_positioning_quality(attacker_ranges, victim_ranges) do
    # Evaluate quality of positioning based on range profiles
    # Good positioning has clear range advantage or balanced engagement

    range_spread = calculate_range_spread(attacker_ranges)
    victim_spread = calculate_range_spread(victim_ranges)

    # Higher spread indicates better positioning flexibility
    avg_spread = (range_spread + victim_spread) / 2.0

    # Normalize to 0-1 scale
    min(avg_spread / 0.6, 1.0)
  end

  defp calculate_range_spread(range_profile) do
    # Calculate spread/diversity of range profile
    ranges = [range_profile.short, range_profile.medium, range_profile.long]

    # Calculate standard deviation as measure of spread
    mean = Enum.sum(ranges) / 3.0

    variance =
      ranges
      |> Enum.map(&:math.pow(&1 - mean, 2))
      |> Enum.sum()
      |> then(&(&1 / 3.0))

    :math.sqrt(variance)
  end

  # More missing helper functions
  defp analyze_early_victims(events) do
    # Analyze the characteristics of early victims to understand initial positioning
    victim_ships =
      Enum.map(events, fn event ->
        ship_type_id = event.victim[:ship_type_id]

        %{
          ship_type_id: ship_type_id,
          ship_class: EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id),
          isk_value: event[:isk_value] || 0,
          timestamp: event.timestamp
        }
      end)

    # Analyze victim patterns
    ship_classes = Enum.map(victim_ships, & &1.ship_class)
    total_isk = Enum.sum(Enum.map(victim_ships, & &1.isk_value))

    %{
      victim_count: length(victim_ships),
      ship_classes: Enum.frequencies(ship_classes),
      total_isk_lost: total_isk,
      average_victim_value:
        if(not Enum.empty?(victim_ships), do: total_isk / Enum.count(victim_ships), else: 0),
      high_value_targets: Enum.count(victim_ships, &(&1.isk_value > 500_000_000)),
      positioning_vulnerability: calculate_positioning_vulnerability(ship_classes)
    }
  end

  defp analyze_early_attackers(events, participants) do
    # Analyze attacker patterns in early engagements
    all_attackers =
      events
      |> Enum.flat_map(&(&1[:attackers] || []))
      |> Enum.uniq_by(& &1["character_id"])

    attacker_ships =
      all_attackers
      |> Enum.map(fn attacker ->
        ship_type_id = attacker["ship_type_id"]

        %{
          character_id: attacker["character_id"],
          ship_type_id: ship_type_id,
          ship_class: EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id),
          damage_done: attacker["damage_done"] || 0
        }
      end)

    ship_classes = Enum.map(attacker_ships, & &1.ship_class)
    total_damage = Enum.sum(Enum.map(attacker_ships, & &1.damage_done))

    %{
      attacker_count: length(attacker_ships),
      ship_classes: Enum.frequencies(ship_classes),
      total_damage_dealt: total_damage,
      coordination_level: calculate_early_coordination(events),
      engagement_aggressiveness:
        calculate_engagement_aggressiveness(attacker_ships, participants),
      tactical_composition: analyze_tactical_composition(ship_classes)
    }
  end

  defp calculate_initial_positioning_quality(victim_analysis, attacker_analysis) do
    # Calculate positioning quality based on victim and attacker analysis
    victim_score = evaluate_victim_positioning_score(victim_analysis)
    attacker_score = evaluate_attacker_positioning_score(attacker_analysis)
    coordination_score = attacker_analysis[:coordination_level] || 0.0

    # Weight the scores
    victim_score * 0.4 + attacker_score * 0.4 + coordination_score * 0.2
  end

  defp calculate_tactical_advantage(events) do
    # Calculate tactical advantage from initial engagement
    if Enum.empty?(events) do
      0.0
    else
      # Analyze kill/damage ratios and timing
      total_damage =
        events
        |> Enum.flat_map(&(&1[:attackers] || []))
        |> Enum.sum(fn attacker -> attacker["damage_done"] || 0 end)

      total_isk_destroyed =
        events
        |> Enum.sum(fn event -> event[:isk_value] || 0 end)

      # Higher ISK destroyed with efficient damage indicates advantage
      if total_damage > 0 do
        # Normalize damage
        isk_efficiency = total_isk_destroyed / (total_damage / 1000)
        # Scale to 0-1
        min(isk_efficiency / 100_000, 1.0)
      else
        # Neutral if no damage data
        0.5
      end
    end
  end

  defp calculate_strategic_positioning_value(events) do
    # Calculate strategic value of initial positioning
    if Enum.empty?(events) do
      0.0
    else
      # Analyze systems and strategic elements
      systems = Enum.map(events, & &1[:system_id]) |> Enum.uniq()

      # Single system engagement is more controlled
      system_control_score = if length(systems) == 1, do: 0.8, else: 0.4

      # High-value targets suggest good positioning
      high_value_kills = Enum.count(events, &((&1[:isk_value] || 0) > 500_000_000))
      value_score = min(high_value_kills / 3.0, 1.0)

      # Time compression suggests good initial positioning
      first_kill = List.first(events)
      last_kill = List.last(events)

      time_score =
        if first_kill && last_kill do
          time_span = DateTime.diff(last_kill.timestamp, first_kill.timestamp)
          # Quick engagement is better
          if time_span < 300, do: 0.9, else: 0.6
        else
          0.5
        end

      system_control_score * 0.4 + value_score * 0.4 + time_score * 0.2
    end
  end

  defp identify_positioning_errors(events, participants) do
    # Identify common positioning errors from early engagement
    errors = []

    # Check for isolation errors (participants caught alone)
    isolated_victims = identify_isolated_victims(events, participants)

    errors =
      if not Enum.empty?(isolated_victims) do
        [
          {:isolation_error, length(isolated_victims), "Participants caught in poor position"}
          | errors
        ]
      else
        errors
      end

    # Check for range errors (wrong ships at wrong ranges)
    range_errors = identify_range_positioning_errors(events)

    errors =
      if not Enum.empty?(range_errors) do
        [{:range_error, length(range_errors), "Ships positioned at suboptimal ranges"} | errors]
      else
        errors
      end

    # Check for formation errors
    formation_errors = identify_formation_errors(events, participants)

    errors =
      if not Enum.empty?(formation_errors) do
        [{:formation_error, length(formation_errors), "Poor formation discipline"} | errors]
      else
        errors
      end

    # Check for escape route errors
    if has_escape_route_errors?(events, participants) do
      [{:escape_route_error, 1, "Limited escape route availability"} | errors]
    else
      errors
    end
  end

  defp infer_initial_formation(_events), do: :unknown

  defp analyze_ship_compositions(_participants), do: %{}
  defp analyze_optimal_ranges(_compositions), do: %{}
  defp analyze_range_control_events(_events, _optimal_ranges), do: []
  defp calculate_range_control_score(_events), do: 0.0

  defp calculate_avg_response_time(_events), do: 0.0
  defp calculate_standard_deviation(_times), do: 0.0

  # More missing range control functions
  defp analyze_range_from_kills(_events), do: []
  defp calculate_range_advantage(_range_events, _ship_compositions), do: 0.0
  defp calculate_range_control_effectiveness(_range_events), do: 0.0
  defp determine_range_dictation_level(_range_events, _timeline), do: 0.0
  defp identify_range_adaptations(_range_events), do: []
  defp calculate_optimal_range_time(_range_events), do: 0.0

  # Helper functions for target selection analysis
  defp extract_target_order(events) do
    events
    |> Enum.map(fn event ->
      %{
        ship_type_id: event.victim[:ship_type_id],
        ship_class: EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id]),
        value: event[:isk_value] || 0,
        timestamp: event.timestamp
      }
    end)
  end

  defp calculate_optimal_target_order(events) do
    # Calculate optimal kill order based on threat and value
    events
    |> Enum.map(fn event ->
      ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id])

      threat_score =
        case ship_class do
          # High threat - tackle
          :frigate -> 0.9
          # Support/EWAR
          :cruiser -> 0.8
          # DPS
          :battlecruiser -> 0.6
          # Heavy DPS
          :battleship -> 0.5
          # Strategic but slow
          :capital -> 0.4
          _ -> 0.3
        end

      value_score =
        if event[:isk_value], do: min(event[:isk_value] / 1_000_000_000, 1.0), else: 0.0

      %{
        event: event,
        priority_score: threat_score * 0.7 + value_score * 0.3,
        ship_class: ship_class
      }
    end)
    |> Enum.sort_by(& &1.priority_score, :desc)
    |> Enum.map(& &1.event)
  end

  defp calculate_prioritization_accuracy(actual_order, optimal_order) do
    if Enum.empty?(actual_order) do
      0.0
    else
      # Compare actual vs optimal target order
      matches =
        Enum.zip(actual_order, optimal_order)
        |> Enum.count(fn {actual, optimal} ->
          actual[:ship_class] == optimal[:ship_class]
        end)

      matches / length(actual_order)
    end
  end

  defp calculate_priority_adherence(events) do
    # Check if high-priority targets were engaged first
    priority_violations =
      events
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [prev, current] ->
        prev_priority = get_target_priority(prev)
        curr_priority = get_target_priority(current)
        # Higher priority killed after lower
        curr_priority > prev_priority
      end)

    if length(events) > 1 do
      1.0 - priority_violations / (length(events) - 1)
    else
      1.0
    end
  end

  defp calculate_prioritization_speed(events) do
    # How quickly high-priority targets were eliminated
    high_priority_kills =
      events
      |> Enum.filter(fn event ->
        ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id])
        # High priority targets
        ship_class in [:frigate, :cruiser]
      end)

    if not Enum.empty?(high_priority_kills) && not Enum.empty?(events) do
      # Check if they were killed early
      early_ratio = length(Enum.take(events, div(length(events), 2)))

      high_priority_early =
        Enum.count(high_priority_kills, fn kill ->
          Enum.find_index(events, &(&1 == kill)) < early_ratio
        end)

      high_priority_early / length(high_priority_kills)
    else
      0.5
    end
  end

  defp calculate_prioritization_effectiveness(events) do
    # Overall effectiveness based on threat reduction
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, index} ->
      threat_value = get_threat_value(event)
      # Earlier kills worth more
      time_factor = 1.0 - index / length(events)
      threat_value * time_factor
    end)
    |> Enum.sum()
    |> then(fn sum -> min(sum / length(events), 1.0) end)
  end

  defp identify_focus_fire_windows_detailed(timeline) do
    # Group kills into time windows and analyze focus fire
    timeline.events
    # 10-second windows for focus fire
    |> create_time_windows(10)
    |> Enum.map(fn {window_time, events} ->
      %{
        timestamp: window_time,
        kills: length(events),
        targets: extract_unique_targets(events),
        concentration: calculate_kill_concentration(events),
        participant_count: count_unique_attackers(events)
      }
    end)
    # Only windows with multiple kills
    |> Enum.filter(&(&1.kills > 1))
  end

  defp calculate_focus_effectiveness(focus_windows) do
    if Enum.empty?(focus_windows) do
      0.0
    else
      # Average concentration across windows
      total_concentration = Enum.sum(Enum.map(focus_windows, & &1.concentration))
      total_concentration / length(focus_windows)
    end
  end

  defp calculate_switching_frequency(events) do
    if length(events) < 2 do
      0.0
    else
      switches = identify_target_switches(events)
      length(switches) / (length(events) - 1)
    end
  end

  defp calculate_focus_coordination(focus_windows) do
    if Enum.empty?(focus_windows) do
      0.0
    else
      # Coordination based on participant alignment
      coordinated_windows =
        Enum.count(focus_windows, fn window ->
          window.participant_count > 3 && window.concentration > 0.7
        end)

      coordinated_windows / length(focus_windows)
    end
  end

  defp calculate_damage_concentration(_focus_windows) do
    # Simplified - would analyze actual damage dealt
    0.8
  end

  defp identify_target_switches(events) do
    events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.filter(fn {[prev, curr], _index} ->
      # Different ship types indicate target switch
      prev.victim[:ship_type_id] != curr.victim[:ship_type_id]
    end)
    |> Enum.map(fn {[prev, curr], index} ->
      %{
        from_target: prev.victim[:ship_type_id],
        to_target: curr.victim[:ship_type_id],
        timestamp: curr.timestamp,
        index: index,
        time_delta: DateTime.diff(curr.timestamp, prev.timestamp)
      }
    end)
  end

  defp evaluate_switch_effectiveness(switches, _timeline) do
    if Enum.empty?(switches) do
      # Neutral if no switches
      0.5
    else
      # Effectiveness based on whether switches improved target quality
      effective_switches =
        Enum.count(switches, fn switch ->
          from_priority = get_target_priority_by_id(switch.from_target)
          to_priority = get_target_priority_by_id(switch.to_target)
          to_priority >= from_priority
        end)

      effective_switches / length(switches)
    end
  end

  defp analyze_switch_reasons(switches, _timeline) do
    # Analyze why switches occurred
    switches
    |> Enum.map(fn switch ->
      cond do
        switch.time_delta < 5 -> :rapid_elimination
        switch.time_delta < 30 -> :tactical_change
        true -> :opportunity
      end
    end)
    |> Enum.frequencies()
    |> Map.keys()
  end

  defp evaluate_switch_coordination(switches) do
    if Enum.empty?(switches) do
      # Perfect if no switches needed
      1.0
    else
      # Coordination based on switch timing
      rapid_switches = Enum.count(switches, &(&1.time_delta < 10))
      rapid_switches / length(switches)
    end
  end

  defp identify_primary_call_patterns(timeline) do
    # Identify patterns that suggest primary calling
    timeline.events
    # 5-second windows
    |> create_time_windows(5)
    |> Enum.filter(fn {_time, events} -> length(events) >= 2 end)
    |> Enum.map(fn {time, events} ->
      %{
        timestamp: time,
        kills: length(events),
        focus_target: identify_focus_target(events),
        response_time: calculate_window_response_time(events)
      }
    end)
  end

  defp evaluate_calling_effectiveness(call_patterns) do
    if Enum.empty?(call_patterns) do
      0.0
    else
      # Effectiveness based on kill clustering
      focused_patterns = Enum.count(call_patterns, &(&1.focus_target != nil))
      focused_patterns / length(call_patterns)
    end
  end

  defp calculate_calling_response_time(call_patterns) do
    if Enum.empty?(call_patterns) do
      0.0
    else
      avg_response =
        call_patterns
        |> Enum.map(& &1.response_time)
        |> Enum.sum()
        |> then(&(&1 / length(call_patterns)))

      # Convert to score (faster = better)
      cond do
        avg_response < 2 -> 1.0
        avg_response < 5 -> 0.8
        avg_response < 10 -> 0.6
        true -> 0.4
      end
    end
  end

  defp evaluate_calling_accuracy(call_patterns, _timeline) do
    # Accuracy of primary selection
    if Enum.empty?(call_patterns) do
      0.0
    else
      accurate_calls =
        Enum.count(call_patterns, fn pattern ->
          pattern.focus_target && get_threat_value_by_id(pattern.focus_target) > 0.5
        end)

      accurate_calls / length(call_patterns)
    end
  end

  defp evaluate_calling_coordination(call_patterns) do
    # Coordination quality from response patterns
    if length(call_patterns) < 2 do
      0.5
    else
      # Check consistency in kill timing
      response_times = Enum.map(call_patterns, & &1.response_time)
      avg_response = Enum.sum(response_times) / length(response_times)

      variance =
        response_times
        |> Enum.map(fn time -> :math.pow(time - avg_response, 2) end)
        |> Enum.sum()
        |> then(&(&1 / length(response_times)))

      # Lower variance = better coordination
      if variance < 5 do
        1.0
      else
        max(0.0, 1.0 - variance / 20)
      end
    end
  end

  defp extract_called_targets(call_patterns) do
    call_patterns
    |> Enum.map(& &1.focus_target)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_target_details(events) do
    events
    |> Enum.map(fn event ->
      ship_type_id = event.victim[:ship_type_id]
      ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

      %{
        ship_type_id: ship_type_id,
        ship_class: ship_class,
        value: event[:isk_value] || 0,
        timestamp: event.timestamp,
        threat_level: get_threat_value_by_class(ship_class)
      }
    end)
  end

  defp calculate_target_value_score(targets) do
    if Enum.empty?(targets) do
      0.0
    else
      # Score based on target values
      total_value = Enum.sum(Enum.map(targets, & &1.value))
      avg_value = total_value / length(targets)

      # Normalize to 0-1 scale
      min(avg_value / 1_000_000_000, 1.0)
    end
  end

  defp calculate_accessibility_score(targets, _timeline) do
    # Score based on how accessible targets were
    if Enum.empty?(targets) do
      0.0
    else
      # Simplified - based on ship class accessibility
      accessible_count =
        Enum.count(targets, fn target ->
          target.ship_class in [:frigate, :destroyer, :cruiser]
        end)

      accessible_count / length(targets)
    end
  end

  defp calculate_priority_adherence_score(targets) do
    # Score based on following optimal priority
    if length(targets) < 2 do
      1.0
    else
      violations =
        targets
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [prev, curr] ->
          prev.threat_level < curr.threat_level
        end)

      1.0 - violations / (length(targets) - 1)
    end
  end

  defp identify_suboptimal_targets(targets) do
    targets
    |> Enum.filter(fn target ->
      # Low threat, low value targets
      target.threat_level < 0.3 && target.value < 50_000_000
    end)
    |> Enum.map(& &1.ship_type_id)
  end

  # Utility functions for target analysis
  defp get_target_priority(event) do
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id])
    get_threat_value_by_class(ship_class)
  end

  defp get_target_priority_by_id(ship_type_id) do
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
    get_threat_value_by_class(ship_class)
  end

  defp get_threat_value(event) do
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id])
    get_threat_value_by_class(ship_class)
  end

  defp get_threat_value_by_id(ship_type_id) do
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
    get_threat_value_by_class(ship_class)
  end

  defp get_threat_value_by_class(ship_class) do
    case ship_class do
      :frigate -> 0.9
      :cruiser -> 0.8
      :battlecruiser -> 0.6
      :battleship -> 0.5
      :capital -> 0.4
      _ -> 0.3
    end
  end

  defp extract_unique_targets(events) do
    events
    |> Enum.map(& &1.victim[:ship_type_id])
    |> Enum.uniq()
  end

  defp calculate_kill_concentration(events) do
    if Enum.empty?(events) do
      0.0
    else
      unique_targets = extract_unique_targets(events)
      # Concentration = kills per target
      1.0 - (length(unique_targets) - 1) / length(events)
    end
  end

  defp count_unique_attackers(events) do
    events
    |> Enum.flat_map(fn event ->
      if attackers = event[:attackers] do
        Enum.map(attackers, & &1["character_id"])
      else
        []
      end
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> length()
  end

  defp identify_focus_target(events) do
    # Find most targeted ship in window
    events
    |> Enum.map(& &1.victim[:ship_type_id])
    |> Enum.frequencies()
    |> Enum.max_by(fn {_id, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp calculate_window_response_time(events) do
    if length(events) < 2 do
      0
    else
      first = List.first(events)
      last = List.last(events)
      DateTime.diff(last.timestamp, first.timestamp)
    end
  end

  # Helper functions for timing pattern analysis
  defp identify_timing_phases(timeline) do
    # Identify timing phases of the battle
    events = timeline.events

    if length(events) < 3 do
      []
    else
      total_duration = DateTime.diff(List.last(events).timestamp, List.first(events).timestamp)

      [
        %{
          phase: :initiation,
          start_time: List.first(events).timestamp,
          end_time: Enum.at(events, div(length(events), 3)).timestamp,
          events: Enum.take(events, div(length(events), 3)),
          duration: div(total_duration, 3)
        },
        %{
          phase: :escalation,
          start_time: Enum.at(events, div(length(events), 3)).timestamp,
          end_time: Enum.at(events, div(length(events) * 2, 3)).timestamp,
          events: Enum.slice(events, div(length(events), 3), div(length(events), 3)),
          duration: div(total_duration, 3)
        },
        %{
          phase: :conclusion,
          start_time: Enum.at(events, div(length(events) * 2, 3)).timestamp,
          end_time: List.last(events).timestamp,
          events: Enum.drop(events, div(length(events) * 2, 3)),
          duration: total_duration - div(total_duration * 2, 3)
        }
      ]
    end
  end

  defp analyze_initiation_timing(_timeline, phases) do
    initiation_phase = Enum.find(phases, &(&1.phase == :initiation))

    if initiation_phase do
      # Score based on rapid initial engagement
      initial_events = initiation_phase.events

      if length(initial_events) > 1 do
        time_deltas =
          initial_events
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [prev, curr] ->
            DateTime.diff(curr.timestamp, prev.timestamp)
          end)

        avg_delta = Enum.sum(time_deltas) / length(time_deltas)

        # Faster initiation = higher score
        cond do
          # Very fast
          avg_delta < 10 -> 1.0
          # Fast
          avg_delta < 30 -> 0.8
          # Moderate
          avg_delta < 60 -> 0.6
          # Slow
          true -> 0.4
        end
      else
        0.5
      end
    else
      0.0
    end
  end

  defp analyze_escalation_timing(_timeline, phases) do
    escalation_phase = Enum.find(phases, &(&1.phase == :escalation))

    if escalation_phase do
      # Score based on consistent escalation
      escalation_events = escalation_phase.events

      if length(escalation_events) > 2 do
        # Calculate kill rate consistency
        time_deltas =
          escalation_events
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [prev, curr] ->
            DateTime.diff(curr.timestamp, prev.timestamp)
          end)

        avg_delta = Enum.sum(time_deltas) / length(time_deltas)
        variance = calculate_variance(time_deltas, avg_delta)

        # Low variance = consistent escalation
        cond do
          variance < 20 -> 1.0
          variance < 60 -> 0.8
          variance < 120 -> 0.6
          true -> 0.4
        end
      else
        0.5
      end
    else
      0.0
    end
  end

  defp analyze_conclusion_timing(_timeline, phases) do
    conclusion_phase = Enum.find(phases, &(&1.phase == :conclusion))

    if conclusion_phase do
      # Score based on decisive conclusion vs dragging out
      conclusion_events = conclusion_phase.events

      if length(conclusion_events) > 0 do
        # Check if conclusion was swift or drawn out
        phase_duration = conclusion_phase.duration
        kill_rate = length(conclusion_events) / max(phase_duration, 1)

        cond do
          # Very decisive
          kill_rate > 0.5 -> 1.0
          # Decisive
          kill_rate > 0.3 -> 0.8
          # Moderate
          kill_rate > 0.1 -> 0.6
          # Drawn out
          true -> 0.4
        end
      else
        0.0
      end
    else
      0.0
    end
  end

  defp analyze_timing_coordination(timeline) do
    # Analyze overall timing coordination across the battle
    if Enum.count(timeline.events) < 2 do
      0.0
    else
      # Look for patterns in kill timing that suggest coordination
      time_deltas =
        timeline.events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          DateTime.diff(curr.timestamp, prev.timestamp)
        end)

      # Identify windows of coordinated activity (multiple kills in short time)
      # 15 seconds
      coordinated_windows = Enum.count(time_deltas, &(&1 < 15))

      if length(time_deltas) > 0 do
        coordinated_windows / length(time_deltas)
      else
        0.0
      end
    end
  end

  defp identify_coordination_events(timeline) do
    # Identify specific coordination events
    timeline.events
    # 30-second windows
    |> create_time_windows(30)
    |> Enum.filter(fn {_time, events} ->
      # At least 2 kills for coordination
      length(events) >= 2
    end)
    |> Enum.map(fn {window_time, events} ->
      %{
        timestamp: window_time,
        type: :coordinated_kills,
        participant_count: count_unique_attackers(events),
        kill_count: length(events),
        coordination_quality: calculate_kill_concentration(events)
      }
    end)
  end

  defp calculate_response_times(coordination_events) do
    coordination_events
    |> Enum.map(fn event ->
      # Response time based on kill clustering
      event[:coordination_quality] || 0.0
    end)
  end

  defp calculate_execution_timing(coordination_events) do
    if Enum.empty?(coordination_events) do
      0.0
    else
      # Average execution quality across events
      total_quality =
        coordination_events
        |> Enum.map(&(&1[:coordination_quality] || 0.0))
        |> Enum.sum()

      total_quality / length(coordination_events)
    end
  end

  defp calculate_timing_effectiveness(timeline, coordination_events) do
    if Enum.empty?(coordination_events) do
      0.0
    else
      # Effectiveness based on achieving objectives quickly
      total_events = length(timeline.events)
      coordinated_kills = Enum.sum(Enum.map(coordination_events, &(&1[:kill_count] || 0)))

      if total_events > 0 do
        coordinated_kills / total_events
      else
        0.0
      end
    end
  end

  defp calculate_timing_variance(coordination_events) do
    if length(coordination_events) < 2 do
      0.0
    else
      qualities = Enum.map(coordination_events, &(&1[:coordination_quality] || 0.0))
      mean = Enum.sum(qualities) / length(qualities)
      calculate_variance(qualities, mean)
    end
  end

  defp identify_alpha_strikes(timeline) do
    # Identify concentrated kill windows that represent alpha strikes
    timeline.events
    # 5-second windows for alpha strikes
    |> create_time_windows(5)
    |> Enum.filter(fn {_time, events} ->
      # At least 3 kills for alpha strike
      length(events) >= 3
    end)
    |> Enum.map(fn {window_time, events} ->
      %{
        timestamp: window_time,
        kills: length(events),
        window_duration: 5,
        participants: count_unique_attackers(events),
        total_isk: Enum.sum(Enum.map(events, &(&1[:isk_value] || 0))),
        targets: extract_unique_targets(events)
      }
    end)
  end

  defp calculate_timing_precision(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      # Precision based on kill concentration in time windows
      total_precision =
        alpha_strikes
        |> Enum.map(fn strike ->
          # Higher kill density = higher precision
          strike.kills / max(strike.window_duration, 1)
        end)
        |> Enum.sum()

      avg_precision = total_precision / length(alpha_strikes)
      # Normalize to 0-1
      min(avg_precision / 2.0, 1.0)
    end
  end

  defp identify_retreat_events(timeline) do
    # Identify potential retreat events from battle patterns
    events = timeline.events

    if length(events) < 5 do
      []
    else
      # Look for sudden drops in activity
      intensity_by_window =
        events
        # 1-minute windows
        |> create_time_windows(60)
        |> Enum.map(fn {time, window_events} ->
          {time, length(window_events)}
        end)

      # Find significant drops that might indicate retreat
      intensity_by_window
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.filter(fn {[{_prev_time, prev_intensity}, {_curr_time, curr_intensity}], _index} ->
        # 50% drop in intensity might indicate retreat
        prev_intensity > 2 && curr_intensity < prev_intensity * 0.5
      end)
      |> Enum.map(fn {[{_prev_time, _prev_intensity}, {curr_time, curr_intensity}], index} ->
        %{
          timestamp: curr_time,
          type: :potential_retreat,
          intensity_drop: curr_intensity,
          sequence_position: index
        }
      end)
    end
  end

  defp calculate_retreat_decision_timing(retreat_events, timeline) do
    if Enum.empty?(retreat_events) do
      # Neutral if no retreats
      0.5
    else
      # Analyze timing of retreat decisions
      battle_duration =
        if length(timeline.events) >= 2 do
          DateTime.diff(
            List.last(timeline.events).timestamp,
            List.first(timeline.events).timestamp
          )
        else
          0
        end

      # Earlier retreats might indicate good timing
      retreat_timing_scores =
        retreat_events
        |> Enum.map(fn retreat ->
          retreat_time = DateTime.diff(retreat.timestamp, List.first(timeline.events).timestamp)
          timing_ratio = if battle_duration > 0, do: retreat_time / battle_duration, else: 0.5

          cond do
            # Early, might be good
            timing_ratio < 0.3 -> 0.8
            # Mid-battle, strategic
            timing_ratio < 0.7 -> 1.0
            # Late, might be desperate
            true -> 0.6
          end
        end)

      Enum.sum(retreat_timing_scores) / length(retreat_timing_scores)
    end
  end

  defp calculate_retreat_execution_speed(retreat_events) do
    if Enum.empty?(retreat_events) do
      0.5
    else
      # Speed based on intensity drop rate
      avg_drop =
        retreat_events
        |> Enum.map(& &1.intensity_drop)
        |> Enum.sum()
        |> then(&(&1 / length(retreat_events)))

      # Higher drop = faster execution
      min(avg_drop / 5.0, 1.0)
    end
  end

  defp calculate_retreat_coordination(retreat_events) do
    if length(retreat_events) <= 1 do
      # Perfect if single or no retreat
      1.0
    else
      # Check if retreats were coordinated vs scattered
      retreat_times = Enum.map(retreat_events, & &1.timestamp)
      time_windows = create_retreat_time_windows(retreat_times)

      # More retreats in same window = better coordination
      coordinated_retreats = Enum.count(time_windows, fn window -> length(window) > 1 end)

      if length(time_windows) > 0 do
        coordinated_retreats / length(time_windows)
      else
        0.0
      end
    end
  end

  defp calculate_kill_intervals(timeline) do
    if Enum.count(timeline.events) < 2 do
      []
    else
      timeline.events
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        DateTime.diff(curr.timestamp, prev.timestamp)
      end)
    end
  end

  defp create_retreat_time_windows(retreat_times) do
    # Group retreats into 2-minute windows
    retreat_times
    |> Enum.group_by(fn timestamp ->
      unix = DateTime.to_unix(timestamp)
      # 2-minute windows
      div(unix, 120) * 120
    end)
    |> Map.values()
  end

  # Additional timing helper functions
  defp identify_tempo_changes(timeline) do
    # Identify changes in battle tempo
    if length(timeline.events) < 4 do
      []
    else
      intervals = calculate_kill_intervals(timeline)
      avg_interval = Enum.sum(intervals) / length(intervals)

      intervals
      |> Enum.with_index()
      |> Enum.filter(fn {interval, _index} ->
        # Significant tempo change
        abs(interval - avg_interval) > avg_interval * 0.5
      end)
      |> Enum.map(fn {interval, index} ->
        %{
          timestamp: Enum.at(timeline.events, index + 1).timestamp,
          type: if(interval > avg_interval, do: :slowdown, else: :acceleration),
          magnitude: abs(interval - avg_interval) / avg_interval
        }
      end)
    end
  end

  defp calculate_synchronization_score(timeline) do
    # Score based on kill timing synchronization
    if Enum.count(timeline.events) < 2 do
      0.0
    else
      # Look for kills happening in close succession
      close_kills =
        timeline.events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [prev, curr] ->
          DateTime.diff(curr.timestamp, prev.timestamp) < 5
        end)

      if length(timeline.events) > 1 do
        close_kills / (length(timeline.events) - 1)
      else
        0.0
      end
    end
  end

  defp calculate_average_response_time(coordination_events) do
    if Enum.empty?(coordination_events) do
      0.0
    else
      # Average response time from coordination events
      response_times = calculate_response_times(coordination_events)
      Enum.sum(response_times) / length(response_times)
    end
  end

  defp calculate_average_alpha_window(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      # Average window duration for alpha strikes
      total_duration = Enum.sum(Enum.map(alpha_strikes, & &1.window_duration))
      total_duration / length(alpha_strikes)
    end
  end

  defp calculate_alpha_effectiveness(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      # Effectiveness based on ISK destroyed per strike
      total_isk = Enum.sum(Enum.map(alpha_strikes, & &1.total_isk))
      avg_isk = total_isk / length(alpha_strikes)

      # Normalize to 0-1 scale (1B ISK = high effectiveness)
      min(avg_isk / 1_000_000_000, 1.0)
    end
  end

  defp calculate_alpha_concentration(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      # Concentration based on kills per strike
      total_kills = Enum.sum(Enum.map(alpha_strikes, & &1.kills))
      avg_kills = total_kills / length(alpha_strikes)

      # Normalize to 0-1 scale
      min(avg_kills / 5.0, 1.0)
    end
  end

  defp calculate_alpha_coordination(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      # Coordination based on participant alignment
      total_participants = Enum.sum(Enum.map(alpha_strikes, & &1.participants))
      avg_participants = total_participants / length(alpha_strikes)

      # More participants = better coordination for alpha strikes
      min(avg_participants / 10.0, 1.0)
    end
  end

  # Additional helper functions for retreat timing and rhythm analysis
  defp evaluate_retreat_decision_timing(retreat_events, timeline) do
    calculate_retreat_decision_timing(retreat_events, timeline)
  end

  defp evaluate_retreat_execution(retreat_events) do
    calculate_retreat_execution_speed(retreat_events)
  end

  defp evaluate_retreat_coordination(retreat_events) do
    calculate_retreat_coordination(retreat_events)
  end

  defp evaluate_retreat_effectiveness(retreat_events, _timeline) do
    if Enum.empty?(retreat_events) do
      # Perfect if no retreat needed
      1.0
    else
      # Effectiveness based on successful disengagement
      avg_intensity_drop =
        retreat_events
        |> Enum.map(& &1.intensity_drop)
        |> Enum.sum()
        |> then(&(&1 / length(retreat_events)))

      min(avg_intensity_drop / 3.0, 1.0)
    end
  end

  defp identify_retreat_triggers(retreat_events, timeline) do
    # Identify what triggered retreat decisions
    retreat_events
    |> Enum.map(fn retreat ->
      # Analyze events before retreat to identify triggers
      events_before_retreat =
        timeline.events
        |> Enum.filter(fn event ->
          DateTime.diff(retreat.timestamp, event.timestamp) <= 60 &&
            DateTime.diff(retreat.timestamp, event.timestamp) > 0
        end)

      trigger_type =
        cond do
          length(events_before_retreat) > 5 -> :heavy_losses
          length(events_before_retreat) > 2 -> :escalation
          true -> :tactical
        end

      %{
        trigger: trigger_type,
        events_count: length(events_before_retreat),
        timestamp: retreat.timestamp
      }
    end)
  end

  defp identify_rhythm_patterns(kill_intervals) do
    if length(kill_intervals) < 3 do
      []
    else
      # Identify patterns in kill timing
      avg_interval = Enum.sum(kill_intervals) / length(kill_intervals)

      patterns = []

      # Check for burst patterns (multiple short intervals)
      short_intervals = Enum.count(kill_intervals, &(&1 < avg_interval * 0.5))

      patterns =
        if short_intervals > length(kill_intervals) * 0.3 do
          [:burst | patterns]
        else
          patterns
        end

      # Check for sustained patterns (consistent intervals)
      variance = calculate_variance(kill_intervals, avg_interval)

      patterns =
        if variance < avg_interval * 0.3 do
          [:sustained | patterns]
        else
          patterns
        end

      # Check for wave patterns (alternating intervals)
      patterns =
        if has_wave_pattern?(kill_intervals) do
          [:wave | patterns]
        else
          patterns
        end

      patterns
    end
  end

  defp calculate_rhythm_consistency(kill_intervals) do
    if length(kill_intervals) < 2 do
      1.0
    else
      avg_interval = Enum.sum(kill_intervals) / length(kill_intervals)
      variance = calculate_variance(kill_intervals, avg_interval)

      # Lower variance = higher consistency
      if avg_interval > 0 do
        1.0 - min(variance / (avg_interval * avg_interval), 1.0)
      else
        0.0
      end
    end
  end

  defp calculate_overall_tempo_rating(kill_intervals) do
    if Enum.empty?(kill_intervals) do
      0.0
    else
      avg_interval = Enum.sum(kill_intervals) / length(kill_intervals)

      # Rate tempo - faster = higher rating
      cond do
        # Very fast
        avg_interval < 10 -> 1.0
        # Fast
        avg_interval < 30 -> 0.8
        # Moderate
        avg_interval < 60 -> 0.6
        # Slow
        avg_interval < 120 -> 0.4
        # Very slow
        true -> 0.2
      end
    end
  end

  defp has_wave_pattern?(kill_intervals) do
    if length(kill_intervals) < 4 do
      false
    else
      # Check for alternating short/long intervals
      alternating_count =
        kill_intervals
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [first, second] ->
          (first < second && second > first * 1.5) ||
            (second < first && first > second * 1.5)
        end)

      alternating_count > length(kill_intervals) * 0.4
    end
  end

  # Final helper functions for rhythm analysis
  defp calculate_rhythm_adaptability(rhythm_patterns) do
    # More diverse patterns = higher adaptability
    pattern_count = length(Enum.uniq(rhythm_patterns))
    min(pattern_count / 3.0, 1.0)
  end

  defp calculate_rhythm_effectiveness(_timeline, rhythm_patterns) do
    if Enum.empty?(rhythm_patterns) do
      0.5
    else
      # Effectiveness based on achieving rapid kills with identified patterns
      base_effectiveness = if :burst in rhythm_patterns, do: 0.8, else: 0.6
      consistency_bonus = if :sustained in rhythm_patterns, do: 0.2, else: 0.0

      effectiveness = base_effectiveness + consistency_bonus
      min(effectiveness, 1.0)
    end
  end

  defp create_tempo_profile(timeline) do
    # Create tempo profile over time
    if Enum.count(timeline.events) < 2 do
      []
    else
      timeline.events
      # 1-minute windows
      |> create_time_windows(60)
      |> Enum.map(fn {timestamp, events} ->
        %{
          timestamp: timestamp,
          kills: length(events),
          # kills per second
          tempo_rating: length(events) / 60.0
        }
      end)
    end
  end

  defp identify_peak_periods(timeline) do
    # Identify periods of peak activity
    tempo_profile = create_tempo_profile(timeline)

    if Enum.empty?(tempo_profile) do
      []
    else
      avg_tempo =
        tempo_profile
        |> Enum.map(& &1.tempo_rating)
        |> Enum.sum()
        |> then(&(&1 / length(tempo_profile)))

      # Identify periods above average
      tempo_profile
      |> Enum.filter(&(&1.tempo_rating > avg_tempo * 1.5))
      |> Enum.map(fn period ->
        %{
          timestamp: period.timestamp,
          intensity: period.tempo_rating,
          kills: period.kills,
          peak_type:
            cond do
              period.tempo_rating > avg_tempo * 3 -> :extreme
              period.tempo_rating > avg_tempo * 2 -> :high
              true -> :moderate
            end
        }
      end)
    end
  end

  # Innovation analysis helper functions
  defp identify_novel_tactics(timeline, participants) do
    # Identify novel tactical approaches during the battle
    if Enum.count(timeline.events) < 3 do
      []
    else
      novel_tactics = []

      # Look for unusual ship compositions
      ship_compositions = analyze_ship_composition_changes(timeline, participants)

      novel_tactics =
        if has_unusual_composition?(ship_compositions) do
          [create_novel_tactic(:unusual_composition, ship_compositions, timeline) | novel_tactics]
        else
          novel_tactics
        end

      # Look for unconventional target prioritization
      target_priorities = analyze_target_priority_changes(timeline)

      novel_tactics =
        if has_unconventional_targeting?(target_priorities) do
          [
            create_novel_tactic(:unconventional_targeting, target_priorities, timeline)
            | novel_tactics
          ]
        else
          novel_tactics
        end

      # Look for innovative positioning
      positioning_changes = analyze_positioning_innovations(timeline, participants)

      novel_tactics =
        if has_innovative_positioning?(positioning_changes) do
          [
            create_novel_tactic(:innovative_positioning, positioning_changes, timeline)
            | novel_tactics
          ]
        else
          novel_tactics
        end

      # Look for timing innovations
      timing_innovations = analyze_timing_innovations(timeline)

      novel_tactics =
        if has_timing_innovations?(timing_innovations) do
          [create_novel_tactic(:timing_innovation, timing_innovations, timeline) | novel_tactics]
        else
          novel_tactics
        end

      novel_tactics
    end
  end

  defp identify_tactical_adaptations(timeline, participants) do
    # Identify how participants adapted to changing conditions
    if Enum.count(timeline.events) < 5 do
      []
    else
      adaptations = []

      # Look for adaptations to losses
      loss_adaptations = analyze_loss_adaptations(timeline, participants)
      adaptations = adaptations ++ loss_adaptations

      # Look for adaptations to enemy tactics
      tactical_adaptations = analyze_tactical_counter_adaptations(timeline, participants)
      adaptations = adaptations ++ tactical_adaptations

      # Look for formation adaptations
      formation_adaptations = analyze_formation_adaptations(timeline, participants)
      adaptations = adaptations ++ formation_adaptations

      # Look for timing adaptations
      timing_adaptations = analyze_timing_adaptations(timeline)
      adaptations = adaptations ++ timing_adaptations

      adaptations
    end
  end

  defp identify_counter_tactics(timeline, participants) do
    # Identify counter-tactical responses
    if length(timeline.events) < 4 do
      []
    else
      counter_tactics = []

      # Look for counter-positioning
      position_counters = identify_position_counter_tactics(timeline, participants)
      counter_tactics = counter_tactics ++ position_counters

      # Look for target switching counters
      target_counters = identify_target_counter_tactics(timeline)
      counter_tactics = counter_tactics ++ target_counters

      # Look for timing counters
      timing_counters = identify_timing_counter_tactics(timeline)
      counter_tactics = counter_tactics ++ timing_counters

      # Look for composition counters
      composition_counters = identify_composition_counter_tactics(timeline, participants)
      counter_tactics = counter_tactics ++ composition_counters

      counter_tactics
    end
  end

  defp evaluate_innovation_effectiveness(timeline, participants) do
    # Evaluate how effective the innovations were
    if Enum.count(timeline.events) < 3 do
      %{overall_score: 0.0, details: []}
    else
      # Analyze pre and post innovation performance
      innovations = identify_innovation_points(timeline, participants)

      effectiveness_scores =
        innovations
        |> Enum.map(fn innovation ->
          pre_performance = calculate_pre_innovation_performance(timeline, innovation)
          post_performance = calculate_post_innovation_performance(timeline, innovation)

          %{
            innovation_type: innovation.type,
            timestamp: innovation.timestamp,
            pre_performance: pre_performance,
            post_performance: post_performance,
            improvement: post_performance - pre_performance,
            effectiveness_score: calculate_effectiveness_score(pre_performance, post_performance)
          }
        end)

      overall_score =
        if length(effectiveness_scores) > 0 do
          total_score = Enum.sum(Enum.map(effectiveness_scores, & &1.effectiveness_score))
          total_score / length(effectiveness_scores)
        else
          0.0
        end

      %{
        overall_score: overall_score,
        details: effectiveness_scores,
        innovation_count: length(innovations),
        successful_innovations: Enum.count(effectiveness_scores, &(&1.improvement > 0))
      }
    end
  end

  defp analyze_learning_patterns(timeline, participants) do
    # Analyze how participants learned and improved during battle
    if length(timeline.events) < 6 do
      %{patterns: [], learning_rate: 0.0, adaptation_speed: 0.0}
    else
      # Divide battle into phases to track learning
      battle_phases = divide_battle_into_learning_phases(timeline)

      learning_patterns =
        battle_phases
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.with_index()
        |> Enum.map(fn {[prev_phase, curr_phase], index} ->
          analyze_phase_learning(prev_phase, curr_phase, index, participants)
        end)
        |> Enum.reject(&is_nil/1)

      learning_rate = calculate_learning_rate(learning_patterns)
      adaptation_speed = calculate_adaptation_speed_from_patterns(learning_patterns)

      %{
        patterns: learning_patterns,
        learning_rate: learning_rate,
        adaptation_speed: adaptation_speed,
        learning_effectiveness: evaluate_learning_effectiveness(learning_patterns),
        key_learnings: identify_key_learnings(learning_patterns)
      }
    end
  end

  # Supporting functions for innovation analysis
  defp analyze_ship_composition_changes(timeline, participants) do
    # Analyze how ship compositions changed over time
    timeline.events
    # 2-minute windows
    |> create_time_windows(120)
    |> Enum.map(fn {timestamp, events} ->
      ship_types = extract_ship_types_from_events(events, participants)
      composition = Enum.frequencies(ship_types)

      %{
        timestamp: timestamp,
        composition: composition,
        diversity: length(Map.keys(composition)),
        dominant_type: get_dominant_ship_type(composition)
      }
    end)
  end

  defp has_unusual_composition?(compositions) do
    if length(compositions) < 2 do
      false
    else
      # Check for significant composition changes
      composition_changes =
        compositions
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          calculate_composition_change(prev.composition, curr.composition)
        end)

      # 50% composition change
      Enum.any?(composition_changes, &(&1 > 0.5))
    end
  end

  defp analyze_target_priority_changes(timeline) do
    # Analyze how target priorities changed
    timeline.events
    # Overlapping windows
    |> Enum.chunk_every(5, 2, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {events, index} ->
      priorities =
        Enum.map(events, fn event ->
          ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(event.victim[:ship_type_id])
          get_threat_value_by_class(ship_class)
        end)

      %{
        window_index: index,
        timestamp: List.first(events).timestamp,
        priority_pattern: priorities,
        avg_priority: Enum.sum(priorities) / length(priorities),
        priority_variance:
          calculate_variance(priorities, Enum.sum(priorities) / length(priorities))
      }
    end)
  end

  defp has_unconventional_targeting?(target_priorities) do
    if length(target_priorities) < 2 do
      false
    else
      # Look for unusual priority patterns
      priority_changes =
        target_priorities
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          abs(curr.avg_priority - prev.avg_priority)
        end)

      # Significant priority shift
      Enum.any?(priority_changes, &(&1 > 0.3))
    end
  end

  defp analyze_positioning_innovations(_timeline, _participants) do
    # Analyze positioning innovations (simplified)
    # Would analyze position data if available
    []
  end

  defp has_innovative_positioning?(positioning_changes) do
    length(positioning_changes) > 0
  end

  defp analyze_timing_innovations(timeline) do
    # Analyze timing pattern innovations
    rhythm_changes = identify_rhythm_changes(timeline)
    tempo_shifts = identify_tempo_shifts(timeline)

    %{
      rhythm_changes: rhythm_changes,
      tempo_shifts: tempo_shifts,
      timing_adaptations: rhythm_changes ++ tempo_shifts
    }
  end

  defp has_timing_innovations?(timing_innovations) do
    length(timing_innovations.timing_adaptations) > 2
  end

  defp create_novel_tactic(type, data, timeline) do
    %{
      type: type,
      timestamp:
        if(length(timeline.events) > 0, do: List.first(timeline.events).timestamp, else: nil),
      data: data,
      novelty_score: calculate_novelty_score(type, data),
      battle_phase:
        determine_battle_phase_for_timestamp(timeline, List.first(timeline.events).timestamp)
    }
  end

  defp analyze_loss_adaptations(timeline, participants) do
    # Identify adaptations following losses
    high_loss_events = identify_high_loss_periods(timeline, participants)

    high_loss_events
    |> Enum.map(fn loss_period ->
      post_loss_behavior = analyze_post_loss_behavior(timeline, loss_period, participants)

      if shows_adaptation?(post_loss_behavior) do
        %{
          type: :loss_adaptation,
          timestamp: loss_period.end_time,
          trigger: loss_period,
          adaptation: post_loss_behavior,
          effectiveness: evaluate_adaptation_effectiveness(post_loss_behavior)
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp analyze_tactical_counter_adaptations(_timeline, _participants) do
    # Analyze adaptations to enemy tactics (simplified)
    # Would analyze tactical responses
    []
  end

  defp analyze_formation_adaptations(_timeline, _participants) do
    # Analyze formation adaptations (simplified)
    # Would analyze formation changes
    []
  end

  defp analyze_timing_adaptations(timeline) do
    # Analyze timing adaptations
    rhythm_adaptations = identify_rhythm_adaptations(timeline)

    rhythm_adaptations
    |> Enum.map(fn adaptation ->
      %{
        type: :timing_adaptation,
        timestamp: adaptation.timestamp,
        change: adaptation.change,
        effectiveness: adaptation.effectiveness
      }
    end)
  end

  # Helper functions for counter-tactics
  defp identify_position_counter_tactics(_timeline, _participants) do
    # Simplified
    []
  end

  defp identify_target_counter_tactics(timeline) do
    # Look for reactive target switching
    target_switches = identify_target_switches(timeline.events)

    target_switches
    |> Enum.filter(fn switch ->
      # Counter-tactical if switch improved threat reduction
      from_threat = get_threat_value_by_id(switch.from_target)
      to_threat = get_threat_value_by_id(switch.to_target)
      to_threat > from_threat
    end)
    |> Enum.map(fn switch ->
      %{
        type: :target_counter,
        timestamp: switch.timestamp,
        from_target: switch.from_target,
        to_target: switch.to_target,
        tactical_improvement:
          get_threat_value_by_id(switch.to_target) - get_threat_value_by_id(switch.from_target)
      }
    end)
  end

  defp identify_timing_counter_tactics(timeline) do
    # Look for timing-based counters
    alpha_strikes = identify_alpha_strikes(timeline)

    alpha_strikes
    |> Enum.filter(fn strike ->
      # Counter-tactical if it came after enemy escalation
      strike.kills >= 3 && strike.participants >= 5
    end)
    |> Enum.map(fn strike ->
      %{
        type: :timing_counter,
        timestamp: strike.timestamp,
        participants: strike.participants,
        kills: strike.kills,
        counter_effectiveness: strike.total_isk / 1_000_000_000
      }
    end)
  end

  defp identify_composition_counter_tactics(_timeline, _participants) do
    # Simplified
    []
  end

  # Innovation effectiveness helpers
  defp identify_innovation_points(timeline, participants) do
    # Identify key moments of innovation
    adaptations = identify_tactical_adaptations(timeline, participants)
    novel_tactics = identify_novel_tactics(timeline, participants)

    (adaptations ++ novel_tactics)
    |> Enum.map(fn innovation ->
      %{
        type: innovation[:type] || :unknown,
        timestamp: innovation[:timestamp] || List.first(timeline.events).timestamp
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp calculate_pre_innovation_performance(timeline, innovation) do
    # Calculate performance before innovation
    events_before =
      timeline.events
      |> Enum.filter(fn event ->
        DateTime.diff(innovation.timestamp, event.timestamp) <= 120 &&
          DateTime.diff(innovation.timestamp, event.timestamp) > 0
      end)

    if length(events_before) > 0 do
      avg_interval = calculate_average_kill_interval(events_before)
      # Performance = inverse of time between kills
      1.0 / max(avg_interval, 1)
    else
      0.0
    end
  end

  defp calculate_post_innovation_performance(timeline, innovation) do
    # Calculate performance after innovation
    events_after =
      timeline.events
      |> Enum.filter(fn event ->
        DateTime.diff(event.timestamp, innovation.timestamp) <= 120 &&
          DateTime.diff(event.timestamp, innovation.timestamp) > 0
      end)

    if length(events_after) > 0 do
      avg_interval = calculate_average_kill_interval(events_after)
      # Performance = inverse of time between kills
      1.0 / max(avg_interval, 1)
    else
      0.0
    end
  end

  defp calculate_effectiveness_score(pre_performance, post_performance) do
    if pre_performance > 0 do
      (post_performance - pre_performance) / pre_performance
    else
      if post_performance > 0, do: 1.0, else: 0.0
    end
  end

  # Learning analysis helpers
  defp divide_battle_into_learning_phases(timeline) do
    # Divide battle into phases for learning analysis
    total_events = length(timeline.events)
    # 4 phases minimum
    phase_size = max(div(total_events, 4), 2)

    timeline.events
    |> Enum.chunk_every(phase_size, phase_size, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {events, index} ->
      %{
        phase_index: index,
        events: events,
        start_time: List.first(events).timestamp,
        end_time: List.last(events).timestamp,
        performance: calculate_phase_performance(events)
      }
    end)
  end

  defp analyze_phase_learning(prev_phase, curr_phase, index, participants) do
    performance_change = curr_phase.performance - prev_phase.performance

    # Significant change
    if abs(performance_change) > 0.1 do
      %{
        phase_transition: index,
        timestamp: curr_phase.start_time,
        performance_change: performance_change,
        learning_type: classify_learning_type(performance_change, prev_phase, curr_phase),
        participants_involved:
          estimate_learning_participants(prev_phase, curr_phase, participants)
      }
    else
      nil
    end
  end

  defp calculate_learning_rate(learning_patterns) do
    if Enum.empty?(learning_patterns) do
      0.0
    else
      positive_changes = Enum.count(learning_patterns, &(&1.performance_change > 0))
      positive_changes / length(learning_patterns)
    end
  end

  defp calculate_adaptation_speed_from_patterns(learning_patterns) do
    if length(learning_patterns) < 2 do
      0.0
    else
      # Speed based on how quickly adaptations occurred
      time_between_adaptations =
        learning_patterns
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          DateTime.diff(curr.timestamp, prev.timestamp)
        end)

      if length(time_between_adaptations) > 0 do
        avg_time = Enum.sum(time_between_adaptations) / length(time_between_adaptations)
        # Adaptations per minute
        1.0 / max(avg_time / 60, 1)
      else
        0.0
      end
    end
  end

  # Utility functions for innovation analysis
  defp extract_ship_types_from_events(events, _participants) do
    events
    |> Enum.map(& &1.victim[:ship_type_id])
    |> Enum.reject(&is_nil/1)
  end

  defp get_dominant_ship_type(composition) do
    if map_size(composition) > 0 do
      composition
      |> Enum.max_by(fn {_type, count} -> count end)
      |> elem(0)
    else
      nil
    end
  end

  defp calculate_composition_change(prev_comp, curr_comp) do
    # Calculate how much the composition changed
    all_types = MapSet.union(MapSet.new(Map.keys(prev_comp)), MapSet.new(Map.keys(curr_comp)))

    total_change =
      all_types
      |> Enum.map(fn type ->
        prev_count = Map.get(prev_comp, type, 0)
        curr_count = Map.get(curr_comp, type, 0)
        abs(curr_count - prev_count)
      end)
      |> Enum.sum()

    total_prev = Enum.sum(Map.values(prev_comp))
    total_curr = Enum.sum(Map.values(curr_comp))
    total_base = max(total_prev + total_curr, 1)

    total_change / total_base
  end

  defp identify_rhythm_changes(timeline) do
    # Identify changes in battle rhythm
    tempo_profile = create_tempo_profile(timeline)

    tempo_profile
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      tempo_change = curr.tempo_rating - prev.tempo_rating

      if abs(tempo_change) > prev.tempo_rating * 0.5 do
        %{
          timestamp: curr.timestamp,
          change_type: if(tempo_change > 0, do: :acceleration, else: :deceleration),
          magnitude: abs(tempo_change) / max(prev.tempo_rating, 0.1)
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp identify_tempo_shifts(timeline) do
    # Same as rhythm changes for now
    identify_rhythm_changes(timeline)
  end

  defp calculate_novelty_score(type, _data) do
    # Score novelty based on type
    case type do
      :unusual_composition -> 0.8
      :unconventional_targeting -> 0.7
      :innovative_positioning -> 0.9
      :timing_innovation -> 0.6
      _ -> 0.5
    end
  end

  defp determine_battle_phase_for_timestamp(timeline, timestamp) do
    if length(timeline.events) > 0 do
      battle_start = List.first(timeline.events).timestamp
      battle_end = List.last(timeline.events).timestamp
      total_duration = DateTime.diff(battle_end, battle_start)
      elapsed = DateTime.diff(timestamp, battle_start)

      cond do
        elapsed < total_duration / 3 -> :opening
        elapsed < total_duration * 2 / 3 -> :mid_battle
        true -> :conclusion
      end
    else
      :unknown
    end
  end

  defp identify_high_loss_periods(timeline, _participants) do
    # Identify periods of high losses
    timeline.events
    # 1-minute windows
    |> create_time_windows(60)
    |> Enum.filter(fn {_time, events} -> length(events) >= 3 end)
    |> Enum.map(fn {start_time, events} ->
      %{
        start_time: start_time,
        end_time: DateTime.add(start_time, 60, :second),
        loss_count: length(events),
        total_isk_lost: Enum.sum(Enum.map(events, &(&1[:isk_value] || 0)))
      }
    end)
  end

  defp analyze_post_loss_behavior(timeline, loss_period, _participants) do
    # Analyze behavior following high loss period
    events_after =
      timeline.events
      |> Enum.filter(fn event ->
        DateTime.diff(event.timestamp, loss_period.end_time) > 0 &&
          DateTime.diff(event.timestamp, loss_period.end_time) <= 180
      end)

    %{
      kill_rate_change: calculate_kill_rate_change(events_after, loss_period),
      tactical_changes: identify_tactical_changes_after_loss(events_after),
      recovery_time: calculate_recovery_time(events_after, loss_period)
    }
  end

  defp shows_adaptation?(behavior) do
    behavior.kill_rate_change > 0.2 || length(behavior.tactical_changes) > 0
  end

  defp evaluate_adaptation_effectiveness(behavior) do
    effectiveness = 0.0
    effectiveness = effectiveness + min(behavior.kill_rate_change, 0.5) * 2
    effectiveness = effectiveness + length(behavior.tactical_changes) * 0.2
    min(effectiveness, 1.0)
  end

  defp identify_rhythm_adaptations(timeline) do
    rhythm_changes = identify_rhythm_changes(timeline)

    rhythm_changes
    |> Enum.map(fn change ->
      %{
        timestamp: change.timestamp,
        change: change,
        effectiveness: calculate_rhythm_change_effectiveness(change, timeline)
      }
    end)
  end

  defp calculate_average_kill_interval(events) do
    if length(events) < 2 do
      0
    else
      intervals = calculate_kill_intervals(%{events: events})
      Enum.sum(intervals) / length(intervals)
    end
  end

  defp calculate_phase_performance(events) do
    if Enum.empty?(events) do
      0.0
    else
      # Performance based on kill rate
      time_span =
        if length(events) > 1 do
          DateTime.diff(List.last(events).timestamp, List.first(events).timestamp)
        else
          60
        end

      # Kills per minute
      length(events) / max(time_span / 60, 1)
    end
  end

  defp classify_learning_type(performance_change, _prev_phase, _curr_phase) do
    cond do
      performance_change > 0.3 -> :breakthrough
      performance_change > 0.1 -> :improvement
      performance_change < -0.3 -> :regression
      performance_change < -0.1 -> :decline
      true -> :stable
    end
  end

  defp estimate_learning_participants(_prev_phase, _curr_phase, participants) do
    # Simplified estimation
    div(length(participants), 2)
  end

  defp evaluate_learning_effectiveness(learning_patterns) do
    if Enum.empty?(learning_patterns) do
      0.0
    else
      positive_patterns = Enum.count(learning_patterns, &(&1.performance_change > 0))
      positive_patterns / length(learning_patterns)
    end
  end

  defp identify_key_learnings(learning_patterns) do
    learning_patterns
    |> Enum.filter(&(&1.performance_change > 0.2))
    |> Enum.map(fn pattern ->
      %{
        type: pattern.learning_type,
        timestamp: pattern.timestamp,
        impact: pattern.performance_change
      }
    end)
  end

  defp calculate_kill_rate_change(events_after, loss_period) do
    if Enum.empty?(events_after) do
      # Complete shutdown
      -1.0
    else
      # Per minute over 3 minutes
      after_rate = length(events_after) / 3
      # Per minute during loss period
      before_rate = loss_period.loss_count / 1

      (after_rate - before_rate) / max(before_rate, 0.1)
    end
  end

  defp identify_tactical_changes_after_loss(events_after) do
    # Simplified tactical change identification
    ship_types = Enum.map(events_after, & &1.victim[:ship_type_id])
    ship_classes = Enum.map(ship_types, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)

    if :frigate in ship_classes && :cruiser in ship_classes do
      [:target_prioritization_change]
    else
      []
    end
  end

  defp calculate_recovery_time(events_after, _loss_period) do
    if length(events_after) >= 2 do
      first_kill = List.first(events_after)
      second_kill = Enum.at(events_after, 1)
      DateTime.diff(second_kill.timestamp, first_kill.timestamp)
    else
      # Long recovery time if no quick follow-up
      300
    end
  end

  defp calculate_rhythm_change_effectiveness(change, timeline) do
    # Evaluate if rhythm change improved performance
    events_after_change =
      timeline.events
      |> Enum.filter(fn event ->
        DateTime.diff(event.timestamp, change.timestamp) > 0 &&
          DateTime.diff(event.timestamp, change.timestamp) <= 120
      end)

    if length(events_after_change) > 2 do
      # Per minute
      post_change_rate = length(events_after_change) / 2

      case change.change_type do
        :acceleration -> min(post_change_rate / 2, 1.0)
        :deceleration -> min(1.0 - post_change_rate / 5, 1.0)
        _ -> 0.5
      end
    else
      0.5
    end
  end

  # Summary calculation functions
  defp calculate_adaptation_speed(adaptations) do
    if length(adaptations) < 2 do
      0.0
    else
      # Speed based on time between adaptations
      adaptation_times = Enum.map(adaptations, & &1[:timestamp])

      time_deltas =
        adaptation_times
        |> Enum.sort()
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] -> DateTime.diff(curr, prev) end)

      if length(time_deltas) > 0 do
        avg_time = Enum.sum(time_deltas) / length(time_deltas)
        # Adaptations per minute
        1.0 / max(avg_time / 60, 1)
      else
        0.0
      end
    end
  end

  defp calculate_innovation_success_rate(novel_tactics, effectiveness) do
    if Enum.empty?(novel_tactics) do
      0.0
    else
      successful_innovations = effectiveness[:successful_innovations] || 0
      successful_innovations / length(novel_tactics)
    end
  end

  defp calculate_tactical_flexibility(adaptations, counter_tactics) do
    total_tactical_moves = length(adaptations) + length(counter_tactics)

    if total_tactical_moves == 0 do
      0.0
    else
      # Flexibility based on variety and speed of tactical responses
      adaptation_variety = length(Enum.uniq(Enum.map(adaptations, & &1[:type])))
      counter_variety = length(Enum.uniq(Enum.map(counter_tactics, & &1[:type])))

      total_variety = adaptation_variety + counter_variety
      variety_score = min(total_variety / 5.0, 1.0)

      # Speed component
      speed_score = calculate_adaptation_speed(adaptations ++ counter_tactics)

      # Combined score
      variety_score * 0.6 + speed_score * 0.4
    end
  end

  # Command pattern analysis helper functions
  defp identify_command_structure(participants) do
    # Analyze organizational structure from participant data
    if Enum.empty?(participants) do
      %{type: :unknown, hierarchy: [], command_depth: 0}
    else
      # Group by corporation and alliance
      alliance_groups = group_participants_by_alliance(participants)
      corp_groups = group_participants_by_corporation(participants)

      # Determine structure type
      structure_type = determine_structure_type(alliance_groups, corp_groups, participants)

      # Build hierarchy
      hierarchy = build_command_hierarchy(alliance_groups, corp_groups)

      # Calculate command depth
      command_depth = calculate_command_depth(hierarchy)

      %{
        type: structure_type,
        hierarchy: hierarchy,
        command_depth: command_depth,
        alliance_count: length(Map.keys(alliance_groups)),
        corporation_count: length(Map.keys(corp_groups)),
        participant_distribution:
          calculate_participant_distribution(alliance_groups, corp_groups),
        unity_score: calculate_organizational_unity(alliance_groups, corp_groups, participants)
      }
    end
  end

  defp analyze_decision_making(timeline, participants) do
    # Analyze decision-making patterns from battle events
    if Enum.count(timeline.events) < 3 do
      %{decisions: [], decision_speed: 0.0, decision_quality: 0.0}
    else
      # Identify key decision points
      decision_points = identify_decision_points(timeline, participants)

      # Analyze decision speed
      decision_speeds = calculate_decision_speeds(decision_points, timeline)

      avg_decision_speed =
        if length(decision_speeds) > 0 do
          Enum.sum(decision_speeds) / length(decision_speeds)
        else
          0.0
        end

      # Analyze decision quality
      decision_outcomes = evaluate_decision_outcomes(decision_points, timeline)

      avg_decision_quality =
        if length(decision_outcomes) > 0 do
          Enum.sum(Enum.map(decision_outcomes, & &1.quality_score)) / length(decision_outcomes)
        else
          0.0
        end

      %{
        decisions: decision_points,
        decision_speed: avg_decision_speed,
        decision_quality: avg_decision_quality,
        decision_consistency: calculate_decision_consistency(decision_points),
        strategic_decisions: Enum.filter(decision_points, &(&1.type == :strategic)),
        tactical_decisions: Enum.filter(decision_points, &(&1.type == :tactical)),
        reactive_decisions: Enum.filter(decision_points, &(&1.type == :reactive))
      }
    end
  end

  defp analyze_information_flow(timeline, participants) do
    # Analyze how information flowed through the command structure
    if Enum.count(timeline.events) < 2 do
      %{flow_patterns: [], efficiency: 0.0, bottlenecks: []}
    else
      # Identify information flow events
      flow_events = identify_information_flow_events(timeline, participants)

      # Analyze flow patterns
      flow_patterns = analyze_flow_patterns(flow_events)

      # Calculate efficiency
      flow_efficiency = calculate_flow_efficiency(flow_events, timeline)

      # Identify bottlenecks
      bottlenecks = identify_information_bottlenecks(flow_events, participants)

      %{
        flow_patterns: flow_patterns,
        efficiency: flow_efficiency,
        bottlenecks: bottlenecks,
        broadcast_events: Enum.filter(flow_events, &(&1.type == :broadcast)),
        direct_orders: Enum.filter(flow_events, &(&1.type == :direct_order)),
        coordination_calls: Enum.filter(flow_events, &(&1.type == :coordination)),
        information_lag: calculate_average_information_lag(flow_events)
      }
    end
  end

  defp evaluate_command_effectiveness(timeline, participants) do
    # Evaluate overall command effectiveness
    if Enum.count(timeline.events) < 3 do
      %{overall_score: 0.0, factors: []}
    else
      # Evaluate different effectiveness factors
      coordination_score = evaluate_coordination_effectiveness(timeline, participants)
      response_score = evaluate_response_effectiveness(timeline, participants)
      adaptation_score = evaluate_adaptation_effectiveness(timeline, participants)
      objective_score = evaluate_objective_achievement(timeline, participants)

      # Calculate weighted overall score
      overall_score =
        coordination_score * 0.3 +
          response_score * 0.25 +
          adaptation_score * 0.25 +
          objective_score * 0.2

      %{
        overall_score: overall_score,
        coordination_effectiveness: coordination_score,
        response_effectiveness: response_score,
        adaptation_effectiveness: adaptation_score,
        objective_achievement: objective_score,
        factors: [
          %{factor: :coordination, score: coordination_score, weight: 0.3},
          %{factor: :response, score: response_score, weight: 0.25},
          %{factor: :adaptation, score: adaptation_score, weight: 0.25},
          %{factor: :objectives, score: objective_score, weight: 0.2}
        ]
      }
    end
  end

  defp identify_leadership_patterns(timeline, participants) do
    # Identify leadership patterns and key leaders
    if Enum.empty?(participants) do
      %{leaders: [], patterns: [], leadership_style: :unknown}
    else
      # Identify potential leaders based on activity and influence
      potential_leaders = identify_potential_leaders(timeline, participants)

      # Analyze leadership patterns
      leadership_patterns = analyze_leadership_behaviors(potential_leaders, timeline)

      # Determine leadership style
      leadership_style = determine_leadership_style(leadership_patterns, timeline)

      %{
        leaders: potential_leaders,
        patterns: leadership_patterns,
        leadership_style: leadership_style,
        command_presence: evaluate_command_presence(potential_leaders, timeline),
        delegation_patterns:
          analyze_delegation_patterns(potential_leaders, timeline, participants),
        decision_authority: analyze_decision_authority_distribution(potential_leaders, timeline)
      }
    end
  end

  # Supporting functions for command analysis
  defp group_participants_by_alliance(participants) do
    participants
    |> Enum.group_by(fn participant ->
      participant[:alliance_id] || participant["alliance_id"] || :no_alliance
    end)
    |> Enum.reject(fn {alliance_id, _} -> alliance_id == :no_alliance || is_nil(alliance_id) end)
    |> Map.new()
  end

  defp group_participants_by_corporation(participants) do
    participants
    |> Enum.group_by(fn participant ->
      participant[:corporation_id] || participant["corporation_id"] || :no_corp
    end)
    |> Enum.reject(fn {corp_id, _} -> corp_id == :no_corp || is_nil(corp_id) end)
    |> Map.new()
  end

  defp determine_structure_type(alliance_groups, corp_groups, participants) do
    alliance_count = length(Map.keys(alliance_groups))
    corp_count = length(Map.keys(corp_groups))
    total_participants = Enum.count(participants)

    cond do
      alliance_count == 1 && corp_count <= 3 -> :unified_alliance
      alliance_count == 1 && corp_count > 3 -> :alliance_coalition
      alliance_count > 1 && alliance_count <= 3 -> :small_coalition
      alliance_count > 3 -> :large_coalition
      corp_count == 1 -> :single_corporation
      corp_count <= 5 -> :corporate_group
      total_participants < 10 -> :small_gang
      true -> :mixed_fleet
    end
  end

  defp build_command_hierarchy(alliance_groups, corp_groups) do
    # Build a hierarchical structure
    alliance_groups
    |> Enum.map(fn {alliance_id, alliance_participants} ->
      # Group alliance participants by corporation
      alliance_corps =
        alliance_participants
        |> Enum.group_by(fn participant ->
          participant[:corporation_id] || participant["corporation_id"]
        end)

      corp_nodes =
        alliance_corps
        |> Enum.map(fn {corp_id, corp_participants} ->
          %{
            type: :corporation,
            id: corp_id,
            participant_count: length(corp_participants),
            participants: corp_participants
          }
        end)

      %{
        type: :alliance,
        id: alliance_id,
        participant_count: length(alliance_participants),
        corporations: corp_nodes
      }
    end)
  end

  defp calculate_command_depth(hierarchy) do
    if Enum.empty?(hierarchy) do
      0
    else
      # Command depth based on hierarchy levels
      max_corp_count =
        hierarchy
        |> Enum.map(fn alliance -> length(alliance.corporations) end)
        |> Enum.max(fn -> 0 end)

      cond do
        # Single entity
        Enum.count(hierarchy) == 1 && max_corp_count == 1 -> 1
        # Alliance with multiple corps
        Enum.count(hierarchy) == 1 && max_corp_count > 1 -> 2
        # Coalition
        Enum.count(hierarchy) > 1 -> 3
        true -> 2
      end
    end
  end

  defp calculate_participant_distribution(alliance_groups, corp_groups) do
    alliance_sizes =
      Enum.map(alliance_groups, fn {_id, participants} -> Enum.count(participants) end)

    corp_sizes = Enum.map(corp_groups, fn {_id, participants} -> Enum.count(participants) end)

    %{
      alliance_size_variance:
        if(Enum.count(alliance_sizes) > 1,
          do:
            calculate_variance(
              alliance_sizes,
              Enum.sum(alliance_sizes) / Enum.count(alliance_sizes)
            ),
          else: 0.0
        ),
      corp_size_variance:
        if(Enum.count(corp_sizes) > 1,
          do: calculate_variance(corp_sizes, Enum.sum(corp_sizes) / Enum.count(corp_sizes)),
          else: 0.0
        ),
      largest_alliance:
        if(not Enum.empty?(alliance_sizes), do: Enum.max(alliance_sizes), else: 0),
      largest_corp: if(not Enum.empty?(corp_sizes), do: Enum.max(corp_sizes), else: 0)
    }
  end

  defp calculate_organizational_unity(alliance_groups, corp_groups, participants) do
    total_participants = Enum.count(participants)

    if total_participants == 0 do
      0.0
    else
      # Unity based on how concentrated participants are in fewer organizations
      if not Enum.empty?(alliance_groups) do
        largest_alliance_size =
          alliance_groups
          |> Enum.map(fn {_id, participants} -> Enum.count(participants) end)
          |> Enum.max()

        largest_alliance_size / total_participants
      else
        largest_corp_size =
          corp_groups
          |> Enum.map(fn {_id, participants} -> Enum.count(participants) end)
          |> Enum.max(fn -> 0 end)

        if largest_corp_size > 0 do
          largest_corp_size / total_participants
        else
          0.0
        end
      end
    end
  end

  defp identify_decision_points(timeline, participants) do
    # Identify key decision points in the battle
    decision_points = []

    # Look for engagement initiation decisions
    first_engagement = identify_first_engagement_decision(timeline)

    decision_points =
      if first_engagement, do: [first_engagement | decision_points], else: decision_points

    # Look for escalation decisions
    escalation_decisions = identify_escalation_decisions(timeline)
    decision_points = decision_points ++ escalation_decisions

    # Look for tactical shifts
    tactical_shifts = identify_tactical_shift_decisions(timeline, participants)
    decision_points = decision_points ++ tactical_shifts

    # Look for disengagement decisions
    disengagement_decisions = identify_disengagement_decisions(timeline, participants)
    decision_points = decision_points ++ disengagement_decisions

    decision_points
    |> Enum.sort_by(& &1.timestamp)
  end

  defp identify_first_engagement_decision(timeline) do
    if length(timeline.events) > 0 do
      first_event = List.first(timeline.events)

      %{
        type: :strategic,
        decision: :initiate_engagement,
        timestamp: first_event.timestamp,
        context: %{
          target: first_event.victim[:ship_type_id],
          target_value: first_event[:isk_value] || 0
        }
      }
    else
      nil
    end
  end

  defp identify_escalation_decisions(timeline) do
    # Look for moments where engagement intensity increased significantly
    if Enum.count(timeline.events) < 5 do
      []
    else
      intensity_changes = analyze_intensity_changes(timeline)

      intensity_changes
      |> Enum.filter(fn change -> change.magnitude > 0.5 && change.type == :increase end)
      |> Enum.map(fn change ->
        %{
          type: :tactical,
          decision: :escalate_engagement,
          timestamp: change.timestamp,
          context: %{
            intensity_increase: change.magnitude,
            trigger: change.trigger
          }
        }
      end)
    end
  end

  defp identify_tactical_shift_decisions(timeline, _participants) do
    # Look for significant changes in tactical approach
    target_switches = identify_target_switches(timeline.events)

    major_switches =
      target_switches
      |> Enum.filter(fn switch ->
        # Major if switching to higher threat target
        from_threat = get_threat_value_by_id(switch.from_target)
        to_threat = get_threat_value_by_id(switch.to_target)
        to_threat > from_threat + 0.2
      end)

    major_switches
    |> Enum.map(fn switch ->
      %{
        type: :tactical,
        decision: :tactical_shift,
        timestamp: switch.timestamp,
        context: %{
          from_target: switch.from_target,
          to_target: switch.to_target,
          threat_improvement:
            get_threat_value_by_id(switch.to_target) - get_threat_value_by_id(switch.from_target)
        }
      }
    end)
  end

  defp identify_disengagement_decisions(timeline, _participants) do
    # Look for retreat/disengagement decisions
    retreat_events = identify_retreat_events(timeline)

    retreat_events
    |> Enum.map(fn retreat ->
      %{
        type: :strategic,
        decision: :disengage,
        timestamp: retreat.timestamp,
        context: %{
          trigger: retreat.type,
          intensity_drop: retreat.intensity_drop
        }
      }
    end)
  end

  defp calculate_decision_speeds(decision_points, timeline) do
    # Calculate how quickly decisions were made
    decision_points
    |> Enum.map(fn decision ->
      # Speed based on how quickly action followed the decision trigger
      case decision.decision do
        # Immediate
        :initiate_engagement -> 1.0
        :escalate_engagement -> calculate_escalation_speed(decision, timeline)
        :tactical_shift -> calculate_tactical_shift_speed(decision, timeline)
        :disengage -> calculate_disengagement_speed(decision, timeline)
        _ -> 0.5
      end
    end)
  end

  defp evaluate_decision_outcomes(decision_points, timeline) do
    # Evaluate the quality/success of each decision
    decision_points
    |> Enum.map(fn decision ->
      outcome_quality =
        case decision.decision do
          :initiate_engagement -> evaluate_engagement_initiation_outcome(decision, timeline)
          :escalate_engagement -> evaluate_escalation_outcome(decision, timeline)
          :tactical_shift -> evaluate_tactical_shift_outcome(decision, timeline)
          :disengage -> evaluate_disengagement_outcome(decision, timeline)
          _ -> 0.5
        end

      %{
        decision: decision,
        quality_score: outcome_quality,
        success_indicators: identify_success_indicators(decision, timeline, outcome_quality)
      }
    end)
  end

  defp calculate_decision_consistency(decision_points) do
    if length(decision_points) < 2 do
      1.0
    else
      # Consistency based on decision timing and type patterns
      decision_intervals =
        decision_points
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          DateTime.diff(curr.timestamp, prev.timestamp)
        end)

      if length(decision_intervals) > 0 do
        avg_interval = Enum.sum(decision_intervals) / length(decision_intervals)
        variance = calculate_variance(decision_intervals, avg_interval)

        # Lower variance = higher consistency
        if avg_interval > 0 do
          1.0 - min(variance / (avg_interval * avg_interval), 1.0)
        else
          0.0
        end
      else
        1.0
      end
    end
  end

  # Additional helper functions for command analysis
  defp identify_information_flow_events(timeline, participants) do
    # Identify events that suggest information flow
    flow_events = []

    # Focus fire events suggest broadcast/coordination
    focus_fire_windows = identify_focus_fire_windows_detailed(timeline)

    broadcast_events =
      focus_fire_windows
      |> Enum.filter(&(&1.participant_count >= 3))
      |> Enum.map(fn window ->
        %{
          type: :broadcast,
          timestamp: window.timestamp,
          participants: window.participant_count,
          effectiveness: window.concentration,
          scope: :fleet_wide
        }
      end)

    flow_events = flow_events ++ broadcast_events

    # Target switches suggest direct orders
    target_switches = identify_target_switches(timeline.events)

    direct_orders =
      target_switches
      # Quick switches
      |> Enum.filter(fn switch -> switch.time_delta < 10 end)
      |> Enum.map(fn switch ->
        %{
          type: :direct_order,
          timestamp: switch.timestamp,
          response_time: switch.time_delta,
          effectiveness:
            if(
              get_threat_value_by_id(switch.to_target) >
                get_threat_value_by_id(switch.from_target),
              do: 1.0,
              else: 0.5
            ),
          scope: :tactical
        }
      end)

    flow_events = flow_events ++ direct_orders

    flow_events
    |> Enum.sort_by(& &1.timestamp)
  end

  defp analyze_flow_patterns(flow_events) do
    # Analyze patterns in information flow
    if Enum.empty?(flow_events) do
      []
    else
      patterns = []

      # Check for regular broadcast patterns
      broadcast_events = Enum.filter(flow_events, &(&1.type == :broadcast))

      if length(broadcast_events) >= 3 do
        broadcast_intervals =
          broadcast_events
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [prev, curr] -> DateTime.diff(curr.timestamp, prev.timestamp) end)

        avg_interval = Enum.sum(broadcast_intervals) / length(broadcast_intervals)
        variance = calculate_variance(broadcast_intervals, avg_interval)

        if variance < avg_interval * 0.3 do
          patterns = [
            %{
              type: :regular_broadcasts,
              interval: avg_interval,
              consistency: 1.0 - variance / avg_interval
            }
            | patterns
          ]
        end
      end

      # Check for reactive patterns
      reactive_events = Enum.filter(flow_events, &(&1.type == :direct_order))

      if length(reactive_events) >= 2 do
        avg_response_time =
          reactive_events
          |> Enum.map(& &1.response_time)
          |> Enum.sum()
          |> then(&(&1 / length(reactive_events)))

        patterns = [
          %{
            type: :reactive_commands,
            avg_response_time: avg_response_time,
            frequency: length(reactive_events)
          }
          | patterns
        ]
      end

      patterns
    end
  end

  defp calculate_flow_efficiency(flow_events, timeline) do
    if Enum.empty?(flow_events) do
      0.0
    else
      # Efficiency based on response times and effectiveness
      total_effectiveness =
        flow_events
        |> Enum.map(& &1.effectiveness)
        |> Enum.sum()

      avg_effectiveness = total_effectiveness / length(flow_events)

      # Factor in response times for direct orders
      response_efficiency =
        flow_events
        |> Enum.filter(&(&1.type == :direct_order))
        |> Enum.map(fn event ->
          # Faster response = higher efficiency
          cond do
            event.response_time < 5 -> 1.0
            event.response_time < 15 -> 0.8
            event.response_time < 30 -> 0.6
            true -> 0.4
          end
        end)

      if length(response_efficiency) > 0 do
        avg_response_efficiency = Enum.sum(response_efficiency) / length(response_efficiency)
        avg_effectiveness * 0.6 + avg_response_efficiency * 0.4
      else
        avg_effectiveness
      end
    end
  end

  defp identify_information_bottlenecks(flow_events, participants) do
    # Identify potential information bottlenecks
    bottlenecks = []

    # Look for delays in information flow
    slow_responses =
      flow_events
      |> Enum.filter(&(&1.type == :direct_order && &1.response_time > 30))

    if length(slow_responses) > length(flow_events) * 0.3 do
      bottlenecks = [
        %{
          type: :slow_response,
          frequency: length(slow_responses),
          avg_delay:
            Enum.sum(Enum.map(slow_responses, & &1.response_time)) / length(slow_responses)
        }
        | bottlenecks
      ]
    end

    # Look for coordination failures
    failed_broadcasts =
      flow_events
      |> Enum.filter(&(&1.type == :broadcast && &1.effectiveness < 0.5))

    if length(failed_broadcasts) > 0 do
      bottlenecks = [
        %{
          type: :coordination_failure,
          frequency: length(failed_broadcasts),
          avg_effectiveness:
            Enum.sum(Enum.map(failed_broadcasts, & &1.effectiveness)) / length(failed_broadcasts)
        }
        | bottlenecks
      ]
    end

    bottlenecks
  end

  defp calculate_average_information_lag(flow_events) do
    direct_orders = Enum.filter(flow_events, &(&1.type == :direct_order))

    if length(direct_orders) > 0 do
      total_response_time = Enum.sum(Enum.map(direct_orders, & &1.response_time))
      total_response_time / length(direct_orders)
    else
      0.0
    end
  end

  # Effectiveness evaluation functions
  defp evaluate_coordination_effectiveness(timeline, participants) do
    # Evaluate how well the fleet coordinated
    focus_fire_effectiveness =
      calculate_focus_effectiveness(identify_focus_fire_windows_detailed(timeline))

    target_prioritization =
      calculate_prioritization_accuracy(
        extract_target_order(timeline.events),
        calculate_optimal_target_order(timeline.events)
      )

    timing_coordination = calculate_synchronization_score(timeline)

    focus_fire_effectiveness * 0.4 + target_prioritization * 0.35 + timing_coordination * 0.25
  end

  defp evaluate_response_effectiveness(timeline, _participants) do
    # Evaluate how effectively the fleet responded to situations
    if Enum.count(timeline.events) < 3 do
      0.5
    else
      # Response based on adaptation to losses and threats
      # Empty participants for simplified call
      adaptations = identify_tactical_adaptations(timeline, [])

      if length(adaptations) > 0 do
        adaptation_effectiveness =
          adaptations
          |> Enum.map(&(&1[:effectiveness] || 0.5))
          |> Enum.sum()
          |> then(&(&1 / length(adaptations)))

        min(adaptation_effectiveness, 1.0)
      else
        0.5
      end
    end
  end

  defp evaluate_adaptation_effectiveness(timeline, participants) do
    # Evaluate how well the fleet adapted during battle
    innovations = identify_novel_tactics(timeline, participants)
    counter_tactics = identify_counter_tactics(timeline, participants)

    innovation_score =
      if length(innovations) > 0, do: min(length(innovations) / 3.0, 1.0), else: 0.0

    counter_score =
      if length(counter_tactics) > 0, do: min(length(counter_tactics) / 2.0, 1.0), else: 0.0

    innovation_score * 0.4 + counter_score * 0.6
  end

  defp evaluate_objective_achievement(timeline, _participants) do
    # Evaluate objective achievement (simplified)
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Basic objective achievement based on kill efficiency
      total_isk = Enum.sum(Enum.map(timeline.events, &(&1[:isk_value] || 0)))

      cond do
        # 10B+ ISK destroyed
        total_isk > 10_000_000_000 -> 1.0
        # 5B+ ISK destroyed  
        total_isk > 5_000_000_000 -> 0.8
        # 1B+ ISK destroyed
        total_isk > 1_000_000_000 -> 0.6
        # 100M+ ISK destroyed
        total_isk > 100_000_000 -> 0.4
        true -> 0.2
      end
    end
  end

  # Leadership analysis functions
  defp identify_potential_leaders(timeline, participants) do
    if Enum.empty?(participants) do
      []
    else
      # Identify leaders based on activity patterns and influence
      participant_stats =
        participants
        |> Enum.map(fn participant ->
          char_id = participant[:character_id] || participant["character_id"]

          # Calculate leadership indicators
          activity_score = calculate_activity_score(char_id, timeline)
          influence_score = calculate_influence_score(char_id, timeline, participants)
          coordination_score = calculate_coordination_involvement(char_id, timeline)

          %{
            character_id: char_id,
            activity_score: activity_score,
            influence_score: influence_score,
            coordination_score: coordination_score,
            leadership_potential:
              activity_score * 0.3 + influence_score * 0.4 + coordination_score * 0.3,
            participant_data: participant
          }
        end)
        |> Enum.sort_by(& &1.leadership_potential, :desc)
        # Top 5 potential leaders
        |> Enum.take(5)

      participant_stats
      # Only high-potential leaders
      |> Enum.filter(&(&1.leadership_potential > 0.6))
    end
  end

  defp analyze_leadership_behaviors(leaders, timeline) do
    # Analyze leadership behavior patterns
    leaders
    |> Enum.map(fn leader ->
      char_id = leader.character_id

      decision_involvement = count_decision_involvement(char_id, timeline)
      coordination_frequency = count_coordination_activities(char_id, timeline)
      initiative_actions = count_initiative_actions(char_id, timeline)

      %{
        character_id: char_id,
        decision_involvement: decision_involvement,
        coordination_frequency: coordination_frequency,
        initiative_actions: initiative_actions,
        leadership_style:
          classify_leadership_style(
            decision_involvement,
            coordination_frequency,
            initiative_actions
          ),
        effectiveness: leader.leadership_potential
      }
    end)
  end

  defp determine_leadership_style(leadership_patterns, _timeline) do
    if Enum.empty?(leadership_patterns) do
      :unknown
    else
      # Aggregate leadership styles
      styles = Enum.map(leadership_patterns, & &1.leadership_style)
      style_frequencies = Enum.frequencies(styles)

      # Return most common style
      style_frequencies
      |> Enum.max_by(fn {_style, count} -> count end, fn -> {:unknown, 0} end)
      |> elem(0)
    end
  end

  # Summary calculation functions for command analysis
  defp determine_primary_structure_type(command_structure) do
    command_structure[:type] || :unknown
  end

  defp calculate_average_decision_speed(decision_making) do
    decision_making[:decision_speed] || 0.0
  end

  defp calculate_information_efficiency(information_flow) do
    information_flow[:efficiency] || 0.0
  end

  defp evaluate_leadership_quality(leadership_patterns) do
    if Enum.empty?(leadership_patterns[:leaders] || []) do
      0.0
    else
      avg_potential =
        leadership_patterns[:leaders]
        |> Enum.map(& &1.leadership_potential)
        |> Enum.sum()
        |> then(&(&1 / length(leadership_patterns[:leaders])))

      avg_potential
    end
  end

  defp calculate_coordination_level_from_command(timeline, participants) do
    # Already implemented earlier - delegate to existing function
    calculate_coordination_level(timeline, participants)
  end

  # Utility functions for command analysis
  defp analyze_intensity_changes(timeline) do
    # Analyze changes in battle intensity
    tempo_profile = create_tempo_profile(timeline)

    tempo_profile
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      intensity_change = curr.tempo_rating - prev.tempo_rating

      %{
        timestamp: curr.timestamp,
        type: if(intensity_change > 0, do: :increase, else: :decrease),
        magnitude: abs(intensity_change) / max(prev.tempo_rating, 0.1),
        # Simplified
        trigger: :tactical_decision
      }
    end)
    # Significant changes only
    |> Enum.filter(&(&1.magnitude > 0.3))
  end

  defp calculate_escalation_speed(decision, timeline) do
    # Speed of escalation implementation
    events_after =
      timeline.events
      |> Enum.filter(fn event ->
        DateTime.diff(event.timestamp, decision.timestamp) > 0 &&
          DateTime.diff(event.timestamp, decision.timestamp) <= 60
      end)

    if length(events_after) >= 2 do
      # Fast escalation
      1.0
    else
      # Slower escalation
      0.5
    end
  end

  defp calculate_tactical_shift_speed(decision, _timeline) do
    # Speed based on context
    threat_improvement = decision.context[:threat_improvement] || 0.0

    if threat_improvement > 0.3 do
      # Good tactical shift
      0.9
    else
      # Moderate tactical shift
      0.6
    end
  end

  defp calculate_disengagement_speed(decision, _timeline) do
    # Speed of disengagement
    intensity_drop = decision.context[:intensity_drop] || 0

    if intensity_drop > 2 do
      # Fast disengagement
      0.8
    else
      # Slower disengagement
      0.5
    end
  end

  defp evaluate_engagement_initiation_outcome(decision, timeline) do
    # Evaluate if engagement initiation was successful
    events_after_init =
      timeline.events
      |> Enum.filter(fn event ->
        # 5 minutes after
        DateTime.diff(event.timestamp, decision.timestamp) <= 300
      end)

    if length(events_after_init) >= 3 do
      # Successful engagement
      0.8
    else
      # Limited engagement
      0.4
    end
  end

  defp evaluate_escalation_outcome(decision, timeline) do
    # Evaluate escalation success
    context_intensity = decision.context[:intensity_increase] || 0.0

    if context_intensity > 0.7 do
      # Successful escalation
      0.9
    else
      # Moderate escalation
      0.6
    end
  end

  defp evaluate_tactical_shift_outcome(decision, _timeline) do
    # Evaluate tactical shift success
    threat_improvement = decision.context[:threat_improvement] || 0.0

    if threat_improvement > 0.2 do
      # Good tactical shift
      0.8
    else
      # Moderate shift
      0.5
    end
  end

  defp evaluate_disengagement_outcome(decision, timeline) do
    # Evaluate disengagement success
    events_after_disengage =
      timeline.events
      |> Enum.filter(fn event ->
        DateTime.diff(event.timestamp, decision.timestamp) > 0 &&
          DateTime.diff(event.timestamp, decision.timestamp) <= 180
      end)

    if length(events_after_disengage) < 2 do
      # Successful disengagement
      0.9
    else
      # Failed disengagement
      0.3
    end
  end

  defp identify_success_indicators(decision, timeline, quality_score) do
    # Identify what made the decision successful or not
    indicators = []

    if quality_score > 0.7 do
      indicators = [:good_timing, :effective_execution | indicators]
    end

    if quality_score < 0.4 do
      indicators = [:poor_timing, :ineffective_execution | indicators]
    end

    case decision.decision do
      :initiate_engagement ->
        if length(timeline.events) > 5,
          do: [:successful_engagement | indicators],
          else: indicators

      :escalate_engagement ->
        if decision.context[:intensity_increase] > 0.5,
          do: [:successful_escalation | indicators],
          else: indicators

      _ ->
        indicators
    end
  end

  # Leadership utility functions
  defp calculate_activity_score(_char_id, timeline) do
    # Simplified activity score based on battle participation
    event_count = length(timeline.events)

    cond do
      event_count > 20 -> 0.9
      event_count > 10 -> 0.7
      event_count > 5 -> 0.5
      true -> 0.3
    end
  end

  defp calculate_influence_score(_char_id, _timeline, participants) do
    # Simplified influence based on fleet size
    fleet_size = length(participants)

    cond do
      fleet_size > 50 -> 0.8
      fleet_size > 20 -> 0.6
      fleet_size > 10 -> 0.4
      true -> 0.2
    end
  end

  defp calculate_coordination_involvement(_char_id, timeline) do
    # Simplified coordination involvement
    focus_fire_windows = identify_focus_fire_windows_detailed(timeline)

    if length(focus_fire_windows) > 2 do
      0.8
    else
      0.4
    end
  end

  defp count_decision_involvement(_char_id, _timeline) do
    # Simplified decision involvement count
    # Placeholder
    3
  end

  defp count_coordination_activities(_char_id, timeline) do
    # Count coordination activities
    length(identify_focus_fire_windows_detailed(timeline))
  end

  defp count_initiative_actions(_char_id, _timeline) do
    # Count initiative actions
    # Placeholder
    2
  end

  defp classify_leadership_style(decision_count, coordination_count, initiative_count) do
    total_activity = decision_count + coordination_count + initiative_count

    cond do
      decision_count > total_activity * 0.5 -> :decisive
      coordination_count > total_activity * 0.5 -> :coordinator
      initiative_count > total_activity * 0.5 -> :aggressive
      true -> :balanced
    end
  end

  defp evaluate_command_presence(leaders, timeline) do
    # Evaluate overall command presence
    if Enum.empty?(leaders) do
      0.0
    else
      # Presence based on leader count and battle duration
      battle_duration =
        if length(timeline.events) >= 2 do
          DateTime.diff(
            List.last(timeline.events).timestamp,
            List.first(timeline.events).timestamp
          )
        else
          60
        end

      # Leaders per 5 minutes
      leader_density = length(leaders) / max(battle_duration / 300, 1)
      min(leader_density, 1.0)
    end
  end

  defp analyze_delegation_patterns(leaders, _timeline, participants) do
    # Analyze delegation patterns
    if Enum.empty?(leaders) do
      %{delegation_score: 0.0, patterns: []}
    else
      # Simplified delegation analysis
      participant_count = length(participants)
      leader_count = length(leaders)

      delegation_ratio = if leader_count > 0, do: participant_count / leader_count, else: 0.0

      delegation_score =
        cond do
          # Too few leaders
          delegation_ratio > 15 -> 0.3
          # Good delegation
          delegation_ratio > 8 -> 0.8
          # Excellent delegation
          delegation_ratio > 3 -> 1.0
          # Adequate delegation
          true -> 0.6
        end

      %{
        delegation_score: delegation_score,
        leader_to_participant_ratio: delegation_ratio,
        patterns:
          if(delegation_score > 0.7, do: [:effective_delegation], else: [:concentrated_command])
      }
    end
  end

  defp analyze_decision_authority_distribution(leaders, _timeline) do
    # Analyze how decision authority is distributed
    if Enum.empty?(leaders) do
      %{distribution: :unknown, centralization: 0.0}
    else
      # Authority distribution based on leadership potential variance
      potentials = Enum.map(leaders, & &1.leadership_potential)
      avg_potential = Enum.sum(potentials) / length(potentials)
      variance = calculate_variance(potentials, avg_potential)

      centralization = if avg_potential > 0, do: variance / avg_potential, else: 0.0

      distribution_type =
        cond do
          centralization > 0.5 -> :highly_centralized
          centralization > 0.2 -> :moderately_centralized
          length(leaders) == 1 -> :single_leader
          true -> :distributed
        end

      %{
        distribution: distribution_type,
        centralization: centralization,
        authority_balance: 1.0 - centralization
      }
    end
  end

  # Comprehensive target selection analysis helper functions

  defp analyze_target_acquisition_patterns(timeline, participants) do
    # Analyze how targets are acquired and initial engagement patterns
    Logger.debug("Analyzing target acquisition patterns")

    if Enum.empty?(timeline.events) do
      %{acquisition_speed: 0.0, acquisition_efficiency: 0.0, primary_identification: 0.0}
    else
      # Group participants by side for acquisition analysis
      sides = group_participants_by_side(participants)

      acquisition_metrics =
        Enum.map(sides, fn {side, side_participants} ->
          side_events =
            Enum.filter(timeline.events, fn event ->
              # Find events where this side was the attacker
              attacker_ids = Enum.map(event[:attackers] || [], & &1["character_id"])
              participant_ids = Enum.map(side_participants, & &1[:character_id])
              Enum.any?(attacker_ids, &(&1 in participant_ids))
            end)

          if length(side_events) > 0 do
            # Analyze acquisition speed (time from battle start to first kill)
            first_kill_time = List.first(side_events).timestamp
            battle_start = List.first(timeline.events).timestamp
            acquisition_delay = DateTime.diff(first_kill_time, battle_start, :second)

            # Analyze acquisition efficiency (successful kills vs attempts)
            successful_acquisitions = length(side_events)
            total_targets_engaged = count_unique_targets_engaged(side_events)

            efficiency =
              if total_targets_engaged > 0,
                do: successful_acquisitions / total_targets_engaged,
                else: 0.0

            # Analyze primary target identification speed
            primary_speed = calculate_primary_identification_speed(side_events)

            %{
              side: side,
              # Normalize to 5 minutes
              acquisition_speed: max(0.0, 1.0 - acquisition_delay / 300.0),
              acquisition_efficiency: efficiency,
              primary_identification: primary_speed
            }
          else
            %{
              side: side,
              acquisition_speed: 0.0,
              acquisition_efficiency: 0.0,
              primary_identification: 0.0
            }
          end
        end)

      # Calculate overall metrics
      avg_speed =
        if length(acquisition_metrics) > 0 do
          Enum.sum(Enum.map(acquisition_metrics, & &1.acquisition_speed)) /
            length(acquisition_metrics)
        else
          0.0
        end

      avg_efficiency =
        if length(acquisition_metrics) > 0 do
          Enum.sum(Enum.map(acquisition_metrics, & &1.acquisition_efficiency)) /
            length(acquisition_metrics)
        else
          0.0
        end

      avg_primary =
        if length(acquisition_metrics) > 0 do
          Enum.sum(Enum.map(acquisition_metrics, & &1.primary_identification)) /
            length(acquisition_metrics)
        else
          0.0
        end

      %{
        acquisition_speed: avg_speed,
        acquisition_efficiency: avg_efficiency,
        primary_identification: avg_primary,
        side_breakdown: acquisition_metrics
      }
    end
  end

  defp evaluate_tactical_focus_consistency(timeline, participants) do
    # Evaluate how consistently tactical focus is maintained
    Logger.debug("Evaluating tactical focus consistency")

    if Enum.count(timeline.events) < 3 do
      %{focus_consistency: 0.0, focus_coherence: 0.0, focus_discipline: 0.0}
    else
      sides = group_participants_by_side(participants)

      focus_metrics =
        Enum.map(sides, fn {side, side_participants} ->
          side_events = filter_events_by_side(timeline.events, side_participants)

          if length(side_events) >= 2 do
            # Analyze target focus windows
            focus_windows = identify_focus_windows(side_events)

            # Calculate consistency metrics
            consistency = calculate_focus_window_consistency(focus_windows)
            coherence = evaluate_target_coherence_over_time(side_events)
            discipline = measure_target_discipline(side_events)

            %{
              side: side,
              focus_consistency: consistency,
              focus_coherence: coherence,
              focus_discipline: discipline
            }
          else
            %{side: side, focus_consistency: 0.0, focus_coherence: 0.0, focus_discipline: 0.0}
          end
        end)

      # Calculate overall averages
      avg_consistency =
        if length(focus_metrics) > 0 do
          Enum.sum(Enum.map(focus_metrics, & &1.focus_consistency)) / length(focus_metrics)
        else
          0.0
        end

      avg_coherence =
        if length(focus_metrics) > 0 do
          Enum.sum(Enum.map(focus_metrics, & &1.focus_coherence)) / length(focus_metrics)
        else
          0.0
        end

      avg_discipline =
        if length(focus_metrics) > 0 do
          Enum.sum(Enum.map(focus_metrics, & &1.focus_discipline)) / length(focus_metrics)
        else
          0.0
        end

      %{
        focus_consistency: avg_consistency,
        focus_coherence: avg_coherence,
        focus_discipline: avg_discipline,
        side_breakdown: focus_metrics
      }
    end
  end

  defp identify_target_selection_doctrine(timeline, participants) do
    # Identify the underlying target selection doctrine/strategy
    Logger.debug("Identifying target selection doctrine")

    if Enum.empty?(timeline.events) do
      %{doctrine_type: :unknown, doctrine_adherence: 0.0, doctrine_effectiveness: 0.0}
    else
      # Analyze target priority patterns to infer doctrine
      target_priorities = extract_target_priorities_over_time(timeline.events)
      ship_type_preferences = analyze_ship_type_targeting_preferences(timeline.events)
      value_targeting_patterns = analyze_value_targeting_patterns(timeline.events)

      # Identify doctrine type based on patterns
      doctrine_type =
        determine_doctrine_type(
          target_priorities,
          ship_type_preferences,
          value_targeting_patterns
        )

      # Measure adherence to identified doctrine
      adherence = calculate_doctrine_adherence(timeline.events, doctrine_type)

      # Evaluate doctrine effectiveness
      effectiveness = evaluate_doctrine_effectiveness(timeline.events, doctrine_type)

      %{
        doctrine_type: doctrine_type,
        doctrine_adherence: adherence,
        doctrine_effectiveness: effectiveness,
        target_priorities: target_priorities,
        ship_preferences: ship_type_preferences,
        value_patterns: value_targeting_patterns
      }
    end
  end

  defp analyze_counter_target_selection(timeline, participants) do
    # Analyze counter-targeting and reactive target selection
    Logger.debug("Analyzing counter target selection")

    if Enum.count(timeline.events) < 2 do
      %{counter_selection_frequency: 0.0, counter_effectiveness: 0.0, reactive_targeting: 0.0}
    else
      sides = group_participants_by_side(participants)

      counter_metrics =
        Enum.map(sides, fn {side, side_participants} ->
          side_events = filter_events_by_side(timeline.events, side_participants)

          if length(side_events) >= 2 do
            # Identify counter-targeting events
            counter_events = identify_counter_targeting_events(side_events, timeline.events)

            # Calculate counter-selection frequency
            frequency =
              if length(side_events) > 0,
                do: length(counter_events) / length(side_events),
                else: 0.0

            # Evaluate counter-targeting effectiveness
            effectiveness = evaluate_counter_targeting_effectiveness(counter_events, timeline)

            # Measure reactive targeting capability
            reactive_score = measure_reactive_targeting_capability(side_events, timeline.events)

            %{
              side: side,
              counter_selection_frequency: frequency,
              counter_effectiveness: effectiveness,
              reactive_targeting: reactive_score
            }
          else
            %{
              side: side,
              counter_selection_frequency: 0.0,
              counter_effectiveness: 0.0,
              reactive_targeting: 0.0
            }
          end
        end)

      # Calculate overall averages
      avg_frequency =
        if length(counter_metrics) > 0 do
          Enum.sum(Enum.map(counter_metrics, & &1.counter_selection_frequency)) /
            length(counter_metrics)
        else
          0.0
        end

      avg_effectiveness =
        if length(counter_metrics) > 0 do
          Enum.sum(Enum.map(counter_metrics, & &1.counter_effectiveness)) /
            length(counter_metrics)
        else
          0.0
        end

      avg_reactive =
        if length(counter_metrics) > 0 do
          Enum.sum(Enum.map(counter_metrics, & &1.reactive_targeting)) / length(counter_metrics)
        else
          0.0
        end

      %{
        counter_selection_frequency: avg_frequency,
        counter_effectiveness: avg_effectiveness,
        reactive_targeting: avg_reactive,
        side_breakdown: counter_metrics
      }
    end
  end

  # Summary calculation helper functions

  defp calculate_overall_target_coordination(prioritization, focus_fire, primary_calling) do
    # Calculate overall coordination score from component metrics
    priority_score = prioritization[:prioritization_effectiveness] || 0.0
    focus_score = focus_fire[:coordination_quality] || 0.0
    calling_score = primary_calling[:calling_coordination] || 0.0

    (priority_score + focus_score + calling_score) / 3
  end

  defp evaluate_target_strategic_coherence(prioritization, doctrine) do
    # Evaluate how well target selection aligns with strategic doctrine
    priority_adherence = prioritization[:priority_adherence] || 0.0
    doctrine_adherence = doctrine[:doctrine_adherence] || 0.0

    (priority_adherence + doctrine_adherence) / 2
  end

  defp measure_target_selection_adaptation(target_switching, counter_selection) do
    # Measure adaptability in target selection
    switch_effectiveness = target_switching[:switching_effectiveness] || 0.0
    counter_effectiveness = counter_selection[:counter_effectiveness] || 0.0

    (switch_effectiveness + counter_effectiveness) / 2
  end

  defp calculate_target_execution_quality(focus_fire, effectiveness) do
    # Calculate quality of target selection execution
    focus_effectiveness = focus_fire[:focus_fire_effectiveness] || 0.0
    target_effectiveness = effectiveness[:overall_effectiveness] || 0.0

    (focus_effectiveness + target_effectiveness) / 2
  end

  # Additional helper functions for comprehensive analysis

  defp count_unique_targets_engaged(events) do
    events
    |> Enum.map(& &1[:victim][:ship_type_id])
    |> Enum.uniq()
    |> length()
  end

  defp calculate_primary_identification_speed(events) do
    if length(events) < 2 do
      0.0
    else
      # Measure how quickly primary targets are identified and focused
      first_event = List.first(events)

      primary_events =
        Enum.filter(events, fn event ->
          # Consider events within 60 seconds as potentially coordinated
          DateTime.diff(event.timestamp, first_event.timestamp, :second) <= 60
        end)

      # Speed based on coordination within the first minute
      coordination_ratio = length(primary_events) / length(events)
      # Scale to 0-1 range
      min(1.0, coordination_ratio * 2)
    end
  end

  defp filter_events_by_side(events, side_participants) do
    participant_ids = Enum.map(side_participants, & &1[:character_id])

    Enum.filter(events, fn event ->
      attacker_ids = Enum.map(event[:attackers] || [], & &1["character_id"])
      Enum.any?(attacker_ids, &(&1 in participant_ids))
    end)
  end

  defp identify_focus_windows(events) do
    # Group events by time windows to identify focus periods
    time_grouped =
      Enum.group_by(events, fn event ->
        # Group by 30-second windows
        div(DateTime.to_unix(event.timestamp), 30)
      end)

    Enum.map(time_grouped, fn {_window, window_events} ->
      %{
        start_time: List.first(window_events).timestamp,
        end_time: List.last(window_events).timestamp,
        kill_count: length(window_events),
        focus_targets: extract_focus_targets(window_events)
      }
    end)
  end

  defp extract_focus_targets(events) do
    events
    |> Enum.map(& &1[:victim][:ship_type_id])
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
    # Top 3 focused ship types
    |> Enum.take(3)
  end

  defp calculate_focus_window_consistency(focus_windows) do
    if length(focus_windows) <= 1 do
      0.0
    else
      # Measure consistency of focus across windows
      target_variations =
        Enum.map(focus_windows, fn window ->
          length(window.focus_targets)
        end)

      avg_variation = Enum.sum(target_variations) / length(target_variations)
      variation_std = calculate_standard_deviation(target_variations, avg_variation)

      # Lower variation = higher consistency
      consistency =
        if avg_variation > 0, do: max(0.0, 1.0 - variation_std / avg_variation), else: 0.0

      consistency
    end
  end

  defp evaluate_target_coherence_over_time(events) do
    if length(events) < 3 do
      0.0
    else
      # Analyze if target selection follows a coherent pattern over time
      chronological_targets =
        Enum.map(events, fn event ->
          event[:victim][:ship_type_id]
        end)

      # Look for patterns in target types
      ship_classes =
        Enum.map(chronological_targets, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)

      # Calculate coherence based on class consistency
      class_transitions = Enum.chunk_every(ship_classes, 2, 1, :discard)

      coherent_transitions =
        Enum.count(class_transitions, fn [a, b] ->
          # Coherent if same class or logical progression
          a == b or is_logical_target_progression(a, b)
        end)

      if length(class_transitions) > 0 do
        coherent_transitions / length(class_transitions)
      else
        0.0
      end
    end
  end

  defp measure_target_discipline(events) do
    if length(events) < 2 do
      0.0
    else
      # Measure discipline by looking at target switching patterns
      target_switches = count_unnecessary_target_switches(events)
      total_possible_switches = length(events) - 1

      if total_possible_switches > 0 do
        discipline = 1.0 - target_switches / total_possible_switches
        max(0.0, discipline)
      else
        0.0
      end
    end
  end

  defp extract_target_priorities_over_time(events) do
    # Extract target priority patterns over the course of the battle
    # 5-minute windows
    time_windows = chunk_events_by_time(events, 300)

    Enum.map(time_windows, fn {window_start, window_events} ->
      target_types =
        Enum.map(window_events, fn event ->
          event[:victim][:ship_type_id]
        end)

      ship_classes = Enum.map(target_types, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)
      class_frequencies = Enum.frequencies(ship_classes)

      %{
        time_window: window_start,
        target_distribution: class_frequencies,
        primary_focus: find_primary_target_class(class_frequencies),
        target_diversity: calculate_target_diversity(class_frequencies)
      }
    end)
  end

  defp analyze_ship_type_targeting_preferences(events) do
    # Analyze preferences for targeting specific ship types
    target_ships =
      Enum.map(events, fn event ->
        event[:victim][:ship_type_id]
      end)

    ship_classes = Enum.map(target_ships, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)
    class_frequencies = Enum.frequencies(ship_classes)

    total_kills = length(events)

    preferences =
      Enum.map(class_frequencies, fn {class, count} ->
        %{
          ship_class: class,
          frequency: count / total_kills,
          priority_score: calculate_class_priority_score(class)
        }
      end)
      |> Enum.sort_by(& &1.frequency, :desc)

    %{
      preferences: preferences,
      primary_preference: List.first(preferences),
      preference_diversity: calculate_preference_diversity(preferences)
    }
  end

  defp analyze_value_targeting_patterns(events) do
    # Analyze targeting patterns based on ISK value
    value_targets =
      Enum.map(events, fn event ->
        %{
          isk_value: event[:isk_value] || 0,
          ship_class:
            EveDmv.StaticData.ShipTypes.classify_ship_type(event[:victim][:ship_type_id]),
          timestamp: event.timestamp
        }
      end)

    # Group by value ranges
    # 1B+ ISK
    high_value = Enum.filter(value_targets, &(&1.isk_value >= 1_000_000_000))
    # 100M-1B ISK
    medium_value =
      Enum.filter(value_targets, &(&1.isk_value >= 100_000_000 and &1.isk_value < 1_000_000_000))

    # <100M ISK
    low_value = Enum.filter(value_targets, &(&1.isk_value < 100_000_000))

    total_kills = length(events)

    %{
      high_value_focus: if(total_kills > 0, do: length(high_value) / total_kills, else: 0.0),
      medium_value_focus: if(total_kills > 0, do: length(medium_value) / total_kills, else: 0.0),
      low_value_focus: if(total_kills > 0, do: length(low_value) / total_kills, else: 0.0),
      value_targeting_trend: analyze_value_targeting_trend(value_targets)
    }
  end

  defp determine_doctrine_type(priorities, preferences, value_patterns) do
    # Determine doctrine based on analysis patterns
    primary_preference = preferences[:primary_preference]
    high_value_focus = value_patterns[:high_value_focus] || 0.0

    cond do
      high_value_focus > 0.6 ->
        :high_value_hunting

      primary_preference && primary_preference[:ship_class] in [:frigate, :destroyer] ->
        :tackle_focused

      primary_preference &&
          primary_preference[:ship_class] in [:cruiser, :battlecruiser, :battleship] ->
        :dps_focused

      primary_preference && primary_preference[:ship_class] in [:capital, :supercapital] ->
        :capital_warfare

      length(priorities) > 0 ->
        primary_focus = List.first(priorities)

        if primary_focus && primary_focus[:target_diversity] > 0.7 do
          :opportunistic
        else
          :systematic
        end

      true ->
        :unknown
    end
  end

  defp calculate_doctrine_adherence(events, doctrine_type) do
    # Calculate how well actual targeting adheres to the identified doctrine
    case doctrine_type do
      :high_value_hunting ->
        high_value_kills = Enum.count(events, &((&1[:isk_value] || 0) >= 500_000_000))
        if length(events) > 0, do: high_value_kills / length(events), else: 0.0

      :tackle_focused ->
        tackle_kills =
          Enum.count(events, fn event ->
            class = EveDmv.StaticData.ShipTypes.classify_ship_type(event[:victim][:ship_type_id])
            class in [:frigate, :destroyer]
          end)

        if length(events) > 0, do: tackle_kills / length(events), else: 0.0

      :dps_focused ->
        dps_kills =
          Enum.count(events, fn event ->
            class = EveDmv.StaticData.ShipTypes.classify_ship_type(event[:victim][:ship_type_id])
            class in [:cruiser, :battlecruiser, :battleship]
          end)

        if length(events) > 0, do: dps_kills / length(events), else: 0.0

      :capital_warfare ->
        capital_kills =
          Enum.count(events, fn event ->
            class = EveDmv.StaticData.ShipTypes.classify_ship_type(event[:victim][:ship_type_id])
            class in [:capital, :supercapital]
          end)

        if length(events) > 0, do: capital_kills / length(events), else: 0.0

      _ ->
        # Default moderate adherence for unknown doctrines
        0.5
    end
  end

  defp evaluate_doctrine_effectiveness(events, doctrine_type) do
    # Evaluate how effective the doctrine was
    if Enum.empty?(events) do
      0.0
    else
      total_isk = Enum.sum(Enum.map(events, &(&1[:isk_value] || 0)))
      avg_isk_per_kill = total_isk / length(events)

      # Effectiveness based on ISK efficiency and kill count
      # Normalized to 100M ISK
      isk_effectiveness = min(1.0, avg_isk_per_kill / 100_000_000)
      # Normalized to 20 kills
      volume_effectiveness = min(1.0, length(events) / 20)

      case doctrine_type do
        :high_value_hunting ->
          isk_effectiveness * 0.8 + volume_effectiveness * 0.2

        :tackle_focused ->
          volume_effectiveness * 0.7 + isk_effectiveness * 0.3

        :capital_warfare ->
          isk_effectiveness * 0.9 + volume_effectiveness * 0.1

        _ ->
          (isk_effectiveness + volume_effectiveness) / 2
      end
    end
  end

  defp identify_counter_targeting_events(side_events, all_events) do
    # Identify events that appear to be reactive/counter-targeting
    Enum.filter(side_events, fn event ->
      # Look for kills that happened shortly after enemy kills
      enemy_events_before =
        Enum.filter(all_events, fn e ->
          DateTime.diff(event.timestamp, e.timestamp, :second) <= 60 and
            DateTime.diff(event.timestamp, e.timestamp, :second) > 0 and
            not events_from_same_side?(event, e, side_events)
        end)

      # Consider it counter-targeting if there were recent enemy kills
      length(enemy_events_before) > 0
    end)
  end

  defp evaluate_counter_targeting_effectiveness(counter_events, timeline) do
    if Enum.empty?(counter_events) do
      0.0
    else
      # Evaluate effectiveness of counter-targeting
      counter_isk = Enum.sum(Enum.map(counter_events, &(&1[:isk_value] || 0)))
      total_isk = Enum.sum(Enum.map(timeline.events, &(&1[:isk_value] || 0)))

      if total_isk > 0 do
        counter_isk / total_isk
      else
        0.0
      end
    end
  end

  defp measure_reactive_targeting_capability(side_events, all_events) do
    if length(side_events) < 2 do
      0.0
    else
      # Measure how quickly the side reacts to enemy actions
      reaction_times =
        Enum.map(side_events, fn event ->
          # Find the most recent enemy action before this event
          recent_enemy_events =
            Enum.filter(all_events, fn e ->
              time_diff = DateTime.diff(event.timestamp, e.timestamp, :second)
              # Within 5 minutes
              time_diff > 0 and time_diff <= 300 and
                not events_from_same_side?(event, e, side_events)
            end)

          if length(recent_enemy_events) > 0 do
            most_recent = Enum.max_by(recent_enemy_events, & &1.timestamp)
            reaction_time = DateTime.diff(event.timestamp, most_recent.timestamp, :second)

            # Score reaction time (faster = better, up to 5 minutes)
            reaction_score = max(0.0, 1.0 - reaction_time / 300.0)
            reaction_score
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      if length(reaction_times) > 0 do
        Enum.sum(reaction_times) / length(reaction_times)
      else
        0.0
      end
    end
  end

  # Additional utility helper functions

  defp is_logical_target_progression(class_a, class_b) do
    # Define logical targeting progressions (e.g., tackle -> DPS -> support)
    logical_progressions = %{
      frigate: [:destroyer, :cruiser],
      destroyer: [:cruiser, :battlecruiser],
      cruiser: [:battlecruiser, :battleship],
      battlecruiser: [:battleship, :capital],
      battleship: [:capital, :supercapital]
    }

    progressions = Map.get(logical_progressions, class_a, [])
    class_b in progressions
  end

  defp count_unnecessary_target_switches(events) do
    # Count target switches that don't follow logical patterns
    if length(events) < 2 do
      0
    else
      target_pairs = Enum.chunk_every(events, 2, 1, :discard)

      Enum.count(target_pairs, fn [event_a, event_b] ->
        class_a = EveDmv.StaticData.ShipTypes.classify_ship_type(event_a[:victim][:ship_type_id])
        class_b = EveDmv.StaticData.ShipTypes.classify_ship_type(event_b[:victim][:ship_type_id])

        # Consider it unnecessary if it's not logical progression and no significant time gap
        time_diff = DateTime.diff(event_b.timestamp, event_a.timestamp, :second)
        not is_logical_target_progression(class_a, class_b) and time_diff < 120
      end)
    end
  end

  defp chunk_events_by_time(events, window_seconds) do
    if Enum.empty?(events) do
      []
    else
      start_time = List.first(events).timestamp

      events
      |> Enum.group_by(fn event ->
        div(DateTime.diff(event.timestamp, start_time, :second), window_seconds)
      end)
      |> Enum.map(fn {window_index, window_events} ->
        window_start = DateTime.add(start_time, window_index * window_seconds, :second)
        {window_start, window_events}
      end)
    end
  end

  defp find_primary_target_class(class_frequencies) do
    if map_size(class_frequencies) == 0 do
      :unknown
    else
      {primary_class, _count} = Enum.max_by(class_frequencies, fn {_class, count} -> count end)
      primary_class
    end
  end

  defp calculate_target_diversity(class_frequencies) do
    if map_size(class_frequencies) <= 1 do
      0.0
    else
      total_kills = Enum.sum(Map.values(class_frequencies))

      # Calculate Shannon diversity index
      diversity =
        class_frequencies
        |> Enum.map(fn {_class, count} ->
          proportion = count / total_kills
          if proportion > 0, do: -proportion * :math.log2(proportion), else: 0
        end)
        |> Enum.sum()

      # Normalize to 0-1 range (max diversity for EVE ship classes is around 3.17)
      min(1.0, diversity / 3.17)
    end
  end

  defp calculate_class_priority_score(class) do
    # Assign priority scores based on typical EVE combat priorities
    case class do
      # High priority (tackle)
      :frigate -> 0.7
      # High priority (anti-frigate)
      :destroyer -> 0.6
      # Very high priority (DPS/logistics)
      :cruiser -> 0.8
      # Very high priority (heavy DPS)
      :battlecruiser -> 0.9
      # Very high priority (heavy DPS)
      :battleship -> 0.9
      # Maximum priority
      :capital -> 1.0
      # Maximum priority
      :supercapital -> 1.0
      # Low priority (non-combat)
      :industrial -> 0.3
      # Low priority (non-combat)
      :mining -> 0.2
      # Default medium priority
      _ -> 0.5
    end
  end

  defp calculate_preference_diversity(preferences) do
    if length(preferences) <= 1 do
      0.0
    else
      # Calculate diversity based on frequency distribution
      frequencies = Enum.map(preferences, & &1.frequency)
      total_freq = Enum.sum(frequencies)

      if total_freq > 0 do
        diversity =
          frequencies
          |> Enum.map(fn freq ->
            if freq > 0, do: -freq * :math.log2(freq), else: 0
          end)
          |> Enum.sum()

        # Normalize to 0-1 range
        max_diversity = :math.log2(length(preferences))
        if max_diversity > 0, do: diversity / max_diversity, else: 0.0
      else
        0.0
      end
    end
  end

  defp analyze_value_targeting_trend(value_targets) do
    if length(value_targets) < 3 do
      :insufficient_data
    else
      # Analyze trend in target values over time
      chronological_values = Enum.map(value_targets, & &1.isk_value)

      # Simple trend analysis using first and last thirds
      first_third_size = div(length(chronological_values), 3)
      last_third_size = first_third_size

      first_third = Enum.take(chronological_values, first_third_size)
      last_third = Enum.take(chronological_values, -last_third_size)

      if length(first_third) > 0 and length(last_third) > 0 do
        avg_first = Enum.sum(first_third) / length(first_third)
        avg_last = Enum.sum(last_third) / length(last_third)

        cond do
          avg_last > avg_first * 1.2 -> :escalating_value
          avg_last < avg_first * 0.8 -> :declining_value
          true -> :stable_value
        end
      else
        :insufficient_data
      end
    end
  end

  defp events_from_same_side?(event_a, event_b, side_events) do
    # Check if two events are from the same side
    side_event_timestamps = Enum.map(side_events, & &1.timestamp)

    Enum.member?(side_event_timestamps, event_a.timestamp) and
      Enum.member?(side_event_timestamps, event_b.timestamp)
  end

  defp calculate_standard_deviation(values, mean) do
    if length(values) <= 1 do
      0.0
    else
      variance =
        values
        |> Enum.map(fn value -> :math.pow(value - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(values) - 1)

      :math.sqrt(variance)
    end
  end

  # Advanced timing analysis helper functions

  defp analyze_battle_flow_timing(timeline, participants) do
    # Analyze the overall flow and pacing of the battle
    Logger.debug("Analyzing battle flow timing")

    if Enum.count(timeline.events) < 3 do
      %{flow_consistency: 0.0, phase_transitions: [], pacing_efficiency: 0.0}
    else
      # Identify battle phases based on timing
      battle_phases = identify_battle_phases_by_timing(timeline)

      # Analyze flow between phases
      phase_transitions = analyze_phase_timing_transitions(battle_phases)

      # Calculate flow metrics
      flow_consistency = calculate_battle_flow_consistency(timeline.events)
      pacing_efficiency = evaluate_battle_pacing_efficiency(timeline, participants)
      phase_coherence = measure_phase_timing_coherence(battle_phases)

      %{
        flow_consistency: flow_consistency,
        phase_transitions: phase_transitions,
        pacing_efficiency: pacing_efficiency,
        phase_coherence: phase_coherence,
        battle_phases: battle_phases,
        intensity_curve: generate_battle_intensity_curve(timeline.events)
      }
    end
  end

  defp analyze_tactical_transitions(timeline, participants) do
    # Analyze timing of tactical transitions and adaptations
    Logger.debug("Analyzing tactical transitions")

    if length(timeline.events) < 4 do
      %{transition_speed: 0.0, transition_effectiveness: 0.0, adaptation_timing: 0.0}
    else
      # Identify tactical transition points
      transition_points = identify_tactical_transition_points(timeline, participants)

      # Calculate transition metrics
      transition_speed = calculate_average_transition_speed(transition_points)
      transition_effectiveness = evaluate_transition_effectiveness(transition_points, timeline)
      adaptation_timing = measure_adaptation_timing_quality(transition_points)

      %{
        transition_speed: transition_speed,
        transition_effectiveness: transition_effectiveness,
        adaptation_timing: adaptation_timing,
        transition_points: transition_points,
        transition_patterns: identify_transition_patterns(transition_points)
      }
    end
  end

  defp analyze_pressure_application_timing(timeline, participants) do
    # Analyze timing of pressure application and sustained attacks
    Logger.debug("Analyzing pressure application timing")

    if Enum.count(timeline.events) < 3 do
      %{pressure_buildup: 0.0, pressure_maintenance: 0.0, pressure_release: 0.0}
    else
      # Identify pressure phases
      pressure_phases = identify_pressure_phases(timeline, participants)

      # Calculate pressure timing metrics
      buildup_effectiveness = evaluate_pressure_buildup_timing(pressure_phases)
      maintenance_quality = evaluate_pressure_maintenance_timing(pressure_phases)
      release_timing = evaluate_pressure_release_timing(pressure_phases)

      %{
        pressure_buildup: buildup_effectiveness,
        pressure_maintenance: maintenance_quality,
        pressure_release: release_timing,
        pressure_phases: pressure_phases,
        sustained_pressure_periods: identify_sustained_pressure_periods(pressure_phases)
      }
    end
  end

  defp analyze_escalation_timing_patterns(timeline, participants) do
    # Analyze timing patterns in battle escalation and de-escalation
    Logger.debug("Analyzing escalation timing patterns")

    if length(timeline.events) < 4 do
      %{escalation_speed: 0.0, escalation_control: 0.0, de_escalation_timing: 0.0}
    else
      # Identify escalation events
      escalation_events = identify_escalation_timing_events(timeline, participants)

      # Calculate escalation timing metrics
      escalation_speed = calculate_escalation_speed(escalation_events)
      escalation_control = evaluate_escalation_control_timing(escalation_events)
      de_escalation_timing = analyze_de_escalation_timing(escalation_events, timeline)

      %{
        escalation_speed: escalation_speed,
        escalation_control: escalation_control,
        de_escalation_timing: de_escalation_timing,
        escalation_events: escalation_events,
        escalation_curve: generate_escalation_curve(escalation_events)
      }
    end
  end

  # Summary calculation helper functions for timing analysis

  defp calculate_overall_timing_coordination(
         engagement_timing,
         coordination_timing,
         alpha_strike_timing
       ) do
    # Calculate overall coordination score from timing components
    engagement_score = engagement_timing[:timing_coordination] || 0.0
    coordination_score = coordination_timing[:timing_effectiveness] || 0.0
    alpha_score = alpha_strike_timing[:alpha_strike_coordination] || 0.0

    (engagement_score + coordination_score + alpha_score) / 3
  end

  defp evaluate_tempo_control_effectiveness(tactical_rhythm, pressure_timing) do
    # Evaluate effectiveness of tempo control
    rhythm_effectiveness = tactical_rhythm[:rhythm_effectiveness] || 0.0
    pressure_maintenance = pressure_timing[:pressure_maintenance] || 0.0

    (rhythm_effectiveness + pressure_maintenance) / 2
  end

  defp measure_timing_adaptability(tactical_transitions, escalation_timing) do
    # Measure adaptability in timing decisions
    transition_effectiveness = tactical_transitions[:transition_effectiveness] || 0.0
    escalation_control = escalation_timing[:escalation_control] || 0.0

    (transition_effectiveness + escalation_control) / 2
  end

  defp assess_synchronization_quality(
         coordination_timing,
         alpha_strike_timing,
         battle_flow_timing
       ) do
    # Assess overall synchronization quality
    coordination_sync = coordination_timing[:synchronization] || 0.0
    alpha_precision = alpha_strike_timing[:timing_precision] || 0.0
    flow_consistency = battle_flow_timing[:flow_consistency] || 0.0

    (coordination_sync + alpha_precision + flow_consistency) / 3
  end

  # Detailed timing analysis helper functions

  defp identify_battle_phases_by_timing(timeline) do
    # Identify battle phases based on timing patterns
    if Enum.count(timeline.events) < 3 do
      []
    else
      # Group events by intensity periods
      # 1-minute windows
      intensity_windows = calculate_intensity_windows(timeline.events, 60)

      # Identify phase transitions based on intensity changes
      phases = []
      current_phase = nil

      Enum.reduce(intensity_windows, phases, fn {window_start, window_intensity}, acc ->
        cond do
          current_phase == nil ->
            new_phase = %{
              start_time: window_start,
              phase_type: determine_phase_type_by_intensity(window_intensity),
              intensity: window_intensity
            }

            [new_phase | acc]

          intensity_change_significant?(current_phase.intensity, window_intensity) ->
            # End current phase and start new one
            updated_current = Map.put(current_phase, :end_time, window_start)

            new_phase = %{
              start_time: window_start,
              phase_type: determine_phase_type_by_intensity(window_intensity),
              intensity: window_intensity
            }

            [new_phase, updated_current | acc]

          true ->
            # Continue current phase
            acc
        end
      end)
      |> Enum.reverse()
    end
  end

  defp analyze_phase_timing_transitions(battle_phases) do
    if length(battle_phases) < 2 do
      []
    else
      # Analyze transitions between phases
      phase_pairs = Enum.chunk_every(battle_phases, 2, 1, :discard)

      Enum.map(phase_pairs, fn [phase_a, phase_b] ->
        transition_duration =
          if phase_a[:end_time] && phase_b[:start_time] do
            DateTime.diff(phase_b.start_time, phase_a.end_time, :second)
          else
            0
          end

        %{
          from_phase: phase_a.phase_type,
          to_phase: phase_b.phase_type,
          transition_duration: transition_duration,
          intensity_change: phase_b.intensity - phase_a.intensity,
          transition_type: classify_transition_type(phase_a.phase_type, phase_b.phase_type)
        }
      end)
    end
  end

  defp calculate_battle_flow_consistency(events) do
    if length(events) < 5 do
      0.0
    else
      # Calculate consistency based on kill intervals
      kill_intervals =
        Enum.chunk_every(events, 2, 1, :discard)
        |> Enum.map(fn [event_a, event_b] ->
          DateTime.diff(event_b.timestamp, event_a.timestamp, :second)
        end)

      if length(kill_intervals) > 0 do
        mean_interval = Enum.sum(kill_intervals) / length(kill_intervals)
        variance = calculate_variance(kill_intervals, mean_interval)

        # Lower variance = higher consistency
        consistency =
          if mean_interval > 0, do: max(0.0, 1.0 - variance / mean_interval), else: 0.0

        min(1.0, consistency)
      else
        0.0
      end
    end
  end

  defp evaluate_battle_pacing_efficiency(timeline, participants) do
    # Evaluate how efficiently the battle pacing was managed
    if Enum.count(timeline.events) < 3 do
      0.0
    else
      # Calculate efficiency based on kill rate vs participant engagement
      total_participants = Enum.count(participants)

      battle_duration =
        DateTime.diff(
          List.last(timeline.events).timestamp,
          List.first(timeline.events).timestamp,
          :second
        )

      if battle_duration > 0 && total_participants > 0 do
        kills_per_minute = length(timeline.events) * 60 / battle_duration
        # Normalize to typical fleet sizes
        participant_engagement = total_participants / 10

        # Efficiency based on kills per minute relative to engagement
        efficiency = min(1.0, kills_per_minute / participant_engagement)
        efficiency
      else
        0.0
      end
    end
  end

  defp measure_phase_timing_coherence(battle_phases) do
    if length(battle_phases) < 2 do
      1.0
    else
      # Measure coherence based on logical phase progression
      coherent_transitions =
        Enum.chunk_every(battle_phases, 2, 1, :discard)
        |> Enum.count(fn [phase_a, phase_b] ->
          is_logical_phase_transition(phase_a.phase_type, phase_b.phase_type)
        end)

      total_transitions = length(battle_phases) - 1

      if total_transitions > 0 do
        coherent_transitions / total_transitions
      else
        1.0
      end
    end
  end

  defp generate_battle_intensity_curve(events) do
    # Generate intensity curve over time
    if length(events) < 2 do
      []
    else
      # Calculate intensity in 30-second windows
      intensity_windows = calculate_intensity_windows(events, 30)

      Enum.map(intensity_windows, fn {window_start, intensity} ->
        %{
          timestamp: window_start,
          intensity: intensity,
          # Normalize to 5 kills per window
          normalized_intensity: min(1.0, intensity / 5.0)
        }
      end)
    end
  end

  defp identify_tactical_transition_points(timeline, participants) do
    # Identify points where tactical approach changed
    if length(timeline.events) < 4 do
      []
    else
      # Look for changes in target selection patterns
      # 2-minute windows
      time_windows = chunk_events_by_time(timeline.events, 120)

      transitions = []

      Enum.reduce(time_windows, {nil, transitions}, fn {window_start, window_events},
                                                       {prev_pattern, acc} ->
        if length(window_events) >= 2 do
          current_pattern = analyze_window_tactical_pattern(window_events)

          if prev_pattern && tactical_pattern_changed?(prev_pattern, current_pattern) do
            transition = %{
              timestamp: window_start,
              from_pattern: prev_pattern,
              to_pattern: current_pattern,
              transition_trigger: identify_transition_trigger(prev_pattern, current_pattern)
            }

            {current_pattern, [transition | acc]}
          else
            {current_pattern, acc}
          end
        else
          {prev_pattern, acc}
        end
      end)
      |> elem(1)
      |> Enum.reverse()
    end
  end

  defp calculate_average_transition_speed(transition_points) do
    if length(transition_points) < 2 do
      1.0
    else
      # Calculate speed based on time between transitions
      transition_intervals =
        Enum.chunk_every(transition_points, 2, 1, :discard)
        |> Enum.map(fn [trans_a, trans_b] ->
          DateTime.diff(trans_b.timestamp, trans_a.timestamp, :second)
        end)

      if length(transition_intervals) > 0 do
        avg_interval = Enum.sum(transition_intervals) / length(transition_intervals)
        # Faster transitions = higher score (up to 5 minutes)
        speed_score = max(0.0, 1.0 - avg_interval / 300.0)
        speed_score
      else
        1.0
      end
    end
  end

  defp evaluate_transition_effectiveness(transition_points, timeline) do
    if Enum.empty?(transition_points) do
      1.0
    else
      # Evaluate effectiveness by looking at outcomes after transitions
      effective_transitions =
        Enum.count(transition_points, fn transition ->
          # Look at kills in the 60 seconds after transition
          transition_time = transition.timestamp

          post_transition_events =
            Enum.filter(timeline.events, fn event ->
              time_diff = DateTime.diff(event.timestamp, transition_time, :second)
              time_diff >= 0 && time_diff <= 60
            end)

          # Consider effective if kill rate increased
          length(post_transition_events) >= 2
        end)

      if length(transition_points) > 0 do
        effective_transitions / length(transition_points)
      else
        1.0
      end
    end
  end

  defp measure_adaptation_timing_quality(transition_points) do
    if Enum.empty?(transition_points) do
      1.0
    else
      # Measure quality based on appropriate timing of adaptations
      well_timed_adaptations =
        Enum.count(transition_points, fn transition ->
          # Consider well-timed if it was a logical response
          case transition.transition_trigger do
            :enemy_adaptation -> true
            :tactical_opportunity -> true
            :pressure_response -> true
            _ -> false
          end
        end)

      if length(transition_points) > 0 do
        well_timed_adaptations / length(transition_points)
      else
        1.0
      end
    end
  end

  defp identify_transition_patterns(transition_points) do
    # Identify patterns in tactical transitions
    if length(transition_points) < 2 do
      []
    else
      # Group transitions by type
      transition_types = Enum.group_by(transition_points, & &1.transition_trigger)

      Enum.map(transition_types, fn {trigger_type, transitions} ->
        %{
          pattern_type: trigger_type,
          frequency: length(transitions),
          avg_effectiveness: calculate_avg_transition_effectiveness(transitions),
          timing_consistency: calculate_transition_timing_consistency(transitions)
        }
      end)
    end
  end

  defp identify_pressure_phases(timeline, participants) do
    # Identify phases of sustained pressure application
    if Enum.count(timeline.events) < 3 do
      []
    else
      # Calculate pressure intensity over time
      # 45-second windows
      pressure_windows = calculate_pressure_intensity_windows(timeline.events, participants, 45)

      # Identify sustained pressure periods (3+ consecutive high-intensity windows)
      pressure_phases = []
      current_phase = nil

      Enum.reduce(pressure_windows, pressure_phases, fn {window_start, pressure_intensity}, acc ->
        high_pressure = pressure_intensity >= 0.6

        cond do
          high_pressure && current_phase == nil ->
            new_phase = %{start_time: window_start, intensity: pressure_intensity, events: []}
            [new_phase | acc]

          high_pressure && current_phase ->
            # Continue current phase
            acc

          not high_pressure && current_phase ->
            # End current phase
            updated_phase = Map.put(current_phase, :end_time, window_start)
            [updated_phase | acc]

          true ->
            acc
        end
      end)
      |> Enum.reverse()
    end
  end

  defp evaluate_pressure_buildup_timing(pressure_phases) do
    if Enum.empty?(pressure_phases) do
      1.0
    else
      # Evaluate how well pressure was built up
      effective_buildups =
        Enum.count(pressure_phases, fn phase ->
          buildup_duration =
            if phase[:end_time] do
              DateTime.diff(phase.end_time, phase.start_time, :second)
            else
              # Default for ongoing phases
              60
            end

          # Effective if buildup was sustained (30+ seconds) but not too long (300+ seconds)
          buildup_duration >= 30 && buildup_duration <= 300
        end)

      if length(pressure_phases) > 0 do
        effective_buildups / length(pressure_phases)
      else
        1.0
      end
    end
  end

  defp evaluate_pressure_maintenance_timing(pressure_phases) do
    if Enum.empty?(pressure_phases) do
      1.0
    else
      # Evaluate how well pressure was maintained
      well_maintained =
        Enum.count(pressure_phases, fn phase ->
          maintenance_duration =
            if phase[:end_time] do
              DateTime.diff(phase.end_time, phase.start_time, :second)
            else
              60
            end

          # Well maintained if pressure lasted 60+ seconds
          maintenance_duration >= 60
        end)

      if length(pressure_phases) > 0 do
        well_maintained / length(pressure_phases)
      else
        1.0
      end
    end
  end

  defp evaluate_pressure_release_timing(pressure_phases) do
    if length(pressure_phases) <= 1 do
      1.0
    else
      # Evaluate timing of pressure release/reset
      good_releases =
        Enum.count(pressure_phases, fn _phase ->
          # For now, consider all releases as appropriately timed
          # Could be enhanced to check if release was strategic
          true
        end)

      if length(pressure_phases) > 0 do
        good_releases / length(pressure_phases)
      else
        1.0
      end
    end
  end

  defp identify_sustained_pressure_periods(pressure_phases) do
    # Identify periods of particularly sustained pressure
    Enum.filter(pressure_phases, fn phase ->
      duration =
        if phase[:end_time] do
          DateTime.diff(phase.end_time, phase.start_time, :second)
        else
          60
        end

      # 2+ minutes of sustained pressure
      duration >= 120
    end)
    |> Enum.map(fn phase ->
      duration =
        if phase[:end_time] do
          DateTime.diff(phase.end_time, phase.start_time, :second)
        else
          60
        end

      %{
        start_time: phase.start_time,
        end_time: phase[:end_time],
        duration: duration,
        intensity: phase.intensity,
        # Normalize to 5 minutes
        sustainability_score: min(1.0, duration / 300.0)
      }
    end)
  end

  defp identify_escalation_timing_events(timeline, participants) do
    # Identify escalation events and their timing
    if length(timeline.events) < 4 do
      []
    else
      # Look for significant increases in kill rate or ISK destruction
      intensity_windows = calculate_intensity_windows(timeline.events, 60)

      escalation_events = []

      Enum.reduce(intensity_windows, {nil, escalation_events}, fn {window_start, intensity},
                                                                  {prev_intensity, acc} ->
        if prev_intensity && intensity > prev_intensity * 1.5 do
          # Significant escalation detected
          escalation = %{
            timestamp: window_start,
            intensity_increase: intensity - prev_intensity,
            escalation_factor: intensity / prev_intensity,
            escalation_type: determine_escalation_type_by_intensity(intensity, prev_intensity)
          }

          {intensity, [escalation | acc]}
        else
          {intensity, acc}
        end
      end)
      |> elem(1)
      |> Enum.reverse()
    end
  end

  defp calculate_escalation_speed(escalation_events) do
    if length(escalation_events) < 2 do
      1.0
    else
      # Calculate average time between escalations
      escalation_intervals =
        Enum.chunk_every(escalation_events, 2, 1, :discard)
        |> Enum.map(fn [esc_a, esc_b] ->
          DateTime.diff(esc_b.timestamp, esc_a.timestamp, :second)
        end)

      if length(escalation_intervals) > 0 do
        avg_interval = Enum.sum(escalation_intervals) / length(escalation_intervals)
        # Faster escalation = higher score (normalize to 2 minutes)
        speed_score = max(0.0, 1.0 - avg_interval / 120.0)
        speed_score
      else
        1.0
      end
    end
  end

  defp evaluate_escalation_control_timing(escalation_events) do
    if Enum.empty?(escalation_events) do
      1.0
    else
      # Evaluate control based on escalation factors
      controlled_escalations =
        Enum.count(escalation_events, fn escalation ->
          # Controlled if escalation factor is reasonable (1.5x to 3x)
          escalation.escalation_factor >= 1.5 && escalation.escalation_factor <= 3.0
        end)

      if length(escalation_events) > 0 do
        controlled_escalations / length(escalation_events)
      else
        1.0
      end
    end
  end

  defp analyze_de_escalation_timing(escalation_events, timeline) do
    if Enum.empty?(escalation_events) do
      1.0
    else
      # Look for periods of de-escalation after escalation events
      well_timed_de_escalations =
        Enum.count(escalation_events, fn escalation ->
          # Look for reduced activity in the 90 seconds after escalation
          escalation_time = escalation.timestamp

          post_escalation_events =
            Enum.filter(timeline.events, fn event ->
              time_diff = DateTime.diff(event.timestamp, escalation_time, :second)
              time_diff >= 60 && time_diff <= 150
            end)

          # Good de-escalation if activity reduced after peak
          length(post_escalation_events) < 3
        end)

      if length(escalation_events) > 0 do
        well_timed_de_escalations / length(escalation_events)
      else
        1.0
      end
    end
  end

  defp generate_escalation_curve(escalation_events) do
    # Generate escalation intensity curve
    Enum.map(escalation_events, fn escalation ->
      %{
        timestamp: escalation.timestamp,
        escalation_factor: escalation.escalation_factor,
        intensity_increase: escalation.intensity_increase,
        escalation_type: escalation.escalation_type
      }
    end)
  end

  # Additional utility helper functions for timing analysis

  defp calculate_intensity_windows(events, window_seconds) do
    if Enum.empty?(events) do
      []
    else
      start_time = List.first(events).timestamp

      events
      |> Enum.group_by(fn event ->
        div(DateTime.diff(event.timestamp, start_time, :second), window_seconds)
      end)
      |> Enum.map(fn {window_index, window_events} ->
        window_start = DateTime.add(start_time, window_index * window_seconds, :second)
        # Simple intensity based on kill count
        intensity = length(window_events)
        {window_start, intensity}
      end)
      |> Enum.sort_by(fn {timestamp, _intensity} -> timestamp end)
    end
  end

  defp determine_phase_type_by_intensity(intensity) do
    cond do
      intensity >= 5 -> :high_intensity
      intensity >= 3 -> :medium_intensity
      intensity >= 1 -> :low_intensity
      true -> :minimal_activity
    end
  end

  defp intensity_change_significant?(prev_intensity, current_intensity) do
    change_ratio =
      if prev_intensity > 0,
        do: abs(current_intensity - prev_intensity) / prev_intensity,
        else: 1.0

    change_ratio >= 0.5
  end

  defp classify_transition_type(from_phase, to_phase) do
    case {from_phase, to_phase} do
      {:low_intensity, :high_intensity} -> :escalation
      {:high_intensity, :low_intensity} -> :de_escalation
      {:minimal_activity, :medium_intensity} -> :engagement_start
      {:medium_intensity, :minimal_activity} -> :engagement_end
      _ -> :tempo_shift
    end
  end

  defp is_logical_phase_transition(from_phase, to_phase) do
    # Define logical phase transitions
    logical_transitions = [
      {:minimal_activity, :low_intensity},
      {:low_intensity, :medium_intensity},
      {:medium_intensity, :high_intensity},
      {:high_intensity, :medium_intensity},
      {:medium_intensity, :low_intensity},
      {:low_intensity, :minimal_activity}
    ]

    {from_phase, to_phase} in logical_transitions
  end

  defp analyze_window_tactical_pattern(window_events) do
    # Analyze tactical pattern in a time window
    if length(window_events) < 2 do
      %{pattern_type: :insufficient_data}
    else
      # Analyze ship types targeted
      target_ship_types =
        Enum.map(window_events, fn event ->
          event[:victim][:ship_type_id]
        end)

      ship_classes =
        Enum.map(target_ship_types, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)

      class_frequencies = Enum.frequencies(ship_classes)

      # Determine pattern based on targeting
      primary_target_class =
        if map_size(class_frequencies) > 0 do
          {class, _count} = Enum.max_by(class_frequencies, fn {_class, count} -> count end)
          class
        else
          :unknown
        end

      %{
        pattern_type: determine_tactical_pattern_type(primary_target_class, class_frequencies),
        target_diversity: calculate_target_diversity(class_frequencies),
        primary_focus: primary_target_class
      }
    end
  end

  defp tactical_pattern_changed?(prev_pattern, current_pattern) do
    prev_pattern.pattern_type != current_pattern.pattern_type ||
      prev_pattern.primary_focus != current_pattern.primary_focus
  end

  defp identify_transition_trigger(prev_pattern, current_pattern) do
    case {prev_pattern.pattern_type, current_pattern.pattern_type} do
      {:frigate_focus, :cruiser_focus} -> :escalation_response
      {:cruiser_focus, :frigate_focus} -> :tactical_opportunity
      {:diverse_targeting, :focused_targeting} -> :pressure_response
      {:focused_targeting, :diverse_targeting} -> :enemy_adaptation
      _ -> :unknown_trigger
    end
  end

  defp calculate_avg_transition_effectiveness(transitions) do
    if Enum.empty?(transitions) do
      1.0
    else
      # For now, return a default effectiveness
      # Could be enhanced with actual effectiveness calculation
      0.7
    end
  end

  defp calculate_transition_timing_consistency(transitions) do
    if length(transitions) < 2 do
      1.0
    else
      # Calculate consistency based on timing intervals
      transition_intervals =
        Enum.chunk_every(transitions, 2, 1, :discard)
        |> Enum.map(fn [trans_a, trans_b] ->
          DateTime.diff(trans_b.timestamp, trans_a.timestamp, :second)
        end)

      if length(transition_intervals) > 0 do
        mean_interval = Enum.sum(transition_intervals) / length(transition_intervals)
        variance = calculate_variance(transition_intervals, mean_interval)

        # Lower variance = higher consistency
        consistency =
          if mean_interval > 0, do: max(0.0, 1.0 - variance / mean_interval), else: 1.0

        consistency
      else
        1.0
      end
    end
  end

  defp calculate_pressure_intensity_windows(events, _participants, window_seconds) do
    # Calculate pressure intensity based on kill rate and ISK destruction
    intensity_windows = calculate_intensity_windows(events, window_seconds)

    Enum.map(intensity_windows, fn {window_start, kill_count} ->
      # Normalize intensity (pressure increases with kill count and ISK value)
      # Normalize to 3 kills per window
      normalized_intensity = min(1.0, kill_count / 3.0)
      {window_start, normalized_intensity}
    end)
  end

  defp determine_escalation_type_by_intensity(current_intensity, prev_intensity) do
    escalation_factor = current_intensity / prev_intensity

    cond do
      escalation_factor >= 3.0 -> :major_escalation
      escalation_factor >= 2.0 -> :significant_escalation
      escalation_factor >= 1.5 -> :moderate_escalation
      true -> :minor_escalation
    end
  end

  defp determine_tactical_pattern_type(primary_target_class, class_frequencies) do
    diversity = calculate_target_diversity(class_frequencies)

    cond do
      diversity > 0.7 -> :diverse_targeting
      primary_target_class in [:frigate, :destroyer] -> :frigate_focus
      primary_target_class in [:cruiser, :battlecruiser, :battleship] -> :cruiser_focus
      primary_target_class in [:capital, :supercapital] -> :capital_focus
      diversity < 0.3 -> :focused_targeting
      true -> :balanced_targeting
    end
  end

  # Advanced innovation and learning analysis helper functions

  defp analyze_innovation_evolution(timeline, participants, novel_tactics, adaptations) do
    # Analyze how innovations evolved throughout the battle
    Logger.debug("Analyzing innovation evolution")

    if Enum.count(timeline.events) < 5 do
      %{evolution_stages: [], innovation_progression: 0.0, refinement_quality: 0.0}
    else
      # Identify evolution stages by tracking changes over time
      # 3-minute windows
      time_windows = chunk_events_by_time(timeline.events, 180)

      evolution_stages =
        Enum.map(time_windows, fn {window_start, window_events} ->
          if length(window_events) >= 2 do
            # Analyze tactical patterns in this window
            window_pattern = analyze_window_tactical_pattern(window_events)

            innovations_in_window =
              filter_innovations_by_time(novel_tactics ++ adaptations, window_start, 180)

            %{
              timestamp: window_start,
              tactical_pattern: window_pattern,
              innovations_introduced: length(innovations_in_window),
              pattern_complexity: calculate_pattern_complexity(window_pattern),
              innovation_types: categorize_innovations(innovations_in_window)
            }
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      # Calculate innovation progression score
      progression_score = calculate_innovation_progression(evolution_stages)

      # Evaluate refinement quality
      refinement_quality = evaluate_innovation_refinement(evolution_stages)

      %{
        evolution_stages: evolution_stages,
        innovation_progression: progression_score,
        refinement_quality: refinement_quality,
        evolution_patterns: identify_evolution_patterns(evolution_stages)
      }
    end
  end

  defp analyze_tactical_experimentation(timeline, participants) do
    # Analyze experimental behavior and risk-taking in tactics
    Logger.debug("Analyzing tactical experimentation")

    if length(timeline.events) < 4 do
      %{experimentation_frequency: 0.0, risk_tolerance: 0.0, experimental_success: 0.0}
    else
      # Identify experimental behaviors
      experimental_events = identify_experimental_behaviors(timeline, participants)

      # Calculate experimentation metrics
      experimentation_frequency =
        if length(timeline.events) > 0 do
          length(experimental_events) / length(timeline.events)
        else
          0.0
        end

      risk_tolerance = calculate_risk_tolerance(experimental_events, timeline)
      experimental_success = evaluate_experimental_success(experimental_events, timeline)

      %{
        experimentation_frequency: experimentation_frequency,
        risk_tolerance: risk_tolerance,
        experimental_success: experimental_success,
        experimental_events: experimental_events,
        innovation_triggers: identify_innovation_triggers(experimental_events)
      }
    end
  end

  defp analyze_knowledge_transfer_patterns(timeline, participants) do
    # Analyze how knowledge and tactics spread between participants
    Logger.debug("Analyzing knowledge transfer patterns")

    if length(participants) < 3 do
      %{transfer_efficiency: 0.0, spread_speed: 0.0, adoption_rate: 0.0}
    else
      # Group participants by side for transfer analysis
      sides = group_participants_by_side(participants)

      transfer_patterns =
        Enum.map(sides, fn {side, side_participants} ->
          if length(side_participants) >= 2 do
            # Analyze knowledge transfer within this side
            transfer_events = identify_knowledge_transfer_events(timeline, side_participants)

            efficiency = calculate_transfer_efficiency(transfer_events, side_participants)
            spread_speed = calculate_knowledge_spread_speed(transfer_events)
            adoption_rate = calculate_tactic_adoption_rate(transfer_events, side_participants)

            %{
              side: side,
              transfer_efficiency: efficiency,
              spread_speed: spread_speed,
              adoption_rate: adoption_rate,
              transfer_events: transfer_events
            }
          else
            %{
              side: side,
              transfer_efficiency: 0.0,
              spread_speed: 0.0,
              adoption_rate: 0.0,
              transfer_events: []
            }
          end
        end)

      # Calculate overall metrics
      overall_efficiency =
        if length(transfer_patterns) > 0 do
          Enum.sum(Enum.map(transfer_patterns, & &1.transfer_efficiency)) /
            length(transfer_patterns)
        else
          0.0
        end

      overall_speed =
        if length(transfer_patterns) > 0 do
          Enum.sum(Enum.map(transfer_patterns, & &1.spread_speed)) / length(transfer_patterns)
        else
          0.0
        end

      overall_adoption =
        if length(transfer_patterns) > 0 do
          Enum.sum(Enum.map(transfer_patterns, & &1.adoption_rate)) / length(transfer_patterns)
        else
          0.0
        end

      %{
        transfer_efficiency: overall_efficiency,
        spread_speed: overall_speed,
        adoption_rate: overall_adoption,
        side_breakdown: transfer_patterns,
        transfer_mechanisms: identify_transfer_mechanisms(transfer_patterns)
      }
    end
  end

  defp measure_adaptive_capacity(timeline, participants, adaptations) do
    # Measure the overall adaptive capacity of the battle participants
    Logger.debug("Measuring adaptive capacity")

    if Enum.count(timeline.events) < 3 do
      %{capacity_score: 0.0, response_flexibility: 0.0, adaptation_depth: 0.0}
    else
      # Analyze adaptive responses to challenges
      challenges = identify_tactical_challenges(timeline, participants)
      responses = identify_adaptive_responses(challenges, adaptations, timeline)

      # Calculate capacity metrics
      capacity_score = calculate_overall_adaptive_capacity(challenges, responses)
      response_flexibility = measure_response_flexibility(responses)
      adaptation_depth = evaluate_adaptation_depth(adaptations, responses)

      %{
        capacity_score: capacity_score,
        response_flexibility: response_flexibility,
        adaptation_depth: adaptation_depth,
        challenges_identified: length(challenges),
        successful_adaptations: count_successful_adaptations(responses),
        adaptation_coverage: calculate_adaptation_coverage(challenges, responses)
      }
    end
  end

  # Innovation analysis summary calculation functions

  defp calculate_learning_efficiency(learning_patterns, knowledge_transfer) do
    # Calculate overall learning efficiency
    learning_effectiveness = learning_patterns[:learning_effectiveness] || 0.0
    transfer_efficiency = knowledge_transfer[:transfer_efficiency] || 0.0

    (learning_effectiveness + transfer_efficiency) / 2
  end

  defp evaluate_experimental_tendency(tactical_experimentation) do
    # Evaluate tendency toward experimentation
    experimentation_freq = tactical_experimentation[:experimentation_frequency] || 0.0
    risk_tolerance = tactical_experimentation[:risk_tolerance] || 0.0

    (experimentation_freq + risk_tolerance) / 2
  end

  defp assess_adaptive_responsiveness(adaptive_capacity, innovation_evolution) do
    # Assess overall adaptive responsiveness
    capacity_score = adaptive_capacity[:capacity_score] || 0.0
    progression_score = innovation_evolution[:innovation_progression] || 0.0

    (capacity_score + progression_score) / 2
  end

  # Detailed innovation analysis helper functions

  defp filter_innovations_by_time(innovations, window_start, window_duration) do
    window_end = DateTime.add(window_start, window_duration, :second)

    Enum.filter(innovations, fn innovation ->
      innovation_time =
        case innovation do
          %{timestamp: timestamp} -> timestamp
          %{detection_time: timestamp} -> timestamp
          # Default if no timestamp
          _ -> window_start
        end

      DateTime.compare(innovation_time, window_start) != :lt and
        DateTime.compare(innovation_time, window_end) != :gt
    end)
  end

  defp calculate_pattern_complexity(window_pattern) do
    # Calculate complexity based on target diversity and pattern type
    diversity = window_pattern[:target_diversity] || 0.0

    case window_pattern[:pattern_type] do
      :diverse_targeting -> diversity * 1.2
      :balanced_targeting -> diversity * 1.0
      :focused_targeting -> diversity * 0.8
      _ -> diversity * 0.5
    end
  end

  defp categorize_innovations(innovations) do
    # Categorize innovations by type
    Enum.group_by(innovations, fn innovation ->
      cond do
        Map.has_key?(innovation, :tactic) -> :novel_tactic
        Map.has_key?(innovation, :adaptation) -> :tactical_adaptation
        Map.has_key?(innovation, :counter_tactic) -> :counter_tactic
        true -> :unknown
      end
    end)
  end

  defp calculate_innovation_progression(evolution_stages) do
    if length(evolution_stages) < 2 do
      0.0
    else
      # Calculate progression based on increasing complexity
      complexity_progression =
        Enum.chunk_every(evolution_stages, 2, 1, :discard)
        |> Enum.map(fn [stage_a, stage_b] ->
          stage_b.pattern_complexity - stage_a.pattern_complexity
        end)

      positive_progressions = Enum.count(complexity_progression, &(&1 > 0))
      total_transitions = length(complexity_progression)

      if total_transitions > 0 do
        positive_progressions / total_transitions
      else
        0.0
      end
    end
  end

  defp evaluate_innovation_refinement(evolution_stages) do
    if length(evolution_stages) < 2 do
      0.0
    else
      # Evaluate refinement based on consistent innovation introduction
      innovation_consistency = Enum.map(evolution_stages, & &1.innovations_introduced)

      if length(innovation_consistency) > 0 do
        avg_innovations = Enum.sum(innovation_consistency) / length(innovation_consistency)
        variance = calculate_variance(innovation_consistency, avg_innovations)

        # Lower variance indicates more consistent refinement
        consistency_score =
          if avg_innovations > 0 do
            max(0.0, 1.0 - variance / avg_innovations)
          else
            0.0
          end

        consistency_score
      else
        0.0
      end
    end
  end

  defp identify_evolution_patterns(evolution_stages) do
    # Identify patterns in innovation evolution
    if length(evolution_stages) < 3 do
      []
    else
      patterns = []

      # Look for acceleration patterns
      complexity_trend = Enum.map(evolution_stages, & &1.pattern_complexity)

      if shows_acceleration?(complexity_trend) do
        patterns = [:accelerating_innovation | patterns]
      end

      # Look for refinement patterns
      innovation_trend = Enum.map(evolution_stages, & &1.innovations_introduced)

      if shows_refinement?(innovation_trend) do
        patterns = [:iterative_refinement | patterns]
      end

      # Look for breakthrough patterns
      if has_breakthrough_moments?(evolution_stages) do
        patterns = [:breakthrough_innovation | patterns]
      end

      patterns
    end
  end

  defp identify_experimental_behaviors(timeline, participants) do
    # Identify behaviors that indicate experimentation
    experimental_events = []

    # Look for unusual target selections
    unusual_targets = identify_unusual_target_selections(timeline.events)
    experimental_events = experimental_events ++ unusual_targets

    # Look for unconventional ship usage
    unconventional_ships = identify_unconventional_ship_usage(timeline.events, participants)
    experimental_events = experimental_events ++ unconventional_ships

    # Look for timing experiments
    timing_experiments = identify_timing_experiments(timeline.events)
    experimental_events = experimental_events ++ timing_experiments

    experimental_events
  end

  defp calculate_risk_tolerance(experimental_events, timeline) do
    if Enum.empty?(experimental_events) do
      0.0
    else
      # Calculate risk based on ISK value of experimental choices
      experimental_isk =
        Enum.sum(
          Enum.map(experimental_events, fn event ->
            event[:risk_isk] || 0
          end)
        )

      total_isk = Enum.sum(Enum.map(timeline.events, &(&1[:isk_value] || 0)))

      if total_isk > 0 do
        experimental_isk / total_isk
      else
        0.0
      end
    end
  end

  defp evaluate_experimental_success(experimental_events, timeline) do
    if Enum.empty?(experimental_events) do
      0.0
    else
      # Evaluate success by looking at outcomes
      successful_experiments =
        Enum.count(experimental_events, fn event ->
          # Consider successful if it led to increased activity
          post_experiment_events =
            Enum.filter(timeline.events, fn e ->
              DateTime.diff(e.timestamp, event[:timestamp] || DateTime.utc_now(), :second) <= 120 and
                DateTime.diff(e.timestamp, event[:timestamp] || DateTime.utc_now(), :second) > 0
            end)

          length(post_experiment_events) >= 2
        end)

      if length(experimental_events) > 0 do
        successful_experiments / length(experimental_events)
      else
        0.0
      end
    end
  end

  defp identify_innovation_triggers(experimental_events) do
    # Identify what triggered innovations
    Enum.group_by(experimental_events, fn event ->
      event[:trigger] || :unknown
    end)
    |> Enum.map(fn {trigger, events} ->
      %{
        trigger_type: trigger,
        frequency: length(events),
        effectiveness: calculate_trigger_effectiveness(events)
      }
    end)
  end

  defp identify_knowledge_transfer_events(timeline, side_participants) do
    # Identify events that suggest knowledge transfer
    if length(side_participants) < 2 do
      []
    else
      participant_ids = Enum.map(side_participants, & &1[:character_id])

      # Look for similar tactical patterns appearing sequentially
      participant_events =
        Enum.filter(timeline.events, fn event ->
          attacker_ids = Enum.map(event[:attackers] || [], & &1["character_id"])
          Enum.any?(attacker_ids, &(&1 in participant_ids))
        end)

      # Group events by participant and look for pattern propagation
      participant_grouped =
        Enum.group_by(participant_events, fn event ->
          attacker_ids = Enum.map(event[:attackers] || [], & &1["character_id"])
          Enum.find(attacker_ids, &(&1 in participant_ids))
        end)

      identify_pattern_propagation(participant_grouped)
    end
  end

  defp calculate_transfer_efficiency(transfer_events, side_participants) do
    if length(transfer_events) == 0 or length(side_participants) < 2 do
      0.0
    else
      # Efficiency based on how quickly patterns spread
      successful_transfers =
        Enum.count(transfer_events, fn event ->
          # Within 3 minutes
          event[:transfer_speed] && event.transfer_speed <= 180
        end)

      if length(transfer_events) > 0 do
        successful_transfers / length(transfer_events)
      else
        0.0
      end
    end
  end

  defp calculate_knowledge_spread_speed(transfer_events) do
    if Enum.empty?(transfer_events) do
      0.0
    else
      # Calculate average spread speed
      transfer_times =
        Enum.map(transfer_events, fn event ->
          # Default 5 minutes if not specified
          event[:transfer_speed] || 300
        end)

      if length(transfer_times) > 0 do
        avg_time = Enum.sum(transfer_times) / length(transfer_times)
        # Convert to score (faster = higher score, normalize to 5 minutes)
        max(0.0, 1.0 - avg_time / 300.0)
      else
        0.0
      end
    end
  end

  defp calculate_tactic_adoption_rate(transfer_events, side_participants) do
    if length(transfer_events) == 0 or length(side_participants) < 2 do
      0.0
    else
      # Calculate adoption rate based on how many participants adopted new tactics
      participants_with_adoptions = Enum.uniq(Enum.map(transfer_events, & &1[:adopter_id]))

      if length(side_participants) > 0 do
        length(participants_with_adoptions) / length(side_participants)
      else
        0.0
      end
    end
  end

  defp identify_transfer_mechanisms(transfer_patterns) do
    # Identify how knowledge was transferred
    mechanisms = []

    # Look for coordination-based transfer
    coordination_transfers =
      Enum.flat_map(transfer_patterns, &(&1[:transfer_events] || []))
      |> Enum.filter(&(&1[:mechanism] == :coordination))

    if length(coordination_transfers) > 0 do
      mechanisms = [:coordination_based | mechanisms]
    end

    # Look for observation-based transfer
    observation_transfers =
      Enum.flat_map(transfer_patterns, &(&1[:transfer_events] || []))
      |> Enum.filter(&(&1[:mechanism] == :observation))

    if length(observation_transfers) > 0 do
      mechanisms = [:observation_based | mechanisms]
    end

    # Look for communication-based transfer
    communication_transfers =
      Enum.flat_map(transfer_patterns, &(&1[:transfer_events] || []))
      |> Enum.filter(&(&1[:mechanism] == :communication))

    if length(communication_transfers) > 0 do
      mechanisms = [:communication_based | mechanisms]
    end

    mechanisms
  end

  defp identify_tactical_challenges(timeline, participants) do
    # Identify challenges that required adaptation
    challenges = []

    # Look for sudden changes in battle dynamics
    intensity_changes = identify_intensity_change_points(timeline.events)

    challenges =
      challenges ++
        Enum.map(intensity_changes, fn change ->
          %{
            type: :intensity_change,
            timestamp: change.timestamp,
            severity: change.intensity_delta,
            context: change
          }
        end)

    # Look for tactical disadvantages
    disadvantages = identify_tactical_disadvantages(timeline, participants)
    challenges = challenges ++ disadvantages

    challenges
  end

  defp identify_adaptive_responses(challenges, adaptations, timeline) do
    # Identify responses to challenges
    Enum.map(challenges, fn challenge ->
      # Find adaptations that occurred shortly after this challenge
      relevant_adaptations =
        Enum.filter(adaptations, fn adaptation ->
          adaptation_time = adaptation[:timestamp] || adaptation[:detection_time]

          if adaptation_time do
            time_diff = DateTime.diff(adaptation_time, challenge.timestamp, :second)
            # Within 5 minutes
            time_diff >= 0 && time_diff <= 300
          else
            false
          end
        end)

      %{
        challenge: challenge,
        responses: relevant_adaptations,
        response_speed: calculate_response_speed(challenge, relevant_adaptations),
        response_effectiveness: evaluate_response_effectiveness(relevant_adaptations, timeline)
      }
    end)
  end

  defp calculate_overall_adaptive_capacity(challenges, responses) do
    if Enum.empty?(challenges) do
      1.0
    else
      # Calculate capacity based on successful responses
      successful_responses =
        Enum.count(responses, fn response ->
          length(response.responses) > 0 && response.response_effectiveness > 0.5
        end)

      successful_responses / length(challenges)
    end
  end

  defp measure_response_flexibility(responses) do
    if Enum.empty?(responses) do
      0.0
    else
      # Measure flexibility based on variety of response types
      response_types =
        Enum.flat_map(responses, fn response ->
          Enum.map(response.responses, fn adaptation ->
            adaptation[:adaptation] || adaptation[:type] || :unknown
          end)
        end)
        |> Enum.uniq()

      # Normalize flexibility score
      # Assume max 5 types
      flexibility_score = length(response_types) / 5.0
      min(1.0, flexibility_score)
    end
  end

  defp evaluate_adaptation_depth(adaptations, responses) do
    if Enum.empty?(adaptations) do
      0.0
    else
      # Evaluate depth based on complexity of adaptations
      complex_adaptations =
        Enum.count(adaptations, fn adaptation ->
          case adaptation[:adaptation] || adaptation[:type] do
            :formation_change -> true
            :tactical_doctrine_shift -> true
            :multi_vector_adaptation -> true
            _ -> false
          end
        end)

      if length(adaptations) > 0 do
        complex_adaptations / length(adaptations)
      else
        0.0
      end
    end
  end

  defp count_successful_adaptations(responses) do
    Enum.count(responses, fn response ->
      response.response_effectiveness > 0.6
    end)
  end

  defp calculate_adaptation_coverage(challenges, responses) do
    if Enum.empty?(challenges) do
      1.0
    else
      # Calculate what percentage of challenges had adaptive responses
      challenges_with_responses =
        Enum.count(responses, fn response ->
          length(response.responses) > 0
        end)

      challenges_with_responses / length(challenges)
    end
  end

  # Additional utility helper functions for innovation analysis

  defp shows_acceleration?(values) do
    if length(values) < 3 do
      false
    else
      # Check if values show increasing rate of change
      differences =
        Enum.chunk_every(values, 2, 1, :discard)
        |> Enum.map(fn [a, b] -> b - a end)

      if length(differences) >= 2 do
        second_differences =
          Enum.chunk_every(differences, 2, 1, :discard)
          |> Enum.map(fn [a, b] -> b - a end)

        positive_accelerations = Enum.count(second_differences, &(&1 > 0))
        positive_accelerations > length(second_differences) / 2
      else
        false
      end
    end
  end

  defp shows_refinement?(values) do
    if length(values) < 3 do
      false
    else
      # Check for decreasing variance over time (indicating refinement)
      first_half = Enum.take(values, div(length(values), 2))
      second_half = Enum.drop(values, div(length(values), 2))

      if length(first_half) > 0 and length(second_half) > 0 do
        first_mean = Enum.sum(first_half) / length(first_half)
        second_mean = Enum.sum(second_half) / length(second_half)

        first_variance = calculate_variance(first_half, first_mean)
        second_variance = calculate_variance(second_half, second_mean)

        second_variance < first_variance * 0.8
      else
        false
      end
    end
  end

  defp has_breakthrough_moments?(evolution_stages) do
    # Look for sudden jumps in innovation count
    innovation_counts = Enum.map(evolution_stages, & &1.innovations_introduced)

    if length(innovation_counts) >= 2 do
      max_count = Enum.max(innovation_counts)
      avg_count = Enum.sum(innovation_counts) / length(innovation_counts)

      # Breakthrough if max is significantly higher than average
      max_count > avg_count * 2
    else
      false
    end
  end

  defp identify_unusual_target_selections(events) do
    # Identify target selections that are statistically unusual
    target_types =
      Enum.map(events, fn event ->
        event[:victim][:ship_type_id]
      end)

    ship_classes = Enum.map(target_types, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)
    class_frequencies = Enum.frequencies(ship_classes)

    # Find classes that are targeted unusually often or rarely
    total_kills = length(events)

    unusual_selections =
      Enum.filter(class_frequencies, fn {class, count} ->
        frequency = count / total_kills
        expected_frequency = get_expected_target_frequency(class)

        # Unusual if frequency deviates significantly from expected
        abs(frequency - expected_frequency) > 0.2
      end)

    Enum.map(unusual_selections, fn {class, count} ->
      %{
        type: :unusual_targeting,
        target_class: class,
        frequency: count / total_kills,
        unusual_factor: abs(count / total_kills - get_expected_target_frequency(class)),
        timestamp: List.first(events).timestamp,
        risk_isk: estimate_targeting_risk(class, count)
      }
    end)
  end

  defp identify_unconventional_ship_usage(events, participants) do
    # Identify unconventional ship usage patterns
    # For now, return empty list as this requires more complex analysis
    []
  end

  defp identify_timing_experiments(events) do
    # Identify timing-based experiments
    if length(events) < 5 do
      []
    else
      # Look for unusual timing patterns
      kill_intervals =
        Enum.chunk_every(events, 2, 1, :discard)
        |> Enum.map(fn [event_a, event_b] ->
          DateTime.diff(event_b.timestamp, event_a.timestamp, :second)
        end)

      if length(kill_intervals) > 0 do
        mean_interval = Enum.sum(kill_intervals) / length(kill_intervals)

        # Find intervals that deviate significantly
        unusual_intervals =
          Enum.with_index(kill_intervals)
          |> Enum.filter(fn {interval, _index} ->
            abs(interval - mean_interval) > mean_interval * 0.5
          end)

        Enum.map(unusual_intervals, fn {interval, index} ->
          %{
            type: :timing_experiment,
            interval_deviation: abs(interval - mean_interval),
            timestamp: Enum.at(events, index).timestamp,
            # Timing experiments don't directly risk ISK
            risk_isk: 0
          }
        end)
      else
        []
      end
    end
  end

  defp calculate_trigger_effectiveness(events) do
    # Calculate how effective different triggers were
    if Enum.empty?(events) do
      0.0
    else
      # For now, return a default effectiveness
      # Could be enhanced with actual outcome analysis
      0.6
    end
  end

  defp identify_pattern_propagation(participant_grouped) do
    # Identify patterns spreading between participants
    if map_size(participant_grouped) < 2 do
      []
    else
      # Look for similar tactical patterns appearing in sequence
      participant_patterns =
        Enum.map(participant_grouped, fn {participant_id, events} ->
          if length(events) >= 2 do
            pattern = analyze_participant_tactical_pattern(events)

            %{
              participant_id: participant_id,
              pattern: pattern,
              first_occurrence: List.first(events).timestamp
            }
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      # Find similar patterns with different timestamps (indicating transfer)
      identify_similar_patterns_with_timing(participant_patterns)
    end
  end

  defp identify_intensity_change_points(events) do
    # Identify points where battle intensity changed significantly
    if length(events) < 5 do
      []
    else
      # 90-second windows
      intensity_windows = calculate_intensity_windows(events, 90)

      change_points = []

      Enum.reduce(intensity_windows, {nil, change_points}, fn {window_start, intensity},
                                                              {prev_intensity, acc} ->
        if prev_intensity && abs(intensity - prev_intensity) >= 2 do
          change_point = %{
            timestamp: window_start,
            intensity_delta: intensity - prev_intensity,
            new_intensity: intensity,
            prev_intensity: prev_intensity
          }

          {intensity, [change_point | acc]}
        else
          {intensity, acc}
        end
      end)
      |> elem(1)
      |> Enum.reverse()
    end
  end

  defp identify_tactical_disadvantages(timeline, participants) do
    # Identify tactical disadvantages that required adaptation
    disadvantages = []

    # Look for numerical disadvantages
    sides = group_participants_by_side(participants)

    if length(sides) >= 2 do
      side_sizes = Enum.map(sides, fn {_side, side_participants} -> length(side_participants) end)
      max_size = Enum.max(side_sizes)
      min_size = Enum.min(side_sizes)

      if max_size > min_size * 1.5 do
        disadvantages = [
          %{
            type: :numerical_disadvantage,
            timestamp: List.first(timeline.events).timestamp,
            severity: max_size / min_size,
            context: %{max_size: max_size, min_size: min_size}
          }
          | disadvantages
        ]
      end
    end

    disadvantages
  end

  defp calculate_response_speed(challenge, responses) do
    if Enum.empty?(responses) do
      0.0
    else
      # Calculate average response time
      response_times =
        Enum.map(responses, fn response ->
          response_time = response[:timestamp] || response[:detection_time]

          if response_time do
            DateTime.diff(response_time, challenge.timestamp, :second)
          else
            # Default 5 minutes
            300
          end
        end)

      if length(response_times) > 0 do
        avg_response_time = Enum.sum(response_times) / length(response_times)
        # Convert to score (faster = higher score, normalize to 5 minutes)
        max(0.0, 1.0 - avg_response_time / 300.0)
      else
        0.0
      end
    end
  end

  defp evaluate_response_effectiveness(responses, timeline) do
    if Enum.empty?(responses) do
      0.0
    else
      # Evaluate effectiveness based on battle outcomes after responses
      effective_responses =
        Enum.count(responses, fn response ->
          response_time = response[:timestamp] || response[:detection_time]

          if response_time do
            # Look at events after this response
            post_response_events =
              Enum.filter(timeline.events, fn event ->
                time_diff = DateTime.diff(event.timestamp, response_time, :second)
                # Within 3 minutes
                time_diff >= 0 && time_diff <= 180
              end)

            # Consider effective if there was increased activity
            length(post_response_events) >= 2
          else
            false
          end
        end)

      if length(responses) > 0 do
        effective_responses / length(responses)
      else
        0.0
      end
    end
  end

  defp get_expected_target_frequency(ship_class) do
    # Expected frequency of targeting different ship classes
    case ship_class do
      :frigate -> 0.25
      :destroyer -> 0.15
      :cruiser -> 0.30
      :battlecruiser -> 0.15
      :battleship -> 0.10
      :capital -> 0.03
      :supercapital -> 0.01
      :industrial -> 0.01
      _ -> 0.1
    end
  end

  defp estimate_targeting_risk(ship_class, count) do
    # Estimate ISK risk of unusual targeting
    base_risk =
      case ship_class do
        :capital -> 2_000_000_000 * count
        :supercapital -> 50_000_000_000 * count
        :battleship -> 200_000_000 * count
        :battlecruiser -> 100_000_000 * count
        :cruiser -> 50_000_000 * count
        _ -> 10_000_000 * count
      end

    base_risk
  end

  defp analyze_participant_tactical_pattern(events) do
    # Analyze tactical pattern for a specific participant
    if length(events) < 2 do
      %{pattern_type: :insufficient_data}
    else
      target_ships =
        Enum.map(events, fn event ->
          event[:victim][:ship_type_id]
        end)

      ship_classes = Enum.map(target_ships, &EveDmv.StaticData.ShipTypes.classify_ship_type/1)
      class_frequencies = Enum.frequencies(ship_classes)

      primary_target =
        if map_size(class_frequencies) > 0 do
          {class, _count} = Enum.max_by(class_frequencies, fn {_class, count} -> count end)
          class
        else
          :unknown
        end

      %{
        pattern_type: determine_tactical_pattern_type(primary_target, class_frequencies),
        primary_target: primary_target,
        target_diversity: calculate_target_diversity(class_frequencies)
      }
    end
  end

  defp identify_similar_patterns_with_timing(participant_patterns) do
    # Find similar patterns that occurred at different times
    if length(participant_patterns) < 2 do
      []
    else
      pattern_pairs =
        for pattern_a <- participant_patterns,
            pattern_b <- participant_patterns,
            pattern_a.participant_id != pattern_b.participant_id,
            patterns_similar?(pattern_a.pattern, pattern_b.pattern) do
          time_diff =
            DateTime.diff(pattern_b.first_occurrence, pattern_a.first_occurrence, :second)

          # Within 5 minutes and B came after A
          if time_diff > 0 && time_diff <= 300 do
            %{
              type: :pattern_transfer,
              from_participant: pattern_a.participant_id,
              to_participant: pattern_b.participant_id,
              pattern: pattern_a.pattern,
              transfer_speed: time_diff,
              timestamp: pattern_b.first_occurrence,
              adopter_id: pattern_b.participant_id,
              # Could be enhanced to detect mechanism
              mechanism: :observation
            }
          else
            nil
          end
        end
        |> Enum.reject(&is_nil/1)

      pattern_pairs
    end
  end

  defp patterns_similar?(pattern_a, pattern_b) do
    # Check if two tactical patterns are similar
    pattern_a[:pattern_type] == pattern_b[:pattern_type] and
      pattern_a[:primary_target] == pattern_b[:primary_target]
  end
end
