defmodule EveDmv.Intelligence.WandererClient do
  @moduledoc """
  Client for Wanderer Map API integration.

  Provides functions to fetch chain topology, system inhabitants,
  and maintain real-time connections via Server-Sent Events (SSE).
  """

  use GenServer
  require Logger

  defstruct [
    :auth_token,
    :sse_pid,
    :sse_connections,
    :monitored_maps,
    :rate_limiter,
    :connection_state
  ]

  @api_timeout 30_000
  @max_retries 3
  @retry_delay 5_000

  # Get base URL at runtime for better configuration flexibility
  defp base_url do
    Application.get_env(:eve_dmv, :wanderer_base_url, "http://host.docker.internal:4004")
  end

  # Get SSE URL for real-time updates
  defp sse_url(map_id) do
    Application.get_env(:eve_dmv, :wanderer_sse_url, "#{base_url()}/api/maps/#{map_id}/events/stream")
  end

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
  Fetch chain inhabitants for a map (alias for get_system_inhabitants).
  """
  def get_chain_inhabitants(map_id) do
    get_system_inhabitants(map_id)
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

  @impl GenServer
  def init(opts) do
    auth_token = Keyword.get(opts, :auth_token) || get_auth_token_from_env()

    state = %__MODULE__{
      auth_token: auth_token,
      sse_pid: nil,
      sse_connections: %{},
      monitored_maps: MapSet.new(),
      rate_limiter: :ets.new(:wanderer_rate_limiter, [:set, :private]),
      connection_state: :disconnected
    }

    {:ok, state}
  end

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
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

  @impl GenServer
  def handle_call(:connection_status, _from, state) do
    status = %{
      sse: state.connection_state,
      monitored_maps: MapSet.to_list(state.monitored_maps),
      auth_token_present: state.auth_token != nil
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_cast({:monitor_map, map_id}, state) do
    new_monitored = MapSet.put(state.monitored_maps, map_id)

    # Start individual SSE connection for this map
    case connect_sse_for_map(map_id, state.auth_token) do
      {:ok, sse_pid} ->
        Logger.info("Started SSE monitoring for map #{map_id}")
        new_sse_connections = Map.put(state.sse_connections || %{}, map_id, sse_pid)
        {:noreply, %{state | monitored_maps: new_monitored, sse_connections: new_sse_connections}}

      {:error, reason} ->
        Logger.error("Failed to start SSE for map #{map_id}: #{inspect(reason)}")
        {:noreply, %{state | monitored_maps: new_monitored}}
    end
  end

  @impl GenServer
  def handle_cast({:unmonitor_map, map_id}, state) do
    new_monitored = MapSet.delete(state.monitored_maps, map_id)

    # Stop SSE connection for this map
    if sse_pid = get_in(state.sse_connections || %{}, [map_id]) do
      send(sse_pid, :close)
      new_sse_connections = Map.delete(state.sse_connections || %{}, map_id)
      Logger.info("Stopped SSE monitoring for map #{map_id}")
      {:noreply, %{state | monitored_maps: new_monitored, sse_connections: new_sse_connections}}
    else
      Logger.info("No longer monitoring map #{map_id}")
      {:noreply, %{state | monitored_maps: new_monitored}}
    end
  end

  @impl GenServer
  def handle_info({:sse_event, map_id, event_data}, state) do
    case Jason.decode(event_data) do
      {:ok, data} ->
        handle_sse_event(data, map_id, state)

      {:error, reason} ->
        Logger.error("Failed to decode SSE message for map #{map_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:sse_closed, map_id, reason}, state) do
    Logger.warning("Wanderer SSE connection closed for map #{map_id}: #{inspect(reason)}")
    
    # Remove from connections and attempt reconnect if still monitoring
    new_sse_connections = Map.delete(state.sse_connections || %{}, map_id)
    
    if MapSet.member?(state.monitored_maps, map_id) do
      # Retry connection after delay
      Process.send_after(self(), {:reconnect_sse, map_id}, 5_000)
    end
    
    {:noreply, %{state | sse_connections: new_sse_connections}}
  end

  @impl GenServer
  def handle_info({:reconnect_sse, map_id}, state) do
    if MapSet.member?(state.monitored_maps, map_id) do
      case connect_sse_for_map(map_id, state.auth_token) do
        {:ok, sse_pid} ->
          Logger.info("Reconnected SSE for map #{map_id}")
          new_sse_connections = Map.put(state.sse_connections, map_id, sse_pid)
          {:noreply, %{state | sse_connections: new_sse_connections}}

        {:error, reason} ->
          Logger.error("Failed to reconnect SSE for map #{map_id}: #{inspect(reason)}")
          Process.send_after(self(), {:reconnect_sse, map_id}, 10_000)
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
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
    url = "#{base_url()}/api/maps/#{map_id}/systems"
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
    url = "#{base_url()}/api/maps/#{map_id}/connections"
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

  defp connect_sse_for_map(map_id, auth_token) do
    # Start SSE connection process for a specific map
    parent_pid = self()
    
    sse_pid = spawn_link(fn -> 
      sse_loop(parent_pid, map_id, auth_token)
    end)
    
    {:ok, sse_pid}
  end

  defp sse_loop(parent_pid, map_id, auth_token) do
    url = sse_url(map_id)
    headers = build_headers(auth_token)
    
    # Add SSE-specific headers
    headers = headers ++ [
      {"Accept", "text/event-stream"},
      {"Cache-Control", "no-cache"}
    ]
    
    case HTTPoison.get(url, headers, 
      stream_to: self(), 
      async: :once,
      timeout: :infinity,
      recv_timeout: :infinity
    ) do
      {:ok, %HTTPoison.AsyncResponse{id: _id}} ->
        Logger.info("SSE connection established to #{url} for map #{map_id}")
        sse_receive_loop(parent_pid, map_id)
        
      {:error, reason} ->
        Logger.error("Failed to establish SSE connection for map #{map_id}: #{inspect(reason)}")
        send(parent_pid, {:sse_closed, map_id, reason})
    end
  end

  defp sse_receive_loop(parent_pid, map_id) do
    receive do
      %HTTPoison.AsyncStatus{code: code} ->
        if code == 200 do
          HTTPoison.stream_next(self())
          sse_receive_loop(parent_pid, map_id)
        else
          Logger.error("SSE connection failed with status: #{code} for map #{map_id}")
          send(parent_pid, {:sse_closed, map_id, {:http_error, code}})
        end

      %HTTPoison.AsyncHeaders{headers: _headers} ->
        HTTPoison.stream_next(self())
        sse_receive_loop(parent_pid, map_id)

      %HTTPoison.AsyncChunk{chunk: chunk} ->
        process_sse_chunk(chunk, parent_pid, map_id)
        HTTPoison.stream_next(self())
        sse_receive_loop(parent_pid, map_id)

      %HTTPoison.AsyncEnd{} ->
        Logger.info("SSE stream ended for map #{map_id}")
        send(parent_pid, {:sse_closed, map_id, :stream_ended})

      {:timeout, _} ->
        # Heartbeat timeout - reconnect
        Logger.warning("SSE connection timeout for map #{map_id}")
        send(parent_pid, {:sse_closed, map_id, :timeout})

      :close ->
        Logger.info("SSE connection closed by request for map #{map_id}")
        send(parent_pid, {:sse_closed, map_id, :normal})

    after
      # Heartbeat timeout - 5 minutes
      300_000 ->
        Logger.warning("SSE heartbeat timeout for map #{map_id}")
        send(parent_pid, {:sse_closed, map_id, :heartbeat_timeout})
    end
  end

  defp process_sse_chunk(chunk, parent_pid, map_id) do
    # SSE events are formatted as:
    # event: event_type\n
    # data: json_data\n\n
    
    chunk
    |> String.split("\n\n")
    |> Enum.each(fn event_block ->
      if String.trim(event_block) != "" do
        parse_sse_event(event_block, parent_pid, map_id)
      end
    end)
  end

  defp parse_sse_event(event_block, parent_pid, map_id) do
    lines = String.split(event_block, "\n")
    
    {_event_type, data} = 
      Enum.reduce(lines, {nil, nil}, fn line, {event_type, data} ->
        cond do
          String.starts_with?(line, "event:") ->
            {String.trim(String.slice(line, 6..-1//-1)), data}
          
          String.starts_with?(line, "data:") ->
            {event_type, String.trim(String.slice(line, 5..-1//-1))}
          
          true ->
            {event_type, data}
        end
      end)
    
    if data do
      send(parent_pid, {:sse_event, map_id, data})
    end
  end

  defp handle_sse_event(%{"type" => "add_system", "payload" => payload}, map_id, state) do
    # Handle system added events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:chain_updates",
        {:chain_topology_update, map_id, %{"type" => "add_system", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "connection_added", "payload" => payload}, map_id, state) do
    # Handle connection added events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:chain_updates",
        {:chain_topology_update, map_id, %{"type" => "connection_added", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "connection_removed", "payload" => payload}, map_id, state) do
    # Handle connection removed events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:chain_updates",
        {:chain_topology_update, map_id, %{"type" => "connection_removed", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "map_kill", "payload" => payload}, map_id, state) do
    # Handle kill events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "killmails:enriched",
        {:killmail_activity, %{map_id: map_id, payload: payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "signature_added", "payload" => payload}, map_id, state) do
    # Handle signature added events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:chain_updates",
        {:chain_topology_update, map_id, %{"type" => "signature_added", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "signature_removed", "payload" => payload}, map_id, state) do
    # Handle signature removed events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:chain_updates",
        {:chain_topology_update, map_id, %{"type" => "signature_removed", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "acl_member_added", "payload" => payload}, map_id, state) do
    # Handle ACL member added events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:inhabitant_updates",
        {:inhabitant_update, map_id, nil, %{"type" => "acl_member_added", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(%{"type" => "acl_member_removed", "payload" => payload}, map_id, state) do
    # Handle ACL member removed events
    if MapSet.member?(state.monitored_maps, map_id) do
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "wanderer:inhabitant_updates",
        {:inhabitant_update, map_id, nil, %{"type" => "acl_member_removed", "payload" => payload}}
      )
    end

    {:noreply, state}
  end

  defp handle_sse_event(data, map_id, state) do
    Logger.debug("Unhandled SSE event for map #{map_id}: #{inspect(data)}")
    {:noreply, state}
  end
end
