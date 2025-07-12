defmodule EveDmv.Contexts.BattleAnalysis.Domain.BattleTimelineService do
  @moduledoc """
  Service for reconstructing battle timelines from clustered killmails.

  Analyzes the sequence of events, identifies key moments, tracks fleet
  compositions over time, and provides insights into battle progression.
  """

  require Logger

  @doc """
  Reconstructs a detailed timeline from battle data.

  ## Parameters
  - battle: A battle map containing killmails and metadata

  ## Returns
  A timeline structure with:
  - events: Chronological list of battle events
  - phases: Identified battle phases (initial engagement, escalation, etc.)
  - fleet_composition: How fleets changed over time
  - key_moments: Significant events (first blood, turning points, etc.)
  """
  def reconstruct_timeline(battle) do
    events = build_events_from_killmails(battle.killmails)
    phases = identify_battle_phases(events)
    fleet_composition = analyze_fleet_composition_over_time(events)
    key_moments = identify_key_moments(events, phases)

    %{
      battle_id: battle.battle_id,
      start_time: List.first(events).timestamp,
      end_time: List.last(events).timestamp,
      duration_minutes: battle.metadata.duration_minutes,
      events: events,
      phases: phases,
      fleet_composition: fleet_composition,
      key_moments: key_moments,
      summary: generate_battle_summary(events, phases, key_moments)
    }
  end

  @doc """
  Analyzes multiple battles to identify patterns and connections.
  """
  def analyze_battle_sequence(battles) when is_list(battles) do
    sorted_battles =
      Enum.sort_by(battles, fn b ->
        List.first(b.killmails).killmail_time
      end)

    %{
      battles: sorted_battles,
      connections: find_battle_connections(sorted_battles),
      escalation_pattern: analyze_escalation_pattern(sorted_battles),
      participant_flow: track_participant_flow(sorted_battles)
    }
  end

  # Private functions

  defp build_events_from_killmails(killmails) do
    killmails
    |> Enum.map(&build_event_from_killmail/1)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp build_event_from_killmail(killmail) do
    attackers = extract_attacker_details(killmail.raw_data)

    %{
      type: :kill,
      timestamp: killmail.killmail_time,
      killmail_id: killmail.killmail_id,
      victim: %{
        character_id: killmail.victim_character_id,
        corporation_id: killmail.victim_corporation_id,
        alliance_id: killmail.victim_alliance_id,
        ship_type_id: killmail.victim_ship_type_id,
        character_name: extract_victim_name(killmail.raw_data, "character_name"),
        corporation_name: extract_victim_name(killmail.raw_data, "corporation_name"),
        ship_name: extract_victim_name(killmail.raw_data, "ship_name")
      },
      attackers: attackers,
      final_blow: find_final_blow_attacker(attackers),
      total_damage: calculate_total_damage(attackers),
      attacker_count: length(attackers),
      location: %{
        solar_system_id: killmail.solar_system_id
      }
    }
  end

  defp extract_attacker_details(raw_data) do
    case raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        Enum.map(attackers, fn attacker ->
          %{
            character_id: get_attacker_id(attacker, "character_id"),
            corporation_id: get_attacker_id(attacker, "corporation_id"),
            alliance_id: get_attacker_id(attacker, "alliance_id"),
            ship_type_id: get_attacker_id(attacker, "ship_type_id"),
            weapon_type_id: get_attacker_id(attacker, "weapon_type_id"),
            damage_done: attacker["damage_done"] || 0,
            final_blow: attacker["final_blow"] || false,
            character_name: attacker["character_name"],
            corporation_name: attacker["corporation_name"],
            ship_name: attacker["ship_name"]
          }
        end)

      _ ->
        []
    end
  end

  defp get_attacker_id(attacker, field) do
    case attacker[field] do
      nil -> nil
      id when is_integer(id) -> id
      id when is_binary(id) -> String.to_integer(id)
    end
  end

  defp extract_victim_name(raw_data, field) do
    case raw_data do
      %{"victim" => victim} when is_map(victim) ->
        victim[field]

      _ ->
        nil
    end
  end

  defp find_final_blow_attacker(attackers) do
    Enum.find(attackers, & &1.final_blow) || List.first(attackers)
  end

  defp calculate_total_damage(attackers) do
    Enum.sum(Enum.map(attackers, & &1.damage_done))
  end

  defp identify_battle_phases(events) do
    # Initial engagement phase
    initial_phase = identify_initial_engagement(events)

    # Escalation phases
    escalation_phases =
      if initial_phase do
        identify_escalations(events, initial_phase)
      else
        []
      end

    initial_phases =
      if initial_phase, do: [initial_phase | escalation_phases], else: escalation_phases

    # Cleanup/final phase - only add if there are events after other phases
    last_phase_end =
      if length(initial_phases) > 0 do
        initial_phases |> Enum.map(& &1.end_time) |> Enum.max()
      else
        nil
      end

    final_phase =
      if last_phase_end do
        identify_final_phase(events, last_phase_end)
      else
        nil
      end

    all_phases =
      if final_phase, do: Enum.reverse([final_phase | initial_phases]), else: initial_phases

    all_phases
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort_by(& &1.start_time)
  end

  defp identify_initial_engagement(events) do
    case events do
      [] ->
        nil

      [first | _] ->
        # Find the initial burst of activity
        initial_events =
          Enum.take_while(events, fn event ->
            time_diff = NaiveDateTime.diff(event.timestamp, first.timestamp, :second)
            # Within 2 minutes of first kill
            time_diff <= 120
          end)

        %{
          phase_type: :initial_engagement,
          start_time: first.timestamp,
          end_time: List.last(initial_events).timestamp,
          event_count: length(initial_events),
          description: "Initial engagement with #{length(initial_events)} kills"
        }
    end
  end

  defp identify_escalations(events, initial_phase) do
    # Look for periods where kill rate increases significantly
    events
    |> Enum.chunk_every(5, 1, :discard)
    |> Enum.map(fn chunk ->
      analyze_kill_rate_change(chunk)
    end)
    |> Enum.filter(fn analysis ->
      analysis.is_escalation and
        NaiveDateTime.compare(analysis.start_time, initial_phase.end_time) == :gt
    end)
    |> Enum.map(fn analysis ->
      %{
        phase_type: :escalation,
        start_time: analysis.start_time,
        end_time: analysis.end_time,
        event_count: analysis.event_count,
        description: "Escalation phase - kill rate increased to #{analysis.kill_rate} kills/min"
      }
    end)
  end

  defp analyze_kill_rate_change(events) do
    first = List.first(events)
    last = List.last(events)
    duration_seconds = NaiveDateTime.diff(last.timestamp, first.timestamp, :second)

    kill_rate =
      if duration_seconds > 0 do
        length(events) / (duration_seconds / 60)
      else
        0.0
      end

    %{
      start_time: first.timestamp,
      end_time: last.timestamp,
      event_count: length(events),
      kill_rate: Float.round(kill_rate, 2),
      # More than 2 kills per minute
      is_escalation: kill_rate > 2.0
    }
  end

  defp identify_final_phase(events, last_phase_end) do
    # Find events after the last identified phase
    final_events =
      Enum.filter(events, fn event ->
        NaiveDateTime.compare(event.timestamp, last_phase_end) == :gt
      end)

    case final_events do
      [] ->
        nil

      [single] ->
        # Single cleanup kill
        %{
          phase_type: :cleanup,
          start_time: single.timestamp,
          end_time: single.timestamp,
          event_count: 1,
          description: "Final cleanup kill"
        }

      multiple ->
        # Multiple cleanup kills
        %{
          phase_type: :cleanup,
          start_time: List.first(multiple).timestamp,
          end_time: List.last(multiple).timestamp,
          event_count: length(multiple),
          description: "Cleanup phase with #{length(multiple)} final kills"
        }
    end
  end

  defp analyze_fleet_composition_over_time(events) do
    # Group events into time windows
    # 5-minute windows
    time_windows = chunk_events_by_time_window(events, 300)

    Enum.map(time_windows, fn {window_start, window_events} ->
      # First analyze sides
      sides = analyze_battle_sides(window_events)

      # Then analyze pilots with side assignments
      pilot_ships = analyze_ship_types_in_window(window_events, sides)

      %{
        timestamp: window_start,
        active_attackers: count_unique_attackers(window_events),
        active_victims: count_unique_victims(window_events),
        pilot_ships: pilot_ships,
        corporation_breakdown: analyze_corporation_breakdown(window_events),
        sides: sides
      }
    end)
  end

  defp chunk_events_by_time_window(events, window_seconds) do
    case events do
      [] ->
        []

      [first | _] ->
        events
        |> Enum.group_by(fn event ->
          seconds_since_start = NaiveDateTime.diff(event.timestamp, first.timestamp, :second)
          window_index = div(seconds_since_start, window_seconds)
          NaiveDateTime.add(first.timestamp, window_index * window_seconds, :second)
        end)
        |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
    end
  end

  defp count_unique_attackers(events) do
    events
    |> Enum.flat_map(& &1.attackers)
    |> Enum.map(& &1.character_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_victims(events) do
    events
    |> Enum.map(& &1.victim.character_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp analyze_ship_types_in_window(events, sides_analysis) do
    # Analyze individual pilots and their ships
    events
    |> Enum.flat_map(fn event ->
      # Add victim as a pilot
      victim_entry =
        if event.victim.character_id do
          [
            %{
              character_id: event.victim.character_id,
              character_name: event.victim.character_name,
              corporation_id: event.victim.corporation_id,
              corporation_name: event.victim.corporation_name,
              alliance_id: event.victim.alliance_id,
              ship_type_id: event.victim.ship_type_id,
              ship_name: event.victim.ship_name,
              damage_taken: event.total_damage,
              damage_given: 0,
              kills: 0,
              losses: 1,
              is_victim: true
            }
          ]
        else
          []
        end

      # Add attackers as pilots
      attacker_entries =
        event.attackers
        |> Enum.filter(&(&1.character_id && &1.ship_type_id))
        |> Enum.map(fn attacker ->
          %{
            character_id: attacker.character_id,
            character_name: attacker.character_name,
            corporation_id: attacker.corporation_id,
            corporation_name: attacker.corporation_name,
            alliance_id: attacker.alliance_id,
            ship_type_id: attacker.ship_type_id,
            ship_name: attacker.ship_name,
            damage_taken: 0,
            damage_given: attacker.damage_done,
            kills: if(attacker.final_blow, do: 1, else: 0),
            losses: 0,
            is_victim: false
          }
        end)

      victim_entry ++ attacker_entries
    end)
    |> Enum.group_by(fn pilot ->
      # Group by character and ship to aggregate stats
      {pilot.character_id, pilot.ship_type_id}
    end)
    |> Enum.map(fn {{char_id, ship_id}, pilot_entries} ->
      # Aggregate stats for same pilot/ship combo
      first = List.first(pilot_entries)

      %{
        character_id: char_id,
        character_name: first.character_name,
        corporation_id: first.corporation_id,
        corporation_name: first.corporation_name,
        alliance_id: first.alliance_id,
        ship_type_id: ship_id,
        ship_name: first.ship_name,
        damage_taken: Enum.sum(Enum.map(pilot_entries, & &1.damage_taken)),
        damage_given: Enum.sum(Enum.map(pilot_entries, & &1.damage_given)),
        kills: Enum.sum(Enum.map(pilot_entries, & &1.kills)),
        losses: Enum.sum(Enum.map(pilot_entries, & &1.losses)),
        # Determine side based on corporation
        side: determine_pilot_side_from_analysis(first, sides_analysis)
      }
    end)
    |> Enum.sort_by(&(&1.damage_given + &1.damage_taken), :desc)
  end

  defp determine_pilot_side_from_analysis(pilot, sides_analysis) do
    # Find which side this pilot's corporation belongs to
    Enum.find_value(sides_analysis, fn side ->
      if pilot.corporation_id in side.corporations do
        side.side_id
      else
        nil
      end
    end) || "unassigned"
  end

  defp analyze_corporation_breakdown(events) do
    victim_corps =
      events
      |> Enum.map(& &1.victim.corporation_id)
      |> Enum.filter(&(&1 != nil))

    attacker_corps =
      events
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.corporation_id)
      |> Enum.filter(&(&1 != nil))

    %{
      victim_corporations: Enum.frequencies(victim_corps),
      attacker_corporations: Enum.frequencies(attacker_corps)
    }
  end

  defp analyze_battle_sides(events) do
    # Build a graph of who attacked whom
    interactions =
      Enum.flat_map(events, fn event ->
        victim_corp = event.victim.corporation_id
        victim_alliance = event.victim.alliance_id
        victim_corp_name = event.victim.corporation_name

        Enum.map(event.attackers, fn attacker ->
          %{
            attacker_corp: attacker.corporation_id,
            attacker_alliance: attacker.alliance_id,
            attacker_corp_name: attacker.corporation_name,
            victim_corp: victim_corp,
            victim_alliance: victim_alliance,
            victim_corp_name: victim_corp_name,
            damage: attacker.damage_done
          }
        end)
      end)

    # Group corporations by their alliance or standalone
    corp_groups =
      interactions
      |> Enum.flat_map(fn i ->
        [
          {i.attacker_corp, i.attacker_alliance || "standalone_#{i.attacker_corp}"},
          {i.victim_corp, i.victim_alliance || "standalone_#{i.victim_corp}"}
        ]
      end)
      |> Enum.uniq()
      |> Enum.group_by(fn {_corp, group} -> group end, fn {corp, _} -> corp end)

    # Calculate damage dealt between groups
    group_interactions =
      interactions
      |> Enum.group_by(fn i ->
        attacker_group =
          Map.get(
            corp_groups,
            i.attacker_corp,
            i.attacker_alliance || "standalone_#{i.attacker_corp}"
          )

        victim_group =
          Map.get(corp_groups, i.victim_corp, i.victim_alliance || "standalone_#{i.victim_corp}")

        {attacker_group, victim_group}
      end)
      |> Enum.map(fn {{attacker_group, victim_group}, interactions} ->
        %{
          attacker_group: attacker_group,
          victim_group: victim_group,
          total_damage: Enum.sum(Enum.map(interactions, & &1.damage)),
          interaction_count: length(interactions)
        }
      end)

    # Identify sides based on who shoots whom
    identify_sides_from_interactions(corp_groups, group_interactions)
  end

  defp identify_sides_from_interactions(corp_groups, interactions) do
    # Simple algorithm: groups that shoot each other are on different sides
    # Groups that don't shoot each other are on the same side

    groups = Map.keys(corp_groups)

    # Build adjacency list of hostile relationships
    hostile_map =
      interactions
      |> Enum.reduce(%{}, fn interaction, acc ->
        if interaction.attacker_group != interaction.victim_group do
          acc
          |> Map.update(
            interaction.attacker_group,
            [interaction.victim_group],
            &[interaction.victim_group | &1]
          )
          |> Map.update(
            interaction.victim_group,
            [interaction.attacker_group],
            &[interaction.attacker_group | &1]
          )
        else
          acc
        end
      end)

    # Group into sides based on hostile relationships
    sides =
      groups
      |> Enum.reduce({[], []}, fn group, {assigned, sides} ->
        if group in assigned do
          {assigned, sides}
        else
          # Find which side this group belongs to
          side_index =
            sides
            |> Enum.find_index(fn side_groups ->
              # Check if this group is hostile to any group in this side
              not Enum.any?(side_groups, fn side_group ->
                Map.get(hostile_map, group, [])
                |> Enum.member?(side_group)
              end)
            end)

          if side_index do
            # Add to existing side
            updated_sides = List.update_at(sides, side_index, &[group | &1])
            {[group | assigned], updated_sides}
          else
            # Create new side
            {[group | assigned], [[group] | sides]}
          end
        end
      end)
      |> elem(1)

    # Convert to detailed side information
    sides
    |> Enum.with_index()
    |> Enum.map(fn {side_groups, index} ->
      corps =
        side_groups
        |> Enum.flat_map(fn group -> Map.get(corp_groups, group, []) end)
        |> Enum.uniq()

      %{
        side_id: "side_#{index + 1}",
        groups: side_groups,
        corporations: corps,
        participant_count: count_participants_for_corps(corps, interactions)
      }
    end)
  end

  defp count_participants_for_corps(corps, _interactions) do
    # Simplified - in production would count unique characters
    length(corps)
  end

  defp identify_key_moments(events, phases) do
    base_moments = []

    # First blood
    first_blood_moments =
      if first_blood = List.first(events) do
        [
          %{
            type: :first_blood,
            timestamp: first_blood.timestamp,
            description: "First kill of the battle",
            event: first_blood
          }
        ]
      else
        []
      end

    # Largest kill (by attacker count)
    largest_kill_moments =
      if largest_kill = Enum.max_by(events, & &1.attacker_count, fn -> nil end) do
        [
          %{
            type: :largest_engagement,
            timestamp: largest_kill.timestamp,
            description: "Largest kill with #{largest_kill.attacker_count} attackers",
            event: largest_kill
          }
        ]
      else
        []
      end

    # Identify kill streaks
    kill_streak_moments = identify_kill_streaks(events)

    # Combine all moments
    moments = base_moments ++ first_blood_moments ++ largest_kill_moments ++ kill_streak_moments

    # Add phase transitions as key moments
    phase_transitions =
      phases
      |> Enum.map(fn phase ->
        %{
          type: :phase_transition,
          timestamp: phase.start_time,
          description: "#{phase.phase_type} began",
          phase: phase
        }
      end)

    (moments ++ phase_transitions)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp identify_kill_streaks(events) do
    events
    |> Enum.chunk_while(
      {nil, []},
      fn event, {last_killer, streak} ->
        current_killer = event.final_blow.character_id

        cond do
          last_killer == nil ->
            {:cont, {current_killer, [event]}}

          current_killer == last_killer ->
            {:cont, {current_killer, [event | streak]}}

          length(streak) >= 3 ->
            {:cont,
             %{
               type: :kill_streak,
               character_id: last_killer,
               kills: Enum.reverse(streak),
               timestamp: List.last(streak).timestamp
             }, {current_killer, [event]}}

          true ->
            {:cont, {current_killer, [event]}}
        end
      end,
      fn
        {_last_killer, streak} when length(streak) >= 3 ->
          {:cont,
           %{
             type: :kill_streak,
             character_id: List.first(streak).final_blow.character_id,
             kills: Enum.reverse(streak),
             timestamp: List.last(streak).timestamp
           }, []}

        _ ->
          {:cont, []}
      end
    )
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn streak ->
      %{
        type: :kill_streak,
        timestamp: streak.timestamp,
        description: "#{length(streak.kills)}-kill streak by character #{streak.character_id}",
        character_id: streak.character_id,
        kill_count: length(streak.kills)
      }
    end)
  end

  defp generate_battle_summary(events, phases, key_moments) do
    phase_names = Enum.map(phases, & &1.phase_type) |> Enum.join(", ")
    key_moment_count = length(key_moments)

    %{
      total_kills: length(events),
      phases: phase_names,
      key_moments: key_moment_count,
      description:
        "Battle with #{length(events)} kills across #{length(phases)} phases, featuring #{key_moment_count} key moments"
    }
  end

  defp find_battle_connections(battles) do
    # Find battles that might be connected (same participants, nearby systems, etc.)
    battles
    |> Enum.with_index()
    |> Enum.flat_map(fn {battle1, idx1} ->
      battles
      |> Enum.drop(idx1 + 1)
      |> Enum.with_index(idx1 + 1)
      |> Enum.filter(fn {battle2, _idx2} ->
        are_battles_connected?(battle1, battle2)
      end)
      |> Enum.map(fn {battle2, _idx2} ->
        %{
          battle1_id: battle1.battle_id,
          battle2_id: battle2.battle_id,
          connection_type: determine_connection_type(battle1, battle2),
          time_gap_minutes: calculate_time_gap(battle1, battle2)
        }
      end)
    end)
  end

  defp are_battles_connected?(battle1, battle2) do
    # Check if battles are within 30 minutes and share participants
    time_gap = calculate_time_gap(battle1, battle2)

    if time_gap <= 30 do
      participants1 = extract_all_participants(battle1)
      participants2 = extract_all_participants(battle2)

      shared_participants =
        MapSet.intersection(
          MapSet.new(participants1),
          MapSet.new(participants2)
        )

      MapSet.size(shared_participants) > 0
    else
      false
    end
  end

  defp determine_connection_type(battle1, battle2) do
    # Analyze the nature of the connection
    if battle1.metadata.primary_system == battle2.metadata.primary_system do
      :same_system_continuation
    else
      :roaming_gang
    end
  end

  defp calculate_time_gap(battle1, battle2) do
    end_time1 = List.last(battle1.killmails).killmail_time
    start_time2 = List.first(battle2.killmails).killmail_time

    NaiveDateTime.diff(start_time2, end_time1, :second) / 60
  end

  defp extract_all_participants(battle) do
    battle.killmails
    |> Enum.flat_map(fn km ->
      victim = [km.victim_character_id]

      attackers =
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            attackers
            |> Enum.map(&get_attacker_id(&1, "character_id"))
            |> Enum.filter(&(&1 != nil))

          _ ->
            []
        end

      victim ++ attackers
    end)
    |> Enum.uniq()
  end

  defp analyze_escalation_pattern(battles) do
    # Track how battles grow or shrink over time
    battles
    |> Enum.map(fn battle ->
      %{
        battle_id: battle.battle_id,
        participant_count: battle.metadata.unique_participants,
        kill_count: length(battle.killmails),
        timestamp: List.first(battle.killmails).killmail_time
      }
    end)
  end

  defp track_participant_flow(battles) do
    # Track how participants move between battles
    battles
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [battle1, battle2] ->
      participants1 = MapSet.new(extract_all_participants(battle1))
      participants2 = MapSet.new(extract_all_participants(battle2))

      %{
        from_battle: battle1.battle_id,
        to_battle: battle2.battle_id,
        continuing_participants:
          participants1 |> MapSet.intersection(participants2) |> MapSet.size(),
        new_participants: participants2 |> MapSet.difference(participants1) |> MapSet.size(),
        departing_participants: participants1 |> MapSet.difference(participants2) |> MapSet.size()
      }
    end)
  end
end
