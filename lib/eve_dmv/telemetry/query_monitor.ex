defmodule EveDmv.Telemetry.QueryMonitor do
  @moduledoc """
  Monitors database query performance and tracks slow queries.
  """

  use GenServer
  require Logger

  # milliseconds
  @slow_query_threshold 1000
  @max_stored_queries 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Subscribe to Ecto telemetry events
    :telemetry.attach(
      "eve-dmv-query-monitor",
      [:eve_dmv, :repo, :query],
      &__MODULE__.handle_event/4,
      nil
    )

    {:ok, %{slow_queries: []}}
  end

  def track_query(query_time, query_type, table_name) do
    :telemetry.execute(
      [:eve_dmv, :repo, :query],
      %{duration: query_time},
      %{type: query_type, table: table_name}
    )

    if query_time > @slow_query_threshold do
      Logger.warning("Slow query detected: #{query_type} on #{table_name} took #{query_time}ms")
      GenServer.cast(__MODULE__, {:record_slow_query, query_type, table_name, query_time})
    end
  end

  def handle_event([:eve_dmv, :repo, :query], measurements, metadata, _config) do
    query_time = measurements.duration

    if query_time > @slow_query_threshold do
      query_info = %{
        query: metadata.query || "Unknown",
        duration_ms: query_time,
        source: metadata.source || "Unknown",
        timestamp: DateTime.utc_now()
      }

      GenServer.cast(__MODULE__, {:record_slow_query_details, query_info})
    end
  end

  def get_slow_queries do
    GenServer.call(__MODULE__, :get_slow_queries)
  end

  def clear_slow_queries do
    GenServer.call(__MODULE__, :clear_slow_queries)
  end

  def get_query_stats do
    GenServer.call(__MODULE__, :get_query_stats)
  end

  # GenServer callbacks

  def handle_cast({:record_slow_query, query_type, table_name, query_time}, state) do
    slow_query = %{
      type: query_type,
      table: table_name,
      duration_ms: query_time,
      timestamp: DateTime.utc_now()
    }

    updated_queries = [slow_query | state.slow_queries] |> Enum.take(@max_stored_queries)
    {:noreply, %{state | slow_queries: updated_queries}}
  end

  def handle_cast({:record_slow_query_details, query_info}, state) do
    updated_queries = [query_info | state.slow_queries] |> Enum.take(@max_stored_queries)
    {:noreply, %{state | slow_queries: updated_queries}}
  end

  def handle_call(:get_slow_queries, _from, state) do
    {:reply, state.slow_queries, state}
  end

  def handle_call(:clear_slow_queries, _from, state) do
    {:reply, :ok, %{state | slow_queries: []}}
  end

  def handle_call(:get_query_stats, _from, state) do
    stats = %{
      total_slow_queries: length(state.slow_queries),
      slowest_query: state.slow_queries |> Enum.max_by(& &1.duration_ms, fn -> nil end),
      average_slow_query_time: calculate_average_time(state.slow_queries)
    }

    {:reply, stats, state}
  end

  defp calculate_average_time([]), do: 0

  defp calculate_average_time(queries) do
    total = Enum.sum(Enum.map(queries, & &1.duration_ms))
    Float.round(total / length(queries), 2)
  end
end
