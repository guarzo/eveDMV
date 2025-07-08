# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Intelligence.ChainAnalysis.ChainMonitor do
  use GenServer

    alias EveDmv.Intelligence.ChainAnalysis.ChainDataSync
  alias EveDmv.Intelligence.ChainAnalysis.ChainEventHandlers
  alias EveDmv.Intelligence.WandererClient
  alias EveDmv.Intelligence.WandererSSE

  require Ash.Query
  require Logger
  @moduledoc """
  Monitors and synchronizes chain topology data from Wanderer API.

  This GenServer manages the periodic synchronization of chain data,
  processes real-time updates, and maintains chain intelligence state.
  """



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

  @impl GenServer
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

  @impl GenServer
  def handle_call({:monitor_chain, map_id, corporation_id}, _from, state) do
    case ChainDataSync.create_or_update_chain_topology(map_id, corporation_id) do
      {:ok, _topology} ->
        # Add to Wanderer client monitoring (legacy REST API)
        WandererClient.monitor_map(map_id)

        # Subscribe to real-time SSE events
        WandererSSE.monitor_map(map_id)

        new_monitored = MapSet.put(state.monitored_chains, map_id)
        {:reply, :ok, %{state | monitored_chains: new_monitored}}

      {:error, reason} ->
        Logger.error("Failed to start monitoring chain #{map_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:stop_monitoring, map_id}, _from, state) do
    WandererClient.unmonitor_map(map_id)
    WandererSSE.stop_monitoring(map_id)

    new_monitored = MapSet.delete(state.monitored_chains, map_id)
    {:reply, :ok, %{state | monitored_chains: new_monitored}}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      monitored_chains: MapSet.to_list(state.monitored_chains),
      last_sync: state.last_sync,
      sync_errors: state.sync_errors,
      wanderer_connection: WandererClient.connection_status()
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_cast(:force_sync, state) do
    send(self(), :sync_chains)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:wanderer_event, map_id, event_type, event_data}, state) do
    # Handle real-time events from Wanderer WebSocket
    if MapSet.member?(state.monitored_chains, map_id) do
      spawn_task(fn ->
        ChainEventHandlers.process_wanderer_event(map_id, event_type, event_data)
      end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:schedule_sync, state) do
    timer = Process.send_after(self(), :sync_chains, @sync_interval_ms)
    {:noreply, %{state | sync_timer: timer}}
  end

  @impl GenServer
  def handle_info(:sync_chains, state) do
    new_state = perform_chain_sync(state)

    # Schedule next sync
    timer = Process.send_after(self(), :sync_chains, @sync_interval_ms)

    {:noreply, %{new_state | sync_timer: timer, last_sync: DateTime.utc_now()}}
  end

  @impl GenServer
  def handle_info({:system_update, data}, state) do
    # Legacy handler - keeping for backward compatibility
    map_id = Map.get(data, "map_id")

    if MapSet.member?(state.monitored_chains, map_id) do
      spawn_task(fn -> ChainEventHandlers.process_system_update(map_id, data) end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:connection_update, data}, state) do
    # Legacy handler - keeping for backward compatibility
    map_id = Map.get(data, "map_id")

    if MapSet.member?(state.monitored_chains, map_id) do
      spawn_task(fn -> ChainEventHandlers.process_connection_update(map_id, data) end)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp perform_chain_sync(state) do
    errors = %{}

    new_errors =
      Enum.reduce(state.monitored_chains, errors, fn map_id, acc ->
        case ChainDataSync.sync_chain_data(map_id) do
          :ok ->
            Map.delete(acc, map_id)

          {:error, reason} ->
            Logger.warning("Failed to sync chain #{map_id}: #{inspect(reason)}")
            Map.put(acc, map_id, reason)
        end
      end)

    %{state | sync_errors: new_errors}
  end

  defp spawn_task(fun) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fun)
  end
end
