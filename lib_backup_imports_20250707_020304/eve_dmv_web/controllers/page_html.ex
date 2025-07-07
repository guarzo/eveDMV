defmodule EveDmvWeb.PageHTML do
  use EveDmvWeb, :html
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates.
  """

  embed_templates("page_html/*")
end
