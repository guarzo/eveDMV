defmodule EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker do
  @moduledoc """
  Background worker that processes the historical fetch queue.

  Manages Phase 2 (2-year) fetches for entities. Runs as a GenServer
  that processes one entity at a time to respect zkillboard rate limits.

  ## Architecture

  The worker maintains a queue of pending fetches and processes them sequentially.
  It uses PubSub to broadcast progress updates to subscribed LiveViews.

  ## Configuration

  The following options can be set via environment variables:
  - `HISTORICAL_FETCH_CHECK_INTERVAL` - Queue check interval (ms, default: 30000)
  - `HISTORICAL_FETCH_ENABLED` - Enable/disable the worker (default: true)

  ## Usage

      # Queue a fetch (typically done through the API)
      HistoricalFetchWorker.queue_fetch(:character, 12345)

      # Get status
      {:ok, status} = HistoricalFetchWorker.get_status(:character, 12345)

      # Subscribe to updates
      HistoricalFetchWorker.subscribe(:character, 12345)
  """

  use GenServer

  alias EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher
  alias EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus
  alias Phoenix.PubSub

  require Logger

  # Default check interval: 30 seconds
  @default_check_interval 30_000

  # PubSub topic prefix
  @pubsub_topic_prefix "historical_fetch_updates"

  @type entity_type :: :character | :corporation | :system | :alliance
  @type state :: %{
          current_fetch: String.t() | nil,
          enabled: boolean(),
          test_mode: boolean()
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start the HistoricalFetchWorker.

  ## Options

  - `:test_mode` - When true, disables automatic queue checks and background processing.
    Use this in tests to prevent background tasks from outliving the test process.
    Default: false

  - `:name` - The registered name. Default: `__MODULE__`

  ## Examples

      # Normal startup
      {:ok, pid} = HistoricalFetchWorker.start_link()

      # Test mode - no automatic background processing
      {:ok, pid} = HistoricalFetchWorker.start_link(test_mode: true)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Queue an entity for Phase 2 historical fetch.

  Creates or updates the fetch status record and notifies the worker.

  ## Examples

      iex> queue_fetch(:character, 12345)
      {:ok, %HistoricalFetchStatus{}}
  """
  @spec queue_fetch(entity_type(), integer()) :: {:ok, term()} | {:error, term()}
  def queue_fetch(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    GenServer.call(__MODULE__, {:queue_fetch, entity_type, entity_id})
  end

  @doc """
  Get the current status of a fetch.

  ## Examples

      iex> get_status(:character, 12345)
      {:ok, %{status: :in_progress, killmails_fetched: 50}}

      iex> get_status(:character, 99999)
      {:error, :not_found}
  """
  @spec get_status(entity_type(), integer()) :: {:ok, map()} | {:error, :not_found}
  def get_status(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    case HistoricalFetchStatus.get_by_entity(entity_type, entity_id) do
      {:ok, [status]} -> {:ok, status_to_map(status)}
      {:ok, []} -> {:error, :not_found}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  Subscribe to status updates for an entity.

  Updates are broadcast as `{:historical_fetch_update, entity_type, entity_id, update}`.

  ## Examples

      iex> subscribe(:character, 12345)
      :ok
  """
  @spec subscribe(entity_type(), integer()) :: :ok
  def subscribe(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    PubSub.subscribe(EveDmv.PubSub, topic(entity_type, entity_id))
  end

  @doc """
  Unsubscribe from status updates.
  """
  @spec unsubscribe(entity_type(), integer()) :: :ok
  def unsubscribe(entity_type, entity_id)
      when entity_type in [:character, :corporation, :system, :alliance] and is_integer(entity_id) do
    PubSub.unsubscribe(EveDmv.PubSub, topic(entity_type, entity_id))
  end

  @doc """
  Check if the worker is currently processing a fetch.
  """
  @spec busy?() :: boolean()
  def busy? do
    GenServer.call(__MODULE__, :busy?)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    enabled = get_config(:enabled, true)
    test_mode = Keyword.get(opts, :test_mode, false)

    Logger.info("HistoricalFetchWorker starting (enabled: #{enabled}, test_mode: #{test_mode})")

    state = %{
      current_fetch: nil,
      enabled: enabled,
      test_mode: test_mode
    }

    # Schedule initial work check after startup delay (disabled in test mode)
    if enabled and not test_mode do
      Process.send_after(self(), :check_queue, 5_000)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:queue_fetch, entity_type, entity_id}, _from, state) do
    result = ensure_fetch_record(entity_type, entity_id)

    # Trigger queue check if enabled (but not in test mode to prevent background tasks)
    if state.enabled and not state.test_mode do
      send(self(), :check_queue)
    end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:busy?, _from, state) do
    {:reply, state.current_fetch != nil, state}
  end

  @impl GenServer
  def handle_info(:check_queue, %{current_fetch: nil, enabled: true} = state) do
    # No current fetch, look for work
    case get_next_pending() do
      {:ok, nil} ->
        # No pending work, schedule next check
        schedule_check()
        {:noreply, state}

      {:ok, fetch_record} when is_struct(fetch_record) ->
        Logger.info(
          "Starting Phase 2 fetch for #{fetch_record.entity_type} #{fetch_record.entity_id}"
        )

        # Start async fetch
        parent = self()

        Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
          result = process_fetch(fetch_record, parent)
          send(parent, {:fetch_complete, fetch_record.id, result})
        end)

        {:noreply, %{state | current_fetch: fetch_record.id}}

      {:error, reason} ->
        Logger.error("Error checking fetch queue: #{inspect(reason)}")
        schedule_check()
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:check_queue, %{enabled: false} = state) do
    # Worker disabled, do nothing
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:check_queue, %{test_mode: true} = state) do
    # Test mode, do not process queue automatically
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:check_queue, state) do
    # Already processing, ignore
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:fetch_complete, fetch_id, result}, state) do
    Logger.info("Fetch #{fetch_id} complete: #{inspect(result)}")

    # Schedule next queue check immediately
    send(self(), :check_queue)

    {:noreply, %{state | current_fetch: nil}}
  end

  @impl GenServer
  def handle_info({:fetch_progress, entity_type, entity_id, progress}, state) do
    # Broadcast progress update
    broadcast_update(entity_type, entity_id, {:progress, progress})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("HistoricalFetchWorker received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  @spec ensure_fetch_record(entity_type(), integer()) :: {:ok, term()} | {:error, term()}
  defp ensure_fetch_record(entity_type, entity_id) do
    case get_status(entity_type, entity_id) do
      {:ok, status} ->
        # Already exists
        {:ok, status}

      {:error, :not_found} ->
        # Create new record
        case Ash.create(
               HistoricalFetchStatus,
               %{entity_type: entity_type, entity_id: entity_id, status: :pending},
               domain: EveDmv.Api
             ) do
          {:ok, status} -> {:ok, status_to_map(status)}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec get_next_pending() :: {:ok, term() | nil} | {:error, term()}
  defp get_next_pending do
    case HistoricalFetchStatus.get_pending_fetches() do
      {:ok, []} -> {:ok, nil}
      {:ok, [first | _]} -> {:ok, first}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec process_fetch(term(), pid()) :: {:ok, map()} | {:error, term()}
  defp process_fetch(fetch_record, worker_pid) do
    entity_type = fetch_record.entity_type
    entity_id = fetch_record.entity_id

    # Mark as in progress
    case Ash.update(fetch_record, %{}, action: :start_phase2, domain: EveDmv.Api) do
      {:ok, _} ->
        broadcast_update(entity_type, entity_id, :started)

      {:error, reason} ->
        Logger.warning("Failed to mark fetch as in_progress: #{inspect(reason)}")
    end

    # Create progress callback
    callback = fn {:progress, progress} ->
      # Update record with progress
      update_progress(fetch_record, progress)

      # Notify worker to broadcast
      send(worker_pid, {:fetch_progress, entity_type, entity_id, progress})
    end

    # Perform the extended historical fetch
    case ExtendedHistoricalFetcher.fetch_extended_history(
           entity_type,
           entity_id,
           callback: callback
         ) do
      {:ok, result} ->
        # Mark as complete
        case Ash.update(fetch_record, %{}, action: :mark_completed, domain: EveDmv.Api) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to mark fetch as completed: #{inspect(reason)}")
        end

        broadcast_update(entity_type, entity_id, {:completed, result})
        {:ok, result}

      {:error, reason} ->
        # Mark as failed
        case Ash.update(
               fetch_record,
               %{last_error: inspect(reason)},
               action: :mark_failed,
               domain: EveDmv.Api
             ) do
          {:ok, _} ->
            :ok

          {:error, update_reason} ->
            Logger.warning("Failed to mark fetch as failed: #{inspect(update_reason)}")
        end

        broadcast_update(entity_type, entity_id, {:failed, reason})
        {:error, reason}
    end
  end

  @spec update_progress(term(), map()) :: :ok
  defp update_progress(fetch_record, progress) do
    base_attrs = %{
      killmails_fetched: progress.killmails_fetched,
      current_page: progress.pages_processed
    }

    attrs =
      if progress.oldest_date do
        Map.put(base_attrs, :oldest_killmail_date, progress.oldest_date)
      else
        base_attrs
      end

    case Ash.update(fetch_record, attrs, action: :update_progress, domain: EveDmv.Api) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.debug("Failed to update progress: #{inspect(reason)}")
    end

    :ok
  end

  @spec topic(entity_type(), integer()) :: String.t()
  defp topic(entity_type, entity_id) do
    "#{@pubsub_topic_prefix}:#{entity_type}:#{entity_id}"
  end

  @spec broadcast_update(entity_type(), integer(), term()) :: :ok
  defp broadcast_update(entity_type, entity_id, message) do
    PubSub.broadcast(
      EveDmv.PubSub,
      topic(entity_type, entity_id),
      {:historical_fetch_update, entity_type, entity_id, message}
    )
  end

  @spec schedule_check() :: reference()
  defp schedule_check do
    check_interval = get_config(:check_interval, @default_check_interval)
    Process.send_after(self(), :check_queue, check_interval)
  end

  @spec get_config(atom(), term()) :: term()
  defp get_config(key, default) do
    config = Application.get_env(:eve_dmv, __MODULE__, [])
    Keyword.get(config, key, default)
  end

  @spec status_to_map(term()) :: map()
  defp status_to_map(status) do
    %{
      id: status.id,
      entity_type: status.entity_type,
      entity_id: status.entity_id,
      status: status.status,
      phase1_completed_at: status.phase1_completed_at,
      phase2_started_at: status.phase2_started_at,
      phase2_completed_at: status.phase2_completed_at,
      oldest_killmail_date: status.oldest_killmail_date,
      target_date: status.target_date,
      killmails_fetched: status.killmails_fetched,
      current_page: status.current_page,
      last_error: status.last_error,
      retry_count: status.retry_count
    }
  end
end
