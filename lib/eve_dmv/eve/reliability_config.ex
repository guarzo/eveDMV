defmodule EveDmv.Eve.ReliabilityConfig do
  @moduledoc """
  Configuration management for ESI client reliability features.

  Provides configurable timeouts, retry policies, circuit breaker settings,
  and fallback strategies with environment-specific overrides.
  """

  # Default timeout configurations (in milliseconds)
  @default_timeouts %{
    # Reduced from 30s for better UX
    default: 10_000,
    # Character lookups should be fast
    character: 5_000,
    # Corp data can be slightly slower
    corporation: 8_000,
    # Alliance data similar to corp
    alliance: 8_000,
    # Market data can take longer
    market: 15_000,
    # Universe data (systems, types, etc.)
    universe: 12_000,
    # Killmail data can be large
    killmail: 20_000,
    # Search operations
    search: 10_000
  }

  # Default retry configurations
  @default_retry %{
    max_attempts: 3,
    # 1 second
    base_delay: 1_000,
    # 30 seconds
    max_delay: 30_000,
    backoff_multiplier: 2.0,
    jitter: true,
    retry_http_statuses: [420, 429, 500, 502, 503, 504]
  }

  # Default circuit breaker configurations
  @default_circuit_breaker %{
    # Failures before opening
    failure_threshold: 5,
    # 30 seconds before testing recovery
    recovery_timeout: 30_000,
    # Successes needed to close circuit
    success_threshold: 3,
    enabled: true
  }

  # Default fallback strategies
  @default_fallback %{
    use_stale_cache: true,
    # 1 hour
    stale_cache_ttl: 3_600_000,
    use_placeholder_data: false,
    fail_fast_on_circuit_open: true
  }

  @doc """
  Get timeout configuration for a specific operation type.
  """
  @spec get_timeout(atom()) :: integer()
  def get_timeout(operation_type) do
    configured_timeouts = get_config(:timeouts, @default_timeouts)
    Map.get(configured_timeouts, operation_type, configured_timeouts.default)
  end

  @doc """
  Get retry configuration.
  """
  @spec get_retry_config() :: map()
  def get_retry_config do
    get_config(:retry, @default_retry)
  end

  @doc """
  Get circuit breaker configuration for a service.
  """
  @spec get_circuit_breaker_config(atom()) :: map()
  def get_circuit_breaker_config(service_name \\ :default) do
    base_config = get_config(:circuit_breaker, @default_circuit_breaker)

    # Allow per-service overrides
    service_overrides = get_config({:circuit_breaker, service_name}, %{})
    Map.merge(base_config, service_overrides)
  end

  @doc """
  Get fallback strategy configuration.
  """
  @spec get_fallback_config() :: map()
  def get_fallback_config do
    get_config(:fallback, @default_fallback)
  end

  @doc """
  Check if circuit breaker is enabled for a service.
  """
  @spec circuit_breaker_enabled?(atom()) :: boolean()
  def circuit_breaker_enabled?(service_name \\ :default) do
    config = get_circuit_breaker_config(service_name)
    Map.get(config, :enabled, true)
  end

  @doc """
  Calculate retry delay with jitter.
  """
  @spec calculate_retry_delay(integer(), map() | nil) :: integer()
  def calculate_retry_delay(attempt, retry_config \\ nil) do
    config = retry_config || get_retry_config()

    # Exponential backoff: base_delay * multiplier^(attempt-1)
    # Use integer multiplication instead of :math.pow for better performance
    delay =
      if config.backoff_multiplier == 2.0 do
        # Optimize common case of doubling
        config.base_delay * integer_pow(2, attempt - 1)
      else
        config.base_delay * :math.pow(config.backoff_multiplier, attempt - 1)
      end

    delay = min(delay, config.max_delay)

    # Add jitter if enabled
    if config.jitter do
      # 10% jitter
      jitter_amount = delay * 0.1
      jitter = :rand.uniform() * jitter_amount * 2 - jitter_amount
      max(0, delay + jitter) |> round()
    else
      round(delay)
    end
  end

  @doc """
  Check if HTTP status should be retried.
  """
  @spec should_retry_status?(integer()) :: boolean()
  def should_retry_status?(status) do
    retry_config = get_retry_config()
    status in retry_config.retry_http_statuses
  end

  @doc """
  Get rate limiting configuration.
  """
  @spec get_rate_limit_config() :: map()
  def get_rate_limit_config do
    get_config(:rate_limiting, %{
      # ESI default
      requests_per_second: 150,
      # ESI burst capacity
      burst_allowance: 400,
      # Use X-ESI-Error-Limit headers
      respect_headers: true,
      # Adjust based on responses
      adaptive: true
    })
  end

  @doc """
  Get monitoring configuration.
  """
  @spec get_monitoring_config() :: map()
  def get_monitoring_config do
    get_config(:monitoring, %{
      enabled: true,
      log_level: :info,
      metrics_enabled: true,
      # 5 minutes
      failure_tracking_window: 300_000,
      # Alert if >10% errors
      alert_threshold_percentage: 10.0
    })
  end

  @doc """
  Get configuration for ESI service endpoints.
  """
  @spec get_service_config(atom()) :: map()
  def get_service_config(service) do
    base_config = %{
      timeout: get_timeout(service),
      retry: get_retry_config(),
      circuit_breaker: get_circuit_breaker_config(service),
      fallback: get_fallback_config()
    }

    # Service-specific overrides
    service_overrides = get_config({:services, service}, %{})
    deep_merge(base_config, service_overrides)
  end

  @doc """
  Update configuration at runtime (for testing or dynamic adjustment).
  """
  @spec update_config(atom(), any()) :: :ok
  def update_config(key, value) do
    current_config = Application.get_env(:eve_dmv, :esi_reliability, %{})
    new_config = Map.put(current_config, key, value)
    Application.put_env(:eve_dmv, :esi_reliability, new_config)
  end

  @doc """
  Validate configuration on startup.
  """
  @spec validate_config() :: :ok | {:error, String.t()}
  def validate_config do
    with :ok <- validate_timeouts(),
         :ok <- validate_retry_config(),
         :ok <- validate_circuit_breaker_config() do
      :ok
    else
      {:error, reason} -> {:error, "ESI reliability config validation failed: #{reason}"}
    end
  end

  # Private functions

  defp get_config(key, default) do
    :eve_dmv
    |> Application.get_env(:esi_reliability, %{})
    |> get_nested_config(key, default)
  end

  defp get_nested_config(config, {key1, key2}, default) do
    config
    |> Map.get(key1, %{})
    |> Map.get(key2, default)
  end

  defp get_nested_config(config, key, default) when is_atom(key) do
    Map.get(config, key, default)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _key, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end

  defp deep_merge(_left, right), do: right

  defp validate_timeouts do
    timeouts = get_config(:timeouts, @default_timeouts)

    case Enum.find(timeouts, &validate_timeout_entry/1) do
      nil -> :ok
      {key, error_msg} -> {:error, "Timeout #{key} #{error_msg}"}
    end
  end

  defp validate_timeout_entry({key, value}) do
    cond do
      not is_integer(value) ->
        {key, "must be an integer, got: #{inspect(value)}"}

      value <= 0 ->
        {key, "must be positive, got: #{value}"}

      # 5 minutes max
      value > 300_000 ->
        {key, "too large (max 5 minutes), got: #{value}"}

      true ->
        nil
    end
  end

  defp validate_retry_config do
    retry = get_retry_config()

    cond do
      not is_integer(retry.max_attempts) or retry.max_attempts < 1 ->
        {:error, "max_attempts must be positive integer"}

      not is_integer(retry.base_delay) or retry.base_delay < 100 ->
        {:error, "base_delay must be >= 100ms"}

      not is_number(retry.backoff_multiplier) or retry.backoff_multiplier < 1.0 ->
        {:error, "backoff_multiplier must be >= 1.0"}

      true ->
        :ok
    end
  end

  defp validate_circuit_breaker_config do
    cb = get_circuit_breaker_config()

    cond do
      not is_integer(cb.failure_threshold) or cb.failure_threshold < 1 ->
        {:error, "failure_threshold must be positive integer"}

      not is_integer(cb.recovery_timeout) or cb.recovery_timeout < 1000 ->
        {:error, "recovery_timeout must be >= 1 second"}

      not is_integer(cb.success_threshold) or cb.success_threshold < 1 ->
        {:error, "success_threshold must be positive integer"}

      true ->
        :ok
    end
  end

  # Optimized integer power calculation
  defp integer_pow(_base, 0), do: 1
  defp integer_pow(base, 1), do: base

  defp integer_pow(base, exponent) when exponent > 0 do
    base * integer_pow(base, exponent - 1)
  end
end
