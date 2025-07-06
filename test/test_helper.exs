# Configure ExUnit for async testing and better output
ExUnit.start(
  capture_log: true,
  max_failures: 10,
  timeout: 30_000,
  exclude: [:skip]
)

# Set up the sandbox mode properly
Ecto.Adapters.SQL.Sandbox.mode(EveDmv.Repo, :manual)

# Create a setup that works for async tests
defmodule TestHelper do
  import ExUnit.Callbacks
  alias Ecto.Adapters.SQL.Sandbox

  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(EveDmv.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end
end

# Set up Mox for testing
Mox.defmock(HTTPoisonMock, for: HTTPoison.Base)

# Helper module for common test utilities
defmodule EveDmv.TestHelpers do
  @moduledoc """
  Common test helpers and utilities.
  """

  alias EveDmv.Repo
  alias Ecto.Adapters.SQL

  def setup_database do
    :ok = SQL.Sandbox.checkout(Repo)
  end

  def cleanup_database do
    SQL.Sandbox.checkin(Repo)
  end
end
