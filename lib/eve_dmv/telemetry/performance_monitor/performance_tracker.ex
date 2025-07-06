defmodule EveDmv.Telemetry.PerformanceMonitor.PerformanceTracker do
  @moduledoc """
  Tracks performance metrics for various operations.

  Handles telemetry events for database queries, API calls, bulk operations,
  cache access, and LiveView rendering with configurable thresholds.
  """

  require Logger

  # Default performance thresholds (configurable)
  @default_thresholds %{
    slow_query_ms: 1000,
    slow_api_call_ms: 5000,
    slow_liveview_render_ms: 500
  }

  @doc """
  Get threshold values from config or use defaults.
  """
  def get_threshold(type) do
    thresholds = Application.get_env(:eve_dmv, :performance_thresholds, @default_thresholds)
    Map.get(thresholds, type, @default_thresholds[type])
  end

  @doc """
  Track database query performance.
  """
  def track_query(query_name, fun) when is_function(fun) do
    threshold = get_threshold(:slow_query_ms)

    execute_with_timing(
      query_name,
      fun,
      [:eve_dmv, :database, :query],
      %{query: query_name},
      threshold,
      "Slow database query"
    )
  end

  @doc """
  Track API call performance (ESI, external services).
  """
  def track_api_call(service_name, endpoint, fun) when is_function(fun) do
    threshold = get_threshold(:slow_api_call_ms)
    operation_name = "#{service_name}/#{endpoint}"

    execute_with_timing(
      operation_name,
      fun,
      [:eve_dmv, :api, :call],
      %{service: service_name, endpoint: endpoint},
      threshold,
      "Slow API call"
    )
  end

  @doc """
  Track bulk operation performance.
  """
  def track_bulk_operation(operation_name, record_count, fun) when is_function(fun) do
    safe_execute(fn ->
      start_time = System.monotonic_time(:millisecond)

      result = fun.()

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      throughput = calculate_throughput(record_count, duration)

      :telemetry.execute(
        [:eve_dmv, :bulk, :operation],
        %{duration: duration, record_count: record_count, throughput: throughput},
        %{operation: operation_name}
      )

      Logger.info(
        "Bulk operation #{operation_name}: #{record_count} records in #{duration}ms (#{Float.round(throughput, 1)} records/sec)"
      )

      result
    end)
  end

  @doc """
  Track cache hit/miss rates.
  """
  def track_cache_access(cache_name, hit_or_miss) do
    :telemetry.execute(
      [:eve_dmv, :cache, :access],
      %{count: 1},
      %{cache: cache_name, result: hit_or_miss}
    )
  end

  @doc """
  Track database metrics like connection pool stats.
  """
  def track_database_metric(metric_name, value) do
    :telemetry.execute(
      [:eve_dmv, :database, :metric],
      %{value: value},
      %{metric: metric_name}
    )
  end

  @doc """
  Track LiveView rendering performance.
  """
  def track_liveview_render(view_name, fun) when is_function(fun) do
    threshold = get_threshold(:slow_liveview_render_ms)

    execute_with_timing(
      view_name,
      fun,
      [:eve_dmv, :liveview, :render],
      %{view: view_name},
      threshold,
      "Slow LiveView render"
    )
  end

  @doc """
  Execute function with timing, telemetry, and logging.
  """
  def execute_with_timing(operation_name, fun, telemetry_event, metadata, threshold, log_prefix) do
    case safe_execute(fn ->
           start_time = System.monotonic_time(:millisecond)

           result = fun.()

           end_time = System.monotonic_time(:millisecond)
           duration = end_time - start_time

           :telemetry.execute(
             telemetry_event,
             %{duration: duration},
             metadata
           )

           if duration > threshold do
             Logger.warning("#{log_prefix}: #{operation_name} took #{duration}ms")
           end

           result
         end) do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Safely execute a function with error handling.
  Returns {:ok, result} on success or {:error, error} on failure.
  """
  def safe_execute(fun) when is_function(fun) do
    result = fun.()
    {:ok, result}
  rescue
    error ->
      Logger.error("Performance monitoring error: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Calculate throughput safely handling division by zero.
  """
  def calculate_throughput(record_count, duration) do
    if duration > 0 do
      record_count * 1000 / duration
    else
      0.0
    end
  rescue
    error in [ArithmeticError, ArgumentError] ->
      Logger.warning("Arithmetic error in throughput calculation: #{inspect(error)}")
      0.0

    error ->
      Logger.error("Unexpected error in throughput calculation: #{inspect(error)}")
      0.0
  end
end
