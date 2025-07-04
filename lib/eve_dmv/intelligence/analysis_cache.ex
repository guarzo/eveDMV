defmodule EveDmv.Intelligence.AnalysisCache do
  @moduledoc """
  Cachex-based caching layer for intelligence analysis results.
  
  Provides efficient caching for character analysis, vetting analysis,
  correlation data, and other expensive intelligence computations with
  proper TTL management and cache invalidation strategies.
  """

  require Logger
  use GenServer

  @cache_name :intelligence_analysis_cache

  # Cache TTLs (in milliseconds)
  @character_analysis_ttl :timer.hours(12)
  @vetting_analysis_ttl :timer.hours(24)
  @correlation_analysis_ttl :timer.hours(4)
  @threat_analysis_ttl :timer.hours(8)
  @member_activity_ttl :timer.hours(6)
  @home_defense_ttl :timer.hours(2)

  # Cache warming configuration
  @warm_cache_on_startup true
  @popular_character_threshold 10

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
    
    get_or_compute(cache_key, @character_analysis_ttl, fn ->
      EveDmv.Intelligence.CharacterAnalyzer.analyze_character(character_id)
    end)
  end

  @doc """
  Get vetting analysis from cache or compute if missing.
  """
  @spec get_vetting_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_vetting_analysis(character_id) do
    cache_key = {:vetting_analysis, character_id}
    
    get_or_compute(cache_key, @vetting_analysis_ttl, fn ->
      EveDmv.Intelligence.WHVettingAnalyzer.analyze_character(character_id)
    end)
  end

  @doc """
  Get correlation analysis from cache or compute if missing.
  """
  @spec get_correlation_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_correlation_analysis(character_id) do
    cache_key = {:correlation_analysis, character_id}
    
    get_or_compute(cache_key, @correlation_analysis_ttl, fn ->
      EveDmv.Intelligence.CorrelationEngine.analyze_cross_module_correlations(character_id)
    end)
  end

  @doc """
  Get threat analysis from cache or compute if missing.
  """
  @spec get_threat_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_threat_analysis(character_id) do
    cache_key = {:threat_analysis, character_id}
    
    get_or_compute(cache_key, @threat_analysis_ttl, fn ->
      EveDmv.Intelligence.ThreatAnalyzer.analyze_character(character_id)
    end)
  end

  @doc """
  Get member activity analysis from cache or compute if missing.
  """
  @spec get_member_activity_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_member_activity_analysis(character_id) do
    cache_key = {:member_activity, character_id}
    
    get_or_compute(cache_key, @member_activity_ttl, fn ->
      EveDmv.Intelligence.MemberActivityAnalyzer.analyze_character(character_id)
    end)
  end

  @doc """
  Get home defense analysis from cache or compute if missing.
  """
  @spec get_home_defense_analysis(integer()) :: {:ok, any()} | {:error, any()}
  def get_home_defense_analysis(system_id) do
    cache_key = {:home_defense, system_id}
    
    get_or_compute(cache_key, @home_defense_ttl, fn ->
      EveDmv.Intelligence.HomeDefenseAnalyzer.analyze_system(system_id)
    end)
  end

  @doc """
  Get bulk character analyses efficiently.
  """
  @spec get_bulk_character_analyses([integer()]) :: %{integer() => any()}
  def get_bulk_character_analyses(character_ids) do
    cache_keys = Enum.map(character_ids, fn id -> {:character_analysis, id} end)
    
    case Cachex.get_many(@cache_name, cache_keys) do
      {:ok, cached_results} ->
        cached_map = Map.new(cached_results, fn {{:character_analysis, id}, result} -> {id, result} end)
        missing_ids = Enum.reject(character_ids, fn id -> Map.has_key?(cached_map, id) end)
        
        # Compute missing analyses in parallel
        missing_results = 
          missing_ids
          |> Task.async_stream(
            fn id -> 
              case EveDmv.Intelligence.CharacterAnalyzer.analyze_character(id) do
                {:ok, result} -> {id, result}
                error -> {id, error}
              end
            end,
            max_concurrency: 5,
            timeout: 30_000
          )
          |> Enum.map(fn {:ok, result} -> result end)
          |> Map.new()

        # Cache the newly computed results
        cache_entries = 
          Enum.map(missing_results, fn {id, result} -> 
            {{:character_analysis, id}, result} 
          end)
        
        if not Enum.empty?(cache_entries) do
          Cachex.put_many(@cache_name, cache_entries, ttl: @character_analysis_ttl)
        end

        Map.merge(cached_map, missing_results)

      {:error, _} ->
        Logger.error("Failed to perform bulk cache lookup")
        %{}
    end
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
        Logger.error("Failed to invalidate cache for character #{character_id}: #{inspect(error)}")
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
        cache_info = Cachex.info(@cache_name)
        
        %{
          cache_size: stats.set_count || 0,
          memory_bytes: cache_info[:memory] || 0,
          hit_count: stats.hit_count || 0,
          miss_count: stats.miss_count || 0,
          eviction_count: stats.eviction_count || 0,
          hit_ratio: calculate_hit_ratio(stats),
          expiration_count: stats.expiration_count || 0
        }
      
      {:error, _} ->
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
      limit: 50_000,
      
      # TTL policy with periodic cleanup
      expiration: [
        default: @character_analysis_ttl,
        interval: :timer.minutes(5),
        lazy: true
      ],
      
      # Statistics tracking
      stats: true,
      
      # Pre/post hooks for monitoring
      hooks: [
        Cachex.Spec.hook(
          module: EveDmv.Intelligence.AnalysisCache.TelemetryHook,
          type: :post,
          options: []
        )
      ]
    ]

    case Cachex.start_link(@cache_name, cache_opts) do
      {:ok, _pid} ->
        Logger.info("Started intelligence analysis cache with Cachex")
        
        if @warm_cache_on_startup do
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
    # Schedule warming every 30 minutes
    Process.send_after(self(), :warm_popular_cache, :timer.minutes(30))
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
        Process.sleep(100)
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

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_notify({:get, cache_key}, _result, state) do
    :telemetry.execute([:intelligence, :cache, :get], %{}, %{key: cache_key})
    {:ok, state}
  end

  @impl true
  def handle_notify({:put, cache_key}, _result, state) do
    :telemetry.execute([:intelligence, :cache, :put], %{}, %{key: cache_key})
    {:ok, state}
  end

  @impl true
  def handle_notify({:del, cache_key}, _result, state) do
    :telemetry.execute([:intelligence, :cache, :del], %{}, %{key: cache_key})
    {:ok, state}
  end

  @impl true
  def handle_notify(_action, _result, state) do
    {:ok, state}
  end
end