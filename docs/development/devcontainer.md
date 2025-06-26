# Dev Container Configuration

Below is a recommended VS Code Dev Container configuration for local development of the EVE PvP Tracker (Elixir + Phoenix) using the latest stable versions of Elixir, Alpine, Node, Postgres, and Redis.

## Configuration Files

### 1. `.devcontainer/devcontainer.json`

```json
{
  "name": "EVE PvP Tracker Dev Container",
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  },
  "forwardPorts": [4000, 5432, 6379],
  "postCreateCommand": "mix deps.get && npm ci --prefix assets",
  "settings": {
    "terminal.integrated.shell.linux": "/bin/bash",
    "editor.formatOnSave": true
  },
  "extensions": [
    "phoenixframework.phoenix",
    "jakebecker.elixir-ls",
    "esbenp.prettier-vscode"
  ],
  "remoteUser": "vscode"
}
```

### 2. `.devcontainer/Dockerfile`

```dockerfile
# Use latest Alpine with Erlang/Elixir 1.15
FROM elixir:1.15-alpine

# Install build tools, Node.js 20.x, and other dependencies
RUN apk add --no-cache \
    build-base \
    git \
    bash \
    openssl \
    inotify-tools \
    nodejs-current \
    npm \
    postgresql-client

WORKDIR /workspace

# Pre-install Elixir deps for faster rebuilds
COPY mix.* ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && mix deps.compile

# Copy the rest of the app
COPY . .

# Install and build JS assets
RUN npm ci --prefix assets

# Default to bash
CMD ["bash"]
```

### 3. `docker-compose.yml`

```yaml
version: "3.9"

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: eve_tracker_dev
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    command: ["redis-server", "--save", "900", "1"]
    ports:
      - "6379:6379"

  app:
    build:
      context: .
      dockerfile: .devcontainer/Dockerfile
    command: >
      bash -lc "mix ecto.create && mix ecto.migrate && mix phx.server"
    volumes:
      - .:/workspace:cached
    working_dir: /workspace
    env_file: .env
    ports:
      - "4000:4000"
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
```

### 4. `.env.example`

```dotenv
# Database URL for Ecto (Postgres)
DATABASE_URL=ecto://postgres:postgres@db/eve_tracker_dev

# Redis URL (Phoenix.Presence, caching)
REDIS_URL=redis://redis:6379

# EVE SSO credentials
EVE_SSO_CLIENT_ID=your_ccp_client_id
EVE_SSO_CLIENT_SECRET=your_ccp_client_secret

# External Services
WANDERER_SSE_URL=https://wanderer-kills.example.com/sse
JANICE_API_BASE=https://janice.e-351.com/api
MUTAMARKET_API_BASE=https://mutamarket.com/api/rest

# Phoenix secret (generate with mix phx.gen.secret)
SECRET_KEY_BASE=YOUR_SECRET_KEY_BASE
```

## Setup Features

With this configuration you get:

- **Elixir 1.15** on Alpine Linux for a minimal image
- **Node.js 20.x** via `nodejs-current` and `npm` for asset builds
- **Postgres 15-alpine** and **Redis 7-alpine** for development services
- **Dev Container** that installs dependencies, prebuilds assets, and forwards necessary ports

## Usage

Open in VS Code with the Remote–Containers extension, and you'll be ready to develop immediately. If you need debugging configurations or LiveReload tweaks, let me know!
