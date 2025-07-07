# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Killmails.HTTPoisonSSEProducer do
  @moduledoc """
  Broadway producer using HTTPoison's built-in streaming - the industry standard approach.
  Uses: HTTPoison.get!(url, [], recv_timeout: :infinity, stream_to: self())
  """

  use GenStage

  alias Broadway.Message

  require Logger

  @default_retry_delay 1000
  @max_retry_delay 30_000

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
      last_summary_time: DateTime.utc_now(),
      summary_timer: summary_timer
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
               connected_at: DateTime.utc_now()
           }}

        {:error, reason} ->
          Logger.error("❌ Failed to start HTTPoison SSE stream: #{inspect(reason)}")
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
    # Process incoming SSE chunk
    {events, new_buffer} = parse_sse_data(state.buffer <> chunk)

    # Convert events to Broadway messages and count killmails
    filtered_events = Enum.reject(events, &is_nil/1)

    {broadway_messages, killmail_count} =
      Enum.reduce(filtered_events, {[], 0}, fn event, {messages, count} ->
        case to_broadway_message(event) do
          {:batch, batch_messages} ->
            {messages ++ batch_messages, count + length(batch_messages)}

          message when is_struct(message, Message) ->
            {[message | messages], count + 1}

          nil ->
            {messages, count}
        end
      end)

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
         killmail_count: state.killmail_count + killmail_count
     }}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    duration =
      if state.connected_at,
        do: DateTime.diff(DateTime.utc_now(), state.connected_at, :second),
        else: 0

    Logger.info("HTTPoison SSE stream ended after #{duration}s")
    schedule_retry(state)
    {:noreply, [], %{state | connected: false, connected_at: nil, buffer: ""}}
  end

  def handle_info(%HTTPoison.Error{reason: reason}, state) do
    duration =
      if state.connected_at,
        do: DateTime.diff(DateTime.utc_now(), state.connected_at, :second),
        else: 0

    Logger.warning("🔌 HTTPoison SSE error after #{duration}s - Reason: #{inspect(reason)}")
    schedule_retry(state)
    {:noreply, [], %{state | connected: false, connected_at: nil, buffer: ""}}
  end

  def handle_info(:log_summary, state) do
    now = DateTime.utc_now()
    duration = DateTime.diff(now, state.last_summary_time, :second)

    rate = if duration > 0, do: Float.round(state.killmail_count / (duration / 60), 1), else: 0.0

    connection_status = if state.connected, do: "Connected", else: "Disconnected"

    connection_duration =
      if state.connected_at, do: DateTime.diff(now, state.connected_at, :second), else: 0

    Logger.info(
      "📊 EVE DMV Killmail Summary: #{state.killmail_count} kills received in last #{duration}s (#{rate}/min) | Status: #{connection_status} for #{connection_duration}s"
    )

    # Schedule next summary log
    summary_timer = Process.send_after(self(), :log_summary, 60_000)

    {:noreply, [],
     %{state | killmail_count: 0, last_summary_time: now, summary_timer: summary_timer}}
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
             connected_at: DateTime.utc_now(),
             buffer: ""
         }}

      {:error, reason} ->
        Logger.error("❌ Failed to reconnect HTTPoison SSE stream: #{inspect(reason)}")
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

      if length(events) > 0 do
        Logger.debug("Parsed #{length(events)} SSE events from chunk")
      end

      {events, remaining}
    else
      # No complete events yet, keep everything in buffer
      {[], data}
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
