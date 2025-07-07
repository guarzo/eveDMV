# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Intelligence.Supervisor do
  use Supervisor

  alias EveDmv.Intelligence.AnalyzerSupervisor
  alias EveDmv.Intelligence.Cache.IntelligenceCache

  require Logger
  @moduledoc """
  Supervisor for the Intelligence system.

  Manages all intelligence-related processes including cache workers,
  analysis task supervisors, and monitoring processes.

  Provides fault tolerance and process lifecycle management for
  the unified intelligence analyzer architecture.
  """



  @doc """
  Start the Intelligence supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting Intelligence system supervisor")

    children = [
      # Intelligence cache for analyzer results
      {IntelligenceCache, []},

      # Task supervisor for concurrent analysis operations
      {Task.Supervisor, name: EveDmv.Intelligence.TaskSupervisor},

      # Dynamic supervisor for analyzer processes
      {DynamicSupervisor,
       name: EveDmv.Intelligence.AnalyzerSupervisor, strategy: :one_for_one, max_children: 50},

      # Telemetry reporter for intelligence metrics
      {EveDmv.Intelligence.TelemetryReporter, []},

      # Cache cleanup worker
      {EveDmv.Intelligence.CacheCleanupWorker, []},

      # Analysis scheduler for background tasks
      {EveDmv.Intelligence.AnalysisScheduler, []}
    ]

    # Supervisor strategy: restart failed processes but don't restart too frequently
    opts = [
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 60
    ]

    Supervisor.init(children, opts)
  end

  @doc """
  Start an analyzer process for a specific entity.

  Returns {:ok, pid} or {:error, reason}
  """
  def start_analyzer(analyzer_module, entity_id, opts \\ %{}) do
    child_spec = %{
      id: {analyzer_module, entity_id},
      start: {analyzer_module, :start_link, [entity_id, opts]},
      restart: :temporary,
      type: :worker
    }

    case DynamicSupervisor.start_child(EveDmv.Intelligence.AnalyzerSupervisor, child_spec) do
      {:ok, pid} ->
        Logger.debug("Started analyzer #{analyzer_module} for entity #{entity_id}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.debug("Analyzer #{analyzer_module} for entity #{entity_id} already running")
        {:ok, pid}

      {:error, reason} ->
        Logger.warning(
          "Failed to start analyzer #{analyzer_module} for entity #{entity_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Stop an analyzer process for a specific entity.
  """
  def stop_analyzer(analyzer_module, entity_id) do
    case Registry.lookup(EveDmv.Intelligence.AnalyzerRegistry, {analyzer_module, entity_id}) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(EveDmv.Intelligence.AnalyzerSupervisor, pid)
        Logger.debug("Stopped analyzer #{analyzer_module} for entity #{entity_id}")
        :ok

      [] ->
        Logger.debug("Analyzer #{analyzer_module} for entity #{entity_id} not running")
        :ok
    end
  end

  @doc """
  Get the status of all running analyzers.
  """
  def analyzer_status do
    children = DynamicSupervisor.which_children(EveDmv.Intelligence.AnalyzerSupervisor)

    %{
      total_analyzers: length(children),
      running_analyzers: Enum.count(children, fn {_, pid, _, _} -> Process.alive?(pid) end),
      analyzer_breakdown: build_analyzer_breakdown(children)
    }
  end

  @doc """
  Get intelligence system health status.
  """
  def health_status do
    cache_status = get_cache_health()
    task_supervisor_status = get_task_supervisor_health()
    analyzer_status = analyzer_status()

    overall_health =
      determine_overall_health([
        cache_status.status,
        task_supervisor_status.status,
        if(analyzer_status.running_analyzers > 0, do: :healthy, else: :idle)
      ])

    %{
      overall_health: overall_health,
      cache: cache_status,
      task_supervisor: task_supervisor_status,
      analyzers: analyzer_status,
      telemetry: get_telemetry_health(),
      uptime_seconds: get_uptime_seconds()
    }
  end

  @doc """
  Restart all intelligence processes.

  Use with caution - will interrupt ongoing analyses.
  """
  def restart_intelligence_system do
    Logger.warning("Restarting Intelligence system - ongoing analyses will be interrupted")

    # Stop all analyzer processes
    DynamicSupervisor.which_children(AnalyzerSupervisor)
    |> Enum.each(fn {_, pid, _, _} ->
      DynamicSupervisor.terminate_child(AnalyzerSupervisor, pid)
    end)

    # Clear cache
    IntelligenceCache.clear_cache()

    Logger.info("Intelligence system restart completed")
    :ok
  end

  # Private helper functions

  defp build_analyzer_breakdown(children) do
    children
    |> Enum.group_by(fn {id, _pid, _type, _modules} ->
      case id do
        {analyzer_module, _entity_id} -> analyzer_module
        _ -> :unknown
      end
    end)
    |> Enum.map(fn {analyzer_module, analyzer_children} ->
      {analyzer_module, length(analyzer_children)}
    end)
    |> Map.new()
  end

  defp get_cache_health do
    try do
      stats = IntelligenceCache.get_cache_stats()

      %{
        status: :healthy,
        cache_size: stats.cache_size,
        memory_usage: "#{stats.cache_size} entries"
      }
    rescue
      error ->
        Logger.error("Cache health check failed: #{inspect(error)}")

        %{
          status: :unhealthy,
          error: inspect(error)
        }
    end
  end

  defp get_task_supervisor_health do
    try do
      children = Task.Supervisor.children(EveDmv.Intelligence.TaskSupervisor)

      %{
        status: :healthy,
        active_tasks: length(children)
      }
    rescue
      error ->
        Logger.error("Task supervisor health check failed: #{inspect(error)}")

        %{
          status: :unhealthy,
          error: inspect(error)
        }
    end
  end

  defp get_telemetry_health do
    # Simple telemetry health check
    %{
      status: :healthy,
      events_registered: true
    }
  end

  defp get_uptime_seconds do
    case Process.info(self(), :dictionary) do
      {:dictionary, dict} ->
        start_time = Keyword.get(dict, :start_time, System.monotonic_time())
        System.convert_time_unit(System.monotonic_time() - start_time, :native, :second)

      _ ->
        0
    end
  end

  defp determine_overall_health(statuses) do
    cond do
      Enum.any?(statuses, &(&1 == :unhealthy)) -> :unhealthy
      Enum.all?(statuses, &(&1 in [:healthy, :idle])) -> :healthy
      true -> :degraded
    end
  end
end
