defmodule EveDmv.Workers.AnalysisWorkerPool do
  use GenServer

  alias EveDmv.Cache

  require Logger
  @moduledoc """
  Worker pool for intelligence analysis tasks.

  This module provides a pool of workers that can handle character analysis,
  correlation analysis, and other intelligence processing tasks in parallel
  while maintaining resource limits and proper error handling.

  ## Features
  - **Dynamic pool sizing**: Adjusts worker count based on demand
  - **Job queuing**: Queues analysis requests when all workers are busy
  - **Priority handling**: High priority analysis can preempt normal jobs
  - **Result caching**: Integrates with the unified cache system
  - **Telemetry**: Comprehensive metrics for analysis performance
  """



  # Configuration
  @default_pool_size 3
  @max_pool_size 8
  @min_pool_size 1
  @queue_size_limit 100
  # 5 minutes
  @job_timeout 5 * 60 * 1000
  # 30 seconds
  @scaling_check_interval 30_000

  defmodule Job do
    @moduledoc false
    defstruct [
      :id,
      :type,
      :subject_id,
      :analysis_fun,
      :priority,
      :requested_at,
      :requester_pid,
      :timeout,
      :cache_key
    ]
  end

  defmodule Worker do
    @moduledoc false
    defstruct [
      :pid,
      :ref,
      # :idle, :busy
      :status,
      :current_job,
      :started_at
    ]
  end

  defmodule State do
    @moduledoc false
    defstruct [
      :pool_size,
      :workers,
      :job_queue,
      :job_counter,
      :stats,
      :scaling_timer
    ]
  end

  ## Public API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    pool_size = Keyword.get(opts, :size, @default_pool_size)
    GenServer.start_link(__MODULE__, [pool_size: pool_size], name: name)
  end

  @doc """
  Submit an analysis job to the worker pool.

  ## Options
  - `:priority` - Job priority (:high, :normal, :low)
  - `:timeout` - Custom timeout in milliseconds
  - `:cache_key` - Cache key for result storage
  """
  def analyze(server \\ __MODULE__, analysis_type, subject_id, analysis_fun, opts \\ []) do
    priority = Keyword.get(opts, :priority, :normal)
    timeout = Keyword.get(opts, :timeout, @job_timeout)
    cache_key = Keyword.get(opts, :cache_key)

    # Check cache first if cache_key provided
    if cache_key do
      case Cache.get(:analysis, cache_key) do
        {:ok, cached_result} ->
          Logger.debug("Analysis cache hit for #{analysis_type}:#{subject_id}")
          {:ok, cached_result}

        :miss ->
          submit_job(
            server,
            analysis_type,
            subject_id,
            analysis_fun,
            priority,
            timeout,
            cache_key
          )
      end
    else
      submit_job(server, analysis_type, subject_id, analysis_fun, priority, timeout, nil)
    end
  end

  @doc """
  Submit an analysis job asynchronously (fire-and-forget).
  """
  def analyze_async(server \\ __MODULE__, analysis_type, subject_id, analysis_fun, opts \\ []) do
    GenServer.cast(server, {:analyze_async, analysis_type, subject_id, analysis_fun, opts})
  end

  @doc """
  Get worker pool statistics.
  """
  def get_stats(server \\ __MODULE__) do
    GenServer.call(server, :get_stats, 5000)
  end

  @doc """
  Manually scale the worker pool.
  """
  def scale_pool(server \\ __MODULE__, target_size)
      when target_size >= @min_pool_size and target_size <= @max_pool_size do
    GenServer.call(server, {:scale_pool, target_size}, 10_000)
  end

  @doc """
  Clear the job queue (emergency reset).
  """
  def clear_queue(server \\ __MODULE__) do
    GenServer.call(server, :clear_queue)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    Logger.info("Starting Analysis Worker Pool with #{pool_size} workers")

    state = %State{
      pool_size: pool_size,
      workers: %{},
      job_queue: :queue.new(),
      job_counter: 0,
      stats: init_stats(),
      scaling_timer: nil
    }

    # Start initial workers
    {:ok, state_with_workers} = start_workers(state, pool_size)

    # Schedule periodic scaling check
    scaling_timer = Process.send_after(self(), :check_scaling, @scaling_check_interval)
    final_state = %{state_with_workers | scaling_timer: scaling_timer}

    {:ok, final_state}
  end

  @impl GenServer
  def handle_call(
        {:analyze, analysis_type, subject_id, analysis_fun, priority, timeout, cache_key},
        from,
        state
      ) do
    job =
      create_job(
        analysis_type,
        subject_id,
        analysis_fun,
        priority,
        timeout,
        from,
        cache_key,
        state
      )

    case assign_job_to_worker(job, state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:queue, new_state} ->
        if :queue.len(new_state.job_queue) >= @queue_size_limit do
          {:reply, {:error, :queue_full}, new_state}
        else
          queued_state = queue_job(job, new_state)
          {:noreply, queued_state}
        end
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = calculate_current_stats(state)
    {:reply, stats, %{state | stats: stats}}
  end

  @impl GenServer
  def handle_call({:scale_pool, target_size}, _from, state) do
    case scale_workers(state, target_size) do
      {:ok, new_state} ->
        Logger.info(
          "Scaled analysis worker pool from #{state.pool_size} to #{target_size} workers"
        )

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:clear_queue, _from, state) do
    queue_size = :queue.len(state.job_queue)
    Logger.warning("Clearing analysis job queue (#{queue_size} jobs discarded)")

    new_state = %{state | job_queue: :queue.new()}
    {:reply, {:ok, queue_size}, new_state}
  end

  @impl GenServer
  def handle_cast({:analyze_async, analysis_type, subject_id, analysis_fun, opts}, state) do
    priority = Keyword.get(opts, :priority, :normal)
    timeout = Keyword.get(opts, :timeout, @job_timeout)
    cache_key = Keyword.get(opts, :cache_key)

    job =
      create_job(
        analysis_type,
        subject_id,
        analysis_fun,
        priority,
        timeout,
        nil,
        cache_key,
        state
      )

    case assign_job_to_worker(job, state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:queue, new_state} ->
        if :queue.len(new_state.job_queue) < @queue_size_limit do
          queued_state = queue_job(job, new_state)
          {:noreply, queued_state}
        else
          Logger.warning(
            "Analysis job queue full, dropping async job #{job.type}:#{job.subject_id}"
          )

          {:noreply, new_state}
        end
    end
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case find_worker_by_ref(state.workers, ref) do
      {worker_id, worker} ->
        Logger.warning("Analysis worker #{worker_id} died: #{inspect(reason)}")

        # Handle the worker's current job if any
        new_state = handle_worker_death(worker, reason, state)

        # Remove the dead worker and start a replacement
        workers_without_dead = Map.delete(new_state.workers, worker_id)
        {:ok, replacement_state} = start_workers(%{new_state | workers: workers_without_dead}, 1)

        {:noreply, replacement_state}

      nil ->
        Logger.debug("Received DOWN message for unknown worker")
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:job_result, worker_id, job_id, result}, state) do
    case Map.get(state.workers, worker_id) do
      %Worker{current_job: %Job{id: ^job_id} = job} = worker ->
        # Mark worker as idle
        updated_worker = %{worker | status: :idle, current_job: nil}
        updated_workers = Map.put(state.workers, worker_id, updated_worker)

        # Handle the result
        new_state = handle_job_result(job, result, %{state | workers: updated_workers})

        # Try to assign next job from queue
        final_state = try_assign_queued_job(worker_id, new_state)

        {:noreply, final_state}

      _ ->
        Logger.warning("Received job result for unknown worker/job: #{worker_id}/#{job_id}")
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:check_scaling, state) do
    new_state = check_and_scale(state)

    # Schedule next scaling check
    scaling_timer = Process.send_after(self(), :check_scaling, @scaling_check_interval)
    final_state = %{new_state | scaling_timer: scaling_timer}

    {:noreply, final_state}
  end

  # Private functions

  defp submit_job(server, analysis_type, subject_id, analysis_fun, priority, timeout, cache_key) do
    GenServer.call(
      server,
      {:analyze, analysis_type, subject_id, analysis_fun, priority, timeout, cache_key},
      timeout + 5000
    )
  end

  defp create_job(
         analysis_type,
         subject_id,
         analysis_fun,
         priority,
         timeout,
         requester_pid,
         cache_key,
         state
       ) do
    %Job{
      id: state.job_counter + 1,
      type: analysis_type,
      subject_id: subject_id,
      analysis_fun: analysis_fun,
      priority: priority,
      requested_at: System.monotonic_time(:millisecond),
      requester_pid: requester_pid,
      timeout: timeout,
      cache_key: cache_key
    }
  end

  defp start_workers(state, count) do
    {new_workers, _} =
      Enum.reduce(1..count, {state.workers, map_size(state.workers)}, fn _,
                                                                         {workers_acc, id_counter} ->
        worker_id = id_counter + 1
        {:ok, pid} = start_worker(worker_id)
        ref = Process.monitor(pid)

        worker = %Worker{
          pid: pid,
          ref: ref,
          status: :idle,
          current_job: nil,
          started_at: System.monotonic_time(:millisecond)
        }

        {Map.put(workers_acc, worker_id, worker), id_counter + 1}
      end)

    {:ok, %{state | workers: new_workers, pool_size: map_size(new_workers)}}
  end

  defp start_worker(worker_id) do
    Task.start_link(fn ->
      worker_loop(worker_id, self())
    end)
  end

  defp worker_loop(worker_id, pool_pid) do
    receive do
      {:execute_job, job} ->
        result = execute_analysis_job(job)
        send(pool_pid, {:job_result, worker_id, job.id, result})
        worker_loop(worker_id, pool_pid)

      :shutdown ->
        Logger.debug("Analysis worker #{worker_id} shutting down")
        :ok
    end
  end

  defp execute_analysis_job(%Job{} = job) do
    Logger.debug(
      "Starting analysis job #{job.type}:#{job.subject_id} (priority: #{job.priority})"
    )

    start_time = System.monotonic_time(:millisecond)

    try do
      result = job.analysis_fun.()
      duration = System.monotonic_time(:millisecond) - start_time

      Logger.debug("Completed analysis job #{job.type}:#{job.subject_id} in #{duration}ms")

      :telemetry.execute(
        [:eve_dmv, :analysis_worker, :job_completed],
        %{duration: duration},
        %{type: job.type, priority: job.priority}
      )

      {:ok, result}
    catch
      kind, reason ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error(
          "Analysis job #{job.type}:#{job.subject_id} failed after #{duration}ms: #{kind} #{inspect(reason)}"
        )

        :telemetry.execute(
          [:eve_dmv, :analysis_worker, :job_failed],
          %{duration: duration},
          %{type: job.type, priority: job.priority, error_kind: kind}
        )

        {:error, {kind, reason}}
    end
  end

  defp assign_job_to_worker(%Job{} = job, state) do
    case find_idle_worker(state.workers) do
      {worker_id, worker} ->
        # Assign job to worker
        updated_worker = %{worker | status: :busy, current_job: job}
        updated_workers = Map.put(state.workers, worker_id, updated_worker)

        # Send job to worker
        send(worker.pid, {:execute_job, job})

        {:ok, %{state | workers: updated_workers, job_counter: job.id}}

      nil ->
        {:queue, state}
    end
  end

  defp find_idle_worker(workers) do
    Enum.find(workers, fn {_id, worker} -> worker.status == :idle end)
  end

  defp queue_job(job, state) do
    # Insert based on priority
    new_queue =
      case job.priority do
        # Front of queue
        :high -> :queue.in_r(job, state.job_queue)
        # Back of queue
        _ -> :queue.in(job, state.job_queue)
      end

    %{state | job_queue: new_queue, job_counter: job.id}
  end

  defp try_assign_queued_job(worker_id, state) do
    case :queue.out(state.job_queue) do
      {{:value, job}, new_queue} ->
        worker = Map.get(state.workers, worker_id)
        updated_worker = %{worker | status: :busy, current_job: job}
        updated_workers = Map.put(state.workers, worker_id, updated_worker)

        send(worker.pid, {:execute_job, job})

        %{state | workers: updated_workers, job_queue: new_queue}

      {:empty, _} ->
        state
    end
  end

  defp handle_job_result(%Job{requester_pid: nil}, _result, state) do
    # Async job, no response needed
    state
  end

  defp handle_job_result(%Job{requester_pid: requester_pid} = job, result, state) do
    # Send result back to requester
    GenServer.reply(requester_pid, result)

    # Cache result if cache_key provided
    case {result, job} do
      {{:ok, data}, %Job{cache_key: cache_key}} when cache_key != nil ->
        Cache.put(:analysis, cache_key, data)

      _ ->
        :ok
    end

    state
  end

  defp handle_worker_death(%Worker{current_job: nil}, _reason, state), do: state

  defp handle_worker_death(%Worker{current_job: job}, reason, state) do
    Logger.error(
      "Lost analysis job #{job.type}:#{job.subject_id} due to worker death: #{inspect(reason)}"
    )

    # If job had a requester, send error response
    if job.requester_pid do
      GenServer.reply(job.requester_pid, {:error, :worker_died})
    end

    state
  end

  defp find_worker_by_ref(workers, ref) do
    Enum.find(workers, fn {_id, worker} -> worker.ref == ref end)
  end

  defp scale_workers(state, target_size) when target_size > state.pool_size do
    additional_workers = target_size - state.pool_size
    start_workers(state, additional_workers)
  end

  defp scale_workers(state, target_size) when target_size < state.pool_size do
    workers_to_remove = state.pool_size - target_size
    remove_workers(state, workers_to_remove)
  end

  defp scale_workers(state, _target_size), do: {:ok, state}

  defp remove_workers(state, count) do
    # Remove idle workers first
    {idle_workers, busy_workers} =
      Enum.split_with(state.workers, fn {_id, worker} -> worker.status == :idle end)

    {to_remove, to_keep} = Enum.split(idle_workers, count)

    # Shutdown workers to remove
    Enum.each(to_remove, fn {_id, worker} ->
      send(worker.pid, :shutdown)
    end)

    remaining_workers = Enum.into(to_keep ++ busy_workers, %{})

    {:ok, %{state | workers: remaining_workers, pool_size: map_size(remaining_workers)}}
  end

  defp check_and_scale(state) do
    queue_length = :queue.len(state.job_queue)
    idle_workers = count_idle_workers(state.workers)
    _busy_workers = state.pool_size - idle_workers

    cond do
      # Scale up if queue is building and we're not at max capacity
      queue_length > 2 and state.pool_size < @max_pool_size ->
        target_size = min(@max_pool_size, state.pool_size + 1)

        case scale_workers(state, target_size) do
          {:ok, new_state} ->
            Logger.info(
              "Auto-scaled analysis worker pool up to #{target_size} workers (queue: #{queue_length})"
            )

            new_state

          {:error, _} ->
            state
        end

      # Scale down if too many idle workers and above minimum
      idle_workers > 2 and state.pool_size > @min_pool_size ->
        target_size = max(@min_pool_size, state.pool_size - 1)

        case scale_workers(state, target_size) do
          {:ok, new_state} ->
            Logger.info(
              "Auto-scaled analysis worker pool down to #{target_size} workers (idle: #{idle_workers})"
            )

            new_state

          {:error, _} ->
            state
        end

      true ->
        state
    end
  end

  defp count_idle_workers(workers) do
    Enum.count(workers, fn {_id, worker} -> worker.status == :idle end)
  end

  defp calculate_current_stats(state) do
    queue_length = :queue.len(state.job_queue)
    idle_workers = count_idle_workers(state.workers)
    busy_workers = state.pool_size - idle_workers

    %{
      pool_size: state.pool_size,
      idle_workers: idle_workers,
      busy_workers: busy_workers,
      queue_length: queue_length,
      total_jobs_processed: state.job_counter,
      capacity_utilization: busy_workers / state.pool_size
    }
  end

  defp init_stats do
    %{
      pool_size: 0,
      idle_workers: 0,
      busy_workers: 0,
      queue_length: 0,
      total_jobs_processed: 0,
      capacity_utilization: 0.0
    }
  end
end
