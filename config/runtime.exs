import Config
require Logger

# Validate required secrets early in runtime configuration
# This ensures the application fails fast if critical configuration is missing
required_secrets = [
  "EVE_SSO_CLIENT_ID",
  "EVE_SSO_CLIENT_SECRET",
  "SECRET_KEY_BASE",
  "DATABASE_URL"
]

# Only validate in production environment
if config_env() == :prod do
  for secret <- required_secrets do
    if is_nil(System.get_env(secret)) do
      raise """
      Missing required environment variable: #{secret}

      Please ensure all required secrets are configured before starting the application.
      See .env.example for the complete list of required environment variables.

      Generate SECRET_KEY_BASE with: mix phx.gen.secret
      """
    end
  end

  # Additional validation for specific variables
  secret_key_base = System.get_env("SECRET_KEY_BASE")

  if String.length(secret_key_base) < 64 do
    raise "SECRET_KEY_BASE must be at least 64 characters long"
  end

  Logger.info("✅ All required environment variables validated successfully")
end

# Helper function for safe environment variable handling
defmodule ConfigHelper do
  def safe_string_to_integer(value, default) when is_binary(value) do
    try do
      String.to_integer(value)
    rescue
      ArgumentError ->
        Logger.warning("Invalid integer value '#{value}', using default: #{default}")
        default
    end
  end

  def safe_string_to_integer(nil, default), do: default

  def configure_external_apis do
    [
      {:janice,
       [
         base_url: System.get_env("JANICE_BASE_URL", "https://janice.e-351.com/api")
       ]},
      {:mutamarket,
       [
         base_url: System.get_env("MUTAMARKET_BASE_URL", "https://mutamarket.com/api/v1")
       ]},
      {:esi,
       [
         base_url: System.get_env("ESI_BASE_URL", "https://esi.evetech.net")
       ]}
    ]
  end
end

# Load .env files if they exist (but not in test environment)
unless config_env() == :test do
  env_files = [
    # Environment-specific .env file
    ".env.#{config_env()}",
    # Default .env file
    ".env"
  ]

  for env_file <- env_files do
    if File.exists?(env_file) do
      try do
        Dotenvy.source([env_file])
        Logger.info("Loaded environment variables from #{env_file}")
      rescue
        error ->
          Logger.warning("Failed to load #{env_file}: #{inspect(error)}")
      end
    end
  end
end

# Common configuration for all non-test environments
unless config_env() == :test do
  # Authentication configuration
  config :eve_dmv,
    token_signing_secret: System.get_env("TOKEN_SIGNING_SECRET"),
    eve_sso: [
      client_id: System.get_env("EVE_SSO_CLIENT_ID", "your-eve-sso-client-id"),
      client_secret: System.get_env("EVE_SSO_CLIENT_SECRET", "your-eve-sso-client-secret"),
      redirect_uri:
        System.get_env("EVE_SSO_REDIRECT_URI", "http://localhost:4010/auth/user/eve_sso/callback")
    ]

  # Pipeline configuration
  config :eve_dmv,
    pipeline_enabled: System.get_env("PIPELINE_ENABLED", "true") == "true",
    mock_sse_server_enabled: System.get_env("MOCK_SSE_SERVER_ENABLED", "false") == "true",
    # SDE configuration
    sde_auto_update: System.get_env("SDE_AUTO_UPDATE", "true") == "true",
    static_data_load_delay:
      ConfigHelper.safe_string_to_integer(System.get_env("STATIC_DATA_LOAD_DELAY"), 5000)

  # External service configuration
  config :eve_dmv,
    wanderer_kills_sse_url: System.get_env("WANDERER_KILLS_SSE_URL", "http://localhost:8080/sse"),
    wanderer_kills_websocket_url:
      System.get_env("WANDERER_KILLS_WS_URL", "ws://localhost:4004/socket"),
    wanderer_kills_base_url:
      System.get_env("WANDERER_KILLS_BASE_URL", "http://host.docker.internal:4004"),
    wanderer_base_url: System.get_env("WANDERER_BASE_URL", "http://host.docker.internal:4004"),
    wanderer_ws_url:
      System.get_env("WANDERER_WS_URL", "ws://host.docker.internal:4004/socket/events"),
    wanderer_api_token: System.get_env("WANDERER_API_TOKEN"),
    default_chain_id: System.get_env("DEFAULT_CHAIN_ID")

  # Performance configuration
  config :eve_dmv,
    batch_size: ConfigHelper.safe_string_to_integer(System.get_env("BATCH_SIZE"), 100),
    batch_timeout: ConfigHelper.safe_string_to_integer(System.get_env("BATCH_TIMEOUT"), 30000),
    pipeline_concurrency:
      ConfigHelper.safe_string_to_integer(System.get_env("PIPELINE_CONCURRENCY"), 12),
    batcher_concurrency:
      ConfigHelper.safe_string_to_integer(System.get_env("BATCHER_CONCURRENCY"), 4),
    price_cache_ttl_hours:
      ConfigHelper.safe_string_to_integer(System.get_env("PRICE_CACHE_TTL_HOURS"), 24)

  # Historical Fetch Configuration (Phase 2 - 2-year killmail fetch)
  # See HISTORICAL_FETCH_2YEAR_IMPLEMENTATION.md for details
  config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher,
    rate_limit_delay:
      ConfigHelper.safe_string_to_integer(System.get_env("HISTORICAL_FETCH_RATE_LIMIT"), 1_000),
    max_pages:
      ConfigHelper.safe_string_to_integer(System.get_env("HISTORICAL_FETCH_MAX_PAGES"), 100),
    lookback_days:
      ConfigHelper.safe_string_to_integer(System.get_env("HISTORICAL_FETCH_LOOKBACK_DAYS"), 730)

  config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker,
    check_interval:
      ConfigHelper.safe_string_to_integer(
        System.get_env("HISTORICAL_FETCH_CHECK_INTERVAL"),
        30_000
      ),
    enabled: System.get_env("HISTORICAL_FETCH_ENABLED", "true") == "true"

  # External API configurations
  for {api_name, api_config} <- ConfigHelper.configure_external_apis() do
    config :eve_dmv, api_name, api_config
  end
