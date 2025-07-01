defmodule EveDmv.Intelligence.WandererSSE do
  @moduledoc """
  Server-Sent Events (SSE) client for Wanderer map events.

  Connects to Wanderer's SSE API to receive real-time map events:
  - Character events (pilots entering/leaving systems)
  - System events (systems added/removed from maps)
  - Connection events (wormhole connections created/destroyed)

  Reuses the existing SSE infrastructure from wanderer-kills integration.
  """

  use GenServer
  require Logger

  @default_base_url "http://localhost:4000"

  defstruct [
    :base_url,
    :api_token,
    :monitored_maps,
    :sse_connections
  ]

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def monitor_map(map_id) do
    GenServer.call(__MODULE__, {:monitor_map, map_id})
  end

  def stop_monitoring(map_id) do
    GenServer.call(__MODULE__, {:stop_monitoring, map_id})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    base_url = Keyword.get(opts, :base_url) || get_base_url_from_env()
    api_token = Keyword.get(opts, :api_token) || get_api_token_from_env()

    state = %__MODULE__{
      base_url: base_url,
      api_token: api_token,
      monitored_maps: MapSet.new(),
      sse_connections: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:monitor_map, map_id}, _from, state) do
    if MapSet.member?(state.monitored_maps, map_id) do
      {:reply, {:ok, :already_monitoring}, state}
    else
      {:ok, connection_pid} = start_sse_connection(map_id, state)
      new_monitored = MapSet.put(state.monitored_maps, map_id)
      new_connections = Map.put(state.sse_connections, map_id, connection_pid)

      new_state = %{state | monitored_maps: new_monitored, sse_connections: new_connections}

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:stop_monitoring, map_id}, _from, state) do
    case Map.get(state.sse_connections, map_id) do
      nil ->
        {:reply, :ok, state}

      connection_pid ->
        Process.exit(connection_pid, :normal)
        new_monitored = MapSet.delete(state.monitored_maps, map_id)
        new_connections = Map.delete(state.sse_connections, map_id)

        new_state = %{state | monitored_maps: new_monitored, sse_connections: new_connections}

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      monitored_maps: MapSet.to_list(state.monitored_maps),
      active_connections: Map.keys(state.sse_connections),
      base_url: state.base_url
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:sse_event, map_id, event_data}, state) do
    process_sse_event(map_id, event_data)
    {:noreply, state}
  end

  @impl true
  def handle_info({:sse_connection_closed, map_id, reason}, state) do
    Logger.warning("SSE connection closed for map #{map_id}: #{inspect(reason)}")

    # Remove from tracking
    new_monitored = MapSet.delete(state.monitored_maps, map_id)
    new_connections = Map.delete(state.sse_connections, map_id)

    new_state = %{state | monitored_maps: new_monitored, sse_connections: new_connections}

    # Schedule reconnection
    Process.send_after(self(), {:reconnect_map, map_id}, 5000)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:reconnect_map, map_id}, state) do
    Logger.info("Attempting to reconnect SSE for map #{map_id}")

    {:ok, connection_pid} = start_sse_connection(map_id, state)
    new_monitored = MapSet.put(state.monitored_maps, map_id)
    new_connections = Map.put(state.sse_connections, map_id, connection_pid)

    new_state = %{state | monitored_maps: new_monitored, sse_connections: new_connections}

    Logger.info("Successfully reconnected SSE for map #{map_id}")
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp get_base_url_from_env do
    System.get_env("WANDERER_BASE_URL") || @default_base_url
  end

  defp get_api_token_from_env do
    System.get_env("WANDERER_API_TOKEN")
  end

  defp start_sse_connection(map_id, state) do
    url = build_sse_url(map_id, state)

    headers = [
      {"Accept", "text/event-stream"},
      {"Cache-Control", "no-cache"}
    ]

    parent_pid = self()

    # Note: Current approach uses spawn_link which ensures the SSE connection
    # is terminated if the parent GenServer crashes. This is acceptable
    # for SSE connections as they need to be tightly coupled to their parent.
    connection_pid =
      spawn_link(fn ->
        sse_loop(map_id, url, headers, parent_pid)
      end)

    {:ok, connection_pid}
  end

  defp build_sse_url(map_id, state) do
    base_url = "#{state.base_url}/api/maps/#{map_id}/events/stream"

    params =
      []
      |> maybe_add_param("token", state.api_token)
      |> maybe_add_param("include_state", "true")
      |> maybe_add_param(
        "events",
        "character_location_changed,add_system,character_ship_changed,character_online_status_changed"
      )
      |> Enum.filter(fn {_k, v} -> v end)

    if params == [] do
      base_url
    else
      query_string = URI.encode_query(params)
      "#{base_url}?#{query_string}"
    end
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: [{key, value} | params]

  defp sse_loop(map_id, url, headers, parent_pid) do
    Logger.info("Starting SSE connection for map #{map_id} at #{url}")

    case HTTPoison.get(url, headers, stream_to: self(), recv_timeout: :infinity) do
      {:ok, %HTTPoison.AsyncResponse{id: _id}} ->
        sse_receive_loop(map_id, parent_pid)

      {:error, reason} ->
        send(parent_pid, {:sse_connection_closed, map_id, reason})
    end
  end

  defp sse_receive_loop(map_id, parent_pid) do
    receive do
      %HTTPoison.AsyncStatus{code: 200} ->
        Logger.debug("SSE connection established for map #{map_id}")
        sse_receive_loop(map_id, parent_pid)

      %HTTPoison.AsyncStatus{code: code} ->
        Logger.error("SSE connection failed for map #{map_id} with status #{code}")
        send(parent_pid, {:sse_connection_closed, map_id, {:http_error, code}})

      %HTTPoison.AsyncHeaders{headers: _headers} ->
        sse_receive_loop(map_id, parent_pid)

      %HTTPoison.AsyncChunk{chunk: chunk} ->
        process_sse_chunk(map_id, chunk, parent_pid)
        sse_receive_loop(map_id, parent_pid)

      %HTTPoison.AsyncEnd{} ->
        Logger.info("SSE connection ended for map #{map_id}")
        send(parent_pid, {:sse_connection_closed, map_id, :connection_ended})

      {:error, reason} ->
        send(parent_pid, {:sse_connection_closed, map_id, reason})
    end
  end

  defp process_sse_chunk(map_id, chunk, parent_pid) do
    # Parse SSE format: "data: {...}\n\n"
    chunk
    |> String.split("\n\n")
    |> Enum.each(fn event_block ->
      if String.starts_with?(event_block, "data: ") do
        json_data = String.trim_leading(event_block, "data: ")

        case Jason.decode(json_data) do
          {:ok, event_data} ->
            send(parent_pid, {:sse_event, map_id, event_data})

          {:error, _reason} ->
            Logger.debug("Failed to parse SSE event data: #{json_data}")
        end
      end
    end)
  end

  defp process_sse_event(map_id, event_data) do
    event_type = Map.get(event_data, "type")
    payload = Map.get(event_data, "payload", %{})
    initial_state = Map.get(event_data, "initial_state", false)

    Logger.debug(
      "Received SSE event for map #{map_id}: #{event_type} (initial: #{initial_state})"
    )

    # Only process relevant events for chain intelligence
    if should_process_event?(event_type) do
      # Forward to ChainMonitor with Wanderer format
      GenServer.cast(EveDmv.Intelligence.ChainMonitor, {
        :wanderer_event,
        map_id,
        event_type,
        payload
      })

      # Broadcast via PubSub
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:#{map_id}",
        {:wanderer_event, event_type, payload}
      )
    end
  end

  defp should_process_event?(event_type) do
    case event_type do
      "character_location_changed" -> true
      "character_ship_changed" -> true
      "character_online_status_changed" -> true
      "character_ready_status_changed" -> true
      "add_system" -> true
      "map_kill" -> true
      _ -> false
    end
  end
end
