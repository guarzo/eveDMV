defmodule EveDmv.Workers.GenericTaskSupervisor do
  @moduledoc """
  A generic task supervisor behavior that eliminates code duplication
  across UI, Background, and Realtime task supervisors.

  This module provides a common supervision pattern with configurable
  policies for timeout, concurrency, and monitoring.
  """

  @doc """
  Defines the configuration for a task supervisor.

  ## Required Configuration
  - `:name` - The supervisor name (atom)
  - `:max_duration` - Maximum task duration in milliseconds
  - `:max_concurrent` - Maximum concurrent tasks
  - `:warning_time` - Warning threshold in milliseconds
  - `:telemetry_prefix` - Telemetry event prefix (list of atoms)

  ## Optional Configuration
  - `:max_per_user` - Maximum tasks per user (for UI supervisors)
  - `:capacity_check` - Function to check capacity limits
  """
  @callback config() :: keyword()

  defmacro __using__(_opts) do
    quote do
      use DynamicSupervisor

      @behaviour EveDmv.Workers.GenericTaskSupervisor

      require Logger

      # ETS table for task tracking (replaces Process dictionary)
      @table_name Module.concat(__MODULE__, :TaskRegistry)

      def start_link(init_arg) do
        DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
      end

      @impl true
      def init(_init_arg) do
        # Initialize ETS table for task tracking
        :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])

        DynamicSupervisor.init(strategy: :one_for_one)
      end

      @doc """
      Starts a task with monitoring and telemetry.
      """
      def start_task(task_fn, options \\ [], metadata \\ %{}) do
        config = config()

        # Check capacity limits
        if exceeds_capacity?(config, metadata) do
          {:error, :capacity_exceeded}
        else
          # Start the task with monitoring
          case DynamicSupervisor.start_child(__MODULE__, {Task, task_fn}) do
            {:ok, pid} ->
              # Register task in ETS instead of Process dictionary
              task_info = %{
                pid: pid,
                started_at: System.monotonic_time(:millisecond),
                metadata: metadata,
                supervisor: __MODULE__
              }

              :ets.insert(@table_name, {pid, task_info})

              # Start monitoring
              monitor_task(pid, config, task_info)

              {:ok, pid}

            {:error, reason} ->
              emit_telemetry(config[:telemetry_prefix], :failed, %{reason: reason}, metadata)
              {:error, reason}
          end
        end
      end

      @doc """
      Gets statistics for all tasks managed by this supervisor.
      """
      def get_stats() do
        config = config()

        tasks = :ets.tab2list(@table_name)
        now = System.monotonic_time(:millisecond)

        running_tasks = Enum.count(tasks)

        task_durations =
          Enum.map(tasks, fn {_pid, task_info} ->
            now - task_info.started_at
          end)

        avg_duration =
          if running_tasks > 0 do
            Enum.sum(task_durations) / running_tasks
          else
            0
          end

        %{
          running_tasks: running_tasks,
          max_concurrent: config[:max_concurrent],
          capacity_utilization: running_tasks / config[:max_concurrent],
          average_duration_ms: avg_duration
        }
      end

      @doc """
      Gets all running tasks with their metadata.
      """
      def get_running_tasks() do
        :ets.tab2list(@table_name)
        |> Enum.map(fn {pid, task_info} ->
          %{
            pid: pid,
            duration_ms: System.monotonic_time(:millisecond) - task_info.started_at,
            metadata: task_info.metadata
          }
        end)
      end

      # Private functions

      defp exceeds_capacity?(config, metadata) do
        current_count = :ets.info(@table_name, :size)

        # Check global capacity
        if current_count >= config[:max_concurrent] do
          true
        else
          # Check per-user capacity if configured
          case config[:max_per_user] do
            nil ->
              false

            max_per_user ->
              user_id = Map.get(metadata, :user_id)

              if user_id do
                user_task_count = count_user_tasks(user_id)
                user_task_count >= max_per_user
              else
                false
              end
          end
        end
      end

      defp count_user_tasks(user_id) do
        :ets.tab2list(@table_name)
        |> Enum.count(fn {_pid, task_info} ->
          Map.get(task_info.metadata, :user_id) == user_id
        end)
      end

      defp monitor_task(pid, config, task_info) do
        # Start monitoring process
        spawn(fn ->
          ref = Process.monitor(pid)

          # Set up warning timer
          if config[:warning_time] do
            Process.send_after(self(), {:warning_timeout, pid}, config[:warning_time])
          end

          # Set up max duration timer
          Process.send_after(self(), {:max_timeout, pid}, config[:max_duration])

          # Wait for completion or timeout
          receive do
            {:DOWN, ^ref, :process, ^pid, reason} ->
              # Task completed
              cleanup_task(pid, reason, config, task_info)

            {:warning_timeout, ^pid} ->
              # Task is taking too long, log warning
              duration = System.monotonic_time(:millisecond) - task_info.started_at

              Logger.warning("Task #{inspect(pid)} exceeding warning time: #{duration}ms",
                supervisor: __MODULE__,
                duration_ms: duration,
                task_metadata: task_info.metadata
              )

              # Continue monitoring
              receive do
                {:DOWN, ^ref, :process, ^pid, reason} ->
                  cleanup_task(pid, reason, config, task_info)

                {:max_timeout, ^pid} ->
                  # Force kill the task
                  Process.exit(pid, :kill)
                  cleanup_task(pid, :timeout, config, task_info)
              end

            {:max_timeout, ^pid} ->
              # Task exceeded max duration, kill it
              Process.exit(pid, :kill)
              cleanup_task(pid, :timeout, config, task_info)
          end
        end)
      end

      defp cleanup_task(pid, reason, config, task_info) do
        # Remove from ETS table
        :ets.delete(@table_name, pid)

        # Calculate final duration
        duration = System.monotonic_time(:millisecond) - task_info.started_at

        # Emit telemetry
        event_suffix = if reason == :normal, do: :completed, else: :failed

        measurements = %{
          duration_ms: duration,
          task_count: :ets.info(@table_name, :size)
        }

        metadata =
          Map.merge(task_info.metadata, %{
            supervisor: __MODULE__,
            exit_reason: reason
          })

        emit_telemetry(config[:telemetry_prefix], event_suffix, measurements, metadata)
      end

      defp emit_telemetry(prefix, event, measurements, metadata) do
        :telemetry.execute(prefix ++ [event], measurements, metadata)
      end
    end
  end
end
