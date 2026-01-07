# Use the official Elixir image
FROM elixir:1.19-alpine AS builder

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

# Copy source code
COPY config/ ./config/
COPY priv/ ./priv/
COPY lib/ ./lib/

# Compile the project
RUN mix compile

# Digest static assets (creates cache_manifest.json for production)
RUN mix phx.digest

# Build the release
RUN mix release

# Start a new build stage for the runtime image
# IMPORTANT: Must match Alpine version from elixir:1.19-alpine to ensure OpenSSL compatibility
FROM alpine:3.21 AS runtime

# Install runtime dependencies
# OpenSSL must come from Alpine edge to match OTP 27.2+ which requires OpenSSL 3.4+
# (EVP_PKEY_sign_message_init was added in OpenSSL 3.4.0)
RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    ncurses-libs \
    libbz2 && \
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
    openssl \
    libcrypto3 \
    libssl3

# Create app user
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup

# Create app directory
WORKDIR /app

# Copy the release from builder stage (includes digested static assets)
COPY --from=builder --chown=appuser:appgroup /app/_build/prod/rel/eve_dmv ./

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