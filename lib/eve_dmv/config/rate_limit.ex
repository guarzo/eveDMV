defmodule EveDmv.Config.RateLimit do
  @moduledoc """
  Rate limiting configuration management.

  Centralizes rate limiting parameters for API protection and external service
  compliance across the application.
  """

  alias EveDmv.Config

  # Default rate limiting settings
  @default_max_tokens 10
  @default_refill_rate 1
  @default_refill_interval 1000
  @default_queue_timeout 5000

  # Auth rate limiting defaults
  @default_auth_max_attempts 5
  @default_auth_window_minutes 15
  @default_auth_block_duration_minutes 30

  # API-specific defaults
  @default_janice_max_tokens 5
  @default_janice_refill_rate 5

  @doc """
  Get default maximum tokens for rate limiter.

  Environment: EVE_DMV_RATE_LIMIT_MAX_TOKENS (default: 10)
  """
  @spec max_tokens() :: pos_integer()
  def max_tokens do
    Config.get(:eve_dmv, :rate_limit_max_tokens, @default_max_tokens)
  end

  @doc """
  Get default token refill rate (tokens per second).

  Environment: EVE_DMV_RATE_LIMIT_REFILL_RATE (default: 1)
  """
  @spec refill_rate() :: pos_integer()
  def refill_rate do
    Config.get(:eve_dmv, :rate_limit_refill_rate, @default_refill_rate)
  end

  @doc """
  Get refill interval in milliseconds.

  Environment: EVE_DMV_RATE_LIMIT_REFILL_INTERVAL_MS (default: 1000)
  """
  @spec refill_interval() :: pos_integer()
  def refill_interval do
    Config.get(:eve_dmv, :rate_limit_refill_interval_ms, @default_refill_interval)
  end

  @doc """
  Get queue timeout in milliseconds.

  Environment: EVE_DMV_RATE_LIMIT_QUEUE_TIMEOUT_MS (default: 5000)
  """
  @spec queue_timeout() :: pos_integer()
  def queue_timeout do
    Config.get(:eve_dmv, :rate_limit_queue_timeout_ms, @default_queue_timeout)
  end

  @doc """
  Get Janice API rate limiting configuration.

  Environment: 
  - EVE_DMV_JANICE_RATE_LIMIT_MAX_TOKENS (default: 5)
  - EVE_DMV_JANICE_RATE_LIMIT_REFILL_RATE (default: 5)
  """
  @spec janice_rate_limit() :: keyword()
  def janice_rate_limit do
    [
      max_tokens: Config.get(:eve_dmv, :janice_rate_limit_max_tokens, @default_janice_max_tokens),
      refill_rate:
        Config.get(:eve_dmv, :janice_rate_limit_refill_rate, @default_janice_refill_rate)
    ]
  end

  @doc """
  Get authentication rate limiting configuration.

  Environment:
  - EVE_DMV_AUTH_RATE_LIMIT_MAX_ATTEMPTS (default: 5)
  - EVE_DMV_AUTH_RATE_LIMIT_WINDOW_MINUTES (default: 15)
  - EVE_DMV_AUTH_RATE_LIMIT_BLOCK_DURATION_MINUTES (default: 30)
  """
  @spec auth_rate_limit() :: keyword()
  def auth_rate_limit do
    [
      max_attempts:
        Config.get(:eve_dmv, :auth_rate_limit_max_attempts, @default_auth_max_attempts),
      window_minutes:
        Config.get(:eve_dmv, :auth_rate_limit_window_minutes, @default_auth_window_minutes),
      block_duration_minutes:
        Config.get(
          :eve_dmv,
          :auth_rate_limit_block_duration_minutes,
          @default_auth_block_duration_minutes
        )
    ]
  end

  @doc """
  Get rate limiting configuration for a specific API client.
  """
  @spec client_rate_limit(atom()) :: keyword()
  def client_rate_limit(:janice), do: janice_rate_limit()
  def client_rate_limit(:mutamarket), do: [max_tokens: max_tokens(), refill_rate: refill_rate()]
  def client_rate_limit(:esi), do: [max_tokens: max_tokens(), refill_rate: refill_rate()]
  def client_rate_limit(_), do: [max_tokens: max_tokens(), refill_rate: refill_rate()]
end
