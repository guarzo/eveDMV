defmodule EveDmv.Intelligence.Supervisor do
  @moduledoc """
  Supervisor for intelligence analysis operations.

  Manages analysis jobs using DynamicSupervisor to allow for
  concurrent analysis tasks with proper supervision and fault tolerance.
  """

  use Supervisor

  require Logger

  alias EveDmv.Intelligence.{AnalysisWorker, TaskRegistry}

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Registry for tracking analysis tasks
      {Registry, keys: :unique, name: TaskRegistry},

      # DynamicSupervisor for analysis workers
      {DynamicSupervisor, strategy: :one_for_one, name: EveDmv.Intelligence.AnalysisSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Start a supervised analysis task.

  Returns {:ok, pid} if the task starts successfully, {:error, reason} otherwise.
  """
  def start_analysis_task(analyzer_module, entity_id, opts \\ %{}) do
    task_id = generate_task_id(analyzer_module, entity_id)

    case Registry.lookup(TaskRegistry, task_id) do
      [] ->
        # No existing task, start a new one
        worker_spec = {AnalysisWorker, {analyzer_module, entity_id, opts, task_id}}

        case DynamicSupervisor.start_child(EveDmv.Intelligence.AnalysisSupervisor, worker_spec) do
          {:ok, pid} ->
            Logger.info("Started analysis task #{task_id} with pid #{inspect(pid)}")
            {:ok, pid}

          {:error, reason} = error ->
            Logger.error("Failed to start analysis task #{task_id}: #{inspect(reason)}")
            error
        end

      [{pid, _}] ->
        # Task already running
        Logger.debug("Analysis task #{task_id} already running with pid #{inspect(pid)}")
        {:ok, pid}
    end
  end

  @doc """
  Stop a running analysis task.
  """
  def stop_analysis_task(analyzer_module, entity_id) do
    task_id = generate_task_id(analyzer_module, entity_id)

    case Registry.lookup(TaskRegistry, task_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(EveDmv.Intelligence.AnalysisSupervisor, pid)
        Logger.info("Stopped analysis task #{task_id}")
        :ok

      [] ->
        Logger.debug("No analysis task found for #{task_id}")
        :ok
    end
  end

  @doc """
  List all currently running analysis tasks.
  """
  def list_running_tasks do
    Registry.select(TaskRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Get the status of a specific analysis task.
  """
  def get_task_status(analyzer_module, entity_id) do
    task_id = generate_task_id(analyzer_module, entity_id)

    case Registry.lookup(TaskRegistry, task_id) do
      [{pid, _}] when is_pid(pid) ->
        if Process.alive?(pid) do
          {:running, pid}
        else
          :not_running
        end

      [] ->
        :not_running
    end
  end

  @doc """
  Start multiple analysis tasks concurrently.

  Returns a map of task_id => {:ok, pid} | {:error, reason}
  """
  def start_batch_analysis(tasks) when is_list(tasks) do
    Logger.info("Starting batch analysis for #{length(tasks)} tasks")

    results =
      tasks
      |> Task.async_stream(
        fn {analyzer_module, entity_id, opts} ->
          task_id = generate_task_id(analyzer_module, entity_id)
          result = start_analysis_task(analyzer_module, entity_id, opts)
          {task_id, result}
        end,
        max_concurrency: 10,
        timeout: 5000
      )
      |> Enum.map(fn
        {:ok, {task_id, result}} -> {task_id, result}
        {:exit, reason} -> {:error, reason}
      end)
      |> Map.new()

    successful = Enum.count(results, fn {_, result} -> match?({:ok, _}, result) end)
    failed = length(tasks) - successful

    Logger.info("Batch analysis started: #{successful} successful, #{failed} failed")

    results
  end

  defp generate_task_id(analyzer_module, entity_id) do
    analyzer_name = analyzer_module |> Module.split() |> List.last() |> String.downcase()
    "#{analyzer_name}_#{entity_id}"
  end
end
