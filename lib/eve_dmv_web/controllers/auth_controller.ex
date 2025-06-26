defmodule EveDmvWeb.AuthController do
  @moduledoc """
  Authentication controller handling EVE SSO login/logout flows.

  Manages user authentication via EVE Online SSO and session handling.
  """

  use EveDmvWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_flash(:info, "Welcome back, #{user.eve_character_name || "pilot"}!")
    |> redirect(to: ~p"/dashboard")
  end

  def failure(conn, _activity, _reason) do
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
end
