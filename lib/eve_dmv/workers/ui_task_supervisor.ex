defmodule EveDmv.Workers.UITaskSupervisor do
  @moduledoc """
  Task supervisor optimized for UI-triggered operations.

  This supervisor handles short-lived tasks that are triggered by user interactions
  in LiveViews and should complete quickly to maintain good user experience.

  ## Task Categories
  - Character lookups and analysis (< 10 seconds)
  - Price calculations for individual items
  - Real-time data fetches for UI components
  - Simple API calls and ESI requests

  ## Configuration
  - **Max Task Duration**: 30 seconds (with warnings at 10 seconds)
  - **Max Concurrent Tasks**: 20 per user session
  - **Global Concurrent Limit**: 100 tasks
  - **Restart Strategy**: temporary (failed tasks don't restart)
  """

  @behaviour DynamicSupervisor

  use DynamicSupervisor
  require Logger

  # Configuration
  # 30 seconds
  @max_task_duration 30_000
  # 10 seconds
  @warning_duration 10_000
  @max_concurrent_global 100
  @max_concurrent_per_user 20

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    Logger.info("Started UI Task Supervisor")
    DynamicSupervisor.init(strategy: :one_for_one, max_children: @max_concurrent_global)
  end

  @doc """
  Start a UI task with proper timeout and monitoring.

  ## Options
  - `:user_id` - User ID for per-user limits
  - `:timeout` - Custom timeout (max #{@max_task_duration}ms)
  - `:description` - Task description for logging
  """
  def start_task(supervisor \\ __MODULE__, fun, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    timeout = min(Keyword.get(opts, :timeout, @max_task_duration), @max_task_duration)
    description = Keyword.get(opts, :description, "UI Task")

    # Check global and per-user limits
    with :ok <- check_global_limit(supervisor),
         :ok <- check_user_limit(supervisor, user_id) do
      task_spec = %{
        id: make_ref(),
        start: {Task, :start_link, [fn -> run_with_monitoring(fun, description, timeout) end]},
        restart: :temporary,
        type: :worker
      }

      case DynamicSupervisor.start_child(supervisor, task_spec) do
        {:ok, pid} ->
          track_task(pid, user_id, description)
          {:ok, pid}

        {:error, reason} ->
          Logger.warning("Failed to start UI task '#{description}': #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :limit_exceeded} = error ->
        Logger.warning("UI task limit exceeded for '#{description}' (user: #{user_id})")
        error
    end
  end

  @doc """
  Async version that returns immediately.
  """
  def start_task_async(supervisor \\ __MODULE__, fun, opts \\ []) do
    case start_task(supervisor, fun, opts) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Start task and await result with timeout.
  """
  def start_task_await(supervisor \\ __MODULE__, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @max_task_duration)

    case start_task(supervisor, fun, opts) do
      {:ok, pid} ->
        try do
          Task.await(pid, timeout)
        catch
          :exit, {:timeout, _} ->
            Logger.warning("UI task timed out after #{timeout}ms")
            DynamicSupervisor.terminate_child(supervisor, pid)
            {:error, :timeout}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get current task statistics.
  """
  def get_stats(supervisor \\ __MODULE__) do
    children = DynamicSupervisor.which_children(supervisor)
    task_count = length(children)

    user_counts = get_user_task_counts()

    %{
      total_tasks: task_count,
      max_global: @max_concurrent_global,
      max_per_user: @max_concurrent_per_user,
      user_task_counts: user_counts,
      capacity_used: task_count / @max_concurrent_global
    }
  end

  # Private functions

  defp run_with_monitoring(fun, description, timeout) do
    start_time = System.monotonic_time(:millisecond)

    # Set up warning timer
    warning_timer = Process.send_after(self(), :task_warning, @warning_duration)

    # Set up timeout timer
    timeout_timer = Process.send_after(self(), :task_timeout, timeout)

    try do
      result = fun.()

      # Cancel timers
      Process.cancel_timer(warning_timer)
      Process.cancel_timer(timeout_timer)

      # Log completion
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.debug("UI task '#{description}' completed in #{duration}ms")

      # Telemetry
      :telemetry.execute(
        [:eve_dmv, :ui_task, :completed],
        %{duration: duration},
        %{description: description}
      )

      result
    catch
      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error(
          "UI task '#{description}' failed after #{duration}ms: #{kind} #{inspect(reason)}"
        )

        :telemetry.execute(
          [:eve_dmv, :ui_task, :failed],
          %{duration: duration},
          %{description: description, error_kind: kind}
        )

        {:error, {kind, reason}}
    end
  end

  defp check_global_limit(supervisor) do
    current_count = length(DynamicSupervisor.which_children(supervisor))

    if current_count >= @max_concurrent_global do
      {:error, :limit_exceeded}
    else
      :ok
    end
  end

  defp check_user_limit(_supervisor, nil), do: :ok

  defp check_user_limit(_supervisor, user_id) do
    user_task_count = get_user_task_count(user_id)

    if user_task_count >= @max_concurrent_per_user do
      {:error, :limit_exceeded}
    else
      :ok
    end
  end

  defp track_task(pid, user_id, description) do
    if user_id do
      # Store task tracking info
      :ets.insert(
        :ui_task_tracking,
        {pid, user_id, description, System.monotonic_time(:millisecond)}
      )
    end
  end

  defp get_user_task_count(user_id) do
    case :ets.lookup(:ui_task_tracking, user_id) do
      [] -> 0
      tasks -> length(tasks)
    end
  end

  defp get_user_task_counts do
    :ets.foldl(
      fn {_pid, user_id, _desc, _time}, acc ->
        Map.update(acc, user_id, 1, &(&1 + 1))
      end,
      %{},
      :ui_task_tracking
    )
  rescue
    _ -> %{}
  end
end
