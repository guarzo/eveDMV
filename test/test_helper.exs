# Configure ExUnit for async testing and better output
ExUnit.start(
  capture_log: true,
  timeout: 30_000,
  exclude: [:skip]
)

require Logger

# Start the application to ensure the repo is available
{:ok, _} = Application.ensure_all_started(:eve_dmv)

# Verify we're using the correct pool for testing
repo_config = Application.get_env(:eve_dmv, EveDmv.Repo)
pool_class = Keyword.get(repo_config, :pool)

if pool_class != Ecto.Adapters.SQL.Sandbox do
  Logger.warning("Test repository is not using SQL Sandbox pool: #{inspect(pool_class)}")
  Logger.warning("Current repo config: #{inspect(repo_config)}")
  raise "Test environment requires Ecto.Adapters.SQL.Sandbox pool"
end

# Set up the sandbox mode for testing
Ecto.Adapters.SQL.Sandbox.mode(EveDmv.Repo, :manual)

# Set up Mox for testing
Mox.defmock(HTTPoisonMock, for: HTTPoison.Base)

# Helper module for common test utilities
defmodule EveDmv.TestHelpers do
  @moduledoc """
  Common test helpers and utilities.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Repo

  def setup_database do
    :ok = SQL.Sandbox.checkout(Repo)
  end

  def cleanup_database do
    SQL.Sandbox.checkin(Repo)
  end
end
