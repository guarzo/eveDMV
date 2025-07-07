defmodule EveDmv.Telemetry.QueryMonitor do
  @moduledoc """
  Monitors database query performance and tracks slow queries.
  Enhanced with comprehensive query analysis and pattern detection.
  """

  use GenServer
  require Logger

  # milliseconds
  @slow_query_threshold 1000
  @max_stored_queries 100
  @query_pattern_window :timer.minutes(10)
  @n_plus_one_threshold 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Subscribe to Ecto telemetry events
    :telemetry.attach(
      "eve-dmv-query-monitor",
      [:eve_dmv, :repo, :query],
      &__MODULE__.handle_event/4,
      nil
    )

    {:ok,
     %{
       slow_queries: [],
       query_patterns: %{},
       execution_stats: %{},
       n_plus_one_alerts: []
     }}
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
    # Handle different measurement formats - prefer total_time, fallback to query_time, then duration
    query_time =
      measurements[:total_time] || measurements[:query_time] || measurements[:duration] || 0

    query_sql = metadata.query || "Unknown"
    source = metadata.source || "Unknown"

    # Normalize query for pattern detection
    normalized_query = normalize_query(query_sql)

    # Track all queries for pattern analysis
    GenServer.cast(__MODULE__, {:track_query_execution, normalized_query, query_time, source})

    if query_time > @slow_query_threshold do
      query_info = %{
        query: query_sql,
        normalized_query: normalized_query,
        duration_ms: query_time,
        source: source,
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

  @doc """
  Get comprehensive query performance analysis.
  """
  def get_performance_analysis do
    GenServer.call(__MODULE__, :get_performance_analysis)
  end

  @doc """
  Get N+1 query detection alerts.
  """
  def get_n_plus_one_alerts do
    GenServer.call(__MODULE__, :get_n_plus_one_alerts)
  end

  @doc """
  Get query execution patterns for optimization.
  """
  def get_query_patterns do
    GenServer.call(__MODULE__, :get_query_patterns)
  end

  @doc """
  Get most frequent queries with their performance stats.
  """
  def get_frequent_queries(limit \\ 20) do
    GenServer.call(__MODULE__, {:get_frequent_queries, limit})
  end

  @doc """
  Clear all tracking data (useful for testing).
  """
  def reset_tracking do
    GenServer.call(__MODULE__, :reset_tracking)
  end

  # GenServer callbacks

  def handle_cast({:record_slow_query, query_type, table_name, query_time}, state) do
    slow_query = %{
      type: query_type,
      table: table_name,
      duration_ms: query_time,
      timestamp: DateTime.utc_now()
    }

    updated_queries = Enum.take([slow_query | state.slow_queries], @max_stored_queries)
    {:noreply, %{state | slow_queries: updated_queries}}
  end

  def handle_cast({:record_slow_query_details, query_info}, state) do
    updated_queries = Enum.take([query_info | state.slow_queries], @max_stored_queries)
    {:noreply, %{state | slow_queries: updated_queries}}
  end

  def handle_cast({:track_query_execution, normalized_query, duration, source}, state) do
    # Update execution stats
    current_time = DateTime.utc_now()

    # Track query patterns with timestamps for N+1 detection
    pattern_key = {normalized_query, source}
    pattern_executions = Map.get(state.query_patterns, pattern_key, [])

    # Keep only recent executions within the window
    recent_executions =
      [%{timestamp: current_time, duration: duration} | pattern_executions]
      |> Enum.filter(fn exec ->
        DateTime.diff(current_time, exec.timestamp, :millisecond) <= @query_pattern_window
      end)
      # Limit per pattern
      |> Enum.take(50)

    updated_patterns = Map.put(state.query_patterns, pattern_key, recent_executions)

    # Check for N+1 patterns
    n_plus_one_alerts =
      check_n_plus_one_pattern(pattern_key, recent_executions, state.n_plus_one_alerts)

    # Update execution stats
    stats_key = normalized_query

    current_stats =
      Map.get(state.execution_stats, stats_key, %{
        count: 0,
        total_duration: 0,
        min_duration: duration,
        max_duration: duration,
        last_execution: current_time
      })

    updated_stats = %{
      count: current_stats.count + 1,
      total_duration: current_stats.total_duration + duration,
      min_duration: min(current_stats.min_duration, duration),
      max_duration: max(current_stats.max_duration, duration),
      last_execution: current_time,
      avg_duration: (current_stats.total_duration + duration) / (current_stats.count + 1)
    }

    updated_execution_stats = Map.put(state.execution_stats, stats_key, updated_stats)

    {:noreply,
     %{
       state
       | query_patterns: updated_patterns,
         execution_stats: updated_execution_stats,
         n_plus_one_alerts: n_plus_one_alerts
     }}
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
      slowest_query: Enum.max_by(state.slow_queries, & &1.duration_ms, fn -> nil end),
      average_slow_query_time: calculate_average_time(state.slow_queries)
    }

    {:reply, stats, state}
  end

  def handle_call(:get_performance_analysis, _from, state) do
    analysis = %{
      query_count: map_size(state.execution_stats),
      total_executions:
        state.execution_stats |> Map.values() |> Stream.map(& &1.count) |> Enum.sum(),
      slowest_patterns: get_slowest_patterns(state.execution_stats),
      most_frequent: get_most_frequent_patterns(state.execution_stats),
      n_plus_one_count: length(state.n_plus_one_alerts),
      performance_issues: identify_performance_issues(state)
    }

    {:reply, analysis, state}
  end

  def handle_call(:get_n_plus_one_alerts, _from, state) do
    {:reply, state.n_plus_one_alerts, state}
  end

  def handle_call(:get_query_patterns, _from, state) do
    patterns =
      Enum.map(state.query_patterns, fn {{query, source}, executions} ->
        %{
          query: query,
          source: source,
          recent_executions: length(executions),
          avg_duration: calculate_pattern_avg_duration(executions),
          last_execution: Enum.max(Enum.map(executions, & &1.timestamp), fn -> nil end)
        }
      end)

    {:reply, patterns, state}
  end

  def handle_call({:get_frequent_queries, limit}, _from, state) do
    frequent_queries =
      state.execution_stats
      |> Enum.sort_by(fn {_, stats} -> stats.count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {query, stats} ->
        Map.put(stats, :query, query)
      end)

    {:reply, frequent_queries, state}
  end

  def handle_call(:reset_tracking, _from, _state) do
    {:reply, :ok,
     %{
       slow_queries: [],
       query_patterns: %{},
       execution_stats: %{},
       n_plus_one_alerts: []
     }}
  end

  defp calculate_average_time([]), do: 0

  defp calculate_average_time(queries) do
    total = Enum.sum(Enum.map(queries, & &1.duration_ms))
    Float.round(total / length(queries), 2)
  end

  # Helper functions for enhanced query analysis

  defp normalize_query(query) when is_binary(query) do
    query
    # Remove specific values and replace with placeholders
    |> String.replace(~r/\$\d+|\?\d*/, "?")
    |> String.replace(~r/IN\s*\([^)]+\)/i, "IN (?)")
    |> String.replace(~r/VALUES\s*\([^)]+\)/i, "VALUES (?)")
    |> String.replace(~r/=\s*\d+/, "= ?")
    |> String.replace(~r/=\s*'[^']*'/, "= ?")
    |> String.replace(~r/LIMIT\s+\d+/i, "LIMIT ?")
    |> String.replace(~r/OFFSET\s+\d+/i, "OFFSET ?")
    # Normalize whitespace
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_query(_), do: "Unknown"

  defp check_n_plus_one_pattern({normalized_query, source}, recent_executions, current_alerts) do
    execution_count = length(recent_executions)

    # Detect N+1 pattern: same query executed many times in a short window
    if execution_count >= @n_plus_one_threshold do
      # Check if we already have a recent alert for this pattern
      alert_key = {normalized_query, source}

      recent_alert =
        Enum.find(current_alerts, fn alert ->
          alert.pattern == alert_key and
            DateTime.diff(DateTime.utc_now(), alert.timestamp, :minute) < 5
        end)

      if is_nil(recent_alert) do
        alert = %{
          pattern: alert_key,
          query: normalized_query,
          source: source,
          execution_count: execution_count,
          window_minutes: @query_pattern_window / 60_000,
          timestamp: DateTime.utc_now(),
          avg_duration: calculate_pattern_avg_duration(recent_executions)
        }

        Logger.warning(
          "N+1 query pattern detected: #{normalized_query} executed #{execution_count} times from #{source}"
        )

        # Keep last 20 alerts
        Enum.take([alert | current_alerts], 20)
      else
        current_alerts
      end
    else
      current_alerts
    end
  end

  defp calculate_pattern_avg_duration([]), do: 0.0

  defp calculate_pattern_avg_duration(executions) do
    total = Enum.sum(Enum.map(executions, & &1.duration))
    Float.round(total / length(executions), 2)
  end

  defp get_slowest_patterns(execution_stats) do
    Enum.sort_by(execution_stats, fn {_, stats} -> stats.avg_duration end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {query, stats} ->
      Map.put(stats, :query, query)
    end)
  end

  defp get_most_frequent_patterns(execution_stats) do
    Enum.sort_by(execution_stats, fn {_, stats} -> stats.count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {query, stats} ->
      Map.put(stats, :query, query)
    end)
  end

  defp identify_performance_issues(state) do
    issues = []

    # Check for queries with high average duration
    slow_avg_queries =
      state.execution_stats
      |> Enum.filter(fn {_, stats} -> stats.avg_duration > @slow_query_threshold / 2 end)
      |> then(&length/1)

    issues_with_slow =
      if slow_avg_queries > 0,
        do: ["#{slow_avg_queries} queries with high average duration" | issues],
        else: issues

    # Check for highly frequent queries
    frequent_queries =
      state.execution_stats
      |> Enum.filter(fn {_, stats} -> stats.count > 100 end)
      |> then(&length/1)

    issues_with_frequent =
      if frequent_queries > 0,
        do: ["#{frequent_queries} highly frequent queries" | issues_with_slow],
        else: issues_with_slow

    # Check for N+1 alerts
    issues_with_n_plus_one =
      if length(state.n_plus_one_alerts) > 0,
        do: ["#{length(state.n_plus_one_alerts)} N+1 query alerts" | issues_with_frequent],
        else: issues_with_frequent

    # Check for queries with high duration variance
    high_variance_queries =
      state.execution_stats
      |> Enum.filter(fn {_, stats} ->
        stats.max_duration > stats.min_duration * 10 and stats.count > 5
      end)
      |> then(&length/1)

    final_issues =
      if high_variance_queries > 0,
        do: [
          "#{high_variance_queries} queries with high duration variance" | issues_with_n_plus_one
        ],
        else: issues_with_n_plus_one

    final_issues
  end
end
