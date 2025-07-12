# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.Router do
  @moduledoc """
  Phoenix router defining application routes and pipelines.
  """

  use EveDmvWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {EveDmvWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(EveDmvWeb.Plugs.SecurityHeaders)
    plug(EveDmvWeb.Plugs.SessionActivity)
    plug(:load_from_session)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:load_from_bearer)
  end

  pipeline :auth do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {EveDmvWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(EveDmvWeb.Plugs.SecurityHeaders)
    plug(EveDmvWeb.Plugs.AuthRateLimiter)
    plug(EveDmvWeb.Plugs.SessionActivity)
    plug(:load_from_session)
  end

  scope "/", EveDmvWeb do
    pipe_through(:browser)

    live("/", HomeLive)
    live("/feed", KillFeedLive)
    live("/dashboard", DashboardLive)
    live("/profile", ProfileLive)
    live("/character", CharacterSearchLive)
    live("/character/:character_id", CharacterAnalysisLive)
    # Redirect old intelligence route to main character page
    get("/character/:character_id/intelligence", PageController, :redirect_to_character)
    live("/player/:character_id", PlayerProfileLive)
    live("/corporation/:corporation_id", CorporationLive)
    live("/alliance/:alliance_id", AllianceLive)
    live("/system/:system_id", SystemLive)
    live("/search/systems", SystemSearchLive)
    live("/search", UniversalSearchLive)

    # Redirects for backward compatibility
    get("/analysis/:character_id", PageController, :redirect_character)
    get("/corp/:corporation_id", PageController, :redirect_corporation)
    # Redirect old surveillance route to new surveillance profiles page
    get("/surveillance", PageController, :redirect_to_surveillance_profiles)
    live("/surveillance-profiles", SurveillanceProfilesLive)
    live("/surveillance-alerts", SurveillanceAlertsLive)
    live("/surveillance-dashboard", SurveillanceDashboardLive)
    live("/chain-intelligence", ChainIntelligenceLive)
    live("/chain-intelligence/:map_id", ChainIntelligenceLive)
    live("/wh-vetting", WHVettingLive)
    live("/intelligence-dashboard", IntelligenceDashboardLive)
    live("/battle", BattleAnalysisLive)
    live("/battle/:battle_id", BattleAnalysisLive)
    live("/fleet", FleetOperationsLive)

    # System monitoring (admin only in production)
    live("/monitoring", MonitoringDashboardLive)
  end

  # Authentication routes
  scope "/auth", EveDmvWeb do
    pipe_through(:auth)

    # AshAuthentication routes for EVE SSO
    sign_in_route()
    sign_out_route(AuthController)
    reset_route([])
  end

  # Login page with rate limiting
  scope "/", EveDmvWeb do
    pipe_through(:auth)

    live("/login", AuthLive.SignIn)
  end

  # OAuth routes need to be outside /auth scope to avoid double prefix
  scope "/", EveDmvWeb do
    pipe_through(:auth)

    auth_routes_for(EveDmv.Users.User, to: AuthController)
  end

  # Other scopes may use custom stacks.
  scope "/api", EveDmvWeb do
    pipe_through(:api)
  end

  # Authenticated API endpoints
  scope "/api/v1", EveDmvWeb.Api do
    pipe_through([:api, :load_from_bearer])

    # API key management (requires user authentication)
    resources "/api_keys", ApiKeysController, only: [:index, :create, :delete] do
      post("/validate", ApiKeysController, :validate)
    end

    # Sprint 8: Battle Intelligence APIs
    get("/battles/:id/intelligence", BattleIntelligenceController, :show)
    get("/battles/:id/multi_system", MultiSystemBattleController, :show)

    # Sprint 8: Character Intelligence APIs
    get("/characters/:id/threat_score", CharacterThreatController, :show)
    get("/characters/:id/behavioral_patterns", CharacterBehaviorController, :show)

    # Sprint 8: Corporation Intelligence APIs
    get("/corporations/:id/doctrine_analysis", CorporationDoctrineController, :show)
    get("/corporations/:id/threat_assessment", CorporationThreatController, :show)

    # Sprint 8: Battle Sharing APIs
    post("/battles/:id/share", BattleShareController, :create)
    post("/battles/:id/rate", BattleRatingController, :create)
  end

  # Internal API endpoints (requires API key authentication)
  scope "/api/internal", EveDmvWeb.Api do
    pipe_through([:api, {EveDmvWeb.Plugs.ApiAuth, permissions: ["internal"]}])

    # Internal endpoints would go here
    # get "/health", HealthController, :check
    # get "/metrics", MetricsController, :index
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
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: EveDmvWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
