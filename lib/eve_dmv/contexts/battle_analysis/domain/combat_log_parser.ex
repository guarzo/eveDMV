defmodule EveDmv.Contexts.BattleAnalysis.Domain.CombatLogParser do
  @moduledoc """
  Parser for EVE Online combat logs.

  Extracts detailed combat information including:
  - Damage application (wrecking shots, glancing blows, etc)
  - Module activations (weapons, ewar, logistics)
  - Fleet broadcasts and target calling
  - Range and transversal data
  """

  require Logger

  # Combat log patterns - simplified to avoid regex syntax issues
  # We'll parse these line by line with simpler patterns

  @doc """
  Parses a combat log file and extracts combat events.

  ## Parameters
  - content: The raw combat log text
  - options: 
    - :start_time - Filter events after this time
    - :end_time - Filter events before this time
    - :pilot_name - Extract events only for this pilot

  ## Returns
  {:ok, %{
    events: [combat_event],
    summary: %{
      total_damage_dealt: integer,
      total_damage_taken: integer,
      ships_destroyed: integer,
      unique_targets: integer,
      ...
    }
  }}
  """
  def parse_combat_log(content, options \\ []) do
    lines = String.split(content, "\n", trim: true)

    events =
      lines
      |> Enum.map(&parse_line/1)
      |> Enum.filter(&(&1 != nil))
      |> filter_by_time(options[:start_time], options[:end_time])
      |> filter_by_pilot(options[:pilot_name])

    summary = generate_summary(events, options[:pilot_name])

    {:ok,
     %{
       events: events,
       summary: summary,
       metadata: extract_metadata(events)
     }}
  end

  @doc """
  Analyzes combat events to extract performance metrics.
  """
  def analyze_combat_performance(events, pilot_name) do
    pilot_events = filter_by_pilot(events, pilot_name)

    %{
      damage_application: analyze_damage_application(pilot_events),
      weapon_performance: analyze_weapon_performance(pilot_events),
      ewar_effectiveness: analyze_ewar_effectiveness(pilot_events),
      survivability: analyze_survivability(pilot_events),
      engagement_ranges: analyze_engagement_ranges(pilot_events)
    }
  end

  @doc """
  Correlates combat log events with killmail data for enhanced analysis.
  """
  def correlate_with_killmails(combat_events, killmails) do
    # Group events by approximate time windows
    # 1 minute windows
    event_windows = group_events_by_time(combat_events, 60)

    Enum.map(killmails, fn killmail ->
      # Find combat events around this killmail time
      relevant_events = find_events_near_time(event_windows, killmail.killmail_time)

      %{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        combat_events: relevant_events,
        damage_timeline: build_damage_timeline(relevant_events, killmail),
        final_blow_analysis: analyze_final_blow(relevant_events, killmail)
      }
    end)
  end

  # Private parsing functions

  defp parse_line(line) do
    cond do
      String.contains?(line, "\tCombat\t") && String.contains?(line, " from ") &&
          Regex.match?(~r/\d+ from/, line) ->
        parse_damage_line(line)

      String.contains?(line, "\tCombat\t") && String.contains?(line, "misses") &&
          String.contains?(line, "completely") ->
        parse_miss_line(line)

      String.contains?(line, "\tCombat\t") && String.contains?(line, "energy drained") ->
        parse_energy_drain_line(line)

      String.contains?(line, "\tCombat\t") ->
        parse_combat_line(line)

      String.contains?(line, "\tNotify\t") && String.contains?(line, "Session change") ->
        parse_session_line(line)

      true ->
        nil
    end
  end

  defp parse_damage_line(line) do
    # Extract timestamp from beginning of line: 04:27:08
    timestamp = extract_timestamp(line)

    # Parse format: "04:27:08\tCombat\t15 from Kragden[GI.N](Covetor) - Hornet II - Glances Off"
    case Regex.run(~r/\t(\d+) from ([^\(]+)\(([^\)]+)\) - ([^-]+) - ([^\t\n\r]+)/, line) do
      [_, damage_str, attacker_name, attacker_ship, weapon, quality_str] ->
        damage = String.to_integer(damage_str)
        from = String.trim(attacker_name)
        weapon_name = String.trim(weapon)
        quality = parse_hit_quality(String.trim(quality_str))

        %{
          type: :damage,
          timestamp: timestamp,
          damage: damage,
          from: from,
          # This log is from victim's perspective
          to: nil,
          weapon: %{weapon: weapon_name, ammo: nil},
          quality: quality,
          attacker_ship: String.trim(attacker_ship)
        }

      _ ->
        nil
    end
  end

  defp parse_miss_line(line) do
    timestamp = extract_timestamp(line)

    # Parse format: "Valkyrie II belonging to Darin Raltin misses you completely - Valkyrie II"
    case Regex.run(~r/([^\s]+) belonging to ([^\s]+) misses you completely - ([^\t\n\r]+)/, line) do
      [_, _weapon, attacker, weapon_type] ->
        %{
          type: :miss,
          timestamp: timestamp,
          from: String.trim(attacker),
          # This log is from victim's perspective  
          to: nil,
          weapon: %{weapon: String.trim(weapon_type), ammo: nil},
          damage: 0,
          quality: :miss
        }

      _ ->
        nil
    end
  end

  defp parse_energy_drain_line(line) do
    timestamp = extract_timestamp(line)

    # Parse format: "04:35:03\tCombat\t-0 GJ energy drained to [Brutix] Kragden |[GI.N] - Medium Energy Nosferatu II"
    case Regex.run(
           ~r/\t-?(\d+) GJ energy drained to \[([^\]]+)\]\s*([^\-]+) - ([^\t\n\r]+)/,
           line
         ) do
      [_, energy_str, target_ship, target_name, module] ->
        %{
          type: :ewar,
          timestamp: timestamp,
          action: "Energy drained: #{energy_str} GJ",
          ewar_type: :neut,
          energy_amount: String.to_integer(energy_str),
          target: String.trim(target_name),
          target_ship: String.trim(target_ship),
          module: String.trim(module)
        }

      _ ->
        nil
    end
  end

  defp parse_combat_line(line) do
    timestamp = extract_timestamp(line)

    # Generic combat event that doesn't match other patterns
    content =
      line
      |> String.replace(~r/^[^\t]*\tCombat\t/, "")
      |> String.trim()

    %{
      type: :combat,
      timestamp: timestamp,
      action: content
    }
  end

  defp parse_session_line(line) do
    timestamp = extract_timestamp(line)

    # Extract session change info
    action =
      case Regex.run(~r/Session change: (.+)$/, line) do
        [_, a] -> a
        _ -> "Unknown"
      end

    %{
      type: :session,
      timestamp: timestamp,
      action: action
    }
  end

  defp extract_timestamp(line) do
    # Extract timestamp from line: 04:27:08\tCombat\t...
    case Regex.run(~r/^(\d{2}:\d{2}:\d{2})\t/, line) do
      [_, time_str] ->
        # Parse time format: "04:27:08" - assume today's date
        today = Date.utc_today()

        case Time.from_iso8601(time_str) do
          {:ok, time} ->
            case NaiveDateTime.new(today, time) do
              {:ok, dt} -> dt
              {:error, _} -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # Parse functions integrated above

  defp parse_hit_quality(quality_str) do
    cond do
      String.contains?(quality_str, "Wrecks") -> :wrecking
      String.contains?(quality_str, "Smashes") -> :excellent
      String.contains?(quality_str, "Penetrates") -> :good
      String.contains?(quality_str, "Hits") -> :normal
      String.contains?(quality_str, "Glances Off") -> :glancing
      String.contains?(quality_str, "Grazes") -> :grazing
      true -> :normal
    end
  end

  # Analysis functions

  defp analyze_damage_application(events) do
    damage_events = Enum.filter(events, &(&1.type == :damage))

    total_shots = length(damage_events)
    hits = Enum.reject(damage_events, &(&1.quality == :miss))

    quality_breakdown =
      hits
      |> Enum.group_by(& &1.quality)
      |> Enum.map(fn {quality, events} ->
        {quality,
         %{
           count: length(events),
           percentage: length(events) / max(total_shots, 1) * 100,
           total_damage: Enum.sum(Enum.map(events, & &1.damage))
         }}
      end)
      |> Enum.into(%{})

    %{
      total_shots: total_shots,
      hit_rate: length(hits) / max(total_shots, 1) * 100,
      average_damage_per_hit: average_damage(hits),
      quality_breakdown: quality_breakdown,
      wrecking_shot_rate: Map.get(quality_breakdown, :wrecking, %{percentage: 0}).percentage
    }
  end

  defp analyze_weapon_performance(events) do
    events
    |> Enum.filter(&(&1.type == :damage && &1[:weapon]))
    |> Enum.group_by(& &1.weapon.weapon)
    |> Enum.map(fn {weapon, weapon_events} ->
      {weapon,
       %{
         shots_fired: length(weapon_events),
         total_damage: Enum.sum(Enum.map(weapon_events, & &1.damage)),
         average_damage: average_damage(weapon_events),
         hit_quality: analyze_damage_application(weapon_events)
       }}
    end)
    |> Enum.into(%{})
  end

  defp analyze_ewar_effectiveness(events) do
    events
    |> Enum.filter(&(&1.type == :ewar))
    |> Enum.group_by(& &1.ewar_type)
    |> Enum.map(fn {type, ewar_events} ->
      {type,
       %{
         activations: length(ewar_events),
         unique_targets: ewar_events |> Enum.map(& &1.ship) |> Enum.uniq() |> length()
       }}
    end)
    |> Enum.into(%{})
  end

  defp analyze_survivability(events) do
    incoming_damage =
      events
      |> Enum.filter(&(&1.type == :damage && &1[:to]))
      |> Enum.map(& &1.damage)

    %{
      total_damage_taken: Enum.sum(incoming_damage),
      incoming_shots: length(incoming_damage),
      average_incoming_damage: average_damage(incoming_damage),
      damage_timeline: build_damage_over_time(events)
    }
  end

  defp analyze_engagement_ranges(_events) do
    # This would require additional log parsing for range information
    # EVE logs don't always include range data directly
    %{
      optimal_range_percentage: 0,
      falloff_engagements: 0,
      average_engagement_range: nil
    }
  end

  # Helper functions

  defp filter_by_time(events, nil, nil), do: events

  defp filter_by_time(events, start_time, end_time) do
    Enum.filter(events, fn event ->
      start_ok = !start_time || NaiveDateTime.compare(event.timestamp, start_time) != :lt
      end_ok = !end_time || NaiveDateTime.compare(event.timestamp, end_time) != :gt
      start_ok && end_ok
    end)
  end

  defp filter_by_pilot(events, nil), do: events

  defp filter_by_pilot(events, pilot_name) do
    Enum.filter(events, fn event ->
      case event.type do
        :damage ->
          # From victim's perspective: we are the target, attacker is in 'from' field
          event.from == pilot_name || event.to == pilot_name

        :miss ->
          # From victim's perspective: we are being shot at
          event.from == pilot_name || event.to == pilot_name

        :ewar ->
          # EWAR events - check if pilot is target or source
          event[:target] == pilot_name || String.contains?(event.action || "", pilot_name)

        # Include other events for context
        _ ->
          true
      end
    end)
  end

  defp generate_summary(events, _pilot_name) do
    # For victim's perspective logs: damage FROM others TO us = damage taken
    # If pilot_name matches, this is damage taken by pilot
    pilot_damage_taken =
      events
      |> Enum.filter(&(&1.type == :damage))
      |> Enum.map(& &1.damage)
      |> Enum.sum()

    # Count unique attackers
    unique_attackers =
      events
      |> Enum.filter(&(&1.type == :damage && &1.from))
      |> Enum.map(& &1.from)
      |> Enum.uniq()
      |> length()

    # Count misses
    total_shots =
      events
      |> Enum.filter(&(&1.type in [:damage, :miss]))
      |> length()

    hits =
      events
      |> Enum.filter(&(&1.type == :damage))
      |> length()

    %{
      # This log perspective doesn't show outgoing damage
      total_damage_dealt: 0,
      total_damage_taken: pilot_damage_taken,
      # Attackers shooting at us
      unique_targets: unique_attackers,
      event_count: length(events),
      time_span: calculate_time_span(events),
      total_shots_incoming: total_shots,
      hits_taken: hits,
      hit_rate_against_us: if(total_shots > 0, do: hits / total_shots * 100, else: 0)
    }
  end

  defp extract_metadata(events) do
    participants =
      events
      |> Enum.flat_map(fn event ->
        case event.type do
          :damage -> [event.from, event.to]
          :ewar -> [event.ship]
          _ -> []
        end
      end)
      |> Enum.uniq()

    %{
      start_time: events |> Enum.map(& &1.timestamp) |> Enum.min(fn -> nil end),
      end_time: events |> Enum.map(& &1.timestamp) |> Enum.max(fn -> nil end),
      unique_participants: length(participants),
      event_types: events |> Enum.map(& &1.type) |> Enum.uniq()
    }
  end

  defp group_events_by_time(events, window_seconds) do
    events
    |> Enum.group_by(fn event ->
      if event.timestamp do
        # Round to nearest window
        unix = event.timestamp |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
        div(unix, window_seconds) * window_seconds
      else
        nil
      end
    end)
  end

  defp find_events_near_time(event_windows, target_time) do
    target_unix = target_time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()

    # Look for events within 5 minutes
    -5..5
    |> Enum.flat_map(fn offset ->
      window_key = div(target_unix + offset * 60, 60) * 60
      Map.get(event_windows, window_key, [])
    end)
  end

  defp build_damage_timeline(events, killmail) do
    damage_events =
      events
      |> Enum.filter(&(&1.type == :damage && &1.to == killmail.victim_character_name))
      |> Enum.sort_by(& &1.timestamp)

    cumulative_damage = 0

    damage_events
    |> Enum.map(fn event ->
      cumulative_damage = cumulative_damage + event.damage

      %{
        timestamp: event.timestamp,
        damage: event.damage,
        cumulative_damage: cumulative_damage,
        attacker: event.from,
        weapon: event[:weapon]
      }
    end)
  end

  defp analyze_final_blow(events, killmail) do
    # Find damage events in the last 10 seconds before the kill
    final_events =
      events
      |> Enum.filter(fn event ->
        event.type == :damage &&
          event.to == killmail.victim_character_name &&
          NaiveDateTime.diff(killmail.killmail_time, event.timestamp, :second) <= 10
      end)

    %{
      final_blow_damage: final_events |> Enum.map(& &1.damage) |> Enum.sum(),
      final_blow_quality:
        final_events
        |> List.last()
        |> case do
          nil -> nil
          event -> event.quality
        end,
      overkill_percentage: calculate_overkill(final_events, killmail)
    }
  end

  defp calculate_overkill(_events, _killmail) do
    # Would need ship EHP data to calculate actual overkill
    0
  end

  defp average_damage([]), do: 0

  defp average_damage(events) do
    total = Enum.sum(Enum.map(events, &(&1[:damage] || 0)))
    Float.round(total / Enum.count(events), 1)
  end

  defp build_damage_over_time(events) do
    events
    |> Enum.filter(&(&1.type == :damage))
    |> Enum.sort_by(& &1.timestamp)
    # Group by 10 events
    |> Enum.chunk_every(10)
    |> Enum.map(fn chunk ->
      %{
        timestamp: List.first(chunk).timestamp,
        damage_dealt: chunk |> Enum.filter(& &1[:from]) |> Enum.map(& &1.damage) |> Enum.sum(),
        damage_taken: chunk |> Enum.filter(& &1[:to]) |> Enum.map(& &1.damage) |> Enum.sum()
      }
    end)
  end

  defp calculate_time_span([]), do: 0

  defp calculate_time_span(events) do
    timestamps = events |> Enum.map(& &1.timestamp) |> Enum.filter(& &1)

    case timestamps do
      [] ->
        0

      [_] ->
        0

      _ ->
        start_time = Enum.min(timestamps)
        end_time = Enum.max(timestamps)
        NaiveDateTime.diff(end_time, start_time, :second) / 60
    end
  end
end
