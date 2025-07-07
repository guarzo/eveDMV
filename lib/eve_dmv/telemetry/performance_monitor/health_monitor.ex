defmodule EveDmv.Telemetry.PerformanceMonitor.HealthMonitor do
  @moduledoc """
  Real-time database health monitoring.

  Monitors query health, lock contention, replication lag, and provides
  comprehensive health status reporting.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Telemetry.PerformanceMonitor.ConnectionPoolMonitor
  require Logger

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

  @doc """
  Monitor query health and performance.
  """
  def monitor_query_health do
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

    case SQL.query(EveDmv.Repo, query) do
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

  @doc """
  Monitor lock contention in the database.
  """
  def monitor_lock_contention do
    query = """
    SELECT
      count(*) as blocked_queries,
      count(DISTINCT blocked.pid) as blocked_pids,
      array_agg(DISTINCT blocking.query ORDER BY blocking.query) as blocking_queries
    FROM pg_stat_activity blocked
    JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
    WHERE blocked.wait_event_type = 'Lock'
    """

    case SQL.query(EveDmv.Repo, query) do
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

  @doc """
  Check replication lag if applicable.
  """
  def check_replication_lag do
    # Check if this instance has any replicas
    query = """
    SELECT
      client_addr,
      state,
      sent_lsn,
      write_lsn,
      flush_lsn,
      replay_lsn,
      pg_wal_lsn_diff(sent_lsn, replay_lsn) as lag_bytes,
      write_lag,
      flush_lag,
      replay_lag
    FROM pg_stat_replication
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: []}} ->
        %{
          has_issues: false,
          issues: [],
          replicas: [],
          message: "No replication configured"
        }

      {:ok, %{rows: rows}} ->
        replicas =
          Enum.map(rows, fn [
                              addr,
                              state,
                              _sent,
                              _write,
                              _flush,
                              _replay,
                              lag_bytes,
                              write_lag,
                              flush_lag,
                              replay_lag
                            ] ->
            %{
              client_address: addr,
              state: state,
              lag_bytes: lag_bytes || 0,
              write_lag: write_lag,
              flush_lag: flush_lag,
              replay_lag: replay_lag,
              is_lagging: replica_lagging?(lag_bytes, replay_lag)
            }
          end)

        lagging_replicas = Enum.filter(replicas, & &1.is_lagging)

        %{
          has_issues: length(lagging_replicas) > 0,
          issues: if(length(lagging_replicas) > 0, do: ["replica_lag"], else: []),
          replicas: replicas,
          lagging_count: length(lagging_replicas)
        }

      {:error, _} ->
        %{
          has_issues: false,
          issues: [],
          lag_bytes: 0,
          lag_seconds: 0
        }
    end
  end

  @doc """
  Get comprehensive health summary.
  """
  def get_health_summary do
    health = monitor_database_health()

    %{
      timestamp: DateTime.utc_now(),
      overall_status: determine_overall_status(health),
      components: health,
      critical_issues: extract_critical_issues(health),
      warnings: extract_warnings(health),
      metrics: collect_key_metrics(health)
    }
  end

  @doc """
  Monitor long running transactions.
  """
  def monitor_long_transactions do
    query = """
    SELECT
      pid,
      usename,
      application_name,
      xact_start,
      EXTRACT(EPOCH FROM (now() - xact_start)) as duration_seconds,
      state,
      LEFT(query, 100) as current_query
    FROM pg_stat_activity
    WHERE xact_start IS NOT NULL
      AND xact_start < now() - interval '5 minutes'
    ORDER BY xact_start
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        transactions =
          Enum.map(rows, fn [pid, user, app, start, duration, state, query] ->
            %{
              pid: pid,
              username: user,
              application: app,
              started_at: start,
              duration_seconds: duration,
              duration_human: format_duration(duration),
              state: state,
              query: query,
              severity: categorize_transaction_severity(duration)
            }
          end)

        %{
          count: length(transactions),
          transactions: transactions,
          has_issues: length(transactions) > 0,
          critical_count: Enum.count(transactions, &(&1.severity == :critical))
        }

      {:error, _} ->
        %{count: 0, transactions: [], has_issues: false}
    end
  end

  @doc """
  Check database size and growth trends.
  """
  def monitor_database_size do
    query = """
    SELECT
      pg_database_size(current_database()) as size_bytes,
      pg_size_pretty(pg_database_size(current_database())) as size_pretty,
      (SELECT count(*) FROM pg_stat_user_tables) as table_count,
      (SELECT count(*) FROM pg_stat_user_indexes) as index_count
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[size_bytes, size_pretty, tables, indexes]]}} ->
        %{
          size_bytes: size_bytes,
          size: size_pretty,
          table_count: tables,
          index_count: indexes,
          warnings: generate_size_warnings(size_bytes)
        }

      {:error, _} ->
        %{error: "Failed to get database size"}
    end
  end

  @doc """
  Monitor autovacuum activity and effectiveness.
  """
  def monitor_autovacuum do
    query = """
    SELECT
      schemaname,
      tablename,
      last_vacuum,
      last_autovacuum,
      n_dead_tup,
      n_live_tup,
      ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) as dead_tuple_percent
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 1000
      OR (last_autovacuum IS NULL AND n_live_tup > 10000)
    ORDER BY n_dead_tup DESC
    LIMIT 20
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        tables_needing_vacuum =
          Enum.map(rows, fn [schema, table, vacuum, autovacuum, dead, live, dead_pct] ->
            %{
              schema: schema,
              table: table,
              last_vacuum: vacuum,
              last_autovacuum: autovacuum,
              dead_tuples: dead,
              live_tuples: live,
              dead_tuple_percent: dead_pct || 0,
              needs_vacuum: dead_pct && dead_pct > 20
            }
          end)

        %{
          tables_needing_vacuum: tables_needing_vacuum,
          count: length(tables_needing_vacuum),
          has_issues: length(tables_needing_vacuum) > 5,
          recommendations: generate_vacuum_recommendations(tables_needing_vacuum)
        }

      {:error, _} ->
        %{tables_needing_vacuum: [], count: 0, has_issues: false}
    end
  end

  # Private helper functions

  defp monitor_connection_health do
    # Delegate to ConnectionPoolMonitor for consistency
    ConnectionPoolMonitor.monitor_connection_health()
  end

  defp replica_lagging?(lag_bytes, replay_lag) do
    # Consider lagging if more than 100MB behind or replay lag > 1 minute
    lag_bytes > 100_000_000 or (replay_lag && elem(replay_lag, 0) > 0)
  end

  defp determine_overall_status(health) do
    critical_issues =
      Enum.any?(health, fn {_, component} ->
        component[:has_issues] and has_critical_issue?(component)
      end)

    warnings =
      Enum.any?(health, fn {_, component} ->
        component[:has_issues]
      end)

    cond do
      critical_issues -> :critical
      warnings -> :warning
      true -> :healthy
    end
  end

  defp has_critical_issue?(component) do
    Enum.any?(component[:issues] || [], fn issue ->
      issue in ["very_slow_queries", "lock_contention", "replica_lag"]
    end)
  end

  defp extract_critical_issues(health) do
    Enum.flat_map(health, fn {category, component} ->
      if component[:has_issues] do
        component[:issues]
        |> Enum.filter(&critical_issue?/1)
        |> Enum.map(&{category, &1})
      else
        []
      end
    end)
  end

  defp critical_issue?(issue) do
    issue in ["very_slow_queries", "lock_contention", "replica_lag", "near_pool_limit"]
  end

  defp extract_warnings(health) do
    Enum.flat_map(health, fn {category, component} ->
      if component[:has_issues] do
        component[:issues]
        |> Enum.reject(&critical_issue?/1)
        |> Enum.map(&{category, &1})
      else
        []
      end
    end)
  end

  defp collect_key_metrics(health) do
    %{
      active_connections: health.connections[:active] || 0,
      slow_queries: health.queries[:slow_queries] || 0,
      blocked_queries: health.locks[:blocked_queries] || 0,
      replica_lag_bytes: get_max_replica_lag(health.replication_lag)
    }
  end

  defp get_max_replica_lag(replication) do
    case replication[:replicas] do
      nil ->
        0

      [] ->
        0

      replicas ->
        replicas
        |> Enum.map(& &1.lag_bytes)
        |> Enum.max()
    end
  end

  defp format_duration(seconds) when is_number(seconds) do
    cond do
      seconds < 60 -> "#{round(seconds)}s"
      seconds < 3600 -> "#{round(seconds / 60)}m"
      seconds < 86_400 -> "#{round(seconds / 3600)}h"
      true -> "#{round(seconds / 86_400)}d"
    end
  end

  defp format_duration(_), do: "unknown"

  defp categorize_transaction_severity(duration_seconds) when is_number(duration_seconds) do
    cond do
      # > 1 hour
      duration_seconds > 3600 -> :critical
      # > 30 minutes
      duration_seconds > 1800 -> :high
      # > 10 minutes
      duration_seconds > 600 -> :medium
      true -> :low
    end
  end

  defp categorize_transaction_severity(_), do: :unknown

  defp generate_size_warnings(size_bytes) when is_number(size_bytes) do
    initial_warnings = []

    # 100GB
    warnings_with_100gb =
      if size_bytes > 100_000_000_000 do
        ["Database size exceeds 100GB - monitor growth rate" | initial_warnings]
      else
        initial_warnings
      end

    # 500GB
    warnings_with_500gb =
      if size_bytes > 500_000_000_000 do
        ["Database size exceeds 500GB - consider archiving strategy" | warnings_with_100gb]
      else
        warnings_with_100gb
      end

    warnings_with_500gb
  end

  defp generate_size_warnings(_), do: []

  defp generate_vacuum_recommendations(tables) do
    critical_tables = Enum.filter(tables, &(&1.dead_tuple_percent > 30))
    never_vacuumed = Enum.filter(tables, &(is_nil(&1.last_vacuum) and is_nil(&1.last_autovacuum)))

    initial_recommendations = []

    critical_recommendations =
      if length(critical_tables) > 0 do
        [
          "#{length(critical_tables)} tables have > 30% dead tuples - urgent vacuum needed"
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    final_recommendations =
      if length(never_vacuumed) > 0 do
        ["#{length(never_vacuumed)} tables have never been vacuumed" | critical_recommendations]
      else
        critical_recommendations
      end

    if Enum.empty?(final_recommendations) do
      ["Autovacuum is functioning normally"]
    else
      final_recommendations
    end
  end
end
