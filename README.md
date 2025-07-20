# EVE DMV

A real-time PvP activity tracking platform for EVE Online. **Active development** with multiple working intelligence features and advanced analytics in progress.

## 📚 Documentation

### Current Status
- **Active Development** - Sprint 19 focused on removing placeholder implementations
- See **[CLAUDE.md](./CLAUDE.md)** for development guidelines and current implementation status

### Development
- **[Project Instructions](./CLAUDE.md)** - Development guidelines and commands
- **[Architecture Guide](./docs/ARCHITECTURE.md)** - System design and patterns

For complete documentation, see the [/docs directory](./docs/README.md). For deployment instructions, see [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md).

## Current Features

### ✅ Working Features
- 🔴 **Live Kill Feed** (`/feed`) - Real-time killmail display from wanderer-kills SSE
- 🔍 **Character Intelligence** (`/character/:character_id`) - Complete analysis with ship preferences, activity patterns, and intelligence summary
- 🏢 **Corporation Intelligence** (`/corporation/:corporation_id`) - Member activity analysis, timezone heatmaps, participation metrics
- 🌍 **System Intelligence** (`/system/:system_id`) - Activity statistics, danger assessment, alliance presence analysis
- 🔍 **Universal Search** (`/search`) - Auto-completion for characters, corporations, and systems
- ⚔️ **Battle Analysis** (In Development) - Combat log parsing, ship performance analysis, battle metrics
- 🔐 **EVE SSO Authentication** - Login/logout with EVE Online account
- 📊 **Static Data** - Complete EVE universe data (49,906 items including all ships)
- 🗃️ **Database Infrastructure** - PostgreSQL with Broadway pipeline processing 50-100 killmails/minute
- 📈 **Monitoring Dashboard** (`/monitoring`) - Error tracking, pipeline health, performance monitoring

### 🚧 In Development (Sprint 19)
- **Character Intelligence Cleanup** - Replacing placeholder functions with real database queries
- **Advanced Battle Analysis** - Multi-system battle correlation and tactical phase detection
- **Threat Intelligence Engine** - Multi-dimensional threat scoring with real data

### 📋 Future Priorities
- **Price Integration** - Real-time ISK calculations via Janice/Mutamarket APIs
- **Advanced Surveillance** - Profile matching and smart alert system
- **Fleet Composition Tools** - Wormhole fleet optimization algorithms
- **Predictive Analytics** - Machine learning for threat assessment

**Note**: All working features use real data and algorithms. No mock data in production features.

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) and Docker Compose
- OR: Elixir 1.15+, Node.js 20+, PostgreSQL 16+

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd eveDMV
   ```

2. **Copy environment variables:**
   ```bash
   cp .env.example .env
   ```

3. **Configure EVE SSO (Required):**
   - Go to [CCP Developers Portal](https://developers.eveonline.com/)
   - Create a new application with callback URL: `http://localhost:4010/auth/eve/callback`
   - Update `.env` with your `EVE_SSO_CLIENT_ID` and `EVE_SSO_CLIENT_SECRET`

4. **Generate Phoenix secret:**
   ```bash
   # Run this in any Elixir environment or use online generator
   mix phx.gen.secret
   # Update SECRET_KEY_BASE in .env with the generated value
   ```

### Environment Setup and Secrets

**Important:** Never commit sensitive credentials to version control. The `.env` file is gitignored for security.

1. **Required Environment Variables:**
   - `EVE_SSO_CLIENT_ID` - Your EVE application client ID
   - `EVE_SSO_CLIENT_SECRET` - Your EVE application client secret
   - `SECRET_KEY_BASE` - Phoenix secret key (generate with `mix phx.gen.secret`)
   - `DATABASE_URL` - PostgreSQL connection string

2. **Optional API Keys:**
   - `JANICE_API_KEY` - For market price data (get from Janice dashboard)
   - `MUTAMARKET_API_KEY` - For mutated module prices

3. **Security Best Practices:**
   - Rotate secrets regularly
   - Use strong, unique values for each environment
   - Never reuse production secrets in development
   - Store production secrets in a secure secret management system

4. **Regenerating Compromised Secrets:**
   If any secrets are exposed:
   - Immediately regenerate the affected credentials
   - Update all environments with new values
   - Review access logs for any unauthorized usage

5. **Start the application:**
   ```bash
   # Using Docker Compose
   docker-compose up -d
   
   # Or manually
   mix setup  # Install deps, create/migrate DB
   mix phx.server  # Start server on http://localhost:4010
   ```

