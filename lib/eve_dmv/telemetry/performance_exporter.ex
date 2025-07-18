defmodule EveDmv.Telemetry.PerformanceExporter do
  @moduledoc """
  Export performance data from production to development environment.

  Provides tools to:
  - Export slow query patterns and statistics
  - Generate performance reports for analysis
  - Create sanitized data dumps for development testing
  """

  alias EveDmv.Telemetry.{QueryMonitor, PerformanceMonitor}
  alias EveDmv.Repo

  @doc """
  Export slow query patterns and statistics to JSON format.

  Returns sanitized query patterns with timing statistics,
  removing any sensitive data while preserving performance characteristics.
  """
  def export_slow_queries(opts \\ []) do
    hours = Keyword.get(opts, :hours, 24)
    threshold_ms = Keyword.get(opts, :threshold_ms, 1000)

    slow_queries = QueryMonitor.get_slow_queries(hours: hours, threshold_ms: threshold_ms)

    %{
      exported_at: DateTime.utc_now(),
      time_window_hours: hours,
      threshold_ms: threshold_ms,
      slow_queries: Enum.map(slow_queries, &sanitize_query/1)
    }
  end

  @doc """
  Export database statistics and metrics.
  """
  def export_database_metrics(opts \\ []) do
    include_tables = Keyword.get(opts, :include_tables, true)
    include_statements = Keyword.get(opts, :include_statements, true)

    metrics = %{
      exported_at: DateTime.utc_now(),
      database_size: get_database_size(),
      connection_stats: get_connection_stats()
    }

    metrics =
      if include_tables do
        Map.put(metrics, :table_stats, get_table_statistics())
      else
        metrics
      end

    metrics =
      if include_statements do
        Map.put(metrics, :statement_stats, get_statement_statistics())
      else
        metrics
      end

    metrics
  end

  @doc """
  Generate a comprehensive performance report for development analysis.
  """
  def generate_performance_report(opts \\ []) do
    %{
      report_generated_at: DateTime.utc_now(),
      database_metrics: export_database_metrics(opts),
      slow_queries: export_slow_queries(opts),
      performance_alerts: PerformanceMonitor.DatabaseMetrics.get_recent_alerts(24),
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
      max_conn as max_connections,
      used as used_connections,
      res_for_super as reserved_for_superuser
    FROM pg_stat_database 
    WHERE datname = current_database()
    """

    case Ecto.Adapters.SQL.query(Repo, query) do
      {:ok, %{rows: rows}} when length(rows) > 0 ->
        [max_conn, used, reserved] = hd(rows)

        %{
          max_connections: max_conn,
          used_connections: used,
          reserved_for_superuser: reserved
        }

      _ ->
        %{max_connections: nil, used_connections: nil, reserved_for_superuser: nil}
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
end
