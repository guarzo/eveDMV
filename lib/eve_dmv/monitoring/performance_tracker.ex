defmodule EveDmv.Monitoring.PerformanceTracker do
  @moduledoc """
  Tracks performance metrics for database queries and API calls.
  Provides real-time visibility into performance bottlenecks.
  """

  use GenServer
  require Logger

  @table_name :performance_metrics
  @cleanup_interval :timer.minutes(5)
  @metric_ttl :timer.hours(24)

  defstruct [
    :metrics_table,
    :start_time
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track a database query execution.
  """
  def track_query(query_name, duration_ms, opts \\ []) do
    GenServer.cast(__MODULE__, {:track_query, query_name, duration_ms, opts})
  end

  @doc """
  Track an API call execution.
  """
  def track_api_call(api_name, endpoint, duration_ms, opts \\ []) do
    GenServer.cast(__MODULE__, {:track_api_call, api_name, endpoint, duration_ms, opts})
  end

  @doc """
  Track a LiveView mount/render time.
  """
  def track_liveview(view_module, action, duration_ms, opts \\ []) do
    GenServer.cast(__MODULE__, {:track_liveview, view_module, action, duration_ms, opts})
  end

  @doc """
  Get performance metrics summary.
  """
  def get_metrics_summary(time_range \\ :hour) do
    GenServer.call(__MODULE__, {:get_metrics_summary, time_range})
  end

  @doc """
  Get slow queries above threshold.
  """
  def get_slow_queries(threshold_ms \\ 1000) do
    GenServer.call(__MODULE__, {:get_slow_queries, threshold_ms})
  end

  @doc """
  Get performance bottlenecks.
  """
  def get_bottlenecks do
    GenServer.call(__MODULE__, :get_bottlenecks)
  end

  @doc """
  Time a function execution and track it.
  """
  defmacro time_query(query_name, opts \\ [], do: block) do
    quote do
      start_time = System.monotonic_time(:millisecond)
      result = unquote(block)
      duration = System.monotonic_time(:millisecond) - start_time

      EveDmv.Monitoring.PerformanceTracker.track_query(
        unquote(query_name),
        duration,
        unquote(opts)
      )

      result
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for metrics
    table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Schedule periodic cleanup
    schedule_cleanup()

    state = %__MODULE__{
      metrics_table: table,
      start_time: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:track_query, query_name, duration_ms, opts}, state) do
    record_metric(:query, query_name, duration_ms, opts)
    check_threshold(:query, query_name, duration_ms)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:track_api_call, api_name, endpoint, duration_ms, opts}, state) do
    metric_name = "#{api_name}:#{endpoint}"
    record_metric(:api_call, metric_name, duration_ms, opts)
    check_threshold(:api_call, metric_name, duration_ms)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:track_liveview, view_module, action, duration_ms, opts}, state) do
    metric_name = "#{view_module}:#{action}"
    record_metric(:liveview, metric_name, duration_ms, opts)
    check_threshold(:liveview, metric_name, duration_ms)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_metrics_summary, time_range}, _from, state) do
    since = calculate_since_time(time_range)

    metrics =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_key, metric} ->
        DateTime.compare(metric.timestamp, since) == :gt
      end)
      |> Enum.group_by(fn {_key, metric} -> metric.type end)
      |> Enum.map(fn {type, metrics} ->
        stats = calculate_stats(metrics)
        {type, stats}
      end)
      |> Map.new()

    {:reply, metrics, state}
  end

  @impl true
  def handle_call({:get_slow_queries, threshold_ms}, _from, state) do
    slow_queries =
      :ets.tab2list(@table_name)
      |> Enum.filter(fn {_key, metric} ->
        metric.type == :query && metric.duration_ms > threshold_ms
      end)
      |> Enum.sort_by(fn {_key, metric} -> -metric.duration_ms end)
      |> Enum.take(20)
      |> Enum.map(fn {_key, metric} ->
        Map.take(metric, [:name, :duration_ms, :timestamp, :metadata])
      end)

    {:reply, slow_queries, state}
  end

  @impl true
  def handle_call(:get_bottlenecks, _from, state) do
    # Analyze recent metrics to identify bottlenecks
    recent_metrics = get_recent_metrics(:timer.minutes(15))

    bottlenecks = %{
      slowest_queries: get_slowest_by_type(recent_metrics, :query, 10),
      slowest_api_calls: get_slowest_by_type(recent_metrics, :api_call, 10),
      slowest_views: get_slowest_by_type(recent_metrics, :liveview, 10),
      high_frequency: get_high_frequency_operations(recent_metrics),
      performance_degradation: detect_performance_degradation(recent_metrics)
    }

    {:reply, bottlenecks, state}
  end

  @impl true
  def handle_info(:cleanup_metrics, state) do
    cleanup_old_metrics()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp record_metric(type, name, duration_ms, opts) do
    timestamp = DateTime.utc_now()
    key = {type, name, :erlang.unique_integer()}

    metric = %{
      type: type,
      name: name,
      duration_ms: duration_ms,
      timestamp: timestamp,
      metadata: Keyword.get(opts, :metadata, %{})
    }

    :ets.insert(@table_name, {key, metric})
  end

  defp check_threshold(type, name, duration_ms) do
    thresholds = %{
      # 1 second
      query: 1000,
      # 2 seconds
      api_call: 2000,
      # 500ms
      liveview: 500
    }

    threshold = Map.get(thresholds, type, 1000)

    if duration_ms > threshold do
      Logger.warning("""
      Performance threshold exceeded:
      Type: #{type}
      Name: #{name}
      Duration: #{duration_ms}ms
      Threshold: #{threshold}ms
      """)
    end
  end

  defp calculate_since_time(:minute), do: DateTime.add(DateTime.utc_now(), -60, :second)
  defp calculate_since_time(:hour), do: DateTime.add(DateTime.utc_now(), -3600, :second)
  defp calculate_since_time(:day), do: DateTime.add(DateTime.utc_now(), -86400, :second)

  defp calculate_stats(metrics) do
    durations = Enum.map(metrics, fn {_key, metric} -> metric.duration_ms end)

    %{
      count: length(metrics),
      min: Enum.min(durations, fn -> 0 end),
      max: Enum.max(durations, fn -> 0 end),
      avg: calculate_average(durations),
      p50: calculate_percentile(durations, 0.5),
      p95: calculate_percentile(durations, 0.95),
      p99: calculate_percentile(durations, 0.99)
    }
  end

  defp calculate_average([]), do: 0
  defp calculate_average(list), do: round(Enum.sum(list) / length(list))

  defp calculate_percentile([], _), do: 0

  defp calculate_percentile(list, percentile) do
    sorted = Enum.sort(list)
    index = round(percentile * length(sorted)) - 1
    Enum.at(sorted, max(0, index), 0)
  end

  defp get_recent_metrics(time_ms) do
    since = DateTime.add(DateTime.utc_now(), -div(time_ms, 1000), :second)

    :ets.tab2list(@table_name)
    |> Enum.filter(fn {_key, metric} ->
      DateTime.compare(metric.timestamp, since) == :gt
    end)
  end

  defp get_slowest_by_type(metrics, type, limit) do
    metrics
    |> Enum.filter(fn {_key, metric} -> metric.type == type end)
    |> Enum.sort_by(fn {_key, metric} -> -metric.duration_ms end)
    |> Enum.take(limit)
    |> Enum.map(fn {_key, metric} ->
      %{
        name: metric.name,
        duration_ms: metric.duration_ms,
        timestamp: metric.timestamp
      }
    end)
  end

  defp get_high_frequency_operations(metrics) do
    metrics
    |> Enum.group_by(fn {_key, metric} -> {metric.type, metric.name} end)
    |> Enum.map(fn {{type, name}, group} ->
      %{
        type: type,
        name: name,
        count: length(group),
        total_time_ms: Enum.sum(Enum.map(group, fn {_key, m} -> m.duration_ms end))
      }
    end)
    |> Enum.sort_by(& &1.total_time_ms, :desc)
    |> Enum.take(10)
  end

  defp detect_performance_degradation(metrics) do
    # Group by operation and check if recent performance is worse than historical
    metrics
    |> Enum.group_by(fn {_key, metric} -> {metric.type, metric.name} end)
    |> Enum.map(fn {{type, name}, group} ->
      sorted_by_time = Enum.sort_by(group, fn {_key, m} -> m.timestamp end)

      if length(sorted_by_time) >= 10 do
        {older, recent} = Enum.split(sorted_by_time, div(length(sorted_by_time), 2))

        older_avg = calculate_average(Enum.map(older, fn {_key, m} -> m.duration_ms end))
        recent_avg = calculate_average(Enum.map(recent, fn {_key, m} -> m.duration_ms end))

        degradation_pct =
          if older_avg > 0, do: (recent_avg - older_avg) / older_avg * 100, else: 0

        if degradation_pct > 20 do
          %{
            type: type,
            name: name,
            older_avg_ms: older_avg,
            recent_avg_ms: recent_avg,
            degradation_pct: Float.round(degradation_pct, 2)
          }
        end
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.sort_by(& &1.degradation_pct, :desc)
  end

  defp cleanup_old_metrics do
    cutoff = DateTime.add(DateTime.utc_now(), -div(@metric_ttl, 1000), :second)

    :ets.tab2list(@table_name)
    |> Enum.each(fn {key, metric} ->
      if DateTime.compare(metric.timestamp, cutoff) == :lt do
        :ets.delete(@table_name, key)
      end
    end)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_metrics, @cleanup_interval)
  end
end
