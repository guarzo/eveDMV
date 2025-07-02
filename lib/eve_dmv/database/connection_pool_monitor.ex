defmodule EveDmv.Database.ConnectionPoolMonitor do
  @moduledoc """
  Monitors database connection pool health and metrics.

  Tracks connection pool size, queue length, available connections,
  and provides alerts when thresholds are exceeded.
  """

  use GenServer
  require Logger

  alias EveDmv.Repo
  alias EveDmv.Telemetry.PerformanceMonitor

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

  def handle_call(:get_pool_stats, _from, state) do
    stats = collect_pool_stats()
    {:reply, stats, state}
  end

  def handle_call(:get_pool_health, _from, state) do
    health = analyze_pool_health(state)
    {:reply, health, state}
  end

  def handle_cast(:force_check, state) do
    perform_check(state)
    {:noreply, state}
  end

  def handle_info(:check_pool, state) do
    new_state = perform_check(state)
    schedule_check(state.check_interval)
    {:noreply, new_state}
  end

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

    # Update state
    new_history = [%{timestamp: DateTime.utc_now(), stats: stats} | state.stats_history]
                  |> Enum.take(100) # Keep last 100 checks

    %{state | 
      stats_history: new_history,
      alerts: alerts,
      last_check: DateTime.utc_now()
    }
  end

  defp collect_pool_stats do
    # Get pool configuration
      pool_config = Application.get_env(:eve_dmv, Repo, [])
      pool_size = Keyword.get(pool_config, :pool_size, 10)
      queue_target = Keyword.get(pool_config, :queue_target, 50)
      queue_interval = Keyword.get(pool_config, :queue_interval, 1000)

      # Collect DBConnection pool stats
      pool_stats = DBConnection.status(Repo, [])

      # Extract key metrics
      stats = %{
        pool_size: pool_size,
        checked_out: Map.get(pool_stats, :checked_out, 0),
        checked_in: Map.get(pool_stats, :checked_in, 0),
        available: Map.get(pool_stats, :available, 0),
        queue_length: Map.get(pool_stats, :queue_length, 0),
        max_connections: pool_size,
        queue_target: queue_target,
        queue_interval: queue_interval,
        utilization: calculate_utilization(pool_stats, pool_size),
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

  defp calculate_utilization(pool_stats, pool_size) do
    checked_out = Map.get(pool_stats, :checked_out, 0)
    if pool_size > 0 do
      checked_out / pool_size
    else
      0.0
    end
  end

  defp pool_stressed?(stats) do
    high_utilization = stats.utilization > @pool_size_warning_threshold
    high_queue = stats.queue_length > @queue_length_warning_threshold

    high_utilization or high_queue
  end

  defp check_for_alerts(stats) do
    alerts = []

    # Check pool utilization
    alerts = if stats.utilization > @pool_size_warning_threshold do
      alert = %{
        type: :high_pool_utilization,
        severity: :warning,
        message: "High pool utilization: #{round(stats.utilization * 100)}%",
        value: stats.utilization,
        threshold: @pool_size_warning_threshold,
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end

    # Check queue length
    alerts = if stats.queue_length > @queue_length_warning_threshold do
      alert = %{
        type: :high_queue_length,
        severity: :warning,
        message: "High queue length: #{stats.queue_length} connections waiting",
        value: stats.queue_length,
        threshold: @queue_length_warning_threshold,
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end

    # Check if pool is completely exhausted
    alerts = if stats.available == 0 and stats.queue_length > 0 do
      alert = %{
        type: :pool_exhausted,
        severity: :critical,
        message: "Connection pool exhausted: #{stats.queue_length} connections queued",
        value: 0,
        threshold: 0,
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end

    alerts
  end

  defp track_telemetry_metrics(stats) do
    if Map.has_key?(stats, :pool_size) do
      # Track pool metrics via telemetry
      PerformanceMonitor.track_database_metric("pool_utilization", stats.utilization)
      PerformanceMonitor.track_database_metric("queue_length", stats.queue_length)
      PerformanceMonitor.track_database_metric("available_connections", stats.available)
      PerformanceMonitor.track_database_metric("checked_out_connections", stats.checked_out)
    end
  end

  defp analyze_pool_health(state) do
    recent_stats = state.stats_history |> Enum.take(10)
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
        avg_utilization = recent_stats
                          |> Enum.map(&get_in(&1, [:stats, :utilization]))
                          |> Enum.reject(&is_nil/1)
                          |> case do
                            [] -> 0.0
                            values -> Enum.sum(values) / length(values)
                          end

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
        ["Critical: Increase pool size immediately",
         "Optimize long-running queries",
         "Consider connection pooling strategies"]

      stats.utilization > 0.8 ->
        ["Warning: Consider increasing pool size",
         "Monitor query performance",
         "Review connection usage patterns"]

      stats.queue_length > 5 ->
        ["High queue length detected",
         "Investigate slow queries",
         "Consider increasing pool size"]

      true ->
        ["Pool is operating within normal parameters"]
    end
  end
end
