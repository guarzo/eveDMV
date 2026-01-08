defmodule EveDmvWeb.HealthController do
  @moduledoc """
  Health check endpoint for deployment verification and monitoring.
  """

  use EveDmvWeb, :controller

  import Plug.Conn

  alias EveDmv.Platform.Database.HealthCheck
  alias EveDmv.Platform.Monitoring.HealthAggregator

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
  """
  def detailed(conn, _params) do
    health = get_health_safely()

    conn
    |> put_status(200)
    |> json(health)
  end

  defp get_health_safely do
    HealthAggregator.get_health_snapshot()
  rescue
    _ ->
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
end
