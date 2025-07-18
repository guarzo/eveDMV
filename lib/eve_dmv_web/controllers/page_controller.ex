defmodule EveDmvWeb.PageController do
  @moduledoc """
  Controller for static pages and home page rendering.
  """

  use EveDmvWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def redirect_character(conn, %{"character_id" => character_id}) do
    redirect(conn, to: ~p"/character/#{character_id}")
  end

  def redirect_corporation(conn, %{"corporation_id" => corporation_id}) do
    redirect(conn, to: ~p"/corporation/#{corporation_id}")
  end

  def redirect_to_character(conn, %{"character_id" => character_id}) do
    redirect(conn, to: ~p"/character/#{character_id}")
  end

  def redirect_to_surveillance_profiles(conn, _params) do
    redirect(conn, to: ~p"/surveillance-profiles")
  end
end
