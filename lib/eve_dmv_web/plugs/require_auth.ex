defmodule EveDmvWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug to require user authentication for protected routes.

  Redirects unauthenticated users to the login page.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, "current_user_id") do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
