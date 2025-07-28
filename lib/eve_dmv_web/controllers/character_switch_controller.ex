defmodule EveDmvWeb.CharacterSwitchController do
  @moduledoc """
  Controller for handling character switching operations.

  Provides endpoints for switching between characters in a multi-character account.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Security.AuditLogger
  alias EveDmv.Users.AccountManager

  plug(:require_authenticated_user)

  @doc """
  Switches to a different character within the same account.
  """
  def switch(conn, %{"character_id" => character_id}) do
    current_user = conn.assigns.current_user
    account_id = get_session(conn, "current_account_id")

    if account_id do
      case AccountManager.switch_character(account_id, character_id) do
        {:ok, _updated_account, new_character} ->
          # Log the character switch
          client_ip = get_client_ip(conn)
          AuditLogger.log_character_switch(current_user.id, new_character.id, client_ip)

          # Update session with new character
          conn
          |> put_session("current_user_id", new_character.id)
          |> put_session("last_activity", System.system_time(:millisecond))
          |> put_flash(:info, "Switched to #{new_character.eve_character_name}")
          |> redirect(to: get_return_path(conn))

        {:error, :character_not_in_account} ->
          conn
          |> put_flash(:error, "Character not found in your account")
          |> redirect(to: get_return_path(conn))

        _ ->
          conn
          |> put_flash(:error, "Failed to switch character")
          |> redirect(to: get_return_path(conn))
      end
    else
      conn
      |> put_flash(:error, "No account found in session")
      |> redirect(to: ~p"/login")
    end
  end

  @doc """
  Sets a character as the primary character for the account.
  """
  def set_primary(conn, %{"character_id" => character_id}) do
    account_id = get_session(conn, "current_account_id")

    if account_id do
      case AccountManager.switch_character(account_id, character_id, true) do
        {:ok, _updated_account, character} ->
          conn
          |> put_flash(:info, "#{character.eve_character_name} is now your primary character")
          |> redirect(to: ~p"/profile")

        _ ->
          conn
          |> put_flash(:error, "Failed to set primary character")
          |> redirect(to: ~p"/profile")
      end
    else
      conn
      |> put_flash(:error, "No account found in session")
      |> redirect(to: ~p"/login")
    end
  end

  # Private functions

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp get_return_path(conn) do
    case get_session(conn, "return_to") do
      nil -> ~p"/dashboard"
      path -> path
    end
  end

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
