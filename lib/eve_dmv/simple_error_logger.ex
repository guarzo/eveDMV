defmodule EveDmv.SimpleErrorLogger do
  @moduledoc """
  Simple error logging with reference IDs for user support.

  This provides basic error tracking without complex infrastructure.
  """

  require Logger

  @doc """
  Log an error with a unique reference ID and context.

  Returns the error ID so users can reference it when reporting issues.
  """
  def log_error(error, context \\ %{}) do
    error_id = generate_error_id()

    stacktrace =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Exception.format_stacktrace()

    Logger.error("""
    [ERROR-#{error_id}] #{Exception.message(error)}
    Context: #{inspect(context, pretty: true)}
    Stacktrace:
    #{stacktrace}
    """)

    # Store in simple cache for recent lookup if needed
    cache_error(error_id, error, context)

    error_id
  end

  @doc """
  Log a warning with context (no reference ID needed).
  """
  def log_warning(message, context \\ %{}) when is_binary(message) do
    Logger.warning("#{message} | Context: #{inspect(context)}")
  end

  @doc """
  Wrap any operation with error logging for easier error handling.
  """
  def with_error_logging(context, fun) when is_function(fun, 0) do
    fun.()
  rescue
    error ->
      error_id = log_error(error, context)
      {:error, "An error occurred (ref: #{error_id})"}
  end

  @doc """
  Get error details by ID (for debugging/support).
  """
  def get_error(error_id) do
    case :ets.lookup(:simple_error_cache, error_id) do
      [{^error_id, error_data, timestamp}] ->
        {:ok, Map.put(error_data, :logged_at, timestamp)}

      [] ->
        {:error, :not_found}
    end
  rescue
    ArgumentError ->
      {:error, :cache_not_available}
  end

  defp generate_error_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end

  defp cache_error(error_id, error, context) do
    ensure_cache_table()

    error_data = %{
      message: Exception.message(error),
      type: error.__struct__,
      context: context
    }

    timestamp = System.system_time(:second)

    # Store for 24 hours
    :ets.insert(:simple_error_cache, {error_id, error_data, timestamp})

    # Clean old entries occasionally (simple cleanup)
    # Every 5 minutes
    if rem(timestamp, 300) == 0 do
      cleanup_old_errors()
    end
  end

  defp ensure_cache_table do
    case :ets.whereis(:simple_error_cache) do
      :undefined ->
        :ets.new(:simple_error_cache, [
          :named_table,
          :public,
          :set,
          {:read_concurrency, true}
        ])

      _ ->
        :ok
    end
  rescue
    ArgumentError ->
      # Table might exist due to race condition
      :ok
  end

  defp cleanup_old_errors do
    # 24 hours ago
    cutoff = System.system_time(:second) - 86_400

    :ets.select_delete(:simple_error_cache, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", cutoff}], [true]}
    ])
  rescue
    # Ignore cleanup errors
    _ -> :ok
  end
end
