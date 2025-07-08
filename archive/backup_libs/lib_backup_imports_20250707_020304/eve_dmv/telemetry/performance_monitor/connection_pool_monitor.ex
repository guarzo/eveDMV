defmodule EveDmv.Telemetry.PerformanceMonitor.ConnectionPoolMonitor do
  alias Ecto.Adapters.SQL

  require Logger
  @moduledoc """
  Monitors database connection pool health and metrics.

  Tracks connection usage, pool utilization, and identifies potential
  connection-related issues.
  """


  @doc """
  Get connection pool metrics.
  """
  def get_pool_metrics do
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

    case SQL.query(EveDmv.Repo, query) do
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
    error in [Ecto.QueryError, DBConnection.ConnectionError, Postgrex.Error] ->
      Logger.warning("Database query error in pool metrics: #{inspect(error)}")
      %{error: "Failed to get pool metrics"}

    error ->
      Logger.error("Unexpected error in pool metrics: #{inspect(error)}")
      %{error: "Failed to get pool metrics"}
  end

  @doc """
  Monitor connection health metrics.
  """
  def monitor_connection_health do
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

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: [[total, active, idle, idle_tx, waiting, longest_query]]}} ->
        build_connection_health_metrics(total, active, idle, idle_tx, waiting, longest_query)

      {:error, _} ->
        %{has_issues: true, issues: ["failed_to_query_connections"]}
    end
  end

  @doc """
  Get detailed connection information.
  """
  def get_connection_details do
    query = """
    SELECT
      pid,
      usename,
      application_name,
      client_addr,
      state,
      state_change,
      wait_event_type,
      wait_event,
      EXTRACT(EPOCH FROM (now() - backend_start)) as connection_age_seconds,
      EXTRACT(EPOCH FROM (now() - query_start)) as query_duration_seconds,
      LEFT(query, 100) as current_query
    FROM pg_stat_activity
    WHERE datname = current_database()
      AND pid != pg_backend_pid()
    ORDER BY backend_start
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            pid,
                            user,
                            app,
                            addr,
                            state,
                            state_change,
                            wait_type,
                            wait_event,
                            conn_age,
                            query_dur,
                            query
                          ] ->
          %{
            pid: pid,
            username: user,
            application_name: app,
            client_address: addr,
            state: state,
            state_changed_at: state_change,
            wait_event_type: wait_type,
            wait_event: wait_event,
            connection_age_seconds: conn_age,
            query_duration_seconds: query_dur,
            current_query: query,
            is_problematic: problematic_connection?(state, query_dur, wait_event)
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Check for connection pool saturation.
  """
  def check_pool_saturation do
    metrics = get_pool_metrics()
    config = EveDmv.Repo.config()
    pool_size = Keyword.get(config, :pool_size, 10)

    saturation_threshold = 0.8
    current_utilization = (metrics[:total_connections] || 0) / pool_size

    %{
      pool_size: pool_size,
      used_connections: metrics[:total_connections] || 0,
      utilization_percent: Float.round(current_utilization * 100, 2),
      is_saturated: current_utilization >= saturation_threshold,
      available_connections: pool_size - (metrics[:total_connections] || 0),
      recommendations: generate_pool_recommendations(current_utilization, metrics)
    }
  end

  @doc """
  Monitor for idle in transaction connections.
  """
  def check_idle_transactions do
    query = """
    SELECT
      pid,
      usename,
      application_name,
      EXTRACT(EPOCH FROM (now() - state_change)) as idle_duration_seconds,
      LEFT(query, 100) as last_query
    FROM pg_stat_activity
    WHERE datname = current_database()
      AND state = 'idle in transaction'
      AND state_change < now() - interval '1 minute'
    ORDER BY state_change
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        idle_transactions =
          Enum.map(rows, fn [pid, user, app, duration, query] ->
            %{
              pid: pid,
              username: user,
              application_name: app,
              idle_duration_seconds: duration,
              last_query: query,
              severity: categorize_idle_severity(duration)
            }
          end)

        %{
          count: length(idle_transactions),
          transactions: idle_transactions,
          has_issues: length(idle_transactions) > 0,
          recommendations: generate_idle_recommendations(idle_transactions)
        }

      {:error, _} ->
        %{count: 0, transactions: [], has_issues: false}
    end
  end

  @doc """
  Get connection pool configuration recommendations.
  """
  def analyze_pool_configuration do
    metrics = get_pool_metrics()
    health = monitor_connection_health()
    config = EveDmv.Repo.config()
    pool_size = Keyword.get(config, :pool_size, 10)

    %{
      current_configuration: %{
        pool_size: pool_size,
        timeout: Keyword.get(config, :timeout, 15_000),
        queue_target: Keyword.get(config, :queue_target, 50),
        queue_interval: Keyword.get(config, :queue_interval, 1000)
      },
      current_metrics: metrics,
      health_status: health,
      recommendations: analyze_and_recommend(metrics, health, pool_size)
    }
  end

  # Private helper functions

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

  defp problematic_connection?(state, query_duration, wait_event) do
    cond do
      state == "idle in transaction" -> true
      # 5 minutes
      query_duration && query_duration > 300 -> true
      wait_event not in [nil, "ClientRead", "ClientWrite"] -> true
      true -> false
    end
  end

  defp generate_pool_recommendations(utilization, metrics) do
    recommendations = []

    recommendations =
      if utilization > 0.8 do
        ["Consider increasing pool_size - current utilization is above 80%" | recommendations]
      else
        recommendations
      end

    recommendations =
      if metrics[:waiting_connections] > 0 do
        ["Connections are waiting for available slots" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Connection pool is healthy"]
    else
      recommendations
    end
  end

  defp categorize_idle_severity(duration_seconds) do
    cond do
      # > 1 hour
      duration_seconds > 3600 -> :critical
      # > 10 minutes
      duration_seconds > 600 -> :high
      # > 5 minutes
      duration_seconds > 300 -> :medium
      true -> :low
    end
  end

  defp generate_idle_recommendations(idle_transactions) do
    critical_count = Enum.count(idle_transactions, &(&1.severity == :critical))

    recommendations = []

    recommendations =
      if critical_count > 0 do
        [
          "#{critical_count} connections idle in transaction for over 1 hour - investigate immediately"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if length(idle_transactions) > 3 do
        [
          "Multiple idle transactions detected - review transaction handling in application"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["No idle transaction issues detected"]
    else
      recommendations
    end
  end

  defp analyze_and_recommend(metrics, health, pool_size) do
    recommendations = []

    # Check utilization
    utilization = metrics[:utilization] || 0

    recommendations =
      cond do
        utilization > 90 ->
          [
            "URGENT: Pool utilization above 90% - increase pool_size immediately"
            | recommendations
          ]

        utilization > 75 ->
          ["Pool utilization above 75% - consider increasing pool_size" | recommendations]

        utilization < 20 and pool_size > 20 ->
          [
            "Pool utilization below 20% - consider reducing pool_size to save resources"
            | recommendations
          ]

        true ->
          recommendations
      end

    # Check for issues
    recommendations =
      if health[:has_issues] do
        health[:issues]
        |> Enum.map(fn
          "near_pool_limit" -> "Connection pool is near capacity"
          "idle_in_transaction" -> "Idle transactions detected - review transaction handling"
          "long_running_queries" -> "Long running queries detected - review query optimization"
          issue -> issue
        end)
        |> Enum.concat(recommendations)
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Connection pool configuration is optimal"]
    else
      recommendations
    end
  end
end
