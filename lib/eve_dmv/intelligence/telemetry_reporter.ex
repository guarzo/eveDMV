defmodule EveDmv.Intelligence.TelemetryReporter do
  @moduledoc """
  Telemetry reporter for Intelligence system metrics.

  Collects and reports telemetry events from intelligence analyzers,
  providing observability into analysis performance, cache effectiveness,
  and system health.
  """

  use GenServer
  require Logger

  @doc """
  Start the telemetry reporter.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Intelligence telemetry reporter")

    # Attach to intelligence telemetry events
    attach_telemetry_handlers()

    # Initialize metrics collection
    state = %{
      start_time: System.monotonic_time(),
      analysis_count: 0,
      cache_hits: 0,
      cache_misses: 0,
      error_count: 0,
      average_analysis_time: 0,
      last_analysis_time: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:telemetry_event, event_name, measurements, metadata}, state) do
    updated_state = process_telemetry_event(event_name, measurements, metadata, state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      uptime_seconds: get_uptime_seconds(state.start_time),
      total_analyses: state.analysis_count,
      cache_hit_ratio: calculate_cache_hit_ratio(state.cache_hits, state.cache_misses),
      average_analysis_time_ms: state.average_analysis_time,
      error_rate: calculate_error_rate(state.error_count, state.analysis_count),
      last_analysis_at: state.last_analysis_time
    }

    {:reply, metrics, state}
  end

  @doc """
  Get current intelligence metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # Private functions

  defp attach_telemetry_handlers do
    # Attach to intelligence analysis events
    :telemetry.attach_many(
      "intelligence-telemetry",
      [
        [:eve_dmv, :intelligence, :analysis],
        [:eve_dmv, :intelligence, :cache_access],
        [:eve_dmv, :intelligence, :cache_miss],
        [:eve_dmv, :intelligence, :cache_invalidation]
      ],
      &handle_telemetry_event/4,
      %{}
    )

    Logger.debug("Attached intelligence telemetry handlers")
  end

  defp handle_telemetry_event(event_name, measurements, metadata, _config) do
    # Send to our GenServer for processing
    send(__MODULE__, {:telemetry_event, event_name, measurements, metadata})
  end

  defp process_telemetry_event(
         [:eve_dmv, :intelligence, :analysis],
         measurements,
         metadata,
         state
       ) do
    duration_ms = Map.get(measurements, :duration_ms, 0)

    new_average =
      calculate_moving_average(
        state.average_analysis_time,
        duration_ms,
        state.analysis_count + 1
      )

    updated_state = %{
      state
      | analysis_count: state.analysis_count + 1,
        average_analysis_time: new_average,
        last_analysis_time: DateTime.utc_now()
    }

    # Check for errors
    case Map.get(metadata, :error) do
      nil -> updated_state
      _error -> %{updated_state | error_count: state.error_count + 1}
    end
  end

  defp process_telemetry_event(
         [:eve_dmv, :intelligence, :cache_access],
         _measurements,
         metadata,
         state
       ) do
    case Map.get(metadata, :cache_status) do
      :hit -> %{state | cache_hits: state.cache_hits + 1}
      :computed -> %{state | cache_misses: state.cache_misses + 1}
      _ -> state
    end
  end

  defp process_telemetry_event(
         [:eve_dmv, :intelligence, :cache_miss],
         _measurements,
         _metadata,
         state
       ) do
    %{state | cache_misses: state.cache_misses + 1}
  end

  defp process_telemetry_event(_event_name, _measurements, _metadata, state) do
    # Ignore unknown events
    state
  end

  defp get_uptime_seconds(start_time) do
    System.convert_time_unit(System.monotonic_time() - start_time, :native, :second)
  end

  defp calculate_cache_hit_ratio(hits, misses) when hits + misses > 0 do
    hits / (hits + misses)
  end

  defp calculate_cache_hit_ratio(_, _), do: 0.0

  defp calculate_error_rate(errors, total) when total > 0 do
    errors / total
  end

  defp calculate_error_rate(_, _), do: 0.0

  defp calculate_moving_average(current_average, new_value, count) when count > 1 do
    (current_average * (count - 1) + new_value) / count
  end

  defp calculate_moving_average(_, new_value, _), do: new_value
end
