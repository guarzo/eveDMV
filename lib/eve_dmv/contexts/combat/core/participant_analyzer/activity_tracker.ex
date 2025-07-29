defmodule EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.ActivityTracker do
  @moduledoc """
  Tracks participant activity patterns and builds activity timelines.
  """
  
  @doc """
  Build an activity timeline showing participant engagement over time.
  """
  def build_timeline(participants, killmails) do
    # Group killmails by time slots
    time_slots = create_time_slots(killmails)
    
    # Track activity in each slot
    timeline = Enum.map(time_slots, fn slot ->
      %{
        time: slot.time,
        duration: slot.duration,
        active_participants: count_active_participants(slot, participants),
        kills: length(slot.killmails),
        new_arrivals: find_new_arrivals(slot, participants, time_slots),
        departures: find_departures(slot, participants, time_slots),
        intensity: calculate_slot_intensity(slot)
      }
    end)
    
    %{
      slots: timeline,
      peak_activity: find_peak_activity(timeline),
      total_duration: calculate_total_duration(killmails),
      phases: identify_battle_phases(timeline)
    }
  end
  
  @doc """
  Analyze activity patterns for a specific participant.
  """
  def analyze_participant_activity(participant, killmails) do
    participant_killmails = filter_participant_killmails(participant, killmails)
    
    %{
      first_appearance: find_first_appearance(participant_killmails),
      last_appearance: find_last_appearance(participant_killmails),
      active_duration: calculate_active_duration(participant_killmails),
      activity_gaps: find_activity_gaps(participant_killmails),
      engagement_pattern: classify_engagement_pattern(participant_killmails),
      peak_activity_time: find_participant_peak_activity(participant_killmails)
    }
  end
  
  defp create_time_slots(killmails) do
    return [] if Enum.empty?(killmails)
    
    # Sort killmails by time
    sorted = Enum.sort_by(killmails, & &1.killmail_time)
    
    # Create 2-minute time slots
    start_time = List.first(sorted).killmail_time
    end_time = List.last(sorted).killmail_time
    
    slots = generate_time_slots(start_time, end_time, 2)
    
    # Assign killmails to slots
    Enum.map(slots, fn slot ->
      km_in_slot = Enum.filter(sorted, fn km ->
        DateTime.compare(km.killmail_time, slot.start) != :lt &&
        DateTime.compare(km.killmail_time, slot.end) == :lt
      end)
      
      %{
        time: slot.start,
        duration: 2,
        killmails: km_in_slot
      }
    end)
  end
  
  defp generate_time_slots(start_time, end_time, interval_minutes) do
    total_minutes = DateTime.diff(end_time, start_time, :minute)
    slot_count = div(total_minutes, interval_minutes) + 1
    
    Enum.map(0..(slot_count - 1), fn i ->
      slot_start = DateTime.add(start_time, i * interval_minutes * 60, :second)
      slot_end = DateTime.add(slot_start, interval_minutes * 60, :second)
      
      %{
        start: slot_start,
        end: slot_end
      }
    end)
  end
  
  defp count_active_participants(slot, participants) do
    # Count unique participants active in this time slot
    active_ids = slot.killmails
    |> Enum.flat_map(fn km ->
      victim_id = get_in(km.victim, ["character_id"])
      attacker_ids = (km.attackers || [])
      |> Enum.map(&get_in(&1, ["character_id"]))
      |> Enum.reject(&is_nil/1)
      
      [victim_id | attacker_ids] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    
    length(active_ids)
  end
  
  defp find_new_arrivals(slot, participants, all_slots) do
    slot_index = Enum.find_index(all_slots, &(&1 == slot))
    
    if slot_index == 0 do
      # First slot - all participants are new
      count_active_participants(slot, participants)
    else
      current_participants = get_slot_participants(slot)
      previous_participants = all_slots
      |> Enum.take(slot_index)
      |> Enum.flat_map(&get_slot_participants/1)
      |> MapSet.new()
      
      current_participants
      |> MapSet.difference(previous_participants)
      |> MapSet.size()
    end
  end
  
  defp find_departures(slot, participants, all_slots) do
    slot_index = Enum.find_index(all_slots, &(&1 == slot))
    
    if slot_index == length(all_slots) - 1 do
      # Last slot - no departures to track
      0
    else
      current_participants = get_slot_participants(slot)
      future_slots = Enum.drop(all_slots, slot_index + 1)
      
      # Participants who don't appear in any future slots
      Enum.count(current_participants, fn participant ->
        not Enum.any?(future_slots, fn future_slot ->
          participant in get_slot_participants(future_slot)
        end)
      end)
    end
  end
  
  defp get_slot_participants(slot) do
    slot.killmails
    |> Enum.flat_map(fn km ->
      victim_id = get_in(km.victim, ["character_id"])
      attacker_ids = (km.attackers || [])
      |> Enum.map(&get_in(&1, ["character_id"]))
      |> Enum.reject(&is_nil/1)
      
      [victim_id | attacker_ids] |> Enum.reject(&is_nil/1)
    end)
    |> MapSet.new()
  end
  
  defp calculate_slot_intensity(slot) do
    kills = length(slot.killmails)
    
    cond do
      kills >= 10 -> :extreme
      kills >= 5 -> :high
      kills >= 2 -> :moderate
      kills >= 1 -> :low
      true -> :none
    end
  end
  
  defp find_peak_activity(timeline) do
    timeline
    |> Enum.max_by(& &1.kills, fn -> nil end)
  end
  
  defp calculate_total_duration(killmails) do
    if Enum.empty?(killmails) do
      0
    else
      sorted = Enum.sort_by(killmails, & &1.killmail_time)
      first = List.first(sorted).killmail_time
      last = List.last(sorted).killmail_time
      DateTime.diff(last, first, :minute)
    end
  end
  
  defp identify_battle_phases(timeline) do
    # Identify distinct phases based on activity patterns
    phases = []
    current_phase = nil
    
    timeline
    |> Enum.reduce({phases, current_phase}, fn slot, {phases_acc, current} ->
      intensity = slot.intensity
      
      cond do
        # Start new phase if intensity changes significantly
        is_nil(current) ->
          new_phase = %{
            start_time: slot.time,
            intensity: intensity,
            type: classify_phase_type(slot)
          }
          {phases_acc, new_phase}
          
        intensity != current.intensity ->
          # End current phase and start new one
          completed_phase = Map.put(current, :end_time, slot.time)
          new_phase = %{
            start_time: slot.time,
            intensity: intensity,
            type: classify_phase_type(slot)
          }
          {[completed_phase | phases_acc], new_phase}
          
        true ->
          # Continue current phase
          {phases_acc, current}
      end
    end)
    |> then(fn {phases, last_phase} ->
      if last_phase do
        # Close the last phase
        last_slot = List.last(timeline)
        completed = Map.put(last_phase, :end_time, last_slot.time)
        [completed | phases]
      else
        phases
      end
    end)
    |> Enum.reverse()
  end
  
  defp classify_phase_type(slot) do
    cond do
      slot.new_arrivals > 5 -> :escalation
      slot.departures > 5 -> :withdrawal
      slot.intensity == :extreme -> :peak_combat
      slot.intensity == :high -> :heavy_combat
      slot.intensity == :moderate -> :skirmish
      true -> :positioning
    end
  end
  
  defp filter_participant_killmails(participant, killmails) do
    Enum.filter(killmails, fn km ->
      victim_match = get_in(km.victim, ["character_id"]) == participant.character_id
      
      attacker_match = Enum.any?(km.attackers || [], fn attacker ->
        attacker["character_id"] == participant.character_id
      end)
      
      victim_match || attacker_match
    end)
  end
  
  defp find_first_appearance(killmails) do
    killmails
    |> Enum.map(& &1.killmail_time)
    |> Enum.min(fn -> nil end)
  end
  
  defp find_last_appearance(killmails) do
    killmails
    |> Enum.map(& &1.killmail_time)
    |> Enum.max(fn -> nil end)
  end
  
  defp calculate_active_duration(killmails) do
    case {find_first_appearance(killmails), find_last_appearance(killmails)} do
      {nil, _} -> 0
      {_, nil} -> 0
      {first, last} -> DateTime.diff(last, first, :minute)
    end
  end
  
  defp find_activity_gaps(killmails) do
    times = killmails
    |> Enum.map(& &1.killmail_time)
    |> Enum.sort()
    
    times
    |> Enum.zip(Enum.drop(times, 1))
    |> Enum.map(fn {t1, t2} ->
      %{
        start: t1,
        end: t2,
        duration: DateTime.diff(t2, t1, :minute)
      }
    end)
    |> Enum.filter(& &1.duration > 5) # Gaps longer than 5 minutes
  end
  
  defp classify_engagement_pattern(killmails) do
    times = Enum.map(killmails, & &1.killmail_time)
    
    cond do
      length(times) <= 1 -> :single_engagement
      continuous_engagement?(times) -> :continuous
      has_reengagement?(times) -> :hit_and_run
      true -> :intermittent
    end
  end
  
  defp continuous_engagement?(times) do
    gaps = times
    |> Enum.sort()
    |> Enum.zip(Enum.drop(Enum.sort(times), 1))
    |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1, :minute) end)
    
    Enum.all?(gaps, & &1 <= 3)
  end
  
  defp has_reengagement?(times) do
    gaps = times
    |> Enum.sort()
    |> Enum.zip(Enum.drop(Enum.sort(times), 1))
    |> Enum.map(fn {t1, t2} -> DateTime.diff(t2, t1, :minute) end)
    
    Enum.any?(gaps, & &1 > 10)
  end
  
  defp find_participant_peak_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTime.truncate(:minute)
    end)
    |> Enum.max_by(fn {_time, kms} -> length(kms) end, fn -> {nil, []} end)
    |> elem(0)
  end
end