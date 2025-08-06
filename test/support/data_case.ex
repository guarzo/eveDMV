defmodule EveDmv.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EveDmv.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias EveDmv.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import EveDmv.DataCase
      import EveDmv.Factories
    end
  end

  setup tags do
    setup_sandbox(tags)

    # Seed common test ships if needed
    if tags[:seed_ships] != false do
      EveDmv.TestDataHelpers.seed_test_ships()
    end

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # Wait for repo to be fully registered before starting sandbox owner
    wait_for_repo_registration()

    pid = Sandbox.start_owner!(EveDmv.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  # Wait for repo to be properly registered in the Ecto registry
  defp wait_for_repo_registration(attempts \\ 0, max_attempts \\ 30) do
    if attempts >= max_attempts do
      raise "Repo registration timeout after #{max_attempts} attempts"
    end

    case GenServer.whereis(EveDmv.Repo) do
      nil ->
        Process.sleep(100)
        wait_for_repo_registration(attempts + 1, max_attempts)

      _pid ->
        # Repo is running, give it a moment to be fully registered
        Process.sleep(25)
        :ok
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
