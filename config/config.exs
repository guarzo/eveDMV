# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :eve_dmv,
  ecto_repos: [EveDmv.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :eve_dmv, EveDmvWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EveDmvWeb.ErrorHTML, json: EveDmvWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EveDmv.PubSub,
  live_view: [signing_salt: "wbpgCQmS"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :eve_dmv, EveDmv.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  eve_dmv: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  eve_dmv: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :plugin,
    :entity_id,
    :duration_ms,
    :exception,
    :reason,
    :entity_type,
    :threat_level,
    :error,
    :character_id,
    :corporation_id,
    :supervisor,
    :task_metadata,
    :user_id,
    :task_id,
    :security_event,
    :performance,
    :business,
    :operation,
    :killmail_id,
    :battle_id,
    :solar_system_id,
    :pipeline,
    :stage,
    :event,
    :batch_size,
    :success_count,
    :error_count,
    :service,
    :endpoint,
    :status,
    :response_size,
    :rate_limit_remaining,
    :table,
    :rows_affected,
    :cache_hit,
    :query_time,
    :response_time,
    :memory_usage,
    :priority,
    :description,
    :url,
    :body,
    :headers,
    :body_type,
    :profile_id,
    :name,
    :new_level
  ]

# Filter sensitive parameters from logs
config :phoenix, :filter_parameters, [
  "password",
  "token",
  "secret",
  "api_key",
  "client_secret",
  "access_token",
  "refresh_token",
  "authorization"
]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Disable Tesla deprecated builder warning
config :tesla, disable_deprecated_builder_warning: true

# Configure Hammer rate limiting
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000, cleanup_interval_ms: 60_000]}

# Ash Framework configuration
config :ash, :include_embedded_source_by_default?, false
config :ash, :policies, show_policy_breakdowns?: true

# Configure Ash domains
config :eve_dmv,
  ash_domains: [
    EveDmv.Api,
    EveDmv.Api.SurveillanceApi,
    EveDmv.Api.AnalyticsApi,
    EveDmv.Api.BattleAnalysisApi,
    EveDmv.Domains.Analytics,
    EveDmv.Domains.Intelligence,
    EveDmv.Domains.Surveillance,
    EveDmv.Contexts.BattleAnalysis.Api,
    EveDmv.Contexts.FleetOperations.Domain
  ]

# AshPostgres configuration
config :ash_postgres, AshPostgres.DataLayer,
  migration_ignore_attributes: [AshPostgres.MigrationGenerator.Reference]

# Environment-specific configuration is now handled in runtime.exs
# This ensures consistent behavior across all environments and eliminates
# duplication between config.exs and runtime.exs files

# Default application configuration (overridden by runtime.exs)
config :eve_dmv,
  # Authentication defaults (overridden by environment variables)
  token_signing_secret: nil,
  eve_sso: [
    client_id: "your-eve-sso-client-id",
    client_secret: "your-eve-sso-client-secret",
    redirect_uri: "http://localhost:4010/auth/user/eve_sso/callback"
  ],
  # Pipeline defaults (overridden by environment variables)
  pipeline_enabled: true,
  mock_sse_server_enabled: false,
  # SDE defaults (overridden by environment variables)
  sde_auto_update: true,
  static_data_load_delay: 5000

# Name Resolver Cache Warming Configuration
config :eve_dmv, :name_resolver_cache_warming,
  # T1 Frigates: Rifter, Punisher, Tormentor, Merlin, Incursus, Tristan, Kestrel, Atron
  common_ships: [587, 588, 589, 590, 591, 592, 593, 594],
  # Major trade hubs: Jita, Amarr, Dodixie, Rens
  trade_hubs: [30_000_142, 30_002_187, 30_002_659, 30_002_510],
  # Major NPC corporations for preloading
  npc_corporations: [
    # Caldari Business Tribunal
    1_000_001,
    # Garoun Investment Bank
    1_000_002,
    # Amarr Trade Registry
    1_000_003,
    # Core Complexion Inc.
    1_000_004,
    # CONCORD
    1_000_125
  ]

# Database connection pool configuration moved to environment-specific configs

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
