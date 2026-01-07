defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalyzer do
  @moduledoc """
  Consolidated battle analysis module that combines functionality from multiple specialized analyzers.

  This module consolidates the following previously separate analyzers:
  - FleetEffectivenessAnalyzer
  - TargetSelectionAnalyzer
  - TimingAnalyzer
  - FormationAnalyzer
  - BattlePhaseAnalyzer
  - ShipClassificationAnalyzer

  The consolidation improves maintainability while preserving all real analysis functionality.
  """

  alias EveDmv.Contexts.BattleAnalysis.Shared.BattleAnalysisUtils
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedUtilities
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.StaticData.ShipTypes
  require Logger

  @doc """
  Perform comprehensive battle analysis on killmail data.

  Combines fleet effectiveness, target selection, timing, formation, and phase analysis
  into a single comprehensive analysis result.
  """
  def analyze_battle(killmails, _options \\ []) do
    Logger.info("Starting comprehensive battle analysis for #{length(killmails)} killmails")

    with {:ok, timeline} <- build_battle_timeline(killmails),
         {:ok, participants} <- extract_participants(killmails),
         {:ok, sides} <- determine_battle_sides(participants) do
      # Core analysis components
      fleet_analysis = analyze_fleet_effectiveness(participants)
      target_analysis = analyze_target_selection(timeline, participants)
      timing_analysis = analyze_timing_patterns(timeline, participants)
      formation_analysis = analyze_formation_patterns(timeline, participants)
      phase_analysis = analyze_battle_phases(timeline, participants)

      # Tactical insights
      tactical_insights =
        generate_tactical_insights(
          fleet_analysis,
          target_analysis,
          timing_analysis,
          formation_analysis
        )

      {:ok,
       %{
         timeline: timeline,
         participants: participants,
         sides: sides,
         fleet_effectiveness: fleet_analysis,
         target_selection: target_analysis,
         timing_patterns: timing_analysis,
         formation_patterns: formation_analysis,
         battle_phases: phase_analysis,
         tactical_insights: tactical_insights,
         summary:
           generate_battle_summary([
             fleet_analysis,
             target_analysis,
             timing_analysis,
             formation_analysis,
             phase_analysis
           ])
       }}
    else
      {:error, reason} ->
        Logger.error("Battle analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Analyze fleet effectiveness metrics including role balance and coordination.
  """
  def analyze_fleet_effectiveness(participants) do
    Logger.debug("Analyzing fleet effectiveness for #{length(participants)} participants")

    if Enum.empty?(participants) do
      %{
        role_balance: %{score: 0.0, balance: 0.0},
        doctrine_adherence: %{score: 0.0, coherence: 0.0, doctrine_type: :unknown},
        class_consistency: %{score: 0.0, diversity: 0.0},
        critical_roles: %{score: 0.0, coverage: []},
        fleet_size_rating: %{score: 0.0, size: 0, category: :empty}
      }
    else
      # Classify ships and extract roles
      ship_classes = classify_ships_by_class(participants)
      role_distribution = extract_role_distribution(participants)

      %{
        role_balance: calculate_role_balance(role_distribution),
        doctrine_adherence: calculate_doctrine_adherence(ship_classes, participants),
        class_consistency: calculate_class_consistency(ship_classes),
        critical_roles: analyze_critical_roles(role_distribution),
        fleet_size_rating: evaluate_fleet_size(length(participants))
      }
    end
  end

  @doc """
  Analyze target selection patterns and prioritization strategies.
  """
  def analyze_target_selection(timeline, participants) do
    Logger.debug("Analyzing target selection patterns")

    if Enum.empty?(timeline.events) do
      %{
        prioritization: %{consistency: 0.0, high_value_focus: 0.0},
        focus_fire: %{quality: 0.0, consistency: 0.0},
        target_switching: %{switches: 0, switch_rate: 0.0},
        effectiveness: %{overall: 0.0, coordination: 0.0}
      }
    else
      # Extract target selection data
      target_order = extract_target_order(timeline)
      focus_windows = identify_focus_fire_windows(timeline)
      target_switches = identify_target_switches(timeline)

      %{
        prioritization: analyze_target_prioritization(target_order, timeline),
        focus_fire: analyze_focus_fire_patterns(focus_windows, timeline),
        target_switching: analyze_target_switching_patterns(target_switches, timeline),
        effectiveness: evaluate_target_selection_effectiveness(timeline, participants)
      }
    end
  end

  @doc """
  Analyze timing patterns and tempo control.
  """
  def analyze_timing_patterns(timeline, participants) do
    Logger.debug("Analyzing timing patterns")

    if Enum.empty?(timeline.events) do
      %{
        engagement_timing: %{initiation_speed: 0, escalation_rate: 0.0},
        coordination_timing: %{synchronization: 0.0, timing_windows: []},
        alpha_strikes: %{instances: 0, quality: 0.0},
        tactical_rhythm: %{tempo: 0.0, consistency: 0.0}
      }
    else
      early_events = Enum.take(timeline.events, 5)

      %{
        engagement_timing: analyze_engagement_timing(early_events, timeline),
        coordination_timing: analyze_coordination_timing(timeline),
        alpha_strikes: analyze_alpha_strike_timing(timeline),
        tactical_rhythm: analyze_tactical_rhythm(timeline, participants)
      }
    end
  end

  @doc """
  Analyze formation patterns and positioning strategies.
  """
  def analyze_formation_patterns(timeline, participants) do
    Logger.debug("Analyzing formation patterns")

    if Enum.empty?(participants) do
      %{
        initial_formation: :unknown,
        formations_by_side: %{},
        formation_changes: [],
        effectiveness: 0.0
      }
    else
      # Group by sides and analyze formations
      sides = group_participants_by_side(participants)

      formations_by_side =
        Enum.map(sides, fn {side, side_participants} ->
          {side, analyze_side_formation(timeline, side_participants)}
        end)
        |> Map.new()

      %{
        initial_formation: determine_initial_formation(timeline, participants),
        formations_by_side: formations_by_side,
        formation_changes: detect_formation_changes(timeline, participants),
        effectiveness: calculate_formation_effectiveness(timeline, formations_by_side)
      }
    end
  end

  @doc """
  Analyze battle phases and engagement progression.
  """
  def analyze_battle_phases(timeline, _participants) do
    Logger.debug("Analyzing battle phases")

    if Enum.empty?(timeline.events) do
      %{
        phases: [],
        phase_transitions: [],
        dominant_phase: :unknown,
        phase_effectiveness: %{}
      }
    else
      phases = identify_battle_phases(timeline)
      transitions = analyze_phase_transitions(phases, timeline)

      %{
        phases: phases,
        phase_transitions: transitions,
        dominant_phase: determine_dominant_phase(phases),
        phase_effectiveness: evaluate_phase_effectiveness(phases, timeline)
      }
    end
  end

  @doc """
  Extract tactical insights from comprehensive analysis results.
  """
  def extract_tactical_insights(analysis_results) do
    generate_tactical_insights(
      analysis_results.fleet_effectiveness,
      analysis_results.target_selection,
      analysis_results.timing_patterns,
      analysis_results.formation_patterns
    )
  end

  # Private helper functions for fleet effectiveness

  defp classify_ships_by_class(participants) do
    participants
    |> Enum.group_by(fn participant ->
      ship_type_id = participant[:ship_type_id] || participant["ship_type_id"]
      classify_ship_type(ship_type_id)
    end)
    |> Enum.map(fn {class, ships} ->
      {class, %{count: length(ships), ships: ships}}
    end)
    |> Map.new()
  end

  defp extract_role_distribution(participants) do
    participants
    |> Enum.group_by(fn participant ->
      ship_type_id = participant[:ship_type_id] || participant["ship_type_id"]
      determine_ship_role(ship_type_id)
    end)
    |> Enum.map(fn {role, ships} ->
      {role, %{count: length(ships), ships: ships}}
    end)
    |> Map.new()
  end

  defp calculate_role_balance(role_distribution) do
    BattleAnalysisUtils.calculate_role_balance(role_distribution)
  end

  defp calculate_doctrine_adherence(ship_classes, participants) do
    if Enum.empty?(ship_classes) do
      %{score: 0.0, coherence: 0.0, doctrine_type: :unknown}
    else
      coherence = calculate_doctrine_coherence(ship_classes)
      doctrine_type = identify_doctrine_type(participants)

      %{
        score: coherence,
        coherence: coherence,
        doctrine_type: doctrine_type
      }
    end
  end

  defp calculate_class_consistency(ship_classes) do
    class_count = map_size(ship_classes)

    consistency_score =
      case class_count do
        1 -> 1.0
        2 -> 0.8
        3 -> 0.6
        4 -> 0.4
        _ -> 0.2
      end

    # Assume 6 main ship classes
    diversity = class_count / 6.0

    %{score: consistency_score, diversity: diversity}
  end

  defp analyze_critical_roles(role_distribution) do
    critical_roles = [:logistics, :command, :ewar, :capital]

    present_critical =
      critical_roles
      |> Enum.filter(&Map.has_key?(role_distribution, &1))

    coverage_score = length(present_critical) / length(critical_roles)

    %{score: coverage_score, coverage: present_critical}
  end

  defp evaluate_fleet_size(size) do
    {category, score} =
      case size do
        s when s <= 5 -> {:small_gang, 0.6}
        s when s <= 20 -> {:medium_gang, 0.8}
        s when s <= 50 -> {:large_gang, 1.0}
        s when s <= 100 -> {:small_fleet, 0.9}
        _ -> {:large_fleet, 0.8}
      end

    %{score: score, size: size, category: category}
  end

  # Private helper functions for target selection

  defp extract_target_order(timeline) do
    timeline.events
    |> Enum.map(fn event ->
      %{
        victim_id: event.victim_character_id,
        victim_ship: event.victim_ship_type_id,
        timestamp: event.timestamp,
        attackers: extract_attackers(event)
      }
    end)
  end

  defp identify_focus_fire_windows(timeline) do
    timeline.events
    |> Enum.chunk_by(fn event -> event.victim_character_id end)
    |> Enum.filter(fn events -> length(events) > 1 end)
    |> Enum.map(fn events ->
      %{
        target: hd(events).victim_character_id,
        start_time: hd(events).timestamp,
        end_time: List.last(events).timestamp,
        attackers: events |> Enum.flat_map(&extract_attackers/1) |> Enum.uniq(),
        damage_coordination: calculate_damage_coordination(events)
      }
    end)
  end

  defp identify_target_switches(timeline) do
    timeline.events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, curr] ->
      prev.victim_character_id != curr.victim_character_id
    end)
    |> Enum.map(fn [prev, curr] ->
      %{
        from_target: prev.victim_character_id,
        to_target: curr.victim_character_id,
        switch_time: curr.timestamp,
        time_gap: DateTimeUtils.diff(curr.timestamp, prev.timestamp, :second)
      }
    end)
  end

  # Private helper functions for timing analysis

  defp analyze_engagement_timing(early_events, timeline) do
    if Enum.empty?(early_events) do
      %{initiation_speed: 0, escalation_rate: 0.0}
    else
      first_event = hd(timeline.events)

      # Calculate time to reach engagement intensity
      intensity_buildup = calculate_intensity_buildup(early_events)

      %{
        initiation_speed: calculate_initiation_speed(early_events),
        escalation_rate: intensity_buildup,
        first_kill_time: first_event.timestamp
      }
    end
  end

  defp analyze_coordination_timing(timeline) do
    if length(timeline.events) < 2 do
      %{synchronization: 0.0, timing_windows: []}
    else
      # Analyze timing gaps between coordinated attacks
      timing_gaps = calculate_timing_gaps(timeline.events)
      coordination_windows = identify_coordination_windows(timeline.events)

      %{
        synchronization: calculate_synchronization_score(timing_gaps),
        timing_windows: coordination_windows,
        average_gap: average(timing_gaps)
      }
    end
  end

  defp analyze_alpha_strike_timing(timeline) do
    alpha_strikes = identify_alpha_strikes(timeline.events)

    %{
      instances: length(alpha_strikes),
      quality: calculate_average_alpha_quality(alpha_strikes),
      timing_precision: calculate_alpha_timing_precision(alpha_strikes)
    }
  end

  defp analyze_tactical_rhythm(timeline, _participants) do
    if Enum.empty?(timeline.events) do
      %{tempo: 0.0, consistency: 0.0}
    else
      # Analyze the rhythm of engagement
      event_intervals = calculate_event_intervals(timeline.events)
      tempo_changes = identify_tempo_changes(event_intervals)

      %{
        tempo: calculate_average_tempo(event_intervals),
        consistency: calculate_tempo_consistency(event_intervals),
        tempo_changes: tempo_changes
      }
    end
  end

  # Private helper functions for formation analysis

  defp group_participants_by_side(participants) do
    participants
    |> Enum.group_by(fn participant ->
      # Determine side based on corporation/alliance patterns
      determine_participant_side(participant)
    end)
  end

  defp analyze_side_formation(timeline, participants) do
    if Enum.empty?(participants) do
      %{formation_type: :unknown, cohesion: 0.0}
    else
      # Analyze formation based on ship types and timing
      ship_distribution = analyze_ship_distribution(participants)
      formation_type = infer_formation_type(ship_distribution)
      cohesion = calculate_formation_cohesion(timeline, participants)

      %{
        formation_type: formation_type,
        cohesion: cohesion,
        ship_distribution: ship_distribution
      }
    end
  end

  defp determine_initial_formation(timeline, participants) do
    # Analyze early engagement patterns to determine formation
    early_participants = extract_early_participants(timeline, participants)
    ship_roles = Enum.map(early_participants, &determine_ship_role(&1[:ship_type_id]))

    cond do
      Enum.member?(ship_roles, :logistics) and Enum.member?(ship_roles, :dps) -> :ball_formation
      Enum.count(ship_roles, &(&1 == :tackle)) > 2 -> :spread_formation
      Enum.count(ship_roles, &(&1 == :dps)) > length(ship_roles) * 0.7 -> :alpha_formation
      true -> :mixed_formation
    end
  end

  defp detect_formation_changes(timeline, participants) do
    # Analyze timeline for formation changes
    # This is a simplified implementation
    timeline_segments = Enum.chunk_every(timeline.events, 5)

    timeline_segments
    |> Enum.with_index()
    |> Enum.map(fn {segment, index} ->
      segment_participants = extract_segment_participants(segment, participants)

      %{
        time_segment: index,
        formation: determine_segment_formation(segment_participants),
        participants: length(segment_participants)
      }
    end)
  end

  defp calculate_formation_effectiveness(_timeline, formations_by_side) do
    if Enum.empty?(formations_by_side) do
      0.0
    else
      # Calculate effectiveness based on cohesion and survival
      cohesion_scores =
        formations_by_side
        |> Map.values()
        |> Enum.map(&Map.get(&1, :cohesion, 0.0))

      average(cohesion_scores)
    end
  end

  # Private helper functions for battle phases

  defp identify_battle_phases(timeline) do
    # Analyze timeline to identify distinct phases
    if length(timeline.events) < 3 do
      [%{phase: :single_engagement, start_time: hd(timeline.events).timestamp, duration: 0}]
    else
      # Group events by intensity and timing
      event_groups = group_events_by_intensity(timeline.events)

      event_groups
      |> Enum.with_index()
      |> Enum.map(fn {events, index} ->
        %{
          phase: determine_phase_type(events, index),
          start_time: hd(events).timestamp,
          end_time: List.last(events).timestamp,
          duration: calculate_phase_duration(events),
          intensity: calculate_phase_intensity(events),
          events: length(events)
        }
      end)
    end
  end

  defp analyze_phase_transitions(phases, _timeline) do
    if length(phases) < 2 do
      []
    else
      phases
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev_phase, curr_phase] ->
        %{
          from_phase: prev_phase.phase,
          to_phase: curr_phase.phase,
          transition_time: curr_phase.start_time,
          intensity_change: curr_phase.intensity - prev_phase.intensity,
          duration_gap: DateTimeUtils.diff(curr_phase.start_time, prev_phase.end_time, :second)
        }
      end)
    end
  end

  defp determine_dominant_phase(phases) do
    phases
    |> Enum.max_by(&(&1.duration * &1.intensity), fn -> %{phase: :unknown} end)
    |> Map.get(:phase, :unknown)
  end

  defp evaluate_phase_effectiveness(phases, timeline) do
    phases
    |> Enum.map(fn phase ->
      effectiveness = calculate_phase_effectiveness(phase, timeline)
      {phase.phase, effectiveness}
    end)
    |> Map.new()
  end

  # Tactical insights generation

  defp generate_tactical_insights(
         fleet_analysis,
         target_analysis,
         timing_analysis,
         formation_analysis
       ) do
    strengths =
      identify_tactical_strengths(
        fleet_analysis,
        target_analysis,
        timing_analysis,
        formation_analysis
      )

    weaknesses =
      identify_tactical_weaknesses(
        fleet_analysis,
        target_analysis,
        timing_analysis,
        formation_analysis
      )

    recommendations = generate_tactical_recommendations(strengths, weaknesses)

    %{
      strengths: strengths,
      weaknesses: weaknesses,
      recommendations: recommendations,
      overall_assessment:
        calculate_overall_tactical_assessment(
          fleet_analysis,
          target_analysis,
          timing_analysis,
          formation_analysis
        )
    }
  end

  defp generate_battle_summary(analysis_components) do
    # Generate a comprehensive battle summary
    %{
      overall_score: calculate_overall_battle_score(analysis_components),
      key_factors: extract_key_battle_factors(analysis_components),
      battle_outcome: determine_battle_outcome(analysis_components),
      lessons_learned: extract_lessons_learned(analysis_components)
    }
  end

  # Utility functions

  defp build_battle_timeline(killmails) do
    events =
      killmails
      |> Enum.map(fn km ->
        %{
          timestamp: km.killmail_time,
          victim_character_id: km.victim_character_id,
          victim_ship_type_id: km.victim_ship_type_id,
          victim_corporation_id: km.victim_corporation_id,
          attackers: extract_attackers_from_killmail(km),
          solar_system_id: km.solar_system_id,
          total_value: get_killmail_value(km)
        }
      end)
      |> Enum.sort_by(& &1.timestamp)

    {:ok, %{events: events, duration: calculate_timeline_duration(events)}}
  end

  defp extract_participants(killmails) do
    participants =
      killmails
      |> Enum.flat_map(fn km ->
        victim = %{
          character_id: km.victim_character_id,
          ship_type_id: km.victim_ship_type_id,
          corporation_id: km.victim_corporation_id,
          role: :victim
        }

        attackers =
          extract_attackers_from_killmail(km)
          |> Enum.map(fn attacker ->
            %{
              character_id: attacker["character_id"],
              ship_type_id: attacker["ship_type_id"],
              corporation_id: attacker["corporation_id"],
              role: :attacker
            }
          end)

        [victim | attackers]
      end)
      |> Enum.uniq_by(& &1.character_id)
      |> Enum.filter(& &1.character_id)

    {:ok, participants}
  end

  defp determine_battle_sides(participants) do
    # Group participants by corporation/alliance
    sides =
      participants
      |> Enum.group_by(& &1.corporation_id)
      |> Enum.map(fn {corp_id, corp_participants} ->
        %{
          corporation_id: corp_id,
          participants: corp_participants,
          size: length(corp_participants)
        }
      end)
      |> Enum.sort_by(& &1.size, :desc)

    {:ok, %{sides: sides, side_count: length(sides)}}
  end

  # Helper utility functions

  defp classify_ship_type(ship_type_id) do
    ShipTypes.classify_ship_type(ship_type_id)
  end

  defp determine_ship_role(ship_type_id) do
    # Use centralized ship role determination
    cond do
      ShipTypes.tackle_ship?(ship_type_id) -> :tackle
      ShipTypes.logistics?(ship_type_id) -> :logistics
      ShipTypes.ewar?(ship_type_id) -> :ewar
      ShipTypes.dps_ship?(ship_type_id) -> :dps
      true -> :unknown
    end
  end

  defp extract_attackers(event) do
    # Extract attacker information from event
    Map.get(event, :attackers, [])
  end

  defp extract_attackers_from_killmail(killmail) do
    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) -> attackers
      _ -> []
    end
  end

  defp get_killmail_value(killmail) do
    get_in(killmail.raw_data, ["zkb", "totalValue"]) || 0
  end

  defp calculate_timeline_duration(events) do
    if length(events) < 2 do
      0
    else
      first_event = hd(events)
      last_event = List.last(events)
      DateTimeUtils.diff(last_event.timestamp, first_event.timestamp, :second)
    end
  end

  defp determine_participant_side(participant) do
    # Simplified side determination based on corporation
    participant.corporation_id || :unknown
  end

  defp calculate_doctrine_coherence(ship_classes) do
    BattleAnalysisUtils.calculate_doctrine_coherence(ship_classes)
  end

  defp identify_doctrine_type(participants) do
    ship_roles = Enum.map(participants, &determine_ship_role(&1[:ship_type_id]))

    cond do
      Enum.count(ship_roles, &(&1 == :dps)) > length(ship_roles) * 0.7 -> :alpha_strike
      Enum.member?(ship_roles, :logistics) -> :sustained_engagement
      Enum.count(ship_roles, &(&1 == :tackle)) > 3 -> :control_doctrine
      true -> :mixed_doctrine
    end
  end

  defp calculate_damage_coordination(events) do
    # Simplified coordination calculation
    if length(events) < 2 do
      0.0
    else
      time_gaps =
        events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, curr] ->
          DateTimeUtils.diff(curr.timestamp, prev.timestamp, :second)
        end)

      avg_gap = average(time_gaps)
      # Better coordination with smaller time gaps
      max(0.0, 1.0 - avg_gap / 30.0)
    end
  end

  # Additional utility functions for timing and formation analysis

  defp calculate_initiation_speed(early_events) do
    if length(early_events) < 2 do
      0
    else
      first_event = hd(early_events)
      last_early = List.last(early_events)
      time_diff = DateTimeUtils.diff(last_early.timestamp, first_event.timestamp, :second)
      # Speed = events per minute
      (length(early_events) / max(time_diff / 60.0, 1.0)) |> round()
    end
  end

  defp calculate_intensity_buildup(events) do
    if length(events) < 2 do
      0.0
    else
      # Calculate escalation rate based on increasing event frequency
      intervals = calculate_event_intervals(events)

      if Enum.empty?(intervals) do
        0.0
      else
        # Escalation rate = change in frequency over time
        first_interval = hd(intervals)
        last_interval = List.last(intervals)
        (first_interval - last_interval) / max(first_interval, 1.0)
      end
    end
  end

  defp calculate_timing_gaps(events) do
    events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      DateTimeUtils.diff(curr.timestamp, prev.timestamp, :second)
    end)
  end

  defp identify_coordination_windows(events) do
    # Identify periods of coordinated activity
    events
    |> Enum.chunk_by(fn event ->
      # Group by minute
      # Group by minute
      timestamp_seconds = event.timestamp |> DateTimeUtils.to_datetime() |> DateTime.to_unix()

      event.timestamp
      |> NaiveDateTime.truncate(:second)
      |> DateTimeUtils.add(-rem(timestamp_seconds, 60), :second)
    end)
    |> Enum.filter(fn window -> length(window) > 1 end)
    |> Enum.map(fn window ->
      %{
        start_time: hd(window).timestamp,
        end_time: List.last(window).timestamp,
        events: length(window),
        coordination_level: calculate_window_coordination(window)
      }
    end)
  end

  defp calculate_synchronization_score(timing_gaps) do
    if Enum.empty?(timing_gaps) do
      0.0
    else
      # Better synchronization with smaller, more consistent gaps
      avg_gap = average(timing_gaps)
      gap_variance = calculate_variance(timing_gaps)

      # Score inversely related to gap size and variance
      base_score = max(0.0, 1.0 - avg_gap / 30.0)
      consistency_bonus = max(0.0, 1.0 - gap_variance / 100.0)

      (base_score + consistency_bonus) / 2
    end
  end

  defp identify_alpha_strikes(events) do
    # Identify coordinated burst attacks
    events
    |> Enum.chunk_by(fn event ->
      # Group by 10-second windows
      # Group by 10-second windows
      timestamp_seconds = event.timestamp |> DateTimeUtils.to_datetime() |> DateTime.to_unix()

      event.timestamp
      |> NaiveDateTime.truncate(:second)
      |> DateTimeUtils.add(-rem(timestamp_seconds, 10), :second)
    end)
    # At least 3 kills in 10 seconds
    |> Enum.filter(fn window -> length(window) >= 3 end)
    |> Enum.map(fn window ->
      %{
        start_time: hd(window).timestamp,
        end_time: List.last(window).timestamp,
        kills: length(window),
        total_value: Enum.sum(Enum.map(window, & &1.total_value)),
        coordination: calculate_window_coordination(window)
      }
    end)
  end

  defp calculate_average_alpha_quality(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      qualities = Enum.map(alpha_strikes, & &1.coordination)
      average(qualities)
    end
  end

  defp calculate_alpha_timing_precision(alpha_strikes) do
    if Enum.empty?(alpha_strikes) do
      0.0
    else
      # Precision based on tight timing windows
      durations =
        alpha_strikes
        |> Enum.map(fn strike ->
          DateTimeUtils.diff(strike.end_time, strike.start_time, :second)
        end)

      avg_duration = average(durations)
      # Better precision with shorter durations
      max(0.0, 1.0 - avg_duration / 30.0)
    end
  end

  defp calculate_event_intervals(events) do
    events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      DateTimeUtils.diff(curr.timestamp, prev.timestamp, :second)
    end)
  end

  defp identify_tempo_changes(intervals) do
    if length(intervals) < 3 do
      []
    else
      # Identify significant changes in tempo
      intervals
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.with_index()
      |> Enum.filter(fn {[prev, curr], _index} ->
        # Significant change threshold
        abs(curr - prev) > 10
      end)
      |> Enum.map(fn {[prev, curr], index} ->
        %{
          position: index,
          change: curr - prev,
          change_type: if(curr > prev, do: :deceleration, else: :acceleration)
        }
      end)
    end
  end

  defp calculate_average_tempo(intervals) do
    if Enum.empty?(intervals) do
      0.0
    else
      avg_interval = average(intervals)
      # Tempo = kills per minute (inverse of average interval)
      60.0 / max(avg_interval, 1.0)
    end
  end

  defp calculate_tempo_consistency(intervals) do
    if Enum.empty?(intervals) do
      0.0
    else
      variance = calculate_variance(intervals)
      mean = average(intervals)
      # Higher consistency with lower variance
      max(0.0, 1.0 - variance / (mean * mean + 1))
    end
  end

  defp analyze_ship_distribution(participants) do
    participants
    |> Enum.group_by(&determine_ship_role(&1[:ship_type_id]))
    |> Enum.map(fn {role, ships} ->
      {role, length(ships)}
    end)
    |> Map.new()
  end

  defp infer_formation_type(ship_distribution) do
    total_ships = ship_distribution |> Map.values() |> Enum.sum()

    cond do
      Map.get(ship_distribution, :logistics, 0) > 0 and total_ships > 10 -> :ball_formation
      Map.get(ship_distribution, :tackle, 0) > total_ships * 0.4 -> :spread_formation
      Map.get(ship_distribution, :dps, 0) > total_ships * 0.7 -> :alpha_formation
      true -> :mixed_formation
    end
  end

  defp calculate_formation_cohesion(timeline, _participants) do
    # Simplified cohesion based on coordination timing
    if Enum.empty?(timeline.events) do
      0.0
    else
      timing_gaps = calculate_timing_gaps(timeline.events)
      calculate_synchronization_score(timing_gaps)
    end
  end

  defp extract_early_participants(timeline, participants) do
    if Enum.empty?(timeline.events) do
      []
    else
      # Get participants from first 25% of timeline
      early_cutoff =
        hd(timeline.events).timestamp
        |> DateTimeUtils.add(div(calculate_timeline_duration(timeline.events), 4), :second)

      early_events =
        Enum.filter(timeline.events, &(DateTimeUtils.compare(&1.timestamp, early_cutoff) != :gt))

      early_character_ids =
        early_events
        |> Enum.flat_map(&extract_attackers/1)
        |> Enum.map(& &1["character_id"])
        |> Enum.uniq()

      Enum.filter(participants, &(&1.character_id in early_character_ids))
    end
  end

  defp extract_segment_participants(segment, participants) do
    segment_character_ids =
      segment
      |> Enum.flat_map(&extract_attackers/1)
      |> Enum.map(& &1["character_id"])
      |> Enum.uniq()

    Enum.filter(participants, &(&1.character_id in segment_character_ids))
  end

  defp determine_segment_formation(segment_participants) do
    ship_distribution = analyze_ship_distribution(segment_participants)
    infer_formation_type(ship_distribution)
  end

  defp group_events_by_intensity(events) do
    # Group events by temporal intensity
    if length(events) < 5 do
      [events]
    else
      # Calculate rolling intensity
      events
      |> Enum.chunk_every(5, 2, :discard)
      |> Enum.group_by(&calculate_chunk_intensity/1)
      |> Map.values()
      |> Enum.flat_map(& &1)
      |> Enum.chunk_by(&calculate_event_intensity/1)
    end
  end

  defp determine_phase_type(events, index) do
    intensity = calculate_phase_intensity(events)

    cond do
      index == 0 -> :opening
      intensity > 0.8 -> :climax
      intensity > 0.5 -> :escalation
      intensity > 0.2 -> :engagement
      true -> :resolution
    end
  end

  defp calculate_phase_duration(events) do
    if length(events) < 2 do
      0
    else
      first_event = hd(events)
      last_event = List.last(events)
      DateTimeUtils.diff(last_event.timestamp, first_event.timestamp, :second)
    end
  end

  defp calculate_phase_intensity(events) do
    # Intensity based on kill frequency and value
    if Enum.empty?(events) do
      0.0
    else
      duration = calculate_phase_duration(events)
      # kills per minute
      kill_rate = length(events) / max(duration / 60.0, 1.0)
      avg_value = average(Enum.map(events, & &1.total_value))

      # Normalize to 0-1 scale
      rate_score = min(1.0, kill_rate / 10.0)
      # 100M ISK as reference
      value_score = min(1.0, avg_value / 100_000_000)

      (rate_score + value_score) / 2
    end
  end

  defp calculate_phase_effectiveness(phase, _timeline) do
    # Simplified effectiveness calculation
    # 5 minutes as reference
    phase.intensity * min(1.0, phase.duration / 300.0)
  end

  # Tactical assessment functions

  defp identify_tactical_strengths(
         fleet_analysis,
         target_analysis,
         timing_analysis,
         formation_analysis
       ) do
    base_strengths = []

    # Fleet effectiveness strengths
    fleet_strengths =
      if fleet_analysis.role_balance.score > 0.7 do
        ["Strong role balance and fleet composition" | base_strengths]
      else
        base_strengths
      end

    # Target selection strengths
    target_strengths =
      if target_analysis.focus_fire.quality > 0.7 do
        ["Excellent focus fire coordination" | fleet_strengths]
      else
        fleet_strengths
      end

    # Timing strengths
    timing_strengths =
      if timing_analysis.coordination_timing.synchronization > 0.7 do
        ["Superior timing coordination" | target_strengths]
      else
        target_strengths
      end

    # Formation strengths
    final_strengths =
      if formation_analysis.effectiveness > 0.7 do
        ["Effective formation discipline" | timing_strengths]
      else
        timing_strengths
      end

    final_strengths
  end

  defp identify_tactical_weaknesses(
         fleet_analysis,
         target_analysis,
         timing_analysis,
         formation_analysis
       ) do
    base_weaknesses = []

    # Fleet weaknesses
    fleet_weaknesses =
      if fleet_analysis.role_balance.score < 0.4 do
        ["Poor role balance in fleet composition" | base_weaknesses]
      else
        base_weaknesses
      end

    # Target selection weaknesses
    target_weaknesses =
      if target_analysis.focus_fire.quality < 0.4 do
        ["Weak focus fire coordination" | fleet_weaknesses]
      else
        fleet_weaknesses
      end

    # Timing weaknesses
    timing_weaknesses =
      if timing_analysis.coordination_timing.synchronization < 0.4 do
        ["Poor timing coordination" | target_weaknesses]
      else
        target_weaknesses
      end

    # Formation weaknesses
    final_weaknesses =
      if formation_analysis.effectiveness < 0.4 do
        ["Ineffective formation discipline" | timing_weaknesses]
      else
        timing_weaknesses
      end

    final_weaknesses
  end

  defp generate_tactical_recommendations(strengths, weaknesses) do
    base_recommendations = []

    # Address weaknesses
    balance_recommendations =
      if "Poor role balance in fleet composition" in weaknesses do
        ["Add logistics and tackle support to improve fleet balance" | base_recommendations]
      else
        base_recommendations
      end

    focus_recommendations =
      if "Weak focus fire coordination" in weaknesses do
        ["Improve target calling and focus fire discipline" | balance_recommendations]
      else
        balance_recommendations
      end

    timing_recommendations =
      if "Poor timing coordination" in weaknesses do
        ["Practice coordinated engagement timing" | focus_recommendations]
      else
        focus_recommendations
      end

    # Leverage strengths
    leverage_recommendations =
      if "Excellent focus fire coordination" in strengths do
        ["Continue leveraging superior focus fire capability" | timing_recommendations]
      else
        timing_recommendations
      end

    final_recommendations =
      if "Superior timing coordination" in strengths do
        ["Use timing advantage for alpha strike tactics" | leverage_recommendations]
      else
        leverage_recommendations
      end

    final_recommendations
  end

  defp calculate_overall_tactical_assessment(
         fleet_analysis,
         target_analysis,
         timing_analysis,
         formation_analysis
       ) do
    scores = [
      fleet_analysis.role_balance.score,
      target_analysis.effectiveness.overall,
      timing_analysis.coordination_timing.synchronization,
      formation_analysis.effectiveness
    ]

    overall_score = average(scores)

    assessment =
      cond do
        overall_score > 0.8 -> :excellent
        overall_score > 0.6 -> :good
        overall_score > 0.4 -> :average
        overall_score > 0.2 -> :poor
        true -> :very_poor
      end

    %{score: overall_score, assessment: assessment}
  end

  defp calculate_overall_battle_score(_analysis_components) do
    # Extract key scores from each analysis component
    # This would be more sophisticated in a real implementation
    # Placeholder
    0.75
  end

  defp extract_key_battle_factors(_analysis_components) do
    [
      "Fleet composition effectiveness",
      "Target selection coordination",
      "Timing and tempo control",
      "Formation discipline"
    ]
  end

  defp determine_battle_outcome(_analysis_components) do
    # Determine battle outcome based on analysis
    # This would analyze ISK efficiency, casualties, objectives
    # Placeholder
    :decisive_victory
  end

  defp extract_lessons_learned(_analysis_components) do
    [
      "Focus fire coordination was crucial",
      "Early engagement timing determined outcome",
      "Fleet composition balanced roles effectively"
    ]
  end

  # Utility mathematical functions

  defp average(list), do: SharedUtilities.average(list)

  defp calculate_variance(list), do: SharedUtilities.calculate_variance(list)

  defp calculate_window_coordination(window) do
    if length(window) < 2 do
      0.0
    else
      timing_gaps = calculate_timing_gaps(window)
      calculate_synchronization_score(timing_gaps)
    end
  end

  defp calculate_chunk_intensity(chunk) do
    # Calculate intensity for event grouping
    if length(chunk) < 2 do
      0.0
    else
      duration = calculate_phase_duration(chunk)
      # kills per minute
      length(chunk) / max(duration / 60.0, 1.0)
    end
  end

  defp calculate_event_intensity(event) do
    # Individual event intensity based on value and context
    value_score = min(1.0, event.total_value / 100_000_000)
    attacker_count = length(extract_attackers(event))
    coordination_score = min(1.0, attacker_count / 20.0)

    (value_score + coordination_score) / 2
  end

  # Target selection analysis helpers

  defp analyze_target_prioritization(target_order, _timeline) do
    if Enum.empty?(target_order) do
      %{consistency: 0.0, high_value_focus: 0.0}
    else
      # Analyze if high-value targets were prioritized
      high_value_targets = Enum.filter(target_order, &(&1.victim_ship in get_high_value_ships()))
      high_value_ratio = length(high_value_targets) / length(target_order)

      # Analyze prioritization consistency
      priority_consistency = calculate_priority_consistency(target_order)

      %{
        consistency: priority_consistency,
        high_value_focus: high_value_ratio,
        support_focus: calculate_support_target_ratio(target_order),
        dps_focus: calculate_dps_target_ratio(target_order)
      }
    end
  end

  defp analyze_focus_fire_patterns(focus_windows, timeline) do
    if Enum.empty?(focus_windows) do
      %{quality: 0.0, consistency: 0.0}
    else
      avg_quality = average(Enum.map(focus_windows, & &1.damage_coordination))
      consistency = calculate_focus_consistency(focus_windows, timeline)

      %{
        quality: avg_quality,
        consistency: consistency,
        windows: length(focus_windows),
        avg_duration: average(Enum.map(focus_windows, &calculate_window_duration/1))
      }
    end
  end

  defp analyze_target_switching_patterns(target_switches, timeline) do
    if Enum.empty?(target_switches) do
      %{switches: 0, switch_rate: 0.0}
    else
      timeline_duration = calculate_timeline_duration(timeline.events)
      # switches per minute
      switch_rate = length(target_switches) / max(timeline_duration / 60.0, 1.0)

      %{
        switches: length(target_switches),
        switch_rate: switch_rate,
        avg_switch_time: average(Enum.map(target_switches, & &1.time_gap)),
        rapid_switches: Enum.count(target_switches, &(&1.time_gap < 30))
      }
    end
  end

  defp evaluate_target_selection_effectiveness(timeline, _participants) do
    if Enum.empty?(timeline.events) do
      %{overall: 0.0, coordination: 0.0}
    else
      # Calculate effectiveness based on kill efficiency and coordination
      high_value_kills = Enum.count(timeline.events, &(&1.total_value > 50_000_000))
      total_kills = length(timeline.events)

      efficiency = if total_kills > 0, do: high_value_kills / total_kills, else: 0.0
      coordination = calculate_overall_coordination(timeline.events)

      %{
        overall: (efficiency + coordination) / 2,
        coordination: coordination,
        efficiency: efficiency,
        value_destroyed: Enum.sum(Enum.map(timeline.events, & &1.total_value))
      }
    end
  end

  defp get_high_value_ships do
    # This would use real EVE static data
    # Capital ships and expensive hull types
    # Example ship type IDs
    [23_757, 23_919, 24_483]
  end

  defp calculate_priority_consistency(target_order) do
    # Simplified consistency calculation
    if length(target_order) < 2 do
      0.0
    else
      # Check if similar ship types were targeted in sequence
      ship_sequence = Enum.map(target_order, & &1.victim_ship)
      transitions = Enum.chunk_every(ship_sequence, 2, 1, :discard)

      consistent_transitions =
        Enum.count(transitions, fn [prev, curr] -> similar_ship_types?(prev, curr) end)

      consistent_transitions / length(transitions)
    end
  end

  defp calculate_support_target_ratio(target_order) do
    support_ships = get_support_ships()
    support_targets = Enum.count(target_order, &(&1.victim_ship in support_ships))
    support_targets / length(target_order)
  end

  defp calculate_dps_target_ratio(target_order) do
    dps_ships = get_dps_ships()
    dps_targets = Enum.count(target_order, &(&1.victim_ship in dps_ships))
    dps_targets / length(target_order)
  end

  defp calculate_focus_consistency(focus_windows, timeline) do
    if Enum.empty?(focus_windows) do
      0.0
    else
      total_timeline = calculate_timeline_duration(timeline.events)
      focus_time = Enum.sum(Enum.map(focus_windows, &calculate_window_duration/1))

      focus_time / max(total_timeline, 1)
    end
  end

  defp calculate_window_duration(window) do
    DateTimeUtils.diff(window.end_time, window.start_time, :second)
  end

  defp calculate_overall_coordination(events) do
    if length(events) < 2 do
      0.0
    else
      timing_gaps = calculate_timing_gaps(events)
      calculate_synchronization_score(timing_gaps)
    end
  end

  defp similar_ship_types?(ship1, ship2) do
    classify_ship_type(ship1) == classify_ship_type(ship2)
  end

  defp get_support_ships do
    # This would use real EVE static data
    # Example logistics ship type IDs
    [11_985, 11_987, 11_989]
  end

  defp get_dps_ships do
    # This would use real EVE static data
    # Example DPS ship type IDs
    [24_696, 24_698, 24_700]
  end

  # Fleet effectiveness functions

  @doc """
  Estimates fleet effectiveness based on composition and ship capabilities.
  """
  def estimate_fleet_effectiveness(participants) do
    if Enum.empty?(participants) do
      %{overall: 0.0, dps_rating: 0.0, tank_rating: 0.0, mobility_rating: 0.0}
    else
      # Calculate fleet composition metrics
      dps_rating = calculate_fleet_dps_rating(participants)
      tank_rating = calculate_fleet_tank_rating(participants)
      mobility_rating = calculate_fleet_mobility_rating(participants)
      role_coverage = calculate_role_coverage(participants)

      overall = (dps_rating + tank_rating + mobility_rating + role_coverage) / 4.0

      %{
        overall: overall,
        dps_rating: dps_rating,
        tank_rating: tank_rating,
        mobility_rating: mobility_rating,
        role_coverage: role_coverage
      }
    end
  end

  @doc """
  Calculates fleet synergy based on ship combinations and doctrine adherence.
  """
  def calculate_fleet_synergy(participants) do
    if Enum.empty?(participants) do
      %{overall: 0.0, ship_synergy: 0.0, role_balance: 0.0, doctrine_coherence: 0.0}
    else
      ship_synergy = calculate_ship_synergy(participants)
      role_balance = calculate_role_balance(participants)
      doctrine_coherence = calculate_doctrine_coherence(participants)

      overall = (ship_synergy + role_balance.score + doctrine_coherence) / 3.0

      %{
        overall: overall,
        ship_synergy: ship_synergy,
        role_balance: role_balance,
        doctrine_coherence: doctrine_coherence
      }
    end
  end

  @doc """
  Analyzes composition balance looking for over/under representation of roles.
  """
  def analyze_composition_balance(role_distribution) do
    if Enum.empty?(role_distribution) do
      %{balance_score: 0.0, imbalances: [], recommendations: []}
    else
      total_ships = Enum.sum(Map.values(role_distribution))

      # Calculate ideal percentages for different roles
      ideal_ratios = %{
        dps: 0.6,
        tank: 0.15,
        support: 0.15,
        tackle: 0.1
      }

      imbalances =
        ideal_ratios
        |> Enum.map(fn {role, ideal_ratio} ->
          actual_count = Map.get(role_distribution, role, 0)
          actual_ratio = actual_count / total_ships
          deviation = abs(actual_ratio - ideal_ratio)
          {role, deviation}
        end)
        |> Enum.filter(fn {_role, deviation} -> deviation > 0.1 end)

      balance_score =
        1.0 - Enum.sum(Enum.map(imbalances, fn {_role, dev} -> dev end)) / map_size(ideal_ratios)

      %{
        balance_score: max(balance_score, 0.0),
        imbalances: imbalances,
        recommendations: generate_balance_recommendations(imbalances)
      }
    end
  end

  @doc """
  Calculates overall fleet strength as a single metric.
  """
  def calculate_fleet_strength(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      effectiveness = estimate_fleet_effectiveness(participants)
      synergy = calculate_fleet_synergy(participants)
      # Cap at 2x for large fleets
      fleet_size_factor = min(length(participants) / 50.0, 2.0)

      base_strength = (effectiveness.overall + synergy.overall) / 2.0
      base_strength * fleet_size_factor
    end
  end

  @doc """
  Calculates doctrine adherence for a fleet composition.
  """
  def calculate_doctrine_adherence(participants) do
    if Enum.empty?(participants) do
      %{score: 0.0, adherence_level: :none, doctrine_type: :unknown}
    else
      # Simplified doctrine analysis - could be enhanced with actual doctrine definitions
      ship_types = Enum.map(participants, & &1.ship_type_id)
      unique_ships = Enum.uniq(ship_types)
      ship_diversity = length(unique_ships) / length(participants)

      # Lower diversity suggests better doctrine adherence
      adherence_score = 1.0 - ship_diversity

      adherence_level =
        cond do
          adherence_score >= 0.8 -> :excellent
          adherence_score >= 0.6 -> :good
          adherence_score >= 0.4 -> :moderate
          adherence_score >= 0.2 -> :poor
          true -> :none
        end

      %{
        score: adherence_score,
        adherence_level: adherence_level,
        # Could be enhanced to detect specific doctrines
        doctrine_type: :mixed,
        ship_diversity: ship_diversity
      }
    end
  end

  @doc """
  Calculates survival rate for ships in combat.
  """
  def calculate_survival_rate(ships, killmails) do
    if Enum.empty?(ships) do
      0.0
    else
      ship_character_ids = Enum.map(ships, & &1.character_id)
      killed_character_ids = Enum.map(killmails, & &1.victim_character_id)

      killed_ships = Enum.count(ship_character_ids, &(&1 in killed_character_ids))
      survival_rate = (length(ships) - killed_ships) / length(ships)

      max(survival_rate, 0.0)
    end
  end

  # Helper functions for fleet effectiveness calculations

  defp calculate_fleet_dps_rating(participants) do
    # Simplified DPS calculation based on ship types
    dps_ships = get_dps_ships()
    dps_count = Enum.count(participants, &(&1.ship_type_id in dps_ships))
    dps_count / length(participants)
  end

  defp calculate_fleet_tank_rating(participants) do
    # Simplified tank calculation based on ship types
    tank_ships = get_tank_ships()
    tank_count = Enum.count(participants, &(&1.ship_type_id in tank_ships))
    tank_count / length(participants)
  end

  defp calculate_fleet_mobility_rating(participants) do
    # Simplified mobility calculation
    fast_ships = get_fast_ships()
    fast_count = Enum.count(participants, &(&1.ship_type_id in fast_ships))
    fast_count / length(participants)
  end

  defp calculate_role_coverage(participants) do
    # Calculate how well different roles are covered
    roles = [:dps, :tank, :support, :tackle]
    covered_roles = Enum.count(roles, &role_is_covered?(participants, &1))
    covered_roles / length(roles)
  end

  defp calculate_ship_synergy(_participants) do
    # Simplified synergy calculation based on ship combinations
    # This could be enhanced with actual EVE ship synergy data
    0.7
  end

  defp generate_balance_recommendations(imbalances) do
    Enum.map(imbalances, fn {role, deviation} ->
      cond do
        deviation > 0.2 -> "Consider rebalancing #{role} representation"
        deviation > 0.1 -> "Minor #{role} imbalance detected"
        true -> "#{role} balance is acceptable"
      end
    end)
  end

  defp get_tank_ships do
    # This would use real EVE static data
    # Example tank ship type IDs
    [11_978, 11_980, 11_982]
  end

  defp get_fast_ships do
    # This would use real EVE static data
    # Example fast ship type IDs
    [11_176, 11_178, 11_180]
  end

  defp role_is_covered?(participants, role) do
    case role do
      :dps -> Enum.any?(participants, &dps_ship?/1)
      :tank -> Enum.any?(participants, &tank_ship?/1)
      :support -> Enum.any?(participants, &support_ship?/1)
      :tackle -> Enum.any?(participants, &tackle_ship?/1)
      _ -> false
    end
  end

  defp dps_ship?(participant), do: participant.ship_type_id in get_dps_ships()
  defp tank_ship?(participant), do: participant.ship_type_id in get_tank_ships()
  defp support_ship?(participant), do: participant.ship_type_id in get_support_ships()
  defp tackle_ship?(participant), do: participant.ship_type_id in get_fast_ships()
end
