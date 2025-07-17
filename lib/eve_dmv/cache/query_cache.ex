defmodule EveDmv.Cache.QueryCache do
  @moduledoc """
  Caching layer for expensive database queries.

  Provides automatic caching with TTL, invalidation, and performance tracking.
  """

  use GenServer
  require Logger

  alias EveDmv.Monitoring.PerformanceTracker

  @table_name :query_cache
  @default_ttl :timer.minutes(15)
  @max_cache_size 10_000
  @cleanup_interval :timer.minutes(5)

  defstruct [
    :cache_table,
    :stats_table,
    :start_time
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get or compute a cached query result.

  ## Examples

      QueryCache.get_or_compute(
        "character_stats:123",
        fn -> expensive_query() end,
        ttl: :timer.minutes(30)
      )
  """
  def get_or_compute(key, compute_fn, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    force_refresh = Keyword.get(opts, :force_refresh, false)

    start_time = System.monotonic_time(:millisecond)

    result =
      if force_refresh do
        compute_and_cache(key, compute_fn, ttl)
      else
        case get(key) do
          {:ok, value} ->
            record_hit(key, start_time)
            {:ok, value}

          {:error, :not_found} ->
            record_miss(key, start_time)
            compute_and_cache(key, compute_fn, ttl)

          {:error, :expired} ->
            record_miss(key, start_time)
            compute_and_cache(key, compute_fn, ttl)
        end
      end

    # Track performance
    duration = System.monotonic_time(:millisecond) - start_time

    PerformanceTracker.track_query("cache:#{key}", duration,
      metadata: %{cache_hit: result != :miss}
    )

    result
  end

  @doc """
  Get a cached value directly.
  """
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if DateTime.compare(DateTime.utc_now(), expiry) == :lt do
          {:ok, value}
        else
          {:error, :expired}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Put a value in the cache with TTL.
  """
  def put(key, value, ttl \\ @default_ttl) do
    expiry = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(@table_name, {key, value, expiry})
    :ok
  end

  @doc """
  Delete a cached value.
  """
  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  @doc """
  Delete all cache entries matching a pattern.
  """
  def delete_pattern(pattern) do
    :ets.foldl(
      fn {key, _value, _expiry}, acc ->
        if match_pattern?(key, pattern) do
          :ets.delete(@table_name, key)
          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )
  end

  @doc """
  Invalidate all cache entries for a specific entity.
  """
  def invalidate_entity(entity_type, entity_id) do
    pattern = "#{entity_type}:#{entity_id}:*"
    deleted = delete_pattern(pattern)
    Logger.info("Invalidated #{deleted} cache entries for #{entity_type}:#{entity_id}")
    :ok
  end

  @doc """
  Invalidate cache entries matching a pattern.
  Alias for delete_pattern/1 for backward compatibility.
  """
  def invalidate_pattern(pattern) do
    delete_pattern(pattern)
  end

  @doc """
  Get all cache keys matching a pattern.
  Used for hash-based smart invalidation.
  """
  def get_keys_by_pattern(pattern) do
    :ets.foldl(
      fn {key, _value, _expiry}, acc ->
        if match_pattern?(key, pattern) do
          [key | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
  end

  @doc """
  Invalidate a specific cache key.
  """
  def invalidate_key(key) do
    delete(key)
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Clear the entire cache.
  """
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create cache table
    cache_table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Create stats table
    stats_table =
      :ets.new(:query_cache_stats, [
        :named_table,
        :public,
        :set,
        write_concurrency: true
      ])

    # Initialize stats
    :ets.insert(stats_table, {:hits, 0})
    :ets.insert(stats_table, {:misses, 0})
    :ets.insert(stats_table, {:evictions, 0})

    # Schedule cleanup
    schedule_cleanup()

    state = %__MODULE__{
      cache_table: cache_table,
      stats_table: stats_table,
      start_time: DateTime.utc_now()
    }

    Logger.info("QueryCache started")

    {:ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    [{:hits, hits}] = :ets.lookup(:query_cache_stats, :hits)
    [{:misses, misses}] = :ets.lookup(:query_cache_stats, :misses)
    [{:evictions, evictions}] = :ets.lookup(:query_cache_stats, :evictions)

    total_requests = hits + misses
    hit_rate = if total_requests > 0, do: hits / total_requests * 100, else: 0

    cache_size = :ets.info(@table_name, :size)
    memory_bytes = :ets.info(@table_name, :memory) * :erlang.system_info(:wordsize)

    stats = %{
      hits: hits,
      misses: misses,
      evictions: evictions,
      hit_rate: Float.round(hit_rate, 2),
      cache_size: cache_size,
      memory_mb: Float.round(memory_bytes / 1_048_576, 2),
      uptime_hours: DateTime.diff(DateTime.utc_now(), state.start_time, :hour)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(@table_name)
    :ets.update_counter(:query_cache_stats, :evictions, :ets.info(@table_name, :size))

    Logger.info("QueryCache cleared")

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    enforce_size_limit()
    schedule_cleanup()

    {:noreply, state}
  end

  # Private functions

  defp compute_and_cache(key, compute_fn, ttl) do
    try do
      result = compute_fn.()

      case result do
        {:ok, value} ->
          put(key, value, ttl)
          {:ok, value}

        {:error, _} = error ->
          # Don't cache errors
          error

        value ->
          # Assume bare values are successful
          put(key, value, ttl)
          {:ok, value}
      end
    rescue
      error ->
        Logger.error("Error computing cache value for #{key}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp record_hit(key, start_time) do
    :ets.update_counter(:query_cache_stats, :hits, 1)

    duration = System.monotonic_time(:millisecond) - start_time

    if duration > 0 do
      Logger.debug("Cache hit for #{key} (#{duration}ms)")
    end
  end

  defp record_miss(key, start_time) do
    :ets.update_counter(:query_cache_stats, :misses, 1)

    duration = System.monotonic_time(:millisecond) - start_time

    if duration > 0 do
      Logger.debug("Cache miss for #{key} (#{duration}ms)")
    end
  end

  defp match_pattern?(key, pattern) when is_binary(key) and is_binary(pattern) do
    regex_pattern =
      pattern
      |> String.replace("*", ".*")
      |> Regex.compile!()

    Regex.match?(regex_pattern, key)
  end

  defp cleanup_expired_entries do
    now = DateTime.utc_now()

    expired_count =
      :ets.foldl(
        fn {key, _value, expiry}, acc ->
          if DateTime.compare(now, expiry) == :gt do
            :ets.delete(@table_name, key)
            acc + 1
          else
            acc
          end
        end,
        0,
        @table_name
      )

    if expired_count > 0 do
      :ets.update_counter(:query_cache_stats, :evictions, expired_count)
      Logger.debug("Cleaned up #{expired_count} expired cache entries")
    end
  end

  defp enforce_size_limit do
    cache_size = :ets.info(@table_name, :size)

    if cache_size > @max_cache_size do
      # Get all entries sorted by expiry time
      entries =
        :ets.tab2list(@table_name)
        |> Enum.sort_by(fn {_key, _value, expiry} -> expiry end)

      # Calculate how many to remove
      # Remove 10% extra
      to_remove = cache_size - @max_cache_size + div(@max_cache_size, 10)

      # Remove oldest entries
      entries
      |> Enum.take(to_remove)
      |> Enum.each(fn {key, _value, _expiry} ->
        :ets.delete(@table_name, key)
      end)

      :ets.update_counter(:query_cache_stats, :evictions, to_remove)
      Logger.info("Evicted #{to_remove} cache entries due to size limit")
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
