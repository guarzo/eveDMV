defmodule EveDmv.Intelligence.Core.CacheHelper do
  @moduledoc """
  Unified caching interface for intelligence analyzers.

  Provides consistent caching patterns with TTL management, cache invalidation,
  and telemetry integration. Supports both analyzer-specific and cross-analyzer
  cache invalidation strategies.
  """

  alias EveDmv.Utils.Cache

  require Logger

  # Cache name for intelligence operations
  @cache_name :intelligence_cache

  @type cache_key :: String.t()
  @type cache_value :: term()
  @type cache_ttl :: pos_integer()
  @type analysis_type :: atom()

  @doc """
  Get or compute cached analysis result with standardized key generation.

  Uses analyzer type and entity ID to generate consistent cache keys.
  Automatically handles TTL and provides telemetry events.
  """
  @spec get_or_compute(analysis_type(), integer(), cache_ttl(), (-> cache_value())) ::
          cache_value()
  def get_or_compute(analysis_type, entity_id, ttl_seconds, compute_fn) do
    cache_key = generate_cache_key(analysis_type, entity_id)

    start_time = System.monotonic_time()

    result =
      Cache.get_or_compute(
        @cache_name,
        cache_key,
        fn ->
          Logger.debug("Cache miss for #{analysis_type} analysis of entity #{entity_id}")

          :telemetry.execute(
            [:eve_dmv, :intelligence, :cache_miss],
            %{count: 1},
            %{analysis_type: analysis_type, entity_id: entity_id, cache_key: cache_key}
          )

          compute_fn.()
        end,
        ttl_ms: ttl_seconds * 1000
      )

    duration_native = System.monotonic_time() - start_time
    duration_ms = System.convert_time_unit(duration_native, :native, :millisecond)

    # Emit cache hit/miss telemetry
    cache_status = if duration_ms < 1, do: :hit, else: :computed

    :telemetry.execute(
      [:eve_dmv, :intelligence, :cache_access],
      %{duration_ms: duration_ms},
      %{
        analysis_type: analysis_type,
        entity_id: entity_id,
        cache_key: cache_key,
        cache_status: cache_status
      }
    )

    result
  end

  @doc """
  Invalidate cache entries for a specific entity across multiple analysis types.

  Useful when an entity's data changes and multiple cached analyses become stale.
  """
  @spec invalidate_entity(integer(), [analysis_type()]) :: :ok
  def invalidate_entity(entity_id, analysis_types) do
    Logger.debug(
      "Invalidating cache for entity #{entity_id} across #{length(analysis_types)} analysis types"
    )

    Enum.each(analysis_types, fn analysis_type ->
      cache_key = generate_cache_key(analysis_type, entity_id)
      Cache.delete(@cache_name, cache_key)

      :telemetry.execute(
        [:eve_dmv, :intelligence, :cache_invalidation],
        %{count: 1},
        %{analysis_type: analysis_type, entity_id: entity_id, cache_key: cache_key}
      )
    end)

    :ok
  end

  @doc """
  Invalidate cache entry for a specific analysis type and entity.
  """
  @spec invalidate_analysis(analysis_type(), integer()) :: :ok
  def invalidate_analysis(analysis_type, entity_id) do
    cache_key = generate_cache_key(analysis_type, entity_id)

    Logger.debug("Invalidating #{analysis_type} cache for entity #{entity_id}")

    Cache.delete(@cache_name, cache_key)

    :telemetry.execute(
      [:eve_dmv, :intelligence, :cache_invalidation],
      %{count: 1},
      %{analysis_type: analysis_type, entity_id: entity_id, cache_key: cache_key}
    )

    :ok
  end

  @doc """
  Generate standardized cache key for analysis type and entity.

  Ensures consistent cache key format across all analyzers.
  """
  @spec generate_cache_key(analysis_type(), integer()) :: cache_key()
  def generate_cache_key(analysis_type, entity_id) do
    "intelligence:#{analysis_type}:#{entity_id}"
  end

  @doc """
  Warm cache for multiple entities and analysis types.

  Useful for batch processing or preloading frequently accessed data.
  """
  @spec warm_cache([{analysis_type(), integer(), (-> cache_value())}], cache_ttl()) :: :ok
  def warm_cache(entries, ttl_seconds) do
    Logger.info("Warming cache for #{length(entries)} analysis entries")

    start_time = System.monotonic_time()

    entries
    |> Task.async_stream(
      fn {analysis_type, entity_id, compute_fn} ->
        get_or_compute(analysis_type, entity_id, ttl_seconds, compute_fn)
      end,
      max_concurrency: 10,
      timeout: 60_000
    )
    |> Stream.run()

    warm_duration_native = System.monotonic_time() - start_time
    duration_ms = System.convert_time_unit(warm_duration_native, :native, :millisecond)

    Logger.info("Cache warming completed for #{length(entries)} entries in #{duration_ms}ms")

    :telemetry.execute(
      [:eve_dmv, :intelligence, :cache_warm],
      %{count: length(entries), duration_ms: duration_ms},
      %{ttl_seconds: ttl_seconds}
    )

    :ok
  end

  @doc """
  Get cache statistics for monitoring and debugging.
  """
  @spec get_cache_stats() :: map()
  def get_cache_stats do
    # This would integrate with the actual cache implementation
    # For now, return a placeholder structure
    %{
      total_keys: 0,
      hit_rate: 0.0,
      memory_usage_bytes: 0,
      oldest_entry_age_seconds: 0
    }
  end
end
