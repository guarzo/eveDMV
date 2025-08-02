defmodule EveDmv.Intelligence.Core.TimeoutHelper do
  @moduledoc """
  Standardized timeout management for intelligence analyzers.

  Provides consistent timeout handling patterns, async task management,
  and graceful degradation strategies for intelligence operations.
  """

  require Logger

  # Default timeouts for different operation types
  @default_query_timeout 10_000
  @default_api_timeout 15_000
  @default_analysis_timeout 30_000
  @default_batch_timeout 60_000

  @type timeout_ms :: pos_integer()
  @type task_result :: {:ok, term()} | {:error, term()}
  @type async_task :: Task.t()

  @doc """
  Execute a function with timeout and proper error handling.

  Provides standardized timeout behavior with telemetry and logging.
  """
  @spec with_timeout((-> term()), timeout_ms(), atom()) :: task_result()
  def with_timeout(func, timeout_ms, operation_type \\ :generic) do
    start_time = System.monotonic_time()

    metadata = %{
      operation_type: operation_type,
      timeout_ms: timeout_ms
    }

    try do
      task = Task.async(func)

      case Task.yield(task, timeout_ms) do
        {:ok, result} ->
          duration_ms = calculate_duration(start_time)

          :telemetry.execute(
            [:eve_dmv, :intelligence, :timeout_operation],
            %{duration_ms: duration_ms, success: 1},
            Map.put(metadata, :status, :completed)
          )

          {:ok, result}

        nil ->
          # Task didn't complete within timeout
          Task.shutdown(task, :brutal_kill)
          duration_ms = calculate_duration(start_time)

          Logger.warning("Operation #{operation_type} timed out after #{timeout_ms}ms")

          :telemetry.execute(
            [:eve_dmv, :intelligence, :timeout_operation],
            %{duration_ms: duration_ms, timeout: 1},
            Map.put(metadata, :status, :timeout)
          )

          {:error, :timeout}
      end
    rescue
      exception ->
        duration_ms = calculate_duration(start_time)

        Logger.error("Operation #{operation_type} failed with exception: #{inspect(exception)}")

        :telemetry.execute(
          [:eve_dmv, :intelligence, :timeout_operation],
          %{duration_ms: duration_ms, error: 1},
          Map.merge(metadata, %{status: :error, error: inspect(exception)})
        )

        {:error, {:exception, exception}}
    end
  end

  @doc """
  Execute multiple tasks with timeout and collect results.

  Handles batch operations with individual timeouts and failure isolation.
  """
  @spec with_timeout_batch([{(-> term()), atom()}], timeout_ms()) :: [task_result()]
  def with_timeout_batch(tasks, timeout_ms) do
    start_time = System.monotonic_time()

    Logger.debug("Starting batch operation with #{length(tasks)} tasks, timeout: #{timeout_ms}ms")

    results =
      tasks
      |> Task.async_stream(
        fn {func, operation_type} ->
          with_timeout(func, timeout_ms, operation_type)
        end,
        max_concurrency: 10,
        timeout: timeout_ms + 1_000,
        on_timeout: :kill_task
      )
      |> Enum.to_list()

    duration_ms = calculate_duration(start_time)

    success_count =
      Enum.count(results, fn
        {_, {:ok, _}} -> true
        _ -> false
      end)

    error_count = length(results) - success_count

    Logger.info(
      "Batch operation completed: #{success_count} success, #{error_count} errors in #{duration_ms}ms"
    )

    :telemetry.execute(
      [:eve_dmv, :intelligence, :timeout_batch],
      %{
        duration_ms: duration_ms,
        task_count: length(tasks),
        success_count: success_count,
        error_count: error_count
      },
      %{timeout_ms: timeout_ms}
    )

    Enum.map(results, fn
      {:ok, result} -> result
      {:exit, :timeout} -> {:error, :timeout}
      {:exit, reason} -> {:error, {:exit, reason}}
    end)
  end

  @doc """
  Get default timeout for operation type.
  """
  @spec get_default_timeout(atom()) :: timeout_ms()
  def get_default_timeout(operation_type) do
    case operation_type do
      :query -> @default_query_timeout
      :api -> @default_api_timeout
      :analysis -> @default_analysis_timeout
      :batch -> @default_batch_timeout
      _ -> @default_analysis_timeout
    end
  end

  @doc """
  Execute with operation-specific default timeout.
  """
  @spec with_default_timeout((-> term()), atom()) :: task_result()
  def with_default_timeout(func, operation_type) do
    timeout_ms = get_default_timeout(operation_type)
    with_timeout(func, timeout_ms, operation_type)
  end

  @doc """
  Execute with exponential backoff retry on timeout.

  Useful for operations that might succeed on retry due to temporary resource constraints.
  """
  @spec with_retry_timeout((-> term()), timeout_ms(), atom(), pos_integer()) :: task_result()
  def with_retry_timeout(func, timeout_ms, operation_type, max_retries \\ 3) do
    do_retry_timeout(func, timeout_ms, operation_type, max_retries, 1)
  end

  # Private helper functions

  defp do_retry_timeout(func, timeout_ms, operation_type, max_retries, attempt) do
    case with_timeout(func, timeout_ms, operation_type) do
      {:ok, result} ->
        {:ok, result}

      {:error, :timeout} when attempt < max_retries ->
        backoff_ms = round(:math.pow(2, attempt) * 1000)

        Logger.debug(
          "Retrying #{operation_type} after #{backoff_ms}ms backoff (attempt #{attempt}/#{max_retries})"
        )

        :timer.sleep(backoff_ms)
        do_retry_timeout(func, timeout_ms, operation_type, max_retries, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_duration(start_time) do
    duration = System.monotonic_time() - start_time
    System.convert_time_unit(duration, :native, :millisecond)
  end
end
