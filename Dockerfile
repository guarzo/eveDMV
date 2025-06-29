# Use the official Elixir image
FROM elixir:1.17.2-alpine AS builder

# Set environment variables
ENV MIX_ENV=prod

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

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

# Copy assets and build them
COPY assets/ ./assets/
COPY config/ ./config/
COPY priv/ ./priv/

# Install node dependencies and build assets
RUN cd assets && npm install && cd ..
RUN mix assets.deploy

# Copy source code
COPY lib/ ./lib/

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
    openssl

# Create app user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

# Create app directory
WORKDIR /app

# Copy the release from builder stage
COPY --from=builder --chown=appuser:appgroup /app/_build/prod/rel/eve_dmv ./

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

# Start the application
CMD ["bin/eve_dmv", "start"]