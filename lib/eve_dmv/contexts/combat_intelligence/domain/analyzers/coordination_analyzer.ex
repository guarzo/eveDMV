defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.CoordinationAnalyzer do
  @moduledoc """
  Analyzer for fleet coordination patterns and teamwork effectiveness.

  Extracts and analyzes coordination-related functions from the tactical analysis system.
  """
  """

  require Logger

  @doc """
  Analyze coordination patterns from battle timeline and participant data.
  """
  def analyze_coordination_patterns(timeline, participants) do
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

  @doc """
  Assess overall coordination level from patterns.
  """
  def assess_coordination_level(coordination_patterns) do
    coordination_patterns[:coordination_level] || 0.0
  end

  @doc """
  Evaluate coordination effectiveness.
  """
  def evaluate_coordination_effectiveness(timeline, participants) do
    if Enum.empty?(timeline.events) do
      0.0
    else
      coordination_patterns = analyze_coordination_patterns(timeline, participants)

      # Coordination effectiveness factors
      level = coordination_patterns[:coordination_level] || 0.0
      focus_quality = coordination_patterns[:focus_fire_quality] || 0.0

      breakdown_penalty =
        calculate_breakdown_penalty(coordination_patterns[:coordination_breakdowns])

      # Calculate weighted effectiveness
      base_score = level * 0.5 + focus_quality * 0.5
      base_score * (1.0 - breakdown_penalty)
    end
  end

  @doc """
  Calculate coordination level from command patterns.
  """
  def calculate_coordination_level_from_command(timeline, participants) do
    calculate_coordination_level(timeline, participants)
  end

  # Private helper functions

  defp calculate_coordination_level(timeline, _participants) do
    # Calculate coordination from simultaneous actions and focus fire
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Analyze focus fire windows
      focus_windows = identify_focus_fire_windows(timeline)

      # Calculate timing synchronization
      timing_sync = calculate_timing_synchronization(timeline)

      # Calculate target selection consistency
      target_consistency = calculate_target_consistency(timeline)

      # Weighted average
      focus_score = (length(focus_windows) / (length(timeline.events) * 0.3)) |> min(1.0)

      focus_score * 0.4 + timing_sync * 0.3 + target_consistency * 0.3
    end
  end

  defp infer_coordination_methods(timeline, _participants) do
    # Infer coordination methods from patterns
    base_methods = []

    # Check for voice comms indicators (tight timing)
    voice_methods =
      if has_tight_timing_coordination?(timeline) do
        [:voice_comms | base_methods]
      else
        base_methods
      end

    # Check for FC-directed patterns
    fc_methods =
      if has_fc_directed_patterns?(timeline) do
        [:fleet_commander | voice_methods]
      else
        voice_methods
      end

    # Check for broadcast patterns
    final_methods =
      if has_broadcast_patterns?(timeline) do
        [:broadcasts | fc_methods]
      else
        fc_methods
      end

    if Enum.empty?(final_methods) do
      [:uncoordinated]
    else
      final_methods
    end
  end

  defp calculate_coordination_effectiveness(timeline, _participants) do
    # Calculate effectiveness based on outcomes
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Focus fire effectiveness
      focus_effectiveness = calculate_focus_fire_effectiveness(timeline)

      # Timing effectiveness
      timing_effectiveness = calculate_timing_effectiveness(timeline)

      # Target priority effectiveness
      priority_effectiveness = calculate_priority_effectiveness(timeline)

      # Weighted average
      focus_effectiveness * 0.5 + timing_effectiveness * 0.3 + priority_effectiveness * 0.2
    end
  end

  defp identify_coordination_breakdowns(timeline, _participants) do
    # Identify coordination failures
    base_breakdowns = []

    # Check for split damage
    split_damage_events = identify_split_damage(timeline)

    split_damage_breakdowns =
      base_breakdowns ++
        Enum.map(split_damage_events, fn event ->
          %{
            type: :split_damage,
            timestamp: event.timestamp,
            severity: :medium
          }
        end)

    # Check for mistimed attacks
    mistimed_attacks = identify_mistimed_attacks(timeline)

    final_breakdowns =
      split_damage_breakdowns ++
        Enum.map(mistimed_attacks, fn event ->
          %{
            type: :mistimed_attack,
            timestamp: event.timestamp,
            severity: :low
          }
        end)

    # Sort by timestamp
    Enum.sort_by(final_breakdowns, & &1.timestamp)
  end

  defp identify_coordination_improvements(_timeline, breakdowns) do
    # Analyze if coordination improved over time
    if length(breakdowns) < 2 do
      []
    else
      # Group breakdowns by time windows
      # 5-minute windows
      breakdown_windows =
        breakdowns
        |> Enum.group_by(fn b -> div(b.timestamp, 300) end)
        |> Enum.sort_by(fn {window, _} -> window end)

      # Look for decreasing breakdown frequency
      breakdown_windows
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [{_w1, b1}, {_w2, b2}] ->
        length(b2) < length(b1)
      end)
      |> Enum.map(fn [{w1, _}, {w2, _}] ->
        %{
          from_time: w1 * 300,
          to_time: w2 * 300,
          improvement_type: :reduced_breakdowns
        }
      end)
    end
  end

  defp analyze_focus_fire_quality(timeline) do
    # Analyze quality of focus fire
    if Enum.empty?(timeline.events) do
      0.0
    else
      focus_windows = identify_focus_fire_windows(timeline)

      if Enum.empty?(focus_windows) do
        0.0
      else
        # Calculate average focus quality
        total_quality =
          focus_windows
          |> Enum.map(& &1.quality)
          |> Enum.sum()

        total_quality / length(focus_windows)
      end
    end
  end

  defp identify_focus_fire_windows(timeline) do
    # Identify windows where multiple attackers hit same target
    timeline.events
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.filter(fn window ->
      # Check if same victim appears multiple times
      victims = Enum.map(window, & &1.victim_character_id)
      length(Enum.uniq(victims)) < length(victims)
    end)
    |> Enum.map(fn window ->
      %{
        timestamp: hd(window).timestamp,
        quality: calculate_window_focus_quality(window)
      }
    end)
  end

  defp calculate_timing_synchronization(timeline) do
    # Calculate how synchronized attacks are
    if length(timeline.events) < 2 do
      0.0
    else
      # Look at time gaps between kills
      gaps =
        timeline.events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, current] ->
          current.timestamp - prev.timestamp
        end)

      # Good synchronization = consistent small gaps
      avg_gap = Enum.sum(gaps) / length(gaps)

      cond do
        avg_gap < 30 ->
          # Very tight timing
          0.9

        avg_gap < 60 ->
          # Good timing
          0.7

        avg_gap < 120 ->
          # Moderate timing
          0.5

        true ->
          # Poor timing
          0.3
      end
    end
  end

  defp calculate_target_consistency(timeline) do
    # Calculate how consistent target selection is
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Group events by victim
      victim_groups = Enum.group_by(timeline.events, & &1.victim_character_id)

      # Good consistency = focusing down targets completely
      focused_kills =
        victim_groups
        |> Enum.count(fn {_victim, events} ->
          # Single event per victim = focused
          length(events) == 1
        end)

      focused_kills / map_size(victim_groups)
    end
  end

  defp has_tight_timing_coordination?(timeline) do
    # Check for very tight timing indicating voice comms
    if length(timeline.events) < 5 do
      false
    else
      # Look for clusters of kills within 10 seconds
      timeline.events
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.any?(fn [e1, _e2, e3] ->
        e3.timestamp - e1.timestamp < 10
      end)
    end
  end

  defp has_fc_directed_patterns?(timeline) do
    # Check for patterns indicating FC direction
    if length(timeline.events) < 10 do
      false
    else
      # Look for consistent target prioritization
      calculate_target_consistency(timeline) > 0.7
    end
  end

  defp has_broadcast_patterns?(timeline) do
    # Check for broadcast-style coordination
    focus_windows = identify_focus_fire_windows(timeline)
    length(focus_windows) > length(timeline.events) * 0.3
  end

  defp calculate_focus_fire_effectiveness(timeline) do
    focus_windows = identify_focus_fire_windows(timeline)

    if Enum.empty?(focus_windows) do
      # No focus fire is poor
      0.3
    else
      # Calculate average quality of focus fire windows
      analyze_focus_fire_quality(timeline)
    end
  end

  defp calculate_timing_effectiveness(timeline) do
    calculate_timing_synchronization(timeline)
  end

  defp calculate_priority_effectiveness(timeline) do
    # Analyze if high-value targets were prioritized
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Simplified - would analyze ship values and order
      0.7
    end
  end

  defp identify_split_damage(timeline) do
    # Identify events where damage was split inefficiently
    timeline.events
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.filter(fn window ->
      # Many different victims in short time = split damage
      victims = Enum.map(window, & &1.victim_character_id) |> Enum.uniq()
      time_span = List.last(window).timestamp - hd(window).timestamp

      length(victims) > 3 && time_span < 60
    end)
    |> Enum.map(fn window -> hd(window) end)
  end

  defp identify_mistimed_attacks(timeline) do
    # Identify attacks that were poorly timed
    timeline.events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [prev, current] ->
      # Large gap followed by failed kill attempt
      gap = current.timestamp - prev.timestamp
      gap > 180 && current.victim_character_id == prev.victim_character_id
    end)
    |> Enum.map(fn [_, current] -> current end)
  end

  defp calculate_window_focus_quality(window) do
    # Calculate quality of focus fire in this window
    victims = Enum.map(window, & &1.victim_character_id)
    victim_counts = Enum.frequencies(victims)

    # Quality based on concentration of fire
    max_count = victim_counts |> Map.values() |> Enum.max()
    max_count / length(window)
  end

  defp calculate_breakdown_penalty(breakdowns) do
    # Calculate penalty based on number and severity of breakdowns
    if Enum.empty?(breakdowns) do
      0.0
    else
      severity_scores = %{
        low: 0.1,
        medium: 0.2,
        high: 0.3
      }

      total_penalty =
        breakdowns
        |> Enum.map(fn b -> severity_scores[b.severity] || 0.1 end)
        |> Enum.sum()

      # Cap at 0.5 max penalty
      min(total_penalty, 0.5)
    end
  end
end
