defmodule EveDmvWeb.Plugs.SessionActivity do
  @moduledoc """
  Plug to track session activity for timeout handling.

  Updates the last_activity timestamp in the session for authenticated users
  to enable proper session timeout functionality.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, "current_user_id") do
      put_session(conn, "last_activity", System.system_time(:millisecond))
    else
      conn
    end
  end
end
