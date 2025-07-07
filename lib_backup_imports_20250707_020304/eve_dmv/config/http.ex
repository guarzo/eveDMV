defmodule EveDmv.Config.Http do
  alias EveDmv.Config
  @moduledoc """
  HTTP client configuration management.

  Centralizes HTTP timeout values, retry logic, and connection settings
  across all external API clients.
  """


  # Default HTTP configuration
  @default_timeout 30_000
  @default_connect_timeout 30_000
  @default_retry_attempts 3
  @default_retry_delay 1_000
  @default_max_retry_delay 30_000

  @doc """
  Get HTTP request timeout in milliseconds.

  Environment: EVE_DMV_HTTP_TIMEOUT_MS (default: 30000)
  """
  @spec timeout() :: pos_integer()
  def timeout do
    Config.get(:eve_dmv, :http_timeout_ms, @default_timeout)
  end

  @doc """
  Get HTTP connection timeout in milliseconds.

  Environment: EVE_DMV_HTTP_CONNECT_TIMEOUT_MS (default: 30000)
  """
  @spec connect_timeout() :: pos_integer()
  def connect_timeout do
    Config.get(:eve_dmv, :http_connect_timeout_ms, @default_connect_timeout)
  end

  @doc """
  Get number of retry attempts for failed requests.

  Environment: EVE_DMV_HTTP_RETRY_ATTEMPTS (default: 3)
  """
  @spec retry_attempts() :: pos_integer()
  def retry_attempts do
    Config.get(:eve_dmv, :http_retry_attempts, @default_retry_attempts)
  end

  @doc """
  Get initial retry delay in milliseconds.

  Environment: EVE_DMV_HTTP_RETRY_DELAY_MS (default: 1000)
  """
  @spec retry_delay() :: pos_integer()
  def retry_delay do
    Config.get(:eve_dmv, :http_retry_delay_ms, @default_retry_delay)
  end

  @doc """
  Get maximum retry delay in milliseconds.

  Environment: EVE_DMV_HTTP_MAX_RETRY_DELAY_MS (default: 30000)
  """
  @spec max_retry_delay() :: pos_integer()
  def max_retry_delay do
    Config.get(:eve_dmv, :http_max_retry_delay_ms, @default_max_retry_delay)
  end

  @doc """
  Get Janice API specific timeout.

  Environment: EVE_DMV_JANICE_TIMEOUT_MS (default: inherits from http_timeout)
  """
  @spec janice_timeout() :: pos_integer()
  def janice_timeout do
    Config.get(:eve_dmv, :janice_timeout_ms, timeout())
  end

  @doc """
  Get Mutamarket API specific timeout.

  Environment: EVE_DMV_MUTAMARKET_TIMEOUT_MS (default: inherits from http_timeout)
  """
  @spec mutamarket_timeout() :: pos_integer()
  def mutamarket_timeout do
    Config.get(:eve_dmv, :mutamarket_timeout_ms, timeout())
  end

  @doc """
  Get ESI API specific timeout.

  Environment: EVE_DMV_ESI_TIMEOUT_MS (default: inherits from http_timeout)
  """
  @spec esi_timeout() :: pos_integer()
  def esi_timeout do
    Config.get(:eve_dmv, :esi_timeout_ms, timeout())
  end

  @doc """
  Get SSE connection timeout.

  Environment: EVE_DMV_SSE_TIMEOUT_MS (default: inherits from http_timeout)
  """
  @spec sse_timeout() :: pos_integer()
  def sse_timeout do
    Config.get(:eve_dmv, :sse_timeout_ms, timeout())
  end

  @doc """
  Get HTTPoison configuration options.
  """
  @spec httpoison_options() :: keyword()
  def httpoison_options do
    [
      timeout: timeout(),
      recv_timeout: timeout(),
      connect_timeout: connect_timeout(),
      pool_timeout: 5_000,
      max_redirect: 3
    ]
  end

  @doc """
  Get Finch pool configuration.
  """
  @spec finch_pool_config() :: keyword()
  def finch_pool_config do
    [
      size: Config.get(:eve_dmv, :http_pool_size, 10),
      conn_opts: [
        timeout: connect_timeout()
      ]
    ]
  end
end
