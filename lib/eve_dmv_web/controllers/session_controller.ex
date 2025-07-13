defmodule EveDmvWeb.SessionController do
  @moduledoc """
  Controller for session management operations.
  """

  use EveDmvWeb, :controller

  def clear(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Session cleared successfully.")
    |> redirect(to: ~p"/login")
  end
end