### Manual Setup (Alternative)

If you prefer not to use dev containers:

1. **Install dependencies:**
   - Elixir 1.15+
   - Node.js 20+
   - PostgreSQL 15+
   - Redis 7+

2. **Setup database:**
   ```bash
   mix deps.get
   mix ecto.create
   mix ecto.migrate
   ```

3. **Install Node.js dependencies:**
   ```bash
   npm install --prefix assets
   ```

4. **Start the application:**
   ```bash
   mix phx.server
   ```

## Development

### Useful Commands

```bash
# Elixir/Phoenix
mix deps.get              # Install dependencies
mix ecto.migrate          # Run database migrations
mix ecto.rollback         # Rollback last migration
mix test                  # Run tests
mix test --cover          # Run tests with coverage
mix format                # Format code
mix credo                 # Static analysis
mix dialyzer              # Type checking

# Phoenix
mix phx.server            # Start server
mix phx.routes            # List all routes
iex -S mix                # Interactive Elixir shell

# Database
mix ecto.create           # Create database
mix ecto.drop             # Drop database
mix ecto.reset            # Drop, create, and migrate
mix ecto.gen.migration    # Generate new migration

# Frontend
npm install --prefix assets           # Install JS dependencies
npm run build --prefix assets         # Build assets
npm run watch --prefix assets         # Watch and rebuild assets
```

### Project Structure

```
├── .devcontainer/          # Dev container configuration
├── assets/                 # Frontend assets (CSS, JS)
├── config/                 # Application configuration
├── lib/
│   ├── eve_dmv/            # Business logic with DDD structure
│   │   ├── api.ex          # Main Ash API domain
│   │   └── contexts/       # Domain contexts (battle, character, fleet, etc.)
│   └── eve_dmv_web/        # Web interface (controllers, views, live views)
├── priv/
│   ├── repo/               # Database migrations and seeds
│   └── static/             # Static assets
├── test/                   # Test files
├── docker-compose.yml      # Development services
└── mix.exs                 # Project configuration
```

### Database

The application uses PostgreSQL with range partitioning for optimal performance:

- **killmails_raw** - Raw killmail data (partitioned by timestamp)
- **materialized views** - Pre-computed aggregations for performance
- **users** - User accounts linked to EVE characters
- **surveillance_profiles** - Custom alert configurations

### External Services

- **EVE ESI** - Character, corporation, and universe data
- **wanderer-kills** - Enriched killmail data (primary source)
- **zKillboard** - Fallback killmail source
- **Janice/Mutamarket** - Market price data for ISK calculations

## Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# Required
EVE_SSO_CLIENT_ID=your_client_id
EVE_SSO_CLIENT_SECRET=your_client_secret
SECRET_KEY_BASE=generated_secret

# Database
DATABASE_URL=ecto://postgres:postgres@db/eve_dmv_dev

# External Services
WANDERER_KILLS_SSE_URL=http://host.docker.internal:4004/api/v1/kills/stream
JANICE_API_BASE=https://janice.e-351.com/api
```

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/eve_dmv/killmails_test.exs

# Run tests matching pattern
mix test --grep "surveillance"
```

## Deployment

See [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md) for detailed deployment instructions.

### Docker Production Build

```bash
# Build production image
docker build -t eve-dmv .

# Run with environment variables
docker run -p 4000:4000 --env-file .env.prod eve-dmv
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests and linting (`mix test && mix format && mix credo`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Pull Request Checklist

Before submitting a pull request:
- All tests must pass
- Code must be formatted (`mix format`)
- Static analysis must pass (`mix credo --strict`)
- Coverage should meet minimum threshold (70%)

## Documentation

Complete project documentation is organized in the [`docs/`](./docs/) directory:

- **[Documentation Index](./docs/README.md)** - Complete overview of all documentation
- **[Product Requirements](./docs/product-requirements.md)** - Business requirements and user stories  
- **[Architecture](./docs/ARCHITECTURE.md)** - System design and implementation details
- **[Implementation Status](./docs/IMPLEMENTATION_STATUS_COMBINED.md)** - Current feature status

See the [Documentation Index](./docs/README.md) for the complete list of guides, implementation details, and reference materials.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [CCP Games](https://www.ccpgames.com/) for EVE Online and the ESI API
- [zKillboard](https://zkillboard.com/) for killmail data
- The EVE Online community for feedback and support 