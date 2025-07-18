defmodule EveDmv.Monitoring.PerformanceDashboard do
  @moduledoc """
  Sprint 15A: Comprehensive performance monitoring dashboard.

  Provides real-time metrics, alerts, and performance insights for EVE DMV.
  Integrates with Telemetry for event-driven monitoring.
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub

  # Metrics we track
  @metrics %{
    queries: %{
      count: 0,
      durations: [],
      slow_queries: [],
      by_name: %{}
    },
    cache: %{
      hits: 0,
      misses: 0,
      invalidations: 0,
      hit_rate: 0.0
    },
    broadway: %{
      messages_processed: 0,
      batches_processed: 0,
      errors: 0,
      throughput: 0
    },
    memory: %{
      total_mb: 0,
      process_memory: %{},
      ets_tables: %{}
    },
    database: %{
      connection_pool_size: 0,
      connection_pool_available: 0,
      slow_queries: []
    },
    imports: %{
      active: 0,
      completed: 0,
      total_processed: 0,
      average_rate: 0
    }
  }

  defstruct [
    :metrics,
    :alerts,
    :history,
    :start_time
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current performance metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get performance alerts.
  """
  def get_alerts do
    GenServer.call(__MODULE__, :get_alerts)
  end

  @doc """
  Get historical metrics for a time range.
  """
  def get_history(duration_minutes \\ 60) do
    GenServer.call(__MODULE__, {:get_history, duration_minutes})
  end

  @doc """
  Subscribe to real-time performance updates.
  """
  def subscribe do
    PubSub.subscribe(EveDmv.PubSub, "performance:metrics")
  end

  # Server callbacks

  def init(_opts) do
    # Attach telemetry handlers
    attach_telemetry_handlers()

    # Schedule periodic snapshots
    Process.send_after(self(), :take_snapshot, :timer.seconds(30))

    # Schedule memory monitoring
    Process.send_after(self(), :monitor_memory, :timer.seconds(10))

    state = %__MODULE__{
      metrics: @metrics,
      alerts: [],
      history: [],
      start_time: DateTime.utc_now()
    }

    Logger.info("📊 Performance Dashboard started")

    {:ok, state}
  end

  def handle_call(:get_metrics, _from, state) do
    # Add calculated metrics
    metrics =
      state.metrics
      |> add_calculated_metrics()
      |> add_uptime(state.start_time)

    {:reply, metrics, state}
  end

  def handle_call(:get_alerts, _from, state) do
    # Return recent alerts
    recent_alerts =
      state.alerts
      |> Enum.take(50)
      |> Enum.map(fn alert ->
        Map.put(alert, :age_seconds, DateTime.diff(DateTime.utc_now(), alert.timestamp))
      end)

    {:reply, recent_alerts, state}
  end

  def handle_call({:get_history, duration_minutes}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -duration_minutes, :minute)

    history =
      state.history
      |> Enum.filter(fn snapshot ->
        DateTime.compare(snapshot.timestamp, cutoff) == :gt
      end)

    {:reply, history, state}
  end

  # Telemetry event handlers
  def handle_info(
        {:telemetry_event, [:eve_dmv, :query, :duration], measurements, metadata},
        state
      ) do
    duration = measurements.duration || 0
    query_name = metadata.query || "unknown"

    # Update query metrics
    metrics = state.metrics
    queries = metrics.queries

    # Track by name
    by_name =
      Map.update(
        queries.by_name,
        query_name,
        %{count: 1, total_duration: duration, avg_duration: duration},
        fn existing ->
          count = existing.count + 1
          total = existing.total_duration + duration
          %{existing | count: count, total_duration: total, avg_duration: round(total / count)}
        end
      )

    # Track slow queries (>500ms)
    slow_queries =
      if duration > 500 do
        query = %{
          name: query_name,
          duration: duration,
          timestamp: DateTime.utc_now(),
          metadata: metadata
        }

        [query | queries.slow_queries] |> Enum.take(100)
      else
        queries.slow_queries
      end

    updated_queries = %{
      queries
      | count: queries.count + 1,
        durations: [duration | queries.durations] |> Enum.take(1000),
        by_name: by_name,
        slow_queries: slow_queries
    }

    new_metrics = %{metrics | queries: updated_queries}
    new_state = %{state | metrics: new_metrics}

    # Check for performance degradation
    check_query_performance(query_name, duration, state)

    {:noreply, new_state}
  end

  def handle_info({:telemetry_event, [:eve_dmv, :cache, event], measurements, _metadata}, state) do
    metrics = state.metrics
    cache = metrics.cache

    updated_cache =
      case event do
        :hit ->
          %{cache | hits: cache.hits + 1}

        :miss ->
          %{cache | misses: cache.misses + 1}

        :invalidation ->
          count = measurements.count || 1
          %{cache | invalidations: cache.invalidations + count}

        _ ->
          cache
      end

    # Calculate hit rate
    total = updated_cache.hits + updated_cache.misses
    hit_rate = if total > 0, do: updated_cache.hits / total * 100, else: 0.0
    updated_cache = %{updated_cache | hit_rate: Float.round(hit_rate, 2)}

    new_metrics = %{metrics | cache: updated_cache}
    new_state = %{state | metrics: new_metrics}

    # Alert on low cache hit rate
    if hit_rate < 70 and total > 100 do
      add_alert(new_state, :warning, "Low cache hit rate: #{hit_rate}%", %{hit_rate: hit_rate})
    else
      {:noreply, new_state}
    end
  end

  def handle_info(
        {:telemetry_event, [:broadway, :processor, :message, event], _measurements, _metadata},
        state
      ) do
    metrics = state.metrics
    broadway = metrics.broadway

    updated_broadway =
      case event do
        :stop ->
          %{broadway | messages_processed: broadway.messages_processed + 1}

        :exception ->
          %{broadway | errors: broadway.errors + 1}

        _ ->
          broadway
      end

    new_metrics = %{metrics | broadway: updated_broadway}
    {:noreply, %{state | metrics: new_metrics}}
  end

  def handle_info({:telemetry_event, [:eve_dmv, :import, :batch], measurements, _metadata}, state) do
    metrics = state.metrics
    imports = metrics.imports

    processed = measurements.processed || 0

    updated_imports = %{imports | total_processed: imports.total_processed + processed}

    new_metrics = %{metrics | imports: updated_imports}
    {:noreply, %{state | metrics: new_metrics}}
  end

  def handle_info({:telemetry_event, [:ecto, :repo, :query], measurements, metadata}, state) do
    # Track database query performance
    duration = System.convert_time_unit(measurements.total_time || 0, :native, :millisecond)

    # Queries over 1 second
    if duration > 1000 do
      metrics = state.metrics
      database = metrics.database

      slow_query = %{
        query: String.slice(metadata.query || "", 0, 200),
        duration: duration,
        timestamp: DateTime.utc_now()
      }

      updated_database = %{
        database
        | slow_queries: [slow_query | database.slow_queries] |> Enum.take(50)
      }

      new_metrics = %{metrics | database: updated_database}
      new_state = %{state | metrics: new_metrics}

      # Alert on very slow queries
      if duration > 5000 do
        add_alert(new_state, :critical, "Very slow database query: #{duration}ms", slow_query)
      else
        {:noreply, new_state}
      end
    else
      {:noreply, state}
    end
  end

  # Memory monitoring
  def handle_info(:monitor_memory, state) do
    # Get system memory info
    memory_data = :erlang.memory()
    total_mb = memory_data[:total] / 1_048_576

    # Get top memory-consuming processes
    processes =
      Process.list()
      |> Enum.map(fn pid ->
        case Process.info(pid, [:registered_name, :memory, :message_queue_len]) do
          nil ->
            nil

          info ->
            %{
              pid: pid,
              name: info[:registered_name] || :unnamed,
              memory_mb: info[:memory] / 1_048_576,
              message_queue: info[:message_queue_len]
            }
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.memory_mb, :desc)
      |> Enum.take(20)

    # Get ETS table sizes
    ets_tables =
      :ets.all()
      |> Enum.map(fn table ->
        info = :ets.info(table)

        %{
          name: info[:name] || table,
          size: info[:size] || 0,
          memory_mb: (info[:memory] || 0) * :erlang.system_info(:wordsize) / 1_048_576
        }
      end)
      |> Enum.sort_by(& &1.memory_mb, :desc)
      |> Enum.take(10)

    metrics = state.metrics

    memory = %{
      total_mb: Float.round(total_mb, 2),
      process_memory: processes,
      ets_tables: ets_tables
    }

    new_metrics = %{metrics | memory: memory}
    new_state = %{state | metrics: new_metrics}

    # Check for memory issues
    new_state = check_memory_alerts(new_state, total_mb, processes)

    # Schedule next check
    Process.send_after(self(), :monitor_memory, :timer.seconds(10))

    {:noreply, new_state}
  end

  # Periodic snapshots for history
  def handle_info(:take_snapshot, state) do
    snapshot = %{
      timestamp: DateTime.utc_now(),
      queries_per_second: calculate_qps(state.metrics.queries),
      cache_hit_rate: state.metrics.cache.hit_rate,
      memory_mb: state.metrics.memory.total_mb,
      broadway_throughput: calculate_broadway_throughput(state.metrics.broadway),
      active_imports: state.metrics.imports.active
    }

    # Add to history (keep last 24 hours)
    # 30s intervals = 2880 per day
    history = [snapshot | state.history] |> Enum.take(2880)

    # Broadcast current metrics
    PubSub.broadcast(EveDmv.PubSub, "performance:metrics", {:metrics_update, state.metrics})

    # Schedule next snapshot
    Process.send_after(self(), :take_snapshot, :timer.seconds(30))

    {:noreply, %{state | history: history}}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp attach_telemetry_handlers do
    handlers = [
      {[:eve_dmv, :query, :duration], {__MODULE__, :handle_telemetry, []}},
      {[:eve_dmv, :cache, :hit], {__MODULE__, :handle_telemetry, []}},
      {[:eve_dmv, :cache, :miss], {__MODULE__, :handle_telemetry, []}},
      {[:eve_dmv, :cache, :invalidation], {__MODULE__, :handle_telemetry, []}},
      {[:broadway, :processor, :message, :stop], {__MODULE__, :handle_telemetry, []}},
      {[:broadway, :processor, :message, :exception], {__MODULE__, :handle_telemetry, []}},
      {[:eve_dmv, :import, :batch], {__MODULE__, :handle_telemetry, []}},
      {[:ecto, :repo, :query], {__MODULE__, :handle_telemetry, []}},
      {[:eve_dmv, :materialized_views, :refresh], {__MODULE__, :handle_telemetry, []}}
    ]

    Enum.each(handlers, fn {event, handler} ->
      :telemetry.attach(
        "performance-dashboard-#{inspect(event)}",
        event,
        handler,
        nil
      )
    end)
  end

  def handle_telemetry(event, measurements, metadata, _config) do
    send(self(), {:telemetry_event, event, measurements, metadata})
  end

  defp add_calculated_metrics(metrics) do
    # Add query performance stats
    queries = metrics.queries

    query_stats =
      if length(queries.durations) > 0 do
        sorted = Enum.sort(queries.durations)

        %{
          avg_duration: round(Enum.sum(sorted) / length(sorted)),
          p50: Enum.at(sorted, round(length(sorted) * 0.5)),
          p95: Enum.at(sorted, round(length(sorted) * 0.95)),
          p99: Enum.at(sorted, round(length(sorted) * 0.99))
        }
      else
        %{avg_duration: 0, p50: 0, p95: 0, p99: 0}
      end

    updated_queries = Map.put(queries, :stats, query_stats)
    %{metrics | queries: updated_queries}
  end

  defp add_uptime(metrics, start_time) do
    uptime_seconds = DateTime.diff(DateTime.utc_now(), start_time)
    Map.put(metrics, :uptime_seconds, uptime_seconds)
  end

  defp calculate_qps(queries) do
    # Calculate queries per second from recent history
    recent = queries.durations |> Enum.take(100)

    if length(recent) > 0 do
      # Over last 30 seconds
      Float.round(length(recent) / 30, 2)
    else
      0.0
    end
  end

  defp calculate_broadway_throughput(broadway) do
    # Messages per minute
    broadway.messages_processed
  end

  defp check_query_performance(query_name, duration, state) do
    # Check if this query is consistently slow
    by_name = state.metrics.queries.by_name

    case Map.get(by_name, query_name) do
      %{avg_duration: avg} when avg > 1000 and duration > 2000 ->
        add_alert(state, :warning, "Consistently slow query: #{query_name}", %{
          avg_duration: avg,
          current_duration: duration
        })

      _ ->
        {:noreply, state}
    end
  end

  defp check_memory_alerts(state, total_mb, processes) do
    cond do
      total_mb > 4000 ->
        add_alert(state, :critical, "High memory usage: #{round(total_mb)}MB", %{
          memory_mb: total_mb
        })

      total_mb > 2000 ->
        add_alert(state, :warning, "Elevated memory usage: #{round(total_mb)}MB", %{
          memory_mb: total_mb
        })

      true ->
        # Check for individual process memory issues
        case Enum.find(processes, &(&1.memory_mb > 500)) do
          nil ->
            state

          process ->
            add_alert(
              state,
              :warning,
              "Process using high memory: #{inspect(process.name)}",
              process
            )
        end
    end
  end

  defp add_alert(state, level, message, details) do
    alert = %{
      id: System.unique_integer([:positive]),
      level: level,
      message: message,
      details: details,
      timestamp: DateTime.utc_now()
    }

    # Keep last 100 alerts
    alerts = [alert | state.alerts] |> Enum.take(100)

    # Log critical alerts
    if level == :critical do
      Logger.error("🚨 Performance Alert: #{message}")
    end

    # Broadcast alert
    PubSub.broadcast(EveDmv.PubSub, "performance:alerts", {:performance_alert, alert})

    %{state | alerts: alerts}
  end

  # Public utilities for dashboard UI

  @doc """
  Get performance report for the last N minutes.
  """
  def generate_report(minutes \\ 60) do
    metrics = get_metrics()
    history = get_history(minutes)
    alerts = get_alerts()

    %{
      summary: %{
        uptime: format_uptime(metrics.uptime_seconds),
        queries_total: metrics.queries.count,
        cache_hit_rate: metrics.cache.hit_rate,
        memory_usage: metrics.memory.total_mb,
        active_alerts: length(Enum.filter(alerts, &(&1.age_seconds < 300)))
      },
      performance: %{
        query_stats: metrics.queries.stats,
        top_queries:
          metrics.queries.by_name
          |> Map.to_list()
          |> Enum.sort_by(fn {_, stats} -> stats.total_duration end, :desc)
          |> Enum.take(10),
        slow_queries: Enum.take(metrics.queries.slow_queries, 10)
      },
      trends: analyze_trends(history),
      alerts: alerts
    }
  end

  defp format_uptime(seconds) when seconds < 3600 do
    "#{div(seconds, 60)} minutes"
  end

  defp format_uptime(seconds) when seconds < 86400 do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    "#{days}d #{hours}h"
  end

  defp analyze_trends(history) do
    if length(history) < 2 do
      %{status: :insufficient_data}
    else
      recent = Enum.take(history, 10)
      older = Enum.slice(history, 30, 10)

      %{
        cache_hit_trend: compare_metric(recent, older, & &1.cache_hit_rate),
        memory_trend: compare_metric(recent, older, & &1.memory_mb),
        query_rate_trend: compare_metric(recent, older, & &1.queries_per_second)
      }
    end
  end

  defp compare_metric(recent, older, extractor) do
    recent_avg = average(recent, extractor)
    older_avg = average(older, extractor)

    if older_avg > 0 do
      change = (recent_avg - older_avg) / older_avg * 100

      %{
        direction: if(change > 0, do: :up, else: :down),
        percentage: Float.round(abs(change), 1)
      }
    else
      %{direction: :stable, percentage: 0.0}
    end
  end

  defp average(list, extractor) do
    if length(list) > 0 do
      sum = list |> Enum.map(extractor) |> Enum.sum()
      sum / length(list)
    else
      0.0
    end
  end
end
