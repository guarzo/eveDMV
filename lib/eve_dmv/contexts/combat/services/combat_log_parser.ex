defmodule EveDmv.Contexts.Combat.Services.CombatLogParser do
  @moduledoc """
  Service for parsing EVE Online combat logs.

  Handles:
  - Parsing combat log files in various formats
  - Extracting combat events and damage information
  - Reconstructing battles from log data
  - Converting log data to analyzable format
  """

  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Contexts.Combat.Resources.CombatLog
  alias EveDmv.Contexts.Combat.Services.BattleService

  require Logger

  @combat_log_regex ~r/^\[\s*(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})\s*\]\s*(.+)$/
  @damage_regex ~r/\(combat\)\s*<[^>]+><[^>]+>\s*(.+?)\s*(?:-|from)\s*(.+?)\s*-\s*(.+?)\s*-\s*(.+)$/
  @warp_regex ~r/\(notify\)\s*Warping to\s+(.+)\s+(.+)$/
  @session_regex ~r/Session started:\s*(\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2})$/

  @doc """
  Parse a combat log file and extract combat events.
  """
  def parse_combat_log(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, events} <- parse_log_content(content),
         {:ok, processed} <- process_combat_events(events) do
      Logger.info("Parsed #{length(processed.events)} combat events from log")
      {:ok, processed}
    else
      {:error, reason} = error ->
        Logger.error("Failed to parse combat log: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Parse combat log from string content.
  """
  def parse_log_content(content) when is_binary(content) do
    lines = String.split(content, "\n", trim: true)

    events =
      lines
      |> Enum.map(&parse_log_line/1)
      |> Enum.reject(&is_nil/1)
      |> add_session_context()

    {:ok, events}
  end

  @doc """
  Import combat log and create associated battles.
  """
  def import_combat_log(file_path, opts \\ []) do
    with {:ok, parsed} <- parse_combat_log(file_path),
         {:ok, combat_log} <- save_combat_log(parsed, opts),
         {:ok, battles} <- detect_battles_from_log(parsed) do
      # Link battles to combat log
      Enum.each(battles, fn battle ->
        link_battle_to_log(battle.id, combat_log.id)
      end)

      {:ok,
       %{
         combat_log: combat_log,
         battles: battles,
         events: length(parsed.events)
       }}
    end
  end

  @doc """
  Extract damage statistics from combat log.
  """
  def extract_damage_stats(combat_log_id) do
    with {:ok, log} <- get_combat_log(combat_log_id),
         {:ok, events} <- parse_log_content(log.content) do
      damage_events = Enum.filter(events, &(&1.type == :damage))

      stats = %{
        total_damage_dealt: calculate_total_damage_dealt(damage_events),
        total_damage_received: calculate_total_damage_received(damage_events),
        damage_by_type: group_damage_by_type(damage_events),
        damage_by_ship: group_damage_by_ship(damage_events),
        damage_timeline: build_damage_timeline(damage_events),
        peak_dps: calculate_peak_dps(damage_events),
        average_dps: calculate_average_dps(damage_events)
      }

      {:ok, stats}
    end
  end

  @doc """
  Convert combat log to standard killmail format.
  """
  def convert_to_killmail_format(combat_log_id) do
    with {:ok, log} <- get_combat_log(combat_log_id),
         {:ok, events} <- parse_log_content(log.content) do
      # Group events by target destruction
      destruction_events = identify_destruction_events(events)

      killmails =
        Enum.map(destruction_events, fn destruction ->
          build_killmail_from_destruction(destruction, events)
        end)

      {:ok, killmails}
    end
  end

  # Private Functions

  defp parse_log_line(line) do
    cond do
      match = Regex.run(@combat_log_regex, line) ->
        [_, timestamp, content] = match
        parse_combat_content(timestamp, content)

      match = Regex.run(@session_regex, line) ->
        [_, timestamp] = match

        %{
          type: :session_start,
          timestamp: parse_timestamp(timestamp),
          raw: line
        }

      true ->
        nil
    end
  end

  defp parse_combat_content(timestamp, content) do
    parsed_time = parse_timestamp(timestamp)

    cond do
      match = Regex.run(@damage_regex, content) ->
        parse_damage_event(parsed_time, match, content)

      match = Regex.run(@warp_regex, content) ->
        parse_warp_event(parsed_time, match, content)

      String.contains?(content, ["(combat)", "(notify)"]) ->
        %{
          type: :other_combat,
          timestamp: parsed_time,
          content: content,
          raw: content
        }

      true ->
        nil
    end
  end

  defp parse_damage_event(timestamp, [_, _full_match, _source, target, weapon, damage_info], raw) do
    {damage_amount, damage_type} = parse_damage_info(damage_info)

    %{
      type: :damage,
      timestamp: timestamp,
      source: extract_entity_name(raw, "from"),
      target: clean_entity_name(target),
      weapon: clean_weapon_name(weapon),
      damage: damage_amount,
      damage_type: damage_type,
      raw: raw
    }
  end

  defp parse_warp_event(timestamp, [_, location, _distance], raw) do
    %{
      type: :warp,
      timestamp: timestamp,
      destination: location,
      raw: raw
    }
  end

  defp parse_timestamp(timestamp_str) do
    # EVE logs use format: "2024.01.15 14:30:45"
    case Regex.run(~r/(\d{4})\.(\d{2})\.(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/, timestamp_str) do
      [_, year, month, day, hour, minute, second] ->
        {:ok, datetime} =
          NaiveDateTime.new(
            String.to_integer(year),
            String.to_integer(month),
            String.to_integer(day),
            String.to_integer(hour),
            String.to_integer(minute),
            String.to_integer(second)
          )

        DateTime.from_naive!(datetime, "Etc/UTC")

      _ ->
        DateTime.utc_now()
    end
  end

  defp parse_damage_info(damage_str) do
    # Parse damage string like "115 damage" or "Grazes - 89 damage"
    case Regex.run(~r/(\d+)\s*damage/, damage_str) do
      [_, damage] ->
        amount = String.to_integer(damage)

        type =
          cond do
            String.contains?(damage_str, "Wrecks") -> :wrecking
            String.contains?(damage_str, "Smashes") -> :smashing
            String.contains?(damage_str, "Penetrates") -> :penetrating
            String.contains?(damage_str, "Hits") -> :solid
            String.contains?(damage_str, "Glances") -> :glancing
            String.contains?(damage_str, "Grazes") -> :grazing
            true -> :unknown
          end

        {amount, type}

      _ ->
        {0, :unknown}
    end
  end

  defp extract_entity_name(raw, prefix) do
    # Extract entity name that appears after a prefix
    case Regex.run(~r/#{prefix}\s+([^-]+)\s*-/, raw) do
      [_, name] -> clean_entity_name(name)
      _ -> "Unknown"
    end
  end

  defp clean_entity_name(name) do
    name
    |> String.trim()
    |> String.replace(~r/<[^>]+>/, "")
    |> String.trim()
  end

  defp clean_weapon_name(weapon) do
    weapon
    |> String.trim()
    |> String.replace(~r/\s*\[.+\]$/, "")
  end

  defp add_session_context(events) do
    # Add session information to events
    {contextualized, _} =
      events
      |> Enum.reduce({[], nil}, fn event, {acc, current_session} ->
        case event.type do
          :session_start ->
            {[event | acc], event.timestamp}

          _ ->
            event_with_session =
              if current_session do
                Map.put(event, :session_start, current_session)
              else
                event
              end

            {[event_with_session | acc], current_session}
        end
      end)

    Enum.reverse(contextualized)
  end

  defp process_combat_events(events) do
    damage_events = Enum.filter(events, &(&1.type == :damage))

    processed = %{
      events: events,
      damage_events: damage_events,
      participants: extract_participants(damage_events),
      weapons_used: extract_weapons(damage_events),
      time_span: calculate_time_span(events),
      sessions: extract_sessions(events)
    }

    {:ok, processed}
  end

  defp extract_participants(damage_events) do
    sources = Enum.map(damage_events, & &1.source) |> Enum.uniq()
    targets = Enum.map(damage_events, & &1.target) |> Enum.uniq()

    %{
      all: Enum.uniq(sources ++ targets),
      sources: sources,
      targets: targets
    }
  end

  defp extract_weapons(damage_events) do
    damage_events
    |> Enum.map(& &1.weapon)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_weapon, count} -> count end, :desc)
  end

  defp calculate_time_span([]), do: %{start: nil, end: nil, duration: 0}

  defp calculate_time_span(events) do
    sorted = Enum.sort_by(events, & &1.timestamp)
    first = List.first(sorted).timestamp
    last = List.last(sorted).timestamp

    %{
      start: first,
      end: last,
      duration: DateTime.diff(last, first, :second)
    }
  end

  defp extract_sessions(events) do
    events
    |> Enum.filter(&(&1.type == :session_start))
    |> Enum.map(& &1.timestamp)
  end

  defp save_combat_log(parsed_data, opts) do
    character_id = Keyword.get(opts, :character_id)

    log_data = %{
      character_id: character_id,
      log_timestamp: parsed_data.time_span.start,
      duration_seconds: parsed_data.time_span.duration,
      event_count: length(parsed_data.events),
      participant_count: length(parsed_data.participants.all),
      metadata: %{
        weapons: Map.new(parsed_data.weapons_used),
        sessions: parsed_data.sessions
      },
      content: encode_events(parsed_data.events),
      created_at: DateTime.utc_now()
    }

    CombatLog
    |> Ash.Changeset.for_create(:create, log_data)
    |> Ash.create()
  end

  defp encode_events(events) do
    # Encode events as JSON for storage
    Jason.encode!(events)
  end

  defp detect_battles_from_log(parsed_data) do
    # Convert damage events to pseudo-killmails for battle detection
    pseudo_killmails =
      parsed_data.damage_events
      |> group_by_destruction()
      |> Enum.map(&create_pseudo_killmail/1)

    case BattleDetector.detect_battles(pseudo_killmails) do
      {:ok, battles} ->
        # Create battle records
        created =
          Enum.map(battles, fn battle_data ->
            case BattleService.create_battle(battle_data) do
              {:ok, battle} -> battle
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, created}

      _ ->
        {:ok, []}
    end
  end

  defp group_by_destruction(damage_events) do
    # Group damage events by target destruction
    damage_events
    |> Enum.group_by(& &1.target)
    |> Enum.map(fn {target, events} ->
      %{
        target: target,
        events: Enum.sort_by(events, & &1.timestamp),
        total_damage: Enum.sum(Enum.map(events, & &1.damage)),
        sources: Enum.map(events, & &1.source) |> Enum.uniq()
      }
    end)
    # Filter out minor damage
    |> Enum.filter(&(&1.total_damage > 1000))
  end

  defp create_pseudo_killmail(destruction_group) do
    last_event = List.last(destruction_group.events)

    %{
      killmail_id: generate_pseudo_id(destruction_group.target, last_event.timestamp),
      killmail_time: last_event.timestamp,
      victim: %{
        "character_name" => destruction_group.target,
        "damage_taken" => destruction_group.total_damage
      },
      attackers:
        Enum.map(destruction_group.sources, fn source ->
          %{
            "character_name" => source,
            "damage_done" => calculate_source_damage(source, destruction_group.events)
          }
        end),
      # Unknown system
      solar_system_id: 30_000_142,
      zkb: %{"totalValue" => 0}
    }
  end

  defp generate_pseudo_id(target, timestamp) do
    # Generate deterministic ID from target and timestamp
    data = "#{target}:#{DateTime.to_iso8601(timestamp)}"

    :crypto.hash(:md5, data)
    |> Base.encode16()
    |> String.slice(0..15)
    |> String.to_integer(16)
  end

  defp calculate_source_damage(source, events) do
    events
    |> Enum.filter(&(&1.source == source))
    |> Enum.map(& &1.damage)
    |> Enum.sum()
  end

  defp link_battle_to_log(battle_id, combat_log_id) do
    # Update battle with combat log reference
    BattleService.update_battle(battle_id, %{
      combat_log_id: combat_log_id,
      source: :combat_log
    })
  end

  defp get_combat_log(combat_log_id) do
    case Ash.get(CombatLog, combat_log_id) do
      {:ok, log} -> {:ok, log}
      _ -> {:error, :combat_log_not_found}
    end
  end

  defp calculate_total_damage_dealt(damage_events) do
    # Sum damage where our pilot is the source
    # Would need character context to determine "our" pilot
    Enum.reduce(damage_events, 0, &(&1.damage + &2))
  end

  defp calculate_total_damage_received(_damage_events) do
    # Sum damage where our pilot is the target
    # Would need character context
    0
  end

  defp group_damage_by_type(damage_events) do
    damage_events
    |> Enum.group_by(& &1.damage_type)
    |> Enum.map(fn {type, events} ->
      {type,
       %{
         count: length(events),
         total: Enum.sum(Enum.map(events, & &1.damage)),
         average: Enum.sum(Enum.map(events, & &1.damage)) / max(length(events), 1)
       }}
    end)
    |> Map.new()
  end

  defp group_damage_by_ship(damage_events) do
    damage_events
    |> Enum.group_by(& &1.target)
    |> Enum.map(fn {target, events} ->
      {target,
       %{
         count: length(events),
         total: Enum.sum(Enum.map(events, & &1.damage)),
         weapons_used: Enum.map(events, & &1.weapon) |> Enum.uniq()
       }}
    end)
    |> Map.new()
  end

  defp build_damage_timeline(damage_events) do
    damage_events
    |> Enum.group_by(fn event ->
      event.timestamp
      |> DateTime.truncate(:second)
    end)
    |> Enum.map(fn {time, events} ->
      %{
        time: time,
        damage: Enum.sum(Enum.map(events, & &1.damage)),
        event_count: length(events)
      }
    end)
    |> Enum.sort_by(& &1.time)
  end

  defp calculate_peak_dps(damage_events) do
    timeline = build_damage_timeline(damage_events)

    if length(timeline) > 0 do
      timeline
      |> Enum.map(& &1.damage)
      |> Enum.max()
    else
      0
    end
  end

  defp calculate_average_dps(damage_events) do
    if Enum.empty?(damage_events) do
      0
    else
      total_damage = Enum.sum(Enum.map(damage_events, & &1.damage))
      time_span = calculate_time_span(damage_events)

      if time_span.duration > 0 do
        total_damage / time_span.duration
      else
        0
      end
    end
  end

  defp identify_destruction_events(events) do
    # Look for patterns indicating target destruction
    # This is heuristic-based since logs don't explicitly show kills

    damage_by_target =
      events
      |> Enum.filter(&(&1.type == :damage))
      |> Enum.group_by(& &1.target)

    Enum.map(damage_by_target, fn {target, target_events} ->
      sorted_events = Enum.sort_by(target_events, & &1.timestamp)

      # Look for cessation of incoming damage (likely destroyed)
      find_destruction_point(target, sorted_events)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp find_destruction_point(target, events) do
    # Find point where target stops taking damage (likely destroyed)
    last_damage = List.last(events)

    if last_damage do
      %{
        target: target,
        destruction_time: last_damage.timestamp,
        total_damage: Enum.sum(Enum.map(events, & &1.damage)),
        final_blow: last_damage,
        damage_events: events
      }
    else
      nil
    end
  end

  defp build_killmail_from_destruction(destruction, _all_events) do
    attackers =
      destruction.damage_events
      |> Enum.group_by(& &1.source)
      |> Enum.map(fn {source, source_events} ->
        %{
          "character_name" => source,
          "damage_done" => Enum.sum(Enum.map(source_events, & &1.damage)),
          "weapon_type_name" => List.first(source_events).weapon,
          "final_blow" => source == destruction.final_blow.source
        }
      end)

    %{
      killmail_id: generate_pseudo_id(destruction.target, destruction.destruction_time),
      killmail_time: destruction.destruction_time,
      victim: %{
        "character_name" => destruction.target,
        "damage_taken" => destruction.total_damage
      },
      attackers: attackers,
      # Unknown
      solar_system_id: 30_000_142,
      source: :combat_log
    }
  end
end
