defmodule EveDmv.Intelligence.AnalysisCache do
  @moduledoc """
  Cachex-based caching layer for intelligence analysis results.

  Provides efficient caching for character analysis, vetting analysis,
  correlation data, and other expensive intelligence computations with
  proper TTL management and cache invalidation strategies.
  """

  require Logger
  require Cachex.Spec
  use GenServer

  alias EveDmv.Config.Cache

  @cache_name :intelligence_analysis_cache

  ## Public API

  @doc """
  Start the analysis cache with Cachex.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get character analysis from cache or compute if missing.
  """
  @spec get_character_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_character_analysis(character_id) do
    cache_key = {:character_analysis, character_id}

    get_or_compute(cache_key, Cache.character_analysis_ttl(), fn ->
      case EveDmv.Intelligence.CharacterAnalyzer.analyze_character(character_id) do
        {:ok, _result} = success -> success
        error -> error
      end
    end)
  end

  @doc """
  Get vetting analysis from cache or compute if missing.
  """
  @spec get_vetting_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_vetting_analysis(character_id) do
    cache_key = {:vetting_analysis, character_id}

    get_or_compute(cache_key, Cache.vetting_analysis_ttl(), fn ->
      case EveDmv.Intelligence.WHVettingAnalyzer.analyze_character(character_id) do
        {:ok, _result} = success -> success
        error -> error
      end
    end)
  end

  @doc """
  Get correlation analysis from cache or compute if missing.
  """
  @spec get_correlation_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_correlation_analysis(character_id) do
    cache_key = {:correlation_analysis, character_id}

    get_or_compute(cache_key, Cache.correlation_analysis_ttl(), fn ->
      EveDmv.Intelligence.CorrelationEngine.analyze_cross_module_correlations(character_id)
    end)
  end

  @doc """
  Get threat analysis from cache or compute if missing.
  """
  @spec get_threat_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_threat_analysis(character_id) do
    cache_key = {:threat_analysis, character_id}

    get_or_compute(cache_key, Cache.threat_analysis_ttl(), fn ->
      case EveDmv.Intelligence.ThreatAnalyzer.analyze_pilot(character_id) do
        {:ok, _result} = success -> success
        error -> error
      end
    end)
  end

  @doc """
  Get member activity analysis from cache or compute if missing.
  """
  @spec get_member_activity_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_member_activity_analysis(character_id) do
    cache_key = {:member_activity, character_id}

    get_or_compute(cache_key, Cache.member_activity_ttl(), fn ->
      # Member activity analysis requires time period, using last 30 days as default
      period_start = DateTime.add(DateTime.utc_now(), -30, :day)
      period_end = DateTime.utc_now()

      case EveDmv.Intelligence.MemberActivityAnalyzer.analyze_member_activity(
             character_id,
             period_start,
             period_end
           ) do
        {:ok, _result} = success -> success
        error -> error
      end
    end)
  end

  @doc """
  Get home defense analysis from cache or compute if missing.
  """
  @spec get_home_defense_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_home_defense_analysis(system_id) do
    cache_key = {:home_defense, system_id}

    get_or_compute(cache_key, Cache.home_defense_ttl(), fn ->
      # Home defense analysis requires corporation context - this is a placeholder
      # In a real scenario, we'd need to determine the corporation from the system
      case EveDmv.Intelligence.HomeDefenseAnalyzer.analyze_home_defense(nil, system_id) do
        {:ok, _result} = success -> success
        error -> error
      end
    end)
  end

  @doc """
  Get bulk character analyses efficiently.
  """
  @spec get_bulk_character_analyses([integer()]) :: %{integer() => any()}
  def get_bulk_character_analyses(character_ids) do
    # Get cached results individually (since Cachex doesn't have get_many)
    {cached_results, missing_ids} =
      Enum.reduce(character_ids, {%{}, []}, fn id, {cached, missing} ->
        case Cachex.get(@cache_name, {:character_analysis, id}) do
          {:ok, nil} -> {cached, [id | missing]}
          {:ok, result} -> {Map.put(cached, id, result), missing}
          {:error, _} -> {cached, [id | missing]}
        end
      end)

    # Compute missing analyses in parallel
    missing_results =
      missing_ids
      |> Task.async_stream(
        fn id ->
          case EveDmv.Intelligence.CharacterAnalyzer.analyze_character(id) do
            {:ok, result} ->
              # Cache the result
              Cachex.put(@cache_name, {:character_analysis, id}, result,
                ttl: Cache.character_analysis_ttl()
              )

              {id, result}

            error ->
              {id, error}
          end
        end,
        max_concurrency: 5,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Map.new()

    Map.merge(cached_results, missing_results)
  end

  @doc """
  Invalidate cache for a specific character across all analysis types.
  """
  @spec invalidate_character_cache(integer()) :: :ok
  def invalidate_character_cache(character_id) do
    keys_to_delete = [
      {:character_analysis, character_id},
      {:vetting_analysis, character_id},
      {:correlation_analysis, character_id},
      {:threat_analysis, character_id},
      {:member_activity, character_id}
    ]

    case Cachex.del(@cache_name, keys_to_delete) do
      {:ok, _count} ->
        Logger.info("Invalidated analysis cache for character #{character_id}")
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to invalidate cache for character #{character_id}: #{inspect(error)}"
        )

        :ok
    end
  end

  @doc """
  Invalidate cache for a specific system.
  """
  @spec invalidate_system_cache(integer()) :: :ok
  def invalidate_system_cache(system_id) do
    case Cachex.del(@cache_name, {:home_defense, system_id}) do
      {:ok, _count} ->
        Logger.info("Invalidated home defense cache for system #{system_id}")
        :ok

      {:error, error} ->
        Logger.error("Failed to invalidate cache for system #{system_id}: #{inspect(error)}")
        :ok
    end
  end

  @doc """
  Warm cache for popular or important characters.
  """
  @spec warm_cache([integer()]) :: :ok
  def warm_cache(character_ids) do
    GenServer.cast(__MODULE__, {:warm_cache, character_ids})
  end

  @doc """
  Get cache statistics and health metrics.
  """
  @spec get_cache_stats() :: map()
  def get_cache_stats do
    case Cachex.stats(@cache_name) do
      {:ok, stats} ->
        case Cachex.size(@cache_name) do
          {:ok, size} ->
            %{
              cache_size: size,
              # Not easily available in Cachex
              memory_bytes: 0,
              hit_count: stats.hit_count || 0,
              miss_count: stats.miss_count || 0,
              eviction_count: stats.eviction_count || 0,
              hit_ratio: calculate_hit_ratio(stats),
              expiration_count: stats.expiration_count || 0
            }

          {:error, _} ->
            get_fallback_stats()
        end

      {:error, _} ->
        get_fallback_stats()
    end
  end

  defp get_fallback_stats do
    %{
      cache_size: 0,
      memory_bytes: 0,
      hit_count: 0,
      miss_count: 0,
      eviction_count: 0,
      hit_ratio: 0.0,
      expiration_count: 0
    }
  end

  @doc """
  Clear all cached analysis data.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    case Cachex.clear(@cache_name) do
      {:ok, _count} ->
        Logger.info("Cleared all analysis cache data")
        :ok

      {:error, error} ->
        Logger.error("Failed to clear analysis cache: #{inspect(error)}")
        :ok
    end
  end

  @doc """
  Update cache entry with new TTL (for extending cache life of popular analyses).
  """
  @spec refresh_cache_ttl(any(), integer()) :: :ok
  def refresh_cache_ttl(cache_key, new_ttl_ms) do
    case Cachex.get(@cache_name, cache_key) do
      {:ok, value} when not is_nil(value) ->
        Cachex.put(@cache_name, cache_key, value, ttl: new_ttl_ms)
        :ok

      _ ->
        :ok
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Start Cachex with comprehensive configuration
    cache_opts = [
      # Limit cache size (number of entries)
      limit: Cache.analysis_cache_size(),

      # TTL policy with periodic cleanup
      expiration: [
        default: Cache.character_analysis_ttl(),
        interval: Cache.analysis_cleanup_interval(),
        lazy: true
      ],

      # Statistics tracking
      stats: true,

      # Pre/post hooks for monitoring
      hooks: [
        Cachex.Spec.hook(
          module: EveDmv.Intelligence.AnalysisCache.TelemetryHook,
          args: []
        )
      ]
    ]

    case Cachex.start_link(@cache_name, cache_opts) do
      {:ok, _pid} ->
        Logger.info("Started intelligence analysis cache with Cachex")

        if Cache.warm_on_startup?() do
          schedule_cache_warming()
        end

        {:ok, %{}}

      {:error, {:already_started, _pid}} ->
        Logger.info("Intelligence analysis cache already started")
        {:ok, %{}}

      {:error, reason} ->
        Logger.error("Failed to start intelligence analysis cache: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:warm_cache, character_ids}, state) do
    Task.start(fn -> perform_cache_warming(character_ids) end)
    {:noreply, state}
  end

  @impl true
  def handle_info(:warm_popular_cache, state) do
    Task.start(fn -> warm_popular_characters() end)
    schedule_cache_warming()
    {:noreply, state}
  end

  ## Private Functions

  defp get_or_compute(cache_key, ttl, compute_fn) do
    case Cachex.get(@cache_name, cache_key) do
      {:ok, nil} ->
        # Cache miss - compute value
        case compute_fn.() do
          {:ok, result} = success ->
            Cachex.put(@cache_name, cache_key, result, ttl: ttl)
            success

          error ->
            error
        end

      {:ok, cached_result} ->
        # Cache hit
        {:ok, cached_result}

      {:error, _reason} ->
        # Cache error - compute without caching
        compute_fn.()
    end
  end

  defp calculate_hit_ratio(stats) do
    hit_count = stats.hit_count || 0
    miss_count = stats.miss_count || 0
    total = hit_count + miss_count

    if total > 0 do
      hit_count / total
    else
      0.0
    end
  end

  defp schedule_cache_warming do
    # Schedule warming every configured interval
    Process.send_after(self(), :warm_popular_cache, EveDmv.Config.Pipeline.warm_cache_interval())
  end

  defp perform_cache_warming(character_ids) do
    Logger.info("Warming analysis cache for #{length(character_ids)} characters")

    character_ids
    |> Enum.chunk_every(10)
    |> Enum.each(fn chunk ->
      Enum.each(chunk, fn character_id ->
        get_character_analysis(character_id)
        get_vetting_analysis(character_id)

        # Small delay to avoid overwhelming the system
        Process.sleep(EveDmv.Config.Pipeline.warm_cache_delay())
      end)
    end)

    Logger.info("Cache warming completed")
  end

  defp warm_popular_characters do
    # Get popular characters from recent activity
    popular_character_ids = get_popular_character_ids()

    if not Enum.empty?(popular_character_ids) do
      perform_cache_warming(popular_character_ids)
    end
  end

  defp get_popular_character_ids do
    # This would typically query the database for characters with recent activity
    # For now, return empty list as placeholder
    []
  end
end

defmodule EveDmv.Intelligence.AnalysisCache.TelemetryHook do
  @moduledoc """
  Telemetry hook for analysis cache operations.
  """

  @behaviour Cachex.Hook

  require Logger

  # Required callbacks
  def actions, do: [:get, :put, :del]
  def async?, do: true
  def timeout, do: 5000
  def type, do: :post

  def handle_notify({:get, cache_key}, _result, state) do
    :telemetry.execute([:intelligence, :cache, :get], %{}, %{key: cache_key})
    {:ok, state}
  end

  def handle_notify({:put, cache_key}, _result, state) do
    :telemetry.execute([:intelligence, :cache, :put], %{}, %{key: cache_key})
    {:ok, state}
  end

  def handle_notify({:del, cache_key}, _result, state) do
    :telemetry.execute([:intelligence, :cache, :del], %{}, %{key: cache_key})
    {:ok, state}
  end

  def handle_notify(_action, _result, state) do
    {:ok, state}
  end
end
