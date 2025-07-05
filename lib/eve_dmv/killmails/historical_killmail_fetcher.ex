defmodule EveDmv.Killmails.HistoricalKillmailFetcher do
  @moduledoc """
  Fetches historical killmail data for specific characters from wanderer-kills SSE service.

  Uses the enhanced SSE endpoint to preload up to 90 days of historical data for a character,
  then disconnects once all historical data is received (detected by multiple heartbeats).
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw, Participant}
  alias EveDmv.Utils.ParsingUtils

  # Get base URL at runtime for better configuration flexibility
  defp wanderer_kills_base_url do
    Application.get_env(:eve_dmv, :wanderer_kills_base_url, "http://host.docker.internal:4004")
  end

  @preload_days 90
  @heartbeat_threshold 3

  @doc """
  Fetch historical killmails for a character ID.

  Returns {:ok, killmail_count} or {:error, reason}
  """
  @spec fetch_character_history(integer()) :: {:ok, integer()} | {:error, term()}
  def fetch_character_history(character_id) when is_integer(character_id) do
    Logger.info("Fetching historical killmails for character #{character_id}")

    url = build_url(character_id)

    case HTTPoison.get(url, [], recv_timeout: 120_000, stream_to: self()) do
      {:ok, %HTTPoison.AsyncResponse{id: ref}} ->
        process_stream(ref, character_id)

      {:error, reason} = error ->
        Logger.error("Failed to connect to wanderer-kills: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Fetch historical killmails for multiple characters concurrently.
  """
  @spec fetch_characters_history([integer()]) :: {:ok, map()}
  def fetch_characters_history(character_ids) when is_list(character_ids) do
    Logger.info("Fetching historical killmails for #{length(character_ids)} characters")

    results =
      character_ids
      |> Enum.map(fn char_id ->
        Task.async(fn ->
          case fetch_character_history(char_id) do
            {:ok, count} -> {char_id, {:ok, count}}
            error -> {char_id, error}
          end
        end)
      end)
      |> Enum.map(&Task.await(&1, 180_000))
      |> Map.new()

    {:ok, results}
  end

  @doc """
  Get cached killmail count for a character.

  Returns the count of participants for this character from cached data.
  """
  @spec get_cached_killmail_count(integer()) :: integer()
  def get_cached_killmail_count(character_id) when is_integer(character_id) do
    # Query participant count for this character
    case Ash.read(Participant,
           actor: nil,
           filter: [character_id: character_id],
           action: :read,
           domain: Api
         ) do
      {:ok, participants} when is_list(participants) -> length(participants)
      {:ok, %{results: results}} -> length(results)
      {:ok, page} when is_map(page) -> Map.get(page, :count, 0)
      _ -> 0
    end
  rescue
    _ -> 0
  end

  # Private functions

  defp build_url(character_id) do
    "#{wanderer_kills_base_url()}/api/v1/kills/stream/enhanced?character_ids=#{character_id}&preload_days=#{@preload_days}"
  end

  defp process_stream(ref, character_id) do
    process_stream_loop(ref, character_id, %{
      heartbeat_count: 0,
      killmail_count: 0,
      batch_count: 0,
      is_realtime: false,
      buffer: ""
    })
  end

  defp process_stream_loop(ref, character_id, state) do
    receive do
      %HTTPoison.AsyncStatus{id: ^ref, code: 200} ->
        Logger.debug("Connected to wanderer-kills SSE stream for character #{character_id}")
        process_stream_loop(ref, character_id, state)

      %HTTPoison.AsyncStatus{id: ^ref, code: code} ->
        Logger.error("Wanderer-kills returned status #{code}")
        # No need to explicitly stop - just stop receiving
        {:error, "HTTP status #{code}"}

      %HTTPoison.AsyncHeaders{id: ^ref, headers: headers} ->
        Logger.debug("Received headers: #{inspect(headers)}")
        process_stream_loop(ref, character_id, state)

      %HTTPoison.AsyncChunk{id: ^ref, chunk: chunk} ->
        new_state = process_chunk(chunk, state, character_id)

        # Check if we should disconnect
        if should_disconnect?(new_state) do
          Logger.info(
            "Received all historical data for character #{character_id} (#{new_state.killmail_count} killmails)"
          )

          # Just return - process will clean up when we stop receiving
          {:ok, new_state.killmail_count}
        else
          process_stream_loop(ref, character_id, new_state)
        end

      %HTTPoison.AsyncEnd{id: ^ref} ->
        Logger.info("SSE stream ended for character #{character_id}")
        {:ok, state.killmail_count}

      %HTTPoison.Error{id: ^ref, reason: reason} ->
        Logger.error("SSE stream error: #{inspect(reason)}")
        {:error, reason}
    after
      120_000 ->
        Logger.error("Timeout waiting for SSE data")
        {:error, :timeout}
    end
  end

  defp process_chunk(chunk, state, character_id) do
    # Append chunk to buffer
    buffer = state.buffer <> chunk

    # Process complete events
    {events, remaining_buffer} = parse_sse_events(buffer)

    new_state = %{state | buffer: remaining_buffer}

    Enum.reduce(events, new_state, fn event, acc_state ->
      process_event(event, acc_state, character_id)
    end)
  end

  defp parse_sse_events(buffer) do
    # Split by double newline (event separator)
    parts = String.split(buffer, "\n\n", trim: true)

    case parts do
      [] ->
        {[], buffer}

      [incomplete] ->
        # Check if this might be a complete event
        if String.ends_with?(buffer, "\n\n") do
          {[parse_sse_event(incomplete)], ""}
        else
          {[], buffer}
        end

      parts ->
        # Last part might be incomplete
        {complete_parts, last_part} =
          if String.ends_with?(buffer, "\n\n") do
            {parts, ""}
          else
            {Enum.drop(parts, -1), List.last(parts)}
          end

        events = Enum.map(complete_parts, &parse_sse_event/1)
        {events, last_part}
    end
  end

  defp parse_sse_event(text) do
    lines = String.split(text, "\n", trim: true)

    Enum.reduce(lines, %{event: nil, data: nil}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        ["event", event_type] -> %{acc | event: String.trim(event_type)}
        ["data", data] -> %{acc | data: String.trim(data)}
        _ -> acc
      end
    end)
  end

  defp process_event(%{event: "connected", data: data}, state, character_id) do
    case Jason.decode(data) do
      {:ok, info} ->
        Logger.info("Connected to wanderer-kills for character #{character_id}: #{inspect(info)}")
        state

      _ ->
        state
    end
  end

  defp process_event(%{event: "batch", data: data}, state, character_id) do
    case Jason.decode(data) do
      {:ok, %{"killmails" => killmails, "batch_number" => batch_num, "total_batches" => total}} ->
        Logger.info(
          "Processing batch #{batch_num}/#{total} for character #{character_id} (#{length(killmails)} killmails)"
        )

        # Process killmails
        Enum.each(killmails, &store_killmail/1)

        %{
          state
          | killmail_count: state.killmail_count + length(killmails),
            batch_count: state.batch_count + 1,
            # Reset heartbeat count on data
            heartbeat_count: 0
        }

      _ ->
        state
    end
  end

  defp process_event(%{event: "killmail", data: data}, state, _character_id) do
    case Jason.decode(data) do
      {:ok, killmail} ->
        store_killmail(killmail)

        %{
          state
          | killmail_count: state.killmail_count + 1,
            # Reset heartbeat count on data
            heartbeat_count: 0
        }

      _ ->
        state
    end
  end

  defp process_event(%{event: "transition", data: data}, state, character_id) do
    case Jason.decode(data) do
      {:ok, info} ->
        Logger.info(
          "Transitioned to realtime mode for character #{character_id}: #{inspect(info)}"
        )

        %{state | is_realtime: true}

      _ ->
        state
    end
  end

  defp process_event(%{event: "heartbeat", data: _}, state, _character_id) do
    %{state | heartbeat_count: state.heartbeat_count + 1}
  end

  defp process_event(%{event: nil, data: data}, state, character_id) when not is_nil(data) do
    # Handle events without explicit event type (default to killmail)
    process_event(%{event: "killmail", data: data}, state, character_id)
  end

  defp process_event(_, state, _), do: state

  defp should_disconnect?(state) do
    # Disconnect if we're in realtime mode OR we've received multiple heartbeats without data
    state.is_realtime or state.heartbeat_count >= @heartbeat_threshold
  end

  defp store_killmail(enriched) do
    # Reuse the same logic from the pipeline for consistency
    raw_changeset = build_raw_changeset(enriched)
    enriched_changeset = build_enriched_changeset(enriched)
    participants = build_participants(enriched)

    # Insert with error handling
    with :ok <- insert_raw_killmail(raw_changeset),
         :ok <- insert_enriched_killmail(enriched_changeset),
         :ok <- insert_participants(participants) do
      :ok
    else
      error ->
        Logger.warning("Failed to store killmail #{enriched["killmail_id"]}: #{inspect(error)}")
        error
    end
  end

  # Reuse changeset builders from pipeline (simplified versions)

  defp build_raw_changeset(enriched) do
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
      killmail_hash: enriched["killmail_hash"] || generate_hash(enriched),
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"],
      victim_character_id: get_in(enriched, ["victim", "character_id"]),
      victim_corporation_id: get_in(enriched, ["victim", "corporation_id"]),
      victim_alliance_id: get_in(enriched, ["victim", "alliance_id"]),
      victim_ship_type_id: get_in(enriched, ["victim", "ship_type_id"]),
      attacker_count: length(enriched["attackers"] || []),
      raw_data: enriched,
      source: "wanderer-kills-historical"
    }
  end

  defp build_enriched_changeset(enriched) do
    victim = enriched["victim"] || %{}

    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"] || enriched["kill_time"]),
      total_value: parse_decimal(enriched["total_value"] || enriched["value"] || 0),
      ship_value: 0.0,
      fitted_value: 0.0,
      victim_character_id: victim["character_id"],
      victim_character_name: victim["character_name"],
      victim_corporation_id: victim["corporation_id"],
      victim_corporation_name: victim["corporation_name"],
      victim_alliance_id: victim["alliance_id"],
      victim_alliance_name: victim["alliance_name"],
      victim_ship_type_id: victim["ship_type_id"],
      victim_ship_name: victim["ship_name"],
      solar_system_id: enriched["solar_system_id"] || enriched["system_id"],
      solar_system_name: enriched["solar_system_name"] || "Unknown System",
      attacker_count: length(enriched["attackers"] || []),
      final_blow_character_id: get_final_blow_character_id(enriched),
      final_blow_character_name: get_final_blow_character_name(enriched),
      kill_category: determine_kill_category(enriched),
      victim_ship_category: "unknown",
      module_tags: enriched["module_tags"] || [],
      noteworthy_modules: enriched["noteworthy_modules"] || [],
      price_data_source: "wanderer_kills"
    }
  end

  defp build_participants(enriched) do
    victim = enriched["victim"] || %{}
    attackers = enriched["attackers"] || []

    victim_participants =
      if victim["ship_type_id"] do
        [build_participant(victim, enriched, true)]
      else
        []
      end

    attacker_participants =
      attackers
      |> Enum.filter(& &1["ship_type_id"])
      |> Enum.map(&build_participant(&1, enriched, false))

    victim_participants ++ attacker_participants
  end

  defp build_participant(entity, killmail, is_victim) do
    %{
      killmail_id: killmail["killmail_id"],
      killmail_time: parse_timestamp(killmail["timestamp"] || killmail["kill_time"]),
      character_id: entity["character_id"],
      character_name: entity["character_name"],
      corporation_id: entity["corporation_id"],
      corporation_name: entity["corporation_name"],
      alliance_id: entity["alliance_id"],
      alliance_name: entity["alliance_name"],
      faction_id: entity["faction_id"],
      faction_name: entity["faction_name"],
      ship_type_id: entity["ship_type_id"],
      ship_name: entity["ship_name"],
      weapon_type_id: entity["weapon_type_id"],
      weapon_name: entity["weapon_name"],
      damage_done: entity["damage_done"] || entity["damage_dealt"] || 0,
      security_status: entity["security_status"],
      is_victim: is_victim,
      final_blow: entity["final_blow"] || false,
      solar_system_id: killmail["solar_system_id"] || killmail["system_id"]
    }
  end

  # Database operations

  defp insert_raw_killmail(changeset) do
    case Ash.create(KillmailRaw, changeset, action: :ingest_from_source, domain: Api) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  rescue
    # Ignore duplicates
    _ -> :ok
  end

  defp insert_enriched_killmail(changeset) do
    case Ash.create(KillmailEnriched, changeset, action: :upsert, domain: Api) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  rescue
    # Ignore duplicates
    _ -> :ok
  end

  defp insert_participants(participants) do
    case Ash.bulk_create(participants, Participant, :create,
           domain: Api,
           return_records?: false,
           return_errors?: false,
           stop_on_error?: false,
           batch_size: 500
         ) do
      %{records: _records} -> :ok
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  # Helper functions

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(_), do: DateTime.utc_now()

  defp parse_decimal(value), do: ParsingUtils.parse_decimal(value)

  defp generate_hash(enriched) do
    id = enriched["killmail_id"]
    timestamp = enriched["timestamp"]
    :crypto.hash(:sha256, "#{id}-#{timestamp}") |> Base.encode16(case: :lower)
  end

  defp get_final_blow_character_id(enriched) do
    case find_final_blow_attacker(enriched) do
      %{"character_id" => id} -> id
      _ -> nil
    end
  end

  defp get_final_blow_character_name(enriched) do
    case find_final_blow_attacker(enriched) do
      %{"character_name" => name} -> name
      _ -> nil
    end
  end

  defp find_final_blow_attacker(enriched) do
    attackers = enriched["attackers"] || []
    Enum.find(attackers, fn a -> a["final_blow"] end)
  end

  defp determine_kill_category(enriched) do
    attacker_count = length(enriched["attackers"] || [])

    case attacker_count do
      1 -> "solo"
      n when n <= 5 -> "small_gang"
      n when n <= 20 -> "fleet"
      _ -> "large_fleet"
    end
  end
end
