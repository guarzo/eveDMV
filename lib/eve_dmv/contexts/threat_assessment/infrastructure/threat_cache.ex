defmodule EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache do
  @moduledoc """
  Cache management for threat assessment data.

  Provides efficient caching of threat assessments, vulnerability scans,
  and related analysis data to reduce computation overhead for frequently
  accessed entities.
  """

  use GenServer
  use EveDmv.ErrorHandler

  require Logger

  # Cache configuration
  # 5 minutes
  @default_ttl 300
  @max_cache_size 10_000
  # 1 minute
  @cleanup_interval 60_000

  # Cache types
  @threat_assessment_prefix "threat_assessment"
  @vulnerability_scan_prefix "vulnerability_scan"
  @threat_level_prefix "threat_level"
  @historical_data_prefix "historical_data"

  @doc """
  Start the cache with periodic cleanup.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store threat assessment result in cache.
  """
  def store_threat_assessment(entity_id, entity_type, assessment_data, ttl \\ @default_ttl) do
    GenServer.cast(
      __MODULE__,
      {:store, @threat_assessment_prefix, entity_id, entity_type, assessment_data, ttl}
    )
  end

  @doc """
  Get cached threat assessment.
  """
  def get_threat_assessment(entity_id, entity_type) do
    GenServer.call(__MODULE__, {:get, @threat_assessment_prefix, entity_id, entity_type})
  end

  @doc """
  Store vulnerability scan result in cache.
  """
  def store_vulnerability_scan(entity_id, entity_type, scan_data, ttl \\ @default_ttl) do
    GenServer.cast(
      __MODULE__,
      {:store, @vulnerability_scan_prefix, entity_id, entity_type, scan_data, ttl}
    )
  end

  @doc """
  Get cached vulnerability scan.
  """
  def get_vulnerability_scan(entity_id, entity_type) do
    GenServer.call(__MODULE__, {:get, @vulnerability_scan_prefix, entity_id, entity_type})
  end

  @doc """
  Store threat level assessment in cache.
  """
  def store_threat_level(entity_id, entity_type, threat_level, ttl \\ @default_ttl) do
    GenServer.cast(
      __MODULE__,
      {:store, @threat_level_prefix, entity_id, entity_type, threat_level, ttl}
    )
  end

  @doc """
  Get cached threat level.
  """
  def get_threat_level(entity_id, entity_type) do
    GenServer.call(__MODULE__, {:get, @threat_level_prefix, entity_id, entity_type})
  end

  @doc """
  Store historical threat data in cache.
  """
  def store_historical_data(entity_id, entity_type, historical_data, ttl \\ nil) do
    # Historical data gets longer TTL (1 hour default)
    historical_ttl = ttl || 3600

    GenServer.cast(
      __MODULE__,
      {:store, @historical_data_prefix, entity_id, entity_type, historical_data, historical_ttl}
    )
  end

  @doc """
  Get cached historical threat data.
  """
  def get_historical_data(entity_id, entity_type) do
    GenServer.call(__MODULE__, {:get, @historical_data_prefix, entity_id, entity_type})
  end

  @doc """
  Invalidate cache entries for an entity.
  """
  def invalidate_entity(entity_id, entity_type) do
    GenServer.cast(__MODULE__, {:invalidate_entity, entity_id, entity_type})
  end

  @doc """
  Invalidate all cache entries of a specific type.
  """
  def invalidate_type(cache_type) do
    GenServer.cast(__MODULE__, {:invalidate_type, cache_type})
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Clear all cache entries.
  """
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)

    state = %{
      cache: %{},
      stats: %{
        hits: 0,
        misses: 0,
        stores: 0,
        evictions: 0,
        cleanups: 0
      }
    }

    Logger.info("ThreatCache started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get, cache_type, entity_id, entity_type}, _from, state) do
    cache_key = build_cache_key(cache_type, entity_id, entity_type)

    case Map.get(state.cache, cache_key) do
      %{data: data, expires_at: expires_at} ->
        if DateTime.after?(DateTime.utc_now(), expires_at) do
          # Entry expired
          new_cache = Map.delete(state.cache, cache_key)
          new_stats = %{state.stats | misses: state.stats.misses + 1}
          new_state = %{state | cache: new_cache, stats: new_stats}

          {:reply, {:error, :not_found}, new_state}
        else
          # Entry valid
          new_stats = %{state.stats | hits: state.stats.hits + 1}
          new_state = %{state | stats: new_stats}

          {:reply, {:ok, data}, new_state}
        end

      nil ->
        # Entry not found
        new_stats = %{state.stats | misses: state.stats.misses + 1}
        new_state = %{state | stats: new_stats}

        {:reply, {:error, :not_found}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    cache_size = map_size(state.cache)

    enhanced_stats =
      state.stats
      |> Map.put(:cache_size, cache_size)
      |> Map.put(:hit_rate, calculate_hit_rate(state.stats))
      |> Map.put(:max_cache_size, @max_cache_size)
      |> Map.put(:cache_utilization, cache_size / @max_cache_size)

    {:reply, enhanced_stats, state}
  end

  @impl GenServer
  def handle_cast({:store, cache_type, entity_id, entity_type, data, ttl}, state) do
    cache_key = build_cache_key(cache_type, entity_id, entity_type)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)

    cache_entry = %{
      data: data,
      expires_at: expires_at,
      stored_at: DateTime.utc_now()
    }

    # Check if we need to evict entries
    new_cache =
      Map.put(
        if map_size(state.cache) >= @max_cache_size do
          # Evict 100 oldest entries
          evict_oldest_entries(state.cache, 100)
        else
          state.cache
        end,
        cache_key,
        cache_entry
      )

    evictions = if map_size(state.cache) >= @max_cache_size, do: 100, else: 0

    new_stats = %{
      state.stats
      | stores: state.stats.stores + 1,
        evictions: state.stats.evictions + evictions
    }

    new_state = %{state | cache: new_cache, stats: new_stats}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:invalidate_entity, entity_id, entity_type}, state) do
    # Remove all cache entries for this entity
    cache_patterns = [
      build_cache_key(@threat_assessment_prefix, entity_id, entity_type),
      build_cache_key(@vulnerability_scan_prefix, entity_id, entity_type),
      build_cache_key(@threat_level_prefix, entity_id, entity_type),
      build_cache_key(@historical_data_prefix, entity_id, entity_type)
    ]

    new_cache =
      Enum.reduce(cache_patterns, state.cache, fn key, cache ->
        Map.delete(cache, key)
      end)

    new_state = %{state | cache: new_cache}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:invalidate_type, cache_type}, state) do
    # Remove all cache entries of this type
    new_cache =
      state.cache
      |> Enum.reject(fn {key, _value} ->
        String.starts_with?(key, cache_type)
      end)
      |> Enum.into(%{})

    new_state = %{state | cache: new_cache}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:clear_all, state) do
    new_state = %{state | cache: %{}}
    Logger.info("ThreatCache cleared all entries")
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    # Remove expired entries
    now = DateTime.utc_now()

    new_cache =
      state.cache
      |> Enum.reject(fn {_key, %{expires_at: expires_at}} ->
        DateTime.after?(now, expires_at)
      end)
      |> Enum.into(%{})

    cleaned_count = map_size(state.cache) - map_size(new_cache)

    new_stats = %{state.stats | cleanups: state.stats.cleanups + 1}
    new_state = %{state | cache: new_cache, stats: new_stats}

    if cleaned_count > 0 do
      Logger.debug("ThreatCache cleanup removed #{cleaned_count} expired entries")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, @cleanup_interval)

    {:noreply, new_state}
  end

  # Private functions

  defp build_cache_key(cache_type, entity_id, entity_type) do
    "#{cache_type}:#{entity_type}:#{entity_id}"
  end

  defp calculate_hit_rate(stats) do
    total_requests = stats.hits + stats.misses

    if total_requests > 0 do
      Float.round(stats.hits / total_requests * 100, 2)
    else
      0.0
    end
  end

  defp evict_oldest_entries(cache, count_to_evict) do
    # Sort by stored_at timestamp and remove oldest entries
    cache
    |> Enum.sort_by(fn {_key, %{stored_at: stored_at}} -> stored_at end)
    |> Enum.drop(count_to_evict)
    |> Enum.into(%{})
  end

  @impl GenServer
  def handle_call({:get_entry_details, cache_type, entity_id, entity_type}, _from, state) do
    cache_key = build_cache_key(cache_type, entity_id, entity_type)

    case Map.get(state.cache, cache_key) do
      nil ->
        {:reply, {:error, :not_found}, state}

      entry ->
        details = %{
          cache_key: cache_key,
          stored_at: entry.stored_at,
          expires_at: entry.expires_at,
          ttl_remaining: DateTime.diff(entry.expires_at, DateTime.utc_now(), :second),
          is_expired: DateTime.after?(DateTime.utc_now(), entry.expires_at),
          data_size: estimate_data_size(entry.data)
        }

        {:reply, {:ok, details}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_cache_keys, pattern}, _from, state) do
    keys =
      if pattern do
        state.cache
        |> Map.keys()
        |> Enum.filter(&String.contains?(&1, pattern))
      else
        Map.keys(state.cache)
      end

    {:reply, keys, state}
  end

  @impl GenServer
  def handle_call(:get_detailed_metrics, _from, state) do
    cache_size = map_size(state.cache)

    # Analyze cache contents by type
    type_breakdown =
      Enum.reduce(state.cache, %{}, fn {key, _value}, acc ->
        type = key |> String.split(":") |> List.first()
        Map.update(acc, type, 1, &(&1 + 1))
      end)

    # Calculate cache age distribution
    now = DateTime.utc_now()

    age_distribution =
      state.cache
      |> Enum.map(fn {_key, %{stored_at: stored_at}} ->
        DateTime.diff(now, stored_at, :second)
      end)
      |> calculate_age_stats()

    detailed_metrics = %{
      basic_stats: state.stats,
      cache_size: cache_size,
      hit_rate: calculate_hit_rate(state.stats),
      cache_utilization: cache_size / @max_cache_size,
      type_breakdown: type_breakdown,
      age_distribution: age_distribution,
      memory_estimate: estimate_total_memory_usage(state.cache)
    }

    {:reply, detailed_metrics, state}
  end

  defp estimate_data_size(data) do
    # Rough estimate of data size in memory
    binary_data = :erlang.term_to_binary(data)
    byte_size(binary_data)
  rescue
    _ -> :unknown
  end

  @impl GenServer
  def handle_cast({:warm_cache, entity_specs}, state) do
    # This would trigger threat assessments for the specified entities
    # For now, just log the warming request
    Logger.info("ThreatCache warming requested for #{length(entity_specs)} entities")

    # In a full implementation, this would:
    # 1. Check if entities are already cached
    # 2. Trigger background threat assessments for uncached entities
    # 3. Populate cache with results

    {:noreply, state}
  end

  # Public API functions moved after GenServer implementation

  @doc """
  Get cache entry details for debugging.
  """
  def get_cache_entry_details(entity_id, entity_type, cache_type) do
    GenServer.call(__MODULE__, {:get_entry_details, cache_type, entity_id, entity_type})
  end

  @doc """
  Get all cache keys matching a pattern.
  """
  def get_cache_keys(pattern \\ nil) do
    GenServer.call(__MODULE__, {:get_cache_keys, pattern})
  end

  @doc """
  Warm cache with commonly accessed entities.
  """
  def warm_cache(entity_specs) when is_list(entity_specs) do
    GenServer.cast(__MODULE__, {:warm_cache, entity_specs})
  end

  @doc """
  Get detailed cache metrics for monitoring.
  """
  def get_detailed_metrics do
    GenServer.call(__MODULE__, :get_detailed_metrics)
  end

  defp calculate_age_stats(ages) do
    if Enum.empty?(ages) do
      %{min: 0, max: 0, avg: 0, median: 0}
    else
      sorted_ages = Enum.sort(ages)
      count = length(sorted_ages)

      %{
        min: List.first(sorted_ages),
        max: List.last(sorted_ages),
        avg: Enum.sum(sorted_ages) / count,
        median: Enum.at(sorted_ages, div(count, 2))
      }
    end
  end

  defp estimate_total_memory_usage(cache) do
    cache
    |> Enum.map(fn {_key, entry} -> estimate_data_size(entry.data) end)
    |> Enum.filter(&is_integer/1)
    |> Enum.sum()
  end
end
