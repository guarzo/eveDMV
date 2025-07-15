defmodule EveDmv.Performance.QueryMonitor do
  @moduledoc """
  Real-time query performance monitoring with telemetry integration.

  Tracks query execution times, identifies slow queries, and provides
  performance metrics for database operations.
  """

  alias EveDmv.Database.QueryPlanAnalyzer

  require Logger

  @slow_query_threshold_ms 1000
  @very_slow_query_threshold_ms 5000

  def attach_telemetry_handlers do
    # Attach to Ecto query events
    :telemetry.attach_many(
      "query-monitor-ecto",
      [
        [:eve_dmv, :repo, :query]
      ],
      &__MODULE__.handle_event/4,
      nil
    )

    Logger.info("Query performance monitoring enabled")
  end

  def handle_event([:eve_dmv, :repo, :query], measurements, metadata, _config) do
    query_time = System.convert_time_unit(measurements.total_time, :native, :millisecond)

    # Log slow queries
    cond do
      query_time >= @very_slow_query_threshold_ms ->
        log_very_slow_query(query_time, metadata)

      query_time >= @slow_query_threshold_ms ->
        log_slow_query(query_time, metadata)

      true ->
        # Log debug for all queries if debug logging is enabled
        Logger.debug(fn ->
          "Query executed in #{query_time}ms: #{truncate_query(metadata.query)}"
        end)
    end

    # Track metrics
    track_query_metrics(query_time, metadata)
  end

  defp log_slow_query(query_time, metadata) do
    Logger.warning("""
    SLOW QUERY DETECTED (#{query_time}ms):
    Query: #{metadata.query}
    Source: #{metadata.source}
    """)

    # Send to QueryPlanAnalyzer for deeper analysis if very slow
    if query_time > 2000 do
      Task.start(fn ->
        QueryPlanAnalyzer.analyze_query(metadata.query, metadata.params || [])
      end)
    end
  end

  defp log_very_slow_query(query_time, metadata) do
    Logger.error("""
    VERY SLOW QUERY DETECTED (#{query_time}ms):
    Query: #{metadata.query}
    Source: #{metadata.source}
    Params: #{inspect(metadata.params)}

    Action Required: This query needs immediate optimization!
    """)

    # Always analyze very slow queries
    Task.start(fn ->
      result =
        QueryPlanAnalyzer.analyze_query(metadata.query, metadata.params || [])

      if result[:recommendations] do
        Logger.error("""
        Query optimization recommendations:
        #{format_recommendations(result.recommendations)}
        """)
      end
    end)
  end

  defp track_query_metrics(query_time, metadata) do
    # Extract table name from query (simple pattern matching)
    table = extract_table_name(metadata.query)

    # Emit telemetry event for metrics collection
    :telemetry.execute(
      [:eve_dmv, :database, :query],
      %{duration: query_time},
      %{
        table: table,
        query_type: extract_query_type(metadata.query),
        source: metadata.source
      }
    )

    # Update ETS-based metrics cache
    update_metrics_cache(table, query_time)
  end

  defp extract_table_name(query) do
    cond do
      query =~ ~r/FROM\s+"?(\w+)"?/i ->
        [_, table] = Regex.run(~r/FROM\s+"?(\w+)"?/i, query)
        table

      query =~ ~r/INSERT\s+INTO\s+"?(\w+)"?/i ->
        [_, table] = Regex.run(~r/INSERT\s+INTO\s+"?(\w+)"?/i, query)
        table

      query =~ ~r/UPDATE\s+"?(\w+)"?/i ->
        [_, table] = Regex.run(~r/UPDATE\s+"?(\w+)"?/i, query)
        table

      query =~ ~r/DELETE\s+FROM\s+"?(\w+)"?/i ->
        [_, table] = Regex.run(~r/DELETE\s+FROM\s+"?(\w+)"?/i, query)
        table

      true ->
        "unknown"
    end
  end

  defp extract_query_type(query) do
    cond do
      String.starts_with?(query, "SELECT") -> :select
      String.starts_with?(query, "INSERT") -> :insert
      String.starts_with?(query, "UPDATE") -> :update
      String.starts_with?(query, "DELETE") -> :delete
      true -> :other
    end
  end

  defp update_metrics_cache(table, query_time) do
    # Create ETS table if it doesn't exist
    ensure_metrics_table()

    # Update metrics
    key = {table, :performance}

    case :ets.lookup(:query_metrics, key) do
      [{^key, metrics}] ->
        updated_metrics = %{
          metrics
          | count: metrics.count + 1,
            total_time: metrics.total_time + query_time,
            max_time: max(metrics.max_time, query_time),
            min_time: min(metrics.min_time, query_time),
            last_query_at: DateTime.utc_now()
        }

        :ets.insert(:query_metrics, {key, updated_metrics})

      [] ->
        :ets.insert(
          :query_metrics,
          {key,
           %{
             count: 1,
             total_time: query_time,
             max_time: query_time,
             min_time: query_time,
             last_query_at: DateTime.utc_now()
           }}
        )
    end
  end

  defp ensure_metrics_table do
    case :ets.whereis(:query_metrics) do
      :undefined ->
        :ets.new(:query_metrics, [:named_table, :public, :set])

      _ ->
        :ok
    end
  end

  defp truncate_query(query, max_length \\ 200) do
    if String.length(query) > max_length do
      String.slice(query, 0, max_length) <> "..."
    else
      query
    end
  end

  defp format_recommendations(recommendations) do
    recommendations
    |> Enum.map_join("\n", fn rec ->
      "- #{rec}"
    end)
  end

  @doc """
  Get current performance metrics for all tables.
  """
  def get_performance_metrics do
    ensure_metrics_table()

    :query_metrics
    |> :ets.tab2list()
    |> Enum.map(fn {{table, :performance}, metrics} ->
      avg_time = if metrics.count > 0, do: metrics.total_time / metrics.count, else: 0

      %{
        table: table,
        query_count: metrics.count,
        avg_time_ms: Float.round(avg_time, 2),
        max_time_ms: metrics.max_time,
        min_time_ms: metrics.min_time,
        total_time_ms: metrics.total_time,
        last_query_at: metrics.last_query_at
      }
    end)
    |> Enum.sort_by(& &1.avg_time_ms, :desc)
  end

  @doc """
  Get metrics for a specific table.
  """
  def get_table_metrics(table_name) do
    ensure_metrics_table()

    case :ets.lookup(:query_metrics, {table_name, :performance}) do
      [{_, metrics}] ->
        avg_time = if metrics.count > 0, do: metrics.total_time / metrics.count, else: 0

        %{
          table: table_name,
          query_count: metrics.count,
          avg_time_ms: Float.round(avg_time, 2),
          max_time_ms: metrics.max_time,
          min_time_ms: metrics.min_time,
          total_time_ms: metrics.total_time,
          last_query_at: metrics.last_query_at
        }

      [] ->
        nil
    end
  end

  @doc """
  Reset all performance metrics.
  """
  def reset_metrics do
    ensure_metrics_table()
    :ets.delete_all_objects(:query_metrics)
    Logger.info("Query performance metrics reset")
  end

  @doc """
  Get slow query report.
  """
  def get_slow_query_report do
    metrics = get_performance_metrics()

    slow_tables =
      metrics
      |> Enum.filter(&(&1.avg_time_ms > @slow_query_threshold_ms))
      |> Enum.take(10)

    %{
      slow_tables: slow_tables,
      total_tables_monitored: length(metrics),
      slow_table_count: length(slow_tables),
      generated_at: DateTime.utc_now()
    }
  end
end
