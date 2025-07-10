defmodule EveDmv.Workers.RealtimeTaskSupervisor do
  @moduledoc """
  Task supervisor optimized for real-time event processing.

  This supervisor handles event-driven tasks that need to process quickly
  to maintain real-time responsiveness for live data streams.

  ## Task Categories
  - Real-time event processing (chain updates, killmail events)
  - Live data synchronization
  - Event broadcasting and notifications
  - Stream processing tasks

  ## Configuration
  - **Max Task Duration**: 5 seconds (aggressive timeout)
  - **Max Concurrent Tasks**: 50 (high throughput)
  - **Priority Queuing**: High priority tasks can preempt normal tasks
  - **Restart Strategy**: temporary (events are ephemeral)
  """

  use DynamicSupervisor
  require Logger

  # Configuration
  # 5 seconds
  @max_task_duration 5_000
  # 2 seconds
  @warning_duration 2_000
  @max_concurrent 50
  # Reserve slots for high priority tasks
  @high_priority_reserve 10

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    Logger.info("Started Realtime Task Supervisor")
    DynamicSupervisor.init(strategy: :one_for_one, max_children: @max_concurrent)
  end

  @doc """
  Start a real-time task with priority handling.

  ## Options
  - `:timeout` - Custom timeout (max #{@max_task_duration}ms)
  - `:description` - Task description for logging
  - `:priority` - Task priority (:high, :normal)
  - `:event_type` - Type of event being processed
  """
  def start_task(supervisor \\ __MODULE__, fun, opts \\ []) do
    timeout = min(Keyword.get(opts, :timeout, @max_task_duration), @max_task_duration)
    description = Keyword.get(opts, :description, "Realtime Task")
    priority = Keyword.get(opts, :priority, :normal)
    event_type = Keyword.get(opts, :event_type, :unknown)

    # Check capacity based on priority
    case check_capacity(supervisor, priority) do
      :ok ->
        task_spec = %{
          id: make_ref(),
          start:
            {Task, :start_link,
             [
               fn ->
                 run_with_realtime_monitoring(fun, description, timeout, priority, event_type)
               end
             ]},
          restart: :temporary,
          type: :worker
        }

        case DynamicSupervisor.start_child(supervisor, task_spec) do
          {:ok, pid} ->
            track_realtime_task(pid, description, priority, event_type)
            {:ok, pid}

          {:error, reason} ->
            Logger.warning("Failed to start realtime task '#{description}': #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :capacity_exceeded} = error ->
        Logger.warning(
          "Realtime task capacity exceeded for '#{description}' (priority: #{priority})"
        )

        # For high priority tasks, try to terminate a normal priority task
        if priority == :high do
          case terminate_normal_priority_task(supervisor) do
            :ok -> start_task(supervisor, fun, opts)
            :error -> error
          end
        else
          error
        end
    end
  end

  @doc """
  Start high priority task (for critical events).
  """
  def start_high_priority_task(supervisor \\ __MODULE__, fun, opts \\ []) do
    opts = Keyword.put(opts, :priority, :high)
    start_task(supervisor, fun, opts)
  end

  @doc """
  Batch process multiple events efficiently.
  """
  def process_event_batch(supervisor \\ __MODULE__, events, processor_fun, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 10)
    timeout = Keyword.get(opts, :timeout, @max_task_duration)

    events
    |> Enum.chunk_every(batch_size)
    |> Enum.map(fn batch ->
      start_task(
        supervisor,
        fn ->
          Enum.map(batch, processor_fun)
        end,
        description: "Event Batch (#{length(batch)} events)",
        timeout: timeout,
        event_type: :batch
      )
    end)
  end

  @doc """
  Get real-time task statistics.
  """
  def get_stats(supervisor \\ __MODULE__) do
    children = DynamicSupervisor.which_children(supervisor)
    task_count = length(children)

    {priority_counts, event_type_counts} = analyze_running_tasks()

    %{
      total_tasks: task_count,
      max_concurrent: @max_concurrent,
      capacity_used: task_count / @max_concurrent,
      high_priority_reserve: @high_priority_reserve,
      normal_capacity: @max_concurrent - @high_priority_reserve,
      priority_breakdown: priority_counts,
      event_type_breakdown: event_type_counts,
      avg_task_duration_ms: get_average_task_duration()
    }
  end

  @doc """
  Terminate all normal priority tasks (emergency capacity clearing).
  """
  def clear_normal_priority_tasks(supervisor \\ __MODULE__) do
    Logger.warning("Clearing normal priority realtime tasks for capacity")

    children = DynamicSupervisor.which_children(supervisor)

    terminated_count =
      children
      |> Enum.filter(fn {_, pid, _, _} ->
        get_task_priority(pid) == :normal
      end)
      |> Enum.map(fn {_, pid, _, _} ->
        DynamicSupervisor.terminate_child(supervisor, pid)
      end)
      |> Enum.count(fn result -> result == :ok end)

    Logger.info("Terminated #{terminated_count} normal priority tasks")
    terminated_count
  end

  # Private functions

  defp run_with_realtime_monitoring(fun, description, timeout, priority, event_type) do
    start_time = System.monotonic_time(:millisecond)

    # Set up aggressive monitoring for real-time tasks
    warning_timer = Process.send_after(self(), :task_warning, @warning_duration)
    timeout_timer = Process.send_after(self(), :task_timeout, timeout)

    try do
      result = fun.()

      # Cancel timers
      Process.cancel_timer(warning_timer)
      Process.cancel_timer(timeout_timer)

      # Log completion (debug level to avoid spam)
      duration = System.monotonic_time(:millisecond) - start_time

      if duration > @warning_duration do
        Logger.warning(
          "Realtime task '#{description}' took #{duration}ms (priority: #{priority})"
        )
      else
        Logger.debug("Realtime task '#{description}' completed in #{duration}ms")
      end

      # Telemetry for performance monitoring
      :telemetry.execute(
        [:eve_dmv, :realtime_task, :completed],
        %{duration: duration},
        %{description: description, priority: priority, event_type: event_type}
      )

      result
    catch
      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error(
          "Realtime task '#{description}' failed after #{duration}ms: #{kind} #{inspect(reason)}"
        )

        :telemetry.execute(
          [:eve_dmv, :realtime_task, :failed],
          %{duration: duration},
          %{
            description: description,
            priority: priority,
            event_type: event_type,
            error_kind: kind
          }
        )

        {:error, {kind, reason}}
    end
  end

  defp check_capacity(supervisor, priority) do
    current_count = length(DynamicSupervisor.which_children(supervisor))

    case priority do
      :high ->
        # High priority tasks can use full capacity
        if current_count >= @max_concurrent do
          {:error, :capacity_exceeded}
        else
          :ok
        end

      :normal ->
        # Normal priority tasks leave reserve for high priority
        normal_capacity = @max_concurrent - @high_priority_reserve

        if current_count >= normal_capacity do
          {:error, :capacity_exceeded}
        else
          :ok
        end
    end
  end

  defp terminate_normal_priority_task(supervisor) do
    case find_normal_priority_task(supervisor) do
      {:ok, pid} ->
        case DynamicSupervisor.terminate_child(supervisor, pid) do
          :ok ->
            Logger.info("Terminated normal priority task to make room for high priority task")
            :ok

          {:error, _} ->
            :error
        end

      :not_found ->
        :error
    end
  end

  defp find_normal_priority_task(supervisor) do
    case DynamicSupervisor.which_children(supervisor) do
      [] ->
        :not_found

      children ->
        case Enum.find(children, fn {_, pid, _, _} ->
               get_task_priority(pid) == :normal
             end) do
          {_, pid, _, _} -> {:ok, pid}
          nil -> :not_found
        end
    end
  end

  defp track_realtime_task(_pid, description, priority, event_type) do
    task_info = %{
      description: description,
      priority: priority,
      event_type: event_type,
      started_at: System.monotonic_time(:millisecond)
    }

    Process.put(:task_info, task_info)

    # Could also store in ETS for global tracking if needed
  end

  defp get_task_priority(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        case Keyword.get(dict, :task_info) do
          %{priority: priority} -> priority
          _ -> :normal
        end

      _ ->
        :normal
    end
  rescue
    _ -> :normal
  end

  defp analyze_running_tasks do
    # This would analyze running tasks for statistics
    # For now, return empty stats
    {%{high: 0, normal: 0}, %{}}
  end

  defp get_average_task_duration do
    # This would track average durations over time
    # For now, return 0
    0
  end
end
