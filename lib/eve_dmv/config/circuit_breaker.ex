defmodule EveDmv.Config.CircuitBreaker do
  @moduledoc """
  Circuit breaker configuration management.

  Centralizes circuit breaker thresholds and timeouts for system stability
  and fault tolerance across external service integrations.
  """

  alias EveDmv.Config

  # Default circuit breaker settings
  @default_failure_threshold 5
  @default_recovery_timeout 30_000
  @default_success_threshold 3
  @default_timeout 10_000

  @doc """
  Get failure threshold before opening circuit.

  Environment: EVE_DMV_CIRCUIT_BREAKER_FAILURE_THRESHOLD (default: 5)
  """
  @spec failure_threshold() :: pos_integer()
  def failure_threshold do
    Config.get(:eve_dmv, :circuit_breaker_failure_threshold, @default_failure_threshold)
  end

  @doc """
  Get recovery timeout in milliseconds (how long circuit stays open).

  Environment: EVE_DMV_CIRCUIT_BREAKER_RECOVERY_TIMEOUT_MS (default: 30000)
  """
  @spec recovery_timeout() :: pos_integer()
  def recovery_timeout do
    Config.get(:eve_dmv, :circuit_breaker_recovery_timeout_ms, @default_recovery_timeout)
  end

  @doc """
  Get success threshold for closing circuit (successes needed in half-open state).

  Environment: EVE_DMV_CIRCUIT_BREAKER_SUCCESS_THRESHOLD (default: 3)
  """
  @spec success_threshold() :: pos_integer()
  def success_threshold do
    Config.get(:eve_dmv, :circuit_breaker_success_threshold, @default_success_threshold)
  end

  @doc """
  Get request timeout in milliseconds.

  Environment: EVE_DMV_CIRCUIT_BREAKER_TIMEOUT_MS (default: 10000)
  """
  @spec timeout() :: pos_integer()
  def timeout do
    Config.get(:eve_dmv, :circuit_breaker_timeout_ms, @default_timeout)
  end

  @doc """
  Get complete circuit breaker configuration.
  """
  @spec config() :: keyword()
  def config do
    [
      failure_threshold: failure_threshold(),
      recovery_timeout: recovery_timeout(),
      success_threshold: success_threshold(),
      timeout: timeout()
    ]
  end

  @doc """
  Get circuit breaker configuration for a specific service.
  """
  @spec service_config(atom()) :: keyword()
  def service_config(:esi) do
    base_config = config()

    # ESI-specific overrides if configured
    esi_failure_threshold = Config.get(:eve_dmv, :esi_circuit_breaker_failure_threshold)
    esi_recovery_timeout = Config.get(:eve_dmv, :esi_circuit_breaker_recovery_timeout_ms)

    base_config
    |> Keyword.put_new(:failure_threshold, esi_failure_threshold || failure_threshold())
    |> Keyword.put_new(:recovery_timeout, esi_recovery_timeout || recovery_timeout())
  end

  def service_config(:janice) do
    base_config = config()

    # Janice-specific overrides if configured
    janice_failure_threshold = Config.get(:eve_dmv, :janice_circuit_breaker_failure_threshold)
    janice_recovery_timeout = Config.get(:eve_dmv, :janice_circuit_breaker_recovery_timeout_ms)

    base_config
    |> Keyword.put_new(:failure_threshold, janice_failure_threshold || failure_threshold())
    |> Keyword.put_new(:recovery_timeout, janice_recovery_timeout || recovery_timeout())
  end

  def service_config(:mutamarket) do
    base_config = config()

    # Mutamarket-specific overrides if configured
    mutamarket_failure_threshold =
      Config.get(:eve_dmv, :mutamarket_circuit_breaker_failure_threshold)

    mutamarket_recovery_timeout =
      Config.get(:eve_dmv, :mutamarket_circuit_breaker_recovery_timeout_ms)

    base_config
    |> Keyword.put_new(:failure_threshold, mutamarket_failure_threshold || failure_threshold())
    |> Keyword.put_new(:recovery_timeout, mutamarket_recovery_timeout || recovery_timeout())
  end

  def service_config(_service), do: config()
end
