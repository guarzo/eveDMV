defmodule EveDmv.Telemetry.RequestMonitor do
  @moduledoc """
  Monitors ESI request performance and reliability.

  This module tracks request metrics to help identify performance
  bottlenecks and reliability issues with ESI API calls.
  """

  @doc """
  Track an ESI request with duration and status.

  ## Parameters
  - service: The ESI service name (e.g., :character, :corporation, :market)
  - duration: Request duration in microseconds
  - status: Request status (:success, :failure, :timeout, :circuit_open)

  ## Examples
      track_request(:character, 1500, :success)
      track_request(:market, 30000, :timeout)
  """
  @spec track_request(atom(), integer(), atom()) :: :ok
  def track_request(service, duration, status) do
    :telemetry.execute(
      [:eve_dmv, :esi, :request],
      %{duration: duration},
      %{service: service, status: status}
    )
  end

  @doc """
  Track a bulk request operation.

  ## Parameters
  - service: The ESI service name
  - count: Number of items in the bulk request
  - duration: Total duration in microseconds
  - status: Request status
  """
  @spec track_bulk_request(atom(), integer(), integer(), atom()) :: :ok
  def track_bulk_request(service, count, duration, status) do
    :telemetry.execute(
      [:eve_dmv, :esi, :bulk_request],
      %{duration: duration, count: count, avg_duration: duration / max(count, 1)},
      %{service: service, status: status}
    )
  end

  @doc """
  Track cache hit/miss statistics.

  ## Parameters
  - service: The ESI service name
  - cache_result: :hit or :miss
  """
  @spec track_cache(atom(), atom()) :: :ok
  def track_cache(service, cache_result) do
    :telemetry.execute(
      [:eve_dmv, :esi, :cache],
      %{count: 1},
      %{service: service, result: cache_result}
    )
  end

  @doc """
  Track circuit breaker state changes.

  ## Parameters
  - service: The ESI service name
  - old_state: Previous circuit state
  - new_state: New circuit state
  """
  @spec track_circuit_breaker_change(atom(), atom(), atom()) :: :ok
  def track_circuit_breaker_change(service, old_state, new_state) do
    :telemetry.execute(
      [:eve_dmv, :esi, :circuit_breaker],
      %{count: 1},
      %{service: service, from_state: old_state, to_state: new_state}
    )
  end

  @doc """
  Track rate limiting events.

  ## Parameters
  - service: The ESI service name
  - remaining: Remaining requests in current window
  - reset_in: Seconds until rate limit reset
  """
  @spec track_rate_limit(atom(), integer(), integer()) :: :ok
  def track_rate_limit(service, remaining, reset_in) do
    :telemetry.execute(
      [:eve_dmv, :esi, :rate_limit],
      %{remaining: remaining, reset_in: reset_in},
      %{service: service}
    )
  end

  @doc """
  Track fallback strategy usage.

  ## Parameters
  - service: The ESI service name
  - strategy: The fallback strategy used (:stale_cache, :placeholder, :none)
  """
  @spec track_fallback(atom(), atom()) :: :ok
  def track_fallback(service, strategy) do
    :telemetry.execute(
      [:eve_dmv, :esi, :fallback],
      %{count: 1},
      %{service: service, strategy: strategy}
    )
  end

  @doc """
  Set up telemetry event handlers for monitoring.

  This should be called during application startup to enable
  metric collection and logging.
  """
  @spec setup_handlers() :: :ok
  def setup_handlers do
    # Log slow requests
    :telemetry.attach(
      "esi-slow-requests",
      [:eve_dmv, :esi, :request],
      &handle_slow_request/4,
      nil
    )

    # Log circuit breaker changes
    :telemetry.attach(
      "esi-circuit-breaker",
      [:eve_dmv, :esi, :circuit_breaker],
      &handle_circuit_breaker_change/4,
      nil
    )

    # Log rate limit warnings
    :telemetry.attach(
      "esi-rate-limit",
      [:eve_dmv, :esi, :rate_limit],
      &handle_rate_limit/4,
      nil
    )

    :ok
  end

  # Private handler functions

  defp handle_slow_request(_event_name, %{duration: duration}, metadata, _config) do
    # Log requests slower than 5 seconds
    if duration > 5_000_000 do
      require Logger

      Logger.warning("Slow ESI request detected",
        service: metadata.service,
        status: metadata.status,
        duration_ms: duration / 1000
      )
    end
  end

  defp handle_circuit_breaker_change(_event_name, _measurements, metadata, _config) do
    require Logger

    Logger.warning("Circuit breaker state changed",
      service: metadata.service,
      from: metadata.from_state,
      to: metadata.to_state
    )
  end

  defp handle_rate_limit(_event_name, measurements, metadata, _config) do
    require Logger

    if measurements.remaining < 10 do
      Logger.warning("ESI rate limit warning",
        service: metadata.service,
        remaining: measurements.remaining,
        reset_in: measurements.reset_in
      )
    end
  end
end
