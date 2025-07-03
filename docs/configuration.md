# Configuration Guide

## Environment Variables

### Required Variables
- `EVE_SSO_CLIENT_ID` - EVE SSO application client ID
- `EVE_SSO_CLIENT_SECRET` - EVE SSO application secret
- `SECRET_KEY_BASE` - Phoenix secret key base
- `DATABASE_URL` - PostgreSQL connection string

### Optional Variables
- `WANDERER_KILLS_ENABLED` - Enable wanderer kills integration (default: true)
- `WANDERER_KILLS_SSE_URL` - SSE endpoint URL
- `PIPELINE_ENABLED` - Enable killmail pipeline (default: true)
- `MOCK_SSE_SERVER_ENABLED` - Use mock server for development (default: false)

## Intelligence Configuration

Configure intelligence analysis behavior in `config/config.exs`:

```elixir
config :eve_dmv, :intelligence,
  analysis_timeout: 30_000,
  correlation_enabled: true,
  threat_scoring: [
    character_age_weight: 0.3,
    corporation_history_weight: 0.4,
    activity_weight: 0.3
  ]
```

## Cache Configuration

Configure caching behavior:

```elixir
config :eve_dmv, :cache,
  ttl: 3600,  # 1 hour default TTL
  max_stale_age: 86400,  # 24 hours max stale age
  cleanup_interval: 300_000  # 5 minutes cleanup
```

## Database Configuration

Configure database connection and pooling:

```elixir
config :eve_dmv, EveDmv.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  queue_target: 5000,
  queue_interval: 1000,
  ssl: true,
  ssl_opts: [
    verify: :verify_none
  ]
```

## Phoenix Server Configuration

Configure the Phoenix server:

```elixir
config :eve_dmv, EveDmvWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: String.to_integer(System.get_env("PHOENIX_PORT") || "4010")],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  render_errors: [
    formats: [html: EveDmvWeb.ErrorHTML, json: EveDmvWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EveDmv.PubSub,
  live_view: [signing_salt: "your_salt_here"]
```

## Wanderer-Kills Integration

Configure the wanderer-kills SSE integration:

```elixir
config :eve_dmv, :wanderer_kills,
  enabled: System.get_env("WANDERER_KILLS_ENABLED") == "true",
  sse_url: System.get_env("WANDERER_KILLS_SSE_URL") || "http://host.docker.internal:4004/api/v1/kills/stream",
  base_url: System.get_env("WANDERER_KILLS_BASE_URL") || "http://host.docker.internal:4004",
  ws_url: System.get_env("WANDERER_KILLS_WS_URL") || "ws://host.docker.internal:4004/socket"
```

## ESI API Configuration

Configure EVE Swagger Interface (ESI) settings:

```elixir
config :eve_dmv, :esi,
  base_url: "https://esi.evetech.net",
  timeout: 30_000,
  max_retries: 3,
  retry_delay: 1000,
  user_agent: "EVE DMV/1.0"
```

## OAuth Configuration

Configure EVE SSO OAuth:

```elixir
config :eve_dmv, :eve_sso,
  client_id: System.get_env("EVE_SSO_CLIENT_ID"),
  client_secret: System.get_env("EVE_SSO_CLIENT_SECRET"),
  redirect_uri: System.get_env("EVE_SSO_REDIRECT_URI") || "http://localhost:4010/auth/callback",
  authorize_url: "https://login.eveonline.com/v2/oauth/authorize",
  token_url: "https://login.eveonline.com/v2/oauth/token",
  scopes: [
    "esi-characters.read_corporation_roles.v1",
    "esi-corporations.read_corporation_membership.v1",
    "esi-killmails.read_killmails.v1"
  ]
```

## Broadway Pipeline Configuration

Configure the killmail processing pipeline:

```elixir
config :eve_dmv, :killmail_pipeline,
  enabled: System.get_env("PIPELINE_ENABLED") == "true",
  batch_size: 100,
  batch_timeout: 5000,
  concurrency: 10,
  rate_limiting: [
    allowed_messages: 1000,
    interval: 60_000  # 1 minute
  ]
```

## Logger Configuration

Configure logging levels and backends:

```elixir
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :character_id, :corporation_id]

config :logger,
  level: :info,
  backends: [:console]
```

## Environment-Specific Configuration

### Development

Development-specific settings in `config/dev.exs`:

```elixir
config :eve_dmv, EveDmvWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]
```

### Production

Production-specific settings in `config/prod.exs`:

```elixir
config :eve_dmv, EveDmvWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

config :logger, level: :warning
```

### Runtime Configuration

Runtime configuration in `config/runtime.exs`:

```elixir
if config_env() == :prod do
  config :eve_dmv, EveDmvWeb.Endpoint,
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      transport_options: [socket_opts: [:inet6]]
    ],
    secret_key_base: secret_key_base
end
```

## Testing Configuration

Test-specific settings in `config/test.exs`:

```elixir
config :eve_dmv, EveDmv.Repo,
  database: "eve_dmv_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :eve_dmv, EveDmvWeb.Endpoint,
  http: [port: 4002],
  server: false
```

## Security Headers Configuration

Configure security headers middleware:

```elixir
config :eve_dmv, :security_headers,
  content_security_policy: "default-src 'self'",
  x_frame_options: "DENY",
  x_content_type_options: "nosniff",
  x_xss_protection: "1; mode=block",
  referrer_policy: "strict-origin-when-cross-origin"
```

## Performance Monitoring

Configure performance monitoring settings:

```elixir
config :eve_dmv, :telemetry,
  metrics_enabled: true,
  sampling_rate: 0.1,  # Sample 10% of requests
  slow_query_threshold: 1000  # Log queries slower than 1 second
```

## Feature Flags

Configure feature toggles:

```elixir
config :eve_dmv, :features,
  intelligence_analysis: true,
  killmail_enrichment: true,
  market_integration: true,
  wormhole_vetting: true
```