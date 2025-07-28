defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.MovementAnalyzer do
  @moduledoc """
  Analyzer for fleet movement patterns and tactical positioning.

  Extracts and analyzes movement-related functions from the tactical analysis system.
  """

  require Logger

  @doc """
  Analyze movement patterns from battle timeline and participant data.
  """
  def analyze_movement_patterns(timeline, participants) do
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

  @doc """
  Evaluate movement effectiveness based on timeline and participants.
  """
  def evaluate_movement_effectiveness(timeline, participants) do
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

  # Private helper functions

  defp extract_movement_events(timeline) do
    # Extract movement patterns from kill locations and timing
    timeline.events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, current] ->
      %{
        from_event: prev.killmail_id,
        to_event: current.killmail_id,
        time_delta: current.timestamp - prev.timestamp,
        location_change: prev.solar_system_id != current.solar_system_id
      }
    end)
  end

  defp calculate_movement_coordination(movement_events, _participants) do
    # Calculate coordination based on synchronized movements
    if Enum.empty?(movement_events) do
      0.0
    else
      synchronized_movements =
        movement_events
        |> Enum.filter(& &1.location_change)
        |> Enum.filter(&(&1.time_delta < 120))
        |> length()

      (synchronized_movements / (length(movement_events) * 0.5)) |> min(1.0)
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
        event_id: event.to_event,
        type: :tactical_repositioning,
        time_delta: event.time_delta
      }
    end)
  end

  defp identify_escape_movements(movement_events, timeline) do
    # Identify escape/retreat movements
    movement_events
    |> Enum.filter(fn event ->
      # Look for rapid movements after losses
      recent_losses = count_recent_losses(timeline, event)
      event.time_delta < 180 && recent_losses > 0
    end)
  end

  defp identify_aggressive_movements(movement_events, timeline) do
    # Identify aggressive pursuit movements
    movement_events
    |> Enum.filter(fn event ->
      # Look for movements following successful kills
      recent_kills = count_recent_kills(timeline, event)
      event.time_delta < 180 && recent_kills > 0
    end)
  end

  defp calculate_movement_effectiveness(events, tactical, escape, aggressive) do
    if Enum.empty?(events) do
      0.0
    else
      # Score based on successful tactical movements
      tactical_score = length(tactical) * 0.4
      escape_score = length(escape) * 0.3
      aggressive_score = length(aggressive) * 0.3

      total_score = tactical_score + escape_score + aggressive_score
      max_score = length(events)

      if max_score > 0 do
        (total_score / max_score) |> min(1.0)
      else
        0.0
      end
    end
  end

  defp count_recent_losses(timeline, event) do
    # Count losses in the 2 minutes before this event
    window_start = event.from_event

    timeline.events
    |> Enum.filter(fn e ->
      e.timestamp >= window_start - 120 && e.timestamp < window_start
    end)
    |> Enum.filter(fn _e ->
      # Check if it's a loss for the moving side
      # Simplified logic - would need participant tracking
      true
    end)
    |> length()
  end

  defp count_recent_kills(timeline, event) do
    # Count kills in the 2 minutes before this event
    window_start = event.from_event

    timeline.events
    |> Enum.filter(fn e ->
      e.timestamp >= window_start - 120 && e.timestamp < window_start
    end)
    |> length()
  end

  defp evaluate_repositioning_success(movement_patterns) do
    # Evaluate success of tactical repositioning
    tactical_repositioning = movement_patterns[:tactical_repositioning] || []

    if Enum.empty?(tactical_repositioning) do
      # No repositioning data
      0.5
    else
      # Score based on successful repositioning
      successful_repositions =
        Enum.filter(tactical_repositioning, fn repositioning ->
          # Simplified success check
          repositioning[:time_delta] < 180
        end)

      length(successful_repositions) / length(tactical_repositioning)
    end
  end

  defp evaluate_escape_effectiveness(movement_patterns) do
    # Evaluate effectiveness of escape movements
    escape_movements = movement_patterns[:escape_movements] || []

    if Enum.empty?(escape_movements) do
      # No escape attempts suggests good positioning
      0.7
    else
      # Score based on successful escapes
      # Simplified - would analyze survival after escape
      0.5
    end
  end
end
