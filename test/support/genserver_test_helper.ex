defmodule EveDmv.GenServerTestHelper do
  @moduledoc """
  Helpers for testing GenServers with SQL Sandbox.

  This module provides utilities for safely starting, stopping, and managing
  GenServers in tests while ensuring proper SQL Sandbox integration.

  ## Usage

  In your test file:

      defmodule MyGenServerTest do
        use EveDmv.DataCase, async: false

        import EveDmv.GenServerTestHelper

        setup do
          {:ok, pid} = start_genserver_for_test(MyGenServer, [])
          {:ok, server_pid: pid}
        end

        test "my test", %{server_pid: pid} do
          # Test your GenServer
        end
      end

  ## Key Features

  - Automatically enables shared sandbox mode for GenServer DB access
  - Graceful cleanup on test exit
  - Handles already-running GenServers
  - Provides utilities for stopping GenServers safely
  """

  alias Ecto.Adapters.SQL.Sandbox

  @doc """
  Starts a GenServer and ensures it's properly registered with SQL Sandbox.

  This function:
  1. Enables shared sandbox mode so the GenServer can access the database
  2. Stops any existing instance of the GenServer
  3. Starts a fresh instance
  4. Allows the GenServer to use the test's database connection
  5. Registers cleanup to stop the GenServer on test exit

  ## Options

  - All options are passed to the GenServer's `start_link/1`
  - `:name` - The registered name (defaults to the module name)

  ## Examples

      {:ok, pid} = start_genserver_for_test(MyGenServer, [])
      {:ok, pid} = start_genserver_for_test(MyGenServer, some_option: true)

  ## Returns

  - `{:ok, pid}` - The GenServer was started successfully
  - `{:error, reason}` - Failed to start the GenServer
  """
  @spec start_genserver_for_test(module(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_genserver_for_test(module, opts \\ []) do
    # Ensure we're using shared sandbox mode so GenServer can access DB
    Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Stop any existing instance
    stop_if_running(module)

    # Small delay to ensure process is fully stopped
    Process.sleep(50)

    # Start fresh instance
    case module.start_link(opts) do
      {:ok, pid} ->
        # Allow the GenServer to access the database
        Sandbox.allow(EveDmv.Repo, self(), pid)

        # Register cleanup on test exit
        ExUnit.Callbacks.on_exit(fn ->
          stop_genserver_gracefully(pid)
        end)

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # Already running, just return the pid
        Sandbox.allow(EveDmv.Repo, self(), pid)
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Starts multiple GenServers in dependency order.

  Some GenServers depend on others being started first. This function
  starts them in the order provided, ensuring each is fully started
  before moving to the next.

  ## Examples

      {:ok, pids} = start_genservers_in_order([
        {ProfileRepository, []},
        {MatchingEngine, []},
        {NotificationService, []}
      ])

  ## Returns

  - `{:ok, pids}` - Map of module => pid for all started GenServers
  - `{:error, {module, reason}}` - First module that failed to start
  """
  @spec start_genservers_in_order([{module(), keyword()}]) ::
          {:ok, %{module() => pid()}} | {:error, {module(), term()}}
  def start_genservers_in_order(genservers) do
    # Ensure we're using shared sandbox mode
    Sandbox.mode(EveDmv.Repo, {:shared, self()})

    # Stop all in reverse order first
    genservers
    |> Enum.map(fn {module, _opts} -> module end)
    |> Enum.reverse()
    |> Enum.each(&stop_if_running/1)

    # Small delay
    Process.sleep(50)

    # Start in order
    result =
      Enum.reduce_while(genservers, {:ok, %{}}, fn {module, opts}, {:ok, acc} ->
        case module.start_link(opts) do
          {:ok, pid} ->
            Sandbox.allow(EveDmv.Repo, self(), pid)
            {:cont, {:ok, Map.put(acc, module, pid)}}

          {:error, {:already_started, pid}} ->
            Sandbox.allow(EveDmv.Repo, self(), pid)
            {:cont, {:ok, Map.put(acc, module, pid)}}

          {:error, reason} ->
            {:halt, {:error, {module, reason}}}
        end
      end)

    case result do
      {:ok, pids} ->
        # Register cleanup for all
        ExUnit.Callbacks.on_exit(fn ->
          pids
          |> Map.values()
          |> Enum.each(&stop_genserver_gracefully/1)
        end)

        {:ok, pids}

      error ->
        error
    end
  end

  @doc """
  Stops a GenServer gracefully, handling already-stopped cases.

  This function safely stops a GenServer, catching any exit exceptions
  that might occur if the process has already terminated.

  ## Examples

      :ok = stop_genserver_gracefully(pid)
      :ok = stop_genserver_gracefully(MyGenServer)

  ## Returns

  Always returns `:ok`
  """
  @spec stop_genserver_gracefully(pid() | atom()) :: :ok
  def stop_genserver_gracefully(pid_or_name) do
    pid = resolve_pid(pid_or_name)

    if pid && Process.alive?(pid) do
      try do
        GenServer.stop(pid, :normal, 5_000)
      catch
        :exit, _ -> :ok
      end
    end

    :ok
  end

  @doc """
  Stops a GenServer if it's currently running.

  ## Examples

      :ok = stop_if_running(MyGenServer)
  """
  @spec stop_if_running(module() | pid()) :: :ok
  def stop_if_running(module) when is_atom(module) do
    case GenServer.whereis(module) do
      nil -> :ok
      pid -> stop_genserver_gracefully(pid)
    end
  end

  def stop_if_running(pid) when is_pid(pid) do
    stop_genserver_gracefully(pid)
  end

  @doc """
  Waits for a GenServer to be ready by calling a health check function.

  Some GenServers may need time to initialize. This function repeatedly
  calls the provided function until it returns a truthy value or times out.

  ## Examples

      :ok = wait_for_ready(fn -> MyGenServer.ready?() end, timeout: 5_000)

  ## Options

  - `:timeout` - Maximum time to wait in ms (default: 5_000)
  - `:interval` - Check interval in ms (default: 100)
  """
  @spec wait_for_ready((-> boolean()), keyword()) :: :ok | {:error, :timeout}
  def wait_for_ready(ready_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    interval = Keyword.get(opts, :interval, 100)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait_for_ready(ready_fn, interval, deadline)
  end

  defp do_wait_for_ready(ready_fn, interval, deadline) do
    if System.monotonic_time(:millisecond) > deadline do
      {:error, :timeout}
    else
      try do
        if ready_fn.() do
          :ok
        else
          Process.sleep(interval)
          do_wait_for_ready(ready_fn, interval, deadline)
        end
      catch
        _, _ ->
          Process.sleep(interval)
          do_wait_for_ready(ready_fn, interval, deadline)
      end
    end
  end

  @doc """
  Resolves a name or pid to a pid.

  ## Examples

      pid = resolve_pid(MyGenServer)
      pid = resolve_pid(some_pid)
  """
  @spec resolve_pid(pid() | atom() | nil) :: pid() | nil
  def resolve_pid(pid) when is_pid(pid), do: pid
  def resolve_pid(nil), do: nil

  def resolve_pid(name) when is_atom(name) do
    GenServer.whereis(name)
  end

  def resolve_pid(_), do: nil
end
