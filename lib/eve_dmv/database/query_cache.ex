defmodule EveDmv.Database.QueryCache do
  @moduledoc """
  Caches expensive query results with TTL support.

  This cache is designed for expensive analytical queries that can benefit
  from temporary result caching, such as intelligence analysis and statistics.
  """

  use GenServer
  require Logger

  @cache_table :query_cache
  # 5 minutes
  @default_ttl 300_000
  # 1 minute
  @cleanup_interval 60_000
  # Maximum number of cached queries
  @max_cache_size 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Create ETS table for cache storage
    :ets.new(@cache_table, [:named_table, :public, :set, {:read_concurrency, true}])

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("Query cache started with TTL #{@default_ttl}ms")
    {:ok, %{}}
  end

  @doc """
  Get a cached result or compute and cache it if not found.

  ## Examples

      # Cache character intelligence for 10 minutes
      QueryCache.get_or_compute("character_intel_\#{character_id}", fn ->
        Intelligence.analyze_character(character_id)
      end, 600_000)
      
      # Use default TTL  
      QueryCache.get_or_compute("system_stats_\#{system_id}", fn ->
        Analytics.get_system_statistics(system_id)
      end)
  """
  def get_or_compute(cache_key, compute_fn, ttl \\ @default_ttl)
      when is_function(compute_fn, 0) do
    case get_from_cache(cache_key) do
      {:ok, value} ->
        Logger.debug("Cache hit for key: #{cache_key}")
        EveDmv.Telemetry.PerformanceMonitor.track_cache_access("query_cache", :hit)
        value

      :miss ->
        Logger.debug("Cache miss for key: #{cache_key}")
        EveDmv.Telemetry.PerformanceMonitor.track_cache_access("query_cache", :miss)

        # Compute value and cache it
        value = compute_fn.()
        put_in_cache(cache_key, value, ttl)
        value
    end
  end

  @doc """
  Manually put a value in the cache.
  """
  def put(cache_key, value, ttl \\ @default_ttl) do
    put_in_cache(cache_key, value, ttl)
  end

  @doc """
  Remove a specific key from the cache.
  """
  def delete(cache_key) do
    :ets.delete(@cache_table, cache_key)
    Logger.debug("Deleted cache key: #{cache_key}")
  end

  @doc """
  Clear all cached entries.
  """
  def clear_all do
    :ets.delete_all_objects(@cache_table)
    Logger.info("Cleared all query cache entries")
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    info = :ets.info(@cache_table)

    %{
      size: Keyword.get(info, :size, 0),
      memory_bytes: Keyword.get(info, :memory, 0) * :erlang.system_info(:wordsize)
    }
  end

  @doc """
  Invalidate cache entries matching a pattern.
  Useful for clearing related cache entries when data changes.

  ## Examples

      # Clear all character-related cache entries
      QueryCache.invalidate_pattern("character_*")
      
      # Clear all system-related cache entries
      QueryCache.invalidate_pattern("system_*")
  """
  def invalidate_pattern(pattern) do
    # Convert glob pattern to regex
    regex_pattern =
      pattern
      |> String.replace("*", ".*")
      |> Regex.compile!()

    # Find matching keys
    matching_keys =
      :ets.foldl(
        fn {key, _value, _expires_at}, acc ->
          if Regex.match?(regex_pattern, to_string(key)) do
            [key | acc]
          else
            acc
          end
        end,
        [],
        @cache_table
      )

    # Delete matching entries
    Enum.each(matching_keys, fn key ->
      :ets.delete(@cache_table, key)
    end)

    Logger.info("Invalidated #{length(matching_keys)} cache entries matching pattern: #{pattern}")
    length(matching_keys)
  end

  # Private functions

  defp get_from_cache(cache_key) do
    current_time = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, value, expires_at}] when expires_at > current_time ->
        {:ok, value}

      [{^cache_key, _value, _expires_at}] ->
        # Entry expired, remove it
        :ets.delete(@cache_table, cache_key)
        :miss

      [] ->
        :miss
    end
  end

  defp put_in_cache(cache_key, value, ttl) do
    expires_at = System.monotonic_time(:millisecond) + ttl

    # Check cache size and evict if necessary
    ensure_cache_size()

    :ets.insert(@cache_table, {cache_key, value, expires_at})
    Logger.debug("Cached value for key: #{cache_key} (TTL: #{ttl}ms)")
  end

  defp ensure_cache_size do
    current_size = :ets.info(@cache_table, :size)

    if current_size >= @max_cache_size do
      # Evict oldest entries (simple FIFO eviction)
      all_entries = :ets.tab2list(@cache_table)

      # Sort by expiration time and remove oldest 10%
      entries_to_remove =
        all_entries
        |> Enum.sort_by(fn {_key, _value, expires_at} -> expires_at end)
        |> Enum.take(div(@max_cache_size, 10))

      Enum.each(entries_to_remove, fn {key, _value, _expires_at} ->
        :ets.delete(@cache_table, key)
      end)

      Logger.debug("Evicted #{length(entries_to_remove)} cache entries due to size limit")
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval)
  end

  # GenServer callbacks

  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp cleanup_expired_entries do
    current_time = System.monotonic_time(:millisecond)

    expired_keys =
      :ets.foldl(
        fn {key, _value, expires_at}, acc ->
          if expires_at <= current_time do
            [key | acc]
          else
            acc
          end
        end,
        [],
        @cache_table
      )

    Enum.each(expired_keys, fn key ->
      :ets.delete(@cache_table, key)
    end)

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end
end
