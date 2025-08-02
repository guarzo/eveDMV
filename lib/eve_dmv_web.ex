# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use EveDmvWeb, :controller
      use EveDmvWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths,
    do:
      ~w(assets fonts images favicon.ico robots.txt site.webmanifest apple-touch-icon.png favicon-96x96.png favicon.svg web-app-manifest-192x192.png web-app-manifest-512x512.png)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      unquote(use_phoenix_controller())
      unquote(import_controller_helpers())
    end
  end

  defp use_phoenix_controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: EveDmvWeb.Layouts]
    end
  end

  defp import_controller_helpers do
    quote do
      use Gettext, backend: EveDmvWeb.Gettext
      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {EveDmvWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(import_phoenix_controller_helpers())
      unquote(html_helpers())
    end
  end

  defp import_phoenix_controller_helpers do
    quote do
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import EveDmvWeb.CoreComponents
      use Gettext, backend: EveDmvWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: EveDmvWeb.Endpoint,
        router: EveDmvWeb.Router,
        statics: EveDmvWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
