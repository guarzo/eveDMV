defmodule EveDmv.Telemetry.PerformanceMonitor do
  @moduledoc """
  Performance monitoring utilities for tracking optimization impact.

  This module provides telemetry events and metrics tracking for
  database queries, API calls, and processing times.
  """

  require Logger

  # Default performance thresholds (configurable)
  @default_thresholds %{
    slow_query_ms: 1000,
    slow_api_call_ms: 5000,
    slow_liveview_render_ms: 500
  }

  # Get threshold values from config or use defaults
  defp get_threshold(type) do
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
  Get performance metrics summary.
  """
  def get_performance_summary do
    %{
      database: get_database_metrics(),
      query_performance: get_slow_queries(),
      connection_pool: get_pool_metrics(),
      cache_hit_rates: get_cache_metrics(),
      table_sizes: get_table_sizes(),
      index_usage: get_index_usage_stats(),
      partition_health: check_partition_health(),
      query_analysis: get_query_analysis(),
      n_plus_one_alerts: get_n_plus_one_detection()
    }
  end

  @doc """
  Get comprehensive query analysis from QueryMonitor.
  """
  def get_query_analysis do
    case Process.whereis(EveDmv.Telemetry.QueryMonitor) do
      nil ->
        %{error: "QueryMonitor not running"}

      _pid ->
        try do
          EveDmv.Telemetry.QueryMonitor.get_performance_analysis()
        rescue
          _ -> %{error: "Failed to get query analysis"}
        end
    end
  end

  @doc """
  Get N+1 query detection alerts.
  """
  def get_n_plus_one_detection do
    case Process.whereis(EveDmv.Telemetry.QueryMonitor) do
      nil ->
        []

      _pid ->
        try do
          EveDmv.Telemetry.QueryMonitor.get_n_plus_one_alerts()
        rescue
          _ -> []
        end
    end
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
    # Get connection pool stats using Ecto telemetry
    # Get pool configuration
    config = EveDmv.Repo.config()
    pool_size = Keyword.get(config, :pool_size, 10)

    # Query database for connection stats
    query = """
    SELECT 
      count(*) as total_connections,
      count(*) FILTER (WHERE state = 'active') as active_connections,
      count(*) FILTER (WHERE state = 'idle') as idle_connections,
      count(*) FILTER (WHERE wait_event IS NOT NULL) as waiting_connections
    FROM pg_stat_activity 
    WHERE datname = current_database()
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[total, active, idle, waiting]]}} ->
        %{
          pool_size: pool_size,
          total_connections: total || 0,
          active_connections: active || 0,
          idle_connections: idle || 0,
          waiting_connections: waiting || 0,
          utilization:
            if(pool_size > 0, do: Float.round((active || 0) / pool_size * 100, 2), else: 0.0)
        }

      _ ->
        %{
          pool_size: pool_size,
          total_connections: 0,
          active_connections: 0,
          idle_connections: 0,
          waiting_connections: 0,
          utilization: 0.0
        }
    end
  rescue
    _ -> %{error: "Failed to get pool metrics"}
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

  defp get_table_sizes do
    # Get table sizes and row counts for monitoring growth
    query = """
    SELECT 
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
      pg_size_pretty(pg_table_size(schemaname||'.'||tablename)) as table_size,
      pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as indexes_size,
      n_live_tup as row_count
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 20
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, total_size, table_size, indexes_size, row_count] ->
          %{
            schema: schema,
            table: table,
            total_size: total_size,
            table_size: table_size,
            indexes_size: indexes_size,
            row_count: row_count
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp get_index_usage_stats do
    # Monitor index usage to identify unused indexes
    query = """
    SELECT 
      schemaname,
      tablename,
      indexname,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch,
      pg_size_pretty(pg_relation_size(indexrelid)) as index_size
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY idx_scan
    LIMIT 20
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, index, scans, reads, fetches, size] ->
          %{
            schema: schema,
            table: table,
            index: index,
            scans: scans || 0,
            tuples_read: reads || 0,
            tuples_fetched: fetches || 0,
            size: size,
            unused: (scans || 0) == 0
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp check_partition_health do
    # Check health of partitioned tables
    query = """
    WITH partition_info AS (
      SELECT 
        parent.relname as parent_table,
        child.relname as partition_name,
        pg_size_pretty(pg_relation_size(child.oid)) as partition_size,
        pg_stat_get_live_tuples(child.oid) as row_count,
        pg_stat_get_last_vacuum_time(child.oid) as last_vacuum,
        pg_stat_get_last_autovacuum_time(child.oid) as last_autovacuum
      FROM pg_inherits
      JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
      JOIN pg_class child ON pg_inherits.inhrelid = child.oid
      WHERE parent.relnamespace = 'public'::regnamespace
    )
    SELECT * FROM partition_info
    ORDER BY parent_table, partition_name
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [parent, partition, size, count, vacuum, autovacuum] ->
          %{
            parent_table: parent,
            partition_name: partition,
            size: size,
            row_count: count || 0,
            last_vacuum: vacuum,
            last_autovacuum: autovacuum,
            needs_vacuum: needs_vacuum?(count, vacuum, autovacuum)
          }
        end)
        |> Enum.group_by(& &1.parent_table)

      {:error, _} ->
        %{}
    end
  end

  # Helper to determine if partition needs vacuum
  defp needs_vacuum?(row_count, last_vacuum, last_autovacuum) do
    # Consider a partition needs vacuum if:
    # - Never vacuumed and has > 10k rows
    # - Last vacuum was > 7 days ago and has > 100k rows
    cond do
      is_nil(last_vacuum) and is_nil(last_autovacuum) and row_count > 10_000 ->
        true

      row_count > 100_000 ->
        last_vacuum_time = last_vacuum || last_autovacuum

        if last_vacuum_time do
          days_since = DateTime.diff(DateTime.utc_now(), last_vacuum_time, :day)
          days_since > 7
        else
          true
        end

      true ->
        false
    end
  end

  @doc """
  Monitor real-time database health metrics.
  """
  def monitor_database_health do
    health_metrics = %{
      connections: monitor_connection_health(),
      queries: monitor_query_health(),
      locks: monitor_lock_contention(),
      replication_lag: check_replication_lag()
    }

    # Log warnings for any issues
    Enum.each(health_metrics, fn {category, metrics} ->
      if metrics[:has_issues] do
        Logger.warning("Database health issue in #{category}: #{inspect(metrics[:issues])}")
      end
    end)

    health_metrics
  end

  defp monitor_connection_health do
    query = """
    SELECT 
      count(*) as total,
      count(*) FILTER (WHERE state = 'active') as active,
      count(*) FILTER (WHERE state = 'idle') as idle,
      count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
      count(*) FILTER (WHERE wait_event IS NOT NULL) as waiting,
      max(EXTRACT(EPOCH FROM (now() - query_start))) as longest_query_seconds
    FROM pg_stat_activity 
    WHERE datname = current_database()
      AND pid != pg_backend_pid()
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[total, active, idle, idle_tx, waiting, longest_query]]}} ->
        build_connection_health_metrics(total, active, idle, idle_tx, waiting, longest_query)

      {:error, _} ->
        %{has_issues: true, issues: ["failed_to_query_connections"]}
    end
  end

  defp build_connection_health_metrics(total, active, idle, idle_tx, waiting, longest_query) do
    pool_config = EveDmv.Repo.config()
    pool_size = Keyword.get(pool_config, :pool_size, 10)

    issues = detect_connection_issues(total, idle_tx, longest_query, pool_size)

    %{
      total: total || 0,
      active: active || 0,
      idle: idle || 0,
      idle_in_transaction: idle_tx || 0,
      waiting: waiting || 0,
      longest_query_seconds: longest_query,
      pool_size: pool_size,
      utilization_percent: Float.round((total || 0) / pool_size * 100, 2),
      has_issues: length(issues) > 0,
      issues: issues
    }
  end

  defp detect_connection_issues(total, idle_tx, longest_query, pool_size) do
    []
    |> add_if_issue(total >= pool_size * 0.9, "near_pool_limit")
    |> add_if_issue(idle_tx > 0, "idle_in_transaction")
    |> add_if_issue(longest_query && longest_query > 300, "long_running_queries")
  end

  defp add_if_issue(issues, condition, issue) do
    if condition, do: [issue | issues], else: issues
  end

  defp monitor_query_health do
    # Check for queries that are taking too long
    query = """
    SELECT 
      count(*) FILTER (WHERE state = 'active' AND query_start < now() - interval '1 minute') as slow_queries,
      count(*) FILTER (WHERE state = 'active' AND query_start < now() - interval '5 minutes') as very_slow_queries,
      count(*) FILTER (WHERE waiting) as waiting_queries
    FROM pg_stat_activity
    WHERE datname = current_database()
      AND pid != pg_backend_pid()
      AND state != 'idle'
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[slow, very_slow, waiting]]}} ->
        issues = []

        issues = if slow > 5, do: ["many_slow_queries" | issues], else: issues
        issues = if very_slow > 0, do: ["very_slow_queries" | issues], else: issues
        issues = if waiting > 3, do: ["many_waiting_queries" | issues], else: issues

        %{
          slow_queries: slow || 0,
          very_slow_queries: very_slow || 0,
          waiting_queries: waiting || 0,
          has_issues: length(issues) > 0,
          issues: issues
        }

      {:error, _} ->
        %{has_issues: true, issues: ["failed_to_query_health"]}
    end
  end

  defp monitor_lock_contention do
    # Check for lock contention issues
    query = """
    SELECT 
      count(*) as blocked_queries,
      count(DISTINCT blocked.pid) as blocked_pids,
      array_agg(DISTINCT blocking.query ORDER BY blocking.query) as blocking_queries
    FROM pg_stat_activity blocked
    JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
    WHERE blocked.wait_event_type = 'Lock'
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[blocked, pids, queries]]}} when blocked > 0 ->
        %{
          blocked_queries: blocked,
          blocked_pids: pids,
          blocking_queries: queries || [],
          has_issues: true,
          issues: ["lock_contention"]
        }

      {:ok, _} ->
        %{
          blocked_queries: 0,
          blocked_pids: 0,
          has_issues: false,
          issues: []
        }

      {:error, _} ->
        %{has_issues: false, issues: []}
    end
  end

  defp check_replication_lag do
    # Placeholder for replication lag monitoring
    # This would be implemented if using streaming replication
    %{
      has_issues: false,
      issues: [],
      lag_bytes: 0,
      lag_seconds: 0
    }
  end

  # Common helper functions

  # Safely execute a function with error handling.
  # Returns {:ok, result} on success or {:error, error} on failure.
  defp safe_execute(fun) when is_function(fun) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      error ->
        Logger.error("Performance monitoring error: #{inspect(error)}")
        {:error, error}
    end
  end

  # Execute function with timing, telemetry, and logging.
  defp execute_with_timing(operation_name, fun, telemetry_event, metadata, threshold, log_prefix) do
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

  # Calculate throughput safely handling division by zero.
  defp calculate_throughput(record_count, duration) do
    try do
      if duration > 0 do
        record_count * 1000 / duration
      else
        0.0
      end
    rescue
      _ -> 0.0
    end
  end
end
