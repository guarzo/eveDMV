# Use official Elixir image based on Ubuntu
FROM elixir:1.17

# Install dependencies and configure locales
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    inotify-tools \
    postgresql-client \
    locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Set locale environment variables
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Create vscode user for development
RUN groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --shell /bin/bash --create-home vscode

# Set up workspace directory
WORKDIR /workspace
RUN chown -R vscode:vscode /workspace

# Create directories that will be volume mounted to ensure proper ownership
RUN mkdir -p /workspace/deps /workspace/_build && \
    chown -R vscode:vscode /workspace/deps /workspace/_build

RUN npm install -g @anthropic-ai/claude-code

# Switch to vscode user
USER vscode

# Install Hex and Rebar for Elixir
RUN mix local.hex --force && \
    mix local.rebar --force

# Set up shell environment
RUN echo 'export MIX_ENV=dev' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias phoenix="mix phx.server"' >> ~/.bashrc && \
    echo 'alias iex="iex -S mix"' >> ~/.bashrc

# Create bash history file
RUN touch ~/.bash_history

# Default to bash
CMD ["bash"] 