# EVE DMV Deployment Guide

This guide covers deploying EVE DMV using Docker Compose for production environments.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Basic Deployment](#basic-deployment)
- [Reverse Proxy Setup (Optional)](#reverse-proxy-setup-optional)
- [Post-Deployment](#post-deployment)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Prerequisites

- Docker Engine 20.10+ and Docker Compose 2.0+
- A server with at least 2GB RAM and 10GB disk space
- Domain name (optional, but recommended for production)
- EVE Online Developer Application credentials
- SSL certificate (for production deployment)

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/yourusername/eve-dmv.git
cd eve-dmv
```

2. Copy the example environment file:
```bash
cp .env.example .env.production
```

3. Configure essential variables (see [Configuration](#configuration))

4. Start the application:
```bash
docker-compose -f docker-compose.production.yml up -d
```

## Configuration

### Required Environment Variables

Create a `.env.production` file with the following variables:

```bash
# Application Settings
MIX_ENV=prod
PHX_HOST=yourdomain.com  # or your server IP
PHX_PORT=4000
SECRET_KEY_BASE=your-64-char-secret-key  # Generate with: mix phx.gen.secret

# Database Configuration
DATABASE_URL=ecto://postgres:strong-password@db/eve_dmv_prod
POSTGRES_PASSWORD=strong-password
POSTGRES_USER=postgres
POSTGRES_DB=eve_dmv_prod

# EVE Online SSO Configuration
EVE_SSO_CLIENT_ID=your-eve-sso-client-id
EVE_SSO_CLIENT_SECRET=your-eve-sso-client-secret
EVE_SSO_REDIRECT_URI=https://yourdomain.com/auth/user/eve_sso/callback

# External Services
WANDERER_KILLS_SSE_URL=http://wanderer-kills:4004/api/v1/kills/stream
WANDERER_KILLS_BASE_URL=http://wanderer-kills:4004
PIPELINE_ENABLED=true

# Optional: Market Data APIs
JANICE_API_KEY=your-janice-api-key
JANICE_ENABLED=true
MUTAMARKET_API_KEY=your-mutamarket-api-key

# Redis Configuration
REDIS_URL=redis://redis:6379

# Performance Settings
POOL_SIZE=10
PORT=4000
```

### Generate Secrets

```bash
# Generate SECRET_KEY_BASE
docker run --rm -it elixir:1.17-alpine mix phx.gen.secret

# Generate strong database password
openssl rand -base64 32
```

## Basic Deployment

### 1. Create Production Docker Compose File

The repository includes a `docker-compose.production.yml` file. Here's what it contains:

- **PostgreSQL** database with optimized settings
- **Redis** for caching and real-time features
- **EVE DMV application** container
- The app will be accessible on port 4000 by default

### 2. Deploy with Docker Compose

```bash
# Start all services
docker-compose -f docker-compose.production.yml up -d

# View logs
docker-compose -f docker-compose.production.yml logs -f

# Stop services
docker-compose -f docker-compose.production.yml down
```

The application will be available at `http://your-server-ip:4000`

## Reverse Proxy Setup (Optional)

If you want to use HTTPS and a domain name, you'll need a reverse proxy. Here are examples for popular options:

### Option A: Using Nginx

Basic Nginx configuration for proxying to EVE DMV:

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option B: Using Caddy

Caddy automatically handles HTTPS certificates:

```
yourdomain.com {
    reverse_proxy localhost:4000
}
```

### Option C: Using Traefik

Docker Compose labels for Traefik:

```yaml
app:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.evedmv.rule=Host(`yourdomain.com`)"
    - "traefik.http.routers.evedmv.entrypoints=websecure"
    - "traefik.http.routers.evedmv.tls.certresolver=letsencrypt"
    - "traefik.http.services.evedmv.loadbalancer.server.port=4000"
```

### Option D: Using Apache

```apache
<VirtualHost *:80>
    ServerName yourdomain.com
    
    ProxyPreserveHost On
    ProxyPass / http://localhost:4000/
    ProxyPassReverse / http://localhost:4000/
    
    RewriteEngine on
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://localhost:4000/$1" [P,L]
</VirtualHost>
```

### Important Notes for WebSockets

EVE DMV uses Phoenix LiveView which requires WebSocket support. Ensure your reverse proxy:
- Supports WebSocket upgrades
- Has appropriate timeout settings (at least 60 seconds)
- Forwards the necessary headers

### 3. Production Build

The included `Dockerfile` is optimized for production:

```dockerfile
# Build stage
FROM elixir:1.17-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git python3 nodejs npm

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy assets
COPY assets assets
COPY priv priv
RUN cd assets && npm install

# Compile assets
RUN mix assets.deploy

# Compile the release
COPY lib lib
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Create release
RUN mix release

# Runtime stage
FROM alpine:3.19 AS app

RUN apk add --no-cache openssl ncurses-libs libgcc libstdc++

WORKDIR /app

RUN chown nobody:nobody /app

USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/eve_dmv ./

ENV HOME=/app

CMD ["bin/eve_dmv", "start"]
```

## Post-Deployment

### 1. Database Setup

```bash
# Run migrations
docker-compose -f docker-compose.production.yml exec app bin/eve_dmv eval "EveDmv.Release.migrate"

# Load static data
docker-compose -f docker-compose.production.yml exec app bin/eve_dmv eval "EveDmv.Release.load_static_data"
```

### 2. Verify Deployment

```bash
# Check if services are running
docker-compose -f docker-compose.production.yml ps

# Check application health
curl http://localhost:4000/api/health

# View application logs
docker-compose -f docker-compose.production.yml logs app
```

### 3. Configure Log Rotation

Create `/etc/logrotate.d/eve-dmv`:

```
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size 100M
    missingok
    delaycompress
    copytruncate
}
```

## Maintenance

### Backup Database

```bash
# Create backup
docker-compose -f docker-compose.production.yml exec db pg_dump -U postgres eve_dmv_prod | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Restore backup
gunzip < backup_20240110_120000.sql.gz | docker-compose -f docker-compose.production.yml exec -T db psql -U postgres eve_dmv_prod
```

### Update Application

```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose -f docker-compose.production.yml build app
docker-compose -f docker-compose.production.yml up -d

# Run migrations
docker-compose -f docker-compose.production.yml exec app bin/eve_dmv eval "EveDmv.Release.migrate"
```

### Monitor Performance

```bash
# View logs
docker-compose -f docker-compose.production.yml logs -f app

# Check resource usage
docker stats

# Access PostgreSQL
docker-compose -f docker-compose.production.yml exec db psql -U postgres eve_dmv_prod

# Check slow queries
SELECT query, calls, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

## Troubleshooting

### Common Issues

1. **Database connection errors**
   - Check DATABASE_URL format
   - Ensure db service is healthy: `docker-compose ps`
   - Check PostgreSQL logs: `docker-compose logs db`

2. **Memory issues**
   - Increase Docker memory limit
   - Adjust POOL_SIZE in environment
   - Check for memory leaks: `docker stats`

3. **SSL/TLS errors**
   - Verify certificate paths in nginx.conf
   - Check certificate validity: `openssl x509 -in ssl/cert.pem -text -noout`

4. **Performance issues**
   - Enable query monitoring in application
   - Check slow query log
   - Review database indexes

### Debug Commands

```bash
# Interactive shell
docker-compose -f docker-compose.production.yml exec app bin/eve_dmv remote

# Run mix tasks
docker-compose -f docker-compose.production.yml exec app bin/eve_dmv eval "IO.inspect(:application.which_applications())"

# Check migrations status
docker-compose -f docker-compose.production.yml exec app bin/eve_dmv eval "EveDmv.Release.migration_status"
```

## Security Considerations

1. **Environment Variables**
   - Never commit `.env.production` to version control
   - Use strong, unique passwords
   - Rotate secrets regularly

2. **Network Security**
   - Use firewall rules to restrict access
   - Only expose ports 80/443
   - Keep internal services on Docker network

3. **Updates**
   - Regularly update Docker images
   - Monitor security advisories
   - Enable automatic security updates

4. **Monitoring**
   - Set up alerts for suspicious activity
   - Monitor failed login attempts
   - Track API usage patterns

5. **Backups**
   - Automate daily backups
   - Test restore procedures
   - Store backups off-site

## Health Checks

Add health check endpoint monitoring:

```bash
# Simple health check
curl https://yourdomain.com/api/health

# Detailed health check
curl https://yourdomain.com/api/health/detailed
```

## Support

For issues or questions:
- Check application logs: `docker-compose logs -f app`
- Review error tracking dashboard at `/monitoring`
- Consult the [main documentation](./README.md)

---

Remember to customize all configuration values for your specific deployment environment!