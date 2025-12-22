defmodule EveDmv.Core.Utils.RetryUtils do
  @moduledoc """
  Shared retry utilities with exponential backoff for HTTP operations.

  Provides a generic `retry_with_backoff/2` function that can be used by any
  client needing retry logic with configurable backoff parameters.

  ## Usage

  The operation function should return:
  - `{:ok, result}` - Success, returns immediately
  - `{:retry, reason}` - Retriable error, will retry with backoff if attempts remain
  - `{:error, reason}` - Non-retriable error, returns immediately without retry

  ## Example

      retry_with_backoff(
        fn ->
          case make_http_request() do
            {:ok, %{status: 200, body: body}} -> {:ok, body}
            {:ok, %{status: status}} when status in 500..599 -> {:retry, {:server_error, status}}
            {:ok, %{status: status}} -> {:error, {:http_error, status}}
            {:error, reason} -> {:retry, reason}
          end
        end,
        max_retries: 3,
        base_delay_ms: 1_000
      )
  """

  require Logger

  @default_max_retries 3
  @default_base_delay_ms 1_000

  @type retry_result :: {:ok, term()} | {:retry, term()} | {:error, term()}
  @type operation :: (-> retry_result())
  @type log_fn :: (reason :: term(),
                   delay_ms :: non_neg_integer(),
                   attempt :: pos_integer(),
                   max_retries :: non_neg_integer() ->
                     :ok)
  @type option ::
          {:max_retries, non_neg_integer()}
          | {:base_delay_ms, non_neg_integer()}
          | {:log_fn, log_fn()}

  @doc """
  Executes an operation with exponential backoff retry logic.

  ## Options

  - `:max_retries` - Maximum number of retry attempts (default: 3)
  - `:base_delay_ms` - Base delay in milliseconds for backoff calculation (default: 1000)
  - `:log_fn` - Custom logging function `fn(reason, delay_ms, attempt, max_retries) -> :ok end`

  The delay between retries follows exponential backoff:
  `base_delay_ms * 2^(attempt - 1)`

  ## Returns

  - `{:ok, result}` on success
  - `{:error, reason}` on non-retriable error or after exhausting retries
  """
  @spec retry_with_backoff(operation(), [option()]) :: {:ok, term()} | {:error, term()}
  def retry_with_backoff(operation, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    log_fn = Keyword.get(opts, :log_fn, &default_log_fn/4)

    do_retry(operation, 1, max_retries, base_delay_ms, log_fn)
  end

  defp do_retry(operation, attempt, max_retries, base_delay_ms, log_fn) do
    case operation.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        # Non-retriable error, return immediately
        {:error, reason}

      {:retry, reason} when attempt <= max_retries ->
        delay = calculate_backoff_delay(base_delay_ms, attempt)
        log_fn.(reason, delay, attempt, max_retries)
        Process.sleep(delay)
        do_retry(operation, attempt + 1, max_retries, base_delay_ms, log_fn)

      {:retry, reason} ->
        # Exhausted retries, convert to error
        {:error, reason}
    end
  end

  defp default_log_fn(reason, delay_ms, attempt, max_retries) do
    Logger.warning(
      "Request failed: #{inspect(reason)}, retrying in #{delay_ms}ms (attempt #{attempt}/#{max_retries})"
    )
  end

  @doc """
  Calculates exponential backoff delay for a given attempt.

  Uses the formula: `base_delay_ms * 2^(attempt - 1)`

  ## Examples

      iex> RetryUtils.calculate_backoff_delay(1000, 1)
      1000

      iex> RetryUtils.calculate_backoff_delay(1000, 2)
      2000

      iex> RetryUtils.calculate_backoff_delay(1000, 3)
      4000
  """
  @spec calculate_backoff_delay(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def calculate_backoff_delay(base_delay_ms, attempt) do
    (base_delay_ms * :math.pow(2, attempt - 1)) |> round()
  end
end
