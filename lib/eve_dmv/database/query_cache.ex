defmodule EveDmv.Database.QueryCache do
  @moduledoc """
  Query cache adapter using the unified cache system.

  This module maintains the same interface as before but delegates
  to the unified cache implementation.
  """

  alias EveDmv.Utils.Cache

  @cache_name :query_cache
  # 5 minutes
  @default_ttl 300_000
  @max_cache_size 1000

  @doc """
  Child specification for supervision tree.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Start the query cache.
  """
  def start_link(_opts \\ []) do
    cache_opts = [
      name: @cache_name,
      ttl_ms: @default_ttl,
      max_size: @max_cache_size,
      # 1 minute
      cleanup_interval_ms: 60_000
    ]

    Cache.start_link(cache_opts)
  end

  @doc """
  Get a cached result or compute and cache it if not found.
  """
  def get_or_compute(cache_key, compute_fn, ttl \\ @default_ttl)
      when is_function(compute_fn, 0) do
    Cache.get_or_compute(@cache_name, cache_key, compute_fn, ttl_ms: ttl)
  end

  @doc """
  Manually put a value in the cache.
  """
  def put(cache_key, value, ttl \\ @default_ttl) do
    Cache.put(@cache_name, cache_key, value, ttl_ms: ttl)
  end

  @doc """
  Remove a specific key from the cache.
  """
  def delete(cache_key) do
    Cache.delete(@cache_name, cache_key)
  end

  @doc """
  Clear all cached entries.
  """
  def clear_all do
    Cache.clear(@cache_name)
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    Cache.stats(@cache_name)
  end

  @doc """
  Invalidate cache entries matching a pattern.
  """
  def invalidate_pattern(pattern) do
    Cache.invalidate_pattern(@cache_name, pattern)
  end
end
