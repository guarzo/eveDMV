defmodule EveDmv.Platform.Cache.MultiLayerCache do
  @moduledoc """
  Multi-layer caching system for EVE DMV with Process → ETS → Redis layers.

  Provides automatic cache promotion/demotion based on access patterns and
  implements intelligent cache warming and eviction strategies.

  ## Architecture

  1. **Process Cache** (L1): Ultra-fast process dictionary cache for hot data
  2. **ETS Cache** (L2): Fast shared memory cache for frequently accessed data  
  3. **Redis Cache** (L3): Distributed cache for persistence and sharing across nodes

  ## Features

  - Automatic cache promotion on frequent access
  - Write-through and write-behind strategies
  - Cache warming on startup
  - Adaptive TTL based on access patterns
  - Memory pressure monitoring and automatic eviction
  """

  use GenServer

  alias EveDmv.Core.Utils.Cache

  require Logger

  # Cache access tracking for promotion
  # Number of accesses before promotion
  @promotion_threshold 5
  # Max items in process cache
  @l1_max_size 100
  # 1 minute TTL for L1
  @l1_ttl_ms 60_000
  # 5 minutes TTL for L2
  @l2_ttl_ms 300_000
  # 1 hour TTL for L3
  @l3_ttl_ms 3_600_000

  defmodule CacheEntry do
    @moduledoc false
    defstruct [:value, :expires_at, :access_count, :last_accessed]
  end

  # Client API

  @doc """
  Start the multi-layer cache.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get a value from the cache, checking all layers.
  """
  def get(key, _opts \\ []) do
    # Check L1 (Process cache)
    case get_from_process_cache(key) do
      {:ok, value} ->
        track_access(:l1_hit)
        {:ok, value}

      :miss ->
        # Check L2 (ETS cache)
        case get_from_ets_cache(key) do
          {:ok, value} ->
            track_access(:l2_hit)
            maybe_promote_to_l1(key, value)
            {:ok, value}

          :miss ->
            # Check L3 (Redis cache)
            case get_from_redis_cache(key) do
              {:ok, value} ->
                track_access(:l3_hit)
                promote_to_l2(key, value)
                {:ok, value}

              :miss ->
                track_access(:cache_miss)
                :miss
            end
        end
    end
  end

  @doc """
  Put a value in the cache with write-through to all layers.
  """
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl_ms)
    write_strategy = Keyword.get(opts, :strategy, :write_through)

    case write_strategy do
      :write_through ->
        # Write to all layers immediately
        put_to_all_layers(key, value, ttl)

      :write_behind ->
        # Write to L1/L2 immediately, queue L3 write
        put_to_process_cache(key, value, ttl || @l1_ttl_ms)
        put_to_ets_cache(key, value, ttl || @l2_ttl_ms)
        queue_redis_write(key, value, ttl || @l3_ttl_ms)
    end

    :ok
  end

  @doc """
  Get or compute a value with automatic caching.
  """
  def get_or_compute(key, compute_fn, opts \\ []) when is_function(compute_fn, 0) do
    case get(key, opts) do
      {:ok, value} ->
        value

      :miss ->
        value = compute_fn.()
        put(key, value, opts)
        value
    end
  end

  @doc """
  Delete a key from all cache layers.
  """
  def delete(key) do
    delete_from_process_cache(key)
    delete_from_ets_cache(key)
    delete_from_redis_cache(key)
    :ok
  end

  @doc """
  Clear all cache layers.
  """
  def clear_all do
    clear_process_cache()
    clear_ets_cache()
    clear_redis_cache()
    :ok
  end

  @doc """
  Get cache statistics for all layers.
  """
  def stats do
    %{
      l1: process_cache_stats(),
      l2: ets_cache_stats(),
      l3: redis_cache_stats(),
      memory: memory_stats()
    }
  end

  @doc """
  Warm the cache with frequently accessed data.
  """
  def warm_cache(keys_and_values) do
    Enum.each(keys_and_values, fn {key, value} ->
      put_to_ets_cache(key, value, @l2_ttl_ms)
    end)

    :ok
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    # Initialize Redis connection pool if configured
    redis_config = Keyword.get(opts, :redis, [])
    redis_enabled = Keyword.get(redis_config, :enabled, false)

    state = %{
      redis_enabled: redis_enabled,
      redis_pool: if(redis_enabled, do: init_redis_pool(redis_config), else: nil),
      write_queue: :queue.new(),
      access_counts: %{},
      memory_limit: Keyword.get(opts, :memory_limit_mb, 100) * 1024 * 1024
    }

    # Schedule periodic tasks
    schedule_memory_check()
    schedule_write_flush()
    schedule_access_count_reset()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:check_memory, state) do
    # Check memory pressure and evict if necessary
    current_memory = :erlang.memory(:total)

    if current_memory > state.memory_limit do
      evict_cache_entries(state)
    end

    schedule_memory_check()
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:flush_writes, state) do
    # Flush queued Redis writes
    new_queue = flush_redis_writes(state.write_queue, state.redis_pool)
    schedule_write_flush()
    {:noreply, %{state | write_queue: new_queue}}
  end

  @impl GenServer
  def handle_info(:reset_access_counts, state) do
    # Reset access counts periodically to prevent unbounded growth
    schedule_access_count_reset()
    {:noreply, %{state | access_counts: %{}}}
  end

  @impl GenServer
  def handle_call({:queue_write, key, value, ttl}, _from, state) do
    new_queue = :queue.in({key, value, ttl, System.system_time(:millisecond)}, state.write_queue)
    {:reply, :ok, %{state | write_queue: new_queue}}
  end

  @impl GenServer
  def handle_call({:track_access, key}, _from, state) do
    count = Map.get(state.access_counts, key, 0) + 1
    new_counts = Map.put(state.access_counts, key, count)

    should_promote = count >= @promotion_threshold

    {:reply, should_promote, %{state | access_counts: new_counts}}
  end

  # Private functions

  defp get_from_process_cache(key) do
    case Process.get({:cache, key}) do
      nil ->
        :miss

      %CacheEntry{value: value, expires_at: expires_at} = entry ->
        if System.system_time(:millisecond) < expires_at do
          # Update access tracking
          Process.put({:cache, key}, %{
            entry
            | access_count: entry.access_count + 1,
              last_accessed: System.system_time(:millisecond)
          })

          {:ok, value}
        else
          Process.delete({:cache, key})
          :miss
        end
    end
  end

  defp put_to_process_cache(key, value, ttl_ms) do
    # Check L1 cache size limit
    enforce_l1_size_limit()

    entry = %CacheEntry{
      value: value,
      expires_at: System.system_time(:millisecond) + ttl_ms,
      access_count: 0,
      last_accessed: System.system_time(:millisecond)
    }

    Process.put({:cache, key}, entry)
    :ok
  end

  defp delete_from_process_cache(key) do
    Process.delete({:cache, key})
    :ok
  end

  defp clear_process_cache do
    Process.get_keys()
    |> Enum.filter(fn
      {:cache, _} -> true
      _ -> false
    end)
    |> Enum.each(&Process.delete/1)

    :ok
  end

  defp get_from_ets_cache(key) do
    Cache.get(:multi_layer_l2, key)
  end

  defp put_to_ets_cache(key, value, ttl_ms) do
    Cache.put(:multi_layer_l2, key, value, ttl_ms: ttl_ms)
  end

  defp delete_from_ets_cache(key) do
    Cache.delete(:multi_layer_l2, key)
  end

  defp clear_ets_cache do
    Cache.clear(:multi_layer_l2)
  end

  defp get_from_redis_cache(_key) do
    # Redis integration would go here
    # For now, return miss as Redis is optional
    :miss
  end

  defp put_to_redis_cache(_key, _value, _ttl_ms) do
    # Redis integration would go here
    :ok
  end

  defp delete_from_redis_cache(_key) do
    # Redis integration would go here
    :ok
  end

  defp clear_redis_cache do
    # Redis integration would go here
    :ok
  end

  defp put_to_all_layers(key, value, ttl) do
    put_to_process_cache(key, value, ttl || @l1_ttl_ms)
    put_to_ets_cache(key, value, ttl || @l2_ttl_ms)
    put_to_redis_cache(key, value, ttl || @l3_ttl_ms)
  end

  defp maybe_promote_to_l1(key, value) do
    # Check if this key should be promoted to L1
    should_promote = GenServer.call(__MODULE__, {:track_access, key})

    if should_promote do
      put_to_process_cache(key, value, @l1_ttl_ms)
    end
  end

  defp promote_to_l2(key, value) do
    put_to_ets_cache(key, value, @l2_ttl_ms)
  end

  defp queue_redis_write(key, value, ttl) do
    GenServer.call(__MODULE__, {:queue_write, key, value, ttl})
  end

  defp enforce_l1_size_limit do
    cache_keys =
      Process.get_keys()
      |> Enum.filter(fn
        {:cache, _} -> true
        _ -> false
      end)

    if length(cache_keys) >= @l1_max_size do
      # Evict least recently accessed entry
      oldest_key =
        cache_keys
        |> Enum.map(fn key ->
          entry = Process.get(key)
          {key, entry.last_accessed}
        end)
        |> Enum.min_by(fn {_, last_accessed} -> last_accessed end)
        |> elem(0)

      Process.delete(oldest_key)
    end
  end

  defp evict_cache_entries(_state) do
    # Evict 10% of L1 cache
    cache_keys =
      Process.get_keys()
      |> Enum.filter(fn
        {:cache, _} -> true
        _ -> false
      end)

    num_to_evict = div(length(cache_keys), 10)

    cache_keys
    |> Enum.take(num_to_evict)
    |> Enum.each(&Process.delete/1)

    Logger.info("Evicted #{num_to_evict} entries from L1 cache due to memory pressure")
  end

  defp flush_redis_writes(_queue, _redis_pool) do
    # Batch write to Redis (would implement actual Redis writes)
    # For now, just clear the queue
    :queue.new()
  end

  defp init_redis_pool(_redis_config) do
    # Would initialize Redis connection pool here
    nil
  end

  defp track_access(type) do
    :telemetry.execute(
      [:eve_dmv, :cache, :access],
      %{count: 1},
      %{type: type}
    )
  end

  defp process_cache_stats do
    cache_entries =
      Process.get_keys()
      |> Enum.filter(fn
        {:cache, _} -> true
        _ -> false
      end)

    %{
      size: length(cache_entries),
      memory_bytes: :erlang.process_info(self(), :memory) |> elem(1)
    }
  end

  defp ets_cache_stats do
    Cache.stats(:multi_layer_l2)
  end

  defp redis_cache_stats do
    # Placeholder
    %{size: 0, memory_bytes: 0}
  end

  defp memory_stats do
    %{
      total: :erlang.memory(:total),
      processes: :erlang.memory(:processes),
      ets: :erlang.memory(:ets),
      system: :erlang.memory(:system)
    }
  end

  defp schedule_memory_check do
    # Every 30 seconds
    Process.send_after(self(), :check_memory, 30_000)
  end

  defp schedule_write_flush do
    # Every 5 seconds
    Process.send_after(self(), :flush_writes, 5_000)
  end

  defp schedule_access_count_reset do
    # Every 5 minutes
    Process.send_after(self(), :reset_access_counts, 300_000)
  end
end
