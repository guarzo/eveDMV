defmodule EveDmv.Intelligence.WandererClient do
  @moduledoc """
  Client for Wanderer Map API integration.

  Provides functions to fetch chain topology, system inhabitants,
  and maintain real-time connections via Server-Sent Events (SSE).
  """

  use GenServer

  alias EveDmv.Core.Utils.DnsResolver
  alias EveDmv.Core.Utils.RetryUtils
  alias HTTPoison
  alias Jason

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

  @type t :: %__MODULE__{
          auth_token: String.t() | nil,
          sse_pid: pid() | nil,
          sse_connections: map(),
          monitored_maps: MapSet.t(),
          rate_limiter: pid() | nil,
          connection_state: atom()
        }

  # Get base URL at runtime for better configuration flexibility
  defp base_url do
    # Try to get working URL from DNS resolver, fallback to config
    case DnsResolver.get_service_url(:wanderer) do
      url when is_binary(url) -> url
      _ -> Application.get_env(:eve_dmv, :wanderer_base_url, "http://host.docker.internal:4004")
    end
  end

  # Get SSE URL for real-time updates
  defp sse_url(map_id) do
    Application.get_env(
      :eve_dmv,
      :wanderer_sse_url,
      "#{base_url()}/api/maps/#{map_id}/events/stream"
    )
  end

  # Public API

  @doc """
  Start the Wanderer client GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
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
  @spec get_chain_topology(String.t() | integer()) :: {:ok, map()} | {:error, term()}
  def get_chain_topology(map_id) do
    GenServer.call(__MODULE__, {:get_chain_topology, map_id}, @api_timeout)
  end

  @doc """
  Fetch system inhabitants for a map.
  """
  @spec get_system_inhabitants(String.t() | integer()) :: {:ok, list(map())} | {:error, term()}
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
  @spec get_connections(String.t() | integer()) :: {:ok, list(map())} | {:error, term()}
  def get_connections(map_id) do
    GenServer.call(__MODULE__, {:get_connections, map_id}, @api_timeout)
  end

  @doc """
  Subscribe to real-time updates for a map.
  """
  @spec monitor_map(String.t() | integer()) :: :ok
  def monitor_map(map_id) do
    GenServer.cast(__MODULE__, {:monitor_map, map_id})
  end

  @doc """
  Unsubscribe from real-time updates for a map.
  """
  @spec unmonitor_map(String.t() | integer()) :: :ok
  def unmonitor_map(map_id) do
    GenServer.cast(__MODULE__, {:unmonitor_map, map_id})
  end

  @doc """
  Get current connection status.
  """
  @spec connection_status() :: {:ok, atom()} | {:error, term()}
  def connection_status do
    GenServer.call(__MODULE__, :connection_status)
  end

  @doc """
  Check if a system is in the chain and get its distance from home.

  This function queries the currently monitored maps to determine if a given
  system is part of any wormhole chain and how many jumps it is from home.

  ## Parameters
  - `system_id` - The EVE solar system ID to check

  ## Returns
  - `{:ok, %{in_chain: true, jumps_from_home: integer}}` if system is in chain
  - `{:ok, %{in_chain: false}}` if system is not in any monitored chain
  - `{:error, reason}` if the check fails

  ## Examples
      iex> WandererClient.check_system_in_chain(30000142)
      {:ok, %{in_chain: true, jumps_from_home: 3}}

      iex> WandererClient.check_system_in_chain(30002187)
      {:ok, %{in_chain: false}}
  """
  @spec check_system_in_chain(integer()) :: {:ok, map()} | {:error, term()}
  def check_system_in_chain(system_id) do
    GenServer.call(__MODULE__, {:check_system_in_chain, system_id}, @api_timeout)
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
  def handle_call({:check_system_in_chain, system_id}, _from, state) do
    # Check all monitored maps for the system
    result = check_system_in_all_chains(system_id, state.monitored_maps, state.auth_token)
    {:reply, result, state}
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
    connections = state.sse_connections || %{}

    # Stop SSE connection for this map
    case Map.get(connections, map_id) do
      nil ->
        Logger.info("No longer monitoring map #{map_id}")
        {:noreply, %{state | monitored_maps: new_monitored}}

      sse_pid ->
        send(sse_pid, :close)
        new_sse_connections = Map.delete(connections, map_id)
        Logger.info("Stopped SSE monitoring for map #{map_id}")
        {:noreply, %{state | monitored_maps: new_monitored, sse_connections: new_sse_connections}}
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

  @spec get_auth_token_from_env() :: String.t() | nil
  defp get_auth_token_from_env do
    System.get_env("WANDERER_AUTH_TOKEN")
  end

  defp check_system_in_all_chains(system_id, monitored_maps, auth_token) do
    # Convert to integer if string
    system_id =
      case Integer.parse(to_string(system_id)) do
        {id, _} -> id
        :error -> system_id
      end

    # If no maps are being monitored, system is not in chain
    if MapSet.size(monitored_maps) == 0 do
      {:ok, %{in_chain: false}}
    else
      # Check each monitored map
      monitored_maps
      |> MapSet.to_list()
      |> Enum.reduce_while({:ok, %{in_chain: false}}, fn map_id, _acc ->
        case check_system_in_single_chain(system_id, map_id, auth_token) do
          {:ok, %{in_chain: true} = result} ->
            # Found in this chain, return result
            {:halt, {:ok, result}}

          {:ok, %{in_chain: false}} ->
            # Not in this chain, continue checking
            {:cont, {:ok, %{in_chain: false}}}

          {:error, _reason} ->
            # Error checking this chain, continue to next
            {:cont, {:ok, %{in_chain: false}}}
        end
      end)
    end
  rescue
    error ->
      Logger.error("Error checking system #{system_id} in chains: #{inspect(error)}")
      {:error, "Failed to check system in chain: #{inspect(error)}"}
  end

  defp check_system_in_single_chain(system_id, map_id, auth_token) do
    case fetch_with_retry(fn -> get_systems_api(map_id, auth_token) end) do
      {:ok, data} ->
        # Parse topology and check if system is present
        topology = parse_topology_data(data)
        systems = Map.get(topology, "systems", [])

        # Check if system exists in this chain
        system_found =
          Enum.find(systems, fn system ->
            Map.get(system, "solar_system_id") == system_id or
              Map.get(system, "id") == system_id or
              Map.get(system, "system_id") == system_id
          end)

        if system_found do
          # System is in chain, calculate jumps from home
          # For now, return a basic distance - this could be enhanced with pathfinding
          jumps_from_home = calculate_jumps_from_home(system_id, systems, map_id, auth_token)
          {:ok, %{in_chain: true, jumps_from_home: jumps_from_home, map_id: map_id}}
        else
          {:ok, %{in_chain: false}}
        end

      {:error, reason} ->
        Logger.warning("Failed to fetch systems for map #{map_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_jumps_from_home(system_id, systems, _map_id, _auth_token) do
    # This is a simplified implementation
    # In a real implementation, you'd need to:
    # 1. Identify the home system (could be marked in system data or configured)
    # 2. Fetch connections data to build a graph
    # 3. Use pathfinding to calculate actual jump distance

    # For now, estimate based on system position in the list
    # This is not accurate but provides a placeholder implementation
    system_index =
      Enum.find_index(systems, fn system ->
        Map.get(system, "solar_system_id") == system_id or
          Map.get(system, "id") == system_id or
          Map.get(system, "system_id") == system_id
      end)

    case system_index do
      # Should not happen since we already found the system
      nil -> 0
      # First system is likely home
      0 -> 0
      # Cap at 10 jumps for safety
      index -> min(index, 10)
    end
  rescue
    error ->
      Logger.warning("Error calculating jumps for system #{system_id}: #{inspect(error)}")
      # Default fallback distance
      5
  end

  defp fetch_with_retry(fetch_fn) do
    operation = fn ->
      case fetch_fn.() do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:retry, reason}
      end
    end

    log_fn = fn reason, delay_ms, attempt, max_retries ->
      Logger.warning(
        "API request failed (attempt #{attempt}), retrying in #{delay_ms}ms: #{inspect(reason)}"
      )

      _ = max_retries
    end

    RetryUtils.retry_with_backoff(operation,
      max_retries: @max_retries,
      base_delay_ms: @retry_delay,
      log_fn: log_fn
    )
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

  defp parse_topology_data(response_data) do
    # Transform Wanderer response data into our topology format
    # Handle the actual API response structure: %{"data" => %{"connections" => [...], "systems" => [...]}}

    case response_data do
      %{"data" => %{"systems" => systems}} when is_list(systems) ->
        %{
          "systems" => systems,
          "system_count" => length(systems),
          "last_updated" => DateTime.utc_now()
        }

      %{"data" => %{"connections" => connections}} when is_list(connections) ->
        # If only connections are provided, extract unique systems from connections
        systems = extract_systems_from_connections(connections)

        %{
          "systems" => systems,
          "system_count" => length(systems),
          "last_updated" => DateTime.utc_now()
        }

      %{"data" => data} when is_map(data) ->
        # Fallback: try to extract systems from data
        systems = Map.get(data, "systems", [])
        connections = Map.get(data, "connections", [])

        all_systems =
          if Enum.empty?(systems) do
            extract_systems_from_connections(connections)
          else
            systems
          end

        %{
          "systems" => all_systems,
          "system_count" => length(all_systems),
          "connections" => connections,
          "last_updated" => DateTime.utc_now()
        }

      # Legacy format support
      systems_list when is_list(systems_list) ->
        %{
          "systems" => systems_list,
          "system_count" => length(systems_list),
          "last_updated" => DateTime.utc_now()
        }

      _ ->
        Logger.warning("Unexpected topology data format: #{inspect(response_data)}")

        %{
          "systems" => [],
          "system_count" => 0,
          "last_updated" => DateTime.utc_now()
        }
    end
  end

  defp extract_systems_from_connections(connections) when is_list(connections) do
    connections
    |> Enum.flat_map(fn conn ->
      [
        Map.get(conn, "solar_system_source"),
        Map.get(conn, "solar_system_target")
      ]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(fn system_id ->
      %{
        "id" => system_id,
        "solar_system_id" => system_id,
        # Would need EVE name resolution
        "name" => "System #{system_id}"
      }
    end)
  end

  defp extract_systems_from_connections(_), do: []

  defp parse_inhabitants_data(response_data) do
    # Extract inhabitant information from response data
    # Handle the actual API response structure
    case response_data do
      %{"data" => %{"systems" => systems}} when is_list(systems) ->
        Enum.flat_map(systems, fn system ->
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

      %{"data" => %{"inhabitants" => inhabitants}} when is_list(inhabitants) ->
        Enum.map(inhabitants, fn inhabitant ->
          %{
            "character_id" => Map.get(inhabitant, "character_id"),
            "character_name" => Map.get(inhabitant, "character_name"),
            "corporation_id" => Map.get(inhabitant, "corporation_id"),
            "system_id" => Map.get(inhabitant, "system_id"),
            "ship_type_id" => Map.get(inhabitant, "ship_type_id"),
            "last_seen" => Map.get(inhabitant, "last_seen")
          }
        end)

      # Legacy format support - direct list
      systems_data when is_list(systems_data) ->
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

      _ ->
        Logger.warning("Unexpected inhabitants data format: #{inspect(response_data)}")
        []
    end
  end

  defp parse_connections_data(connections_data) when is_list(connections_data) do
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

  defp parse_connections_data(connections_data) do
    Logger.warning("Unexpected connections data format: #{inspect(connections_data)}")
    []
  end

  defp connect_sse_for_map(map_id, auth_token) do
    # Start SSE connection process for a specific map
    parent_pid = self()

    sse_pid =
      spawn_link(fn ->
        sse_loop(parent_pid, map_id, auth_token)
      end)

    {:ok, sse_pid}
  rescue
    error ->
      Logger.error("Failed to spawn SSE process for map #{map_id}: #{inspect(error)}")
      {:error, error}
  end

  defp sse_loop(parent_pid, map_id, auth_token) do
    url = sse_url(map_id)

    # Build headers with SSE-specific headers
    headers =
      build_headers(auth_token) ++
        [
          {"Accept", "text/event-stream"},
          {"Cache-Control", "no-cache"}
        ]

    case HTTPoison.get(url, headers,
           stream_to: self(),
           async: :once,
           timeout: :infinity,
           recv_timeout: :infinity
         ) do
      {:ok, %HTTPoison.AsyncResponse{} = async_response} ->
        Logger.info("SSE connection established to #{url} for map #{map_id}")
        sse_receive_loop(parent_pid, map_id, async_response)

      {:error, reason} ->
        Logger.error("Failed to establish SSE connection for map #{map_id}: #{inspect(reason)}")
        send(parent_pid, {:sse_closed, map_id, reason})
    end
  end

  @dialyzer {:nowarn_function, sse_receive_loop: 3}
  defp sse_receive_loop(parent_pid, map_id, async_response) do
    receive do
      %HTTPoison.AsyncStatus{code: code} ->
        if code == 200 do
          case HTTPoison.stream_next(async_response) do
            {:ok, _} -> sse_receive_loop(parent_pid, map_id, async_response)
            {:error, reason} -> send(parent_pid, {:sse_closed, map_id, {:stream_error, reason}})
          end
        else
          Logger.error("SSE connection failed with status: #{code} for map #{map_id}")
          send(parent_pid, {:sse_closed, map_id, {:http_error, code}})
        end

      %HTTPoison.AsyncHeaders{headers: _headers} ->
        case HTTPoison.stream_next(async_response) do
          {:ok, _} -> sse_receive_loop(parent_pid, map_id, async_response)
          {:error, reason} -> send(parent_pid, {:sse_closed, map_id, {:stream_error, reason}})
        end

      %HTTPoison.AsyncChunk{chunk: chunk} ->
        process_sse_chunk(chunk, parent_pid, map_id)

        case HTTPoison.stream_next(async_response) do
          {:ok, _} -> sse_receive_loop(parent_pid, map_id, async_response)
          {:error, reason} -> send(parent_pid, {:sse_closed, map_id, {:stream_error, reason}})
        end

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
