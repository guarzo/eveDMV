defmodule EveDmv.IntelligenceEngine do
  @moduledoc """
  Unified Intelligence Engine for EVE DMV analysis.

  Consolidates 50+ analyzer modules into a streamlined, plugin-based system
  that provides consistent interfaces, optimized performance, and reduced
  maintenance complexity.

  ## Architecture

  The Intelligence Engine uses a pipeline-based approach with four main analysis domains:

  - **Character Intelligence**: Individual pilot analysis, behavior patterns, threat assessment
  - **Corporation Intelligence**: Corporation-level analysis, member activity, fleet readiness
  - **Fleet Intelligence**: Fleet composition, doctrine compliance, tactical analysis
  - **Threat Intelligence**: Risk assessment, vulnerability analysis, security evaluation

  ## Usage

      # Analyze a character with default scope
      {:ok, result} = IntelligenceEngine.analyze(:character, character_id)
      
      # Analyze with specific plugins
      {:ok, result} = IntelligenceEngine.analyze(:character, character_id, 
                        plugins: [:combat_stats, :behavioral_patterns, :threat_assessment])
      
      # Analyze corporation with options
      {:ok, result} = IntelligenceEngine.analyze(:corporation, corp_id,
                        scope: :full, cache_ttl: 300_000)
      
      # Batch analysis for multiple entities
      {:ok, results} = IntelligenceEngine.batch_analyze(:character, [id1, id2, id3])

  ## Plugin System

  Plugins are self-contained analysis modules that implement the `IntelligencePlugin`
  behavior. Each plugin focuses on a specific aspect of intelligence gathering:

      defmodule MyCustomPlugin do
        use EveDmv.IntelligenceEngine.Plugin
        
        @impl true
        def analyze(entity_id, data, opts) do
          # Plugin-specific analysis logic
          {:ok, %{my_analysis: "result"}}
        end
      end
  """

  use GenServer
  require Logger

  alias EveDmv.IntelligenceEngine.{
    Pipeline,
    PluginRegistry,
    CacheManager,
    MetricsCollector,
    Config
  }

  @type entity_id :: integer()
  @type analysis_domain :: :character | :corporation | :fleet | :threat
  @type analysis_result :: map()
  @type analysis_options :: [
          plugins: [atom()],
          scope: :basic | :standard | :full,
          cache_ttl: integer(),
          timeout: integer(),
          bypass_cache: boolean(),
          parallel: boolean()
        ]

  # Public API

  @doc """
  Analyze an entity using the Intelligence Engine.

  ## Options

  - `:plugins` - Specific plugins to run (default: all for domain)
  - `:scope` - Analysis depth: `:basic`, `:standard`, `:full` (default: `:standard`)
  - `:cache_ttl` - Cache TTL in milliseconds (default: domain-specific)
  - `:timeout` - Analysis timeout in milliseconds (default: 30 seconds)
  - `:bypass_cache` - Skip cache lookup (default: `false`)
  - `:parallel` - Run plugins in parallel (default: `true`)

  ## Examples

      # Basic character analysis
      {:ok, result} = IntelligenceEngine.analyze(:character, 98765)
      
      # Full corporation analysis with custom cache
      {:ok, result} = IntelligenceEngine.analyze(:corporation, 12345, 
                        scope: :full, cache_ttl: 600_000)
      
      # Character analysis with specific plugins
      {:ok, result} = IntelligenceEngine.analyze(:character, 98765,
                        plugins: [:combat_stats, :ship_preferences])
  """
  @spec analyze(analysis_domain(), entity_id(), analysis_options()) ::
          {:ok, analysis_result()} | {:error, term()}
  def analyze(domain, entity_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze, domain, entity_id, opts}, get_timeout(opts))
  end

  @doc """
  Batch analyze multiple entities of the same domain.

  Efficiently processes multiple entities using optimized batch operations
  and parallel processing when appropriate.

  ## Examples

      # Analyze multiple characters
      {:ok, results} = IntelligenceEngine.batch_analyze(:character, [98765, 98766, 98767])
      
      # Returns: %{98765 => %{...}, 98766 => %{...}, 98767 => %{...}}
  """
  @spec batch_analyze(analysis_domain(), [entity_id()], analysis_options()) ::
          {:ok, %{entity_id() => analysis_result()}} | {:error, term()}
  def batch_analyze(domain, entity_ids, opts \\ []) when is_list(entity_ids) do
    GenServer.call(
      __MODULE__,
      {:batch_analyze, domain, entity_ids, opts},
      get_timeout(opts, length(entity_ids))
    )
  end

  @doc """
  Get analysis status and progress for long-running operations.
  """
  @spec get_analysis_status(reference()) :: {:ok, map()} | {:error, :not_found}
  def get_analysis_status(analysis_ref) do
    GenServer.call(__MODULE__, {:get_status, analysis_ref})
  end

  @doc """
  Invalidate cache for a specific entity across all domains.
  """
  @spec invalidate_cache(analysis_domain(), entity_id()) :: :ok
  def invalidate_cache(domain, entity_id) do
    GenServer.cast(__MODULE__, {:invalidate_cache, domain, entity_id})
  end

  @doc """
  Get Intelligence Engine performance metrics and statistics.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Register a new plugin with the Intelligence Engine.

  ## Examples

      IntelligenceEngine.register_plugin(:character, :my_custom_plugin, MyCustomPlugin)
  """
  @spec register_plugin(analysis_domain(), atom(), module()) :: :ok | {:error, term()}
  def register_plugin(domain, plugin_name, plugin_module) do
    GenServer.call(__MODULE__, {:register_plugin, domain, plugin_name, plugin_module})
  end

  @doc """
  List available plugins for a domain.
  """
  @spec list_plugins(analysis_domain()) :: [atom()]
  def list_plugins(domain) do
    GenServer.call(__MODULE__, {:list_plugins, domain})
  end

  # GenServer callbacks

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Intelligence Engine")

    state = %{
      plugin_registry: PluginRegistry.initialize(),
      cache_manager: CacheManager.initialize(),
      metrics_collector: MetricsCollector.initialize(),
      active_analyses: %{},
      config: Config.load()
    }

    # Register default plugins
    register_default_plugins(state.plugin_registry)

    {:ok, state}
  end

  @impl true
  def handle_call({:analyze, domain, entity_id, opts}, from, state) do
    analysis_ref = make_ref()

    # Start analysis asynchronously for better responsiveness
    task =
      Task.async(fn ->
        execute_analysis(domain, entity_id, opts, state)
      end)

    # Track active analysis
    state =
      put_in(state.active_analyses[analysis_ref], %{
        task: task,
        from: from,
        started_at: System.monotonic_time(),
        domain: domain,
        entity_id: entity_id
      })

    {:noreply, state}
  end

  @impl true
  def handle_call({:batch_analyze, domain, entity_ids, opts}, from, state) do
    analysis_ref = make_ref()

    task =
      Task.async(fn ->
        execute_batch_analysis(domain, entity_ids, opts, state)
      end)

    state =
      put_in(state.active_analyses[analysis_ref], %{
        task: task,
        from: from,
        started_at: System.monotonic_time(),
        domain: domain,
        entity_ids: entity_ids
      })

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_status, analysis_ref}, _from, state) do
    case Map.get(state.active_analyses, analysis_ref) do
      nil ->
        {:reply, {:error, :not_found}, state}

      analysis ->
        status = %{
          domain: analysis.domain,
          started_at: analysis.started_at,
          running_time_ms: System.monotonic_time() - analysis.started_at,
          status: if(Task.yield(analysis.task, 0), do: :completed, else: :running)
        }

        {:reply, {:ok, status}, state}
    end
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = MetricsCollector.get_metrics(state.metrics_collector)
    {:reply, metrics, state}
  end

  @impl true
  def handle_call({:register_plugin, domain, plugin_name, plugin_module}, _from, state) do
    case PluginRegistry.register(state.plugin_registry, domain, plugin_name, plugin_module) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_plugins, domain}, _from, state) do
    plugins = PluginRegistry.list_plugins(state.plugin_registry, domain)
    {:reply, plugins, state}
  end

  @impl true
  def handle_cast({:invalidate_cache, domain, entity_id}, state) do
    CacheManager.invalidate(state.cache_manager, domain, entity_id)
    {:noreply, state}
  end

  @impl true
  def handle_info({task_ref, result}, state) when is_reference(task_ref) do
    # Handle completed analysis task
    case find_analysis_by_task_ref(state.active_analyses, task_ref) do
      {analysis_ref, analysis} ->
        GenServer.reply(analysis.from, result)

        # Update metrics
        duration_ms = System.monotonic_time() - analysis.started_at

        MetricsCollector.record_analysis(
          state.metrics_collector,
          analysis.domain,
          duration_ms,
          result
        )

        # Clean up
        state = update_in(state.active_analyses, &Map.delete(&1, analysis_ref))
        {:noreply, state}

      nil ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task monitoring - clean up any dead tasks
    {:noreply, state}
  end

  # Private helper functions

  defp execute_analysis(domain, entity_id, opts, state) do
    try do
      Pipeline.execute(domain, entity_id, opts, state)
    rescue
      exception ->
        Logger.error("Intelligence analysis failed: #{inspect(exception)}")
        {:error, {:analysis_failed, exception}}
    end
  end

  defp execute_batch_analysis(domain, entity_ids, opts, state) do
    try do
      Pipeline.execute_batch(domain, entity_ids, opts, state)
    rescue
      exception ->
        Logger.error("Batch intelligence analysis failed: #{inspect(exception)}")
        {:error, {:batch_analysis_failed, exception}}
    end
  end

  defp register_default_plugins(registry) do
    # Character domain plugins
    PluginRegistry.register(
      registry,
      :character,
      :combat_stats,
      EveDmv.IntelligenceEngine.Plugins.Character.CombatStats
    )

    PluginRegistry.register(
      registry,
      :character,
      :behavioral_patterns,
      EveDmv.IntelligenceEngine.Plugins.Character.BehavioralPatterns
    )

    PluginRegistry.register(
      registry,
      :character,
      :ship_preferences,
      EveDmv.IntelligenceEngine.Plugins.Character.ShipPreferences
    )

    PluginRegistry.register(
      registry,
      :character,
      :threat_assessment,
      EveDmv.IntelligenceEngine.Plugins.Character.ThreatAssessment
    )

    # Corporation domain plugins
    PluginRegistry.register(
      registry,
      :corporation,
      :member_activity,
      EveDmv.IntelligenceEngine.Plugins.Corporation.MemberActivity
    )

    PluginRegistry.register(
      registry,
      :corporation,
      :fleet_readiness,
      EveDmv.IntelligenceEngine.Plugins.Corporation.FleetReadiness
    )

    PluginRegistry.register(
      registry,
      :corporation,
      :doctrine_compliance,
      EveDmv.IntelligenceEngine.Plugins.Corporation.DoctrineCompliance
    )

    # Fleet domain plugins
    PluginRegistry.register(
      registry,
      :fleet,
      :composition_analysis,
      EveDmv.IntelligenceEngine.Plugins.Fleet.CompositionAnalysis
    )

    PluginRegistry.register(
      registry,
      :fleet,
      :effectiveness_rating,
      EveDmv.IntelligenceEngine.Plugins.Fleet.EffectivenessRating
    )

    # Threat domain plugins
    PluginRegistry.register(
      registry,
      :threat,
      :vulnerability_scan,
      EveDmv.IntelligenceEngine.Plugins.Threat.VulnerabilityScan
    )

    PluginRegistry.register(
      registry,
      :threat,
      :risk_assessment,
      EveDmv.IntelligenceEngine.Plugins.Threat.RiskAssessment
    )
  end

  defp find_analysis_by_task_ref(active_analyses, task_ref) do
    Enum.find(active_analyses, fn {_analysis_ref, analysis} ->
      analysis.task.ref == task_ref
    end)
  end

  defp get_timeout(opts, multiplier \\ 1) do
    base_timeout = Keyword.get(opts, :timeout, 30_000)
    base_timeout * multiplier
  end
end
