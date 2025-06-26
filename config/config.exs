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
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Ash Framework configuration
config :ash, :include_embedded_source_by_default?, false
config :ash, :policies, show_policy_breakdowns?: true

# Configure Ash domains
config :eve_dmv, ash_domains: [EveDmv.Api]

# AshPostgres configuration
config :ash_postgres, AshPostgres.DataLayer,
  migration_ignore_attributes: [AshPostgres.MigrationGenerator.Reference]

# Token signing secret for authentication
config :eve_dmv, :token_signing_secret, "your-secret-key-here-replace-in-production"

# EVE SSO OAuth2 Configuration
config :eve_dmv, :eve_sso,
  client_id: System.get_env("EVE_SSO_CLIENT_ID", "your-eve-sso-client-id"),
  client_secret: System.get_env("EVE_SSO_CLIENT_SECRET", "your-eve-sso-client-secret"),
  redirect_uri:
    System.get_env("EVE_SSO_REDIRECT_URI", "http://localhost:4000/auth/eve_sso/callback")

# Killmail Pipeline Configuration
config :eve_dmv,
  wanderer_kills_sse_url: System.get_env("WANDERER_KILLS_SSE_URL", "http://localhost:8080/sse"),
  zkillboard_sse_url: System.get_env("ZKILLBOARD_SSE_URL", "https://zkillboard.com/sse"),
  pipeline_enabled: System.get_env("PIPELINE_ENABLED", "true") == "true"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
