defmodule EveDmvWeb.Plugs.LinkToAccountPlug do
  @moduledoc """
  Plug to capture the link_to_account parameter before OAuth redirect.

  When a user clicks "Add Another Character", we need to remember their intent
  to link the new character to their existing account. Since query params don't
  survive the OAuth redirect, we store this in the session.
  """

  import Plug.Conn

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only set the flag on the INITIAL request (not the callback)
    # The initial request is exactly "/auth/user/eve_sso" without "/callback"
    is_initial_request = conn.request_path == "/auth/user/eve_sso"

    if is_initial_request do
      case conn.query_params do
        %{"link_to_account" => "true"} ->
          Logger.info("LinkToAccountPlug: Setting link_to_account flag in session")
          put_session(conn, "link_to_account", true)

        _ ->
          # Only clear on initial request without the flag (fresh login)
          Logger.debug("LinkToAccountPlug: Fresh login, clearing any stale link_to_account flag")
          delete_session(conn, "link_to_account")
      end
    else
      # Don't touch the session on callback or other requests
      conn
    end
  end
end
