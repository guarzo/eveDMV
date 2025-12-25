defmodule EveDmv.Telemetry do
  @moduledoc """
  Simple telemetry setup for basic monitoring.

  This focuses on logging slow queries and basic metrics
  without complex telemetry infrastructure.
  """

  require Logger

  def setup do
    # Attach slow query logging
    # Use module-qualified function references to avoid performance penalty
    :telemetry.attach(
      "log-slow-queries",
      [:eve_dmv, :repo, :query],
      &__MODULE__.log_slow_query/4,
      nil
    )

    # Attach request timing
    :telemetry.attach(
      "log-slow-requests",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.log_slow_request/4,
      nil
    )

    Logger.info("✅ Simple telemetry setup complete")
  end

  def log_slow_query(_event_name, measurements, metadata, _config) do
    # Convert to ms
    query_time_ms = measurements.query_time / 1_000_000

    # Log queries slower than 100ms
    if query_time_ms > 100 do
      Logger.warning("""
      Slow query detected (#{round(query_time_ms)}ms):
      #{String.slice(metadata.query || "unknown", 0, 200)}
      Source: #{metadata.source || "unknown"}
      """)

      # Store for analysis if needed
      store_slow_query(query_time_ms, metadata)
    end
  end

  def log_slow_request(_event_name, measurements, metadata, _config) do
    # Convert to ms
    duration_ms = measurements.duration / 1_000_000

    # Log requests slower than 1 second
    if duration_ms > 1000 do
      Logger.warning("""
      Slow request detected (#{round(duration_ms)}ms):
      #{metadata.conn.method} #{metadata.conn.request_path}
      """)
    end
  end

  defp store_slow_query(time_ms, metadata) do
    # Simple storage in ETS for recent queries
    ensure_slow_query_table()

    entry = {
      :os.system_time(:millisecond),
      round(time_ms),
      String.slice(metadata.query || "unknown", 0, 200),
      metadata.source
    }

    :ets.insert(:slow_queries, entry)

    # Keep only last 100 entries
    case :ets.info(:slow_queries, :size) do
      size when size > 100 ->
        cleanup_slow_queries()

      _ ->
        :ok
    end
  end

  @doc """
  Get recent slow queries for debugging.
  """
  def get_recent_slow_queries(limit \\ 20) do
    :ets.tab2list(:slow_queries)
    |> Enum.sort_by(fn {timestamp, _, _, _} -> timestamp end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {timestamp, time_ms, query, source} ->
      %{
        timestamp: DateTime.from_unix!(timestamp, :millisecond),
        duration_ms: time_ms,
        query: query,
        source: source
      }
    end)
  rescue
    _ -> []
  end

  defp ensure_slow_query_table do
    case :ets.whereis(:slow_queries) do
      :undefined ->
        :ets.new(:slow_queries, [
          :named_table,
          :public,
          :bag,
          {:read_concurrency, true}
        ])

      _ ->
        :ok
    end
  rescue
    ArgumentError ->
      :ok
  end

  defp cleanup_slow_queries do
    # Keep only the 50 most recent entries
    queries =
      :ets.tab2list(:slow_queries)
      |> Enum.sort_by(fn {timestamp, _, _, _} -> timestamp end, :desc)

    :ets.delete_all_objects(:slow_queries)

    queries
    |> Enum.take(50)
    |> Enum.each(&:ets.insert(:slow_queries, &1))
  rescue
    _ -> :ok
  end
end
