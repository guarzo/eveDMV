defmodule EveDmv.Eve.CircuitBreaker do
  @moduledoc """

  Circuit breaker implementation for ESI API calls.

  Protects against cascading failures by:
  - Tracking failure rates per service
  - Opening circuit when failure threshold exceeded
  - Attempting recovery after cooldown period
  - Providing fast-fail during outages
  """

  use GenServer

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  defstruct [
    :service_name,
    :state,
    :failure_count,
    :success_count,
    :last_failure_time,
    :failure_threshold,
    :recovery_timeout,
    :success_threshold,
    :timeout,
    :error_classifier
  ]

  # Circuit states
  # Normal operation
  @closed :closed
  # Failing fast, not calling service
  @open :open
  # Testing if service recovered
  @half_open :half_open

  # Default configuration
  # Failures before opening
  @default_failure_threshold 5
  # 30 seconds before trying recovery
  @default_recovery_timeout 30_000
  # Successes needed to close circuit
  @default_success_threshold 3
  # Request timeout
  @default_timeout 10_000

  @doc """
  Default error classifier that treats all errors as failures.
  Returns true for any error, preserving the original circuit breaker behavior.
  """
  @spec default_error_classifier(term()) :: boolean()
  def default_error_classifier(_error), do: true

  # Client API

  @doc """
  Start a circuit breaker for a service.
  """
  def start_link(opts) do
    service_name = Keyword.fetch!(opts, :service_name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(service_name))
  end

  @doc """
  Execute a function with circuit breaker protection.

  ## Options

    * `:timeout` - Request timeout in milliseconds (default: #{@default_timeout})
    * `:error_classifier` - A function `(error :: term()) :: boolean()` that determines
      whether an error should count toward opening the circuit. Returns `true` if the
      error should be counted as a failure, `false` otherwise. When `false`, the error
      is still returned but doesn't affect circuit state. Defaults to the instance-level
      classifier or `default_error_classifier/1` which treats all errors as failures.

  ## Examples

      # Only count 5xx errors as failures
      CircuitBreaker.call(:my_service, fn -> ... end,
        error_classifier: fn
          {:http_error, status} when status >= 500 -> true
          _ -> false
        end
      )

  """
  @spec call(atom(), (-> term()), keyword()) ::
          {:ok, term()} | {:error, atom() | {atom(), term()}}
  def call(service_name, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    error_classifier = Keyword.get(opts, :error_classifier)

    case GenServer.whereis(via_tuple(service_name)) do
      nil ->
        # No circuit breaker started, execute directly
        try do
          task = Task.async(fun)

          # Don't double-wrap if function already returns {:ok, _} or {:error, _}
          case Task.await(task, timeout) do
            {:ok, _} = result -> result
            {:error, _} = error -> error
            result -> {:ok, result}
          end
        catch
          :exit, {:timeout, _} -> {:error, :timeout}
          kind, reason -> {:error, {kind, reason}}
        end

      pid ->
        GenServer.call(pid, {:execute_request, fun, timeout, error_classifier}, timeout + 1000)
    end
  end

  @doc """
  Get current circuit state for a service.
  """
  @spec get_state(atom()) :: atom()
  def get_state(service_name) do
    case GenServer.whereis(via_tuple(service_name)) do
      # Default to closed if breaker not started
      nil -> @closed
      pid -> GenServer.call(pid, :get_state)
    end
  end

  @doc """
  Get circuit breaker statistics.
  """
  @spec get_stats(atom()) :: map()
  def get_stats(service_name) do
    case GenServer.whereis(via_tuple(service_name)) do
      nil -> %{state: @closed, failure_count: 0, success_count: 0}
      pid -> GenServer.call(pid, :get_stats)
    end
  end

  @doc """
  Reset circuit breaker to closed state.
  """
  @spec reset(atom()) :: :ok
  def reset(service_name) do
    case GenServer.whereis(via_tuple(service_name)) do
      nil -> :ok
      pid -> GenServer.call(pid, :reset)
    end
  end

  @doc """
  Set circuit breaker state for testing purposes.
  """
  @spec set_state(atom(), atom()) :: :ok
  def set_state(service_name, new_state) when new_state in [:open, :closed, :half_open] do
    case GenServer.whereis(via_tuple(service_name)) do
      nil -> :ok
      pid -> GenServer.call(pid, {:set_state, new_state})
    end
  end

  # Private client functions

  defp via_tuple(service_name) do
    {:via, Registry, {EveDmv.Registry, {__MODULE__, service_name}}}
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    service_name = Keyword.fetch!(opts, :service_name)
    failure_threshold = Keyword.get(opts, :failure_threshold, @default_failure_threshold)
    recovery_timeout = Keyword.get(opts, :recovery_timeout, @default_recovery_timeout)
    success_threshold = Keyword.get(opts, :success_threshold, @default_success_threshold)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    error_classifier = Keyword.get(opts, :error_classifier, &default_error_classifier/1)

    state = %__MODULE__{
      service_name: service_name,
      state: @closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      failure_threshold: failure_threshold,
      recovery_timeout: recovery_timeout,
      success_threshold: success_threshold,
      timeout: timeout,
      error_classifier: error_classifier
    }

    Logger.info("Circuit breaker started for service: #{inspect(service_name)}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    current_state = determine_current_state(state)
    {:reply, current_state, %{state | state: current_state}}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    current_state = determine_current_state(state)

    stats = %{
      service_name: state.service_name,
      state: current_state,
      failure_count: state.failure_count,
      success_count: state.success_count,
      last_failure_time: state.last_failure_time,
      failure_threshold: state.failure_threshold,
      recovery_timeout: state.recovery_timeout,
      success_threshold: state.success_threshold
    }

    {:reply, stats, %{state | state: current_state}}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    Logger.info("Circuit breaker reset for service: #{inspect(state.service_name)}")

    new_state = %{
      state
      | state: @closed,
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_state, new_state}, _from, state) do
    Logger.info(
      "Circuit breaker state set to #{new_state} for service: #{inspect(state.service_name)}"
    )

    updated_state = %{state | state: new_state}
    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:execute_request, fun, timeout, call_error_classifier}, _from, state) do
    current_state = determine_current_state(state)
    # Use call-level classifier if provided, otherwise fall back to instance-level
    error_classifier = call_error_classifier || state.error_classifier

    case current_state do
      @open ->
        {:reply, {:error, :circuit_open}, %{state | state: current_state}}

      state_val when state_val in [@closed, @half_open] ->
        execute_and_handle_result(fun, timeout, error_classifier, %{state | state: current_state})
    end
  end

  @impl GenServer
  def handle_cast(:success, state) do
    new_state = handle_success(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:failure, reason}, state) do
    new_state = handle_failure(state, reason)
    {:noreply, new_state}
  end

  # Private server functions

  defp execute_and_handle_result(fun, timeout, error_classifier, state) do
    # Execute function in a separate process without linking to avoid EXIT propagation
    # that could crash the GenServer before we can handle errors
    caller = self()
    ref = make_ref()

    pid = spawn(fn -> execute_and_send(fun, caller, ref) end)
    monitor = Process.monitor(pid)

    await_result(ref, monitor, pid, timeout, error_classifier, state)
  end

  defp execute_and_send(fun, caller, ref) do
    result =
      try do
        {:ok, fun.()}
      rescue
        e -> {:exception, e}
      catch
        kind, reason -> {:caught, kind, reason}
      end

    send(caller, {ref, result})
  end

  defp await_result(ref, monitor, pid, timeout, error_classifier, state) do
    receive do
      {^ref, {:ok, raw_result}} ->
        Process.demonitor(monitor, [:flush])
        handle_raw_result(raw_result, error_classifier, state)

      {^ref, {:exception, exception}} ->
        Process.demonitor(monitor, [:flush])
        handle_exception_result(exception, state)

      {^ref, {:caught, kind, reason}} ->
        Process.demonitor(monitor, [:flush])
        handle_caught_result(kind, reason, state)

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        handle_down_result(reason, state)
    after
      timeout ->
        handle_timeout(ref, monitor, pid, state)
    end
  end

  defp handle_exception_result(exception, state) do
    # Exceptions always count as failures (infrastructure issues)
    new_state = handle_failure(state, exception)
    {:reply, {:error, {:error, exception}}, new_state}
  end

  defp handle_caught_result(kind, reason, state) do
    # Catches always count as failures (infrastructure issues)
    new_state = handle_failure(state, {kind, reason})
    {:reply, {:error, {kind, reason}}, new_state}
  end

  defp handle_down_result(reason, state) do
    # Process crashed unexpectedly - count as failure
    new_state = handle_failure(state, reason)
    {:reply, {:error, {:exit, reason}}, new_state}
  end

  defp handle_timeout(ref, monitor, pid, state) do
    Process.demonitor(monitor, [:flush])
    Process.exit(pid, :kill)

    # Drain any pending message from the killed process to prevent leaked messages
    # in the GenServer's mailbox that could interfere with future operations
    receive do
      {^ref, _} -> :ok
    after
      0 -> :ok
    end

    new_state = handle_failure(state, :timeout)
    {:reply, {:error, :timeout}, new_state}
  end

  defp handle_raw_result(raw_result, error_classifier, state) do
    # Don't double-wrap if function already returns {:ok, _} or {:error, _}
    case raw_result do
      {:ok, _} = result ->
        # Record success and return as-is
        new_state = handle_success(state)
        {:reply, result, new_state}

      {:error, reason} ->
        # Use classifier to determine if error counts toward circuit failure
        if error_classifier.(reason) do
          # Error counts as failure - increment failure state
          new_state = handle_failure(state, reason)
          {:reply, {:error, reason}, new_state}
        else
          # Error doesn't count as failure - don't affect circuit state
          {:reply, {:error, reason}, state}
        end

      result ->
        # Wrap non-tuple results
        new_state = handle_success(state)
        {:reply, {:ok, result}, new_state}
    end
  end

  defp determine_current_state(state) do
    case state.state do
      @open ->
        if can_attempt_recovery?(state) do
          @half_open
        else
          @open
        end

      current ->
        current
    end
  end

  defp can_attempt_recovery?(state) do
    case state.last_failure_time do
      nil ->
        false

      last_failure ->
        DateTimeUtils.diff(DateTime.utc_now(), last_failure, :millisecond) >=
          state.recovery_timeout
    end
  end

  defp handle_success(state) do
    current_state = determine_current_state(state)

    case current_state do
      @half_open ->
        new_success_count = state.success_count + 1

        if new_success_count >= state.success_threshold do
          Logger.info(
            "Circuit breaker closed for service: #{state.service_name} (recovery successful)"
          )

          %{state | state: @closed, failure_count: 0, success_count: 0, last_failure_time: nil}
        else
          %{state | state: @half_open, success_count: new_success_count}
        end

      @closed ->
        # Reset failure count on successful calls when closed
        %{state | failure_count: 0, success_count: state.success_count + 1}

      @open ->
        # Should not happen, but handle gracefully
        state
    end
  end

  defp handle_failure(state, reason) do
    current_state = determine_current_state(state)
    new_failure_count = state.failure_count + 1
    now = DateTime.utc_now()

    Logger.warning(
      "Circuit breaker failure for service #{state.service_name}: #{inspect(reason)}"
    )

    new_state = %{
      state
      | failure_count: new_failure_count,
        success_count: 0,
        last_failure_time: now
    }

    case current_state do
      state_val when state_val in [@closed, @half_open] ->
        if new_failure_count >= state.failure_threshold do
          Logger.error(
            "Circuit breaker opened for service: #{state.service_name} (failures: #{new_failure_count})"
          )

          # Emit telemetry event for monitoring
          :telemetry.execute(
            [:eve_dmv, :circuit_breaker, :opened],
            %{failure_count: new_failure_count},
            %{service: state.service_name, reason: reason}
          )

          %{new_state | state: @open}
        else
          %{new_state | state: current_state}
        end

      @open ->
        new_state
    end
  end
end
