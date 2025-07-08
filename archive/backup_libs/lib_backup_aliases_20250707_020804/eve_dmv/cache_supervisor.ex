defmodule EveDmv.CacheSupervisor do
  @moduledoc """
  Supervisor for the unified cache system.

  Starts and manages three specialized cache instances:
  - Hot data cache: Frequently accessed data (characters, systems, items)
  - API responses cache: External API responses with longer TTL
  - Analysis cache: Intelligence analysis results
  """

  use Supervisor

  alias EveDmv.Config.Cache, as: CacheConfig
  alias EveDmv.Utils.Cache

  @doc """
  Start the cache supervisor.
  """
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      # Hot data cache - frequently accessed data
      {Cache,
       [
         name: :hot_data_cache,
         ttl_ms: CacheConfig.hot_data_ttl(),
         max_size: CacheConfig.hot_data_max_size(),
         # 5 minutes
         cleanup_interval_ms: 5 * 60 * 1000
       ]},

      # API responses cache - external API responses
      {Cache,
       [
         name: :api_responses_cache,
         ttl_ms: CacheConfig.api_responses_ttl(),
         max_size: CacheConfig.api_responses_max_size(),
         # 30 minutes
         cleanup_interval_ms: 30 * 60 * 1000
       ]},

      # Analysis cache - intelligence analysis results
      {Cache,
       [
         name: :analysis_cache,
         ttl_ms: CacheConfig.analysis_ttl(),
         max_size: CacheConfig.analysis_max_size(),
         # 1 hour
         cleanup_interval_ms: 60 * 60 * 1000
       ]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Get the cache name for a given cache type.
  """
  @spec cache_name(cache_type :: atom()) :: atom()
  def cache_name(:hot_data), do: :hot_data_cache
  def cache_name(:api_responses), do: :api_responses_cache
  def cache_name(:analysis), do: :analysis_cache

  @doc """
  Get cache statistics for all cache types.
  """
  @spec all_cache_stats() :: map()
  def all_cache_stats do
    %{
      hot_data: Cache.stats(:hot_data_cache),
      api_responses: Cache.stats(:api_responses_cache),
      analysis: Cache.stats(:analysis_cache)
    }
  end

  @doc """
  Clear all caches.
  """
  @spec clear_all_caches() :: :ok
  def clear_all_caches do
    Cache.clear(:hot_data_cache)
    Cache.clear(:api_responses_cache)
    Cache.clear(:analysis_cache)
    :ok
  end
end
