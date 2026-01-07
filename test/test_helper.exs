# Configure ExUnit for async testing and better output
ExUnit.start(
  capture_log: true,
  timeout: 30_000,
  exclude: [:skip]
)

require Logger

# Ensure support modules are loaded before use
# Use Code.ensure_loaded! to load from compiled beam files if available,
# falling back to require_file if compilation hasn't happened yet
try do
  Code.ensure_loaded!(EveDmv.Test.PartitionHelper)
  Code.ensure_loaded!(EveDmv.Test.PartitionHelpers)
rescue
  ArgumentError ->
    # Modules not compiled yet, load from source
    Code.require_file("support/partition_helper.ex", __DIR__)
    Code.require_file("support/partition_helpers.ex", __DIR__)
end

# Helper function for waiting on repo readiness and connection management
defmodule TestHelper do
  @moduledoc false

  def drain_connections do
    # Get database host from DATABASE_URL or fall back to defaults
    db_host = get_database_host()

    # Terminate any orphaned connections from previous test runs
    drain_query = """
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname LIKE 'eve_dmv_test%'
      AND state = 'idle'
      AND query_start < NOW() - INTERVAL '30 seconds';
    """

    # Connect directly to postgres database to run cleanup
    case Postgrex.start_link(
           hostname: db_host,
           username: System.get_env("DB_USER", "postgres"),
           password: System.get_env("DB_PASS", "postgres"),
           database: "postgres"
         ) do
      {:ok, conn} ->
        Postgrex.query(conn, drain_query, [])
        GenServer.stop(conn)
        Logger.info("Drained orphaned test connections from #{db_host}")

      {:error, reason} ->
        Logger.warning("Could not drain connections from #{db_host}: #{inspect(reason)}")
    end
  end

  # Extract database host from DATABASE_URL or use default
  defp get_database_host do
    case System.get_env("DATABASE_URL") do
      nil ->
        System.get_env("DB_HOST", "db")

      url ->
        # Parse host from DATABASE_URL (postgres://user:pass@host:port/db)
        case URI.parse(url) do
          %URI{host: host} when is_binary(host) -> host
          _ -> System.get_env("DB_HOST", "db")
        end
    end
  end

  def wait_for_repo_ready(attempts \\ 0, max_attempts \\ 50) do
    cond do
      attempts >= max_attempts ->
        Logger.error(
          "Repo readiness check timeout after #{max_attempts} attempts (#{max_attempts * 100}ms)"
        )

        raise "Repo failed to become ready within #{max_attempts * 100}ms"

      is_nil(GenServer.whereis(EveDmv.Repo)) ->
        log_repo_not_registered(attempts)
        Process.sleep(100)
        TestHelper.wait_for_repo_ready(attempts + 1, max_attempts)

      true ->
        verify_repo_with_query(attempts, max_attempts)
    end
  end

  defp log_repo_not_registered(attempts) do
    if rem(attempts, 10) == 0 and attempts > 0 do
      Logger.warning("Repo not registered after #{attempts * 100}ms, still waiting...")
    end
  end

  defp verify_repo_with_query(attempts, max_attempts) do
    case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT 1", []) do
      {:ok, _} ->
        Logger.info("Repo is ready for tests")
        :ok

      {:error, reason} ->
        if rem(attempts, 5) == 0 do
          Logger.warning("Repo registered but query failed: #{inspect(reason)}")
        end

        Process.sleep(100)
        TestHelper.wait_for_repo_ready(attempts + 1, max_attempts)
    end
  end
end

# Start the application to ensure the repo is available
{:ok, _} = Application.ensure_all_started(:eve_dmv)

# Wait for repo to be fully ready
TestHelper.wait_for_repo_ready()

# Initialize StaticData ETS tables for testing
EveDmv.StaticData.start_link()

# Ensure partitions exist for test data
require Logger
Logger.info("Creating test partitions...")
EveDmv.Test.PartitionHelper.ensure_test_partitions()
Logger.info("Test partitions ready")

# Verify we're using the correct pool for testing
# If the pool is wrong at this point, the test.exs or runtime.exs configuration is incorrect
repo_config = Application.get_env(:eve_dmv, EveDmv.Repo) || []
pool_class = Keyword.get(repo_config, :pool)

if pool_class != Ecto.Adapters.SQL.Sandbox do
  Logger.error("""
  CRITICAL: Test repository is not using SQL Sandbox pool!
  Current pool: #{inspect(pool_class)}
  Current repo config: #{inspect(repo_config)}

  This configuration error must be fixed in config/test.exs or config/runtime.exs.
  Note: Changing the config after application start won't restart the repo.

  Environment:
    MIX_ENV: #{System.get_env("MIX_ENV")}
    DATABASE_URL: #{(System.get_env("DATABASE_URL") && "[SET]") || "[NOT SET]"}
    TEST_DATABASE_URL: #{(System.get_env("TEST_DATABASE_URL") && "[SET]") || "[NOT SET]"}
  """)

  raise "Test environment requires SQL Sandbox pool. See error above for details."
else
  Logger.info("Test repository using correct SQL Sandbox pool")
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
