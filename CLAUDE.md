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
mix phx.server         # Start Phoenix server (http://localhost:4010)
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

## Database Configuration

### IMPORTANT: Test Environment Database Setup

The test environment uses SQL Sandbox pool for safe concurrent testing. The configuration is:

**Key Points:**
- Test environment MUST use `Ecto.Adapters.SQL.Sandbox` pool
- Test environment ignores .env files and DATABASE_URL
- Test database name: `eve_dmv_test` (not eve_tracker_*)
- Development database name: From DATABASE_URL in .env file

**Configuration Flow:**
1. `config/test.exs` - Sets SQL Sandbox pool for test environment
2. `test/test_helper.exs` - Validates SQL Sandbox is configured and fails fast if not
3. `config/runtime.exs` - Applies DATABASE_URL only for dev/prod environments
4. Test environment explicitly ignores .env files to prevent DATABASE_URL conflicts

**If tests fail with "Test environment requires Ecto.Adapters.SQL.Sandbox pool":**
- Ensure MIX_ENV=test is set when running tests
- Verify config/test.exs has pool: Ecto.Adapters.SQL.Sandbox
- Check that runtime.exs doesn't override test database config
- Confirm test database exists: `MIX_ENV=test mix ecto.create`

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

## 🚨 CRITICAL DEVELOPMENT RULES

### Clean Codebase Vision
EVE DMV maintains a **CLEAN CODEBASE** with NO placeholder implementations. Every function must provide real value or not exist at all.

### Definition of "Done"
A feature is **ONLY** considered done when:
1. ✅ It queries real data from the database
2. ✅ Calculations use actual algorithms (no hardcoded values)
3. ✅ No placeholder/mock return values
4. ✅ Tests exist and pass with real data
5. ✅ Documentation matches actual implementation
6. ✅ No TODO comments in the implementation

### Prohibited Patterns
**NEVER** implement these anti-patterns:
- ❌ Functions that return empty arrays `[]` or maps `%{}` as placeholders
- ❌ Hardcoded "magic" numbers (e.g., DPS = 600, mass = 10,000,000)
- ❌ Random data generation (`Enum.random`, `:rand.uniform()`) for "analysis"
- ❌ Stub functions that return fake data
- ❌ References to non-existent modules with fallbacks
- ❌ Modulo-based logic for classifications (e.g., `ship_type_id % 10`)

### Required Patterns
**ALWAYS** implement features this way:
- ✅ Query static data tables for ship/system information
- ✅ Calculate metrics from actual killmail data
- ✅ Return meaningful errors if data is unavailable
- ✅ Remove the entire function if it can't be properly implemented
- ✅ Use real EVE static data (49,906 item types are loaded!)

### The Golden Rule
**If you can't implement it with real data, don't implement it at all.**

Better to have fewer features that work perfectly than many features that lie to users.

## Current Implementation Status

### ✅ What Actually Works with Real Data
- **Authentication** - Full EVE SSO integration
- **Kill Feed** (`/feed`) - Real-time killmail display from wanderer-kills SSE
- **Database Pipeline** - Broadway ingestion with partitioned storage
- **Static Data** - 49,906 item types and 8,436 systems loaded and queryable
- **Character Stats** - Basic kill/death counts from real queries
- **Threat Scoring** - Multi-dimensional analysis engine
- **Battle Detection** - Clustering algorithm groups killmails
- **Surveillance Profiles** - Real-time matching engine

### 🔴 What Contains Placeholders (Needs Cleanup)
- **Fleet Analysis** - Hardcoded DPS values, modulo-based ship classification
- **Wormhole Operations** - Random data generation, all systems show as C6
- **Character Preferences** - Returns empty arrays instead of querying data
- **Battle Analysis** - Detection works but advanced analysis returns empty data
- **Market Pricing** - Stub client returns zeros

### 📋 Key Documentation
- **Implementation Status**: `/workspace/docs/IMPLEMENTATION_STATUS_COMBINED.md`
- **Cleanup Plan**: `/workspace/docs/PLACEHOLDER_CLEANUP_PLAN.md`
- **Clean Vision**: `/workspace/docs/CLEAN_CODEBASE_VISION.md`
- **Revised Requirements**: `/workspace/docs/REVISED_REQUIREMENTS.md`

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

# Admin User Bootstrap (Production)
ADMIN_BOOTSTRAP_CHARACTERS      # Comma-separated character names: "John Doe,Jane Smith"
ADMIN_BOOTSTRAP_CHARACTER_IDS   # Comma-separated character IDs: "123456789,987654321"
```

## Common Development Tasks

### Querying the Database

To run SQL queries directly:
```elixir
# In IEx:
{:ok, result} = Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT * FROM table_name WHERE condition = $1", [value])

# Example:
{:ok, result} = Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT type_id, type_name FROM eve_item_types WHERE type_name LIKE $1 LIMIT 10", ["%Abaddon%"])
```

### Quality Assurance
```bash
# Quality Gate Scripts (Sprint 11)
./scripts/quality_check.sh      # Run all quality checks (same as CI)
./scripts/quality_fix.sh        # Auto-fix quality issues where possible
./scripts/analyze_todos.sh       # Analyze TODO comments for Sprint 12

# Quality check options
SKIP_DIALYZER=true ./scripts/quality_check.sh  # Skip slow Dialyzer check
RUN_TESTS=true ./scripts/quality_check.sh      # Include full test suite
CHECK_DOCS=true ./scripts/quality_check.sh     # Include documentation checks

# Individual quality checks
mix compile --warnings-as-errors  # Compilation with warnings as errors
mix format --check-formatted      # Check code formatting
mix credo --strict                 # Static analysis
mix dialyzer                      # Type checking
mix deps.audit                    # Security audit
mix test --cover                  # Tests with coverage
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