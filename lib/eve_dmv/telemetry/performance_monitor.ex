defmodule EveDmv.Telemetry.PerformanceMonitor do
  @moduledoc """
  Performance monitoring utilities for tracking optimization impact.

  This module provides telemetry events and metrics tracking for
  database queries, API calls, and processing times.
  """

  require Logger

  @doc """
  Track database query performance.
  """
  def track_query(query_name, fun) when is_function(fun) do
    start_time = System.monotonic_time(:millisecond)

    result = fun.()

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    :telemetry.execute(
      [:eve_dmv, :database, :query],
      %{duration: duration},
      %{query: query_name}
    )

    if duration > 1000 do
      Logger.warning("Slow database query: #{query_name} took #{duration}ms")
    end

    result
  end

  @doc """
  Track API call performance (ESI, external services).
  """
  def track_api_call(service_name, endpoint, fun) when is_function(fun) do
    start_time = System.monotonic_time(:millisecond)

    result = fun.()

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    :telemetry.execute(
      [:eve_dmv, :api, :call],
      %{duration: duration},
      %{service: service_name, endpoint: endpoint}
    )

    if duration > 5000 do
      Logger.warning("Slow API call: #{service_name}/#{endpoint} took #{duration}ms")
    end

    result
  end

  @doc """
  Track bulk operation performance.
  """
  def track_bulk_operation(operation_name, record_count, fun) when is_function(fun) do
    start_time = System.monotonic_time(:millisecond)

    result = fun.()

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    throughput = if duration > 0, do: record_count * 1000 / duration, else: 0

    :telemetry.execute(
      [:eve_dmv, :bulk, :operation],
      %{duration: duration, record_count: record_count, throughput: throughput},
      %{operation: operation_name}
    )

    Logger.info(
      "Bulk operation #{operation_name}: #{record_count} records in #{duration}ms (#{Float.round(throughput, 1)} records/sec)"
    )

    result
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
  Track LiveView rendering performance.
  """
  def track_liveview_render(view_name, fun) when is_function(fun) do
    start_time = System.monotonic_time(:millisecond)

    result = fun.()

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    :telemetry.execute(
      [:eve_dmv, :liveview, :render],
      %{duration: duration},
      %{view: view_name}
    )

    if duration > 500 do
      Logger.warning("Slow LiveView render: #{view_name} took #{duration}ms")
    end

    result
  end

  @doc """
  Get performance metrics summary.
  """
  def get_performance_summary do
    # This would integrate with telemetry metrics collection
    # For now, return a basic structure
    %{
      database_queries: %{
        total_count: 0,
        avg_duration: 0,
        slow_queries: 0
      },
      api_calls: %{
        total_count: 0,
        avg_duration: 0,
        timeout_count: 0
      },
      cache_performance: %{
        hit_rate: 0.0,
        miss_rate: 0.0
      },
      bulk_operations: %{
        total_records: 0,
        avg_throughput: 0
      }
    }
  end
end
