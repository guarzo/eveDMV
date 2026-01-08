# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.Router do
  @moduledoc """
  Phoenix router defining application routes and pipelines.
  """

  use EveDmvWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    # Add request timing
    plug(EveDmvWeb.Plugs.RequestTimer)
    # 300 req/min for browsers
    plug(EveDmvWeb.Plugs.SimpleRateLimit, limit: 300, window: 60_000)
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
    # Add request timing
    plug(EveDmvWeb.Plugs.RequestTimer)
    # 100 req/min for APIs
    plug(EveDmvWeb.Plugs.SimpleRateLimit, limit: 100, window: 60_000)
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
    plug(EveDmvWeb.Plugs.LinkToAccountPlug)
    plug(:load_from_session)
  end

  pipeline :require_authenticated_user do
    plug(EveDmvWeb.Plugs.RequireAuth)
    plug(EveDmvWeb.TokenRefreshPlug)
  end

  pipeline :require_admin do
    plug(EveDmvWeb.Plugs.RequireAdmin)
  end

  # Cached API pipeline for semi-static data (changes occasionally)
  # Used for analysis endpoints that can be cached for 1 hour
  pipeline :cached_api do
    plug(:accepts, ["json"])
    plug(EveDmvWeb.Plugs.RequestTimer)
    plug(EveDmvWeb.Plugs.SimpleRateLimit, limit: 100, window: 60_000)
    plug(EveDmvWeb.Plugs.CacheControl, :semi_static)
    plug(EveDmvWeb.Plugs.ConditionalGet)
    plug(:load_from_bearer)
  end

  # Cached API pipeline for static EVE data (rarely changes)
  # Used for item types, solar systems, etc. - cached for 24 hours
  pipeline :cached_api_static do
    plug(:accepts, ["json"])
    plug(EveDmvWeb.Plugs.RequestTimer)
    plug(EveDmvWeb.Plugs.SimpleRateLimit, limit: 100, window: 60_000)
    plug(EveDmvWeb.Plugs.CacheControl, :static)
    plug(EveDmvWeb.Plugs.ConditionalGet)
  end

  # Handle .well-known requests (Chrome DevTools, etc.) - return 204 No Content
  scope "/.well-known", EveDmvWeb do
    get("/*path", WellKnownController, :index)
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

    live("/dashboard", UnifiedDashboardLive)
    live("/profile", ProfileLive)
    # Redirect /account/settings to /profile for backward compatibility
    get("/account/settings", PageController, :redirect_to_profile)
    # Consolidated character search - redirect to universal search with filter
    live("/character", UniversalSearchLive, as: :character_search)
    live("/character/:character_id", CharacterAnalysisLive)
    # Redirect old intelligence route to main character page
    get("/character/:character_id/intelligence", PageController, :redirect_to_character)
    live("/killmail/:killmail_id", KillmailLive)
    live("/player/:character_id", PlayerProfileLive)
    live("/corporation/:corporation_id", CorporationLive)
    live("/alliance/:alliance_id", AllianceLive)
    live("/system/:system_id", SystemLive)
    # Consolidated system search - redirect to universal search with filter
    live("/search/systems", UniversalSearchLive, as: :system_search)
    live("/search", UniversalSearchLive)

    # Redirects for backward compatibility
    get("/analysis/:character_id", PageController, :redirect_character)
    get("/corp/:corporation_id", PageController, :redirect_corporation)
    live("/surveillance", SurveillanceLive)
    live("/surveillance-profiles", SurveillanceProfilesLive)
    live("/surveillance-alerts", SurveillanceAlertsLive)
    # Redirect old dashboard routes to unified dashboard with appropriate tab
    live("/intelligence-dashboard", UnifiedDashboardLive, as: :intelligence_dashboard)
    live("/monitoring", UnifiedDashboardLive, as: :monitoring_dashboard)
    live("/surveillance-dashboard", UnifiedDashboardLive, as: :surveillance_dashboard)
    live("/battle", BattleAnalysisLive)
    live("/battle/:battle_id", BattleAnalysisLive)
    live("/fleet", FleetOperationsLive)

    # System activity analytics
    live("/system-activity", SystemActivityLive)
    live("/system-analytics", SystemActivityLive, as: :system_analytics)

    # Character comparison tools
    live("/character-comparison", CharacterComparisonLive)

    # System monitoring redirected to unified dashboard

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

    # Character switching routes
    get("/switch/:character_id", CharacterSwitchController, :switch)
    post("/set_primary/:character_id", CharacterSwitchController, :set_primary)
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

    auth_routes(AuthController, EveDmv.Users.User)
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

  # Comprehensive health endpoints for monitoring
  scope "/health", EveDmvWeb do
    pipe_through(:api)

    get("/status", HealthController, :index)
    get("/detailed", HealthController, :detailed)
  end

  # Authenticated API endpoints (non-cacheable - user-specific or mutations)
  scope "/api/v1", EveDmvWeb.Api do
    pipe_through([:api, :load_from_bearer])

    # API key management (requires user authentication, user-specific)
    resources "/api_keys", ApiKeysController, only: [:index, :create, :delete] do
      post("/validate", ApiKeysController, :validate)
    end

    post("/battles/:id/share", BattleShareController, :create)
    post("/battles/:id/rate", BattleRatingController, :create)
  end

  # Cached API endpoints for intelligence/analysis data (semi-static, 1 hour cache)
  scope "/api/v1", EveDmvWeb.Api do
    pipe_through([:cached_api])

    get("/battles/:id/intelligence", BattleIntelligenceController, :show)
    get("/battles/:id/multi_system", MultiSystemBattleController, :show)

    get("/characters/:id/threat_score", CharacterThreatController, :show)
    get("/characters/:id/behavioral_patterns", CharacterBehaviorController, :show)

    get("/corporations/:id/doctrine_analysis", CorporationDoctrineController, :show)
    get("/corporations/:id/threat_assessment", CorporationThreatController, :show)
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
    live("/health", Admin.SystemHealthLive)
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
