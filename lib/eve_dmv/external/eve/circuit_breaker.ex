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
    :timeout
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
  """
  @spec call(atom(), (-> term()), keyword()) :: {:ok, term()} | {:error, atom() | binary()}
  def call(service_name, fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case GenServer.whereis(via_tuple(service_name)) do
      nil ->
        # No circuit breaker started, execute directly
        try do
          task = Task.async(fun)
          {:ok, Task.await(task, timeout)}
        catch
          :exit, {:timeout, _} -> {:error, :timeout}
          kind, reason -> {:error, {kind, reason}}
        end

      pid ->
        GenServer.call(pid, {:execute_request, fun, timeout}, timeout + 1000)
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

    state = %__MODULE__{
      service_name: service_name,
      state: @closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      failure_threshold: failure_threshold,
      recovery_timeout: recovery_timeout,
      success_threshold: success_threshold,
      timeout: timeout
    }

    Logger.info("Circuit breaker started for service: #{service_name}")
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
    Logger.info("Circuit breaker reset for service: #{state.service_name}")

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
    Logger.info("Circuit breaker state set to #{new_state} for service: #{state.service_name}")

    updated_state = %{state | state: new_state}
    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:execute_request, fun, timeout}, _from, state) do
    current_state = determine_current_state(state)

    case current_state do
      @open ->
        {:reply, {:error, :circuit_open}, %{state | state: current_state}}

      state_val when state_val in [@closed, @half_open] ->
        execute_and_handle_result(fun, timeout, %{state | state: current_state})
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

  defp execute_and_handle_result(fun, timeout, state) do
    # Execute with timeout
    task = Task.async(fun)
    result = Task.await(task, timeout)

    # Record success
    new_state = handle_success(state)
    {:reply, {:ok, result}, new_state}
  rescue
    e ->
      new_state = handle_failure(state, e)
      {:reply, {:error, e}, new_state}
  catch
    :exit, {:timeout, _} ->
      new_state = handle_failure(state, :timeout)
      {:reply, {:error, :timeout}, new_state}

    kind, reason ->
      new_state = handle_failure(state, {kind, reason})
      {:reply, {:error, {kind, reason}}, new_state}
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
        DateTime.diff(DateTime.utc_now(), last_failure, :millisecond) >= state.recovery_timeout
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
