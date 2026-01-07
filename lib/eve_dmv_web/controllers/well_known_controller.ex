defmodule EveDmvWeb.WellKnownController do
  @moduledoc """
  Handles .well-known requests (Chrome DevTools, etc.) with empty responses.
  Prevents 404 errors from cluttering logs during development.
  """

  use EveDmvWeb, :controller

  @doc """
  Returns 204 No Content for any .well-known request.
  """
  def index(conn, _params) do
    conn
    |> put_status(:no_content)
    |> text("")
  end
end
