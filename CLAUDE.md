# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EVE DMV is an Elixir Phoenix application for real-time PvP intelligence and analytics for EVE Online. It uses:
- **Phoenix 1.7.21** with LiveView for real-time UI updates
- **Ash Framework 3.4** for declarative resource management (replaces traditional Ecto schemas)
- **Broadway** for high-throughput killmail ingestion pipeline
- **PostgreSQL 16** with partitioning and materialized views for performance
- **EVE SSO OAuth2** for authentication with automatic token refresh
- **OpenTelemetry** for observability and performance monitoring

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
mix test --cover       # Run with coverage (70% minimum)
mix credo --strict     # Static analysis
mix format             # Format code
mix dialyzer           # Type checking
./scripts/quality_check.sh  # Run all quality gates

# Ash-Specific Commands
mix ash_postgres.create           # Generate migration from resource changes
mix ash_postgres.migrate          # Run Ash migrations
mix ash.codegen <resource_name>   # Generate resource code

# Static Data Management
mix eve.load_static_data          # Load EVE static data (ships, systems)
mix eve.update_sde                # Update to latest SDE version
mix eve.stats                     # Display database statistics

# Performance Analysis
mix eve.analyze_performance       # Analyze query performance
mix eve.check_indexes             # Verify index health
mix eve.benchmark                 # Run performance benchmarks

# Partition Management (Automated with pg_cron)
mix eve.partition_manager status          # Show current partition status
mix eve.partition_manager create_future   # Create partitions for next 3 months
mix eve.partition_manager create 2024-12  # Create partition for specific month
mix eve.partition_manager cleanup         # Clean up old partitions (12 months retention)
mix eve.partition_manager cleanup --months=6  # Custom retention period
mix eve.partition_manager stats           # Show detailed partition statistics

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

### IMPORTANT: pg_cron Extension Setup

EVE DMV uses automated partition management via the pg_cron PostgreSQL extension. This is **automatically configured** in the development environment but requires setup in production.

**Development Environment (Docker/DevContainer)**:
- ✅ pg_cron is automatically installed and configured
- ✅ Partition automation works out of the box
- ✅ Use `mix eve.partition_manager status` to verify

**Production Environment Setup**:
```bash
# Install pg_cron extension (requires superuser privileges)
CREATE EXTENSION IF NOT EXISTS pg_cron;

# Run migrations to set up automation
mix ecto.migrate

# Verify setup
mix eve.partition_manager status
```

**Without pg_cron** (CI/Testing environments):
- ⚠️ Automated partition management is disabled
- ✅ Manual partition management still available via Mix tasks
- ✅ All core functionality works normally

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

The application follows hexagonal architecture with bounded contexts:
- **Contexts**: Domain logic organized by business capability
- **Resources**: Ash resources replace Ecto schemas
- **Infrastructure**: External integrations (ESI, wanderer-kills)
- **Real-time**: PubSub and LiveView for instant updates
- **Pipeline**: Broadway for streaming data processing

See [ARCHITECTURE.md](/workspace/ARCHITECTURE.md) for detailed system design.

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
- **Partitioned tables**: `killmails_raw` partitioned by month for scalability with automated management
- **Materialized views**: Pre-computed aggregations for performance
- **Covering indexes**: Optimized for common query patterns
- **Bulk operations**: Use `Ash.bulk_create` for high-volume inserts
- **Resource snapshots**: Track schema evolution in `priv/resource_snapshots/`
- **Automated partition management**: pg_cron jobs create future partitions and clean up old ones
- **Archive management**: Automatic old data archival via partition cleanup

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
- **Authentication** - Full EVE SSO integration with token refresh
- **Kill Feed** (`/feed`) - Real-time killmail display from wanderer-kills SSE
- **Database Pipeline** - Broadway ingestion with partitioned storage and error handling
- **Static Data** - 49,906 item types and 8,436 systems loaded via SDE import
- **Character Stats** - Kill/death counts, ISK efficiency from materialized views
- **Threat Scoring** - Multi-dimensional analysis with configurable weights
- **Battle Detection** - Clustering algorithm with timeline reconstruction
- **Surveillance Profiles** - Real-time matching with filter builder UI
- **Performance Monitoring** - Query analysis, index health, telemetry
- **API Authentication** - Separate API key system for programmatic access
- **Admin Features** - Performance dashboard, user management

### 🔴 What Contains Placeholders (Current Cleanup Priority)
- **Fleet Analysis** - Hardcoded DPS values (200/600/800/1000), EHP values (15K/50K/80K/100K)
- **Wormhole Operations** - Random data generation, extensive modulo-based classifications
- **Battle Phase Analysis** - Minimal implementation (single phase, modulo-based side assignment)
- **Ship Classification** - Arbitrary mass thresholds (10M), modulo-based logic
- **Surveillance Dashboard** - Random alert counts and confidence scores
- **Battle Sharing System** - Complete random data generation for statistics
- **Corporation Analysis** - Random threat score generation
- **Market Pricing** - Stub client returns `{:ok, %{price: 0.0}}` (deferred)

### ✅ What Actually Works with Real Data (Updated)
- **Character Intelligence** - All preference functions work with real database queries:
  - `get_ship_preferences()` - lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:115
  - `get_weapon_preferences()` - lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:181
  - `get_gang_size_patterns()` - lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:721
  - `calculate_activity_stats()` - lib/eve_dmv_web/live/character_analysis/helpers/character_data_loader.ex:908

### 📋 Key Documentation
- **Architecture**: `/workspace/ARCHITECTURE.md` - System design and patterns
- **Requirements**: `/workspace/docs/REVISED_REQUIREMENTS.md` - Updated to reflect current implementation
- **Implementation Gaps**: `/workspace/docs/IMPLEMENTATION_GAPS.md` - Missing or incomplete features
- **Placeholder Audit**: `/workspace/docs/PLACEHOLDER_IMPLEMENTATIONS.md` - Hardcoded values and fake data to remove
- **Implementation Status**: `/workspace/docs/IMPLEMENTATION_STATUS_COMBINED.md`
- **Clean Vision**: `/workspace/docs/CLEAN_CODEBASE_VISION.md`

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

### Core Architecture
- `lib/eve_dmv/application.ex` - Application supervisor tree
- `lib/eve_dmv/api.ex` - Central Ash API domain
- `lib/eve_dmv/contexts/` - Bounded contexts (battle_analysis, surveillance, etc.)
- `ARCHITECTURE.md` - Complete system design documentation

### Data Pipeline
- `lib/eve_dmv/killmails/killmail_pipeline.ex` - Broadway pipeline
- `lib/eve_dmv/killmails/sse_producer.ex` - SSE connection handler
- `lib/eve_dmv/database/` - Partitioning, materialized views, query optimization

### Web Interface
- `lib/eve_dmv_web/router.ex` - Route definitions
- `lib/eve_dmv_web/live/` - LiveView modules
- `lib/eve_dmv_web/components/` - Reusable UI components

### Intelligence Engine
- `lib/eve_dmv/intelligence/` - Analysis engines and scoring
- `lib/eve_dmv/analytics/` - Battle detection, fleet analysis
- `lib/eve_dmv/surveillance/` - Profile matching engine

### Configuration
- `config/config.exs` - Base configuration
- `config/runtime.exs` - Runtime configuration with .env support
- `.env` - Environment variable configuration