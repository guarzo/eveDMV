defmodule EveDmv.Workers.WorkerSupervisor do
  @moduledoc """
  Main supervisor for all background workers in EVE DMV.

  This supervisor manages dedicated workers for different types of background processing,
  replacing the heavy reliance on ad-hoc Task.Supervisor usage with structured,
  purpose-built workers.

  ## Worker Categories

  - **Maintenance Workers**: Cache warming, cleanup, optimization
  - **Analysis Workers**: Intelligence analysis, correlation processing  
  - **Data Workers**: Re-enrichment, price updates, name resolution
  - **Event Workers**: Real-time event processing, surveillance matching
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Maintenance Workers (implemented)
      {EveDmv.Workers.CacheWarmingWorker, []},
      {EveDmv.Workers.ReEnrichmentWorker, []},

      # Analysis Workers (implemented)
      {EveDmv.Workers.AnalysisWorkerPool, [name: :analysis_worker_pool, size: 3]},

      # Specialized Task Supervisors (implemented)
      {EveDmv.Workers.UITaskSupervisor, [name: EveDmv.UITaskSupervisor]},
      {EveDmv.Workers.BackgroundTaskSupervisor, [name: EveDmv.BackgroundTaskSupervisor]},
      {EveDmv.Workers.RealtimeTaskSupervisor, [name: EveDmv.RealtimeTaskSupervisor]}

      # Additional workers can be added as they are implemented:
      # {EveDmv.Workers.DatabaseCleanupWorker, []},
      # {EveDmv.Workers.PerformanceOptimizationWorker, []},
      # {EveDmv.Workers.CorrelationAnalysisWorker, []},
      # {EveDmv.Workers.PriceUpdateWorker, []},
      # {EveDmv.Workers.NameResolutionWorker, []},
      # {EveDmv.Workers.SurveillanceMatchWorker, []},
      # {EveDmv.Workers.ChainEventWorker, []}
    ]

    Logger.info("Starting EVE DMV Worker Supervisor with #{length(children)} workers")

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end

  @doc """
  Get statistics for all managed workers.
  """
  def worker_stats do
    children = Supervisor.which_children(__MODULE__)

    children
    |> Enum.map(fn {id, pid, _type, _modules} ->
      try do
        case GenServer.call(pid, :get_stats, 5000) do
          stats when is_map(stats) -> {id, stats}
          _ -> {id, %{status: :unavailable}}
        end
      rescue
        _ -> {id, %{status: :error}}
      end
    end)
    |> Enum.into(%{})
  end

  @doc """
  Gracefully stop all workers for maintenance.
  """
  def stop_all_workers do
    Logger.info("Stopping all workers for maintenance")

    Supervisor.which_children(__MODULE__)
    |> Enum.each(fn {id, pid, _type, _modules} ->
      try do
        GenServer.call(pid, :stop_gracefully, 30_000)
        Logger.debug("Gracefully stopped worker: #{id}")
      rescue
        error ->
          Logger.warn("Failed to gracefully stop worker #{id}: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Restart all workers after maintenance.
  """
  def restart_all_workers do
    Logger.info("Restarting all workers after maintenance")

    Supervisor.which_children(__MODULE__)
    |> Enum.each(fn {id, pid, _type, _modules} ->
      try do
        Supervisor.restart_child(__MODULE__, id)
        Logger.debug("Restarted worker: #{id}")
      rescue
        error ->
          Logger.warn("Failed to restart worker #{id}: #{inspect(error)}")
      end
    end)
  end
end
