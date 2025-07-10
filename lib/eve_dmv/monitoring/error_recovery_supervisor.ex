defmodule EveDmv.Monitoring.ErrorRecoverySupervisor do
  @moduledoc """
  Supervisor for error monitoring and recovery processes.

  Manages the error tracking, pipeline monitoring, and recovery
  mechanisms to ensure system resilience.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Error tracking service
      {EveDmv.Monitoring.ErrorTracker, []},

      # Pipeline monitoring service
      {EveDmv.Monitoring.PipelineMonitor, []},

      # Error recovery worker
      {EveDmv.Monitoring.ErrorRecoveryWorker, []},

      # Alert dispatcher
      {EveDmv.Monitoring.AlertDispatcher, []},

      # Missing data tracker
      {EveDmv.Monitoring.MissingDataTracker, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
