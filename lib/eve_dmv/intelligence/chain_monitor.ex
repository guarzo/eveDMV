defmodule EveDmv.Intelligence.ChainAnalysis.ChainMonitor do
  @moduledoc """
  Monitors and synchronizes chain topology data from Wanderer API.

  This GenServer manages the periodic synchronization of chain data,
  processes real-time updates, and maintains chain intelligence state.
  """

  use GenServer
  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Intelligence.{SystemInhabitant, WandererClient}
  alias EveDmv.Intelligence.ChainAnalysis.{ChainConnection, ChainTopology}

  # Sync every 30 seconds
  @sync_interval_ms 30_000

  defstruct [
    :monitored_chains,
    :sync_timer,
    :last_sync,
    :sync_errors
  ]

  # Public API

  @doc """
  Start the chain monitor GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start monitoring a specific chain by map_id.
  """
  def monitor_chain(map_id, corporation_id) do
    GenServer.call(__MODULE__, {:monitor_chain, map_id, corporation_id})
  end

  @doc """
  Stop monitoring a specific chain.
  """
  def stop_monitoring(map_id) do
    GenServer.call(__MODULE__, {:stop_monitoring, map_id})
  end

  @doc """
  Get current monitoring status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Force sync all monitored chains immediately.
  """
  def force_sync do
    GenServer.cast(__MODULE__, :force_sync)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      monitored_chains: MapSet.new(),
      sync_timer: nil,
      last_sync: nil,
      sync_errors: %{}
    }

    # Subscribe to Wanderer real-time updates
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "wanderer:updates")

    # Schedule initial sync
    send(self(), :schedule_sync)

    {:ok, state}
  end

  @impl true
  def handle_call({:monitor_chain, map_id, corporation_id}, _from, state) do
    case create_or_update_chain_topology(map_id, corporation_id) do
      {:ok, _topology} ->
        # Add to Wanderer client monitoring (legacy REST API)
        WandererClient.monitor_map(map_id)

        # Subscribe to real-time SSE events
        EveDmv.Intelligence.WandererSSE.monitor_map(map_id)

        new_monitored = MapSet.put(state.monitored_chains, map_id)
        {:reply, :ok, %{state | monitored_chains: new_monitored}}

      {:error, reason} ->
        Logger.error("Failed to start monitoring chain #{map_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:stop_monitoring, map_id}, _from, state) do
    WandererClient.unmonitor_map(map_id)
    EveDmv.Intelligence.WandererSSE.stop_monitoring(map_id)

    new_monitored = MapSet.delete(state.monitored_chains, map_id)
    {:reply, :ok, %{state | monitored_chains: new_monitored}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      monitored_chains: MapSet.to_list(state.monitored_chains),
      last_sync: state.last_sync,
      sync_errors: state.sync_errors,
      wanderer_connection: WandererClient.connection_status()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:force_sync, state) do
    send(self(), :sync_chains)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:wanderer_event, map_id, event_type, event_data}, state) do
    # Handle real-time events from Wanderer WebSocket
    if MapSet.member?(state.monitored_chains, map_id) do
      spawn_task(fn -> process_wanderer_event(map_id, event_type, event_data) end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:schedule_sync, state) do
    timer = Process.send_after(self(), :sync_chains, @sync_interval_ms)
    {:noreply, %{state | sync_timer: timer}}
  end

  @impl true
  def handle_info(:sync_chains, state) do
    new_state = perform_chain_sync(state)

    # Schedule next sync
    timer = Process.send_after(self(), :sync_chains, @sync_interval_ms)

    {:noreply, %{new_state | sync_timer: timer, last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:system_update, data}, state) do
    # Legacy handler - keeping for backward compatibility
    map_id = Map.get(data, "map_id")

    if MapSet.member?(state.monitored_chains, map_id) do
      spawn_task(fn -> process_system_update(map_id, data) end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:connection_update, data}, state) do
    # Legacy handler - keeping for backward compatibility
    map_id = Map.get(data, "map_id")

    if MapSet.member?(state.monitored_chains, map_id) do
      spawn_task(fn -> process_connection_update(map_id, data) end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp perform_chain_sync(state) do
    errors = %{}

    new_errors =
      state.monitored_chains
      |> Enum.reduce(errors, fn map_id, acc ->
        case sync_chain_data(map_id) do
          :ok ->
            Map.delete(acc, map_id)

          {:error, reason} ->
            Logger.warning("Failed to sync chain #{map_id}: #{inspect(reason)}")
            Map.put(acc, map_id, reason)
        end
      end)

    %{state | sync_errors: new_errors}
  end

  defp sync_chain_data(map_id) do
    with {:ok, topology_data} <- WandererClient.get_chain_topology(map_id),
         {:ok, inhabitants_data} <- WandererClient.get_system_inhabitants(map_id),
         {:ok, connections_data} <- WandererClient.get_connections(map_id) do
      # Update topology
      update_chain_topology(map_id, topology_data)

      # Update inhabitants
      update_system_inhabitants(map_id, inhabitants_data)

      # Update connections
      update_chain_connections(map_id, connections_data)

      # Broadcast update
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        "chain_intelligence:#{map_id}",
        {:chain_updated, map_id}
      )

      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_or_update_chain_topology(map_id, corporation_id) do
    # Try to find existing topology
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read!(domain: Api) do
      [topology] ->
        # Chain already exists, update monitoring status
        Ash.update!(topology, %{monitoring_enabled: true}, domain: Api)
        {:ok, topology}

      [] ->
        # Create new chain topology
        topology =
          Ash.create!(
            ChainTopology,
            %{
              map_id: map_id,
              corporation_id: corporation_id,
              monitoring_enabled: true
            },
            domain: Api
          )

        {:ok, topology}
    end
  rescue
    error ->
      {:error, error}
  end

  defp update_chain_topology(map_id, topology_data) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read!(domain: Api) do
      [topology] ->
        Ash.update!(
          topology,
          %{
            topology_data: topology_data,
            system_count: length(Map.get(topology_data, "systems", [])),
            last_activity_at: DateTime.utc_now()
          },
          domain: Api
        )

        {:ok, topology}

      [] ->
        Logger.warning("Chain topology not found for map_id: #{map_id}")
        {:error, :not_found}
    end
  rescue
    error ->
      {:error, error}
  end

  defp update_system_inhabitants(map_id, inhabitants_data) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Mark all current inhabitants as departed
        mark_all_departed(topology.id)

        # Process new inhabitant data in bulk
        bulk_update_or_create_inhabitants(topology.id, inhabitants_data)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mark_all_departed(chain_topology_id) do
    {:ok, inhabitants} =
      SystemInhabitant
      |> Ash.Query.filter(chain_topology_id == ^chain_topology_id and present == true)
      |> Ash.read(domain: Api)

    # Bulk update all inhabitants to mark as departed
    departure_time = DateTime.utc_now()

    Enum.each(inhabitants, fn inhabitant ->
      Ash.update!(inhabitant, %{present: false, departure_time: departure_time}, domain: Api)
    end)
  end

  defp update_or_create_inhabitant(chain_topology_id, inhabitant_data) do
    character_id = Map.get(inhabitant_data, "character_id")
    system_id = Map.get(inhabitant_data, "system_id")

    case SystemInhabitant
         |> Ash.Query.filter(
           chain_topology_id == ^chain_topology_id and character_id == ^character_id and
             system_id == ^system_id
         )
         |> Ash.read(domain: Api) do
      {:ok, [inhabitant]} ->
        # Update existing inhabitant
        Ash.update(
          inhabitant,
          %{
            present: true,
            last_seen_at: DateTime.utc_now(),
            ship_type_id: Map.get(inhabitant_data, "ship_type_id"),
            departure_time: nil
          },
          domain: Api
        )

      {:ok, []} ->
        # Create new inhabitant
        Ash.create(
          SystemInhabitant,
          %{
            chain_topology_id: chain_topology_id,
            character_id: character_id,
            character_name: Map.get(inhabitant_data, "character_name", "Unknown"),
            corporation_id: Map.get(inhabitant_data, "corporation_id", 1),
            corporation_name: Map.get(inhabitant_data, "corporation_name", "Unknown"),
            system_id: system_id,
            system_name: Map.get(inhabitant_data, "system_name", "Unknown"),
            ship_type_id: Map.get(inhabitant_data, "ship_type_id"),
            present: true
          },
          domain: Api
        )
    end
  end

  defp bulk_update_or_create_inhabitants(chain_topology_id, inhabitants_data) do
    # Get all existing inhabitants for this chain
    {:ok, existing} =
      SystemInhabitant
      |> Ash.Query.filter(chain_topology_id == ^chain_topology_id)
      |> Ash.read(domain: Api)

    existing_map =
      Map.new(existing, fn inhabitant ->
        {inhabitant.character_id, inhabitant}
      end)

    # Prepare bulk data
    {updates, creates} =
      inhabitants_data
      |> Enum.reduce({[], []}, fn inhabitant_data, {updates, creates} ->
        character_id = Map.get(inhabitant_data, "character_id")
        system_id = Map.get(inhabitant_data, "system_id")

        attrs = %{
          chain_topology_id: chain_topology_id,
          character_id: character_id,
          character_name: Map.get(inhabitant_data, "character_name", "Unknown"),
          corporation_id: Map.get(inhabitant_data, "corporation_id", 1),
          corporation_name: Map.get(inhabitant_data, "corporation_name", "Unknown"),
          system_id: system_id,
          system_name: Map.get(inhabitant_data, "system_name", "Unknown"),
          ship_type_id: Map.get(inhabitant_data, "ship_type_id"),
          present: true
        }

        case Map.get(existing_map, character_id) do
          nil ->
            # New inhabitant - add to creates
            {updates, [attrs | creates]}

          existing ->
            # Existing inhabitant - add to updates if changed
            if existing.system_id != system_id or not existing.present do
              update_attrs = Map.put(attrs, :id, existing.id)
              {[update_attrs | updates], creates}
            else
              {updates, creates}
            end
        end
      end)

    # Perform bulk operations
    if creates != [] do
      Ash.bulk_create(creates, SystemInhabitant, :create,
        domain: Api,
        return_records?: false,
        return_errors?: false,
        stop_on_error?: false,
        batch_size: 500
      )
    end

    if updates != [] do
      Enum.each(updates, fn update_attrs ->
        case Ash.get(SystemInhabitant, update_attrs.id, domain: Api) do
          {:ok, record} ->
            update_data = Map.delete(update_attrs, :id)
            Ash.update!(record, update_data, domain: Api)

          {:error, _} ->
            # Record not found, skip
            :ok
        end
      end)
    end

    :ok
  end

  defp update_chain_connections(map_id, connections_data) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Process connections in bulk
        bulk_update_or_create_connections(topology.id, connections_data)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_or_create_connection(chain_topology_id, connection_data) do
    source_system_id = Map.get(connection_data, "source_system_id")
    target_system_id = Map.get(connection_data, "target_system_id")

    case ChainConnection
         |> Ash.Query.filter(
           chain_topology_id == ^chain_topology_id and source_system_id == ^source_system_id and
             target_system_id == ^target_system_id
         )
         |> Ash.read(domain: Api) do
      {:ok, [connection]} ->
        # Update existing connection
        Ash.update(
          connection,
          %{
            mass_status: parse_mass_status(Map.get(connection_data, "mass_status")),
            time_status: parse_time_status(Map.get(connection_data, "time_status")),
            is_eol: Map.get(connection_data, "is_eol", false),
            signature_id: Map.get(connection_data, "signature_id"),
            wormhole_type: Map.get(connection_data, "wormhole_type")
          },
          domain: Api
        )

      {:ok, []} ->
        # Create new connection
        Ash.create(
          ChainConnection,
          %{
            chain_topology_id: chain_topology_id,
            source_system_id: source_system_id,
            source_system_name: Map.get(connection_data, "source_system_name", "Unknown"),
            target_system_id: target_system_id,
            target_system_name: Map.get(connection_data, "target_system_name", "Unknown"),
            signature_id: Map.get(connection_data, "signature_id"),
            wormhole_type: Map.get(connection_data, "wormhole_type"),
            mass_status: parse_mass_status(Map.get(connection_data, "mass_status")),
            time_status: parse_time_status(Map.get(connection_data, "time_status")),
            is_eol: Map.get(connection_data, "is_eol", false)
          },
          domain: Api
        )
    end
  end

  defp bulk_update_or_create_connections(chain_topology_id, connections_data) do
    # Get all existing connections for this chain
    {:ok, existing} =
      ChainConnection
      |> Ash.Query.filter(chain_topology_id == ^chain_topology_id)
      |> Ash.read(domain: Api)

    existing_map =
      Map.new(existing, fn conn ->
        {{conn.source_system_id, conn.target_system_id}, conn}
      end)

    # Prepare bulk data
    {updates, creates} =
      connections_data
      |> Enum.reduce({[], []}, fn connection_data, {updates, creates} ->
        source_system_id = Map.get(connection_data, "source_system_id")
        target_system_id = Map.get(connection_data, "target_system_id")

        attrs = %{
          chain_topology_id: chain_topology_id,
          source_system_id: source_system_id,
          source_system_name: Map.get(connection_data, "source_system_name", "Unknown"),
          target_system_id: target_system_id,
          target_system_name: Map.get(connection_data, "target_system_name", "Unknown"),
          signature_id: Map.get(connection_data, "signature_id"),
          wormhole_type: Map.get(connection_data, "wormhole_type"),
          mass_status: parse_mass_status(Map.get(connection_data, "mass_status")),
          time_status: parse_time_status(Map.get(connection_data, "time_status")),
          is_eol: Map.get(connection_data, "is_eol", false)
        }

        case Map.get(existing_map, {source_system_id, target_system_id}) do
          nil ->
            # New connection - add to creates
            {updates, [attrs | creates]}

          existing ->
            # Existing connection - add to updates
            update_attrs = Map.put(attrs, :id, existing.id)
            {[update_attrs | updates], creates}
        end
      end)

    # Perform bulk operations
    if creates != [] do
      Ash.bulk_create(creates, ChainConnection, :create,
        domain: Api,
        return_records?: false,
        return_errors?: false,
        stop_on_error?: false,
        batch_size: 500
      )
    end

    if updates != [] do
      Enum.each(updates, fn update_attrs ->
        case Ash.get(ChainConnection, update_attrs.id, domain: Api) do
          {:ok, record} ->
            update_data = Map.delete(update_attrs, :id)
            Ash.update!(record, update_data, domain: Api)

          {:error, _} ->
            # Record not found, skip
            :ok
        end
      end)
    end

    :ok
  end

  defp parse_mass_status("stable"), do: :stable
  defp parse_mass_status("destab"), do: :destab
  defp parse_mass_status("critical"), do: :critical
  defp parse_mass_status(_), do: :unknown

  defp parse_time_status("stable"), do: :stable
  defp parse_time_status("eol"), do: :eol
  defp parse_time_status(_), do: :unknown

  defp process_system_update(map_id, data) do
    Logger.debug("Processing system update for #{map_id}: #{inspect(data)}")

    # Extract system and inhabitant updates
    system_data = Map.get(data, "systems", [])

    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [_topology]} ->
        update_system_inhabitants(map_id, system_data)

        # Broadcast specific system update
        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "chain_intelligence:#{map_id}",
          {:system_updated, map_id, data}
        )

      {:error, reason} ->
        Logger.error("Failed to process system update for #{map_id}: #{inspect(reason)}")
    end
  end

  defp process_connection_update(map_id, data) do
    Logger.debug("Processing connection update for #{map_id}: #{inspect(data)}")

    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Update specific connection
        connection_data = Map.get(data, "connection", %{})
        update_or_create_connection(topology.id, connection_data)

        # Broadcast specific connection update
        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "chain_intelligence:#{map_id}",
          {:connection_updated, map_id, data}
        )

      {:error, reason} ->
        Logger.error("Failed to process connection update for #{map_id}: #{inspect(reason)}")
    end
  end

  defp process_wanderer_event(map_id, event_type, event_data) do
    Logger.debug(
      "Processing Wanderer event #{event_type} for map #{map_id}: #{inspect(event_data)}"
    )

    handle_event_by_type(map_id, event_type, event_data)
    broadcast_event_update(map_id, event_type, event_data)
  end

  defp handle_event_by_type(map_id, event_type, event_data) do
    cond do
      character_event?(event_type) ->
        handle_character_event(map_id, event_type, event_data)

      system_event?(event_type) ->
        handle_system_event(map_id, event_type, event_data)

      connection_event?(event_type) ->
        handle_connection_event(map_id, event_type, event_data)

      signature_event?(event_type) ->
        handle_signature_event(map_id, event_type, event_data)

      event_type == "map_kill" ->
        handle_map_kill(map_id, event_data)

      true ->
        Logger.debug("Unhandled Wanderer event type: #{event_type}")
    end
  end

  defp character_event?(event_type) do
    event_type in [
      "character_location_changed",
      "character_ship_changed",
      "character_online_status_changed",
      "character_ready_status_changed"
    ]
  end

  defp system_event?(event_type) do
    event_type in ["add_system", "deleted_system", "system_metadata_changed"]
  end

  defp connection_event?(event_type) do
    event_type in ["connection_added", "connection_removed", "connection_updated"]
  end

  defp signature_event?(event_type) do
    event_type in ["signature_added", "signature_removed", "signatures_updated"]
  end

  defp handle_character_event(map_id, event_type, event_data) do
    case event_type do
      "character_location_changed" ->
        handle_character_location_changed(map_id, event_data)

      "character_ship_changed" ->
        handle_character_ship_changed(map_id, event_data)

      "character_online_status_changed" ->
        handle_character_online_status_changed(map_id, event_data)

      "character_ready_status_changed" ->
        handle_character_ready_status_changed(map_id, event_data)
    end
  end

  defp handle_system_event(map_id, event_type, event_data) do
    case event_type do
      "add_system" -> handle_system_added(map_id, event_data)
      "deleted_system" -> handle_system_deleted(map_id, event_data)
      "system_metadata_changed" -> handle_system_changed(map_id, event_data)
    end
  end

  defp handle_connection_event(map_id, event_type, event_data) do
    case event_type do
      "connection_added" -> handle_connection_added(map_id, event_data)
      "connection_removed" -> handle_connection_removed(map_id, event_data)
      "connection_updated" -> handle_connection_updated(map_id, event_data)
    end
  end

  defp handle_signature_event(map_id, event_type, event_data) do
    case event_type do
      "signature_added" -> handle_signature_added(map_id, event_data)
      "signature_removed" -> handle_signature_removed(map_id, event_data)
      "signatures_updated" -> handle_signatures_updated(map_id, event_data)
    end
  end

  defp broadcast_event_update(map_id, event_type, event_data) do
    Phoenix.PubSub.broadcast(
      EveDmv.PubSub,
      "chain_intelligence:#{map_id}",
      {:wanderer_event, event_type, event_data}
    )
  end

  # Wanderer Event Handlers based on documented payload formats

  defp handle_system_added(map_id, payload) do
    # Payload example: %{"solar_system_id" => 31000001, "name" => "J123456", "type" => "wormhole", "class" => "C3"}
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Update system count
        Ash.update(
          topology,
          %{
            system_count: topology.system_count + 1,
            last_activity_at: DateTime.utc_now()
          },
          domain: Api
        )

        Logger.info("System #{payload["name"]} added to map #{map_id}")

      {:error, reason} ->
        Logger.error("Failed to update topology for system add: #{inspect(reason)}")
    end
  end

  defp handle_system_deleted(map_id, payload) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Remove any inhabitants from this system
        system_id = payload["solar_system_id"]

        {:ok, inhabitants} =
          SystemInhabitant
          |> Ash.Query.filter(chain_topology_id == ^topology.id and system_id == ^system_id)
          |> Ash.read(domain: Api)

        # Bulk destroy inhabitants
        if inhabitants != [] do
          Enum.each(inhabitants, fn inhabitant ->
            Ash.destroy!(inhabitant, domain: Api)
          end)
        end

        # Update system count
        Ash.update(
          topology,
          %{
            system_count: max(0, topology.system_count - 1),
            last_activity_at: DateTime.utc_now()
          },
          domain: Api
        )

        Logger.info("System #{payload["name"]} deleted from map #{map_id}")

      {:error, reason} ->
        Logger.error("Failed to update topology for system delete: #{inspect(reason)}")
    end
  end

  defp handle_system_changed(map_id, _payload) do
    # System metadata changed - mark activity
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

      {:error, reason} ->
        Logger.error("Failed to update topology for system change: #{inspect(reason)}")
    end
  end

  defp handle_connection_added(map_id, payload) do
    # Payload should contain connection details
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Create or update the connection
        connection_data = %{
          chain_topology_id: topology.id,
          source_system_id: payload["source_system_id"],
          source_system_name: payload["from_name"] || "Unknown",
          target_system_id: payload["target_system_id"],
          target_system_name: payload["to_name"] || "Unknown",
          wormhole_type: payload["type"],
          mass_status: parse_mass_status(payload["mass_status"]),
          time_status: :stable,
          is_eol: false
        }

        Ash.create(ChainConnection, connection_data, domain: Api)

        # Update connection count
        Ash.update(
          topology,
          %{
            connection_count: topology.connection_count + 1,
            last_activity_at: DateTime.utc_now()
          },
          domain: Api
        )

        Logger.info(
          "Connection added to map #{map_id}: #{payload["from_name"]} -> #{payload["to_name"]}"
        )

      {:error, reason} ->
        Logger.error("Failed to add connection: #{inspect(reason)}")
    end
  end

  defp handle_connection_removed(map_id, payload) do
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        # Find and remove the connection
        source_id = payload["source_system_id"]
        target_id = payload["target_system_id"]

        case ChainConnection
             |> Ash.Query.filter(
               chain_topology_id == ^topology.id and source_system_id == ^source_id and
                 target_system_id == ^target_id
             )
             |> Ash.read(domain: Api) do
          {:ok, [connection]} ->
            Ash.destroy(connection, domain: Api)

            # Update connection count
            Ash.update(
              topology,
              %{
                connection_count: max(0, topology.connection_count - 1),
                last_activity_at: DateTime.utc_now()
              },
              domain: Api
            )

            Logger.info("Connection removed from map #{map_id}")

          {:ok, []} ->
            Logger.warning("Connection to remove not found in local data")
        end

      {:error, reason} ->
        Logger.error("Failed to remove connection: #{inspect(reason)}")
    end
  end

  defp handle_connection_updated(map_id, payload) do
    # Update connection status (mass, time, EOL)
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        source_id = payload["source_system_id"]
        target_id = payload["target_system_id"]

        case ChainConnection
             |> Ash.Query.filter(
               chain_topology_id == ^topology.id and source_system_id == ^source_id and
                 target_system_id == ^target_id
             )
             |> Ash.read(domain: Api) do
          {:ok, [connection]} ->
            Ash.update(
              connection,
              %{
                mass_status: parse_mass_status(payload["mass_status"]),
                time_status: parse_time_status(payload["time_status"]),
                is_eol: payload["is_eol"] || false
              },
              domain: Api
            )

            Logger.debug("Connection updated in map #{map_id}")

          {:ok, []} ->
            Logger.warning("Connection to update not found in local data")
        end

      {:error, reason} ->
        Logger.error("Failed to update connection: #{inspect(reason)}")
    end
  end

  defp handle_signature_added(map_id, _payload) do
    # Mark activity for signature events
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

      _ ->
        :ok
    end
  end

  defp handle_signature_removed(map_id, _payload) do
    # Mark activity for signature events
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

      _ ->
        :ok
    end
  end

  defp handle_signatures_updated(map_id, _payload) do
    # Mark activity for signature events
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

      _ ->
        :ok
    end
  end

  defp handle_map_kill(map_id, payload) do
    # Payload: %{"killmail_id" => 12345678, "system_name" => "J123456", "victim" => %{...}, "value" => 250_000_000}
    case ChainTopology |> Ash.Query.filter(map_id == ^map_id) |> Ash.read(domain: Api) do
      {:ok, [topology]} ->
        Ash.update(topology, %{last_activity_at: DateTime.utc_now()}, domain: Api)

        # Broadcast kill event for alerts
        Phoenix.PubSub.broadcast(
          EveDmv.PubSub,
          "chain_intelligence:#{map_id}",
          {:map_kill_detected, payload}
        )

        Logger.info(
          "Kill detected in map #{map_id}: #{payload["victim"]["name"]} in #{payload["system_name"]}"
        )

      {:error, reason} ->
        Logger.error("Failed to process map kill: #{inspect(reason)}")
    end
  end

  # Character Event Handlers for Wanderer SSE events

  defp handle_character_location_changed(map_id, payload) do
    character_name = payload["character_name"]
    location = payload["current_location"]
    system_name = location["solar_system_name"]
    system_id = location["solar_system_id"]

    update_or_create_inhabitant(map_id, %{
      character_name: character_name,
      solar_system_id: system_id,
      solar_system_name: system_name,
      present: true,
      arrival_time: DateTime.utc_now()
    })
  end

  defp handle_character_ship_changed(map_id, payload) do
    # Payload: %{"character_name" => "Pilot Name", "current_ship" => %{"ship" => "Astero", "ship_type_id" => 33468}}
    character_name = payload["character_name"]
    ship_info = payload["current_ship"]
    ship_name = ship_info["ship"]
    ship_type_id = ship_info["ship_type_id"]

    Logger.debug("Character #{character_name} switched to #{ship_name} in map #{map_id}")

    # Update inhabitant with new ship information
    case find_character_inhabitant(map_id, character_name) do
      {:ok, inhabitant} ->
        try do
          Ash.update!(
            inhabitant,
            %{
              ship_type_id: ship_type_id,
              ship_name: ship_name,
              last_activity_at: DateTime.utc_now()
            },
            domain: Api
          )
        rescue
          error ->
            Logger.error("Failed to update inhabitant ship: #{inspect(error)}")
        end

      _ ->
        Logger.warning(
          "Could not find inhabitant for character #{character_name} in map #{map_id}"
        )
    end
  end

  defp handle_character_online_status_changed(map_id, payload) do
    # Payload: %{"character_name" => "Pilot Name", "current_online" => true}
    character_name = payload["character_name"]
    online = payload["current_online"]

    Logger.debug(
      "Character #{character_name} went #{if online, do: "online", else: "offline"} in map #{map_id}"
    )

    # Update inhabitant online status
    case find_character_inhabitant(map_id, character_name) do
      {:ok, inhabitant} ->
        try do
          Ash.update!(
            inhabitant,
            %{
              online: online,
              last_activity_at: DateTime.utc_now()
            },
            domain: Api
          )
        rescue
          error ->
            Logger.error("Failed to update inhabitant online status: #{inspect(error)}")
        end

      _ ->
        Logger.warning(
          "Could not find inhabitant for character #{character_name} in map #{map_id}"
        )
    end
  end

  defp handle_character_ready_status_changed(map_id, payload) do
    # Payload: %{"character_name" => "Pilot Name", "ready" => true}
    character_name = payload["character_name"]
    ready = payload["ready"]

    Logger.debug(
      "Character #{character_name} is now #{if ready, do: "ready", else: "not ready"} in map #{map_id}"
    )

    # Update inhabitant ready status (could be used for fleet readiness)
    case find_character_inhabitant(map_id, character_name) do
      {:ok, inhabitant} ->
        try do
          # Add ready status to metadata if the field doesn't exist
          metadata = Map.get(inhabitant, :metadata, %{}) || %{}
          updated_metadata = Map.put(metadata, "ready", ready)

          Ash.update!(
            inhabitant,
            %{
              metadata: updated_metadata,
              last_activity_at: DateTime.utc_now()
            },
            domain: Api
          )
        rescue
          error ->
            Logger.error("Failed to update inhabitant ready status: #{inspect(error)}")
        end

      _ ->
        Logger.warning(
          "Could not find inhabitant for character #{character_name} in map #{map_id}"
        )
    end
  end

  defp find_character_inhabitant(_map_id, character_name) do
    case SystemInhabitant
         |> Ash.Query.filter(character_name == ^character_name and present == true)
         |> Ash.read!(domain: Api) do
      [inhabitant | _] -> {:ok, inhabitant}
      [] -> {:error, :not_found}
    end
  rescue
    error ->
      {:error, error}
  end

  defp spawn_task(fun) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fun)
  end
end
