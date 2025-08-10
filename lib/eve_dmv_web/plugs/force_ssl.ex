defmodule EveDmvWeb.Plugs.ForceSSL do
  @moduledoc """
  Simple HTTPS enforcement for production environments.

  This plug redirects HTTP requests to HTTPS in production while
  allowing normal operation in development.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    if should_force_ssl?() do
      # Use Phoenix's built-in SSL plug
      Plug.SSL.call(conn, Plug.SSL.init(rewrite_on: [:x_forwarded_proto]))
    else
      conn
    end
  end

  defp should_force_ssl? do
    Application.get_env(:eve_dmv, :force_ssl, false) or
      Application.get_env(:eve_dmv, EveDmvWeb.Endpoint)[:force_ssl] != nil
  end
end
