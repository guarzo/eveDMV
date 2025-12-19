# .devcontainer/Dockerfile

# 1) Base image with Erlang/OTP + Elixir
FROM elixir:1.19-otp-28

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
      sudo \
      vim \
 && locale-gen en_US.UTF-8 \
 && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g yarn @anthropic-ai/claude-code \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# 4) Create vscode user for devcontainer compatibility
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
 && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
 && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
 && chmod 0440 /etc/sudoers.d/$USERNAME

# 5) Install hex and rebar for both root and vscode user
RUN mix local.hex --force \
 && mix local.rebar --force

USER $USERNAME
RUN mix local.hex --force \
 && mix local.rebar --force
USER root

# 6) Use /workspace to match devcontainer.json
WORKDIR /workspace

# 7) Cache Elixir deps (invalidate only when mix.exs or mix.lock change)
COPY mix.exs mix.lock ./
RUN chown -R $USERNAME:$USERNAME /workspace
USER $USERNAME
RUN mix deps.get
USER root

# 8) Copy remainder of your app and set ownership
COPY --chown=$USERNAME:$USERNAME . .

# 9) Default to bash (you can always run `mix phx.server` via VSCode tasks)
CMD ["bash"]
