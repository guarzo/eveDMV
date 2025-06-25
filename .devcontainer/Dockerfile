# Use latest Alpine with Erlang/Elixir 1.15
FROM elixir:1.15-alpine

# Install build tools, Node.js 20.x, and other dependencies
RUN apk add --no-cache \
    build-base \
    git \
    bash \
    curl \
    openssl \
    openssl-dev \
    inotify-tools \
    nodejs-current \
    npm \
    postgresql-client \
    ca-certificates \
    tzdata \
    make \
    gcc \
    g++ \
    libc-dev \
    linux-headers

# Create vscode user for development
RUN addgroup -g 1000 vscode && \
    adduser -u 1000 -G vscode -s /bin/bash -D vscode

# Install global tools
RUN npm install -g npm@latest

# Set up workspace directory
WORKDIR /workspace
RUN chown -R vscode:vscode /workspace

# Switch to vscode user
USER vscode

# Install Hex and Rebar for Elixir
RUN mix local.hex --force && \
    mix local.rebar --force

# Set up shell environment
RUN echo 'export MIX_ENV=dev' >> ~/.bashrc && \
    echo 'export LANG=en_US.UTF-8' >> ~/.bashrc && \
    echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias phoenix="mix phx.server"' >> ~/.bashrc && \
    echo 'alias iex="iex -S mix"' >> ~/.bashrc

# Create bash history file
RUN touch ~/.bash_history

# Default to bash
CMD ["bash"] 