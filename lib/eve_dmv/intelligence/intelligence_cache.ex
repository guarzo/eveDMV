defmodule EveDmv.Intelligence.IntelligenceCache do
  @moduledoc """
  Intelligent caching system for intelligence analysis results.

  Provides multi-layered caching with automatic invalidation
  and smart cache warming for frequently accessed data.
  """

  require Logger
  use GenServer

  # Cache configuration
  # Character analysis cached longer
  @character_analysis_ttl :timer.hours(12)
  # Vetting results cached longest
  @vetting_ttl :timer.hours(24)
  # Correlations cached shorter due to dependencies
  @correlation_ttl :timer.hours(4)

  # Cache warming configuration
  # Warm cache every 30 minutes
  @warm_cache_interval :timer.minutes(30)
  # Consider items accessed 5+ times as popular
  @popular_threshold 5

  ## Public API

  @doc """
  Start the intelligence cache process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get character analysis from cache or generate if not cached.
  """
  def get_character_analysis(character_id) do
    cache_key = {:character_analysis, character_id}

    case get_from_cache(cache_key) do
      {:ok, analysis} ->
        track_access(cache_key)
        {:ok, analysis}

      :miss ->
        case generate_character_analysis(character_id) do
          {:ok, analysis} ->
            put_in_cache(cache_key, analysis, @character_analysis_ttl)
            track_access(cache_key)
            {:ok, analysis}

          error ->
            error
        end
    end
  end

  @doc """
  Get vetting analysis from cache or generate if not cached.
  """
  def get_vetting_analysis(character_id) do
    cache_key = {:vetting_analysis, character_id}

    case get_from_cache(cache_key) do
      {:ok, vetting} ->
        track_access(cache_key)
        {:ok, vetting}

      :miss ->
        case generate_vetting_analysis(character_id) do
          {:ok, vetting} ->
            put_in_cache(cache_key, vetting, @vetting_ttl)
            track_access(cache_key)
            {:ok, vetting}

          error ->
            error
        end
    end
  end

  @doc """
  Get correlation analysis from cache or generate if not cached.
  """
  def get_correlation_analysis(character_id) do
    cache_key = {:correlation_analysis, character_id}

    case get_from_cache(cache_key) do
      {:ok, correlation} ->
        track_access(cache_key)
        {:ok, correlation}

      :miss ->
        case generate_correlation_analysis(character_id) do
          {:ok, correlation} ->
            put_in_cache(cache_key, correlation, @correlation_ttl)
            track_access(cache_key)
            {:ok, correlation}

          error ->
            error
        end
    end
  end

  @doc """
  Invalidate cache for a specific character.

  Useful when new data is available that would change analysis results.
  """
  def invalidate_character_cache(character_id) do
    keys_to_invalidate = [
      {:character_analysis, character_id},
      {:vetting_analysis, character_id},
      {:correlation_analysis, character_id}
    ]

    Enum.each(keys_to_invalidate, &delete_from_cache/1)
    Logger.info("Invalidated cache for character #{character_id}")
    :ok
  end

  @doc """
  Warm cache for popular characters.
  """
  def warm_popular_cache do
    GenServer.cast(__MODULE__, :warm_popular_cache)
  end

  @doc """
  Get cache statistics.
  """
  def get_cache_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Clear all cached intelligence data.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  ## GenServer Implementation

  def init(_opts) do
    # Start ETS tables for caching
    :ets.new(:intelligence_cache, [:named_table, :public, read_concurrency: true])
    :ets.new(:cache_access_stats, [:named_table, :public, write_concurrency: true])
    :ets.new(:cache_metadata, [:named_table, :public])

    # Schedule cache warming
    :timer.send_interval(@warm_cache_interval, :warm_cache)

    state = %{
      hit_count: 0,
      miss_count: 0,
      eviction_count: 0
    }

    Logger.info("Intelligence cache started")
    {:ok, state}
  end

  def handle_call(:get_stats, _from, state) do
    cache_size = :ets.info(:intelligence_cache, :size)

    stats = %{
      cache_size: cache_size,
      hit_count: state.hit_count,
      miss_count: state.miss_count,
      eviction_count: state.eviction_count,
      hit_ratio: calculate_hit_ratio(state.hit_count, state.miss_count)
    }

    {:reply, stats, state}
  end

  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(:intelligence_cache)
    :ets.delete_all_objects(:cache_access_stats)
    :ets.delete_all_objects(:cache_metadata)

    Logger.info("Intelligence cache cleared")
    {:reply, :ok, %{state | hit_count: 0, miss_count: 0, eviction_count: 0}}
  end

  def handle_cast(:warm_popular_cache, state) do
    spawn(fn -> perform_cache_warming() end)
    {:noreply, state}
  end

  def handle_info(:warm_cache, state) do
    spawn(fn -> perform_cache_warming() end)
    {:noreply, state}
  end

  def handle_info({:increment_hit}, state) do
    {:noreply, %{state | hit_count: state.hit_count + 1}}
  end

  def handle_info({:increment_miss}, state) do
    {:noreply, %{state | miss_count: state.miss_count + 1}}
  end

  def handle_info({:increment_eviction}, state) do
    {:noreply, %{state | eviction_count: state.eviction_count + 1}}
  end

  ## Private Implementation

  defp get_from_cache(cache_key) do
    case :ets.lookup(:intelligence_cache, cache_key) do
      [{^cache_key, value, expiry_time}] ->
        if DateTime.compare(DateTime.utc_now(), expiry_time) == :lt do
          send(__MODULE__, {:increment_hit})
          {:ok, value}
        else
          # Expired entry
          :ets.delete(:intelligence_cache, cache_key)
          send(__MODULE__, {:increment_eviction})
          :miss
        end

      [] ->
        send(__MODULE__, {:increment_miss})
        :miss
    end
  end

  defp put_in_cache(cache_key, value, ttl) do
    expiry_time = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(:intelligence_cache, {cache_key, value, expiry_time})

    # Store metadata
    :ets.insert(:cache_metadata, {cache_key, DateTime.utc_now(), ttl})

    :ok
  end

  defp delete_from_cache(cache_key) do
    :ets.delete(:intelligence_cache, cache_key)
    :ets.delete(:cache_access_stats, cache_key)
    :ets.delete(:cache_metadata, cache_key)
  end

  defp track_access(cache_key) do
    # Increment access count
    :ets.update_counter(:cache_access_stats, cache_key, {2, 1}, {cache_key, 0})
    :ok
  end

  defp get_popular_characters do
    # Get characters accessed frequently
    :ets.tab2list(:cache_access_stats)
    |> Enum.filter(fn {_key, count} -> count >= @popular_threshold end)
    |> Enum.map(fn {{type, character_id}, _count} ->
      case type do
        t when t in [:character_analysis, :vetting_analysis, :correlation_analysis] ->
          character_id

        _ ->
          nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.uniq()
  end

  defp perform_cache_warming do
    popular_characters = get_popular_characters()

    Logger.info("Warming cache for #{length(popular_characters)} popular characters")

    # Warm cache for popular characters
    Enum.each(popular_characters, fn character_id ->
      # Check if analyses are cached and still valid
      warm_character_analysis(character_id)
      warm_vetting_analysis(character_id)
      warm_correlation_analysis(character_id)
    end)
  end

  defp warm_character_analysis(character_id) do
    cache_key = {:character_analysis, character_id}

    case get_from_cache(cache_key) do
      :miss ->
        # Cache miss, warm the cache
        case generate_character_analysis(character_id) do
          {:ok, analysis} ->
            put_in_cache(cache_key, analysis, @character_analysis_ttl)
            Logger.debug("Warmed character analysis cache for #{character_id}")

          {:error, reason} ->
            Logger.warning(
              "Failed to warm character analysis cache for #{character_id}: #{inspect(reason)}"
            )
        end

      {:ok, _} ->
        # Already cached
        :ok
    end
  end

  defp warm_vetting_analysis(character_id) do
    cache_key = {:vetting_analysis, character_id}

    case get_from_cache(cache_key) do
      :miss ->
        case generate_vetting_analysis(character_id) do
          {:ok, vetting} ->
            put_in_cache(cache_key, vetting, @vetting_ttl)
            Logger.debug("Warmed vetting analysis cache for #{character_id}")

          {:error, reason} ->
            Logger.warning(
              "Failed to warm vetting analysis cache for #{character_id}: #{inspect(reason)}"
            )
        end

      {:ok, _} ->
        :ok
    end
  end

  defp warm_correlation_analysis(character_id) do
    cache_key = {:correlation_analysis, character_id}

    case get_from_cache(cache_key) do
      :miss ->
        case generate_correlation_analysis(character_id) do
          {:ok, correlation} ->
            put_in_cache(cache_key, correlation, @correlation_ttl)
            Logger.debug("Warmed correlation analysis cache for #{character_id}")

          {:error, reason} ->
            Logger.warning(
              "Failed to warm correlation analysis cache for #{character_id}: #{inspect(reason)}"
            )
        end

      {:ok, _} ->
        :ok
    end
  end

  # Data generation functions (delegate to actual analysis modules)

  defp generate_character_analysis(character_id) do
    EveDmv.Intelligence.CharacterAnalyzer.analyze_character(character_id)
  end

  defp generate_vetting_analysis(character_id) do
    EveDmv.Intelligence.WHVettingAnalyzer.analyze_character(character_id)
  end

  defp generate_correlation_analysis(character_id) do
    EveDmv.Intelligence.CorrelationEngine.analyze_cross_module_correlations(character_id)
  end

  defp calculate_hit_ratio(hits, misses) do
    total = hits + misses

    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end
end
