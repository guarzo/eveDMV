defmodule EveDmvWeb.AuthController do
  @moduledoc """
  Authentication controller handling EVE SSO login/logout flows.

  Manages user authentication via EVE Online SSO and session handling.
  """

  use EveDmvWeb, :controller
  use AshAuthentication.Phoenix.Controller

  import Plug.Conn

  alias EveDmv.Security.AuditLogger
  alias EveDmv.Users.AccountManager

  require Logger

  def success(conn, _activity, user, _token) do
    # Log successful authentication
    client_ip = get_client_ip(conn)
    AuditLogger.log_auth_attempt(user.id, client_ip, true)

    # Check if this is a "link to account" request (adding character to existing account)
    # The link_to_account flag is stored in session by LinkToAccountPlug before OAuth redirect
    existing_account_id = get_session(conn, "current_account_id")
    link_to_account? = get_session(conn, "link_to_account") == true

    Logger.info(
      "AuthController.success - link_to_account?: #{link_to_account?}, existing_account_id: #{inspect(existing_account_id)}, user.account_id: #{inspect(user.account_id)}"
    )

    result =
      cond do
        # User wants to link to existing account and has an active session
        link_to_account? && existing_account_id && is_nil(user.account_id) ->
          # Character has no account yet - link it to the existing account
          Logger.info(
            "Linking new character #{user.eve_character_name} to existing account #{existing_account_id}"
          )

          AccountManager.link_character_to_account(user, existing_account_id)

        link_to_account? && existing_account_id && user.account_id == existing_account_id ->
          # Character is already in this account - just return success
          Logger.info(
            "Character #{user.eve_character_name} is already in account #{existing_account_id}"
          )

          {:ok, AccountManager.get_account_by_id!(existing_account_id), user}

        link_to_account? && existing_account_id && user.account_id != existing_account_id ->
          # Character is linked to a DIFFERENT account - need to re-link
          Logger.info(
            "Re-linking character #{user.eve_character_name} from account #{user.account_id} to #{existing_account_id}"
          )

          AccountManager.relink_character_to_account(user, existing_account_id)

        # User already has an account or normal login
        true ->
          case AccountManager.ensure_user_account(user) do
            {:ok, account} -> {:ok, account, user}
            error -> error
          end
      end

    # Clear the link_to_account flag after use
    conn = delete_session(conn, "link_to_account")

    case result do
      {:ok, account, updated_user} ->
        # Update account activity
        AccountManager.update_account_activity(account.id)

        message =
          if link_to_account? && existing_account_id do
            "Character #{updated_user.eve_character_name} added to your account!"
          else
            "Welcome back, #{updated_user.eve_character_name || "pilot"}!"
          end

        conn
        |> store_in_session(updated_user)
        |> assign(:current_user, updated_user)
        |> assign(:current_account, account)
        |> put_session("current_user_id", updated_user.id)
        |> put_session("current_account_id", account.id)
        |> put_session("last_activity", System.system_time(:millisecond))
        |> put_flash(:info, message)
        |> redirect(to: ~p"/dashboard")

      {:ok, account} ->
        # Fallback for ensure_user_account which returns {:ok, account}
        AccountManager.update_account_activity(account.id)

        conn
        |> store_in_session(user)
        |> assign(:current_user, user)
        |> assign(:current_account, account)
        |> put_session("current_user_id", user.id)
        |> put_session("current_account_id", account.id)
        |> put_session("last_activity", System.system_time(:millisecond))
        |> put_flash(:info, "Welcome back, #{user.eve_character_name || "pilot"}!")
        |> redirect(to: ~p"/dashboard")

      {:error, :already_linked_to_different_account} ->
        conn
        |> put_flash(:error, "This character is already linked to a different account.")
        |> redirect(to: ~p"/dashboard")

      {:error, :already_linked_to_this_account} ->
        conn
        |> put_flash(:info, "This character is already in your account.")
        |> redirect(to: ~p"/dashboard")

      {:error, :character_limit_reached} ->
        conn
        |> put_flash(:error, "Maximum character limit reached for this account.")
        |> redirect(to: ~p"/dashboard")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Account setup failed: #{inspect(reason)}")
        |> redirect(to: ~p"/")
    end
  end

  def failure(conn, activity, reason) do
    require Logger
    Logger.error("AUTH FAILURE - activity: #{inspect(activity)}, reason: #{inspect(reason)}")

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
