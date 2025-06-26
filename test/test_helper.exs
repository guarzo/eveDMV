# Configure ExUnit for async testing and better output
ExUnit.start(
  capture_log: true,
  max_failures: 10,
  timeout: 30_000,
  exclude: [:skip]
)

# Configure Ecto test adapter
Ecto.Adapters.SQL.Sandbox.mode(EveDmv.Repo, :auto)

# Helper module for common test utilities
defmodule EveDmv.TestHelpers do
  @moduledoc """
  Common test helpers and utilities.
  """

  alias EveDmv.Repo

  def setup_database do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  def cleanup_database do
    Ecto.Adapters.SQL.Sandbox.checkin(Repo)
  end
end
