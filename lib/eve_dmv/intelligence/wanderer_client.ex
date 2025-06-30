defmodule EveDmv.Intelligence.WandererClient do
  @moduledoc """
  Client for Wanderer Map API integration.

  Provides functions to fetch chain topology, system inhabitants,
  and maintain real-time connections via WebSocket.
  """

  use GenServer
  require Logger

  @base_url Application.compile_env(
              :eve_dmv,
              :wanderer_base_url,
              "http://host.docker.internal:4004"
            )
  @api_timeout 30_000
  @max_retries 3
  @retry_delay 5_000

  defstruct [
    :auth_token,
    :websocket_pid,
    :monitored_maps,
    :rate_limiter,
    :connection_state
  ]

  # Public API

  @doc """
  Start the Wanderer client GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fetch chain topology for a specific map.

  ## Parameters
  - map_id: Wanderer map identifier (UUID or slug)

  ## Returns
  - {:ok, topology_data} on success
  - {:error, reason} on failure
  """
  def get_chain_topology(map_id) do
    GenServer.call(__MODULE__, {:get_chain_topology, map_id}, @api_timeout)
  end

  @doc """
  Fetch system inhabitants for a map.
  """
  def get_system_inhabitants(map_id) do
    GenServer.call(__MODULE__, {:get_system_inhabitants, map_id}, @api_timeout)
  end

  @doc """
  Fetch connections for a map.
  """
  def get_connections(map_id) do
    GenServer.call(__MODULE__, {:get_connections, map_id}, @api_timeout)
  end

  @doc """
  Subscribe to real-time updates for a map.
  """
  def monitor_map(map_id) do
    GenServer.cast(__MODULE__, {:monitor_map, map_id})
  end

  @doc """
  Unsubscribe from real-time updates for a map.
  """
  def unmonitor_map(map_id) do
    GenServer.cast(__MODULE__, {:unmonitor_map, map_id})
  end

  @doc """
  Get current connection status.
  """
  def connection_status do
    GenServer.call(__MODULE__, :connection_status)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    auth_token = Keyword.get(opts, :auth_token) || get_auth_token_from_env()

    state = %__MODULE__{
      auth_token: auth_token,
      websocket_pid: nil,
      monitored_maps: MapSet.new(),
      rate_limiter: :ets.new(:wanderer_rate_limiter, [:set, :private]),
      connection_state: :disconnected
    }

    # Start WebSocket connection
    send(self(), :connect_websocket)

    {:ok, state}
  end

  @impl true
  def handle_call({:get_chain_topology, map_id}, _from, state) do
    case fetch_with_retry(fn -> get_systems_api(map_id, state.auth_token) end) do
      {:ok, data} ->
        topology = parse_topology_data(data)
        {:reply, {:ok, topology}, state}

      {:error, reason} ->
        Logger.error("Failed to fetch chain topology for #{map_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_system_inhabitants, map_id}, _from, state) do
    # This would typically come from Wanderer's fleet/inhabitant tracking
    # For now, we'll extract from the systems data
    case fetch_with_retry(fn -> get_systems_api(map_id, state.auth_token) end) do
      {:ok, data} ->
        inhabitants = parse_inhabitants_data(data)
        {:reply, {:ok, inhabitants}, state}

      {:error, reason} ->
        Logger.error("Failed to fetch inhabitants for #{map_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_connections, map_id}, _from, state) do
    case fetch_with_retry(fn -> get_connections_api(map_id, state.auth_token) end) do
      {:ok, data} ->
        connections = parse_connections_data(data)
        {:reply, {:ok, connections}, state}

      {:error, reason} ->
        Logger.error("Failed to fetch connections for #{map_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:connection_status, _from, state) do
    status = %{
      websocket: state.connection_state,
      monitored_maps: MapSet.to_list(state.monitored_maps),
      auth_token_present: state.auth_token != nil
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:monitor_map, map_id}, state) do
    new_monitored = MapSet.put(state.monitored_maps, map_id)

    # Subscribe to WebSocket events for this map
    send_websocket_message(state.websocket_pid, %{
      "action" => "subscribe",
      "map_id" => map_id
    })

    {:noreply, %{state | monitored_maps: new_monitored}}
  end

  @impl true
  def handle_cast({:unmonitor_map, map_id}, state) do
    new_monitored = MapSet.delete(state.monitored_maps, map_id)

    # Unsubscribe from WebSocket events
    send_websocket_message(state.websocket_pid, %{
      "action" => "unsubscribe",
      "map_id" => map_id
    })

    {:noreply, %{state | monitored_maps: new_monitored}}
  end

  @impl true
  def handle_info(:connect_websocket, state) do
    {:ok, ws_pid} = connect_websocket(state.auth_token)
    Logger.info("Connected to Wanderer WebSocket")
    {:noreply, %{state | websocket_pid: ws_pid, connection_state: :connected}}
  end

  @impl true
  def handle_info({:websocket_message, message}, state) do
    case Jason.decode(message) do
      {:ok, data} ->
        handle_websocket_event(data, state)

      {:error, reason} ->
        Logger.error("Failed to decode WebSocket message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:websocket_closed, _reason}, state) do
    Logger.warning("Wanderer WebSocket connection closed, reconnecting...")
    Process.send_after(self(), :connect_websocket, 5_000)
    {:noreply, %{state | websocket_pid: nil, connection_state: :reconnecting}}
  end

  # Private Functions

  defp get_auth_token_from_env do
    System.get_env("WANDERER_AUTH_TOKEN")
  end

  defp fetch_with_retry(fetch_fn, retries \\ 0) do
    case fetch_fn.() do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} when retries < @max_retries ->
        Logger.warning(
          "API request failed (attempt #{retries + 1}), retrying in #{@retry_delay}ms: #{inspect(reason)}"
        )

        :timer.sleep(@retry_delay)
        fetch_with_retry(fetch_fn, retries + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_systems_api(map_id, auth_token) do
    url = "#{@base_url}/api/maps/#{map_id}/systems"
    headers = build_headers(auth_token)

    case HTTPoison.get(url, headers, timeout: @api_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_connections_api(map_id, auth_token) do
    url = "#{@base_url}/api/maps/#{map_id}/connections"
    headers = build_headers(auth_token)

    case HTTPoison.get(url, headers, timeout: @api_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_headers(auth_token) when is_binary(auth_token) do
    [
      {"Authorization", "Bearer #{auth_token}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  defp build_headers(_),
    do: [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

  defp parse_topology_data(systems_data) do
    # Transform Wanderer systems data into our topology format
    %{
      "systems" => systems_data,
      "system_count" => length(systems_data),
      "last_updated" => DateTime.utc_now()
    }
  end

  defp parse_inhabitants_data(systems_data) do
    # Extract inhabitant information from systems data
    # This would depend on Wanderer's actual data structure
    Enum.flat_map(systems_data, fn system ->
      inhabitants = Map.get(system, "inhabitants", [])

      Enum.map(inhabitants, fn inhabitant ->
        %{
          "character_id" => Map.get(inhabitant, "character_id"),
          "character_name" => Map.get(inhabitant, "character_name"),
          "corporation_id" => Map.get(inhabitant, "corporation_id"),
          "system_id" => Map.get(system, "system_id"),
          "ship_type_id" => Map.get(inhabitant, "ship_type_id"),
          "last_seen" => Map.get(inhabitant, "last_seen")
        }
      end)
    end)
  end

  defp parse_connections_data(connections_data) do
    # Transform Wanderer connections data into our format
    Enum.map(connections_data, fn conn ->
      %{
        "source_system_id" => Map.get(conn, "source_system_id"),
        "target_system_id" => Map.get(conn, "target_system_id"),
        "signature_id" => Map.get(conn, "signature_id"),
        "wormhole_type" => Map.get(conn, "wormhole_type"),
        "mass_status" => Map.get(conn, "mass_status"),
        "time_status" => Map.get(conn, "time_status"),
        "is_eol" => Map.get(conn, "is_eol", false)
      }
    end)
  end

  defp connect_websocket(auth_token) do
    # This is a simplified WebSocket connection
    # In reality, you'd use a proper WebSocket client like Gun or WebSockex
    {:ok, spawn_link(fn -> websocket_loop(auth_token) end)}
  end

  defp websocket_loop(auth_token) do
    # Placeholder for WebSocket connection loop
    # This would handle the actual WebSocket protocol
    receive do
      {:send_message, message} ->
        # Send message to WebSocket
        Logger.debug("Sending WebSocket message: #{inspect(message)}")
        websocket_loop(auth_token)

      {:websocket_data, data} ->
        # Forward received data to the main process
        send(__MODULE__, {:websocket_message, data})
        websocket_loop(auth_token)

      :close ->
        Logger.info("WebSocket connection closed")
        send(__MODULE__, {:websocket_closed, :normal})
    end
  end

  defp send_websocket_message(nil, _message), do: :ok

  defp send_websocket_message(ws_pid, message) when is_pid(ws_pid) do
    send(ws_pid, {:send_message, message})
  end

  defp handle_websocket_event(%{"event" => "system_update", "data" => data}, state) do
    # Handle system inhabitant updates
    map_id = Map.get(data, "map_id")

    if MapSet.member?(state.monitored_maps, map_id) do
      # Process the update and broadcast to subscribers
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "chain_intelligence:#{map_id}",
        {:system_update, data}
      )
    end

    {:noreply, state}
  end

  defp handle_websocket_event(%{"event" => "connection_update", "data" => data}, state) do
    # Handle connection status updates
    map_id = Map.get(data, "map_id")

    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "chain_intelligence:#{map_id}",
        {:connection_update, data}
      )
    end

    {:noreply, state}
  end

  defp handle_websocket_event(data, state) do
    Logger.debug("Unhandled WebSocket event: #{inspect(data)}")
    {:noreply, state}
  end
end
