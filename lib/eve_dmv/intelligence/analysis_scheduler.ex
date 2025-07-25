defmodule EveDmv.Intelligence.AnalysisScheduler do
  @moduledoc """
  Background scheduler for intelligence analysis tasks.

  Manages scheduled and periodic analysis tasks including:
  - Cache warming for popular entities
  - Proactive threat analysis updates
  - Corporation activity monitoring
  - Analysis result freshness maintenance
  """

  use GenServer
  alias EveDmv.Intelligence.Analyzers.CorporationAnalyzer
  alias EveDmv.Intelligence.Analyzers.MemberActivityAnalyzer
  alias EveDmv.Intelligence.Analyzers.ThreatAnalyzer
  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer
  alias EveDmv.Intelligence.Analyzers.WHVettingAnalyzer
  alias EveDmv.Intelligence.Core.Config
  require Logger

  # Default schedule check interval: 1 minute
  @schedule_check_interval_ms 60 * 1000

  @doc """
  Start the analysis scheduler.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    check_interval = Keyword.get(opts, :check_interval_ms, @schedule_check_interval_ms)

    Logger.info("Starting Intelligence analysis scheduler (interval: #{check_interval}ms)")

    # Schedule initial check
    Process.send_after(self(), :check_schedule, check_interval)

    state = %{
      check_interval: check_interval,
      scheduled_tasks: %{},
      completed_tasks: 0,
      failed_tasks: 0,
      last_run: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:check_schedule, state) do
    Logger.debug("Checking analysis schedule")

    start_time = System.monotonic_time()

    # Execute scheduled tasks
    execution_results = execute_scheduled_tasks(state.scheduled_tasks)

    duration_ms =
      System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

    # Update state
    updated_state = %{
      state
      | completed_tasks: state.completed_tasks + execution_results.completed,
        failed_tasks: state.failed_tasks + execution_results.failed,
        last_run: DateTime.utc_now()
    }

    # Log execution results
    if execution_results.completed > 0 or execution_results.failed > 0 do
      Logger.debug(
        "Scheduled analysis execution completed in #{duration_ms}ms: #{inspect(execution_results)}"
      )
    end

    # Emit telemetry
    :telemetry.execute(
      [:eve_dmv, :intelligence, :scheduler_run],
      %{
        duration_ms: duration_ms,
        completed: execution_results.completed,
        failed: execution_results.failed
      },
      %{total_completed: updated_state.completed_tasks, total_failed: updated_state.failed_tasks}
    )

    # Schedule next check
    Process.send_after(self(), :check_schedule, state.check_interval)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_call({:schedule_analysis, entity_id, analyzer_type, schedule_opts}, _from, state) do
    task_id = generate_task_id(entity_id, analyzer_type)

    scheduled_task = %{
      id: task_id,
      entity_id: entity_id,
      analyzer_type: analyzer_type,
      scheduled_at: DateTime.utc_now(),
      interval: Map.get(schedule_opts, :interval_minutes, 60),
      last_run: nil,
      enabled: true,
      priority: Map.get(schedule_opts, :priority, :normal)
    }

    updated_tasks = Map.put(state.scheduled_tasks, task_id, scheduled_task)
    updated_state = %{state | scheduled_tasks: updated_tasks}

    Logger.info(
      "Scheduled #{analyzer_type} analysis for entity #{entity_id} (interval: #{scheduled_task.interval}min)"
    )

    {:reply, {:ok, task_id}, updated_state}
  end

  @impl GenServer
  def handle_call({:unschedule_analysis, task_id}, _from, state) do
    case Map.get(state.scheduled_tasks, task_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      task ->
        updated_tasks = Map.delete(state.scheduled_tasks, task_id)
        updated_state = %{state | scheduled_tasks: updated_tasks}

        Logger.info("Unscheduled analysis task #{task_id} for entity #{task.entity_id}")
        {:reply, :ok, updated_state}
    end
  end

  @impl GenServer
  def handle_call(:get_scheduled_tasks, _from, state) do
    task_list =
      state.scheduled_tasks
      |> Map.values()
      |> Enum.sort_by(& &1.scheduled_at, DateTime)

    {:reply, task_list, state}
  end

  @impl GenServer
  def handle_call(:status, _from, state) do
    status = %{
      total_scheduled: map_size(state.scheduled_tasks),
      completed_tasks: state.completed_tasks,
      failed_tasks: state.failed_tasks,
      last_run: state.last_run,
      next_check_in_ms: state.check_interval
    }

    {:reply, status, state}
  end

  @doc """
  Schedule periodic analysis for an entity.

  Options:
  - interval_minutes: How often to run analysis (default: 60)
  - priority: :low, :normal, :high (default: :normal)
  """
  def schedule_analysis(entity_id, analyzer_type, opts \\ %{}) do
    GenServer.call(__MODULE__, {:schedule_analysis, entity_id, analyzer_type, opts})
  end

  @doc """
  Unschedule a previously scheduled analysis task.
  """
  def unschedule_analysis(task_id) do
    GenServer.call(__MODULE__, {:unschedule_analysis, task_id})
  end

  @doc """
  Get list of all scheduled analysis tasks.
  """
  def get_scheduled_tasks do
    GenServer.call(__MODULE__, :get_scheduled_tasks)
  end

  @doc """
  Get scheduler status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # Private functions

  defp execute_scheduled_tasks(scheduled_tasks) do
    now = DateTime.utc_now()

    tasks_to_run =
      scheduled_tasks
      |> Map.values()
      |> Enum.filter(&should_run_task?(&1, now))

    if length(tasks_to_run) > 0 do
      Logger.debug("Executing #{length(tasks_to_run)} scheduled analysis tasks")

      # Execute tasks with concurrency control
      max_concurrent = Config.get_batch_limit(:concurrent_tasks)

      tasks_to_run
      |> Enum.chunk_every(max_concurrent)
      |> Enum.reduce(%{completed: 0, failed: 0}, fn batch, acc ->
        batch_results = execute_task_batch(batch)

        %{
          completed: acc.completed + batch_results.completed,
          failed: acc.failed + batch_results.failed
        }
      end)
    else
      %{completed: 0, failed: 0}
    end
  end

  defp should_run_task?(task, now) do
    task.enabled and
      (is_nil(task.last_run) or
         DateTime.diff(now, task.last_run, :minute) >= task.interval)
  end

  defp execute_task_batch(tasks) do
    stream_results =
      Task.async_stream(
        tasks,
        &execute_single_task/1,
        max_concurrency: length(tasks),
        timeout: Config.get_timeout(:analysis)
      )

    Enum.reduce(stream_results, %{completed: 0, failed: 0}, fn
      {:ok, :ok}, acc -> %{acc | completed: acc.completed + 1}
      {:ok, {:error, _}}, acc -> %{acc | failed: acc.failed + 1}
      {:exit, _}, acc -> %{acc | failed: acc.failed + 1}
    end)
  end

  defp execute_single_task(task) do
    analyzer_module = get_analyzer_module(task.analyzer_type)

    case analyzer_module.analyze(task.entity_id, %{scheduled: true}) do
      {:ok, _result} ->
        Logger.debug(
          "Scheduled #{task.analyzer_type} analysis completed for entity #{task.entity_id}"
        )

        :ok

      {:error, reason} ->
        Logger.warning(
          "Scheduled #{task.analyzer_type} analysis failed for entity #{task.entity_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  rescue
    error ->
      Logger.error(
        "Scheduled analysis task crashed for entity #{task.entity_id}: #{inspect(error)}"
      )

      {:error, error}
  end

  defp get_analyzer_module(analyzer_type) do
    case analyzer_type do
      :threat -> ThreatAnalyzer
      :corporation -> CorporationAnalyzer
      :vetting -> WHVettingAnalyzer
      :member_activity -> MemberActivityAnalyzer
      :wh_fleet -> WhFleetAnalyzer
      _ -> raise "Unknown analyzer type: #{analyzer_type}"
    end
  end

  defp generate_task_id(entity_id, analyzer_type) do
    "#{analyzer_type}_#{entity_id}_#{System.unique_integer([:positive])}"
  end
end
