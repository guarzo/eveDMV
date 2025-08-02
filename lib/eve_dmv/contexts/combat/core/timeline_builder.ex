defmodule EveDmv.Contexts.Combat.Core.TimelineBuilder do
  @moduledoc """
  Builds comprehensive battle timelines from killmail data.

  Consolidates timeline construction functionality to provide:
  - Chronological event sequences
  - Battle phase identification
  - Key moment detection
  - Tactical flow analysis
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  """

  @doc """
  Build a complete battle timeline from killmails.
  """
  def build_timeline(killmails) when is_list(killmails) do
    events =
      killmails
      |> build_events()
      |> sort_chronologically()
      |> enrich_events()

    phases = identify_phases(events)
    key_moments = detect_key_moments(events, phases)

    {:ok,
     %{
       events: events,
       phases: phases,
       key_moments: key_moments,
       summary: build_timeline_summary(events, phases),
       flow: analyze_tactical_flow(events, phases)
     }}
  end

  @doc """
  Build timeline for a specific battle.
  """
  def build_battle_timeline(_battle_id) do
    # In real implementation, would fetch killmails for battle
    # For now, return error
    {:error, :not_implemented}
  end

  @doc """
  Get battle phases from a timeline.
  """
  def get_battle_phases(battle_id) do
    with {:ok, timeline} <- build_battle_timeline(battle_id) do
      {:ok, timeline.phases}
    end
  end

  # Private Functions

  defp build_events(killmails) do
    Enum.map(killmails, &build_event_from_killmail/1)
  end

  defp build_event_from_killmail(killmail) do
    %{
      id: killmail.killmail_id,
      time: killmail.killmail_time,
      type: :kill,
      victim: extract_victim_info(killmail),
      attackers: extract_attacker_info(killmail),
      location: %{
        system_id: killmail.solar_system_id,
        position: get_in(killmail.victim, ["position"])
      },
      value: get_in(killmail.zkb, ["totalValue"]) || 0,
      is_pod_kill: pod_kill?(killmail),
      is_capital_kill: capital_kill?(killmail),
      is_structure_kill: structure_kill?(killmail),
      raw_data: killmail
    }
  end

  defp extract_victim_info(killmail) do
    victim = killmail.victim || %{}

    %{
      character_id: victim["character_id"],
      character_name: victim["character_name"],
      corporation_id: victim["corporation_id"],
      corporation_name: victim["corporation_name"],
      alliance_id: victim["alliance_id"],
      alliance_name: victim["alliance_name"],
      ship_type_id: victim["ship_type_id"],
      ship_name: victim["ship_name"],
      damage_taken: victim["damage_taken"] || 0
    }
  end

  defp extract_attacker_info(killmail) do
    (killmail.attackers || [])
    |> Enum.map(fn attacker ->
      %{
        character_id: attacker["character_id"],
        character_name: attacker["character_name"],
        corporation_id: attacker["corporation_id"],
        corporation_name: attacker["corporation_name"],
        alliance_id: attacker["alliance_id"],
        alliance_name: attacker["alliance_name"],
        ship_type_id: attacker["ship_type_id"],
        ship_name: attacker["ship_type_name"],
        damage_done: attacker["damage_done"] || 0,
        final_blow: attacker["final_blow"] || false,
        weapon_type_id: attacker["weapon_type_id"]
      }
    end)
    |> Enum.reject(&is_nil(&1.character_id))
  end

  defp sort_chronologically(events) do
    Enum.sort_by(events, & &1.time, DateTime)
  end

  defp enrich_events(events) do
    events
    |> add_time_deltas()
    |> add_running_totals()
    |> add_momentum_shifts()
  end

  defp add_time_deltas(events) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, index} ->
      if index > 0 do
        previous_event = Enum.at(events, index - 1)
        delta = DateTimeUtils.diff(event.time, previous_event.time, :second)
        Map.put(event, :time_since_last, delta)
      else
        Map.put(event, :time_since_last, 0)
      end
    end)
  end

  defp add_running_totals(events) do
    events
    |> Enum.reduce({[], %{kills: 0, isk_destroyed: 0}}, fn event, {acc, totals} ->
      new_totals = %{
        kills: totals.kills + 1,
        isk_destroyed: totals.isk_destroyed + event.value
      }

      enriched_event =
        event
        |> Map.put(:running_kills, new_totals.kills)
        |> Map.put(:running_isk_destroyed, new_totals.isk_destroyed)

      {[enriched_event | acc], new_totals}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp add_momentum_shifts(events) do
    # Analyze kill patterns to detect momentum changes
    events
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.map(fn window ->
      analyze_momentum_window(window)
    end)
    |> then(fn momentum_data ->
      Enum.zip(events, momentum_data ++ List.duplicate(nil, 4))
      |> Enum.map(fn {event, momentum} ->
        Map.put(event, :momentum, momentum)
      end)
    end)
  end

  defp analyze_momentum_window(events) do
    # Simplified momentum analysis
    kill_rate = length(events) / 5.0
    avg_value = Enum.reduce(events, 0, &(&1.value + &2)) / length(events)

    %{
      kill_rate: kill_rate,
      intensity: categorize_intensity(kill_rate),
      avg_value: avg_value
    }
  end

  defp identify_phases(events) do
    # Group events into battle phases based on activity patterns
    events
    |> chunk_by_activity()
    |> Enum.map(&analyze_phase/1)
    |> merge_short_phases()
  end

  defp chunk_by_activity(events) do
    # Split into chunks when there's a significant time gap
    Enum.chunk_while(
      events,
      [],
      fn event, acc ->
        if should_start_new_phase?(event, acc) do
          {:cont, Enum.reverse(acc), [event]}
        else
          {:cont, [event | acc]}
        end
      end,
      fn acc ->
        if acc == [] do
          {:cont, []}
        else
          {:cont, Enum.reverse(acc), []}
        end
      end
    )
  end

  defp should_start_new_phase?(_event, []) do
    false
  end

  defp should_start_new_phase?(event, [last | _]) do
    # New phase if more than 5 minutes since last kill
    DateTimeUtils.diff(event.time, last.time, :minute) > 5
  end

  defp analyze_phase(events) do
    %{
      id: generate_phase_id(),
      start_time: List.first(events).time,
      end_time: List.last(events).time,
      duration: calculate_phase_duration(events),
      events: events,
      kill_count: length(events),
      isk_destroyed: Enum.reduce(events, 0, &(&1.value + &2)),
      intensity: calculate_phase_intensity(events),
      type: classify_phase_type(events),
      dominant_forces: identify_dominant_forces(events)
    }
  end

  defp calculate_phase_duration(events) do
    first = List.first(events).time
    last = List.last(events).time
    DateTimeUtils.diff(last, first, :minute)
  end

  defp calculate_phase_intensity(events) do
    duration = max(calculate_phase_duration(events), 1)
    kill_rate = length(events) / duration

    categorize_intensity(kill_rate)
  end

  defp categorize_intensity(rate) when rate >= 2.0, do: :extreme
  defp categorize_intensity(rate) when rate >= 1.0, do: :high
  defp categorize_intensity(rate) when rate >= 0.5, do: :moderate
  defp categorize_intensity(_), do: :low

  defp classify_phase_type(events) do
    capital_kills = Enum.count(events, & &1.is_capital_kill)
    total_kills = length(events)

    cond do
      capital_kills / total_kills > 0.3 -> :capital_engagement
      all_same_victim_corp?(events) -> :focused_assault
      rapid_succession?(events) -> :blitz
      true -> :standard_engagement
    end
  end

  defp all_same_victim_corp?(events) do
    corps =
      events
      |> Enum.map(& &1.victim.corporation_id)
      |> Enum.uniq()

    length(corps) == 1
  end

  defp rapid_succession?(events) do
    avg_time_between =
      if length(events) > 1 do
        total_duration = DateTimeUtils.diff(List.last(events).time, List.first(events, :second).time)
        total_duration / (length(events) - 1)
      else
        999
      end

    # Less than 30 seconds between kills
    avg_time_between < 30
  end

  defp identify_dominant_forces(events) do
    # Identify which corporations/alliances are dominant in this phase
    attacker_stats =
      events
      |> Enum.flat_map(& &1.attackers)
      |> Enum.group_by(& &1.corporation_id)
      |> Enum.map(fn {corp_id, attackers} ->
        %{
          corporation_id: corp_id,
          kill_participation: length(attackers),
          damage_done: Enum.reduce(attackers, 0, &(&1.damage_done + &2))
        }
      end)
      |> Enum.sort_by(& &1.kill_participation, :desc)
      |> Enum.take(3)

    victim_stats =
      events
      |> Enum.map(& &1.victim.corporation_id)
      |> Enum.frequencies()
      |> Enum.map(fn {corp_id, count} ->
        %{corporation_id: corp_id, losses: count}
      end)
      |> Enum.sort_by(& &1.losses, :desc)
      |> Enum.take(3)

    %{
      dominant_attackers: attacker_stats,
      primary_victims: victim_stats
    }
  end

  defp merge_short_phases(phases) do
    # Merge phases that are too short or too close together
    phases
    |> Enum.reduce([], fn phase, acc ->
      case acc do
        [] ->
          [phase]

        [last | rest] ->
          if should_merge_phases?(last, phase) do
            [merge_phases(last, phase) | rest]
          else
            [phase | acc]
          end
      end
    end)
    |> Enum.reverse()
  end

  defp should_merge_phases?(phase1, phase2) do
    gap = DateTimeUtils.diff(phase2.start_time, phase1.end_time, :minute)
    phase1.duration < 3 || phase2.duration < 3 || gap < 2
  end

  defp merge_phases(phase1, phase2) do
    %{
      id: phase1.id,
      start_time: phase1.start_time,
      end_time: phase2.end_time,
      duration: DateTimeUtils.diff(phase2.end_time, phase1.start_time, :minute),
      events: phase1.events ++ phase2.events,
      kill_count: phase1.kill_count + phase2.kill_count,
      isk_destroyed: phase1.isk_destroyed + phase2.isk_destroyed,
      intensity: max(phase1.intensity, phase2.intensity),
      type: :complex_engagement,
      dominant_forces: merge_dominant_forces(phase1.dominant_forces, phase2.dominant_forces)
    }
  end

  defp merge_dominant_forces(forces1, _forces2) do
    # Simplified merge - in real implementation would properly combine stats
    forces1
  end

  defp detect_key_moments(events, phases) do
    # First blood
    first_blood_moments =
      if length(events) > 0 do
        [
          %{
            type: :first_blood,
            time: List.first(events).time,
            event: List.first(events),
            description: "Battle begins"
          }
        ]
      else
        []
      end

    # Capital losses
    capital_losses = Enum.filter(events, & &1.is_capital_kill)

    capital_moments =
      first_blood_moments ++
        Enum.map(capital_losses, fn event ->
          %{
            type: :capital_loss,
            time: event.time,
            event: event,
            description: "Capital ship destroyed"
          }
        end)

    # Turning points (momentum shifts)
    turning_points = detect_turning_points(events, phases)
    turning_point_moments = capital_moments ++ turning_points

    # Peak intensity
    peak_phase = Enum.max_by(phases, & &1.intensity, fn -> nil end)

    peak_moments =
      if peak_phase do
        [
          %{
            type: :peak_intensity,
            time: peak_phase.start_time,
            phase: peak_phase,
            description: "Peak battle intensity reached"
          }
          | turning_point_moments
        ]
      else
        turning_point_moments
      end

    Enum.sort_by(peak_moments, & &1.time, DateTime)
  end

  defp detect_turning_points(_events, phases) do
    # Detect significant shifts in battle momentum
    phases
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [phase1, phase2] ->
      # Look for significant changes in dominant forces
      phase1.dominant_forces != phase2.dominant_forces
    end)
    |> Enum.map(fn [_phase1, phase2] ->
      %{
        type: :momentum_shift,
        time: phase2.start_time,
        phase: phase2,
        description: "Battle momentum shifts"
      }
    end)
  end

  defp build_timeline_summary(events, phases) do
    %{
      total_duration: calculate_total_duration(events),
      total_kills: length(events),
      total_isk_destroyed: Enum.reduce(events, 0, &(&1.value + &2)),
      phase_count: length(phases),
      average_intensity: calculate_average_intensity(phases),
      peak_activity_time: find_peak_activity_time(phases)
    }
  end

  defp calculate_total_duration([]), do: 0

  defp calculate_total_duration(events) do
    first = List.first(events).time
    last = List.last(events).time
    DateTimeUtils.diff(last, first, :minute)
  end

  defp calculate_average_intensity(phases) do
    if length(phases) > 0 do
      intensity_values =
        phases
        |> Enum.map(&intensity_to_number(&1.intensity))

      sum = Enum.sum(intensity_values)
      avg = sum / length(intensity_values)

      number_to_intensity(avg)
    else
      :none
    end
  end

  defp intensity_to_number(:extreme), do: 4
  defp intensity_to_number(:high), do: 3
  defp intensity_to_number(:moderate), do: 2
  defp intensity_to_number(:low), do: 1
  defp intensity_to_number(_), do: 0

  defp number_to_intensity(n) when n >= 3.5, do: :extreme
  defp number_to_intensity(n) when n >= 2.5, do: :high
  defp number_to_intensity(n) when n >= 1.5, do: :moderate
  defp number_to_intensity(n) when n >= 0.5, do: :low
  defp number_to_intensity(_), do: :none

  defp find_peak_activity_time(phases) do
    phases
    |> Enum.max_by(& &1.kill_count, fn -> nil end)
    |> case do
      nil -> nil
      phase -> phase.start_time
    end
  end

  defp analyze_tactical_flow(events, phases) do
    %{
      opening_moves: analyze_opening(List.first(phases)),
      escalation_pattern: analyze_escalation(phases),
      conclusion_type: analyze_conclusion(List.last(phases)),
      force_commitment: analyze_force_commitment(events, phases)
    }
  end

  defp analyze_opening(nil), do: :unknown

  defp analyze_opening(first_phase) do
    cond do
      first_phase.intensity == :extreme -> :hot_drop
      first_phase.kill_count == 1 -> :ganking
      first_phase.type == :focused_assault -> :planned_assault
      true -> :chance_encounter
    end
  end

  defp analyze_escalation(phases) do
    intensities = Enum.map(phases, & &1.intensity)

    cond do
      increasing_intensity?(intensities) -> :escalating
      decreasing_intensity?(intensities) -> :de_escalating
      stable_intensity?(intensities) -> :sustained
      true -> :chaotic
    end
  end

  defp increasing_intensity?(intensities) do
    intensities
    |> Enum.map(&intensity_to_number/1)
    |> then(fn numbers ->
      numbers == Enum.sort(numbers)
    end)
  end

  defp decreasing_intensity?(intensities) do
    intensities
    |> Enum.map(&intensity_to_number/1)
    |> then(fn numbers ->
      numbers == Enum.sort(numbers, :desc)
    end)
  end

  defp stable_intensity?(intensities) do
    intensities
    |> Enum.uniq()
    |> length() == 1
  end

  defp analyze_conclusion(nil), do: :unknown

  defp analyze_conclusion(last_phase) do
    cond do
      last_phase.intensity == :low && last_phase.kill_count < 3 -> :withdrawal
      last_phase.type == :focused_assault -> :decisive_victory
      last_phase.duration > 10 -> :attrition
      true -> :standard
    end
  end

  defp analyze_force_commitment(events, phases) do
    unique_attackers =
      events
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.character_id)
      |> Enum.uniq()
      |> length()

    %{
      total_participants: unique_attackers,
      commitment_level: categorize_commitment(unique_attackers),
      reinforcement_pattern: detect_reinforcement_pattern(phases)
    }
  end

  defp categorize_commitment(participant_count) do
    cond do
      participant_count >= 100 -> :full_fleet
      participant_count >= 50 -> :heavy_commitment
      participant_count >= 25 -> :moderate_commitment
      participant_count >= 10 -> :light_commitment
      true -> :skirmish
    end
  end

  defp detect_reinforcement_pattern(phases) do
    participant_growth =
      phases
      |> Enum.map(fn phase ->
        phase.events
        |> Enum.flat_map(& &1.attackers)
        |> Enum.map(& &1.character_id)
        |> Enum.uniq()
        |> length()
      end)

    cond do
      growing_participation?(participant_growth) -> :continuous_reinforcement
      stable_participation?(participant_growth) -> :no_reinforcement
      true -> :sporadic_reinforcement
    end
  end

  defp growing_participation?(counts) do
    counts == Enum.sort(counts)
  end

  defp stable_participation?(counts) do
    if length(counts) > 0 do
      min = Enum.min(counts)
      max = Enum.max(counts)
      (max - min) / max < 0.2
    else
      true
    end
  end

  defp pod_kill?(killmail) do
    # Capsule
    get_in(killmail.victim, ["ship_type_id"]) == 670
  end

  defp capital_kill?(killmail) do
    ship_type = get_in(killmail.victim, ["ship_type_id"]) || 0
    # Simplified check
    ship_type > 20_000
  end

  defp structure_kill?(killmail) do
    ship_type = get_in(killmail.victim, ["ship_type_id"]) || 0
    # Simplified check
    ship_type > 35_000
  end

  defp generate_phase_id do
    "phase_#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  end
end
