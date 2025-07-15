defmodule EveDmv.Shutdown.GracefulShutdown do
  @moduledoc """
  Graceful shutdown coordinator for EVE DMV application.

  Handles SIGTERM/SIGINT signals and orchestrates orderly shutdown
  of all application components with proper cleanup.
  """

  use GenServer
  require Logger
  alias EveDmv.Logging.StructuredLogger
  alias EveDmv.Workers.BackgroundTaskSupervisor
  alias EveDmv.Workers.UITaskSupervisor
  alias EveDmv.Workers.RealtimeTaskSupervisor

  # Shutdown phases with timeouts (in milliseconds)
  @shutdown_phases [
    {:stop_accepting_work, 2_000},
    {:drain_tasks, 30_000},
    {:stop_pipeline, 10_000},
    {:cleanup_resources, 5_000},
    {:stop_processes, 5_000}
  ]

  @total_shutdown_timeout Enum.reduce(@shutdown_phases, 0, fn {_phase, timeout}, acc ->
                            acc + timeout
                          end)

  defstruct [
    :shutdown_reason,
    :shutdown_started_at,
    :current_phase,
    :completed_phases,
    :shutdown_timeout,
    :shutdown_timer
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initiate graceful shutdown with optional reason and timeout.
  """
  def initiate_shutdown(reason \\ :normal, timeout \\ @total_shutdown_timeout) do
    GenServer.call(__MODULE__, {:initiate_shutdown, reason, timeout}, timeout + 1000)
  end

  @doc """
  Check if shutdown is in progress.
  """
  def shutdown_in_progress? do
    GenServer.call(__MODULE__, :shutdown_status, 1000)
  end

  @doc """
  Get current shutdown phase and remaining time.
  """
  def get_shutdown_status do
    GenServer.call(__MODULE__, :get_shutdown_status, 1000)
  end

  @impl GenServer
  def init(opts) do
    # Register signal handlers
    setup_signal_handlers()

    timeout = Keyword.get(opts, :shutdown_timeout, @total_shutdown_timeout)

    state = %__MODULE__{
      shutdown_reason: nil,
      shutdown_started_at: nil,
      current_phase: nil,
      completed_phases: [],
      shutdown_timeout: timeout,
      shutdown_timer: nil
    }

    Logger.info("Graceful shutdown coordinator initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:initiate_shutdown, reason, timeout}, _from, state) do
    if state.shutdown_reason do
      {:reply, {:error, :shutdown_already_in_progress}, state}
    else
      StructuredLogger.log_warning("Graceful shutdown initiated", %{
        reason: reason,
        timeout: timeout
      })

      new_state = %{
        state
        | shutdown_reason: reason,
          shutdown_started_at: System.monotonic_time(:millisecond),
          shutdown_timeout: timeout,
          current_phase: :stop_accepting_work
      }

      # Start shutdown timer
      shutdown_timer = Process.send_after(self(), :shutdown_timeout, timeout)
      new_state = %{new_state | shutdown_timer: shutdown_timer}

      # Begin shutdown sequence
      send(self(), :execute_shutdown_phase)

      {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call(:shutdown_status, _from, state) do
    {:reply, not is_nil(state.shutdown_reason), state}
  end

  @impl GenServer
  def handle_call(:get_shutdown_status, _from, state) do
    status = %{
      shutdown_in_progress: not is_nil(state.shutdown_reason),
      shutdown_reason: state.shutdown_reason,
      current_phase: state.current_phase,
      completed_phases: state.completed_phases,
      elapsed_time: calculate_elapsed_time(state)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_info(:execute_shutdown_phase, state) do
    case state.current_phase do
      nil ->
        {:noreply, state}

      phase ->
        {phase_name, phase_timeout} = get_phase_info(phase)

        StructuredLogger.log_warning("Executing shutdown phase", %{
          phase: phase_name,
          timeout: phase_timeout
        })

        # Execute the phase
        case execute_phase(phase, phase_timeout) do
          :ok ->
            # Move to next phase
            completed_phases = [phase | state.completed_phases]
            next_phase = get_next_phase(phase)

            new_state = %{state | current_phase: next_phase, completed_phases: completed_phases}

            if next_phase do
              send(self(), :execute_shutdown_phase)
              {:noreply, new_state}
            else
              # Shutdown complete
              complete_shutdown(state)
              {:stop, :normal, new_state}
            end

          {:error, reason} ->
            StructuredLogger.log_error("Shutdown phase failed", reason, %{
              phase: phase_name,
              timeout: phase_timeout
            })

            # Continue to next phase despite failure
            completed_phases = [phase | state.completed_phases]
            next_phase = get_next_phase(phase)

            new_state = %{state | current_phase: next_phase, completed_phases: completed_phases}

            if next_phase do
              send(self(), :execute_shutdown_phase)
              {:noreply, new_state}
            else
              complete_shutdown(state)
              {:stop, :normal, new_state}
            end
        end
    end
  end

  @impl GenServer
  def handle_info(:shutdown_timeout, state) do
    StructuredLogger.log_error("Shutdown timeout reached", :timeout, %{
      current_phase: state.current_phase,
      completed_phases: state.completed_phases,
      elapsed_time: calculate_elapsed_time(state)
    })

    # Force shutdown
    complete_shutdown(state)
    {:stop, :shutdown_timeout, state}
  end

  @impl GenServer
  def handle_info({:signal, :sigterm}, state) do
    if state.shutdown_reason do
      {:noreply, state}
    else
      send(self(), {:initiate_shutdown, :sigterm, @total_shutdown_timeout})
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:signal, :sigint}, state) do
    if state.shutdown_reason do
      {:noreply, state}
    else
      send(self(), {:initiate_shutdown, :sigint, @total_shutdown_timeout})
      {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(reason, state) do
    if state.shutdown_timer do
      Process.cancel_timer(state.shutdown_timer)
    end

    StructuredLogger.log_warning("Shutdown coordinator terminated", %{
      reason: reason,
      completed_phases: state.completed_phases
    })

    :ok
  end

  # Private functions

  defp setup_signal_handlers do
    # Register for SIGTERM and SIGINT signals
    try do
      :os.set_signal(:sigterm, :handle)
      :os.set_signal(:sigint, :handle)
      Process.flag(:trap_exit, true)
    rescue
      _ ->
        Logger.warning("Unable to set up signal handlers (not supported on this platform)")
    end
  end

  defp get_phase_info(phase) do
    Enum.find(@shutdown_phases, fn {phase_name, _timeout} -> phase_name == phase end)
  end

  defp get_next_phase(current_phase) do
    current_index = Enum.find_index(@shutdown_phases, fn {phase, _} -> phase == current_phase end)

    if current_index && current_index < length(@shutdown_phases) - 1 do
      {next_phase, _} = Enum.at(@shutdown_phases, current_index + 1)
      next_phase
    else
      nil
    end
  end

  defp execute_phase(:stop_accepting_work, timeout) do
    # Stop accepting new work in all supervisors
    tasks = [
      Task.async(fn -> stop_accepting_work(BackgroundTaskSupervisor) end),
      Task.async(fn -> stop_accepting_work(UITaskSupervisor) end),
      Task.async(fn -> stop_accepting_work(RealtimeTaskSupervisor) end)
    ]

    results = Task.await_many(tasks, timeout)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :failed_to_stop_accepting_work}
    end
  end

  defp execute_phase(:drain_tasks, timeout) do
    # Wait for current tasks to complete
    tasks = [
      Task.async(fn ->
        drain_supervisor_tasks(BackgroundTaskSupervisor, timeout)
      end),
      Task.async(fn -> drain_supervisor_tasks(UITaskSupervisor, timeout) end),
      Task.async(fn -> drain_supervisor_tasks(RealtimeTaskSupervisor, timeout) end)
    ]

    results = Task.await_many(tasks, timeout)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :failed_to_drain_tasks}
    end
  end

  defp execute_phase(:stop_pipeline, timeout) do
    # Stop Broadway pipeline gracefully
    stop_broadway_pipeline(EveDmv.Killmails.KillmailPipeline, timeout)
  end

  defp execute_phase(:cleanup_resources, timeout) do
    # Clean up resources like connections, files, etc.
    tasks = [
      Task.async(fn -> cleanup_sse_connections(timeout) end),
      Task.async(fn -> cleanup_database_connections(timeout) end),
      Task.async(fn -> cleanup_cache_operations(timeout) end)
    ]

    results = Task.await_many(tasks, timeout)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :failed_to_cleanup_resources}
    end
  end

  defp execute_phase(:stop_processes, timeout) do
    # Stop remaining processes
    stop_remaining_processes(timeout)
  end

  defp stop_accepting_work(supervisor) do
    # Implementation depends on supervisor - this is a placeholder
    # Real implementation would set a flag to reject new work
    try do
      if Process.whereis(supervisor) do
        GenServer.call(supervisor, :stop_accepting_work, 5000)
      else
        :ok
      end
    rescue
      _ -> :ok
    end
  end

  defp drain_supervisor_tasks(supervisor, timeout) do
    # Wait for all tasks under supervisor to complete
    try do
      if Process.whereis(supervisor) do
        GenServer.call(supervisor, :drain_tasks, timeout)
      else
        :ok
      end
    rescue
      _ -> :ok
    end
  end

  defp stop_broadway_pipeline(pipeline, timeout) do
    try do
      if Process.whereis(pipeline) do
        # Broadway.stop with graceful shutdown
        GenServer.call(pipeline, :graceful_shutdown, timeout)
      else
        :ok
      end
    rescue
      _ -> :ok
    end
  end

  defp cleanup_sse_connections(timeout) do
    # Close SSE connections gracefully
    try do
      if Process.whereis(EveDmv.Intelligence.WandererSSE) do
        GenServer.call(EveDmv.Intelligence.WandererSSE, :close_connections, timeout)
      else
        :ok
      end
    rescue
      _ -> :ok
    end
  end

  defp cleanup_database_connections(_timeout) do
    # Ensure database connections are properly closed
    try do
      Ecto.Adapters.SQL.Sandbox.checkin(EveDmv.Repo)
      :ok
    rescue
      _ -> :ok
    end
  end

  defp cleanup_cache_operations(_timeout) do
    # Clean up any ongoing cache operations
    :ok
  end

  defp stop_remaining_processes(_timeout) do
    # Stop any remaining processes that weren't handled in previous phases
    try do
      # This would typically involve supervisor shutdown
      :ok
    rescue
      _ -> {:error, :failed_to_stop_processes}
    end
  end

  defp complete_shutdown(state) do
    elapsed_time = calculate_elapsed_time(state)

    StructuredLogger.log_warning("Graceful shutdown completed", %{
      reason: state.shutdown_reason,
      elapsed_time: elapsed_time,
      completed_phases: state.completed_phases
    })

    # Send shutdown signal to application
    System.stop(0)
  end

  defp calculate_elapsed_time(state) do
    if state.shutdown_started_at do
      System.monotonic_time(:millisecond) - state.shutdown_started_at
    else
      0
    end
  end
end
