defmodule EveDmvWeb.PageController do
  use EveDmvWeb, :controller
  @moduledoc """
  Controller for static pages and home page rendering.
  """


  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
