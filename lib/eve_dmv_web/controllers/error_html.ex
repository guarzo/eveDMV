defmodule EveDmvWeb.ErrorHTML do
  @moduledoc """
  Error page rendering for HTML requests.
  """
  use EveDmvWeb, :html

  # Default 404 and 500 error pages
  def render("404.html", _assigns) do
    "Page not found"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end
end
