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

  pipeline :require_authenticated_user do
    plug(EveDmvWeb.Plugs.RequireAuth)
    plug(EveDmvWeb.TokenRefreshPlug)
  end

  pipeline :require_admin do
    plug(EveDmvWeb.Plugs.RequireAdmin)
  end

  # Public routes - accessible without authentication
  scope "/", EveDmvWeb do
    pipe_through(:browser)

    live("/", HomeLive)
    live("/feed", KillFeedLive)
  end

  # Authenticated routes - require user login
  scope "/", EveDmvWeb do
    pipe_through([:browser, :require_authenticated_user])

    live("/dashboard", DashboardLive)
    live("/profile", ProfileLive)
    live("/character", CharacterSearchLive)
    live("/character/:character_id", CharacterAnalysisLive)
    # Redirect old intelligence route to main character page
    get("/character/:character_id/intelligence", PageController, :redirect_to_character)
    live("/killmail/:killmail_id", KillmailLive)
    live("/player/:character_id", PlayerProfileLive)
    live("/corporation/:corporation_id", CorporationLive)
    live("/alliance/:alliance_id", AllianceLive)
    live("/system/:system_id", SystemLive)
    live("/search/systems", SystemSearchLive)
    live("/search", UniversalSearchLive)

    # Redirects for backward compatibility
    get("/analysis/:character_id", PageController, :redirect_character)
    get("/corp/:corporation_id", PageController, :redirect_corporation)
    live("/surveillance", SurveillanceLive)
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

    # Performance monitoring dashboard (Sprint 15A)
    live("/admin/performance", Admin.PerformanceLive)
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
    get("/session/clear", SessionController, :clear)
  end

  # OAuth routes need to be outside /auth scope to avoid double prefix
  scope "/", EveDmvWeb do
    pipe_through(:auth)

    auth_routes_for(EveDmv.Users.User, to: AuthController)
  end

  # Other scopes may use custom stacks.
  scope "/api", EveDmvWeb do
    pipe_through(:api)

    # Health check endpoint
    get("/health", HealthController, :check)
  end

  # Public health endpoint (no auth required)
  scope "/", EveDmvWeb do
    pipe_through(:api)

    get("/health", HealthController, :check)
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
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: EveDmvWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  # Admin-only routes
  scope "/admin", EveDmvWeb do
    pipe_through([:browser, :require_admin])

    live("/users", Admin.UsersLive)
    live("/system", Admin.SystemLive)
  end

  # Production performance monitoring (admin only)
  if Mix.env() == :prod do
    import Phoenix.LiveDashboard.Router

    scope "/admin" do
      pipe_through([:browser, :require_admin])

      live_dashboard("/performance-dashboard",
        metrics: EveDmvWeb.Telemetry,
        additional_pages: [
          query_monitor: {EveDmv.Telemetry.QueryMonitor, :dashboard_page}
        ]
      )
    end
  end
end
