# Configure ExUnit for async testing and better output
ExUnit.start(
  capture_log: true,
  timeout: 30_000,
  exclude: [:skip]
)

require Logger

# Helper function for waiting on repo readiness
defmodule TestHelper do
  def wait_for_repo_ready(attempts \\ 0, max_attempts \\ 20) do
    if attempts >= max_attempts do
      Logger.warning("Repo readiness check timeout after #{max_attempts} attempts")
    else
      case GenServer.whereis(EveDmv.Repo) do
        nil ->
          Process.sleep(100)
          TestHelper.wait_for_repo_ready(attempts + 1, max_attempts)

        _pid ->
          # Test a simple query to ensure repo is fully functional
          case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT 1", []) do
            {:ok, _} ->
              Logger.info("Repo is ready for tests")
              :ok

            {:error, _} ->
              Process.sleep(100)
              TestHelper.wait_for_repo_ready(attempts + 1, max_attempts)
          end
      end
    end
  end
end

# Start the application to ensure the repo is available
{:ok, _} = Application.ensure_all_started(:eve_dmv)

# Wait for repo to be fully ready
TestHelper.wait_for_repo_ready()

# Initialize StaticData ETS tables for testing
EveDmv.StaticData.start_link()

# Ensure we're using the correct pool for testing
# Force the pool to be Sandbox if it's not already set correctly
repo_config = Application.get_env(:eve_dmv, EveDmv.Repo) || []
pool_class = Keyword.get(repo_config, :pool)

if pool_class != Ecto.Adapters.SQL.Sandbox do
  Logger.warning("Test repository is not using SQL Sandbox pool: #{inspect(pool_class)}")
  Logger.warning("Current repo config: #{inspect(repo_config)}")

  # Force the correct test configuration
  test_config = [
    username: "postgres",
    password: "postgres",
    hostname: "db",
    database: "eve_dmv_test#{System.get_env("MIX_TEST_PARTITION")}",
    port: 5432,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2,
    ownership_timeout: 60_000,
    timeout: 60_000
  ]

  Application.put_env(:eve_dmv, EveDmv.Repo, test_config)
  Logger.info("Forced test database configuration with SQL Sandbox")
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
