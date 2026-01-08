# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Killmails.HTTPoisonSSEProducer do
  @moduledoc """
  Broadway producer using HTTPoison's built-in streaming - the industry standard approach.
  Uses: HTTPoison.get!(url, [], recv_timeout: :infinity, stream_to: self())
  """

  use GenStage

  alias Broadway.Message
  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @default_retry_delay 1000
  @max_retry_delay 30_000
  @max_buffer_size 1_048_576
  # Half of @max_buffer_size (524KB vs 1MB) to limit memory growth and provide
  # headroom when trimming - ensures we don't immediately overflow again after trim
  @trim_keep_size 524_288
  # Deduplication: Track last N killmail IDs to prevent duplicate processing
  # 1000 IDs should cover ~15-20 minutes of typical EVE activity
  @dedup_cache_size 1000

  def init(opts) do
    url = Keyword.fetch!(opts, :url)

    # Schedule first summary log in 1 minute
    summary_timer = Process.send_after(self(), :log_summary, 60_000)

    state = %{
      url: url,
      connected: false,
      retry_delay: @default_retry_delay,
      demand: 0,
      retry_timer: nil,
      connected_at: nil,
      buffer: "",
      killmail_count: 0,
      last_summary_time: DateTimeUtils.utc_now(),
      summary_timer: summary_timer,
      # Deduplication cache: MapSet for O(1) lookups + FIFO queue for bounded eviction
      seen_killmails: %{set: MapSet.new(), queue: :queue.new()},
      duplicate_count: 0
    }

    {:producer, state,
     dispatcher: {GenStage.DemandDispatcher, [shuffle_demands_on_first_dispatch: true]}}
  end

  def handle_demand(incoming_demand, %{demand: demand} = state) do
    new_demand = demand + incoming_demand

    # If we have a connection, just update demand; otherwise try to establish one
    if state.connected do
      {:noreply, [], %{state | demand: new_demand}}
    else
      case start_sse_stream(state.url) do
        :ok ->
          Logger.info("✅ Started HTTPoison SSE stream: #{state.url}")

          {:noreply, [],
           %{
             state
             | connected: true,
               demand: new_demand,
               retry_delay: @default_retry_delay,
               connected_at: DateTimeUtils.utc_now()
           }}

        {:error, reason} ->
          Logger.error(
            "❌ Failed to start HTTPoison SSE stream to #{state.url}: #{inspect(reason)}"
          )

          schedule_retry(state)
          {:noreply, [], %{state | demand: new_demand}}
      end
    end
  end

  def handle_info(%HTTPoison.AsyncStatus{code: 200}, state) do
    Logger.info("✅ HTTPoison SSE connection established (HTTP 200)")
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    Logger.error("❌ HTTPoison SSE connection failed with HTTP #{code}")
    schedule_retry(state)
    {:noreply, [], %{state | connected: false, connected_at: nil, buffer: ""}}
  end

  def handle_info(%HTTPoison.AsyncHeaders{headers: headers}, state) do
    Logger.debug("HTTPoison SSE headers received: #{inspect(headers)}")
    {:noreply, [], state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    initial_combined_data = state.buffer <> chunk

    combined_data =
      if byte_size(initial_combined_data) > @max_buffer_size do
        Logger.warning(
          "⚠️  SSE buffer overflow detected (#{byte_size(initial_combined_data)} bytes), trimming oldest data"
        )

        # Emit telemetry for monitoring buffer overflow frequency
        :telemetry.execute(
          [:eve_dmv, :sse, :buffer_overflow],
          %{size: byte_size(initial_combined_data)},
          %{
            sse_url: state.url,
            connection_id: inspect(self()),
            connected_at: state.connected_at,
            killmail_count: state.killmail_count
          }
        )

        # Keep last @trim_keep_size bytes (most recent events)
        trimmed =
          binary_part(
            initial_combined_data,
            byte_size(initial_combined_data) - @trim_keep_size,
            @trim_keep_size
          )

        # Find next complete event boundary (double newline marks event end)
        # This ensures we don't start processing in the middle of an event
        case :binary.match(trimmed, "\n\n") do
          {pos, _len} ->
            # Skip to after the event boundary to start with a complete event
            binary_part(trimmed, pos + 2, byte_size(trimmed) - pos - 2)

          :nomatch ->
            # No event boundary found, try single newline (might be Windows-style)
            case :binary.match(trimmed, "\r\n\r\n") do
              {pos, _len} ->
                binary_part(trimmed, pos + 4, byte_size(trimmed) - pos - 4)

              :nomatch ->
                # No complete events in buffer, reset to prevent corruption
                Logger.warning(
                  "No event boundary found in trimmed buffer, resetting. " <>
                    "Discarding #{byte_size(initial_combined_data)} bytes total " <>
                    "(#{byte_size(trimmed)} bytes searched for boundary)"
                )

                ""
            end
        end
      else
        initial_combined_data
      end

    # Process incoming SSE chunk
    {events, new_buffer} = parse_sse_data(combined_data)

    # Convert events to Broadway messages with deduplication
    filtered_events = Enum.reject(events, &is_nil/1)

    {accumulated_messages, killmail_count, new_seen, dup_count} =
      Enum.reduce(filtered_events, {[], 0, state.seen_killmails, 0}, fn event,
                                                                        {messages, count, seen,
                                                                         dups} ->
        case to_broadway_message_with_dedup(event, seen) do
          {:ok, {:batch, batch_messages}, updated_seen} ->
            # Prepend each batch message (O(1) per element) - iterating in order
            # results in reversed order in accumulator, restored by final reverse
            new_messages =
              Enum.reduce(batch_messages, messages, fn msg, acc -> [msg | acc] end)

            {new_messages, count + length(batch_messages), updated_seen, dups}

          {:ok, message, updated_seen} when is_struct(message, Message) ->
            {[message | messages], count + 1, updated_seen, dups}

          {:duplicate, _killmail_id, updated_seen} ->
            {messages, count, updated_seen, dups + 1}

          {:skip, updated_seen} ->
            {messages, count, updated_seen, dups}
        end
      end)

    # Reverse to restore intended chronological order (prepending builds reverse list)
    broadway_messages = Enum.reverse(accumulated_messages)

    # Log duplicates if any were found
    if dup_count > 0 do
      Logger.debug("Skipped #{dup_count} duplicate killmail(s) in chunk")
    end

    # Only emit messages if we have demand
    {to_emit, remaining_demand} =
      if state.demand > 0 do
        take_count = min(length(broadway_messages), state.demand)
        {Enum.take(broadway_messages, take_count), state.demand - take_count}
      else
        {[], state.demand}
      end

    {:noreply, to_emit,
     %{
       state
       | buffer: new_buffer,
         demand: remaining_demand,
         killmail_count: state.killmail_count + killmail_count,
         seen_killmails: new_seen,
         duplicate_count: state.duplicate_count + dup_count
     }}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    duration =
      if state.connected_at,
        do: DateTimeUtils.diff(DateTimeUtils.utc_now(), state.connected_at, :second),
        else: 0

    Logger.info("HTTPoison SSE stream ended after #{duration}s")
    schedule_retry(state)
    {:noreply, [], %{state | connected: false, connected_at: nil, buffer: ""}}
  end

  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    duration =
      if state.connected_at,
        do: DateTimeUtils.diff(DateTimeUtils.utc_now(), state.connected_at, :second),
        else: 0

    Logger.warning("🔌 HTTPoison SSE error after #{duration}s - Reason: #{inspect(reason)}")
    schedule_retry(state)
    {:noreply, [], %{state | connected: false, connected_at: nil, buffer: ""}}
  end

  def handle_info(:log_summary, state) do
    now = DateTimeUtils.utc_now()
    duration = DateTimeUtils.diff(now, state.last_summary_time, :second)

    rate = if duration > 0, do: Float.round(state.killmail_count / (duration / 60), 1), else: 0.0

    connection_status = if state.connected, do: "Connected", else: "Disconnected"

    connection_duration =
      if state.connected_at, do: DateTimeUtils.diff(now, state.connected_at, :second), else: 0

    # Include duplicate stats if any were found
    dup_info =
      if state.duplicate_count > 0,
        do: " | Duplicates filtered: #{state.duplicate_count}",
        else: ""

    Logger.info(
      "📊 EVE DMV Killmail Summary: #{state.killmail_count} kills received in last #{duration}s (#{rate}/min) | Status: #{connection_status} for #{connection_duration}s#{dup_info}"
    )

    # Schedule next summary log
    summary_timer = Process.send_after(self(), :log_summary, 60_000)

    {:noreply, [],
     %{
       state
       | killmail_count: 0,
         last_summary_time: now,
         summary_timer: summary_timer,
         duplicate_count: 0
     }}
  end

  def handle_info(:retry_connection, state) do
    case start_sse_stream(state.url) do
      :ok ->
        Logger.info("🔄 Reconnected HTTPoison SSE stream: #{state.url}")

        {:noreply, [],
         %{
           state
           | connected: true,
             retry_delay: @default_retry_delay,
             retry_timer: nil,
             connected_at: DateTimeUtils.utc_now(),
             buffer: ""
         }}

      {:error, reason} ->
        Logger.error(
          "❌ Failed to reconnect HTTPoison SSE stream to #{state.url}: #{inspect(reason)}"
        )

        schedule_retry(state)
        {:noreply, [], state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message in HTTPoison SSE producer: #{inspect(msg)}")
    {:noreply, [], state}
  end

  def terminate(_reason, %{summary_timer: timer}) do
    if timer, do: Process.cancel_timer(timer)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  # Private functions

  defp start_sse_stream(url) do
    # Use the industry standard HTTPoison streaming pattern with additional options
    HTTPoison.get!(
      url,
      [
        {"Accept", "*/*"},
        {"Cache-Control", "no-cache"},
        {"Connection", "keep-alive"},
        {"User-Agent", "EVE-DMV/1.0 HTTPoison-SSE"}
      ],
      recv_timeout: :infinity,
      timeout: :infinity,
      stream_to: self(),
      hackney: [
        pool: false,
        recv_timeout: :infinity,
        connect_timeout: 30_000
      ]
    )

    :ok
  rescue
    error ->
      {:error, error}
  end

  defp schedule_retry(state) do
    if state.retry_timer do
      Process.cancel_timer(state.retry_timer)
    end

    timer = Process.send_after(self(), :retry_connection, state.retry_delay)
    new_delay = min(state.retry_delay * 2, @max_retry_delay)

    %{state | retry_timer: timer, retry_delay: new_delay}
  end

  defp parse_sse_data(data) do
    # SSE events are separated by double newlines
    # Check if we have any complete events (ending with double newline)
    if String.contains?(data, "\n\n") or String.contains?(data, "\r\n\r\n") do
      # Split data by double newlines to separate events
      events_data = String.split(data, ~r/\r?\n\r?\n/)

      # The last part might be incomplete, so keep it in the buffer
      {complete_events, remaining} =
        case events_data do
          [] -> {[], ""}
          [single] -> {[], single}
          events -> {Enum.drop(events, -1), List.last(events)}
        end

      parsed_events = Enum.map(complete_events, &parse_single_event/1)
      events = Enum.filter(parsed_events, &(&1 != nil))

      if not Enum.empty?(events) do
        Logger.debug("Parsed #{length(events)} SSE events from chunk")
      end

      {events, remaining}
    else
      # No complete events yet, keep everything in buffer
      {[], data}
    end
  end

  # Deduplication wrapper for to_broadway_message
  # Returns {:ok, message, updated_seen}, {:duplicate, killmail_id, seen}, or {:skip, seen}
  # seen_killmails is %{set: MapSet.t(), queue: :queue.queue()} for O(1) lookups
  defp to_broadway_message_with_dedup(%{event: "batch", data: payload} = _event, seen_killmails) do
    # Handle batch events with per-killmail deduplication
    case Jason.decode(payload) do
      {:ok, killmails} when is_list(killmails) ->
        # Filter to only unseen killmails
        unseen_killmails =
          Enum.filter(killmails, fn km ->
            killmail_id = km["killmail_id"]
            killmail_id != nil and not MapSet.member?(seen_killmails.set, killmail_id)
          end)

        seen_count = length(killmails) - length(unseen_killmails)

        if seen_count > 0 do
          Logger.debug(
            "Filtered #{seen_count} duplicate killmails from batch of #{length(killmails)}"
          )
        end

        case unseen_killmails do
          [] ->
            # All killmails in batch were duplicates - compute IDs only when needed
            all_ids = Enum.map(killmails, & &1["killmail_id"]) |> Enum.reject(&is_nil/1)
            {:duplicate, all_ids, seen_killmails}

          _ ->
            # Build batch with only unseen killmails
            messages =
              Enum.map(unseen_killmails, fn km ->
                %Message{
                  data: km,
                  acknowledger: Broadway.NoopAcknowledger.init(),
                  batcher: :db_insert
                }
              end)

            # Track newly processed IDs
            new_ids = Enum.map(unseen_killmails, & &1["killmail_id"]) |> Enum.reject(&is_nil/1)
            updated_seen = add_ids_to_seen(seen_killmails, new_ids)

            {:ok, {:batch, messages}, updated_seen}
        end

      _ ->
        {:skip, seen_killmails}
    end
  end

  defp to_broadway_message_with_dedup(%{data: payload} = event, seen_killmails) do
    # Try to extract killmail_id for deduplication (single killmail events)
    case extract_killmail_id(payload) do
      {:ok, killmail_id} ->
        if MapSet.member?(seen_killmails.set, killmail_id) do
          # Already seen this killmail, skip it
          Logger.debug("Skipping duplicate killmail #{killmail_id}")
          {:duplicate, killmail_id, seen_killmails}
        else
          # New killmail, process and add to seen cache
          case to_broadway_message(event) do
            nil ->
              {:skip, seen_killmails}

            message ->
              updated_seen = add_to_seen(seen_killmails, killmail_id)
              {:ok, message, updated_seen}
          end
        end

      :not_a_killmail ->
        # Non-killmail events pass through without deduplication
        case to_broadway_message(event) do
          nil -> {:skip, seen_killmails}
          message -> {:ok, message, seen_killmails}
        end
    end
  end

  # Extract killmail_id from payload for deduplication
  defp extract_killmail_id(payload) when is_binary(payload) do
    # Quick pattern match to extract killmail_id without full JSON parse
    case Regex.run(~r/"killmail_id"\s*:\s*(\d+)/, payload) do
      [_, id_str] -> {:ok, String.to_integer(id_str)}
      nil -> :not_a_killmail
    end
  end

  defp extract_killmail_id(_), do: :not_a_killmail

  # Add killmail_id to dedup cache with O(1) lookup via MapSet + FIFO eviction via queue
  # seen is %{set: MapSet.t(), queue: :queue.queue()}
  defp add_to_seen(%{set: set, queue: queue} = _seen, killmail_id) do
    # Add to both structures
    new_set = MapSet.put(set, killmail_id)
    new_queue = :queue.in(killmail_id, queue)

    # Evict oldest entries if we exceed cache size
    evict_if_needed(%{set: new_set, queue: new_queue})
  end

  # Add multiple killmail_ids to dedup cache, maintaining max size
  defp add_ids_to_seen(seen, killmail_ids) when is_list(killmail_ids) do
    Enum.reduce(killmail_ids, seen, &add_to_seen(&2, &1))
  end

  # Evict oldest entries from cache if size exceeds limit
  defp evict_if_needed(%{set: set, queue: queue} = seen) do
    if MapSet.size(set) > @dedup_cache_size do
      # Pop oldest from queue and remove from set
      case :queue.out(queue) do
        {{:value, oldest_id}, new_queue} ->
          evict_if_needed(%{set: MapSet.delete(set, oldest_id), queue: new_queue})

        {:empty, _} ->
          # Queue is empty but set is too large - should not happen, but handle gracefully
          seen
      end
    else
      seen
    end
  end

  defp to_broadway_message(%{event: "killmail", data: payload}) do
    case Jason.decode(payload) do
      {:ok, %{"killmail_id" => killmail_id} = enriched} ->
        Logger.info("📡 Received killmail #{killmail_id} from HTTPoison SSE")

        %Message{
          data: enriched,
          acknowledger: Broadway.NoopAcknowledger.init(),
          batcher: :db_insert
        }

      {:ok, _other_json} ->
        Logger.debug("Received non-killmail JSON data: #{inspect(payload)}")
        nil

      {:error, reason} ->
        Logger.warning("Failed to decode killmail JSON: #{inspect(reason)}")
        nil
    end
  rescue
    error ->
      Logger.error("Failed to convert SSE event to Broadway message: #{inspect(error)}")
      nil
  end

  defp to_broadway_message(%{event: "batch", data: payload}) do
    # Handle batch events with multiple killmails
    case Jason.decode(payload) do
      {:ok, killmails} when is_list(killmails) ->
        killmails
        |> Enum.map(fn km ->
          %Message{
            data: km,
            acknowledger: Broadway.NoopAcknowledger.init(),
            batcher: :db_insert
          }
        end)
        |> then(&{:batch, &1})

      _ ->
        nil
    end
  end

  defp to_broadway_message(%{event: "connected", data: data}) do
    Logger.info("🎯 Successfully connected to wanderer-kills HTTPoison SSE stream: #{data}")
    nil
  end

  defp to_broadway_message(%{event: "heartbeat", data: _}) do
    Logger.debug("Received HTTPoison SSE heartbeat")
    nil
  end

  defp to_broadway_message(%{event: "error", data: payload}) do
    case Jason.decode(payload) do
      {:ok, error_data} ->
        Logger.error("HTTPoison SSE stream error: #{inspect(error_data)}")

      _ ->
        Logger.error("HTTPoison SSE stream error: #{payload}")
    end

    nil
  end

  # Handle events with no explicit event type (default "message" events)
  # This is the case with wanderer-kills SSE stream
  defp to_broadway_message(%{event: nil, data: payload}) do
    Logger.debug("Processing SSE event with no event type, data_length=#{String.length(payload)}")

    case Jason.decode(payload) do
      {:ok, %{"killmail_id" => killmail_id} = enriched} ->
        Logger.info("📡 Received killmail #{killmail_id} from HTTPoison SSE (default event)")

        %Message{
          data: enriched,
          acknowledger: Broadway.NoopAcknowledger.init(),
          batcher: :db_insert
        }

      {:ok, _other_json} ->
        Logger.debug("Received non-killmail JSON data from default event: #{inspect(payload)}")
        nil

      {:error, reason} ->
        Logger.warning("Failed to decode JSON from default event: #{inspect(reason)}")
        nil
    end
  rescue
    error ->
      Logger.error("Failed to convert default SSE event to Broadway message: #{inspect(error)}")
      nil
  end

  # Handle "message" event type (SSE standard default)
  defp to_broadway_message(%{event: "message", data: payload}) do
    Logger.debug(
      "Processing SSE event with 'message' type, data_length=#{String.length(payload)}"
    )

    case Jason.decode(payload) do
      {:ok, %{"killmail_id" => killmail_id} = enriched} ->
        Logger.info("📡 Received killmail #{killmail_id} from HTTPoison SSE (message event)")

        %Message{
          data: enriched,
          acknowledger: Broadway.NoopAcknowledger.init(),
          batcher: :db_insert
        }

      {:ok, _other_json} ->
        Logger.debug("Received non-killmail JSON data from message event: #{inspect(payload)}")
        nil

      {:error, reason} ->
        Logger.warning("Failed to decode JSON from message event: #{inspect(reason)}")
        nil
    end
  rescue
    error ->
      Logger.error("Failed to convert message SSE event to Broadway message: #{inspect(error)}")
      nil
  end

  defp to_broadway_message(event) do
    Logger.debug("Unhandled SSE event: #{inspect(event)}")
    nil
  end

  defp parse_single_event(event_data) do
    lines = String.split(event_data, ~r/\r?\n/)
    initial_event = %{event: nil, data: "", id: nil, retry: nil}

    parsed_event = Enum.reduce(lines, initial_event, &parse_sse_line/2)
    validate_parsed_event(parsed_event)
  end

  defp parse_sse_line(line, acc) do
    trimmed_line = String.trim(line)

    cond do
      trimmed_line == "" -> acc
      # SSE comment, ignore
      String.starts_with?(trimmed_line, ":") -> acc
      String.contains?(line, ":") -> parse_field_line(line, acc)
      true -> acc
    end
  end

  defp parse_field_line(line, acc) do
    case String.split(line, ":", parts: 2) do
      [field, value] -> update_event_field(field, value, acc)
      [field] -> handle_field_only(field, acc)
      _ -> acc
    end
  end

  defp update_event_field(field, value, acc) do
    case field do
      "data" -> update_data_field(value, acc)
      "event" -> %{acc | event: String.trim(value)}
      "id" -> %{acc | id: String.trim(value)}
      "retry" -> update_retry_field(value, acc)
      _ -> acc
    end
  end

  defp update_data_field(value, acc) do
    current_data = if acc.data == "", do: "", else: acc.data <> "\n"
    # Only trim leading space after the colon, preserve the rest of the value
    trimmed_value = String.trim_leading(value)
    %{acc | data: current_data <> trimmed_value}
  end

  defp update_retry_field(value, acc) do
    case Integer.parse(String.trim(value)) do
      {num, _} -> %{acc | retry: num}
      _ -> acc
    end
  end

  defp handle_field_only(field, acc) do
    case String.trim(field) do
      "data" -> %{acc | data: acc.data <> "\n"}
      _ -> acc
    end
  end

  defp validate_parsed_event(parsed_event) do
    if parsed_event.data != "" do
      Logger.debug(
        "Parsed SSE event: event=#{inspect(parsed_event.event)}, data_length=#{String.length(parsed_event.data)}, first_100_chars=#{String.slice(parsed_event.data, 0..100)}"
      )

      parsed_event
    else
      nil
    end
  end
end
