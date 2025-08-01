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

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Services.SideDeterminationService

  @doc """
  Identify distinct battle phases from killmail timeline.

  Phases are identified based on:
  - Time gaps between kills (>5 minutes indicates new phase)
  - Kill intensity changes (>50% change in kill rate)
  - Ship type transitions (shift in ship classes involved)
  - Geographic movement (system changes)
  """
  def identify_battle_phases(timeline) do
    # Simplified single-phase analysis as decided in ISSUE.md
    if length(timeline) < 1 do
      []
    else
      # Sort timeline by timestamp
      sorted_timeline = Enum.sort_by(timeline, & &1.timestamp)

      # Treat entire battle as single phase
      [analyze_single_phase(sorted_timeline)]
    end
  end

  # Analyze the entire battle as a single phase.
  defp analyze_single_phase(timeline) do
    if Enum.empty?(timeline) do
      %{
        phase_number: 1,
        start_time: DateTime.utc_now(),
        end_time: DateTime.utc_now(),
        duration_seconds: 0,
        kill_count: 0,
        intensity: 0.0,
        phase_type: :no_activity,
        dominant_side: :unknown,
        key_events: [],
        ship_classes: %{},
        isk_destroyed: 0
      }
    else
      first_kill = List.first(timeline)
      last_kill = List.last(timeline)
      duration = DateTime.diff(last_kill.timestamp, first_kill.timestamp, :second)
      kill_count = length(timeline)

      # Calculate basic metrics for the single phase
      intensity = calculate_battle_intensity(timeline, max(duration, 60))
      ship_classes = analyze_ship_composition(timeline)
      isk_destroyed = calculate_total_isk_destroyed(timeline)
      dominant_side = determine_dominant_side(timeline)
      key_events = identify_key_events(timeline)

      # Determine battle type based on characteristics
      phase_type =
        cond do
          kill_count >= 50 -> :major_engagement
          kill_count >= 20 -> :significant_battle
          kill_count >= 10 -> :skirmish
          kill_count >= 5 -> :small_engagement
          true -> :minor_skirmish
        end

      %{
        phase_number: 1,
        start_time: first_kill.timestamp,
        end_time: last_kill.timestamp,
        duration_seconds: max(duration, 1),
        kill_count: kill_count,
        intensity: Float.round(intensity, 2),
        phase_type: phase_type,
        dominant_side: dominant_side,
        key_events: key_events,
        ship_classes: ship_classes,
        isk_destroyed: isk_destroyed
      }
    end
  end

  @doc """
  Identify boundaries between phases based on multiple factors.
  """
  def identify_phase_boundaries(timeline) do
    timeline
    |> Enum.zip(Enum.drop(timeline, 1))
    |> Enum.with_index()
    |> Enum.reduce([], fn {{prev_event, curr_event}, index}, boundaries ->
      # Calculate time gap
      time_gap = DateTime.diff(curr_event.timestamp, prev_event.timestamp, :second)

      # Check for phase boundary conditions
      # Large time gap (>5 minutes)
      # System change
      # Significant ship class transition
      # Kill intensity spike/drop
      is_boundary =
        time_gap > 300 ||
          Map.get(prev_event, :solar_system_id) != Map.get(curr_event, :solar_system_id) ||
          detect_ship_class_transition(prev_event, curr_event) ||
          detect_intensity_change(timeline, index)

      if is_boundary do
        [index + 1 | boundaries]
      else
        boundaries
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Split timeline into phases based on identified boundaries.
  """
  def split_into_phases(timeline, boundaries) do
    boundaries_with_end = [length(timeline) | Enum.reverse(boundaries)]
    all_boundaries = [0 | Enum.reverse(boundaries)]

    all_boundaries
    |> Enum.zip(Enum.reverse(boundaries_with_end))
    |> Enum.map(fn {start_idx, end_idx} ->
      Enum.slice(timeline, start_idx, end_idx - start_idx)
    end)
    |> Enum.reject(&Enum.empty?/1)
  end

  @doc """
  Analyze a single phase and extract metrics.
  """
  def analyze_phase(phase_events, phase_number, total_phases) do
    start_time = List.first(phase_events).timestamp
    end_time = List.last(phase_events).timestamp
    duration_seconds = DateTime.diff(end_time, start_time)
    kills = length(phase_events)

    # Calculate intensity (kills per minute)
    intensity =
      if duration_seconds > 0 do
        kills / (duration_seconds / 60.0)
      else
        # All kills at same timestamp = instant alpha strike
        kills * 10.0
      end

    phase_data = %{
      phase_number: phase_number,
      start_time: start_time,
      end_time: end_time,
      duration_seconds: duration_seconds,
      kills: kills,
      intensity: intensity
    }

    # Determine phase type based on position and characteristics
    phase_type = determine_phase_type(phase_data, phase_number - 1, total_phases)

    # Calculate additional metrics
    dominant_side = calculate_dominant_side_for_phase(phase_events, phase_data)
    key_events = identify_key_events_in_phase(phase_events, phase_data)
    ship_composition = analyze_phase_ship_composition(phase_events)

    %{
      phase_type: phase_type,
      phase_number: phase_number,
      start_time: start_time,
      end_time: end_time,
      duration_seconds: duration_seconds,
      kills_in_phase: kills,
      dominant_side: dominant_side,
      intensity_rating: classify_intensity_rating(intensity),
      intensity_value: Float.round(intensity, 2),
      key_events: key_events,
      ship_composition: ship_composition,
      geographic_scope: analyze_geographic_scope(phase_events)
    }
  end

  @doc """
  Determine the type of battle phase based on position and characteristics.

  Phase types:
  - :initial_engagement - First contact and opening moves
  - :escalation - Increasing intensity, reinforcements arriving
  - :sustained_combat - Main fighting phase with steady intensity
  - :climax - Peak intensity period of the battle
  - :de_escalation - Intensity dropping, one side pulling back
  - :withdrawal - One side retreating or disengaging
  - :cleanup - Mopping up stragglers
  - :lull - Temporary pause in fighting
  - :reinforcement - New forces arriving after a gap
  - :single_engagement - Entire battle is one continuous phase
  """
  def determine_phase_type(phase, _index, _total_phases) do
    # Simplified single-phase classification based on battle characteristics
    cond do
      phase.kill_count >= 100 -> :massive_battle
      phase.kill_count >= 50 -> :major_engagement
      phase.kill_count >= 20 -> :significant_battle
      phase.kill_count >= 10 -> :skirmish
      phase.kill_count >= 5 -> :small_engagement
      phase.intensity > 2.0 -> :intense_skirmish
      true -> :minor_engagement
    end
  end

  @doc """
  Calculate which side was dominant during a specific phase.
  """
  def calculate_dominant_side_for_phase(phase_events, _phase_data) do
    if Enum.empty?(phase_events) do
      :unknown
    else
      # Extract participants from phase events
      participants = extract_participants_from_events(phase_events)

      # Use SideDeterminationService to classify participants
      sides = SideDeterminationService.classify_participants(participants, phase_events)

      # Count kills by each side
      side_a_victims = count_victims_by_side(phase_events, sides.side_a)
      side_b_victims = count_victims_by_side(phase_events, sides.side_b)

      # Dominant side is the one with fewer losses
      cond do
        side_a_victims == side_b_victims -> :balanced
        side_a_victims < side_b_victims -> :side_a
        true -> :side_b
      end
    end
  end

  @doc """
  Identify key events within a phase (high-value kills, escalations).
  """
  def identify_key_events_in_phase(phase_events, _phase_data) do
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
        value: Map.get(event, :total_value, 0),
        ship_class: classify_ship(Map.get(event, :victim_ship_type_id, 0)),
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

  defp extract_participants_from_events(events) do
    # Extract unique participants from events (victims and attackers)
    victims =
      events
      |> Enum.map(fn event ->
        %{
          character_id: Map.get(event, :victim_character_id),
          corporation_id: Map.get(event, :victim_corporation_id),
          alliance_id: Map.get(event, :victim_alliance_id),
          ship_type_id: Map.get(event, :victim_ship_type_id)
        }
      end)
      |> Enum.filter(& &1.character_id)

    attackers =
      events
      |> Enum.flat_map(fn event ->
        Map.get(event, :attackers, [])
        |> Enum.map(fn attacker ->
          %{
            character_id: Map.get(attacker, :character_id),
            corporation_id: Map.get(attacker, :corporation_id),
            alliance_id: Map.get(attacker, :alliance_id),
            ship_type_id: Map.get(attacker, :ship_type_id)
          }
        end)
      end)
      |> Enum.filter(& &1.character_id)

    # Combine and deduplicate
    (victims ++ attackers)
    |> Enum.uniq_by(& &1.character_id)
  end

  defp count_victims_by_side(events, side_participants) do
    side_character_ids = Enum.map(side_participants, & &1.character_id)

    Enum.count(events, fn event ->
      victim_id = Map.get(event, :victim_character_id)
      victim_id in side_character_ids
    end)
  end

  defp high_value_kill?(event) do
    Map.get(event, :total_value, 0) > 500_000_000
  end

  defp capital_ship_kill?(event) do
    ship_type_id = Map.get(event, :victim_ship_type_id, 0)
    ship_class = classify_ship(ship_type_id)
    ship_class in [:dreadnought, :carrier, :supercarrier, :titan, :force_auxiliary, :capital]
  end

  defp commander_kill?(event) do
    ship_type_id = Map.get(event, :victim_ship_type_id, 0)
    ship_class = classify_ship(ship_type_id)
    value = Map.get(event, :total_value, 0)

    # Command ships, T3 cruisers, or expensive ships that might be FC ships
    ship_class in [:command_ship, :strategic_cruiser] or value > 1_000_000_000
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
    ship_type_id = Map.get(event, :victim_ship_type_id, 0)
    ship_class = classify_ship(ship_type_id)
    value = Map.get(event, :total_value, 0)
    value_formatted = format_isk_value(value)

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
    # Use proper ship classification from static data service
    case EveDmv.StaticData.ShipAttributesService.get_ship_class(ship_type_id) do
      {:ok, ship_class} ->
        ship_class

      {:error, _} ->
        # Fallback classification based on ID ranges for unknown ships
        cond do
          ship_type_id < 1000 -> :frigate
          ship_type_id < 2000 -> :destroyer
          ship_type_id < 5000 -> :cruiser
          ship_type_id < 10_000 -> :battlecruiser
          ship_type_id < 20_000 -> :battleship
          ship_type_id >= 20_000 -> :capital
          true -> :unknown
        end
    end
  rescue
    _ -> :unknown
  end

  defp detect_ship_class_transition(prev_event, curr_event) do
    prev_class = classify_ship(Map.get(prev_event, :victim_ship_type_id, 0))
    curr_class = classify_ship(Map.get(curr_event, :victim_ship_type_id, 0))

    # Detect significant transitions (e.g., subcaps to capitals)
    case {prev_class, curr_class} do
      # Escalation to capitals
      {subcap, :capital} when subcap != :capital -> true
      # De-escalation from capitals
      {:capital, subcap} when subcap != :capital -> true
      # Otherwise no significant transition
      _ -> false
    end
  end

  defp detect_intensity_change(timeline, current_index) do
    # Look at kill rate in 2-minute windows before and after current point
    # seconds
    window_size = 120

    # Get events before current index
    before_events =
      timeline
      |> Enum.take(current_index)
      |> Enum.filter(fn event ->
        ref_time = Enum.at(timeline, current_index).timestamp
        DateTime.diff(ref_time, event.timestamp, :second) <= window_size
      end)

    # Get events after current index
    after_events =
      timeline
      |> Enum.drop(current_index + 1)
      |> Enum.take(10)
      |> Enum.filter(fn event ->
        ref_time = Enum.at(timeline, current_index).timestamp
        DateTime.diff(event.timestamp, ref_time, :second) <= window_size
      end)

    before_rate = length(before_events) / (window_size / 60.0)
    after_rate = length(after_events) / (window_size / 60.0)

    # Detect >50% change in kill rate
    if before_rate > 0 do
      change_ratio = abs(after_rate - before_rate) / before_rate
      change_ratio > 0.5
    else
      after_rate > 1.0
    end
  end

  defp analyze_phase_ship_composition(phase_events) do
    phase_events
    |> Enum.map(fn event -> classify_ship(Map.get(event, :victim_ship_type_id, 0)) end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_class, count} -> count end, :desc)
    |> Enum.map(fn {ship_class, count} ->
      %{
        ship_class: ship_class,
        count: count,
        percentage: Float.round(count / length(phase_events) * 100, 1)
      }
    end)
  end

  defp analyze_geographic_scope(phase_events) do
    systems =
      phase_events
      |> Enum.map(&Map.get(&1, :solar_system_id))
      |> Enum.uniq()

    %{
      systems_involved: length(systems),
      system_ids: systems,
      geographic_type: classify_geographic_scope(length(systems))
    }
  end

  defp classify_geographic_scope(system_count) do
    cond do
      system_count == 1 -> :single_system
      system_count <= 3 -> :localized
      system_count <= 7 -> :regional
      true -> :widespread
    end
  end

  # Missing helper functions for analyze_single_phase

  defp calculate_battle_intensity(timeline, duration_seconds) do
    kill_count = length(timeline)

    if duration_seconds > 0 do
      kill_count / (duration_seconds / 60.0)
    else
      # Instant alpha strike
      kill_count * 10.0
    end
  end

  defp analyze_ship_composition(timeline) do
    timeline
    |> Enum.map(fn event -> classify_ship(Map.get(event, :victim_ship_type_id, 0)) end)
    |> Enum.frequencies()
  end

  defp calculate_total_isk_destroyed(timeline) do
    timeline
    |> Enum.map(&Map.get(&1, :total_value, 0))
    |> Enum.sum()
  end

  defp determine_dominant_side(timeline) do
    if Enum.empty?(timeline) do
      :unknown
    else
      # Simple heuristic: look at alliance/corporation distribution
      participants = extract_participants_from_events(timeline)

      alliance_counts =
        participants
        |> Enum.map(&Map.get(&1, :alliance_id))
        |> Enum.reject(&is_nil/1)
        |> Enum.frequencies()

      if Enum.empty?(alliance_counts) do
        :unknown
      else
        # If one alliance has significantly more participants, they're likely dominant
        {_top_alliance, top_count} = Enum.max_by(alliance_counts, &elem(&1, 1))
        total_participants = length(participants)

        if top_count / total_participants > 0.6 do
          # Dominant alliance
          :side_a
        else
          :balanced
        end
      end
    end
  end

  defp identify_key_events(timeline) do
    timeline
    |> Enum.filter(fn event ->
      high_value_kill?(event) or capital_ship_kill?(event) or commander_kill?(event)
    end)
    |> Enum.map(fn event ->
      %{
        timestamp: Map.get(event, :timestamp),
        event_type: determine_event_type(event),
        description: generate_event_description(event)
      }
    end)
  end
end
