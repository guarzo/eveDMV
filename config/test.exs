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

# Use DATABASE_URL if provided (CI environment), otherwise use local Docker configuration
database_config =
  if database_url = System.get_env("DATABASE_URL") do
    [url: database_url]
  else
    [
      username: "postgres",
      password: "postgres",
      hostname: "db",
      database: "eve_dmv_test#{System.get_env("MIX_TEST_PARTITION")}",
      port: 5432
    ]
  end

config :eve_dmv,
       EveDmv.Repo,
       Keyword.merge(database_config,
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: 10
       )
