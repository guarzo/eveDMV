defmodule EveDmvWeb.AuthController do
  use AshAuthentication.Phoenix.Controller
  use EveDmvWeb, :controller

  alias EveDmv.Security.AuditLogger
  @moduledoc """
  Authentication controller handling EVE SSO login/logout flows.

  Manages user authentication via EVE Online SSO and session handling.
  """



  def success(conn, _activity, user, _token) do
    # Log successful authentication
    client_ip = get_client_ip(conn)
    AuditLogger.log_auth_attempt(user.id, client_ip, true)

    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_session("current_user_id", user.id)
    |> put_session("last_activity", System.system_time(:millisecond))
    |> put_flash(:info, "Welcome back, #{user.eve_character_name || "pilot"}!")
    |> redirect(to: ~p"/dashboard")
  end

  def failure(conn, _activity, _reason) do
    # Log failed authentication
    client_ip = get_client_ip(conn)
    AuditLogger.log_auth_attempt(nil, client_ip, false)

    conn
    |> put_flash(:error, "Authentication failed. Please try again.")
    |> redirect(to: ~p"/")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:eve_dmv)
    |> put_flash(:info, "You have been signed out.")
    |> redirect(to: ~p"/")
  end

  # Helper function to extract client IP address
  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips] ->
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
