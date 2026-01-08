defmodule EveDmv.Platform.Database.ConnectionPoolMonitor do
  @moduledoc """
  Monitors database connection pool health and metrics.

  Tracks connection pool size, queue length, available connections,
  and provides alerts when thresholds are exceeded.
  """

  use GenServer

  alias EveDmv.Repo
  alias EveDmv.Telemetry.PerformanceMonitor

  require Logger

  @check_interval :timer.seconds(30)
  @pool_size_warning_threshold 0.8
  @queue_length_warning_threshold 10

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_pool_stats do
    GenServer.call(__MODULE__, :get_pool_stats)
  end

  def get_pool_health do
    GenServer.call(__MODULE__, :get_pool_health)
  end

  def force_check do
    GenServer.cast(__MODULE__, :force_check)
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      check_interval: Keyword.get(opts, :check_interval, @check_interval),
      stats_history: [],
      alerts: [],
      last_check: nil
    }

    if state.enabled do
      schedule_check(state.check_interval)
      # Initial check
      Process.send_after(self(), :check_pool, 1000)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_pool_stats, _from, state) do
    stats = collect_pool_stats()
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:get_pool_health, _from, state) do
    health = analyze_pool_health(state)
    {:reply, health, state}
  end

  @impl GenServer
  def handle_cast(:force_check, state) do
    perform_check(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:check_pool, state) do
    new_state = perform_check(state)
    schedule_check(state.check_interval)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_check(interval) do
    Process.send_after(self(), :check_pool, interval)
  end

  defp perform_check(state) do
    stats = collect_pool_stats()
    alerts = check_for_alerts(stats)

    # Log alerts
    Enum.each(alerts, fn alert ->
      Logger.warning("Connection pool alert: #{alert.message}")
    end)

    # Track metrics
    track_telemetry_metrics(stats)

    # Check pool health and emit alerts for critical conditions
    check_pool_health(stats)

    # Update state
    new_history =
      Enum.take([%{timestamp: DateTime.utc_now(), stats: stats} | state.stats_history], 100)

    # Keep last 100 checks

    %{state | stats_history: new_history, alerts: alerts, last_check: DateTime.utc_now()}
  end

  defp collect_pool_stats do
    pool_config = Application.get_env(:eve_dmv, Repo, [])
    pool_size = Keyword.get(pool_config, :pool_size, 10)

    # Query pg_stat_activity for actual connection information
    query = """
    SELECT
      count(*) FILTER (WHERE state = 'active') as active,
      count(*) FILTER (WHERE state = 'idle') as idle,
      count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
      count(*) FILTER (WHERE wait_event_type = 'Client' AND wait_event = 'ClientRead') as waiting_for_client,
      count(*) as total
    FROM pg_stat_activity
    WHERE datname = current_database()
      AND pid != pg_backend_pid()
      AND backend_type = 'client backend'
    """

    {active, idle, idle_in_tx, _waiting_for_client, total} =
      case Ecto.Adapters.SQL.query(Repo, query) do
        {:ok, %{rows: [[active, idle, idle_in_tx, waiting, total]]}} ->
          {active || 0, idle || 0, idle_in_tx || 0, waiting || 0, total || 0}

        _ ->
          # Fallback if query fails
          {0, pool_size, 0, 0, pool_size}
      end

    # Calculate utilization based on active connections vs pool size
    checked_out = active + idle_in_tx
    available = max(0, pool_size - checked_out)
    # Queue length estimated from connections exceeding pool size
    queue_length = max(0, total - pool_size)
    utilization = if pool_size > 0, do: checked_out / pool_size, else: 0.0

    stats = %{
      pool_size: pool_size,
      checked_out: checked_out,
      checked_in: idle,
      available: available,
      queue_length: queue_length,
      max_connections: pool_size,
      utilization: utilization,
      active_connections: active,
      idle_connections: idle,
      idle_in_transaction: idle_in_tx,
      total_connections: total,
      timestamp: DateTime.utc_now()
    }

    # Add derived metrics
    Map.merge(stats, %{
      connections_in_use: stats.checked_out,
      connections_available: stats.available,
      pool_utilization_percent: stats.utilization * 100,
      is_pool_stressed: pool_stressed?(stats)
    })
  rescue
    error ->
      Logger.error("Failed to collect pool stats: #{inspect(error)}")

      %{
        error: "Failed to collect stats",
        timestamp: DateTime.utc_now()
      }
  end

  defp pool_stressed?(stats) do
    utilization = Map.get(stats, :utilization, 0.0)
    queue_length = Map.get(stats, :queue_length, 0)

    high_utilization = utilization > @pool_size_warning_threshold
    high_queue = queue_length > @queue_length_warning_threshold

    high_utilization or high_queue
  end

  defp check_for_alerts(stats) do
    initial_alerts = []

    # Check pool utilization
    alerts_after_utilization =
      if stats.utilization > @pool_size_warning_threshold do
        alert = %{
          type: :high_pool_utilization,
          severity: :warning,
          message: "High pool utilization: #{round(stats.utilization * 100)}%",
          value: stats.utilization,
          threshold: @pool_size_warning_threshold,
          timestamp: DateTime.utc_now()
        }

        [alert | initial_alerts]
      else
        initial_alerts
      end

    # Check queue length
    alerts_after_queue =
      if stats.queue_length > @queue_length_warning_threshold do
        alert = %{
          type: :high_queue_length,
          severity: :warning,
          message: "High queue length: #{stats.queue_length} connections waiting",
          value: stats.queue_length,
          threshold: @queue_length_warning_threshold,
          timestamp: DateTime.utc_now()
        }

        [alert | alerts_after_utilization]
      else
        alerts_after_utilization
      end

    # Check if pool is completely exhausted
    final_alerts =
      if stats.available == 0 and stats.queue_length > 0 do
        alert = %{
          type: :pool_exhausted,
          severity: :critical,
          message: "Connection pool exhausted: #{stats.queue_length} connections queued",
          value: 0,
          threshold: 0,
          timestamp: DateTime.utc_now()
        }

        [alert | alerts_after_queue]
      else
        alerts_after_queue
      end

    final_alerts
  end

  defp track_telemetry_metrics(stats) do
    if Map.has_key?(stats, :pool_size) do
      # Track pool metrics via telemetry
      PerformanceMonitor.track_database_metric("pool_utilization", stats.utilization)
      PerformanceMonitor.track_database_metric("queue_length", stats.queue_length)
      PerformanceMonitor.track_database_metric("available_connections", stats.available)
      PerformanceMonitor.track_database_metric("checked_out_connections", stats.checked_out)

      # Emit detailed telemetry events for monitoring dashboards
      utilization_percent = stats.utilization * 100

      :telemetry.execute(
        [:eve_dmv, :database, :pool, :utilization],
        %{value: utilization_percent},
        %{}
      )

      :telemetry.execute(
        [:eve_dmv, :database, :pool, :queue_length],
        %{value: stats.queue_length},
        %{}
      )

      :telemetry.execute(
        [:eve_dmv, :database, :pool, :available],
        %{value: stats.available},
        %{}
      )
    end
  end

  defp check_pool_health(stats) do
    utilization_percent = Map.get(stats, :utilization, 0.0) * 100
    queue_length = Map.get(stats, :queue_length, 0)

    cond do
      utilization_percent >= 95.0 ->
        Logger.error(
          "Database pool critical: #{Float.round(utilization_percent, 1)}% utilized, #{queue_length} waiting"
        )

        emit_alert(:pool_exhaustion, :critical, stats)

      utilization_percent >= 80.0 ->
        Logger.warning("Database pool warning: #{Float.round(utilization_percent, 1)}% utilized")
        emit_alert(:pool_high_utilization, :warning, stats)

      queue_length > 10 ->
        Logger.warning("Database pool queue building: #{queue_length} waiting")
        emit_alert(:pool_queue_building, :warning, stats)

      true ->
        :ok
    end
  end

  defp emit_alert(type, severity, stats) do
    utilization_percent = Map.get(stats, :utilization, 0.0) * 100
    queue_length = Map.get(stats, :queue_length, 0)

    :telemetry.execute(
      [:eve_dmv, :database, :pool, :alert],
      %{utilization: utilization_percent, queue_length: queue_length},
      %{type: type, severity: severity}
    )

    Phoenix.PubSub.broadcast(
      EveDmv.PubSub,
      "performance:alerts",
      {:pool_alert, type, severity, stats}
    )
  end

  defp analyze_pool_health(state) do
    recent_stats = Enum.take(state.stats_history, 10)
    recent_alerts = state.alerts

    cond do
      Enum.any?(recent_alerts, &(&1.severity == :critical)) ->
        %{
          status: :critical,
          message: "Critical pool issues detected",
          alerts: recent_alerts,
          recommendation: "Immediate attention required - pool may be exhausted"
        }

      Enum.any?(recent_alerts, &(&1.severity == :warning)) ->
        %{
          status: :warning,
          message: "Pool performance issues detected",
          alerts: recent_alerts,
          recommendation: "Monitor closely, consider increasing pool size or optimizing queries"
        }

      length(recent_stats) > 5 ->
        utilization_values =
          recent_stats
          |> Enum.map(&get_in(&1, [:stats, :utilization]))
          |> Enum.reject(&is_nil/1)

        avg_utilization = calculate_average(utilization_values)

        if avg_utilization > 0.6 do
          %{
            status: :degraded,
            message: "Elevated pool utilization",
            average_utilization: avg_utilization,
            recommendation: "Consider optimizing query performance or increasing pool size"
          }
        else
          %{
            status: :healthy,
            message: "Pool operating normally",
            average_utilization: avg_utilization
          }
        end

      true ->
        %{
          status: :unknown,
          message: "Insufficient data for health assessment"
        }
    end
  end

  # Public API for external monitoring

  def get_current_metrics do
    case collect_pool_stats() do
      %{error: _} = error_stats ->
        error_stats

      stats ->
        %{
          pool_health: if(stats.is_pool_stressed, do: :stressed, else: :healthy),
          utilization_percent: round(stats.utilization * 100),
          connections_available: stats.available,
          connections_in_use: stats.checked_out,
          queue_length: stats.queue_length,
          timestamp: stats.timestamp
        }
    end
  end

  def get_pool_recommendations do
    stats = collect_pool_stats()

    cond do
      Map.has_key?(stats, :error) ->
        ["Unable to analyze pool - check database connectivity"]

      stats.utilization > 0.9 ->
        [
          "Critical: Increase pool size immediately",
          "Optimize long-running queries",
          "Consider connection pooling strategies"
        ]

      stats.utilization > 0.8 ->
        [
          "Warning: Consider increasing pool size",
          "Monitor query performance",
          "Review connection usage patterns"
        ]

      stats.queue_length > 5 ->
        [
          "High queue length detected",
          "Investigate slow queries",
          "Consider increasing pool size"
        ]

      true ->
        ["Pool is operating within normal parameters"]
    end
  end

  # Helper function to safely extract pool statistics

  defp calculate_average([]), do: 0.0
  defp calculate_average(values), do: Enum.sum(values) / length(values)
end
