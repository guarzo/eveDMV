defmodule EveDmvWeb.Router do
  @moduledoc """
  Phoenix router defining application routes and pipelines.
  """

  use EveDmvWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EveDmvWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", EveDmvWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/feed", KillFeedLive
    live "/dashboard", DashboardLive
    live "/profile", ProfileLive
    live "/login", AuthLive.SignIn
  end

  # Authentication routes
  scope "/auth", EveDmvWeb do
    pipe_through :browser

    # AshAuthentication routes for EVE SSO
    sign_in_route()
    sign_out_route(AuthController)
    reset_route([])
  end

  # OAuth routes need to be outside /auth scope to avoid double prefix
  scope "/", EveDmvWeb do
    pipe_through :browser

    auth_routes_for(EveDmv.Users.User, to: AuthController)
  end

  # Other scopes may use custom stacks.
  scope "/api", EveDmvWeb do
    pipe_through :api
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:eve_dmv, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EveDmvWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
