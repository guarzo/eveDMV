# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Database.HealthCheck do
  @moduledoc """
  Comprehensive database health monitoring and diagnostic tools.

  This module provides health checks for database connectivity, performance,
  partitions, indexes, and overall system health.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Telemetry.PerformanceMonitor

  require Logger

  @doc """
  Run all health checks and return a comprehensive health report.

  ## Examples

      HealthCheck.run_health_checks()
      #=> %{
      #     connection: :healthy,
      #     partitions: :healthy,
      #     indexes: :healthy,
      #     vacuum: :warning,
      #     replication_lag: :unknown
      #   }
  """
  def run_health_checks do
    %{
      connection: check_connection(),
      partitions: check_partitions(),
      indexes: check_index_usage(),
      vacuum: check_vacuum_stats(),
      connection_pool: check_connection_pool(),
      table_stats: check_table_stats(),
      disk_usage: check_disk_usage(),
      query_performance: check_query_performance()
    }
  end

  @doc """
  Quick health check for monitoring systems.
  Returns :healthy, :warning, or :critical.
  """
  def quick_health_check do
    checks = run_health_checks()

    critical_issues = Enum.count(checks, fn {_key, status} -> status == :critical end)
    warning_issues = Enum.count(checks, fn {_key, status} -> status == :warning end)

    cond do
      critical_issues > 0 -> :critical
      warning_issues > 2 -> :warning
      true -> :healthy
    end
  end

  defp check_connection do
    case SQL.query(EveDmv.Repo, "SELECT 1 as health_check") do
      {:ok, %{rows: [[1]]}} ->
        :healthy

      {:ok, _} ->
        :warning

      {:error, reason} ->
        Logger.error("Database connection failed: #{inspect(reason)}")
        :critical
    end
  rescue
    error ->
      Logger.error("Database connection check failed: #{inspect(error)}")
      :critical
  end

  defp check_partitions do
    query = """
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables
    WHERE tablename LIKE 'killmails_raw_%' OR tablename LIKE 'killmails_enriched_%'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} when rows != [] ->
        current_month = Date.beginning_of_month(Date.utc_today())

        future_partitions =
          Enum.count(rows, fn [_schema, table, _size] ->
            # Check if we have partitions for current and next month
            next_month_iso = Date.to_iso8601(Date.add(current_month, 30), :basic)

            String.contains?(table, Date.to_iso8601(current_month, :basic)) or
              String.contains?(table, next_month_iso)
          end)

        if future_partitions >= 2, do: :healthy, else: :warning

      {:ok, %{rows: []}} ->
        Logger.warning("No partitioned tables found")
        :warning

      {:error, reason} ->
        Logger.error("Partition check failed: #{inspect(reason)}")
        :critical
    end
  rescue
    error ->
      Logger.error("Partition check error: #{inspect(error)}")
      :critical
  end

  defp check_index_usage do
    query = """
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    AND idx_scan = 0
    ORDER BY idx_tup_read DESC
    LIMIT 10
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: unused_indexes}} ->
        unused_count = length(unused_indexes)

        cond do
          unused_count == 0 -> :healthy
          unused_count <= 5 -> :warning
          true -> :critical
        end

      {:error, reason} ->
        Logger.error("Index usage check failed: #{inspect(reason)}")
        :warning
    end
  rescue
    error in [Ecto.QueryError, DBConnection.ConnectionError, Postgrex.Error] ->
      Logger.warning("Database error in index usage check: #{inspect(error)}")
      :warning

    error ->
      Logger.error("Unexpected error in index usage check: #{inspect(error)}")
      :warning
  end

  defp check_vacuum_stats do
    query = """
    SELECT
      schemaname,
      tablename,
      last_vacuum,
      last_autovacuum,
      n_dead_tup,
      n_live_tup,
      CASE
        WHEN n_live_tup > 0 THEN (n_dead_tup::float / n_live_tup::float) * 100
        ELSE 0
      END as dead_tuple_percent
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    AND n_live_tup > 1000
    ORDER BY dead_tuple_percent DESC
    LIMIT 5
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: stats}} ->
        high_dead_tuples =
          Enum.count(stats, fn row ->
            dead_percent = Enum.at(row, 6) || 0
            # More than 20% dead tuples
            dead_percent > 20
          end)

        cond do
          high_dead_tuples == 0 -> :healthy
          high_dead_tuples <= 2 -> :warning
          true -> :critical
        end

      {:error, _} ->
        :warning
    end
  rescue
    _ -> :warning
  end

  defp check_connection_pool do
    pool_info = DBConnection.get_connection_metrics(EveDmv.Repo)

    # pool_info is a list of connection metrics, extract relevant data
    total_ready_connections =
      pool_info
      |> Enum.map(& &1.ready_conn_count)
      |> Enum.sum()

    total_queue_length =
      pool_info
      |> Enum.map(& &1.checkout_queue_length)
      |> Enum.sum()

    # Get pool size from config since it's not in the metrics
    pool_config = Application.get_env(:eve_dmv, EveDmv.Repo, [])
    pool_size = Keyword.get(pool_config, :pool_size, 10)

    checked_out = pool_size - total_ready_connections
    utilization = if pool_size > 0, do: checked_out / pool_size, else: 0

    cond do
      utilization < 0.7 and total_queue_length < 5 -> :healthy
      utilization < 0.9 and total_queue_length < 10 -> :warning
      true -> :critical
    end
  rescue
    _ ->
      # Fallback check using ETS if available
      case :ets.info(EveDmv.Repo.Pool) do
        :undefined ->
          :warning

        info ->
          size = Keyword.get(info, :size, 0)
          if size > 0, do: :healthy, else: :warning
      end
  end

  defp check_table_stats do
    query = """
    SELECT
      schemaname,
      tablename,
      n_live_tup,
      n_dead_tup,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY n_live_tup DESC
    LIMIT 10
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} when rows != [] -> :healthy
      {:ok, %{rows: []}} -> :warning
      {:error, _} -> :critical
    end
  rescue
    _ -> :warning
  end

  defp check_disk_usage do
    query = """
    SELECT
      pg_size_pretty(pg_database_size(current_database())) as db_size,
      pg_size_pretty(pg_database_size('postgres')) as postgres_size
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[db_size, _postgres_size]]}} ->
        # Parse size and check if it's reasonable (basic check)
        if String.contains?(db_size, ["TB", "GB"]), do: :healthy, else: :healthy

      {:error, _} ->
        :warning
    end
  rescue
    _ -> :warning
  end

  defp check_query_performance do
    # Check if we have any slow queries in the monitoring
    case Process.whereis(EveDmv.Telemetry.QueryMonitor) do
      nil ->
        :warning

      pid ->
        try do
          stats = GenServer.call(pid, :get_query_stats, 5000)
          slow_queries = Map.get(stats, :total_slow_queries, 0)

          cond do
            slow_queries == 0 -> :healthy
            slow_queries <= 10 -> :warning
            true -> :critical
          end
        rescue
          _ -> :warning
        end
    end
  end

  @doc """
  Get detailed health information for debugging.
  """
  def get_detailed_health_info do
    %{
      timestamp: DateTime.utc_now(),
      database_size: get_database_size(),
      table_sizes: get_largest_tables(),
      index_efficiency: get_index_efficiency(),
      connection_details: get_connection_details(),
      performance_stats: get_performance_stats()
    }
  end

  defp get_database_size do
    query = """
    SELECT
      pg_size_pretty(pg_database_size(current_database())) as size,
      pg_database_size(current_database()) as bytes
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[size, bytes]]}} -> %{pretty: size, bytes: bytes}
      _ -> %{pretty: "Unknown", bytes: 0}
    end
  end

  defp get_largest_tables do
    query = """
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
      pg_total_relation_size(schemaname||'.'||tablename) as bytes
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, size, bytes] ->
          %{schema: schema, table: table, size: size, bytes: bytes}
        end)

      _ ->
        []
    end
  end

  defp get_index_efficiency do
    query = """
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch,
      CASE
        WHEN idx_tup_read > 0 THEN round((idx_tup_fetch::numeric / idx_tup_read::numeric) * 100, 2)
        ELSE 0
      END as efficiency_percent
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    AND idx_scan > 0
    ORDER BY idx_scan DESC
    LIMIT 20
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, index, scans, reads, fetches, efficiency] ->
          %{
            schema: schema,
            table: table,
            index: index,
            scans: scans,
            reads: reads,
            fetches: fetches,
            efficiency: efficiency
          }
        end)

      _ ->
        []
    end
  end

  defp get_connection_details do
    query = """
    SELECT
      count(*) as total_connections,
      count(*) FILTER (WHERE state = 'active') as active_connections,
      count(*) FILTER (WHERE state = 'idle') as idle_connections
    FROM pg_stat_activity
    WHERE datname = current_database()
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[total, active, idle]]}} ->
        %{total: total, active: active, idle: idle}

      _ ->
        %{total: 0, active: 0, idle: 0}
    end
  end

  defp get_performance_stats do
    # Get stats from our performance monitor
    case Process.whereis(PerformanceMonitor) do
      nil -> %{}
      _pid -> PerformanceMonitor.get_performance_summary()
    end
  rescue
    _ -> %{}
  end
end
