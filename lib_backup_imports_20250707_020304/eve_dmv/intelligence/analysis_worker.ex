defmodule EveDmv.Intelligence.AnalysisWorker do
  use GenServer

  alias EveDmv.Intelligence.TaskRegistry

  require Logger
  @moduledoc """
  GenServer worker for executing intelligence analysis tasks.

  Each worker handles a single analysis operation with proper error handling,
  timeout management, and telemetry instrumentation.
  """



  @default_timeout 30_000

  def start_link({analyzer_module, entity_id, opts, task_id}) do
    GenServer.start_link(__MODULE__, {analyzer_module, entity_id, opts, task_id}, [])
  end

  @impl GenServer
  def init({analyzer_module, entity_id, opts, task_id}) do
    # Register this worker in the task registry
    Registry.register(TaskRegistry, task_id, %{
      analyzer: analyzer_module,
      entity_id: entity_id,
      started_at: DateTime.utc_now()
    })

    # Start the analysis immediately
    send(self(), :start_analysis)

    state = %{
      analyzer_module: analyzer_module,
      entity_id: entity_id,
      opts: opts,
      task_id: task_id,
      started_at: System.monotonic_time(),
      status: :starting
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:start_analysis, state) do
    %{
      analyzer_module: analyzer_module,
      entity_id: entity_id,
      opts: opts,
      task_id: task_id
    } = state

    Logger.info("Starting analysis task #{task_id}")

    # Update status to running
    new_state = %{state | status: :running}

    # Execute the analysis with timeout
    timeout = Map.get(opts, :timeout, @default_timeout)

    task =
      Task.async(fn ->
        try do
          # All analyzers now implement the Intelligence.Analyzer behavior
          # Use the standardized behavior interface with built-in telemetry
          analyzer_module.analyze_with_telemetry(entity_id, opts)
        rescue
          error ->
            Logger.error("Analysis task #{task_id} failed with error: #{inspect(error)}")
            {:error, error}
        catch
          :exit, reason ->
            Logger.error("Analysis task #{task_id} exited: #{inspect(reason)}")
            {:error, {:exit, reason}}
        end
      end)

    # Wait for completion or timeout
    try do
      result = Task.await(task, timeout)
      send(self(), {:analysis_complete, result})
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task, :brutal_kill)
        send(self(), {:analysis_complete, {:error, :timeout}})
    end

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:analysis_complete, result}, state) do
    %{task_id: task_id, started_at: started_at} = state

    duration_native = System.monotonic_time() - started_at
    duration_ms = System.convert_time_unit(duration_native, :native, :millisecond)

    case result do
      {:ok, analysis_result} ->
        Logger.info("Analysis task #{task_id} completed successfully in #{duration_ms}ms")

        # Analysis telemetry is now handled by the behavior interface
        # Worker-level telemetry for task management
        :telemetry.execute(
          [:eve_dmv, :intelligence, :analysis_worker, :success],
          %{duration_ms: duration_ms},
          %{task_id: task_id, analyzer: state.analyzer_module}
        )

        # Store result in process state briefly before shutdown
        new_state = %{state | status: :completed, result: analysis_result}

        # Schedule shutdown after a brief delayto allow result retrieval
        Process.send_after(self(), :shutdown, 1000)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Analysis task #{task_id} failed after #{duration_ms}ms: #{inspect(reason)}")

        # Analysis telemetry is now handled by the behavior interface
        # Worker-level telemetry for task management
        :telemetry.execute(
          [:eve_dmv, :intelligence, :analysis_worker, :error],
          %{duration_ms: duration_ms},
          %{task_id: task_id, analyzer: state.analyzer_module, error: reason}
        )

        new_state = %{state | status: :failed, error: reason}

        # Schedule shutdown after a brief delay
        Process.send_after(self(), :shutdown, 1000)
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(:shutdown, state) do
    Logger.debug("Shutting down analysis worker for task #{state.task_id}")
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status_info = %{
      status: state.status,
      task_id: state.task_id,
      analyzer: state.analyzer_module,
      entity_id: state.entity_id,
      started_at: state.started_at,
      result: Map.get(state, :result),
      error: Map.get(state, :error)
    }

    {:reply, status_info, state}
  end

  @impl GenServer
  def handle_call(:get_result, _from, state) do
    case state.status do
      :completed ->
        {:reply, {:ok, state.result}, state}

      :failed ->
        {:reply, {:error, state.error}, state}

      status when status in [:starting, :running] ->
        {:reply, {:error, :not_ready}, state}
    end
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.debug(
      "Analysis worker terminating for task #{state.task_id}, reason: #{inspect(reason)}"
    )

    :ok
  end

  # Client API

  @doc """
  Get the current status of an analysis worker.
  """
  def get_status(pid) when is_pid(pid) do
    GenServer.call(pid, :get_status, 5000)
  end

  @doc """
  Get the result of a completed analysis worker.
  """
  def get_result(pid) when is_pid(pid) do
    GenServer.call(pid, :get_result, 5000)
  end
end
