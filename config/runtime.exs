import Config

# Helper function for safe environment variable handling
defmodule ConfigHelper do
  def safe_string_to_integer(value, default) when is_binary(value) do
    try do
      String.to_integer(value)
    rescue
      ArgumentError ->
        IO.warn("Invalid integer value '#{value}', using default: #{default}")
        default
    end
  end

  def safe_string_to_integer(nil, default), do: default

  def configure_external_apis do
    [
      {:janice,
       [
         api_key: System.get_env("JANICE_API_KEY"),
         base_url: System.get_env("JANICE_BASE_URL", "https://janice.e-351.com/api")
       ]},
      {:mutamarket,
       [
         api_key: System.get_env("MUTAMARKET_API_KEY"),
         base_url: System.get_env("MUTAMARKET_BASE_URL", "https://mutamarket.com/api/v1")
       ]},
      {:esi,
       [
         client_id: System.get_env("EVE_SSO_CLIENT_ID"),
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
        IO.puts("Loaded environment variables from #{env_file}")
      rescue
        error ->
          IO.warn("Failed to load #{env_file}: #{inspect(error)}")
      end
    end
  end
end

# Override application configuration with .env values for development
if config_env() == :dev do
  config :eve_dmv,
    wanderer_kills_sse_url: System.get_env("WANDERER_KILLS_SSE_URL", "http://localhost:8080/sse"),
    wanderer_kills_websocket_url:
      System.get_env("WANDERER_KILLS_WS_URL", "ws://localhost:4004/socket"),
    wanderer_kills_base_url:
      System.get_env("WANDERER_KILLS_BASE_URL", "http://host.docker.internal:4004"),
    pipeline_enabled: System.get_env("PIPELINE_ENABLED", "true") == "true",
    mock_sse_server_enabled: System.get_env("MOCK_SSE_SERVER_ENABLED", "false") == "true"

  # External API configurations
  for {api_name, api_config} <- ConfigHelper.configure_external_apis() do
    config :eve_dmv, api_name, api_config
  end

  # Price cache configuration
  config :eve_dmv,
    price_cache_ttl_hours:
      ConfigHelper.safe_string_to_integer(System.get_env("PRICE_CACHE_TTL_HOURS"), 24)
end

# Test environment specific configuration
if config_env() == :test do
  config :eve_dmv,
    pipeline_enabled: false,
    mock_sse_server_enabled: false

  # Ensure test database uses sandbox pool regardless of DATABASE_URL
  config :eve_dmv, EveDmv.Repo,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/eve_dmv start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :eve_dmv, EveDmvWeb.Endpoint, server: true
end

if config_env() == :prod do
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
  port = String.to_integer(System.get_env("PHX_PORT") || System.get_env("PORT") || "4010")

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

  # Production configuration for external services
  config :eve_dmv,
    wanderer_kills_sse_url: System.get_env("WANDERER_KILLS_SSE_URL"),
    pipeline_enabled: System.get_env("PIPELINE_ENABLED", "true") == "true"

  # External API configurations
  for {api_name, api_config} <- ConfigHelper.configure_external_apis() do
    config :eve_dmv, api_name, api_config
  end

  # Price cache configuration
  config :eve_dmv,
    price_cache_ttl_hours:
      ConfigHelper.safe_string_to_integer(System.get_env("PRICE_CACHE_TTL_HOURS"), 24)

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
