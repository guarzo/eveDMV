defmodule EveDmvWeb.TokenRefreshPlug do
  @moduledoc """
  Plug that automatically checks and refreshes user tokens when they access the application.

  This plug runs before authenticated routes and ensures that user tokens are
  refreshed if they're about to expire, providing a seamless user experience.
  """

  import Plug.Conn
  require Logger

  alias EveDmv.Users.TokenRefreshService

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_current_user(conn) do
      nil ->
        # No authenticated user, continue normally
        conn

      user ->
        # Check if token needs refresh
        if TokenRefreshService.token_needs_refresh?(user) do
          Logger.debug(
            "🔄 User #{user.eve_character_name} token needs refresh, refreshing automatically"
          )

          case TokenRefreshService.refresh_user_token(user.id) do
            {:ok, updated_user} ->
              Logger.debug("✅ Token refreshed successfully for #{user.eve_character_name}")

              # Update the session with the refreshed user data
              conn
              |> put_session(:current_user_id, updated_user.id)
              |> assign(:current_user, updated_user)

            {:error, reason} ->
              Logger.warning(
                "❌ Failed to refresh token for #{user.eve_character_name}: #{inspect(reason)}"
              )

              # If token refresh fails, we could either:
              # 1. Continue with the expired token (current approach)
              # 2. Force logout and redirect to login
              # 3. Show a warning message

              # For now, continue with expired token but log the issue
              conn
          end
        else
          # Token is still valid, continue normally
          conn
        end
    end
  end

  # Helper function to get current user from conn
  defp get_current_user(conn) do
    # Try to get from assigns first (already loaded)
    case conn.assigns[:current_user] do
      nil ->
        # Try to get from session
        case get_session(conn, :current_user_id) do
          nil ->
            nil

          user_id ->
            # Load user from database
            case Ash.get(EveDmv.Users.User, user_id, domain: EveDmv.Api) do
              {:ok, user} -> user
              {:error, _} -> nil
            end
        end

      user ->
        user
    end
  end
end
