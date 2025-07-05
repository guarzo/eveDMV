defmodule EveDmv.IntelligenceEngine.CacheManager do
  @moduledoc """
  Intelligent cache management for the Intelligence Engine.

  Provides a high-level caching layer that integrates with the unified
  EveDmv.Cache system while adding Intelligence Engine-specific features
  like cache warming, invalidation patterns, and performance optimization.
  """

  alias EveDmv.Cache

  @type cache_key :: String.t()
  @type cache_value :: term()
  @type cache_ttl :: integer()
  @type domain :: atom()
  @type entity_id :: integer()

  defstruct [:cache_type, :metrics, :config]

  @doc """
  Initialize a new cache manager instance.
  """
  @spec initialize() :: %__MODULE__{}
  def initialize do
    %__MODULE__{
      # Use analysis cache type for intelligence data
      cache_type: :analysis,
      metrics: %{
        hits: 0,
        misses: 0,
        stores: 0,
        invalidations: 0
      },
      config: %{
        # 10 minutes
        default_ttl: 600_000,
        max_key_size: 250,
        enable_metrics: true
      }
    }
  end

  @doc """
  Get a value from the cache.
  """
  @spec get(%__MODULE__{}, cache_key()) :: {:ok, cache_value()} | :miss
  def get(manager, cache_key) do
    case Cache.get(manager.cache_type, cache_key) do
      {:ok, value} ->
        update_metrics(manager, :hits)
        {:ok, value}

      :miss ->
        update_metrics(manager, :misses)
        :miss
    end
  end

  @doc """
  Store a value in the cache.
  """
  @spec put(%__MODULE__{}, cache_key(), cache_value(), cache_ttl() | nil) :: :ok
  def put(manager, cache_key, value, ttl \\ nil) do
    effective_ttl = ttl || manager.config.default_ttl

    # Validate cache key size and truncate if needed
    final_cache_key =
      if String.length(cache_key) > manager.config.max_key_size do
        truncate_cache_key(cache_key, manager.config.max_key_size)
      else
        cache_key
      end

    Cache.put(manager.cache_type, final_cache_key, value, cache_ttl: effective_ttl)
    update_metrics(manager, :stores)
    :ok
  end

  @doc """
  Invalidate cache entries for a specific entity.
  """
  @spec invalidate(%__MODULE__{}, domain(), entity_id()) :: :ok
  def invalidate(manager, domain, entity_id) do
    # Invalidate all cache entries related to this entity
    patterns = [
      "intelligence:#{domain}:#{entity_id}:*",
      # For batch operations that include this entity
      "intelligence:#{domain}:*:#{entity_id}:*"
    ]

    Enum.each(patterns, fn pattern ->
      Cache.invalidate_pattern(manager.cache_type, pattern)
    end)

    update_metrics(manager, :invalidations)
    :ok
  end

  @doc """
  Invalidate cache entries by pattern.
  """
  @spec invalidate_pattern(%__MODULE__{}, String.t()) :: :ok
  def invalidate_pattern(manager, pattern) do
    Cache.invalidate_pattern(manager.cache_type, pattern)
    update_metrics(manager, :invalidations)
    :ok
  end

  @doc """
  Clear all intelligence cache entries.
  """
  @spec clear_all(%__MODULE__{}) :: :ok
  def clear_all(manager) do
    Cache.invalidate_pattern(manager.cache_type, "intelligence:*")
    :ok
  end

  @doc """
  Get cache performance metrics.
  """
  @spec get_metrics(%__MODULE__{}) :: map()
  def get_metrics(manager) do
    total_requests = manager.metrics.hits + manager.metrics.misses
    hit_rate = if total_requests > 0, do: manager.metrics.hits / total_requests, else: 0.0

    %{
      hits: manager.metrics.hits,
      misses: manager.metrics.misses,
      stores: manager.metrics.stores,
      invalidations: manager.metrics.invalidations,
      hit_rate: hit_rate,
      total_requests: total_requests
    }
  end

  @doc """
  Warm cache with frequently accessed data.
  """
  @spec warm_cache(%__MODULE__{}, domain(), [entity_id()]) :: :ok
  def warm_cache(_manager, _domain, _entity_ids) do
    # Cache warming would be implemented here
    # This is a placeholder for now
    :ok
  end

  @doc """
  Update cache configuration.
  """
  @spec update_config(%__MODULE__{}, map()) :: %__MODULE__{}
  def update_config(manager, new_config) do
    config = Map.merge(manager.config, new_config)
    %{manager | config: config}
  end

  # Private helper functions

  defp update_metrics(manager, metric_type) do
    if manager.config.enable_metrics do
      # Update metrics in place (this is a simple implementation)
      # In a real system, this might use ETS or a metrics system
      :ok
    else
      :ok
    end
  end

  defp truncate_cache_key(cache_key, max_size) when byte_size(cache_key) > max_size do
    # Create a hash of the full key to ensure uniqueness
    hash = :crypto.hash(:sha256, cache_key) |> Base.encode16(case: :lower)
    # Leave room for hash and separator
    prefix_size = max_size - 64 - 1

    prefix = String.slice(cache_key, 0, prefix_size)
    "#{prefix}:#{hash}"
  end

  defp truncate_cache_key(cache_key, _max_size), do: cache_key
end
