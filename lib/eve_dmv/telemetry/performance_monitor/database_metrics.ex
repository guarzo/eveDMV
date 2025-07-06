defmodule EveDmv.Telemetry.PerformanceMonitor.DatabaseMetrics do
  @moduledoc """
  Collects and analyzes database performance metrics.

  Provides insights into table statistics, slow queries, table sizes,
  and overall database performance.
  """

  require Logger

  alias Ecto.Adapters.SQL
  alias EveDmv.Telemetry.QueryMonitor

  @doc """
  Get database performance statistics.
  """
  def get_database_metrics do
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

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows, columns: columns}} ->
        Enum.map(rows, fn row ->
          Enum.zip(columns, row)
          |> Map.new()
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Get slowest queries from pg_stat_statements if available.
  """
  def get_slow_queries do
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

    case SQL.query(EveDmv.Repo, query) do
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

  @doc """
  Get table sizes and row counts for monitoring growth.
  """
  def get_table_sizes do
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

    case SQL.query(EveDmv.Repo, query) do
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

  @doc """
  Get cache metrics from name resolver cache.
  """
  def get_cache_metrics do
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

  @doc """
  Get comprehensive query analysis from QueryMonitor.
  """
  def get_query_analysis do
    case Process.whereis(QueryMonitor) do
      nil ->
        %{error: "QueryMonitor not running"}

      _pid ->
        try do
          QueryMonitor.get_performance_analysis()
        rescue
          error in [FunctionClauseError, UndefinedFunctionError, ArgumentError] ->
            Logger.warning("Query analysis error: #{inspect(error)}")
            %{error: "Failed to get query analysis"}

          error ->
            Logger.error("Unexpected error in query analysis: #{inspect(error)}")
            %{error: "Failed to get query analysis"}
        end
    end
  end

  @doc """
  Get N+1 query detection alerts.
  """
  def get_n_plus_one_detection do
    case Process.whereis(QueryMonitor) do
      nil ->
        []

      _pid ->
        try do
          QueryMonitor.get_n_plus_one_alerts()
        rescue
          error in [FunctionClauseError, UndefinedFunctionError, ArgumentError] ->
            Logger.warning("N+1 detection error: #{inspect(error)}")
            []

          error ->
            Logger.error("Unexpected error in N+1 detection: #{inspect(error)}")
            []
        end
    end
  end

  @doc """
  Get detailed query statistics for a specific table.
  """
  def get_table_query_stats(table_name) do
    query = """
    SELECT
      schemaname,
      tablename,
      seq_scan,
      seq_tup_read,
      idx_scan,
      idx_tup_fetch,
      n_tup_ins,
      n_tup_upd,
      n_tup_del,
      n_tup_hot_upd,
      n_live_tup,
      n_dead_tup
    FROM pg_stat_user_tables
    WHERE tablename = $1
    """

    case SQL.query(EveDmv.Repo, query, [table_name]) do
      {:ok,
       %{
         rows: [
           [
             schema,
             table,
             seq_scan,
             seq_read,
             idx_scan,
             idx_fetch,
             ins,
             upd,
             del,
             hot_upd,
             live,
             dead
           ]
         ]
       }} ->
        %{
          schema: schema,
          table: table,
          sequential_scans: seq_scan || 0,
          sequential_tuples_read: seq_read || 0,
          index_scans: idx_scan || 0,
          index_tuples_fetched: idx_fetch || 0,
          tuples_inserted: ins || 0,
          tuples_updated: upd || 0,
          tuples_deleted: del || 0,
          tuples_hot_updated: hot_upd || 0,
          live_tuples: live || 0,
          dead_tuples: dead || 0,
          table_bloat_ratio: calculate_bloat_ratio(live, dead)
        }

      _ ->
        %{error: "Table not found or query failed"}
    end
  end

  @doc """
  Get query execution plan for analysis.
  """
  def explain_query(sql) do
    explain_sql = "EXPLAIN (ANALYZE, BUFFERS) #{sql}"

    case SQL.query(EveDmv.Repo, explain_sql, []) do
      {:ok, %{rows: rows}} ->
        mapped_rows = Enum.map(rows, fn [line] -> line end)
        plan = Enum.join(mapped_rows, "\n")
        {:ok, plan}

      {:error, error} ->
        {:error, "Failed to explain query: #{inspect(error)}"}
    end
  end

  @doc """
  Analyze table statistics freshness.
  """
  def check_statistics_freshness do
    query = """
    SELECT
      schemaname,
      tablename,
      last_analyze,
      last_autoanalyze,
      n_mod_since_analyze
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
      AND (last_analyze IS NULL OR last_analyze < NOW() - INTERVAL '7 days')
      AND n_mod_since_analyze > 1000
    ORDER BY n_mod_since_analyze DESC
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, last_manual, last_auto, mods] ->
          %{
            schema: schema,
            table: table,
            last_analyze: last_manual,
            last_autoanalyze: last_auto,
            modifications_since_analyze: mods,
            needs_analyze: true
          }
        end)

      {:error, _} ->
        []
    end
  end

  # Private helper functions

  defp calculate_bloat_ratio(live_tuples, dead_tuples) do
    total = (live_tuples || 0) + (dead_tuples || 0)

    if total > 0 do
      Float.round((dead_tuples || 0) / total * 100, 2)
    else
      0.0
    end
  end
end
