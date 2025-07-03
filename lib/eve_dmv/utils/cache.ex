defmodule EveDmv.Utils.Cache do
  @moduledoc """
  Unified caching module using ETS for various caching needs.
  
  This module replaces multiple GenServer-based caches with a simple, 
  efficient ETS-based implementation. It supports:
  - TTL-based expiration
  - Pattern-based invalidation
  - Size limits with FIFO eviction
  - Multiple named caches
  """

  require Logger

  @default_ttl_ms 5 * 60 * 1000  # 5 minutes
  @cleanup_interval_ms 60 * 1000  # 1 minute
  @default_max_size 1000

  @doc """
  Start a new cache with the given name and options.
  
  Options:
  - ttl_ms: Time to live in milliseconds (default: 5 minutes)
  - max_size: Maximum number of entries (default: 1000)
  - cleanup_interval_ms: How often to run cleanup (default: 1 minute)
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    table_name = cache_table_name(name)
    
    # Create ETS table
    :ets.new(table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])
    
    # Start cleanup task
    cleanup_interval = Keyword.get(opts, :cleanup_interval_ms, @cleanup_interval_ms)
    {:ok, _pid} = Task.start_link(fn -> 
      periodic_cleanup(table_name, cleanup_interval)
    end)
  end

  @doc """
  Child specification for supervision tree.
  """
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)
    %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Get a value from the cache, or compute and store it if not found.
  """
  def get_or_compute(cache_name, key, compute_fn, opts \\ []) when is_function(compute_fn, 0) do
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    
    case get(cache_name, key) do
      {:ok, value} ->
        track_cache_access(cache_name, :hit)
        value
        
      :miss ->
        track_cache_access(cache_name, :miss)
        value = compute_fn.()
        put(cache_name, key, value, ttl_ms: ttl_ms)
        value
    end
  end

  @doc """
  Get a value from the cache.
  """
  def get(cache_name, key) do
    table_name = cache_table_name(cache_name)
    
    case :ets.lookup(table_name, key) do
      [{^key, value, expires_at}] ->
        if timestamp_ms() < expires_at do
          {:ok, value}
        else
          # Expired, remove it
          :ets.delete(table_name, key)
          :miss
        end
        
      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss  # Table doesn't exist
  end

  @doc """
  Get multiple values from the cache.
  Returns {found_map, missing_keys}.
  """
  def get_many(cache_name, keys) do
    table_name = cache_table_name(cache_name)
    now = timestamp_ms()
    
    Enum.reduce(keys, {%{}, []}, fn key, {found, missing} ->
      case :ets.lookup(table_name, key) do
        [{^key, value, expires_at}] ->
          if now < expires_at do
            {Map.put(found, key, value), missing}
          else
            :ets.delete(table_name, key)
            {found, [key | missing]}
          end
          
        [] ->
          {found, [key | missing]}
      end
    end)
  rescue
    ArgumentError -> {%{}, keys}  # Table doesn't exist
  end

  @doc """
  Put a value in the cache.
  """
  def put(cache_name, key, value, opts \\ []) do
    table_name = cache_table_name(cache_name)
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    
    expires_at = timestamp_ms() + ttl_ms
    
    # Check size limit
    ensure_size_limit(table_name, max_size)
    
    :ets.insert(table_name, {key, value, expires_at})
    :ok
  rescue
    ArgumentError -> :ok  # Table doesn't exist
  end

  @doc """
  Put multiple values in the cache.
  """
  def put_many(cache_name, entries, opts \\ []) do
    table_name = cache_table_name(cache_name)
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    expires_at = timestamp_ms() + ttl_ms
    
    ets_entries = Enum.map(entries, fn {key, value} ->
      {key, value, expires_at}
    end)
    
    :ets.insert(table_name, ets_entries)
    :ok
  rescue
    ArgumentError -> :ok  # Table doesn't exist
  end

  @doc """
  Delete a key from the cache.
  """
  def delete(cache_name, key) do
    table_name = cache_table_name(cache_name)
    :ets.delete(table_name, key)
    :ok
  rescue
    ArgumentError -> :ok  # Table doesn't exist
  end

  @doc """
  Clear all entries from the cache.
  """
  def clear(cache_name) do
    table_name = cache_table_name(cache_name)
    :ets.delete_all_objects(table_name)
    :ok
  rescue
    ArgumentError -> :ok  # Table doesn't exist
  end

  @doc """
  Invalidate entries matching a pattern.
  Pattern uses * as wildcard (e.g., "user_*").
  """
  def invalidate_pattern(cache_name, pattern) do
    table_name = cache_table_name(cache_name)
    regex = pattern_to_regex(pattern)
    
    matching_keys =
      :ets.foldl(
        fn {key, _value, _expires_at}, acc ->
          key_str = to_string(key)
          if Regex.match?(regex, key_str) do
            [key | acc]
          else
            acc
          end
        end,
        [],
        table_name
      )
    
    Enum.each(matching_keys, fn key ->
      :ets.delete(table_name, key)
    end)
    
    length(matching_keys)
  rescue
    ArgumentError -> 0  # Table doesn't exist
  end

  @doc """
  Get cache statistics.
  """
  def stats(cache_name) do
    table_name = cache_table_name(cache_name)
    
    size = :ets.info(table_name, :size) || 0
    memory = :ets.info(table_name, :memory) || 0
    
    %{
      size: size,
      memory_bytes: memory * :erlang.system_info(:wordsize)
    }
  rescue
    ArgumentError ->
      %{size: 0, memory_bytes: 0}
  end

  # Private functions

  defp cache_table_name(name) when is_atom(name), do: name
  defp cache_table_name(name), do: String.to_atom("cache_#{name}")

  defp timestamp_ms do
    System.monotonic_time(:millisecond)
  end

  defp pattern_to_regex(pattern) do
    pattern
    |> String.replace("*", ".*")
    |> Regex.compile!()
  end

  defp track_cache_access(cache_name, type) do
    # Integration point for telemetry if needed
    Logger.debug("Cache #{cache_name} #{type}")
  end

  defp ensure_size_limit(table_name, max_size) do
    current_size = :ets.info(table_name, :size)
    
    if current_size >= max_size do
      # Simple FIFO eviction - remove oldest 10%
      num_to_remove = div(max_size, 10)
      
      :ets.tab2list(table_name)
      |> Enum.sort_by(fn {_key, _value, expires_at} -> expires_at end)
      |> Enum.take(num_to_remove)
      |> Enum.each(fn {key, _value, _expires_at} ->
        :ets.delete(table_name, key)
      end)
    end
  end

  defp periodic_cleanup(table_name, interval_ms) do
    Process.sleep(interval_ms)
    cleanup_expired(table_name)
    periodic_cleanup(table_name, interval_ms)
  end

  defp cleanup_expired(table_name) do
    now = timestamp_ms()
    
    expired_count =
      :ets.foldl(
        fn {key, _value, expires_at}, count ->
          if expires_at <= now do
            :ets.delete(table_name, key)
            count + 1
          else
            count
          end
        end,
        0,
        table_name
      )
    
    if expired_count > 0 do
      Logger.info("Cleaned up #{expired_count} expired entries from #{table_name}")
    end
  rescue
    ArgumentError -> :ok  # Table doesn't exist
  end
end