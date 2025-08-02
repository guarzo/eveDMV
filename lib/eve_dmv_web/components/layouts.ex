defmodule EveDmvWeb.Layouts do
  @moduledoc """
  This module contains different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered around other layouts.
  """
  use EveDmvWeb, :html

  embed_templates("layouts/*")

  def get_csrf_token do
    Plug.CSRFProtection.get_csrf_token()
  end
end
