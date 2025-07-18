defmodule EveDmv.Telemetry.PerformanceExporter do
  @moduledoc """
  Export performance data from production to development environment.

  Provides tools to:
  - Export slow query patterns and statistics
  - Generate performance reports for analysis
  - Create sanitized data dumps for development testing
  """

  alias EveDmv.Telemetry.QueryMonitor
  # alias EveDmv.Telemetry.PerformanceMonitor # Currently unused
  alias EveDmv.Repo

  @doc """
  Export slow query patterns and statistics to JSON format.

  Returns sanitized query patterns with timing statistics,
  removing any sensitive data while preserving performance characteristics.
  """
  def export_slow_queries(opts \\ []) do
    hours = Keyword.get(opts, :hours, 24)
    threshold_ms = Keyword.get(opts, :threshold_ms, 1000)

    # Get all slow queries from QueryMonitor
    all_slow_queries = QueryMonitor.get_slow_queries()

    # Filter queries based on threshold_ms if needed
    filtered_queries =
      if threshold_ms > 0 do
        Enum.filter(all_slow_queries, fn query ->
          query[:avg_time] >= threshold_ms
        end)
      else
        all_slow_queries
      end

    %{
      exported_at: DateTime.utc_now(),
      time_window_hours: hours,
      threshold_ms: threshold_ms,
      slow_queries: Enum.map(filtered_queries, &sanitize_query/1)
    }
  end

  @doc """
  Export database statistics and metrics.
  """
  def export_database_metrics(opts \\ []) do
    include_tables = Keyword.get(opts, :include_tables, true)
    include_statements = Keyword.get(opts, :include_statements, true)

    base_metrics = %{
      exported_at: DateTime.utc_now(),
      database_size: get_database_size(),
      connection_stats: get_connection_stats()
    }

    # Build metrics map functionally
    [
      {:table_stats, include_tables, &get_table_statistics/0},
      {:statement_stats, include_statements, &get_statement_statistics/0}
    ]
    |> Enum.reduce(base_metrics, fn {key, include?, fetch_fn}, acc ->
      if include? do
        Map.put(acc, key, fetch_fn.())
      else
        acc
      end
    end)
  end

  @doc """
  Generate a comprehensive performance report for development analysis.
  """
  def generate_performance_report(opts \\ []) do
    %{
      report_generated_at: DateTime.utc_now(),
      database_metrics: export_database_metrics(opts),
      slow_queries: export_slow_queries(opts),
      performance_alerts: get_recent_alerts(24),
      system_metrics: %{
        memory_usage: :erlang.memory(),
        process_count: length(Process.list()),
        ets_tables: length(:ets.all())
      }
    }
  end

  @doc """
  Export performance data to a file for transfer to development environment.
  """
  def export_to_file(filepath, opts \\ []) do
    report = generate_performance_report(opts)

    case Jason.encode(report, pretty: true) do
      {:ok, json} ->
        File.write(filepath, json)

      {:error, reason} ->
        {:error, "Failed to encode report: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp sanitize_query(query_data) do
    %{
      query_pattern: sanitize_sql(query_data.query),
      execution_count: query_data.count,
      avg_time_ms: query_data.avg_time,
      max_time_ms: query_data.max_time,
      min_time_ms: query_data.min_time,
      total_time_ms: query_data.total_time,
      first_seen: query_data.first_seen,
      last_seen: query_data.last_seen
    }
  end

  defp sanitize_sql(sql) when is_binary(sql) do
    sql
    # Replace numbers with placeholders
    |> String.replace(~r/\b\d+\b/, "?")
    # Replace string literals
    |> String.replace(~r/'[^']*'/, "'?'")
    # Replace parameter placeholders
    |> String.replace(~r/\$\d+/, "$?")
  end

  defp get_database_size do
    query = """
    SELECT 
      pg_size_pretty(pg_database_size(current_database())) as size,
      pg_database_size(current_database()) as size_bytes
    """

    case Ecto.Adapters.SQL.query(Repo, query) do
      {:ok, %{rows: [[size, size_bytes]]}} ->
        %{size: size, size_bytes: size_bytes}

      _ ->
        %{size: "unknown", size_bytes: 0}
    end
  end

  defp get_connection_stats do
    query = """
    SELECT 
      (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') as max_connections,
      (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_connections,
      (SELECT count(*) FROM pg_stat_activity) as all_pg_connections,
      (SELECT setting::int FROM pg_settings WHERE name = 'superuser_reserved_connections') as reserved_for_superuser
    """

    case Ecto.Adapters.SQL.query(Repo, query) do
      {:ok, %{rows: [[max_conn, active_conn, total_conn, reserved]]}} ->
        %{
          max_connections: max_conn,
          active_connections: active_conn,
          all_pg_connections: total_conn,
          reserved_for_superuser: reserved
        }

      _ ->
        %{
          max_connections: nil,
          active_connections: nil,
          all_pg_connections: nil,
          reserved_for_superuser: nil
        }
    end
  end

  defp get_table_statistics do
    query = """
    SELECT 
      schemaname,
      tablename,
      attname,
      n_distinct,
      correlation,
      most_common_vals
    FROM pg_stats 
    WHERE schemaname = 'public'
    ORDER BY tablename, attname
    """

    case Ecto.Adapters.SQL.query(Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, column, n_distinct, correlation, _mcv] ->
          %{
            schema: schema,
            table: table,
            column: column,
            n_distinct: n_distinct,
            correlation: correlation
          }
        end)

      _ ->
        []
    end
  end

  defp get_statement_statistics do
    # Only available if pg_stat_statements extension is enabled
    query = """
    SELECT 
      query,
      calls,
      total_exec_time,
      mean_exec_time,
      rows,
      100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
    FROM pg_stat_statements 
    WHERE query NOT LIKE '%pg_stat_%'
    ORDER BY total_exec_time DESC 
    LIMIT 20
    """

    case Ecto.Adapters.SQL.query(Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [query, calls, total_time, mean_time, rows_affected, hit_percent] ->
          %{
            query_pattern: sanitize_sql(query),
            calls: calls,
            total_exec_time: total_time,
            mean_exec_time: mean_time,
            rows_affected: rows_affected,
            cache_hit_percent: hit_percent
          }
        end)

      {:error, _} ->
        # pg_stat_statements not available
        []
    end
  end

  defp get_recent_alerts(hours_back) do
    # Get recent performance alerts from the last N hours
    cutoff_time = DateTime.add(DateTime.utc_now(), -hours_back, :hour)

    # Check for database connection issues
    db_alerts = check_database_alerts(cutoff_time)

    # Check for slow queries
    slow_query_alerts = check_slow_query_alerts(cutoff_time)

    # Check for memory issues
    memory_alerts = check_memory_alerts()

    db_alerts ++ slow_query_alerts ++ memory_alerts
  end

  defp check_database_alerts(cutoff_time) do
    # Check for connection pool exhaustion
    query = """
    SELECT 
      'connection_pool' as alert_type,
      'High connection usage detected: ' || active_count || ' active connections' as message,
      $1 as detected_at,
      'warning' as severity
    FROM (
      SELECT count(*) as active_count
      FROM pg_stat_activity 
      WHERE state = 'active' 
        AND query_start >= $1
    ) active_summary
    WHERE active_count > 80
    """

    case Ecto.Adapters.SQL.query(Repo, query, [cutoff_time]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [type, message, detected_at, severity] ->
          %{
            alert_type: type,
            message: message,
            detected_at: detected_at,
            severity: severity
          }
        end)

      _ ->
        []
    end
  end

  defp check_slow_query_alerts(cutoff_time) do
    # Check for queries that have been running too long
    query = """
    SELECT 
      'long_running_query' as alert_type,
      'Query running for ' || extract(epoch from (now() - query_start))::int || ' seconds' as message,
      query_start as detected_at,
      'critical' as severity
    FROM pg_stat_activity 
    WHERE state = 'active' 
      AND query_start >= $1
      AND query_start < now() - interval '5 minutes'
      AND query NOT LIKE '%pg_stat_%'
    """

    case Ecto.Adapters.SQL.query(Repo, query, [cutoff_time]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [type, message, detected_at, severity] ->
          %{
            alert_type: type,
            message: message,
            detected_at: detected_at,
            severity: severity
          }
        end)

      _ ->
        []
    end
  end

  defp check_memory_alerts do
    memory = :erlang.memory()
    total_memory = memory[:total]

    # Alert if memory usage is above 1GB
    if total_memory > 1_000_000_000 do
      [
        %{
          alert_type: "high_memory",
          message: "High memory usage: #{Float.round(total_memory / 1_000_000_000, 2)}GB",
          detected_at: DateTime.utc_now(),
          severity: "warning"
        }
      ]
    else
      []
    end
  end
end
