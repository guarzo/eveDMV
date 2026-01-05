defmodule EveDmv.Platform.Database.Repository.TelemetryHelper do
  @moduledoc """
  Telemetry integration for repository pattern performance monitoring.

  Provides query performance tracking, slow query detection, and database
  operation metrics for repository-based database access.
  """

  require Logger

  @slow_query_threshold_ms 500
  @very_slow_query_threshold_ms 2000

  @doc """
  Measure the execution time of a database query and emit telemetry events.

  ## Examples

      measure_query("killmail", :get, fn ->
        Ash.read(Ash.Query.limit(query, 1), domain: EveDmv.Api) |> case do {:ok, [result]} -> {:ok, result}; {:ok, []} -> {:error, :not_found}; error -> error end
      end)
  """
  @dialyzer {:nowarn_function, measure_query: 3}
  @spec measure_query(String.t(), atom(), function()) :: term()
  def measure_query(resource_name, operation, query_fun) do
    start_time = System.monotonic_time()

    try do
      result = query_fun.()
      duration_ms = calculate_duration_ms(start_time)

      emit_query_telemetry(resource_name, operation, duration_ms, :success, result)
      log_slow_query_if_needed(resource_name, operation, duration_ms)

      result
    rescue
      exception ->
        duration_ms = calculate_duration_ms(start_time)

        emit_query_telemetry(resource_name, operation, duration_ms, :error, exception)
        log_query_error(resource_name, operation, duration_ms, exception)

        reraise exception, __STACKTRACE__
    end
  end

  @doc """
  Emit telemetry event for query execution.
  """
  @spec emit_query_telemetry(String.t(), atom(), integer(), atom(), term()) :: :ok
  def emit_query_telemetry(resource_name, operation, duration_ms, status, result) do
    measurements = %{
      duration_ms: duration_ms,
      result_count: extract_result_count(result)
    }

    metadata = %{
      resource: resource_name,
      operation: operation,
      status: status
    }

    # Update performance statistics
    update_stats_from_telemetry(duration_ms, status)

    :telemetry.execute(
      [:eve_dmv, :database, :repository, :query],
      measurements,
      metadata
    )
  end

  @doc """
  Log performance metrics for repository operations.
  """
  @spec log_query_metrics(String.t(), atom(), integer(), term()) :: :ok
  def log_query_metrics(resource_name, operation, duration_ms, result) do
    result_count = extract_result_count(result)

    Logger.debug("""
    Repository Query: #{resource_name}.#{operation}
    Duration: #{duration_ms}ms
    Results: #{result_count}
    """)
  end

  @doc """
  Check if a query should be considered slow and log accordingly.
  """
  @spec log_slow_query_if_needed(String.t(), atom(), integer()) :: :ok
  def log_slow_query_if_needed(resource_name, operation, duration_ms) do
    cond do
      duration_ms >= @very_slow_query_threshold_ms ->
        Logger.warning("""
        Very slow repository query detected:
        Resource: #{resource_name}
        Operation: #{operation}
        Duration: #{duration_ms}ms
        Consider adding indexes or optimizing query patterns.
        """)

      duration_ms >= @slow_query_threshold_ms ->
        Logger.info("""
        Slow repository query:
        Resource: #{resource_name}
        Operation: #{operation}
        Duration: #{duration_ms}ms
        """)

      true ->
        :ok
    end
  end

  @doc """
  Log query errors with context information.
  """
  @spec log_query_error(String.t(), atom(), integer(), Exception.t()) :: :ok
  def log_query_error(resource_name, operation, duration_ms, exception) do
    Logger.error("""
    Repository query failed:
    Resource: #{resource_name}
    Operation: #{operation}
    Duration: #{duration_ms}ms
    Error: #{inspect(exception)}
    """)
  end

  @doc """
  Get repository performance statistics.
  """
  @dialyzer {:nowarn_function, get_performance_stats: 0}
  @spec get_performance_stats() :: map()
  def get_performance_stats do
    # Ensure ETS table exists (handle race conditions safely)
    ensure_ets_table_exists()

    # Gather stats if table exists, otherwise return defaults
    case :ets.info(:repo_performance_stats) do
      :undefined ->
        get_default_stats()

      _ ->
        gather_current_stats()
    end
  end

  @doc """
  Reset performance tracking metrics.
  """
  @spec reset_performance_stats() :: :ok
  def reset_performance_stats do
    case :ets.info(:repo_performance_stats) do
      :undefined ->
        :ok

      _ ->
        :ets.delete_all_objects(:repo_performance_stats)
        :ok
    end
  end

  # Private helper functions

  defp calculate_duration_ms(start_time) do
    duration_native = System.monotonic_time() - start_time
    System.convert_time_unit(duration_native, :native, :millisecond)
  end

  defp extract_result_count({:ok, results}) when is_list(results) do
    length(results)
  end

  defp extract_result_count({:ok, _single_result}) do
    1
  end

  defp extract_result_count({:error, _reason}) do
    0
  end

  defp extract_result_count(_other) do
    0
  end

  defp get_default_stats do
    %{
      total_queries: 0,
      avg_duration_ms: 0.0,
      slow_queries: 0,
      error_rate: 0.0,
      last_reset: DateTime.utc_now()
    }
  end

  defp gather_current_stats do
    # Get aggregated stats from ETS
    total_queries = get_ets_counter(:total_queries, 0)
    total_duration = get_ets_counter(:total_duration, 0)
    slow_queries = get_ets_counter(:slow_queries, 0)
    error_count = get_ets_counter(:error_count, 0)

    avg_duration_ms = if total_queries > 0, do: total_duration / total_queries, else: 0.0
    error_rate = if total_queries > 0, do: error_count / total_queries * 100, else: 0.0

    %{
      total_queries: total_queries,
      avg_duration_ms: Float.round(avg_duration_ms, 2),
      slow_queries: slow_queries,
      error_rate: Float.round(error_rate, 2),
      last_update: DateTime.utc_now()
    }
  end

  defp get_ets_counter(key, default) do
    case :ets.lookup(:repo_performance_stats, key) do
      [{^key, value}] -> value
      [] -> default
    end
  end

  defp increment_ets_counter(key, amount \\ 1) do
    :ets.update_counter(:repo_performance_stats, key, amount, {key, 0})
  end

  defp update_stats_from_telemetry(duration_ms, status) do
    # Ensure ETS table exists (handle race conditions safely)
    ensure_ets_table_exists()

    # Update counters
    increment_ets_counter(:total_queries)
    increment_ets_counter(:total_duration, round(duration_ms))

    if duration_ms >= @slow_query_threshold_ms do
      increment_ets_counter(:slow_queries)
    end

    if status == :error do
      increment_ets_counter(:error_count)
    end
  end

  # Safely create the ETS table, handling race conditions where another
  # process might create it between our check and creation attempt.
  defp ensure_ets_table_exists do
    case :ets.info(:repo_performance_stats) do
      :undefined ->
        try do
          :ets.new(:repo_performance_stats, [:named_table, :public, :set])
        rescue
          # Table was created by another process between our check and create
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end
  end
end
