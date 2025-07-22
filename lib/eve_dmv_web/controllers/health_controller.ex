defmodule EveDmvWeb.HealthController do
  @moduledoc """
  Health check endpoint for deployment verification and monitoring.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Database.HealthCheck

  @doc """
  Health check endpoint for load balancers and monitoring systems.
  Returns 200 OK if the application and database are healthy.
  """
  def check(conn, _params) do
    HealthCheck.check(case) do
      :ok ->
        conn
    put_status(200)
    json(%{
          status: "healthy",
          timestamp: DateTime.utc_now(),
          version: :eve_dmv |> Application.spec(:vsn) to_string(),
          environment: Application.get_env(:eve_dmv, :environment, "unknown"),
          services: %{
            database: "healthy",
            application: "healthy"
          }
        })

      {:error, reason} ->
        conn
    put_status(503)
    json(%{
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
