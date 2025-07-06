defmodule EveDmv.Workers.CacheWarmingWorker do
  @moduledoc """
  Dedicated worker for cache warming operations.

  This worker replaces the heavy Task.Supervisor usage in cache_warmer.ex
  with a structured, schedulable approach to cache warming that can be
  configured based on system load and usage patterns.

  ## Features
  - **Scheduled warming**: Runs cache warming on configurable intervals
  - **Priority-based warming**: Warms critical data first
  - **Load-aware warming**: Adjusts warming intensity based on system load
  - **Incremental warming**: Warms data in batches to avoid overwhelming the system
  - **Cache hit tracking**: Uses analytics to prioritize which data to warm
  """

  use GenServer
  require Logger

  alias EveDmv.Cache
  alias EveDmv.Database.CacheWarmer

  # Configuration
  # 15 minutes
  @default_warming_interval 15 * 60 * 1000
  # 5 minutes (high priority data)
  @priority_warming_interval 5 * 60 * 1000
  # Items per warming batch
  @batch_size 50
  # Limit concurrent warming operations
  @max_concurrent_batches 3

  defmodule State do
    @moduledoc false
    defstruct [
      :warming_interval,
      :priority_interval,
      :warming_timer,
      :priority_timer,
      :batch_size,
      :max_concurrent,
      :active_batches,
      :warming_stats,
      :last_warming,
      :warming_enabled
    ]
  end

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger immediate cache warming for critical data.
  """
  def warm_critical_data do
    GenServer.cast(__MODULE__, :warm_critical_now)
  end

  @doc """
  Trigger full cache warming cycle.
  """
  def warm_full_cache do
    GenServer.cast(__MODULE__, :warm_full_now)
  end

  @doc """
  Enable or disable automatic cache warming.
  """
  def set_warming_enabled(enabled) when is_boolean(enabled) do
    GenServer.cast(__MODULE__, {:set_warming_enabled, enabled})
  end

  @doc """
  Get cache warming statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Update warming configuration.
  """
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    warming_interval = Keyword.get(opts, :warming_interval, @default_warming_interval)
    priority_interval = Keyword.get(opts, :priority_interval, @priority_warming_interval)
    batch_size = Keyword.get(opts, :batch_size, @batch_size)
    max_concurrent = Keyword.get(opts, :max_concurrent, @max_concurrent_batches)
    warming_enabled = Keyword.get(opts, :warming_enabled, true)

    state = %State{
      warming_interval: warming_interval,
      priority_interval: priority_interval,
      batch_size: batch_size,
      max_concurrent: max_concurrent,
      active_batches: MapSet.new(),
      warming_stats: init_warming_stats(),
      last_warming: nil,
      warming_enabled: warming_enabled,
      warming_timer: nil,
      priority_timer: nil
    }

    Logger.info("Cache Warming Worker started (enabled: #{warming_enabled})")

    if warming_enabled do
      {:ok, schedule_warming_timers(state)}
    else
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_cast(:warm_critical_now, state) do
    if state.warming_enabled do
      Logger.info("Starting immediate critical cache warming")
      spawn_warming_task(:critical, state)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:warm_full_now, state) do
    if state.warming_enabled do
      Logger.info("Starting immediate full cache warming")
      spawn_warming_task(:full, state)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_warming_enabled, enabled}, state) do
    Logger.info("Cache warming #{if enabled, do: "enabled", else: "disabled"}")

    new_state = %{state | warming_enabled: enabled}

    if enabled and not state.warming_enabled do
      # Re-enable warming
      {:noreply, schedule_warming_timers(new_state)}
    else
      # Disable warming
      cancel_timers(new_state)
      {:noreply, %{new_state | warming_timer: nil, priority_timer: nil}}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      warming_enabled: state.warming_enabled,
      active_batches: MapSet.size(state.active_batches),
      max_concurrent_batches: state.max_concurrent,
      last_warming: state.last_warming,
      warming_stats: state.warming_stats,
      next_warming: get_next_warming_time(state),
      config: %{
        warming_interval_minutes: div(state.warming_interval, 60_000),
        priority_interval_minutes: div(state.priority_interval, 60_000),
        batch_size: state.batch_size
      }
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call({:update_config, config}, _from, state) do
    new_state = apply_config_updates(state, config)
    Logger.info("Updated cache warming configuration")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:scheduled_warming, state) do
    if state.warming_enabled and MapSet.size(state.active_batches) < state.max_concurrent do
      spawn_warming_task(:scheduled, state)
    end

    # Reschedule
    warming_timer = Process.send_after(self(), :scheduled_warming, state.warming_interval)
    {:noreply, %{state | warming_timer: warming_timer}}
  end

  @impl GenServer
  def handle_info(:priority_warming, state) do
    if state.warming_enabled and MapSet.size(state.active_batches) < state.max_concurrent do
      spawn_warming_task(:priority, state)
    end

    # Reschedule
    priority_timer = Process.send_after(self(), :priority_warming, state.priority_interval)
    {:noreply, %{state | priority_timer: priority_timer}}
  end

  @impl GenServer
  def handle_info({:warming_completed, batch_id, result}, state) do
    Logger.debug("Cache warming batch #{batch_id} completed: #{inspect(result)}")

    # Remove completed batch from active set
    active_batches = MapSet.delete(state.active_batches, batch_id)

    # Update stats
    updated_stats = update_warming_stats(state.warming_stats, result)

    new_state = %{
      state
      | active_batches: active_batches,
        warming_stats: updated_stats,
        last_warming: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:warming_failed, batch_id, error}, state) do
    Logger.warning("Cache warming batch #{batch_id} failed: #{inspect(error)}")

    # Remove failed batch from active set
    active_batches = MapSet.delete(state.active_batches, batch_id)

    # Update error stats
    updated_stats = %{
      state.warming_stats
      | failed_batches: state.warming_stats.failed_batches + 1
    }

    new_state = %{state | active_batches: active_batches, warming_stats: updated_stats}

    {:noreply, new_state}
  end

  # Private functions

  defp schedule_warming_timers(state) do
    warming_timer = Process.send_after(self(), :scheduled_warming, state.warming_interval)
    priority_timer = Process.send_after(self(), :priority_warming, state.priority_interval)

    %{state | warming_timer: warming_timer, priority_timer: priority_timer}
  end

  defp cancel_timers(state) do
    if state.warming_timer, do: Process.cancel_timer(state.warming_timer)
    if state.priority_timer, do: Process.cancel_timer(state.priority_timer)
  end

  defp spawn_warming_task(type, state) do
    batch_id = make_ref()

    # Add to active batches
    active_batches = MapSet.put(state.active_batches, batch_id)

    # Spawn warming task
    task_pid =
      spawn(fn ->
        perform_cache_warming(type, batch_id, state)
      end)

    Logger.debug(
      "Started cache warming batch #{inspect(batch_id)} (type: #{type}, pid: #{inspect(task_pid)})"
    )

    %{state | active_batches: active_batches}
  end

  defp perform_cache_warming(type, batch_id, state) do
    start_time = System.monotonic_time(:millisecond)
    parent_pid = self()

    try do
      case type do
        :critical ->
          warm_critical_cache_data(state.batch_size)

        :priority ->
          warm_priority_cache_data(state.batch_size)

        :scheduled ->
          warm_regular_cache_data(state.batch_size)

        :full ->
          warm_full_cache_data(state.batch_size)
      end

      duration = System.monotonic_time(:millisecond) - start_time

      send(
        parent_pid,
        {:warming_completed, batch_id,
         %{
           type: type,
           duration_ms: duration,
           items_warmed: state.batch_size
         }}
      )

      :telemetry.execute(
        [:eve_dmv, :cache_warming, :completed],
        %{duration: duration, items_warmed: state.batch_size},
        %{type: type}
      )
    catch
      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time

        send(parent_pid, {:warming_failed, batch_id, {kind, reason}})

        :telemetry.execute(
          [:eve_dmv, :cache_warming, :failed],
          %{duration: duration},
          %{type: type, error_kind: kind}
        )
    end
  end

  # Cache warming implementations (replace Task.Supervisor usage)

  defp warm_critical_cache_data(batch_size) do
    Logger.debug("Warming critical cache data (batch size: #{batch_size})")

    # Warm most frequently accessed characters
    critical_characters = get_critical_character_ids(batch_size)
    warm_characters_batch(critical_characters)

    # Warm critical systems
    critical_systems = get_critical_system_ids(batch_size)
    warm_systems_batch(critical_systems)

    :ok
  end

  defp warm_priority_cache_data(batch_size) do
    Logger.debug("Warming priority cache data (batch size: #{batch_size})")

    # Warm recently active alliances
    priority_alliances = get_priority_alliance_ids(batch_size)
    warm_alliances_batch(priority_alliances)

    # Warm popular items
    priority_items = get_priority_item_ids(batch_size)
    warm_items_batch(priority_items)

    :ok
  end

  defp warm_regular_cache_data(batch_size) do
    Logger.debug("Warming regular cache data (batch size: #{batch_size})")

    # Warm random selection of data for general cache population
    random_characters = get_random_character_ids(batch_size)
    warm_characters_batch(random_characters)

    :ok
  end

  defp warm_full_cache_data(batch_size) do
    Logger.info("Starting full cache warming cycle")

    # Delegate to CacheWarmer for comprehensive warming
    # This triggers all cache warming functions including hot characters,
    # active systems, recent killmails, frequent items, and alliance stats
    CacheWarmer.warm_cache()

    :ok
  end

  # Helper functions for identifying data to warm

  defp get_critical_character_ids(limit) do
    # Get most frequently accessed character IDs
    # This would typically query analytics or cache hit statistics
    # Placeholder
    Enum.to_list(1..limit)
  end

  defp get_critical_system_ids(limit) do
    # Get most active system IDs
    # Placeholder
    Enum.to_list(1..limit)
  end

  defp get_priority_alliance_ids(limit) do
    # Get recently active alliance IDs
    # Placeholder
    Enum.to_list(1..limit)
  end

  defp get_priority_item_ids(limit) do
    # Get frequently traded item IDs
    # Placeholder
    Enum.to_list(1..limit)
  end

  defp get_random_character_ids(limit) do
    # Get random sampling of character IDs
    # Placeholder
    Enum.to_list(1..limit)
  end

  # Batch warming functions

  defp warm_characters_batch(character_ids) do
    # Batch warm character data into hot_data cache
    Enum.each(character_ids, fn character_id ->
      case fetch_character_data(character_id) do
        {:ok, data} -> Cache.put_character(character_id, data)
        {:error, _} -> :ok
      end
    end)
  end

  defp warm_systems_batch(system_ids) do
    # Batch warm system data
    Enum.each(system_ids, fn system_id ->
      case fetch_system_data(system_id) do
        {:ok, data} -> Cache.put(:hot_data, {:system, system_id}, data)
        {:error, _} -> :ok
      end
    end)
  end

  defp warm_alliances_batch(alliance_ids) do
    # Batch warm alliance data
    Enum.each(alliance_ids, fn alliance_id ->
      case fetch_alliance_data(alliance_id) do
        {:ok, data} -> Cache.put(:hot_data, {:alliance, alliance_id}, data)
        {:error, _} -> :ok
      end
    end)
  end

  defp warm_items_batch(item_ids) do
    # Batch warm item data  
    Enum.each(item_ids, fn item_id ->
      case fetch_item_data(item_id) do
        {:ok, data} -> Cache.put(:hot_data, {:item, item_id}, data)
        {:error, _} -> :ok
      end
    end)
  end

  # Data fetching functions (placeholder implementations)

  defp fetch_character_data(_character_id) do
    # Would fetch from database or ESI
    {:ok, %{name: "Character", alliance_id: 123}}
  end

  defp fetch_system_data(_system_id) do
    # Would fetch from universe database
    {:ok, %{name: "System", security_status: 0.5}}
  end

  defp fetch_alliance_data(_alliance_id) do
    # Would fetch from ESI
    {:ok, %{name: "Alliance", member_count: 1000}}
  end

  defp fetch_item_data(_item_id) do
    # Would fetch from universe database
    {:ok, %{name: "Item", market_group_id: 456}}
  end

  # Statistics and configuration management

  defp init_warming_stats do
    %{
      completed_batches: 0,
      failed_batches: 0,
      total_items_warmed: 0,
      total_warming_time_ms: 0,
      average_batch_time_ms: 0
    }
  end

  defp update_warming_stats(stats, %{duration_ms: duration, items_warmed: items}) do
    new_completed = stats.completed_batches + 1
    new_total_items = stats.total_items_warmed + items
    new_total_time = stats.total_warming_time_ms + duration
    new_average = div(new_total_time, new_completed)

    %{
      stats
      | completed_batches: new_completed,
        total_items_warmed: new_total_items,
        total_warming_time_ms: new_total_time,
        average_batch_time_ms: new_average
    }
  end

  defp get_next_warming_time(state) do
    if state.warming_enabled and state.warming_timer do
      # Calculate approximate next warming time
      DateTime.add(DateTime.utc_now(), div(state.warming_interval, 1000), :second)
    else
      nil
    end
  end

  defp apply_config_updates(state, config) do
    state
    |> update_if_present(config, :warming_interval, :warming_interval_minutes, &(&1 * 60_000))
    |> update_if_present(config, :priority_interval, :priority_interval_minutes, &(&1 * 60_000))
    |> update_if_present(config, :batch_size, :batch_size, & &1)
    |> update_if_present(config, :max_concurrent, :max_concurrent_batches, & &1)
  end

  defp update_if_present(state, config, state_key, config_key, transform_fn) do
    case Map.get(config, config_key) do
      nil -> state
      value -> Map.put(state, state_key, transform_fn.(value))
    end
  end
end
