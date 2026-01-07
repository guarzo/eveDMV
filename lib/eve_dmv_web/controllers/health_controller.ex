defmodule EveDmvWeb.HealthController do
  @moduledoc """
  Health check endpoint for deployment verification and monitoring.
  """

  use EveDmvWeb, :controller

  import Plug.Conn

  alias EveDmv.Platform.Database.HealthCheck

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
end
