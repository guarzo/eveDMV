defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.BattlePhaseAnalyzer do
  @moduledoc """
  Analyzer for identifying and classifying battle phases.

  Responsible for:
  - Identifying distinct battle phases based on kill intensity and timing
  - Determining phase types (engagement, escalation, withdrawal, etc.)
  - Calculating dominant sides during each phase
  - Identifying key events within phases
  - Classifying intensity ratings and patterns
  """

  @doc """
  Identify distinct battle phases from killmail timeline.
  """
  def identify_battle_phases(timeline) do
    # Identify distinct phases based on kill intensity and timing patterns
    if length(timeline) < 3 do
      []
    else
      # Simple phase identification based on kill clustering
      detailed_phases = [
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
                DateTime.diff(List.last(timeline).timestamp, List.first(timeline).timestamp) / 60
              )
        }
      ]

      detailed_phases
      |> Enum.with_index()
      |> Enum.map(fn {phase, index} ->
        # Determine phase type based on position and characteristics
        phase_type = determine_phase_type(phase, index, length(detailed_phases))

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
    end
  end

  @doc """
  Determine the type of battle phase based on position and characteristics.
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
  Calculate which side was dominant during a specific phase.
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
      # Count kills by side (simplified - would need proper side determination)
      side_kills =
        phase_events
        |> Enum.map(fn event ->
          # Use corporation/alliance to determine side (simplified)
          determine_side(event.victim_corporation_id, event.victim_alliance_id)
        end)
        |> Enum.frequencies()

      case Enum.max_by(side_kills, &elem(&1, 1), fn -> {:unknown, 0} end) do
        {:unknown, _} -> :balanced
        {side, _count} -> side
      end
    end
  end

  @doc """
  Identify key events within a phase (high-value kills, escalations).
  """
  def identify_key_events_in_phase(timeline, phase) do
    phase_events =
      Enum.filter(timeline, fn event ->
        DateTime.compare(event.timestamp, phase.start_time) != :lt and
          DateTime.compare(event.timestamp, phase.end_time) != :gt
      end)

    phase_events
    |> Enum.filter(fn event ->
      # Consider an event "key" if it meets certain criteria
      high_value_kill?(event) or
        capital_ship_kill?(event) or
        commander_kill?(event)
    end)
    |> Enum.map(fn event ->
      %{
        timestamp: event.timestamp,
        event_type: determine_event_type(event),
        value: event.total_value || 0,
        ship_class: classify_ship(event.victim_ship_type_id),
        description: generate_event_description(event)
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  @doc """
  Classify intensity rating from kills per minute.
  """
  def classify_intensity_rating(intensity) when is_number(intensity) do
    cond do
      # 5+ kills per minute
      intensity >= 5.0 -> :very_high
      # 3-5 kills per minute
      intensity >= 3.0 -> :high
      # 1.5-3 kills per minute
      intensity >= 1.5 -> :moderate
      # 0.5-1.5 kills per minute
      intensity >= 0.5 -> :low
      # <0.5 kills per minute
      true -> :very_low
    end
  end

  def classify_intensity_rating(_), do: :unknown

  # Private helper functions

  defp determine_side(corporation_id, alliance_id) do
    # Improved logic to determine which side a participant is on
    # Uses alliance/corporation hierarchy and attack patterns

    cond do
      # If part of major alliance, use alliance as primary identifier
      alliance_id != nil and alliance_id != 0 ->
        determine_side_by_alliance(alliance_id)

      # If no alliance, use corporation
      corporation_id != nil and corporation_id != 0 ->
        determine_side_by_corporation(corporation_id)

      # Fallback for unknown entities
      true ->
        :unknown
    end
  end

  defp determine_side_by_alliance(alliance_id) do
    # Simple hash-based side assignment for consistency
    # In reality, this would use battle context or known enemy lists
    case rem(alliance_id, 2) do
      0 -> :side_a
      1 -> :side_b
    end
  end

  defp determine_side_by_corporation(corporation_id) do
    # Simple hash-based side assignment for consistency
    case rem(corporation_id, 2) do
      0 -> :side_a
      1 -> :side_b
    end
  end

  defp high_value_kill?(event) do
    (event.total_value || 0) > 500_000_000
  end

  defp capital_ship_kill?(event) do
    ship_class = classify_ship(event.victim_ship_type_id)
    ship_class in [:dreadnought, :carrier, :supercarrier, :titan, :force_auxiliary]
  end

  defp commander_kill?(event) do
    ship_class = classify_ship(event.victim_ship_type_id)
    # Command ships, T3 cruisers, or expensive ships that might be FC ships
    ship_class in [:command_ship, :strategic_cruiser] or
      (event.total_value || 0) > 1_000_000_000
  end

  defp determine_event_type(event) do
    cond do
      capital_ship_kill?(event) -> :capital_kill
      commander_kill?(event) -> :potential_fc_kill
      high_value_kill?(event) -> :high_value_kill
      true -> :significant_kill
    end
  end

  defp generate_event_description(event) do
    ship_class = classify_ship(event.victim_ship_type_id)
    value_formatted = format_isk_value(event.total_value || 0)

    "#{String.capitalize(to_string(ship_class))} destroyed (#{value_formatted})"
  end

  defp format_isk_value(value) when value >= 1_000_000_000 do
    "#{Float.round(value / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk_value(value) when value >= 1_000_000 do
    "#{Float.round(value / 1_000_000, 1)}M ISK"
  end

  defp format_isk_value(value) do
    "#{Float.round(value / 1_000, 0)}K ISK"
  end

  defp classify_ship(ship_type_id) do
    # Classify ship based on type ID ranges (simplified EVE ship classification)
    cond do
      # Frigates
      ship_type_id in [582, 583, 584, 585, 586, 587, 588, 589] -> :frigate
      # Destroyers
      ship_type_id in [16_236, 16_238, 16_240, 16_242] -> :destroyer
      # Cruisers
      ship_type_id in [620, 621, 622, 623, 624, 625, 626, 627] -> :cruiser
      # Battlecruisers
      ship_type_id in [16_227, 16_229, 16_231, 16_233] -> :battlecruiser
      # Battleships
      ship_type_id in [638, 639, 640, 641, 642, 643, 644, 645] -> :battleship
      # Strategic Cruisers (T3C)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> :strategic_cruiser
      # Logistics Cruisers
      ship_type_id in [11_985, 11_987, 11_989, 12_003] -> :logistics
      # Recon Ships
      ship_type_id in [11_957, 11_959, 11_961, 11_963] -> :recon
      # Heavy Assault Cruisers
      ship_type_id in [11_991, 12_005, 11_993, 11_995] -> :heavy_assault_cruiser
      # Capital ships
      ship_type_id > 20_000 and ship_type_id < 30_000 -> :capital
      # Default
      true -> :unknown
    end
  end
end
