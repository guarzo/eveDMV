defmodule EveDmv.Platform.Monitoring.HealthAggregator do
  @moduledoc """
  Aggregates health and performance metrics from all system components.
  Provides a single API for the health dashboard.
  """

  alias EveDmv.Monitoring.ErrorTracker
  alias EveDmv.Monitoring.PipelineMonitor
  alias EveDmv.Platform.Cache.QueryCache
  alias EveDmv.Platform.Monitoring.HealthConfig
  alias EveDmv.Repo
  alias EveDmv.Telemetry.OtelSpans
  alias EveDmv.Telemetry.QueryMonitor

  require Logger

  # Cache TTL for Process.list() in milliseconds (5 seconds)
  @process_list_cache_ttl_ms 5_000

  # Process dictionary key for cached process list
  @process_list_cache_key :health_aggregator_process_list_cache

  @doc """
  Returns comprehensive system health snapshot.

  Emits telemetry events:
  - `[:eve_dmv, :health, :snapshot, :start]` - When snapshot collection begins
  - `[:eve_dmv, :health, :snapshot, :stop]` - When snapshot collection completes
  - `[:eve_dmv, :health, :snapshot, :exception]` - If an exception occurs

  Per-subsystem telemetry events:
  - `[:eve_dmv, :health, :subsystem]` - Emitted for each subsystem check

  Per-subsystem measurements:
  - `:latency_us` - Time taken to collect the subsystem health in microseconds

  Per-subsystem metadata:
  - `:subsystem` - Name of the subsystem (:database, :pipeline, :cache, :memory, :liveview, :queries, :errors, :uptime)
  - `:status` - Health status of the subsystem (:healthy, :warning, :critical, :unknown)
  - `:error` - Error message if the subsystem check failed (optional)

  Measurements (stop event):
  - `:duration` - Time taken in native units

  Metadata:
  - `:overall_status` - The computed overall system status (:healthy, :warning, :critical, :degraded)
  - `:uptime_seconds` - System uptime in seconds
  - `:subsystem_count` - Number of subsystems checked

  OpenTelemetry:
  - Wrapped with OpenTelemetry span `health.snapshot` for distributed tracing
  - Child spans created for each subsystem check
  """
  def get_health_snapshot do
    OtelSpans.with_span("health.snapshot", %{}, fn ->
      :telemetry.span(
        [:eve_dmv, :health, :snapshot],
        %{},
        fn ->
          snapshot = collect_health_snapshot()

          telemetry_metadata = %{
            overall_status: snapshot.overall_status,
            uptime_seconds: snapshot.uptime.total_seconds,
            subsystem_count: 8
          }

          {snapshot, telemetry_metadata}
        end
      )
    end)
  end

  defp collect_health_snapshot do
    database = collect_subsystem_health(:database, &get_database_health/0)
    pipeline = collect_subsystem_health(:pipeline, &get_pipeline_health/0)
    cache = collect_subsystem_health(:cache, &get_cache_health/0)
    memory = collect_subsystem_health(:memory, &get_memory_health/0)
    liveview = collect_subsystem_health(:liveview, &get_liveview_health/0)
    queries = collect_subsystem_health(:queries, &get_query_health/0)
    errors = collect_subsystem_health(:errors, &get_recent_errors/0)
    uptime = collect_subsystem_health(:uptime, &get_uptime/0)

    %{
      timestamp: DateTime.utc_now(),
      overall_status: calculate_overall_status(database, pipeline, cache, memory, queries),
      database: database,
      pipeline: pipeline,
      cache: cache,
      memory: memory,
      liveview: liveview,
      queries: queries,
      errors: errors,
      uptime: uptime
    }
  end

  # Wraps a subsystem health check with telemetry and OpenTelemetry instrumentation.
  # Measures latency, captures status and any errors, and emits per-subsystem events.
  defp collect_subsystem_health(subsystem_name, health_fn) do
    span_name = "health.subsystem.#{subsystem_name}"

    OtelSpans.with_span(span_name, %{subsystem: subsystem_name}, fn ->
      start_time = System.monotonic_time(:microsecond)

      try do
        result = health_fn.()
        latency_us = System.monotonic_time(:microsecond) - start_time

        # Extract status from result - different subsystems have different structures
        status = extract_status(result)

        :telemetry.execute(
          [:eve_dmv, :health, :subsystem],
          %{latency_us: latency_us},
          %{subsystem: subsystem_name, status: status}
        )

        result
      rescue
        e ->
          latency_us = System.monotonic_time(:microsecond) - start_time
          error_message = Exception.message(e)

          :telemetry.execute(
            [:eve_dmv, :health, :subsystem],
            %{latency_us: latency_us},
            %{subsystem: subsystem_name, status: :error, error: error_message}
          )

          Logger.error(
            "Subsystem health check failed for #{subsystem_name}: #{error_message}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
          )

          # Return a fallback result indicating error
          %{status: :unknown, error: error_message}
      end
    end)
  end

  # Extracts the status from a subsystem health result.
  # Different subsystems return different structures.
  defp extract_status(%{status: status}), do: status
  # Uptime and errors don't have a status field - they're always considered healthy
  defp extract_status(%{total_seconds: _}), do: :healthy
  defp extract_status(%{count: _}), do: :healthy
  defp extract_status(_), do: :unknown

  @doc """
  Returns database connection pool and query statistics.
  """
  def get_database_health do
    pool_stats = get_pool_stats()
    query_stats = get_query_stats()

    %{
      status: database_status(pool_stats),
      pool: pool_stats,
      queries: query_stats,
      slow_queries: get_slow_queries(5),
      connections: %{
        active: pool_stats.checked_out,
        available: pool_stats.available,
        total: pool_stats.pool_size,
        utilization_percent: pool_stats.utilization
      }
    }
  end

  defp get_pool_stats do
    pool_size = Application.get_env(:eve_dmv, Repo)[:pool_size] || 20

    query = """
    SELECT
      count(*) FILTER (WHERE state = 'active') as active,
      count(*) FILTER (WHERE state = 'idle') as idle,
      count(*) FILTER (WHERE wait_event_type = 'Client') as waiting,
      count(*) as total
    FROM pg_stat_activity
    WHERE datname = current_database()
      AND pid != pg_backend_pid()
      AND usename = current_user
    """

    case Repo.query(query) do
      {:ok, %{rows: [[active, idle, waiting, _total]]}} ->
        active = active || 0
        idle = idle || 0

        %{
          pool_size: pool_size,
          checked_out: active,
          available: idle,
          queue_length: waiting || 0,
          utilization: Float.round(active / max(pool_size, 1) * 100, 1)
        }

      {:ok, _result} ->
        Logger.warning("get_pool_stats/0 returned unexpected result format")

        %{
          pool_size: pool_size,
          checked_out: 0,
          available: pool_size,
          queue_length: 0,
          utilization: 0.0
        }

      {:error, reason} ->
        Logger.error("get_pool_stats/0 failed: #{inspect(reason)}")

        %{
          pool_size: pool_size,
          checked_out: 0,
          available: pool_size,
          queue_length: 0,
          utilization: 0.0,
          error: inspect(reason)
        }
    end
  end

  defp get_query_stats do
    query = """
    SELECT
      sum(calls) as total_queries,
      round(sum(total_exec_time)::numeric, 2) as total_time_ms,
      round(avg(mean_exec_time)::numeric, 2) as avg_time_ms,
      max(max_exec_time) as max_time_ms
    FROM pg_stat_statements
    WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    """

    case Repo.query(query) do
      {:ok, %{rows: [[total, total_time, avg_time, max_time]]}} ->
        %{
          total_queries: total || 0,
          total_time_ms: total_time || 0,
          avg_time_ms: avg_time || 0,
          max_time_ms: max_time || 0
        }

      {:ok, _result} ->
        %{
          total_queries: 0,
          total_time_ms: 0,
          avg_time_ms: 0,
          max_time_ms: 0,
          note: "pg_stat_statements not available"
        }

      {:error, reason} ->
        Logger.error("get_query_stats/0 failed: #{inspect(reason)}")

        %{
          total_queries: 0,
          total_time_ms: 0,
          avg_time_ms: 0,
          max_time_ms: 0,
          note: "pg_stat_statements not available"
        }
    end
  end

  defp get_slow_queries(limit) do
    query = """
    SELECT
      left(query, 100) as query_preview,
      calls,
      round(mean_exec_time::numeric, 2) as avg_ms,
      round(max_exec_time::numeric, 2) as max_ms,
      round(total_exec_time::numeric, 2) as total_ms
    FROM pg_stat_statements
    WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
      AND mean_exec_time > 100
    ORDER BY mean_exec_time DESC
    LIMIT $1
    """

    case Repo.query(query, [limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [query_text, calls, avg, max, total] ->
          %{query: query_text, calls: calls, avg_ms: avg, max_ms: max, total_ms: total}
        end)

      {:error, reason} ->
        Logger.error("get_slow_queries/1 failed: #{inspect(reason)}")
        []
    end
  end

  defp database_status(pool_stats) do
    HealthConfig.database_status(pool_stats)
  end

  @doc """
  Returns Broadway pipeline health and throughput.
  """
  def get_pipeline_health do
    metrics = PipelineMonitor.get_metrics()

    messages_processed = get_in(metrics, [:messages, :processed]) || 0
    messages_failed = get_in(metrics, [:messages, :failed]) || 0
    batches_processed = get_in(metrics, [:batches, :processed]) || 0

    success_rate =
      if messages_processed > 0 do
        Float.round((messages_processed - messages_failed) / messages_processed * 100, 1)
      else
        100.0
      end

    avg_processing_time = get_in(metrics, [:performance, :avg_processing_time_ms]) || 0

    %{
      status: pipeline_status(success_rate, messages_failed),
      messages_processed: messages_processed,
      messages_failed: messages_failed,
      batches_processed: batches_processed,
      success_rate: success_rate,
      throughput: calculate_throughput(metrics),
      last_batch_time: get_in(metrics, [:last_success]),
      avg_processing_time_ms: avg_processing_time
    }
  rescue
    e ->
      stacktrace = __STACKTRACE__

      Logger.error(
        "get_pipeline_health/0 failed: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
      )

      %{
        status: :unknown,
        messages_processed: 0,
        messages_failed: 0,
        batches_processed: 0,
        success_rate: 100.0,
        throughput: 0,
        note: "Pipeline metrics unavailable",
        error: Exception.message(e)
      }
  end

  defp calculate_throughput(metrics) do
    # Calculate messages per minute based on uptime
    uptime_minutes = get_in(metrics, [:uptime_minutes]) || 1

    messages_processed = get_in(metrics, [:messages, :processed]) || 0

    if uptime_minutes > 0 do
      Float.round(messages_processed / max(uptime_minutes, 1), 1)
    else
      0
    end
  end

  defp pipeline_status(success_rate, messages_failed) do
    HealthConfig.pipeline_status(success_rate, messages_failed)
  end

  @doc """
  Returns cache statistics and hit rates.
  """
  def get_cache_health do
    query_cache_stats = QueryCache.get_stats()

    %{
      status: cache_status(query_cache_stats),
      query_cache: %{
        hits: query_cache_stats.hits,
        misses: query_cache_stats.misses,
        hit_rate: query_cache_stats.hit_rate,
        size: query_cache_stats[:cache_size] || 0,
        memory_mb: query_cache_stats[:memory_mb] || 0
      },
      ets_tables: get_ets_table_stats()
    }
  rescue
    e ->
      stacktrace = __STACKTRACE__

      Logger.error(
        "get_cache_health/0 failed: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
      )

      %{
        status: :unknown,
        query_cache: %{hits: 0, misses: 0, hit_rate: 0, size: 0, memory_mb: 0},
        ets_tables: [],
        note: "Cache stats unavailable",
        error: Exception.message(e)
      }
  end

  defp get_ets_table_stats do
    :ets.all()
    |> Enum.map(fn table ->
      try do
        info = :ets.info(table)

        %{
          name: table,
          size: info[:size] || 0,
          memory_bytes: (info[:memory] || 0) * :erlang.system_info(:wordsize)
        }
      rescue
        e ->
          stacktrace = __STACKTRACE__

          Logger.error(
            "get_ets_table_stats/0 failed for table #{inspect(table)}: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
          )

          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory_bytes, :desc)
    |> Enum.take(10)
  end

  defp cache_status(stats) do
    HealthConfig.cache_status(stats)
  end

  @doc """
  Returns BEAM memory statistics.
  """
  def get_memory_health do
    memory = :erlang.memory()
    total_mb = Float.round(memory[:total] / 1_048_576, 2)

    %{
      status: memory_status(total_mb),
      total_mb: total_mb,
      processes_mb: Float.round(memory[:processes] / 1_048_576, 2),
      ets_mb: Float.round(memory[:ets] / 1_048_576, 2),
      binary_mb: Float.round(memory[:binary] / 1_048_576, 2),
      atom_mb: Float.round(memory[:atom] / 1_048_576, 2),
      code_mb: Float.round(memory[:code] / 1_048_576, 2),
      system_mb: Float.round(memory[:system] / 1_048_576, 2),
      top_processes: get_top_memory_processes(5)
    }
  end

  defp get_top_memory_processes(limit) do
    get_cached_process_list()
    |> Enum.map(fn pid ->
      try do
        info = Process.info(pid, [:memory, :registered_name, :current_function])

        if info do
          name = info[:registered_name] || inspect(info[:current_function])
          %{pid: inspect(pid), name: name, memory_kb: div(info[:memory], 1024)}
        end
      rescue
        e ->
          stacktrace = __STACKTRACE__

          Logger.error(
            "get_top_memory_processes/1 failed for pid #{inspect(pid)}: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
          )

          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory_kb, :desc)
    |> Enum.take(limit)
  end

  defp memory_status(total_mb) do
    HealthConfig.memory_status(total_mb)
  end

  # Returns a cached process list if still valid (within TTL), otherwise fetches fresh.
  # Uses process dictionary for per-process caching to avoid cross-process synchronization.
  defp get_cached_process_list do
    now_ms = System.monotonic_time(:millisecond)

    case Process.get(@process_list_cache_key) do
      {cached_at, process_list} when now_ms - cached_at < @process_list_cache_ttl_ms ->
        process_list

      _ ->
        process_list = Process.list()
        Process.put(@process_list_cache_key, {now_ms, process_list})
        process_list
    end
  end

  @doc """
  Returns LiveView socket statistics.
  """
  def get_liveview_health do
    # Count LiveView processes using cached process list
    liveview_count =
      get_cached_process_list()
      |> Enum.count(fn pid ->
        try do
          case Process.info(pid, :dictionary) do
            {:dictionary, dict} -> Keyword.has_key?(dict, :phoenix_live_view)
            _ -> false
          end
        rescue
          e ->
            stacktrace = __STACKTRACE__

            Logger.error(
              "get_liveview_health/0 failed for pid #{inspect(pid)}: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
            )

            false
        end
      end)

    %{
      status: liveview_status(liveview_count),
      active_sockets: liveview_count
    }
  end

  defp liveview_status(count) do
    HealthConfig.liveview_status(count)
  end

  @doc """
  Returns query performance summary.
  """
  def get_query_health do
    slow_queries = QueryMonitor.get_slow_queries()
    n_plus_one = QueryMonitor.get_n_plus_one_alerts()

    %{
      status: query_health_status(slow_queries, n_plus_one),
      slow_query_count: length(slow_queries),
      n_plus_one_count: length(n_plus_one),
      slow_queries: Enum.take(slow_queries, 5),
      n_plus_one_alerts: Enum.take(n_plus_one, 5)
    }
  rescue
    e ->
      stacktrace = __STACKTRACE__

      Logger.error(
        "get_query_health/0 failed: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
      )

      %{
        status: :unknown,
        slow_query_count: 0,
        n_plus_one_count: 0,
        slow_queries: [],
        n_plus_one_alerts: [],
        error: Exception.message(e)
      }
  end

  defp query_health_status(slow_queries, n_plus_one) do
    HealthConfig.query_health_status(slow_queries, n_plus_one)
  end

  @doc """
  Returns recent errors from error tracker.
  """
  def get_recent_errors do
    errors = ErrorTracker.get_recent_errors(10)

    formatted_errors =
      Enum.map(errors, fn error ->
        %{
          message: get_error_message(error),
          timestamp: error.timestamp,
          module: error.module,
          function: error.function
        }
      end)

    %{
      count: length(formatted_errors),
      errors: formatted_errors
    }
  rescue
    e ->
      stacktrace = __STACKTRACE__

      Logger.error(
        "get_recent_errors/0 failed: #{Exception.message(e)}\n#{Exception.format_stacktrace(stacktrace)}"
      )

      %{count: 0, errors: [], error: Exception.message(e)}
  end

  defp get_error_message(error) do
    cond do
      is_map(error) and Map.has_key?(error, :error) ->
        case error.error do
          %{message: msg} -> msg
          other -> inspect(other)
        end

      is_map(error) and Map.has_key?(error, :message) ->
        error.message

      true ->
        inspect(error)
    end
  end

  @doc """
  Returns application uptime.
  """
  def get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_seconds = div(uptime_ms, 1000)

    days = div(uptime_seconds, 86_400)
    hours = div(rem(uptime_seconds, 86_400), 3600)
    minutes = div(rem(uptime_seconds, 3600), 60)
    seconds = rem(uptime_seconds, 60)

    %{
      total_seconds: uptime_seconds,
      formatted: "#{days}d #{hours}h #{minutes}m #{seconds}s",
      started_at: DateTime.add(DateTime.utc_now(), -uptime_seconds, :second)
    }
  end

  defp calculate_overall_status(database, pipeline, cache, memory, queries) do
    statuses = [
      database.status,
      pipeline.status,
      cache.status,
      memory.status,
      queries.status
    ]

    cond do
      :critical in statuses -> :critical
      :warning in statuses -> :warning
      :unknown in statuses -> :degraded
      true -> :healthy
    end
  end
end
