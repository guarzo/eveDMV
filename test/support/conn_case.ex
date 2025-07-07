defmodule EveDmvWeb.ConnCase do
  @moduledoc """
  Test case for controller tests requiring Phoenix.ConnTest.

  Provides connection setup, database sandboxing, and common test utilities.
  Supports async tests with PostgreSQL via `use EveDmvWeb.ConnCase, async: true`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      unquote(setup_endpoint())
      unquote(import_test_helpers())
    end
  end

  defp setup_endpoint do
    quote do
      @endpoint EveDmvWeb.Endpoint
      use EveDmvWeb, :verified_routes
    end
  end

  defp import_test_helpers do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import EveDmvWeb.ConnCase
    end
  end

  setup tags do
    EveDmv.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
