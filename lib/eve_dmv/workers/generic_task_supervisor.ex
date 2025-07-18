defmodule EveDmv.Workers.GenericTaskSupervisor do
  @moduledoc """
  Generic task supervisor behavior for managing dynamic task execution.

  Provides a behavior and shared implementation for task supervisors that need:
  - Dynamic child management
  - Capacity limits and per-user limits
  - Telemetry and monitoring
  - Timeout handling

  ## Usage

  defmodule MyTaskSupervisor do
    use EveDmv.Workers.GenericTaskSupervisor

    @impl true
    def config do
      [
        telemetry_prefix: [:my_app, :tasks],
        max_concurrent: 100,
        max_duration: :timer.minutes(5),
        warning_time: :timer.minutes(2)
      ]
    end
  end

  ## Configuration

  Required configuration returned by `config/0` callback:
  - `:telemetry_prefix` - Base telemetry event prefix
  - `:max_concurrent` - Maximum concurrent tasks
  - `:max_duration` - Maximum task duration before termination
  - `:warning_time` - Duration before warning is logged

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
        __MODULE__.TaskRunner.start_task(__MODULE__, @table_name, task_fn, options, metadata)
      end

      @doc """
      Gets statistics for all tasks managed by this supervisor.
      """
      def get_stats() do
        __MODULE__.TaskStats.get_stats(__MODULE__, @table_name)
      end

      @doc """
      Gets all running tasks with their metadata.
      """
      def get_running_tasks() do
        __MODULE__.TaskStats.get_running_tasks(@table_name)
      end

      # Define nested modules for implementation
      defmodule TaskRunner do
        @moduledoc false
        @parent_module __MODULE__ |> Module.split() |> Enum.drop(-1) |> Module.concat()

        def start_task(supervisor, table_name, task_fn, _options, metadata) do
          config = supervisor.config()

          # Check capacity limits
          if exceeds_capacity?(table_name, config, metadata) do
            {:error, :capacity_exceeded}
          else
            # Start the task with monitoring
            case DynamicSupervisor.start_child(supervisor, {Task, task_fn}) do
              {:ok, pid} ->
                register_task(table_name, pid, metadata, supervisor)
                start_monitoring(pid, config, table_name, metadata)
                {:ok, pid}

              {:error, reason} ->
                emit_telemetry(config[:telemetry_prefix], :failed, %{reason: reason}, metadata)
                {:error, reason}
            end
          end
        end

        defp exceeds_capacity?(table_name, config, metadata) do
          current_count = :ets.info(table_name, :size)

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
                  user_task_count = count_user_tasks(table_name, user_id)
                  user_task_count >= max_per_user
                else
                  false
                end
            end
          end
        end

        defp count_user_tasks(table_name, user_id) do
          :ets.tab2list(table_name)
          |> Enum.count(fn {_pid, task_info} ->
            Map.get(task_info.metadata, :user_id) == user_id
          end)
        end

        defp register_task(table_name, pid, metadata, supervisor) do
          task_info = %{
            pid: pid,
            started_at: System.monotonic_time(:millisecond),
            metadata: metadata,
            supervisor: supervisor
          }

          :ets.insert(table_name, {pid, task_info})
        end

        defp start_monitoring(pid, config, table_name, _metadata) do
          spawn(fn ->
            @parent_module.TaskMonitor.monitor_task(pid, config, table_name)
          end)
        end

        defp emit_telemetry(prefix, event, measurements, metadata) do
          :telemetry.execute(prefix ++ [event], measurements, metadata)
        end
      end

      defmodule TaskMonitor do
        @moduledoc false

        def monitor_task(pid, config, table_name) do
          ref = Process.monitor(pid)
          task_info = get_task_info(table_name, pid)

          # Only proceed if we have task info
          if task_info do
            # Set up warning timer
            if config[:warning_time] do
              Process.send_after(self(), {:warning_timeout, pid}, config[:warning_time])
            end

            # Set up max duration timer
            Process.send_after(self(), {:max_timeout, pid}, config[:max_duration])

            # Wait for completion or timeout
            handle_monitoring(ref, pid, config, table_name, task_info)
          else
            # Just monitor for completion if no task info
            receive do
              {:DOWN, ^ref, :process, ^pid, _reason} ->
                :ok
            end
          end
        end

        defp handle_monitoring(ref, pid, config, table_name, task_info) do
          receive do
            {:DOWN, ^ref, :process, ^pid, reason} ->
              # Task completed
              cleanup_task(pid, reason, config, table_name, task_info)

            {:warning_timeout, ^pid} ->
              handle_warning(pid, config, table_name, task_info)
              # Continue monitoring
              receive do
                {:DOWN, ^ref, :process, ^pid, reason} ->
                  cleanup_task(pid, reason, config, table_name, task_info)

                {:max_timeout, ^pid} ->
                  # Force kill the task
                  Process.exit(pid, :kill)
                  cleanup_task(pid, :timeout, config, table_name, task_info)
              end

            {:max_timeout, ^pid} ->
              # Task exceeded max duration, kill it
              Process.exit(pid, :kill)
              cleanup_task(pid, :timeout, config, table_name, task_info)
          end
        end

        defp handle_warning(pid, config, _table_name, task_info) do
          duration = System.monotonic_time(:millisecond) - task_info.started_at

          Logger.warning("Task #{inspect(pid)} exceeding warning time: #{duration}ms",
            supervisor: task_info.supervisor,
            duration_ms: duration,
            task_metadata: task_info.metadata
          )
        end

        defp get_task_info(table_name, pid) do
          case :ets.info(table_name) do
            :undefined ->
              nil

            _ ->
              case :ets.lookup(table_name, pid) do
                [{^pid, info}] -> info
                [] -> nil
              end
          end
        end

        defp cleanup_task(pid, reason, config, table_name, task_info) do
          # Remove from ETS table if it exists
          if :ets.info(table_name) != :undefined do
            :ets.delete(table_name, pid)
          end

          # Only process telemetry if we have task_info
          if task_info do
            # Calculate final duration
            duration = System.monotonic_time(:millisecond) - task_info.started_at

            # Emit telemetry
            event_suffix = if reason == :normal, do: :completed, else: :failed

            table_size =
              if :ets.info(table_name) != :undefined, do: :ets.info(table_name, :size), else: 0

            measurements = %{
              duration_ms: duration,
              task_count: table_size
            }

            metadata =
              Map.merge(task_info.metadata, %{
                supervisor: task_info.supervisor,
                exit_reason: reason
              })

            emit_telemetry(config[:telemetry_prefix], event_suffix, measurements, metadata)
          end
        end

        defp emit_telemetry(prefix, event, measurements, metadata) do
          :telemetry.execute(prefix ++ [event], measurements, metadata)
        end
      end

      defmodule TaskStats do
        @moduledoc false

        def get_stats(supervisor, table_name) do
          config = supervisor.config()

          tasks = :ets.tab2list(table_name)
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

        def get_running_tasks(table_name) do
          :ets.tab2list(table_name)
          |> Enum.map(fn {pid, task_info} ->
            %{
              pid: pid,
              duration_ms: System.monotonic_time(:millisecond) - task_info.started_at,
              metadata: task_info.metadata
            }
          end)
        end
      end
    end
  end
end
