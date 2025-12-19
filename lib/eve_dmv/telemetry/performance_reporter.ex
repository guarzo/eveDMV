defmodule EveDmv.Telemetry.PerformanceReporter do
  @moduledoc """
  Performance monitoring and reporting module using Telemetry.

  Tracks key performance metrics across the application including:
  - Database query performance
  - Cache hit rates
  - API response times
  - LiveView render times
  - Memory usage
  - Process counts
  """

  use GenServer
  require Logger

  # Report every minute
  @metrics_interval 60_000
  # 500ms is a reasonable threshold - 100ms was too aggressive and caused
  # false positives for legitimate static data queries
  @slow_query_threshold_ms 500
  @slow_api_threshold_ms 1000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def report_metric(metric_name, value, metadata \\ %{}) do
    :telemetry.execute(
      [:eve_dmv, :performance, metric_name],
      %{value: value},
      metadata
    )
  end

  def get_current_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def reset_stats do
    GenServer.call(__MODULE__, :reset_stats)
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    # Attach telemetry handlers
    attach_handlers()

    # Schedule periodic reporting
    schedule_report()

    state = %{
      query_times: [],
      cache_hits: 0,
      cache_misses: 0,
      api_calls: [],
      render_times: [],
      slow_queries: [],
      errors: [],
      start_time: System.system_time(:second)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = calculate_stats(state)
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:reset_stats, _from, state) do
    new_state = %{
      state
      | query_times: [],
        cache_hits: 0,
        cache_misses: 0,
        api_calls: [],
        render_times: [],
        slow_queries: [],
        errors: [],
        start_time: System.system_time(:second)
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:report_metrics, state) do
    # Calculate and log metrics
    stats = calculate_stats(state)
    log_performance_report(stats)

    # Send to monitoring service if configured
    maybe_send_to_monitoring(stats)

    # Reset short-term metrics
    new_state = %{
      state
      | # Keep last 100
        query_times: Enum.take(state.query_times, -100),
        api_calls: Enum.take(state.api_calls, -100),
        render_times: Enum.take(state.render_times, -100)
    }

    schedule_report()
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:telemetry_event, measurements, metadata}, state) do
    new_state = process_telemetry_event(measurements, metadata, state)
    {:noreply, new_state}
  end

  # Private Functions

  defp attach_handlers do
    handlers = [
      # Ecto queries
      {[:eve_dmv, :repo, :query], &handle_query_event/4},

      # Cache operations
      {[:eve_dmv, :cache, :access], &handle_cache_event/4},

      # API calls
      {[:eve_dmv, :api, :call], &handle_api_event/4},

      # LiveView rendering
      {[:phoenix, :live_view, :mount], &handle_liveview_event/4},
      {[:phoenix, :live_view, :handle_event], &handle_liveview_event/4},
      {[:phoenix, :live_view, :handle_params], &handle_liveview_event/4},

      # Battle analysis
      {[:eve_dmv, :battle_analysis, :computed], &handle_analysis_event/4},

      # Pipeline processing
      {[:broadway, :processor, :stop], &handle_broadway_event/4},

      # HTTP requests
      {[:finch, :request, :stop], &handle_http_event/4},

      # VM metrics
      {[:vm, :memory], &handle_vm_event/4},
      {[:vm, :total_run_queue_lengths], &handle_vm_event/4}
    ]

    Enum.each(handlers, fn {event_name, handler} ->
      :telemetry.attach(
        "performance-#{inspect(event_name)}",
        event_name,
        handler,
        nil
      )
    end)
  end

  defp handle_query_event(_event_name, measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.total_time, :native, :millisecond)

    event_data = %{
      duration: duration,
      query: metadata.query,
      source: metadata.source
    }

    GenServer.cast(__MODULE__, {:query_event, event_data})

    # Log slow queries
    if duration > @slow_query_threshold_ms do
      Logger.warning(
        "Slow query detected (#{duration}ms): #{String.slice(metadata.query, 0, 100)}..."
      )
    end
  end

  defp handle_cache_event(_event_name, _measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:cache_event, metadata.type})
  end

  defp handle_api_event(_event_name, measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    event_data = %{
      duration: duration,
      endpoint: metadata.endpoint,
      status: metadata.status
    }

    GenServer.cast(__MODULE__, {:api_event, event_data})

    # Log slow API calls
    if duration > @slow_api_threshold_ms do
      Logger.warning("Slow API call (#{duration}ms): #{metadata.endpoint}")
    end
  end

  defp handle_liveview_event(_event_name, measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    event_data = %{
      duration: duration,
      module: metadata.socket.view,
      action: metadata.event
    }

    GenServer.cast(__MODULE__, {:render_event, event_data})
  end

  defp handle_analysis_event(_event_name, measurements, metadata, _config) do
    Logger.info(
      "Battle analysis completed for #{metadata.battle_id} in #{measurements.duration}ms"
    )
  end

  defp handle_broadway_event(_event_name, measurements, _metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    :telemetry.execute(
      [:eve_dmv, :performance, :broadway],
      %{duration: duration, messages: measurements.messages},
      %{}
    )
  end

  defp handle_http_event(_event_name, measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)

    :telemetry.execute(
      [:eve_dmv, :performance, :http],
      %{duration: duration},
      %{host: metadata.request.host, method: metadata.request.method}
    )
  end

  defp handle_vm_event([:vm, :memory], measurements, _metadata, _config) do
    :telemetry.execute(
      [:eve_dmv, :performance, :memory],
      measurements,
      %{}
    )
  end

  defp handle_vm_event([:vm, :total_run_queue_lengths], measurements, _metadata, _config) do
    :telemetry.execute(
      [:eve_dmv, :performance, :run_queue],
      measurements,
      %{}
    )
  end

  @impl GenServer
  def handle_cast({:query_event, event_data}, state) do
    new_state = %{state | query_times: [event_data | state.query_times]}

    final_state =
      if event_data.duration > @slow_query_threshold_ms do
        %{new_state | slow_queries: [event_data | new_state.slow_queries]}
      else
        new_state
      end

    {:noreply, final_state}
  end

  @impl GenServer
  def handle_cast({:cache_event, :hit}, state) do
    {:noreply, %{state | cache_hits: state.cache_hits + 1}}
  end

  @impl GenServer
  def handle_cast({:cache_event, type}, state) when type in [:miss, :l1_hit, :l2_hit, :l3_hit] do
    # Track different cache layer hits
    if type == :miss do
      {:noreply, %{state | cache_misses: state.cache_misses + 1}}
    else
      {:noreply, %{state | cache_hits: state.cache_hits + 1}}
    end
  end

  @impl GenServer
  def handle_cast({:api_event, event_data}, state) do
    {:noreply, %{state | api_calls: [event_data | state.api_calls]}}
  end

  @impl GenServer
  def handle_cast({:render_event, event_data}, state) do
    {:noreply, %{state | render_times: [event_data | state.render_times]}}
  end

  defp process_telemetry_event(_measurements, _metadata, state) do
    state
  end

  defp calculate_stats(state) do
    uptime_seconds = System.system_time(:second) - state.start_time

    %{
      uptime_seconds: uptime_seconds,
      database: calculate_query_stats(state.query_times),
      cache: calculate_cache_stats(state),
      api: calculate_api_stats(state.api_calls),
      rendering: calculate_render_stats(state.render_times),
      slow_queries: length(state.slow_queries),
      errors: length(state.errors),
      memory: get_memory_stats(),
      processes: get_process_stats()
    }
  end

  defp calculate_query_stats([]), do: %{count: 0, avg_ms: 0, p95_ms: 0, p99_ms: 0}

  defp calculate_query_stats(query_times) do
    durations = Enum.map(query_times, & &1.duration) |> Enum.sort()

    %{
      count: length(durations),
      avg_ms: Enum.sum(durations) / length(durations),
      p50_ms: percentile(durations, 0.50),
      p95_ms: percentile(durations, 0.95),
      p99_ms: percentile(durations, 0.99),
      max_ms: Enum.max(durations, fn -> 0 end)
    }
  end

  defp calculate_cache_stats(state) do
    total = state.cache_hits + state.cache_misses
    hit_rate = if total > 0, do: state.cache_hits / total * 100, else: 0

    %{
      hits: state.cache_hits,
      misses: state.cache_misses,
      hit_rate: Float.round(hit_rate, 2)
    }
  end

  defp calculate_api_stats([]), do: %{count: 0, avg_ms: 0, error_rate: 0}

  defp calculate_api_stats(api_calls) do
    durations = Enum.map(api_calls, & &1.duration)
    errors = Enum.count(api_calls, &(&1.status >= 400))
    api_count = length(api_calls)
    duration_count = length(durations)

    %{
      count: api_count,
      avg_ms: if(duration_count > 0, do: Enum.sum(durations) / duration_count, else: 0),
      error_rate: if(api_count > 0, do: errors / api_count * 100, else: 0)
    }
  end

  defp calculate_render_stats([]), do: %{count: 0, avg_ms: 0}

  defp calculate_render_stats(render_times) do
    durations = Enum.map(render_times, & &1.duration)
    render_count = length(render_times)
    duration_count = length(durations)

    %{
      count: render_count,
      avg_ms: if(duration_count > 0, do: Enum.sum(durations) / duration_count, else: 0),
      p95_ms: percentile(durations, 0.95),
      p99_ms: percentile(durations, 0.99)
    }
  end

  defp get_memory_stats do
    memory = :erlang.memory()

    %{
      total_mb: memory[:total] / 1_048_576,
      processes_mb: memory[:processes] / 1_048_576,
      ets_mb: memory[:ets] / 1_048_576,
      binary_mb: memory[:binary] / 1_048_576
    }
  end

  defp get_process_stats do
    %{
      count: :erlang.system_info(:process_count),
      run_queue: :erlang.statistics(:run_queue)
    }
  end

  defp percentile([], _), do: 0

  defp percentile(sorted_list, p) do
    raw_index = round(p * length(sorted_list)) - 1
    index = max(0, min(raw_index, length(sorted_list) - 1))
    Enum.at(sorted_list, index)
  end

  defp log_performance_report(stats) do
    Logger.info("""
    === Performance Report ===
    Uptime: #{format_duration(stats.uptime_seconds)}

    Database:
      Queries: #{stats.database.count}
      Avg: #{Float.round(stats.database.avg_ms, 1)}ms
      P95: #{Float.round(stats.database.p95_ms, 1)}ms
      P99: #{Float.round(stats.database.p99_ms, 1)}ms
      Slow queries: #{stats.slow_queries}

    Cache:
      Hits: #{stats.cache.hits}
      Misses: #{stats.cache.misses}
      Hit rate: #{stats.cache.hit_rate}%

    API:
      Calls: #{stats.api.count}
      Avg response: #{Float.round(stats.api.avg_ms, 1)}ms
      Error rate: #{Float.round(stats.api.error_rate, 2)}%

    Rendering:
      Renders: #{stats.rendering.count}
      Avg: #{Float.round(stats.rendering.avg_ms, 1)}ms

    Memory:
      Total: #{Float.round(stats.memory.total_mb, 1)}MB
      Processes: #{Float.round(stats.memory.processes_mb, 1)}MB
      ETS: #{Float.round(stats.memory.ets_mb, 1)}MB

    Processes:
      Count: #{stats.processes.count}
      Run queue: #{stats.processes.run_queue}
    """)
  end

  defp maybe_send_to_monitoring(_stats) do
    # Send to external monitoring service if configured
    if Application.get_env(:eve_dmv, :monitoring_enabled) do
      # Implementation would send to DataDog, Prometheus, etc.
      :ok
    end
  end

  defp schedule_report do
    Process.send_after(self(), :report_metrics, @metrics_interval)
  end

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    "#{minutes}m #{rem(seconds, 60)}s"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end
end
