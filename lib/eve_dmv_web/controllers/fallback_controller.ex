defmodule EveDmvWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid HTTP responses.

  See https://hexdocs.pm/phoenix/controllers.html#action-fallback-controllers
  for more details.
  """
  use EveDmvWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(EveDmvWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(EveDmvWeb.ErrorView)
    |> render(:"401")
  end

  def call(conn, {:error, changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(EveDmvWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end
end
