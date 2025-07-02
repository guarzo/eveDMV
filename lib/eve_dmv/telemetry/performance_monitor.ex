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
    %{
      database: get_database_metrics(),
      query_performance: get_slow_queries(),
      connection_pool: get_pool_metrics(),
      cache_hit_rates: get_cache_metrics()
    }
  end

  defp get_database_metrics do
    # Query actual database performance stats
    query = """
    SELECT 
      schemaname,
      tablename,
      n_tup_ins,
      n_tup_upd,
      n_tup_del,
      n_live_tup,
      n_dead_tup,
      last_vacuum,
      last_autovacuum
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY n_live_tup DESC
    LIMIT 10
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Enum.map(rows, fn row ->
          Enum.zip(columns, row) |> Map.new()
        end)

      {:error, _} ->
        []
    end
  end

  defp get_slow_queries do
    # Get slowest queries from pg_stat_statements if available
    query = """
    SELECT 
      query,
      calls,
      mean_exec_time,
      total_exec_time,
      rows
    FROM pg_stat_statements
    WHERE query NOT LIKE '%pg_stat_statements%'
    ORDER BY mean_exec_time DESC
    LIMIT 10
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [query, calls, mean_time, total_time, rows] ->
          %{
            query: String.slice(query, 0..100),
            calls: calls,
            mean_time_ms: Float.round(mean_time, 2),
            total_time_ms: Float.round(total_time, 2),
            rows: rows
          }
        end)

      {:error, _} ->
        # pg_stat_statements not available, return empty
        []
    end
  end

  defp get_pool_metrics do
    # Get connection pool stats from Ecto
    pool_info = :ets.info(EveDmv.Repo.Pool)

    if pool_info do
      %{
        size: Keyword.get(pool_info, :size, 0),
        memory: Keyword.get(pool_info, :memory, 0)
      }
    else
      %{size: 0, memory: 0}
    end
  end

  defp get_cache_metrics do
    # Get cache metrics from name resolver cache
    case Process.whereis(EveDmv.Eve.NameResolver) do
      nil ->
        %{hit_rate: 0.0, miss_rate: 0.0}

      pid ->
        case GenServer.call(pid, :get_stats, 5000) do
          {:ok, stats} ->
            total = stats[:hits] + stats[:misses]

            if total > 0 do
              %{
                hit_rate: Float.round(stats[:hits] / total * 100, 2),
                miss_rate: Float.round(stats[:misses] / total * 100, 2),
                total_requests: total
              }
            else
              %{hit_rate: 0.0, miss_rate: 0.0, total_requests: 0}
            end

          _ ->
            %{hit_rate: 0.0, miss_rate: 0.0}
        end
    end
  end
end
