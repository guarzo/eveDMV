defmodule EveDmvWeb.HealthController do
  @moduledoc """
  Health check endpoint for deployment verification and monitoring.
  """

  use EveDmvWeb, :controller

  import Plug.Conn

  alias EveDmv.Platform.Database.HealthCheck
  alias EveDmv.Platform.Monitoring.HealthAggregator
  alias EveDmv.Telemetry.OtelSpans

  require Logger

  @doc """
  Health check endpoint for load balancers and monitoring systems.
  Returns 200 OK if the application and database are healthy.
  """
  def check(conn, _params) do
    # Debug static file paths
    static_path = Application.app_dir(:eve_dmv, "priv/static")
    assets_path = Path.join(static_path, "assets")

    static_exists = File.exists?(static_path)
    assets_exists = File.exists?(assets_path)

    static_files = if static_exists, do: File.ls!(static_path) |> Enum.take(10), else: []
    asset_files = if assets_exists, do: File.ls!(assets_path), else: []

    case HealthCheck.check() do
      :ok ->
        conn
        |> put_status(200)
        |> json(%{
          status: "healthy",
          timestamp: DateTime.utc_now(),
          version: :eve_dmv |> Application.spec(:vsn) |> to_string(),
          environment: Application.get_env(:eve_dmv, :environment, "unknown"),
          services: %{
            database: "healthy",
            application: "healthy"
          },
          debug: %{
            static_path: static_path,
            static_exists: static_exists,
            assets_exists: assets_exists,
            static_files: static_files,
            asset_files: asset_files
          }
        })

      {:error, reason} ->
        conn
        |> put_status(503)
        |> json(%{
          status: "unhealthy",
          timestamp: DateTime.utc_now(),
          error: to_string(reason),
          services: %{
            database: "unhealthy",
            application: "healthy"
          }
        })
    end
  end

  @doc """
  Simple health check for load balancers.
  Returns 200 if healthy, 503 if critical.
  """
  def index(conn, _params) do
    health = get_health_safely()

    # Map overall_status to HTTP status codes for load balancer health checks.
    # Return 200 for :healthy, :warning, and :degraded to keep the instance in
    # rotation - these states indicate the service is functional enough to serve
    # traffic. Only :critical (or unknown states) returns 503 to signal the load
    # balancer should take this instance out of service.
    status =
      case health.overall_status do
        :healthy -> 200
        :warning -> 200
        :degraded -> 200
        :critical -> 503
        _ -> 503
      end

    conn
    |> put_status(status)
    |> json(%{
      status: health.overall_status,
      timestamp: health.timestamp,
      uptime: health.uptime.formatted,
      components: %{
        database: health.database.status,
        pipeline: health.pipeline.status,
        cache: health.cache.status,
        memory: health.memory.status
      }
    })
  end

  @doc """
  Detailed health check with all metrics.

  NOTE: This endpoint intentionally returns HTTP 200 regardless of overall health status.
  This is by design for debugging and inspection purposes - operators can view the full
  health details (including all component statuses and metrics) even when the service
  is in a critical or degraded state. For load balancer probes and automated health
  checks that need status-appropriate HTTP codes, use index/2 instead, which reflects
  the aggregated health status in its response code (200 for healthy/warning/degraded,
  503 for critical).
  """
  # Always returns HTTP 200 for debugging/inspection so operators can view
  # full health details regardless of overall service state.
  def detailed(conn, _params) do
    health = get_health_safely()

    conn
    |> put_status(200)
    |> json(health)
  end

  defp get_health_safely do
    HealthAggregator.get_health_snapshot()
  rescue
    e in [RuntimeError, ArgumentError, KeyError, FunctionClauseError] ->
      Logger.error(
        "HealthAggregator.get_health_snapshot/0 raised #{inspect(e.__struct__)}: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      fallback_health_snapshot()

    e in [DBConnection.ConnectionError, Postgrex.Error] ->
      Logger.error(
        "HealthAggregator.get_health_snapshot/0 raised database exception #{inspect(e.__struct__)}: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      fallback_health_snapshot()

    e in [ErlangError, SystemLimitError] ->
      Logger.error(
        "HealthAggregator.get_health_snapshot/0 raised system exception #{inspect(e.__struct__)}: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      fallback_health_snapshot()

    e ->
      Logger.error(
        "HealthAggregator.get_health_snapshot/0 raised unexpected exception #{inspect(e.__struct__)}: #{Exception.format(:error, e, __STACKTRACE__)}"
      )

      fallback_health_snapshot()
  end

  defp fallback_health_snapshot do
    %{
      overall_status: :unknown,
      timestamp: DateTime.utc_now(),
      uptime: %{formatted: "unknown"},
      database: %{status: :unknown},
      pipeline: %{status: :unknown},
      cache: %{status: :unknown},
      memory: %{status: :unknown}
    }
  end

  @doc """
  Performance diagnostics endpoint for troubleshooting sluggishness.

  Returns detailed information about:
  - Background worker status (which workers are running, their state)
  - Active queries (currently executing, duration, whether slow)
  - Connection pool pressure (utilization, waiting connections)
  - Startup status (whether warmup tasks have completed)

  Always returns HTTP 200 for debugging purposes.
  """
  def diagnostics(conn, _params) do
    diagnostics = get_diagnostics_safely()

    conn
    |> put_status(200)
    |> json(diagnostics)
  end

  defp get_diagnostics_safely do
    OtelSpans.with_span(
      "health.diagnostics",
      %{module: __MODULE__, function: :get_diagnostics_safely},
      fn ->
        try do
          HealthAggregator.get_performance_diagnostics()
        rescue
          e ->
            Logger.error(
              "HealthAggregator.get_performance_diagnostics/0 raised #{inspect(e.__struct__)}: #{Exception.format(:error, e, __STACKTRACE__)}"
            )

            %{
              timestamp: DateTime.utc_now(),
              error: "Failed to collect diagnostics",
              message: Exception.message(e)
            }
        end
      end
    )
  end
end
