# .devcontainer/Dockerfile

# 1) Base image with Erlang/OTP + Elixir
FROM elixir:1.17-otp-27

# 2) Non-interactive & dev env
ENV DEBIAN_FRONTEND=noninteractive \
    MIX_ENV=dev \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# 3) Install OS tools, Postgres client, locales, Vim, Node.js LTS & Yarn, plus cleanup
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      gnupg \
      inotify-tools \
      locales \
      net-tools \
      postgresql-client \
      procps \
      vim \
 && locale-gen en_US.UTF-8 \
 && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g yarn @anthropic-ai/claude-code \
 && mix local.hex --force \
 && mix local.rebar --force \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# 4) Use /workspace to match devcontainer.json
WORKDIR /workspace

# 5) Cache Elixir deps (invalidate only when mix.exs or mix.lock change)
COPY mix.exs mix.lock ./
RUN mix deps.get

# 6) Copy remainder of your app
COPY . .

# 7) Default to bash (you can always run `mix phx.server` via VSCode tasks)
CMD ["bash"]
