# EVE DMV

A real-time PvP activity tracking platform for EVE Online that provides actionable intelligence for fleet commanders, recruiters, and PvP enthusiasts.

## 📚 Documentation

- **[Project Overview](./docs/project-management/project-overview.md)** - Start here for project vision and architecture
- **[Product Requirements](./docs/product-requirements.md)** - Detailed feature specifications
- **[Development Setup](./docs/development/devcontainer.md)** - Get started with development
- **[Current Roadmap](./docs/project-management/prioritized-roadmap.md)** - See what we're building next

For complete documentation, see the [/docs directory](./docs/README.md).

## Features

- 🔴 **Live Kill Feed** - Real-time PvP activity with enriched ISK and fitting data
- 🔍 **Character Intelligence** - Deep analytics for pilot assessment and recruitment
- 🚨 **Smart Surveillance** - Custom alerts with advanced filtering and notifications
- ⚡ **Fleet Optimizer** - Data-driven ship assignment recommendations
- 📊 **Performance Metrics** - Mass balance, usefulness index, and activity trends

## Quick Start with Dev Containers

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [VS Code](https://code.visualstudio.com/)
- [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

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

5. **Open in VS Code and start dev container:**
   ```bash
   code .
   ```
   - VS Code will prompt to "Reopen in Container" - click it
   - Or use Command Palette (`Ctrl+Shift+P`) → "Remote-Containers: Open Folder in Container"

6. **Wait for setup to complete:**
   - The container will automatically install dependencies and set up the database
   - Phoenix server will start automatically on http://localhost:4010

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
│   ├── eve_tracker/        # Business logic and contexts
│   └── eve_tracker_web/    # Web interface (controllers, views, live views)
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
- **killmails_enriched** - Enriched killmail data with ISK values and module tags
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
DATABASE_URL=ecto://postgres:postgres@db/eve_tracker_dev

# External Services
WANDERER_SSE_URL=https://wanderer-kills.example.com/sse
JANICE_API_BASE=https://janice.e-351.com/api
```

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/eve_tracker/killmails_test.exs

# Run tests matching pattern
mix test --grep "surveillance"
```

## Deployment

See [Technical Design](./docs/architecture/DESIGN.md) for detailed deployment architecture and instructions.

### Docker Production Build

```bash
# Build production image
docker build -t eve-tracker .

# Run with environment variables
docker run -p 4000:4000 --env-file .env.prod eve-tracker
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests and linting (`mix test && mix format && mix credo`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Pull Request Checklist

See [Pull Request Checklist](./docs/development/pull-request-checklist.md) for the complete checklist.

## Documentation

Complete project documentation is organized in the [`docs/`](./docs/) directory:

- **[Documentation Index](./docs/README.md)** - Complete overview of all documentation
- **[Product Requirements](./docs/product-requirements.md)** - Business requirements and user stories  
- **[Technical Design](./docs/architecture/DESIGN.md)** - Architecture and implementation details
- **[Development Setup](./docs/development/devcontainer.md)** - Dev container configuration

See the [Documentation Index](./docs/README.md) for the complete list of guides, implementation details, and reference materials.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [CCP Games](https://www.ccpgames.com/) for EVE Online and the ESI API
- [zKillboard](https://zkillboard.com/) for killmail data
- The EVE Online community for feedback and support 