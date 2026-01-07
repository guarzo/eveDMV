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

  ## SQL Sandbox Helpers for GenServer Tests

  When testing GenServers or spawned processes that need database access,
  use these helper functions:

  - `allow_sandbox_access/2` - Allow a specific process to share the test's DB connection
  - `set_shared_sandbox_mode/0` - Set sandbox to shared mode for all spawned processes

  Example:
      setup do
        # For tests that spawn processes needing DB access
        set_shared_sandbox_mode()

        {:ok, pid} = MyGenServer.start_link([])
        allow_sandbox_access(pid)

        on_exit(fn -> GenServer.stop(pid, :normal, 5_000) end)
        {:ok, server_pid: pid}
      end
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
      import EveDmv.ApiTestHelpers
    end
  end

  setup tags do
    setup_sandbox(tags)

    # Only seed test ships if explicitly requested via @tag seed_ships: true
    # Ship data is already loaded from SDE - only use this for tests that need specific test ships
    if tags[:seed_ships] == true do
      EveDmv.TestDataHelpers.seed_test_ships()
    end

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.

  Options via tags:
  - `async: true` - Run test asynchronously (each test gets its own sandbox)
  - `async: false` - Run test synchronously with shared sandbox (required for GenServer tests)
  """
  def setup_sandbox(tags) do
    # Wait for repo to be fully registered before starting sandbox owner
    wait_for_repo_registration()

    pid = Sandbox.start_owner!(EveDmv.Repo, shared: not tags[:async])

    on_exit(fn ->
      # Give time for any pending operations to complete before stopping sandbox
      # This helps prevent "owner exited" errors from async operations
      Process.sleep(50)
      Sandbox.stop_owner(pid)
    end)
  end

  @doc """
  Allow a process to use the test's database connection.

  Call this for any GenServer or spawned process that needs DB access.
  The process will share the database connection with the test process.

  ## Example

      {:ok, pid} = MyGenServer.start_link([])
      allow_sandbox_access(pid)

  ## Parameters

  - `pid` - The PID of the process to allow
  - `owner_pid` - The owner process (defaults to `self()`, the test process)
  """
  @spec allow_sandbox_access(pid(), pid()) :: :ok | {:error, term()}
  def allow_sandbox_access(pid, owner_pid \\ self()) when is_pid(pid) do
    Sandbox.allow(EveDmv.Repo, owner_pid, pid)
  end

  @doc """
  Set sandbox to shared mode for tests that spawn processes.

  In shared mode, all processes can access the same database connection.
  Use this sparingly as it disables async test execution for the test module.

  **Important:** Tests using this must have `async: false` in their module definition.

  ## Example

      setup do
        set_shared_sandbox_mode()
        # Now any spawned process can access the database
        :ok
      end
  """
  @spec set_shared_sandbox_mode() :: :ok
  def set_shared_sandbox_mode do
    Sandbox.mode(EveDmv.Repo, {:shared, self()})
  end

  @doc """
  Checkout a database connection for the current process.

  Useful when you need explicit control over the sandbox lifecycle.
  """
  @spec checkout_sandbox(keyword()) :: :ok
  def checkout_sandbox(opts \\ []) do
    :ok = Sandbox.checkout(EveDmv.Repo, opts)
  end

  @doc """
  Check in the database connection for the current process.
  """
  @spec checkin_sandbox() :: :ok
  def checkin_sandbox do
    :ok = Sandbox.checkin(EveDmv.Repo)
  end

  # Wait for repo to be properly registered in the Ecto registry
  # In CI environments under heavy load, the repo may take longer to become available
  # This function now attempts recovery if the repo is not available
  defp wait_for_repo_registration(attempts \\ 0, max_attempts \\ 100) do
    if attempts >= max_attempts do
      # Log diagnostic info before raising
      repo_pid = GenServer.whereis(EveDmv.Repo)

      app_started =
        Application.started_applications() |> Enum.any?(fn {app, _, _} -> app == :eve_dmv end)

      raise "Repo registration timeout after #{max_attempts} attempts (#{max_attempts * 100}ms). " <>
              "Repo PID: #{inspect(repo_pid)}. " <>
              "App started: #{app_started}. " <>
              "This may indicate database connection issues or resource exhaustion in CI."
    end

    case GenServer.whereis(EveDmv.Repo) do
      nil ->
        # Attempt recovery every 10 attempts (1 second) if repo is missing
        if rem(attempts, 10) == 9 do
          attempt_repo_recovery()
        end

        Process.sleep(100)
        wait_for_repo_registration(attempts + 1, max_attempts)

      pid ->
        # Verify the repo process is alive and responsive
        if Process.alive?(pid) do
          # Use a simple GenServer call to verify the process is responsive
          # This is lighter weight than running a SQL query
          case verify_repo_responsive(pid) do
            :ok ->
              :ok

            :retry ->
              Process.sleep(100)
              wait_for_repo_registration(attempts + 1, max_attempts)
          end
        else
          # Process registered but not alive - attempt recovery
          attempt_repo_recovery()
          Process.sleep(100)
          wait_for_repo_registration(attempts + 1, max_attempts)
        end
    end
  end

  # Attempt to recover the repo if it's not available
  # This handles cases where the repo crashes during test execution
  defp attempt_repo_recovery do
    # First check if the application supervisor is running
    case Process.whereis(EveDmv.Supervisor) do
      nil ->
        # Application supervisor not running, try to restart the app
        Application.ensure_all_started(:eve_dmv)

      supervisor_pid when is_pid(supervisor_pid) ->
        # Supervisor is running but repo is not - this shouldn't happen with one_for_one
        # The repo should auto-restart, so just wait
        :ok
    end
  rescue
    # Don't crash if recovery fails - the main loop will retry
    _ -> :ok
  end

  # Verify the repo process is responsive by checking if it can handle messages
  defp verify_repo_responsive(pid) do
    # Use a short timeout call to verify the process is responsive
    # We use :sys.get_state which is a standard OTP call
    case :sys.get_state(pid, 1_000) do
      _state -> :ok
    end
  rescue
    _ -> :retry
  catch
    :exit, {:timeout, _} -> :retry
    :exit, _ -> :retry
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