end

# Development-specific database configuration
# Never override database config in test environment
if config_env() == :dev and System.get_env("MIX_ENV") != "test" and Mix.env() != :test do
  if database_url = System.get_env("DATABASE_URL") do
    current_pool = Application.get_env(:eve_dmv, EveDmv.Repo)[:pool]

    if current_pool != Ecto.Adapters.SQL.Sandbox do
      config :eve_dmv, EveDmv.Repo, url: database_url
    end
  end
end

# Test environment specific configuration
if config_env() == :test do
  config :eve_dmv,
    pipeline_enabled: false,
    mock_sse_server_enabled: false

  # Disable historical fetch worker in tests
  config :eve_dmv, EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker, enabled: false
end

if System.get_env("PHX_SERVER") do
  config :eve_dmv, EveDmvWeb.Endpoint, server: true
end

# Runtime logger configuration
if System.get_env("DISABLE_STRUCTURED_LOGGING") == "true" do
  config :logger, :console,
    format: "$time $metadata[$level] $message\n",
    metadata: [:request_id, :user_id, :character_id]
end

if config_env() == :prod do
  # Database configuration for production
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  # Optimized database configuration for production
  config :eve_dmv, EveDmv.Repo,
    url: database_url,
    # Increased pool size for production workloads
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    # Queue configuration for connection management
    queue_target: String.to_integer(System.get_env("DB_QUEUE_TARGET") || "50"),
    queue_interval: String.to_integer(System.get_env("DB_QUEUE_INTERVAL") || "1000"),
    # Connection timeout settings
    timeout: String.to_integer(System.get_env("DB_TIMEOUT") || "15000"),
    connect_timeout: String.to_integer(System.get_env("DB_CONNECT_TIMEOUT") || "5000"),
    # Prepared statement caching for better performance
    prepare: :unnamed,
    # SSL configuration
    ssl: System.get_env("DATABASE_SSL", "false") == "true",
    socket_options: [],
    # Statement timeout to prevent long-running queries
    parameters: [
      statement_timeout: System.get_env("DB_STATEMENT_TIMEOUT", "30000")
    ]

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  port =
    case Integer.parse(System.get_env("PHX_PORT") || System.get_env("PORT") || "4010") do
      {port_num, ""} -> port_num
      _ -> 4010
    end

  config :eve_dmv, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :eve_dmv, EveDmvWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Production-specific configuration is now handled in the common block above
  # No additional configuration needed here since it's already covered

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :eve_dmv, EveDmvWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :eve_dmv, EveDmvWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :eve_dmv, EveDmv.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
