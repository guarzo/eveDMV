import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :eve_dmv, EveDmvWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ICAjXbg77koCvRrkEn0ABIARnopKP+dfNWnmCHloRJIeOQSMEdLajtvAxfffIWpq",
  server: false

# In test we don't send emails
config :eve_dmv, EveDmv.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

# For tests, always use the dedicated test database configuration
# DATABASE_URL should only be used if explicitly set for testing (CI environments)
test_database_url = System.get_env("TEST_DATABASE_URL")
use_ci_database = System.get_env("CI") && System.get_env("DATABASE_URL")

if test_database_url do
  # Use explicit test DATABASE_URL if provided
  config :eve_dmv, EveDmv.Repo,
    url: test_database_url,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2,
    ownership_timeout: 60_000,
    timeout: 60_000
else
  # Always use local test database for development/testing
  # Do not use the regular DATABASE_URL from .env for tests
  config :eve_dmv, EveDmv.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "db",
    database: "eve_dmv_test#{System.get_env("MIX_TEST_PARTITION")}",
    port: 5432,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2,
    ownership_timeout: 60_000,
    timeout: 60_000
end

# Authentication configuration for tests
config :eve_dmv, :token_signing_secret, "test_signing_secret_at_least_32_characters_long!"

# EVE SSO OAuth2 Test Configuration
config :eve_dmv, :eve_sso,
  client_id: "test_client_id",
  client_secret: "test_client_secret",
  redirect_uri: "http://localhost:4002/auth/user/eve_sso/callback"

# Disable external service connections in tests
config :eve_dmv,
  pipeline_enabled: false,
  mock_sse_server_enabled: false,
  wanderer_kills_sse_url: "http://localhost:8080/sse",
  wanderer_kills_websocket_url: "ws://localhost:4004/socket",
  wanderer_kills_base_url: "http://localhost:4004"

# Final override to ensure SQL Sandbox is used - this must be last!
# Note: Pool configuration is already set above based on DATABASE_URL presence
