defmodule EveDmvWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug to require admin privileges for protected routes.

  This plug ensures that:
  1. User is authenticated
  2. User has admin privileges (is_admin = true)

  Redirects non-admin users with appropriate error messages.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, "current_user_id") do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/login")
        |> halt()

      user_id ->
        case get_user_with_admin_check(user_id) do
          {:ok, %{is_admin: true}} ->
            # User is authenticated and is admin
            assign(conn, :current_admin, true)

          {:ok, %{is_admin: false}} ->
            # User is authenticated but not admin
            conn
            |> put_flash(:error, "Access denied. Administrator privileges required.")
            |> redirect(to: "/dashboard")
            |> halt()

          {:error, _} ->
            # User not found, clear session and redirect to login
            conn
            |> clear_session()
            |> put_flash(:error, "Session expired. Please log in again.")
            |> redirect(to: "/login")
            |> halt()
        end
    end
  end

  defp get_user_with_admin_check(user_id) do
    case Ash.get(EveDmv.Users.User, user_id, domain: EveDmv.Api) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :user_not_found}

      {:error, _error} ->
        {:error, :database_error}
    end
  end
end
