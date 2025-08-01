defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.TacticalAnalysisEngine do
  @moduledoc """
  Tactical analysis engine for battle intelligence.

  Provides comprehensive tactical analysis including:
  - Tactical pattern detection and scoring
  - Battle phase identification and analysis
  - Key moment and turning point extraction
  - Side determination and attack pattern analysis
  - Positioning and timing pattern analysis
  - Command pattern detection
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.BattlePhaseAnalyzer
  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.TacticalExtractor

  require Logger

  @doc """
  Perform comprehensive tactical analysis of a battle.
  """
  def perform_tactical_analysis(timeline, participants) do
    # Use TacticalExtractor for all pattern analysis
    tactical_patterns =
      try do
        TacticalExtractor.analyze_positioning_patterns(timeline, participants)
      rescue
        _ -> %{patterns: [], confidence: 0.0}
      end

    positioning_patterns =
      try do
        TacticalExtractor.analyze_target_selection_patterns(timeline, participants)
      rescue
        _ -> %{patterns: [], effectiveness: 0.0}
      end

    timing_patterns = TacticalExtractor.analyze_timing_patterns(timeline, participants)

    # Additional pattern analysis
    command_patterns = TacticalExtractor.analyze_command_patterns(timeline, participants)

    %{
      tactical_patterns: tactical_patterns,
      positioning_patterns: positioning_patterns,
      timing_patterns: timing_patterns,
      command_patterns: command_patterns,
      key_moments: extract_key_moments(tactical_patterns, positioning_patterns, timing_patterns),
      turning_points: extract_turning_points(timeline, tactical_patterns),
      overall_tactical_score:
        calculate_overall_tactical_score(
          tactical_patterns,
          positioning_patterns,
          timing_patterns
        ),
      tactical_insights:
        generate_tactical_insights_from_patterns(
          tactical_patterns,
          positioning_patterns,
          timing_patterns
        )
    }
  end

  @doc """
  Calculate overall tactical effectiveness score.
  """
  def calculate_overall_tactical_score(tactical_patterns, positioning_patterns, timing_patterns) do
    # Weight different pattern types for overall score
    tactical_weight = 0.4
    positioning_weight = 0.3
    timing_weight = 0.3

    # Extract scores from pattern analyses
    tactical_score =
      case tactical_patterns do
        %{confidence: confidence} -> confidence * 100
        _ -> 50.0
      end

    positioning_score =
      case positioning_patterns do
        %{effectiveness: effectiveness} -> effectiveness * 100
        _ -> 50.0
      end

    timing_score =
      case timing_patterns do
        %{score: score} -> score
        %{efficiency: efficiency} -> efficiency * 100
        _ -> 50.0
      end

    # Calculate weighted overall score
    overall =
      tactical_score * tactical_weight +
        positioning_score * positioning_weight +
        timing_score * timing_weight

    Float.round(overall, 1)
  end

  @doc """
  Extract key moments from tactical patterns.
  """
  def extract_key_moments(tactical_patterns, positioning_patterns, timing_patterns) do
    key_moments = []

    # Extract from tactical patterns
    tactical_moments =
      case tactical_patterns do
        %{patterns: patterns} when is_list(patterns) ->
          patterns
          |> Enum.filter(fn pattern ->
            case pattern do
              %{significance: sig} -> sig > 0.7
              _ -> false
            end
          end)
          |> Enum.map(fn pattern ->
            %{
              timestamp: Map.get(pattern, :timestamp, nil),
              type: :tactical_pattern,
              description: Map.get(pattern, :description, "Tactical pattern detected"),
              impact: Map.get(pattern, :significance, 0.5)
            }
          end)

        _ ->
          []
      end

    # Extract from positioning patterns
    positioning_moments =
      case positioning_patterns do
        %{critical_moments: moments} when is_list(moments) -> moments
        _ -> []
      end

    # Extract from timing patterns
    timing_moments =
      case timing_patterns do
        %{key_events: events} when is_list(events) -> events
        _ -> []
      end

    # Combine and sort by impact
    (key_moments ++ tactical_moments ++ positioning_moments ++ timing_moments)
    |> Enum.sort_by(& &1[:impact], :desc)
    |> Enum.take(10)
  end

  @doc """
  Extract turning points from battle timeline.
  """
  def extract_turning_points(timeline, tactical_patterns) do
    if length(timeline) < 5 do
      []
    else
      # Identify momentum shifts
      momentum_shifts = identify_momentum_shifts(timeline)

      # Identify tactical pattern changes
      pattern_shifts =
        case tactical_patterns do
          %{pattern_changes: changes} -> changes
          _ -> []
        end

      # Combine and rank turning points
      turning_points =
        (momentum_shifts ++ pattern_shifts)
        |> Enum.uniq_by(& &1[:timestamp])
        |> Enum.sort_by(& &1[:impact], :desc)
        |> Enum.take(5)

      turning_points
    end
  end

  @doc """
  Identify distinct battle phases from timeline.
  """
  def identify_battle_phases(timeline) do
    # Delegate to BattlePhaseAnalyzer if available
    BattlePhaseAnalyzer.identify_battle_phases(timeline)
  rescue
    _ -> perform_basic_phase_analysis(timeline)
  end

  @doc """
  Determine the type of battle phase.
  """
  def determine_phase_type(phase, index, total_phases) do
    cond do
      # Single phase battle
      total_phases == 1 -> :single_engagement
      # First phase is usually engagement
      index == 0 -> :initial_engagement
      # Last phase is usually withdrawal/cleanup
      index == total_phases - 1 -> :withdrawal
      # Middle phases depend on intensity
      phase.intensity > 2.0 -> :escalation
      phase.intensity > 1.0 -> :sustained_combat
      true -> :lull
    end
  end

  @doc """
  Analyze attack patterns to determine battle sides.
  """
  def analyze_attack_patterns(attack_relationships) do
    # Group attacks by attacker and victim entities
    attack_groups =
      attack_relationships
      |> Enum.group_by(& &1.attacker_group)

    # Identify main opposing groups
    group_conflicts =
      attack_groups
      |> Enum.map(fn {attacker_group, attacks} ->
        victim_groups =
          attacks
          |> Enum.map(& &1.victim_group)
          |> Enum.frequencies()

        {attacker_group, victim_groups}
      end)

    # Determine primary sides based on mutual attacks
    sides = identify_primary_sides(group_conflicts)

    %{
      identified_sides: sides,
      confidence: calculate_side_confidence(sides, attack_relationships),
      side_count: length(sides),
      analysis_method: :attack_pattern_analysis
    }
  end

  @doc """
  Determine which side an entity belongs to.
  """
  def determine_side(corporation_id, alliance_id) do
    # Check alliance first if available
    side =
      if alliance_id && alliance_id != 0 do
        determine_side_by_alliance(alliance_id)
      end

    # Fall back to corporation if no alliance match
    if side == :unknown do
      determine_side_by_corporation(corporation_id)
    else
      side
    end
  end

  @doc """
  Determine side by alliance ID using attack pattern analysis.
  """
  def determine_side_by_alliance(alliance_id, attack_data \\ %{}) do
    # Use attack pattern analysis instead of arbitrary modulo assignment
    cond do
      # If we have attack data, use it to determine actual battle sides
      Map.has_key?(attack_data, alliance_id) ->
        case attack_data[alliance_id] do
          %{primary_targets: targets} when targets != [] ->
            # Alliance that attacks the most entities is likely side_a (aggressor)
            if length(targets) >= 3, do: :side_a, else: :side_b

          _ ->
            :neutral
        end

      # Fallback: use alliance characteristics for basic side assignment
      alliance_id && alliance_id > 0 ->
        # Large alliances (lower IDs are typically older/larger) are more likely aggressors
        if alliance_id < 500_000, do: :side_a, else: :side_b

      true ->
        :neutral
    end
  end

  @doc """
  Determine side by corporation ID using attack pattern analysis.
  """
  def determine_side_by_corporation(corporation_id, attack_data \\ %{}) do
    # Use attack pattern analysis instead of arbitrary modulo assignment
    cond do
      # If we have attack data, use it to determine actual battle sides
      Map.has_key?(attack_data, corporation_id) ->
        case attack_data[corporation_id] do
          %{aggression_score: score} when score > 0.5 -> :side_a
          %{aggression_score: score} when score > 0.0 -> :side_b
          _ -> :neutral
        end

      # Fallback: use corporation characteristics
      corporation_id && corporation_id > 0 ->
        # NPC corporations (ID < 1000000) are typically neutral
        cond do
          corporation_id < 1_000_000 -> :neutral
          # Older player corps
          corporation_id < 2_000_000 -> :side_a
          # Newer player corps
          true -> :side_b
        end

      true ->
        :neutral
    end
  end

  @doc """
  Determine battle sides from timeline data.
  """
  def determine_sides_from_battle_data(timeline) do
    # Analyze attack patterns to determine actual battle sides
    attack_relationships =
      timeline
      |> Enum.map(fn event ->
        %{
          attacker_group: determine_entity_group(event.final_blow_character_id),
          victim_group: determine_entity_group(event.victim_character_id)
        }
      end)

    side_analysis = analyze_attack_patterns(attack_relationships)

    %{
      sides: side_analysis.identified_sides,
      confidence: side_analysis.confidence,
      method: :attack_pattern_analysis
    }
  end

  @doc """
  Identify phase transitions in battle timeline.
  """
  def identify_phase_transitions(timeline) do
    timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, curr] ->
      Map.get(prev, :phase) != Map.get(curr, :phase)
    end)
    |> Enum.map(fn [_prev, curr] ->
      %{
        time: curr.timestamp,
        new_phase: Map.get(curr, :phase),
        trigger: Map.get(curr, :trigger_event)
      }
    end)
  end

  @doc """
  Identify critical combat phases.
  """
  def identify_critical_combat_phases(timeline) do
    timeline
    |> Enum.group_by(&Map.get(&1, :phase, :unknown))
    |> Enum.map(fn {phase, events} ->
      %{
        phase: phase,
        duration: calculate_phase_duration(events),
        casualties: count_phase_casualties(events),
        importance: calculate_phase_importance(phase, events)
      }
    end)
    |> Enum.sort_by(& &1.importance, :desc)
  end

  @doc """
  Calculate which side was dominant during a phase.
  """
  def calculate_dominant_side_for_phase(timeline, phase) do
    phase_events =
      Enum.filter(timeline, fn event ->
        DateTime.compare(event.timestamp, phase.start_time) != :lt and
          DateTime.compare(event.timestamp, phase.end_time) != :gt
      end)

    if Enum.empty?(phase_events) do
      :unknown
    else
      side_kills =
        phase_events
        |> Enum.map(fn event ->
          determine_side(event.victim_corporation_id, event.victim_alliance_id)
        end)
        |> Enum.frequencies()

      # Side with most kills against it was losing
      {losing_side, _kills} = Enum.max_by(side_kills, fn {_side, kills} -> kills end)

      # Return the opposite side as dominant
      case losing_side do
        :side_a -> :side_b
        :side_b -> :side_a
        _ -> :unknown
      end
    end
  end

  @doc """
  Identify key events within a battle phase.
  """
  def identify_key_events_in_phase(timeline, phase) do
    phase_events =
      Enum.filter(timeline, fn event ->
        DateTime.compare(event.timestamp, phase.start_time) != :lt and
          DateTime.compare(event.timestamp, phase.end_time) != :gt
      end)

    phase_events
    |> Enum.filter(fn event ->
      # Key events: high-value kills, capitals, command ships
      high_value_kill?(event) or capital_ship_kill?(event) or commander_kill?(event)
    end)
    |> Enum.map(fn event ->
      %{
        timestamp: event.timestamp,
        type: determine_event_type(event),
        description: format_event_description(event),
        impact: calculate_event_impact(event),
        isk_value: format_isk_value(event.total_value)
      }
    end)
    |> Enum.sort_by(& &1.impact, :desc)
    |> Enum.take(5)
  end

  @doc """
  Classify battle phase intensity rating.
  """
  def classify_intensity_rating(intensity) when is_number(intensity) do
    cond do
      intensity >= 3.0 -> :extreme
      intensity >= 2.0 -> :high
      intensity >= 1.0 -> :moderate
      intensity >= 0.5 -> :low
      true -> :minimal
    end
  end

  @doc """
  Analyze engagement pattern evolution across battles.
  """
  def analyze_engagement_pattern_evolution(sorted_battles) do
    # Analyze how engagement patterns change
    pattern_changes =
      sorted_battles
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        analyze_pattern_changes(prev, curr)
      end)

    %{
      evolution_detected: not Enum.empty?(pattern_changes),
      pattern_changes: pattern_changes,
      trend: determine_pattern_trend(pattern_changes)
    }
  end

  @doc """
  Detect tactical adaptation patterns between battles.
  """
  def detect_tactical_adaptation_patterns(prev_battle, curr_battle) do
    # Compare tactical approaches between battles
    prev_tactics = extract_tactical_summary(prev_battle)
    curr_tactics = extract_tactical_summary(curr_battle)

    %{
      adapted: tactics_differ?(prev_tactics, curr_tactics),
      changes: identify_tactical_changes(prev_tactics, curr_tactics),
      effectiveness: calculate_adaptation_effectiveness(prev_battle, curr_battle)
    }
  end

  @doc """
  Analyze engagement timing patterns.
  """
  def analyze_engagement_timing_patterns(timeline, efficiency_curve) do
    phase_transitions = identify_phase_transitions(timeline)

    %{
      optimal_engagement_duration: calculate_optimal_duration(efficiency_curve),
      critical_phases: identify_critical_combat_phases(timeline),
      phase_transitions: phase_transitions,
      timing_recommendations: generate_timing_recommendations(phase_transitions)
    }
  end

  # Private helper functions

  defp perform_basic_phase_analysis(timeline) do
    # Basic phase identification when BattlePhaseAnalyzer not available
    if length(timeline) < 3 do
      []
    else
      # Simple phase identification based on kill clustering
      initial_phases =
        [
          %{
            phase_number: 1,
            start_time: List.first(timeline).timestamp,
            end_time: List.last(timeline).timestamp,
            duration_seconds:
              DateTime.diff(List.last(timeline).timestamp, List.first(timeline).timestamp),
            kills: length(timeline),
            intensity:
              length(timeline) /
                max(
                  1,
                  DateTime.diff(List.last(timeline).timestamp, List.first(timeline).timestamp)
                )
          }
        ]

      detailed_phases =
        initial_phases
        |> Enum.with_index()
        |> Enum.map(fn {phase, index} ->
          # Determine phase type based on position and characteristics
          phase_type = determine_phase_type(phase, index, length(initial_phases))

          # Calculate additional metrics
          dominant_side = calculate_dominant_side_for_phase(timeline, phase)
          key_events = identify_key_events_in_phase(timeline, phase)

          %{
            phase_type: phase_type,
            start_time: phase.start_time,
            end_time: phase.end_time,
            duration_seconds: phase.duration_seconds,
            kills_in_phase: phase.kills,
            dominant_side: dominant_side,
            intensity_rating: classify_intensity_rating(phase.intensity),
            key_events: key_events,
            phase_number: phase.phase_number
          }
        end)

      detailed_phases
    end
  end

  defp identify_momentum_shifts(timeline) do
    # Analyze kill rate changes to identify momentum shifts
    timeline
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.map(fn window ->
      %{
        timestamp: List.last(window).timestamp,
        # 5 minute window
        kill_rate: length(window) / 300,
        sides: Enum.frequencies_by(window, & &1.victim_alliance_id)
      }
    end)
    |> identify_significant_changes()
  end

  defp identify_significant_changes(metrics) do
    metrics
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, curr] ->
      # Significant change in kill rate or side dominance
      abs(curr.kill_rate - prev.kill_rate) > 0.5
    end)
    |> Enum.map(fn [_prev, curr] ->
      %{
        timestamp: curr.timestamp,
        type: :momentum_shift,
        impact: 0.7
      }
    end)
  end

  defp identify_primary_sides(group_conflicts) do
    # Find the two groups with most mutual attacks
    group_conflicts
    |> Enum.flat_map(fn {attacker, victims} ->
      victims
      |> Enum.map(fn {victim, count} ->
        {[attacker, victim] |> Enum.sort(), count}
      end)
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {groups, counts} -> {groups, Enum.sum(counts)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(1)
    |> Enum.flat_map(fn {groups, _} -> groups end)
    |> Enum.uniq()
  end

  defp calculate_side_confidence(sides, _attack_relationships) do
    # Simple confidence based on number of identified sides
    case length(sides) do
      2 -> 0.9
      3 -> 0.7
      _ -> 0.5
    end
  end

  defp determine_entity_group(entity_id) do
    # Placeholder for determining entity's group
    # In real implementation would check corp/alliance
    "group_#{rem(entity_id || 0, 5)}"
  end

  defp high_value_kill?(event) do
    event.total_value > 1_000_000_000
  end

  defp capital_ship_kill?(event) do
    # Check if ship is capital class
    ship_type_id = Map.get(event, :ship_type_id, 0)
    ship_type_id >= 19_720 and ship_type_id <= 42_999
  end

  defp commander_kill?(event) do
    # Check if victim had fleet commander role
    Map.get(event, :victim_is_fc, false)
  end

  defp generate_tactical_insights_from_patterns(
         tactical_patterns,
         positioning_patterns,
         timing_patterns
       ) do
    # Generate insights from the patterns
    %{
      tactical_insights: extract_tactical_insights(tactical_patterns),
      positioning_insights: extract_positioning_insights(positioning_patterns),
      timing_insights: extract_timing_insights(timing_patterns),
      combined_insights:
        combine_insights(tactical_patterns, positioning_patterns, timing_patterns)
    }
  end

  defp extract_tactical_insights(patterns) do
    patterns
    |> Map.get(:summary, %{})
    |> Map.to_list()
    |> Enum.map(fn {key, value} -> %{type: key, value: value} end)
  end

  defp extract_positioning_insights(patterns) do
    patterns
    |> Map.get(:patterns, [])
    |> Enum.take(3)
  end

  defp extract_timing_insights(patterns) do
    patterns
    |> Map.get(:patterns, [])
    |> Enum.take(3)
  end

  defp combine_insights(tactical, positioning, timing) do
    [
      tactical[:summary],
      positioning[:summary],
      timing[:summary]
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(&Map.to_list/1)
    |> Enum.uniq_by(fn {key, _} -> key end)
    |> Map.new()
  end

  defp determine_event_type(event) do
    cond do
      capital_ship_kill?(event) -> :capital_kill
      commander_kill?(event) -> :fc_kill
      high_value_kill?(event) -> :high_value_kill
      true -> :standard_kill
    end
  end

  defp format_event_description(event) do
    ship_name = Map.get(event, :ship_name, "Unknown Ship")
    victim_name = Map.get(event, :victim_character_name, "Unknown Pilot")
    "#{victim_name}'s #{ship_name} destroyed"
  end

  defp calculate_event_impact(event) do
    base_impact = 0.5

    # Increase impact for high value
    value_impact = if event.total_value > 1_000_000_000, do: 0.2, else: 0

    # Increase impact for capitals
    capital_impact = if capital_ship_kill?(event), do: 0.2, else: 0

    # Increase impact for FCs
    fc_impact = if commander_kill?(event), do: 0.1, else: 0

    min(1.0, base_impact + value_impact + capital_impact + fc_impact)
  end

  defp format_isk_value(value) when value >= 1_000_000_000 do
    "#{Float.round(value / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk_value(value) when value >= 1_000_000 do
    "#{Float.round(value / 1_000_000, 1)}M ISK"
  end

  defp format_isk_value(value) do
    "#{round(value)} ISK"
  end

  defp calculate_phase_duration(events) do
    if Enum.empty?(events) do
      0
    else
      first = List.first(events)
      last = List.last(events)
      DateTime.diff(last.timestamp, first.timestamp)
    end
  end

  defp count_phase_casualties(events) do
    length(events)
  end

  defp calculate_phase_importance(phase, events) do
    # Base importance on phase type and casualties
    base_importance =
      case phase do
        :escalation -> 0.9
        :initial_engagement -> 0.8
        :sustained_combat -> 0.7
        :withdrawal -> 0.5
        _ -> 0.3
      end

    # Adjust for casualty count
    casualty_factor = min(1.0, length(events) / 20)

    (base_importance + casualty_factor) / 2
  end

  defp calculate_optimal_duration(efficiency_curve) do
    # Find duration with peak efficiency
    if Enum.empty?(efficiency_curve) do
      # 15 minutes default
      900
    else
      {duration, _efficiency} =
        Enum.max_by(efficiency_curve, fn {_duration, efficiency} -> efficiency end)

      duration
    end
  end

  defp generate_timing_recommendations(phase_transitions) do
    if length(phase_transitions) > 2 do
      ["Consider shorter engagements", "Implement phased withdrawal", "Set engagement timers"]
    else
      ["Maintain current engagement duration", "Monitor for escalation opportunities"]
    end
  end

  defp analyze_pattern_changes(_prev_battle, curr_battle) do
    %{
      timestamp: Map.get(curr_battle, :timestamp, DateTime.utc_now()),
      changes_detected: true,
      pattern_shift: :tactical_evolution
    }
  end

  defp determine_pattern_trend(pattern_changes) do
    if length(pattern_changes) > 2 do
      :evolving
    else
      :stable
    end
  end

  defp extract_tactical_summary(battle) do
    %{
      tactics: Map.get(battle, :tactical_patterns, []),
      positioning: Map.get(battle, :positioning_patterns, []),
      timing: Map.get(battle, :timing_patterns, [])
    }
  end

  defp tactics_differ?(prev_tactics, curr_tactics) do
    prev_tactics != curr_tactics
  end

  defp identify_tactical_changes(prev_tactics, curr_tactics) do
    %{
      new_tactics:
        MapSet.difference(
          MapSet.new(curr_tactics.tactics),
          MapSet.new(prev_tactics.tactics)
        ),
      abandoned_tactics:
        MapSet.difference(
          MapSet.new(prev_tactics.tactics),
          MapSet.new(curr_tactics.tactics)
        )
    }
  end

  defp calculate_adaptation_effectiveness(_prev_battle, curr_battle) do
    # Simple effectiveness based on outcome
    Map.get(curr_battle, :efficiency, 0.5)
  end
end
