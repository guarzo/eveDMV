defmodule EveDmv.Shared.Correlation.TimelineManager do
  @moduledoc """
  Manages timeline construction and analysis for activity correlation.

  Provides functionality for:
  - Building activity timelines from system activities
  - Identifying activity bursts and patterns
  - Creating timeline windows for analysis
  - Detecting coordinated operations
  - Calculating timeline statistics
  """
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @doc """
  Builds a comprehensive activity timeline from system activities.
  """
  def build_activity_timeline(system_activities) do
    timeline_events =
      system_activities
      |> Enum.flat_map(&extract_timeline_events/1)
      |> Enum.sort_by(& &1.timestamp, DateTime)
      |> add_sequence_numbers()
      |> group_by_time_windows()

    %{
      events: timeline_events,
      start_time: get_timeline_start(timeline_events),
      end_time: get_timeline_end(timeline_events),
      duration_seconds: calculate_timeline_duration(timeline_events),
      event_count: length(timeline_events),
      systems_involved: count_unique_systems(timeline_events),
      entities_involved: count_unique_entities(timeline_events)
    }
  end

  @doc """
  Identifies bursts of activity within timeline events.
  """
  def identify_activity_bursts(timeline_events) do
    # Group events into time windows (5 minute windows by default)
    window_size_seconds = 300

    timeline_events
    |> Enum.group_by(fn event ->
      # Round down to nearest window
      timestamp_seconds = DateTime.to_unix(event.timestamp)
      window_start = div(timestamp_seconds, window_size_seconds) * window_size_seconds
      DateTime.from_unix!(window_start)
    end)
    |> Enum.map(fn {window_start, events} ->
      %{
        window_start: window_start,
        window_end: DateTimeUtils.add(window_start, window_size_seconds, :second),
        event_count: length(events),
        unique_entities: count_unique_entities(events),
        unique_systems: count_unique_systems(events),
        intensity: calculate_burst_intensity(events),
        events: events
      }
    end)
    |> Enum.filter(fn burst ->
      # Filter for significant bursts (more than 5 events or high intensity)
      burst.event_count > 5 or burst.intensity > 0.7
    end)
    |> Enum.sort_by(& &1.intensity, :desc)
  end

  @doc """
  Creates timeline windows of specified size.
  """
  def create_timeline_windows(timeline_events, window_size_minutes) do
    window_size_seconds = window_size_minutes * 60

    if Enum.empty?(timeline_events) do
      []
    else
      start_time = get_timeline_start(timeline_events)
      end_time = get_timeline_end(timeline_events)

      # Create windows from start to end
      create_windows(start_time, end_time, window_size_seconds)
      |> Enum.map(fn {window_start, window_end} ->
        events_in_window =
          Enum.filter(timeline_events, fn event ->
            DateTimeUtils.compare(event.timestamp, window_start) != :lt and
              DateTimeUtils.compare(event.timestamp, window_end) == :lt
          end)

        %{
          window_start: window_start,
          window_end: window_end,
          duration_minutes: window_size_minutes,
          event_count: length(events_in_window),
          events: events_in_window,
          statistics: calculate_window_statistics(events_in_window)
        }
      end)
    end
  end

  @doc """
  Identifies potentially coordinated operations.
  """
  def identify_coordinated_operations(timeline_events) do
    # Look for patterns suggesting coordination
    coordination_patterns = []

    # Pattern 1: Multiple entities acting within short time windows
    time_clustered =
      timeline_events
      |> Enum.chunk_by(fn event ->
        # Group by 30-second windows
        timestamp_seconds = DateTime.to_unix(event.timestamp)
        div(timestamp_seconds, 30)
      end)
      |> Enum.filter(fn chunk ->
        # Multiple entities in same window
        unique_entities =
          chunk
          |> Enum.map(& &1.entity_id)
          |> Enum.uniq()
          |> length()

        unique_entities > 2
      end)
      |> Enum.map(fn chunk ->
        %{
          pattern_type: :time_clustered_activity,
          confidence: calculate_coordination_confidence(chunk),
          start_time: List.first(chunk).timestamp,
          end_time: List.last(chunk).timestamp,
          entities_involved: Enum.map(chunk, & &1.entity_id) |> Enum.uniq(),
          events: chunk
        }
      end)

    # Pattern 2: Sequential system movements
    movement_patterns = identify_movement_patterns(timeline_events)

    # Pattern 3: Synchronized actions across systems
    synchronized_actions = identify_synchronized_actions(timeline_events)

    (coordination_patterns ++ time_clustered ++ movement_patterns ++ synchronized_actions)
    |> Enum.sort_by(& &1.confidence, :desc)
  end

  @doc """
  Calculates statistics for timeline events.
  """
  def calculate_timeline_statistics(timeline_events) do
    if Enum.empty?(timeline_events) do
      %{
        total_events: 0,
        duration_seconds: 0,
        events_per_minute: 0,
        unique_entities: 0,
        unique_systems: 0,
        activity_distribution: %{}
      }
    else
      duration = calculate_timeline_duration(timeline_events)

      %{
        total_events: length(timeline_events),
        duration_seconds: duration,
        events_per_minute: calculate_events_per_minute(timeline_events, duration),
        unique_entities: count_unique_entities(timeline_events),
        unique_systems: count_unique_systems(timeline_events),
        activity_distribution: calculate_activity_distribution(timeline_events),
        peak_activity_time: find_peak_activity_time(timeline_events),
        activity_gaps: identify_activity_gaps(timeline_events)
      }
    end
  end

  # Private helper functions

  defp extract_timeline_events(system_activity) do
    # Extract individual events from system activity data
    events = []

    # Extract killmail events
    killmail_events =
      Map.get(system_activity, :killmails, [])
      |> Enum.map(fn km ->
        %{
          timestamp: km.killmail_time,
          event_type: :kill,
          system_id: km.solar_system_id,
          entity_id: km.victim["character_id"] || km.victim["corporation_id"],
          entity_type: if(km.victim["character_id"], do: :character, else: :corporation),
          details: %{
            ship_type_id: km.victim["ship_type_id"],
            value: km.zkb_total_value
          }
        }
      end)

    events ++ killmail_events
  end

  defp add_sequence_numbers(events) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, index} ->
      Map.put(event, :sequence_number, index + 1)
    end)
  end

  defp group_by_time_windows(events) do
    # Add time window information to each event
    Enum.map(events, fn event ->
      timestamp_seconds = DateTime.to_unix(event.timestamp)

      Map.merge(event, %{
        minute_window: div(timestamp_seconds, 60),
        five_minute_window: div(timestamp_seconds, 300),
        hour_window: div(timestamp_seconds, 3600)
      })
    end)
  end

  defp get_timeline_start(events) do
    if Enum.empty?(events) do
      DateTime.utc_now()
    else
      events
      |> Enum.map(& &1.timestamp)
      |> Enum.min(DateTime)
    end
  end

  defp get_timeline_end(events) do
    if Enum.empty?(events) do
      DateTime.utc_now()
    else
      events
      |> Enum.map(& &1.timestamp)
      |> Enum.max(DateTime)
    end
  end

  defp calculate_timeline_duration(events) do
    if length(events) < 2 do
      0
    else
      start_time = get_timeline_start(events)
      end_time = get_timeline_end(events)
      DateTimeUtils.diff(end_time, start_time, :second)
    end
  end

  defp count_unique_systems(events) do
    events
    |> Enum.map(& &1[:system_id])
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_entities(events) do
    events
    |> Enum.map(& &1[:entity_id])
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp calculate_burst_intensity(events) do
    # Calculate intensity based on event density and diversity
    event_count = length(events)
    unique_entities = count_unique_entities(events)
    unique_systems = count_unique_systems(events)

    # Normalize factors
    count_factor = min(event_count / 20.0, 1.0)
    entity_factor = min(unique_entities / 10.0, 1.0)
    system_factor = min(unique_systems / 5.0, 1.0)

    # Weighted average
    count_factor * 0.5 + entity_factor * 0.3 + system_factor * 0.2
  end

  defp create_windows(start_time, end_time, window_size_seconds) do
    windows = []
    current = start_time

    create_windows_recursive(current, end_time, window_size_seconds, windows)
  end

  defp create_windows_recursive(current, end_time, window_size_seconds, acc) do
    if DateTimeUtils.compare(current, end_time) == :lt do
      window_end = DateTimeUtils.add(current, window_size_seconds, :second)
      new_window = {current, window_end}
      create_windows_recursive(window_end, end_time, window_size_seconds, [new_window | acc])
    else
      Enum.reverse(acc)
    end
  end

  defp calculate_window_statistics(events) do
    %{
      event_count: length(events),
      unique_entities: count_unique_entities(events),
      unique_systems: count_unique_systems(events),
      event_types: count_event_types(events)
    }
  end

  defp count_event_types(events) do
    events
    |> Enum.group_by(& &1[:event_type])
    |> Enum.map(fn {type, events} -> {type, length(events)} end)
    |> Map.new()
  end

  defp calculate_coordination_confidence(events) do
    # Calculate confidence based on multiple factors
    entity_count = count_unique_entities(events)
    time_span = calculate_time_span(events)

    # Tighter time spans with more entities = higher confidence
    entity_factor = min(entity_count / 5.0, 1.0)
    # Decay over 60 seconds
    time_factor = max(0, 1.0 - time_span / 60.0)

    entity_factor * 0.6 + time_factor * 0.4
  end

  defp calculate_time_span(events) do
    if length(events) < 2 do
      0
    else
      first = List.first(events).timestamp
      last = List.last(events).timestamp
      DateTimeUtils.diff(last, first, :second)
    end
  end

  defp identify_movement_patterns(events) do
    # Group events by entity
    events
    |> Enum.group_by(& &1[:entity_id])
    |> Enum.filter(fn {_entity_id, entity_events} ->
      # Only consider entities with multiple system activities
      count_unique_systems(entity_events) > 1
    end)
    |> Enum.map(fn {entity_id, entity_events} ->
      sorted_events = Enum.sort_by(entity_events, & &1.timestamp, DateTime)

      %{
        pattern_type: :sequential_movement,
        confidence: calculate_movement_confidence(sorted_events),
        entity_id: entity_id,
        path: extract_movement_path(sorted_events),
        events: sorted_events
      }
    end)
  end

  defp identify_synchronized_actions(events) do
    # Look for similar actions happening at similar times across systems
    events
    |> Enum.chunk_by(fn event ->
      # Group by 2-minute windows
      timestamp_seconds = DateTime.to_unix(event.timestamp)
      div(timestamp_seconds, 120)
    end)
    |> Enum.filter(fn chunk ->
      # Multiple systems involved
      count_unique_systems(chunk) > 1
    end)
    |> Enum.map(fn chunk ->
      %{
        pattern_type: :synchronized_action,
        confidence: calculate_synchronization_confidence(chunk),
        systems_involved: Enum.map(chunk, & &1[:system_id]) |> Enum.uniq(),
        events: chunk
      }
    end)
  end

  defp calculate_movement_confidence(events) do
    # Base confidence on speed and pattern of movement
    system_count = count_unique_systems(events)
    time_span = calculate_time_span(events)

    if time_span > 0 do
      # Systems per hour
      movement_rate = (system_count - 1) / (time_span / 3600.0)
      # Higher movement rate = higher confidence
      min(movement_rate / 10.0, 1.0)
    else
      0.0
    end
  end

  defp extract_movement_path(events) do
    events
    |> Enum.map(& &1[:system_id])
    # Remove consecutive duplicates
    |> Enum.dedup()
  end

  defp calculate_synchronization_confidence(events) do
    # Based on system diversity and timing precision
    system_count = count_unique_systems(events)
    time_span = calculate_time_span(events)

    system_factor = min(system_count / 5.0, 1.0)
    # Tighter timing = higher confidence
    time_factor = max(0, 1.0 - time_span / 120.0)

    system_factor * 0.5 + time_factor * 0.5
  end

  defp calculate_events_per_minute(events, duration_seconds) do
    if duration_seconds > 0 do
      Float.round(length(events) / (duration_seconds / 60.0), 2)
    else
      0.0
    end
  end

  defp calculate_activity_distribution(events) do
    events
    |> Enum.group_by(& &1[:event_type])
    |> Enum.map(fn {type, type_events} ->
      {type,
       %{
         count: length(type_events),
         percentage: Float.round(length(type_events) / length(events) * 100, 1)
       }}
    end)
    |> Map.new()
  end

  defp find_peak_activity_time(events) do
    events
    |> Enum.group_by(&DateTime.truncate(&1.timestamp, :minute))
    |> Enum.max_by(fn {_time, events} -> length(events) end, fn -> {nil, []} end)
    |> elem(0)
  end

  defp identify_activity_gaps(events) do
    events
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      gap_seconds = DateTimeUtils.diff(curr.timestamp, prev.timestamp, :second)

      %{
        start: prev.timestamp,
        end: curr.timestamp,
        gap_seconds: gap_seconds,
        gap_minutes: Float.round(gap_seconds / 60.0, 1)
      }
    end)
    |> Enum.filter(fn gap ->
      # Only significant gaps (> 5 minutes)
      gap.gap_seconds > 300
    end)
    |> Enum.sort_by(& &1.gap_seconds, :desc)
  end

end
