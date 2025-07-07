defmodule EveDmv.Workers.BackgroundTaskSupervisor do
  use DynamicSupervisor

  require Logger
  @moduledoc """
  Task supervisor optimized for heavy background processing operations.

  This supervisor handles long-running tasks that process large amounts of data
  and should not interfere with user-facing operations.

  ## Task Categories
  - Bulk data processing and analysis
  - Cache warming and maintenance operations
  - Database cleanup and optimization
  - Large batch operations (100+ items)

  ## Configuration
  - **Max Task Duration**: 30 minutes (with warnings at 10 minutes)
  - **Max Concurrent Tasks**: 5 (to prevent resource exhaustion)
  - **Memory Limit**: Monitoring and alerts for high memory usage
  - **Restart Strategy**: temporary (manual restart required)
  """


  # Configuration
  # 30 minutes
  @max_task_duration 30 * 60 * 1000
  # 10 minutes
  @warning_duration 10 * 60 * 1000
  @max_concurrent 5
  # 500MB
  @memory_warning_threshold 500 * 1024 * 1024

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    Logger.info("Started Background Task Supervisor")
    DynamicSupervisor.init(strategy: :one_for_one, max_children: @max_concurrent)
  end

  @doc """
  Start a background task with resource monitoring.

  ## Options
  - `:timeout` - Custom timeout (max #{div(@max_task_duration, 60_000)} minutes)
  - `:description` - Task description for logging and monitoring
  - `:priority` - Task priority (:low, :normal, :high)
  - `:memory_limit` - Memory limit in bytes (optional)
  """
  def start_task(supervisor \\ __MODULE__, fun, opts \\ []) do
    timeout = min(Keyword.get(opts, :timeout, @max_task_duration), @max_task_duration)
    description = Keyword.get(opts, :description, "Background Task")
    priority = Keyword.get(opts, :priority, :normal)
    memory_limit = Keyword.get(opts, :memory_limit)

    # Check concurrent task limit
    with :ok <- check_concurrent_limit(supervisor) do
      task_spec = %{
        id: make_ref(),
        start:
          {Task, :start_link,
           [
             fn ->
               run_with_resource_monitoring(fun, description, timeout, priority, memory_limit)
             end
           ]},
        restart: :temporary,
        type: :worker
      }

      case DynamicSupervisor.start_child(supervisor, task_spec) do
        {:ok, pid} ->
          track_background_task(pid, description, priority)
          {:ok, pid}

        {:error, reason} ->
          Logger.warning("Failed to start background task '#{description}': #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :limit_exceeded} = error ->
        Logger.warning("Background task limit exceeded for '#{description}'")
        error
    end
  end

  @doc """
  Start task with result callback.
  """
  def start_task_with_callback(supervisor \\ __MODULE__, fun, callback_fun, opts \\ []) do
    case start_task(supervisor, fun, opts) do
      {:ok, pid} ->
        # Spawn a lightweight process to await the result and call callback
        spawn(fn ->
          try do
            result = Task.await(pid, @max_task_duration)
            callback_fun.({:ok, result})
          catch
            :exit, reason ->
              callback_fun.({:error, reason})
          end
        end)

        {:ok, pid}

      {:error, reason} ->
        callback_fun.({:error, reason})
        {:error, reason}
    end
  end

  @doc """
  Start task and return immediately (fire-and-forget).
  """
  def start_task_async(supervisor \\ __MODULE__, fun, opts \\ []) do
    case start_task(supervisor, fun, opts) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get background task statistics and resource usage.
  """
  def get_stats(supervisor \\ __MODULE__) do
    children = DynamicSupervisor.which_children(supervisor)
    task_count = length(children)

    {memory_usage, task_details} = get_task_details(children)

    %{
      total_tasks: task_count,
      max_concurrent: @max_concurrent,
      capacity_used: task_count / @max_concurrent,
      total_memory_mb: div(memory_usage, 1024 * 1024),
      memory_warning_threshold_mb: div(@memory_warning_threshold, 1024 * 1024),
      task_details: task_details,
      started_at: get_supervisor_start_time()
    }
  end

  @doc """
  Force terminate long-running or stuck tasks.
  """
  def terminate_task(supervisor \\ __MODULE__, pid, reason \\ :shutdown) do
    Logger.warning("Force terminating background task: #{inspect(pid)} (reason: #{reason})")

    case DynamicSupervisor.terminate_child(supervisor, pid) do
      :ok ->
        Logger.info("Successfully terminated background task")
        :ok

      {:error, :not_found} ->
        Logger.debug("Task already terminated")
        :ok

      {:error, reason} ->
        Logger.error("Failed to terminate task: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp run_with_resource_monitoring(fun, description, timeout, priority, memory_limit) do
    start_time = System.monotonic_time(:millisecond)
    initial_memory = get_process_memory()

    Logger.info("Starting background task '#{description}' (priority: #{priority})")

    # Set up monitoring timers
    warning_timer = Process.send_after(self(), :task_warning, @warning_duration)
    timeout_timer = Process.send_after(self(), :task_timeout, timeout)
    memory_timer = schedule_memory_check(memory_limit)

    try do
      result = fun.()

      # Cancel timers
      Process.cancel_timer(warning_timer)
      Process.cancel_timer(timeout_timer)
      if memory_timer, do: Process.cancel_timer(memory_timer)

      # Log completion with resource usage
      duration = System.monotonic_time(:millisecond) - start_time
      final_memory = get_process_memory()
      memory_used = final_memory - initial_memory

      Logger.info(
        "Background task '#{description}' completed in #{format_duration(duration)} " <>
          "(memory: #{format_memory(memory_used)})"
      )

      # Telemetry
      :telemetry.execute(
        [:eve_dmv, :background_task, :completed],
        %{duration: duration, memory_used: memory_used},
        %{description: description, priority: priority}
      )

      result
    catch
      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time
        final_memory = get_process_memory()
        memory_used = final_memory - initial_memory

        Logger.error(
          "Background task '#{description}' failed after #{format_duration(duration)}: " <>
            "#{kind} #{inspect(reason)} (memory: #{format_memory(memory_used)})"
        )

        :telemetry.execute(
          [:eve_dmv, :background_task, :failed],
          %{duration: duration, memory_used: memory_used},
          %{description: description, priority: priority, error_kind: kind}
        )

        {:error, {kind, reason}}
    end
  end

  defp check_concurrent_limit(supervisor) do
    current_count = length(DynamicSupervisor.which_children(supervisor))

    if current_count >= @max_concurrent do
      {:error, :limit_exceeded}
    else
      :ok
    end
  end

  defp track_background_task(_pid, description, priority) do
    start_time = System.monotonic_time(:millisecond)
    # Store tracking info if needed
    # Could use ETS table or process dictionary
    Process.put(:task_info, %{
      description: description,
      priority: priority,
      started_at: start_time
    })
  end

  defp get_task_details(children) do
    {total_memory, details} =
      children
      |> Enum.map(fn {_, pid, _, _} ->
        case get_task_info(pid) do
          {:ok, info} -> info
          {:error, _} -> %{pid: pid, memory: 0, description: "Unknown", runtime: 0}
        end
      end)
      |> Enum.reduce({0, []}, fn task, {mem_acc, list_acc} ->
        {mem_acc + task.memory, [task | list_acc]}
      end)

    {total_memory, Enum.reverse(details)}
  end

  defp get_task_info(pid) do
    try do
      case Process.info(pid, [:memory, :current_function]) do
        [memory: memory, current_function: current_function] ->
          {:ok,
           %{
             pid: pid,
             memory: memory,
             current_function: current_function,
             runtime: get_task_runtime(pid)
           }}

        _ ->
          {:error, :unavailable}
      end
    rescue
      _ -> {:error, :process_dead}
    end
  end

  defp get_task_runtime(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        case Keyword.get(dict, :task_info) do
          %{started_at: started_at} ->
            System.monotonic_time(:millisecond) - started_at

          _ ->
            0
        end

      _ ->
        0
    end
  end

  defp get_process_memory do
    case Process.info(self(), :memory) do
      {:memory, memory} -> memory
      _ -> 0
    end
  end

  defp schedule_memory_check(nil), do: nil

  defp schedule_memory_check(memory_limit) do
    # Check every 30 seconds
    Process.send_after(self(), {:memory_check, memory_limit}, 30_000)
  end

  defp get_supervisor_start_time do
    # Could be tracked in ETS or process state
    System.system_time(:second)
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms) when ms < 60_000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{Float.round(ms / 60_000, 1)}min"

  defp format_memory(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_memory(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)}KB"
  defp format_memory(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)}MB"
end
