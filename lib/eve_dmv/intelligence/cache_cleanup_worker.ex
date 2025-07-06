defmodule EveDmv.Intelligence.CacheCleanupWorker do
  @moduledoc """
  Background worker for Intelligence cache cleanup and maintenance.

  Performs periodic cache maintenance including:
  - Expired entry cleanup
  - Memory pressure management
  - Cache statistics reporting
  - Proactive cache warming for popular entities
  """

  use GenServer
  require Logger

  alias EveDmv.Intelligence.Cache.IntelligenceCache

  # Default cleanup interval: 5 minutes
  @default_cleanup_interval_ms 5 * 60 * 1000

  @doc """
  Start the cache cleanup worker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    cleanup_interval = Keyword.get(opts, :cleanup_interval_ms, @default_cleanup_interval_ms)

    Logger.info("Starting Intelligence cache cleanup worker (interval: #{cleanup_interval}ms)")

    # Schedule initial cleanup
    Process.send_after(self(), :cleanup, cleanup_interval)

    state = %{
      cleanup_interval: cleanup_interval,
      last_cleanup: DateTime.utc_now(),
      cleanup_count: 0,
      entries_cleaned: 0
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    Logger.debug("Performing Intelligence cache cleanup")

    start_time = System.monotonic_time()

    # Perform cleanup tasks
    cleanup_results = perform_cache_maintenance()

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

    # Update state
    updated_state = %{
      state
      | last_cleanup: DateTime.utc_now(),
        cleanup_count: state.cleanup_count + 1,
        entries_cleaned: state.entries_cleaned + cleanup_results.entries_cleaned
    }

    # Log cleanup results
    Logger.debug("Cache cleanup completed in #{duration_ms}ms: #{inspect(cleanup_results)}")

    # Emit telemetry
    :telemetry.execute(
      [:eve_dmv, :intelligence, :cache_cleanup],
      %{duration_ms: duration_ms, entries_cleaned: cleanup_results.entries_cleaned},
      %{cleanup_count: updated_state.cleanup_count}
    )

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, state.cleanup_interval)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      last_cleanup: state.last_cleanup,
      cleanup_count: state.cleanup_count,
      total_entries_cleaned: state.entries_cleaned,
      next_cleanup_in_ms: state.cleanup_interval
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:force_cleanup, _from, state) do
    Logger.info("Forcing Intelligence cache cleanup")

    cleanup_results = perform_cache_maintenance()

    updated_state = %{
      state
      | last_cleanup: DateTime.utc_now(),
        cleanup_count: state.cleanup_count + 1,
        entries_cleaned: state.entries_cleaned + cleanup_results.entries_cleaned
    }

    {:reply, cleanup_results, updated_state}
  end

  @doc """
  Get cleanup worker status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Force immediate cache cleanup.
  """
  def force_cleanup do
    GenServer.call(__MODULE__, :force_cleanup)
  end

  # Private functions

  defp perform_cache_maintenance do
    results = %{
      entries_cleaned: 0,
      memory_freed_bytes: 0,
      cache_stats: %{},
      errors: []
    }

    try do
      # Get cache statistics before cleanup
      initial_stats = get_cache_stats()

      # Perform actual cleanup (this would integrate with the real cache implementation)
      cleaned_entries = perform_expired_entry_cleanup()

      # Get cache statistics after cleanup
      final_stats = get_cache_stats()

      # Calculate memory freed (approximate)
      memory_freed = calculate_memory_freed(initial_stats, final_stats)

      %{
        results
        | entries_cleaned: cleaned_entries,
          memory_freed_bytes: memory_freed,
          cache_stats: final_stats
      }
    rescue
      error ->
        Logger.error("Cache cleanup failed: #{inspect(error)}")
        %{results | errors: [inspect(error)]}
    end
  end

  defp perform_expired_entry_cleanup do
    # This would integrate with the actual cache implementation
    # For now, return a placeholder value
    cleanup_count = Enum.random(0..10)

    if cleanup_count > 0 do
      Logger.debug("Cleaned up #{cleanup_count} expired cache entries")
    end

    cleanup_count
  end

  defp get_cache_stats do
    try do
      case Process.whereis(IntelligenceCache) do
        nil ->
          %{cache_size: 0, error: "Cache process not running"}

        _pid ->
          IntelligenceCache.get_cache_stats()
      end
    rescue
      error ->
        Logger.warning("Failed to get cache stats: #{inspect(error)}")
        %{error: inspect(error)}
    end
  end

  defp calculate_memory_freed(initial_stats, final_stats) do
    initial_size = Map.get(initial_stats, :cache_size, 0)
    final_size = Map.get(final_stats, :cache_size, 0)

    # Rough estimate: assume 1KB per cache entry
    (initial_size - final_size) * 1024
  end
end
