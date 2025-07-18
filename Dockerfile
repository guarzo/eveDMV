# Use the official Elixir image
FROM elixir:1.17.2-alpine AS builder

# Set environment variables
ENV MIX_ENV=prod

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    git \
    bzip2-dev \
    linux-headers \
    musl-dev

# Fix picosat_elixir compilation issue on Alpine
RUN mkdir -p /usr/include/sys && \
    ln -sf /usr/include/unistd.h /usr/include/sys/unistd.h

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy assets and source code
COPY assets/ ./assets/
COPY config/ ./config/
COPY priv/ ./priv/
COPY lib/ ./lib/

# Build assets using Elixir tools (no npm needed)
RUN mix assets.deploy

# Compile the project
RUN mix compile

# Build the release
RUN mix release

# Start a new build stage for the runtime image
FROM alpine:3.18 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    ncurses-libs \
    openssl \
    libbz2

# Create app user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

# Create app directory
WORKDIR /app

# Copy the release from builder stage
COPY --from=builder --chown=appuser:appgroup /app/_build/prod/rel/eve_dmv ./

# Copy the digested static assets (includes cache_manifest.json)
COPY --from=builder --chown=appuser:appgroup /app/priv/static ./priv/static

# Copy entrypoint script
COPY --chown=appuser:appgroup entrypoint.sh ./
RUN chmod +x entrypoint.sh

# Switch to app user
USER appuser

# Expose port
EXPOSE 4000

# Set environment variables
ENV HOME=/app
ENV MIX_ENV=prod

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD bin/eve_dmv rpc "1 + 1"

# Start the application with automatic migrations
CMD ["./entrypoint.sh"]