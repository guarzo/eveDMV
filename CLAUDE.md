# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EVE DMV is an Elixir Phoenix application for tracking EVE Online PvP data. It uses:
- **Phoenix 1.7.21** with LiveView for real-time UI
- **Ash Framework 3.4** for declarative resource management (instead of traditional Ecto schemas)
- **Broadway** for real-time killmail ingestion pipeline
- **EVE SSO OAuth2** for authentication

## Essential Commands

```bash
# Setup and Development
mix setup              # Full setup: deps, DB, migrations, assets
mix phx.server         # Start Phoenix server (http://localhost:4000)
iex -S mix phx.server  # Start with interactive shell

# Database Operations
mix ecto.create        # Create database
mix ecto.migrate       # Run migrations
mix ecto.rollback      # Rollback migration
mix ecto.reset         # Drop, create, and migrate

# Testing and Quality
mix test               # Run tests
mix test --cover       # Run with coverage
mix credo              # Static analysis
mix format             # Format code

# Ash-Specific Commands
mix ash_postgres.create           # Create migration from resource changes
mix ash_postgres.migrate          # Run Ash migrations
mix ash.codegen <resource_name>   # Generate resource code

# Pipeline Management
# Set PIPELINE_ENABLED=true/false in .env file to enable/disable Broadway pipeline
# Configuration automatically loaded from .env files at runtime

# Environment File Support (.env files automatically loaded)
# .env files are loaded at both compile-time (dev.exs) and runtime (runtime.exs)
# 1. .env loaded in config/dev.exs (for application startup configuration)
# 2. .env loaded in config/runtime.exs (for runtime configuration)
# 3. .env.dev supported for environment-specific overrides
# Variables in .env files override all config defaults
```

## Architecture Overview

### Ash Framework Usage
This project heavily uses Ash Framework for data modeling. Key concepts:
- **Resources** replace traditional Ecto schemas (in `lib/eve_dmv/`)
- **API Domain** (`EveDmv.Api`) centralizes all resource access
- **Actions** define CRUD and custom operations declaratively
- Resources auto-generate migrations and handle authorization

Example resource pattern:
```elixir
defmodule EveDmv.Killmails.KillmailRaw do
  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer
    
  actions do
    defaults [:read, :destroy]
    create :create do
      # Custom create logic
    end
  end
end
```

### Real-time Pipeline Architecture
The killmail ingestion pipeline (`lib/eve_dmv/killmails/killmail_pipeline.ex`) uses Broadway:
1. **SSE Producer** connects to wanderer-kills feed
2. **Processor** validates and transforms killmails
3. **Batch Handler** bulk inserts using `Ash.bulk_create`
4. **PubSub** broadcasts updates to LiveView

### Database Design
- **Partitioned tables**: `killmails_raw` and `killmails_enriched` partitioned by month
- **Bulk operations**: Use `Ash.bulk_create` for high-volume inserts
- **Resource snapshots**: Track schema evolution in `priv/resource_snapshots/`

## Working with Resources

When creating or modifying Ash resources:
1. Define resource in `lib/eve_dmv/[domain]/[resource].ex`
2. Add to API in `lib/eve_dmv/api.ex`
3. Generate migration: `mix ash_postgres.create`
4. Run migration: `mix ash_postgres.migrate`

## Current Implementation Status

### ✅ Sprint 1 Complete (30/30 pts)
- **Epic 1: Database Foundation** (8 pts) - Ash Framework + partitioned schema
- **Epic 2: Authentication** (10 pts) - EVE SSO integration via AshAuthentication  
- **Epic 3: Killmail Pipeline + UI** (12 pts) - Broadway pipeline + Live Feed UI

### Live Kill Feed UI
- **Route**: `/feed` - Accessible from navigation or home page
- **Features**: Real-time killmail display with sample data, system stats, filtering
- **Demo Data**: Generates 50 sample killmails when database is empty
- **Status**: ✅ UI Complete - displaying sample data, ready for real pipeline data

## Environment Configuration

Required environment variables:
```bash
EVE_SSO_CLIENT_ID       # EVE OAuth application ID
EVE_SSO_CLIENT_SECRET   # EVE OAuth secret
SECRET_KEY_BASE         # Phoenix secret key
DATABASE_URL            # PostgreSQL connection

# Wanderer-Kills Integration
WANDERER_KILLS_SSE_URL      # SSE endpoint: http://host.docker.internal:4004/api/v1/kills/stream
WANDERER_KILLS_BASE_URL     # Base API URL: http://host.docker.internal:4004
WANDERER_KILLS_WS_URL       # WebSocket URL: ws://host.docker.internal:4004/socket

# Pipeline Control
PIPELINE_ENABLED            # Enable/disable Broadway pipeline (true/false)
MOCK_SSE_SERVER_ENABLED     # Use mock server for development (true/false)
```

## Common Development Tasks

### Quality Assurance
```bash
# Run all quality checks (same as CI)
./scripts/quality_check.sh

# Individual quality checks
mix quality.check          # Run all checks
mix quality.fix            # Auto-fix formatting and unused deps
mix format                 # Format code
mix credo --strict         # Static analysis
mix dialyzer              # Type checking
mix deps.audit            # Security audit
mix test --cover          # Tests with coverage
```

### Adding New LiveView Pages
1. Create LiveView module in `lib/eve_dmv_web/live/`
2. Add route in `lib/eve_dmv_web/router.ex`
3. Use `on_mount: {EveDmvWeb.AuthLive, :load_from_session}` for authenticated routes

### Working with the Pipeline
- Pipeline modules in `lib/eve_dmv/killmails/`
- Toggle with `PIPELINE_ENABLED=true/false` environment variable
- ✅ **Broadway pipeline working** - SSE producer properly creates Broadway.Message structs
- ✅ **SSE Integration complete** - Connected to `http://host.docker.internal:4004/api/v1/kills/stream`
- ✅ **Real-time killmail data** - Receiving live EVE Online killmail events
- UI displays real killmail data from wanderer-kills SSE feed

### Authentication Flow
1. User clicks "Sign in with EVE"
2. Redirects to EVE SSO
3. Callback creates/updates User and Token resources
4. Session established with character data

### CI/CD Pipeline
- **GitHub Actions**: Automated testing, quality checks, Docker builds
- **Quality Gates**: Format, Credo, Dialyzer, security audit, test coverage
- **Docker**: Multi-stage builds with Alpine base for production
- **Security**: Trivy vulnerability scanning, dependency auditing
- **Coverage**: ExCoveralls with 70% minimum threshold

## Key Files and Modules

- `lib/eve_dmv/api.ex` - Central Ash API domain
- `lib/eve_dmv/killmails/killmail_pipeline.ex` - Broadway pipeline
- `lib/eve_dmv/killmails/sse_producer.ex` - SSE connection handler
- `lib/eve_dmv_web/live/kill_feed_live.ex` - Live kill feed UI
- `lib/eve_dmv_web/router.ex` - Route definitions
- `config/config.exs` - Base configuration
- `WANDERER_KILLS_SSE_REQUIREMENTS.md` - SSE implementation specification
- `.env` - Environment variable configuration