defmodule EveDmv.Monitoring.PipelineMonitor do
  @moduledoc """
  Monitoring and telemetry for the killmail processing pipeline.

  Tracks pipeline health, performance metrics, and error patterns
  to provide visibility into the data ingestion process.
  """

  use GenServer

  alias EveDmv.Error
  alias EveDmv.Monitoring.ErrorTracker

  require Logger

  @metrics_interval :timer.seconds(30)
  @health_check_interval :timer.minutes(5)

  defmodule PipelineMetrics do
    @moduledoc false
    defstruct [
      :messages_received,
      :messages_processed,
      :messages_failed,
      :batches_processed,
      :batches_failed,
      :processing_times,
      :batch_sizes,
      :errors_by_type,
      :last_reset,
      :last_success,
      :last_failure
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a message being received by the pipeline.
  """
  def record_message_received do
    GenServer.cast(__MODULE__, :message_received)
  end

  @doc """
  Record successful message processing.
  """
  def record_message_processed(processing_time_us) do
    GenServer.cast(__MODULE__, {:message_processed, processing_time_us})
  end

  @doc """
  Record failed message processing.
  """
  def record_message_failed(error) do
    GenServer.cast(__MODULE__, {:message_failed, error})
  end

  @doc """
  Record batch processing.
  """
  def record_batch_processed(batch_size, processing_time_us) do
    GenServer.cast(__MODULE__, {:batch_processed, batch_size, processing_time_us})
  end

  @doc """
  Record batch failure.
  """
  def record_batch_failed(batch_size, error) do
    GenServer.cast(__MODULE__, {:batch_failed, batch_size, error})
  end

  @doc """
  Get current pipeline metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get pipeline health status.
  """
  def get_health_status do
    GenServer.call(__MODULE__, :get_health_status)
  end

  @doc """
  Reset metrics (for testing).
  """
  def reset_metrics do
    GenServer.call(__MODULE__, :reset_metrics)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic metrics emission
    schedule_metrics_emission()
    schedule_health_check()

    # Attach telemetry handlers
    attach_telemetry_handlers()

    state = %{
      metrics: new_metrics(),
      start_time: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast(:message_received, state) do
    metrics = %{state.metrics | messages_received: state.metrics.messages_received + 1}
    {:noreply, %{state | metrics: metrics}}
  end

  @impl true
  def handle_cast({:message_processed, processing_time_us}, state) do
    metrics = state.metrics

    updated_metrics = %{
      metrics
      | messages_processed: metrics.messages_processed + 1,
        processing_times: [processing_time_us | metrics.processing_times],
        last_success: DateTime.utc_now()
    }

    # Keep only last 1000 processing times
    processing_times = Enum.take(updated_metrics.processing_times, 1000)
    final_metrics = %{updated_metrics | processing_times: processing_times}

    {:noreply, %{state | metrics: final_metrics}}
  end

  @impl true
  def handle_cast({:message_failed, error}, state) do
    error_type = extract_error_type(error)

    current_error_count = Map.get(state.metrics.errors_by_type, error_type, 0)
    updated_errors = Map.put(state.metrics.errors_by_type, error_type, current_error_count + 1)

    metrics = %{
      state.metrics
      | messages_failed: state.metrics.messages_failed + 1,
        errors_by_type: updated_errors,
        last_failure: DateTime.utc_now()
    }

    # Track error in error tracker
    ErrorTracker.track_error(error, %{
      module: __MODULE__,
      function: :pipeline_processing
    })

    {:noreply, %{state | metrics: metrics}}
  end

  @impl true
  def handle_cast({:batch_processed, batch_size, processing_time_us}, state) do
    updated_metrics = %{
      state.metrics
      | batches_processed: state.metrics.batches_processed + 1,
        batch_sizes: [batch_size | state.metrics.batch_sizes]
    }

    # Keep only last 100 batch sizes
    batch_sizes = Enum.take(updated_metrics.batch_sizes, 100)
    final_metrics = %{updated_metrics | batch_sizes: batch_sizes}

    # Emit telemetry
    :telemetry.execute(
      [:eve_dmv, :pipeline, :batch_completed],
      %{
        batch_size: batch_size,
        processing_time_ms: div(processing_time_us, 1000)
      },
      %{}
    )

    {:noreply, %{state | metrics: final_metrics}}
  end

  @impl true
  def handle_cast({:batch_failed, batch_size, error}, state) do
    error_type = extract_error_type(error)

    current_error_count = Map.get(state.metrics.errors_by_type, error_type, 0)
    updated_errors = Map.put(state.metrics.errors_by_type, error_type, current_error_count + 1)

    metrics = %{
      state.metrics
      | batches_failed: state.metrics.batches_failed + 1,
        errors_by_type: updated_errors
    }

    # Log batch failure
    Logger.error("Pipeline batch failed: size=#{batch_size}, error=#{inspect(error)}")

    # Emit alert telemetry
    :telemetry.execute(
      [:eve_dmv, :pipeline, :batch_failed],
      %{batch_size: batch_size},
      %{error_type: error_type}
    )

    {:noreply, %{state | metrics: metrics}}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics_summary = summarize_metrics(state.metrics)
    {:reply, metrics_summary, state}
  end

  @impl true
  def handle_call(:get_health_status, _from, state) do
    health = analyze_health(state)
    {:reply, health, state}
  end

  @impl true
  def handle_call(:reset_metrics, _from, state) do
    new_state = %{state | metrics: new_metrics()}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:emit_metrics, state) do
    emit_metrics(state.metrics)
    schedule_metrics_emission()
    {:noreply, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    health = analyze_health(state)

    if health.status != :healthy do
      Logger.warning("Pipeline health check: #{health.status} - #{inspect(health.issues)}")
    end

    schedule_health_check()
    {:noreply, state}
  end

  # Private functions

  defp new_metrics do
    %PipelineMetrics{
      messages_received: 0,
      messages_processed: 0,
      messages_failed: 0,
      batches_processed: 0,
      batches_failed: 0,
      processing_times: [],
      batch_sizes: [],
      errors_by_type: %{},
      last_reset: DateTime.utc_now(),
      last_success: nil,
      last_failure: nil
    }
  end

  defp extract_error_type(error) do
    case error do
      %Error{code: code} -> code
      {:error, %Error{code: code}} -> code
      {:error, reason} when is_atom(reason) -> reason
      _ -> :unknown_error
    end
  end

  defp summarize_metrics(metrics) do
    processing_time_stats = calculate_stats(metrics.processing_times)
    batch_size_stats = calculate_stats(metrics.batch_sizes)

    %{
      messages: %{
        received: metrics.messages_received,
        processed: metrics.messages_processed,
        failed: metrics.messages_failed,
        success_rate: calculate_success_rate(metrics.messages_processed, metrics.messages_failed)
      },
      batches: %{
        processed: metrics.batches_processed,
        failed: metrics.batches_failed,
        average_size: batch_size_stats.mean,
        success_rate: calculate_success_rate(metrics.batches_processed, metrics.batches_failed)
      },
      performance: %{
        avg_processing_time_ms: processing_time_stats.mean / 1000,
        p95_processing_time_ms: processing_time_stats.p95 / 1000,
        p99_processing_time_ms: processing_time_stats.p99 / 1000
      },
      errors: metrics.errors_by_type,
      last_success: metrics.last_success,
      last_failure: metrics.last_failure,
      uptime_minutes: DateTime.diff(DateTime.utc_now(), metrics.last_reset, :minute)
    }
  end

  defp calculate_stats([]), do: %{mean: 0.0, p95: 0.0, p99: 0.0}

  defp calculate_stats(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    # Calculate indices safely
    p95_index = max(0, min(count - 1, round(count * 0.95)))
    p99_index = max(0, min(count - 1, round(count * 0.99)))

    %{
      mean: Enum.sum(sorted) / count,
      p95: Enum.at(sorted, p95_index) || 0.0,
      p99: Enum.at(sorted, p99_index) || 0.0
    }
  end

  defp calculate_success_rate(_, 0), do: 100.0
  defp calculate_success_rate(0, _), do: 0.0

  defp calculate_success_rate(success, failed) do
    success / (success + failed) * 100
  end

  defp analyze_health(state) do
    metrics = state.metrics
    issues = []

    # Check message processing rate
    success_rate = calculate_success_rate(metrics.messages_processed, metrics.messages_failed)

    issues =
      if success_rate < 95.0 do
        ["Low success rate: #{Float.round(success_rate, 1)}%" | issues]
      else
        issues
      end

    # Check for recent failures
    issues =
      if metrics.last_failure &&
           DateTime.diff(DateTime.utc_now(), metrics.last_failure, :minute) < 5 do
        ["Recent failures detected" | issues]
      else
        issues
      end

    # Check for stalled pipeline
    issues =
      if metrics.last_success &&
           DateTime.diff(DateTime.utc_now(), metrics.last_success, :minute) > 10 do
        ["No successful processing in last 10 minutes" | issues]
      else
        issues
      end

    # Check error rates
    total_messages = metrics.messages_processed + metrics.messages_failed
    # 5% error rate threshold
    error_threshold = 0.05

    issues =
      Enum.reduce(metrics.errors_by_type, issues, fn {error_type, count}, acc ->
        error_rate = if total_messages > 0, do: count / total_messages, else: 0

        if error_rate > error_threshold do
          ["High #{error_type} error rate: #{Float.round(error_rate * 100, 1)}%" | acc]
        else
          acc
        end
      end)

    status =
      case length(issues) do
        0 -> :healthy
        n when n <= 2 -> :degraded
        _ -> :unhealthy
      end

    %{
      status: status,
      issues: issues,
      last_check: DateTime.utc_now()
    }
  end

  defp emit_metrics(metrics) do
    summary = summarize_metrics(metrics)

    # Emit telemetry events
    :telemetry.execute(
      [:eve_dmv, :pipeline, :metrics],
      %{
        messages_processed: metrics.messages_processed,
        messages_failed: metrics.messages_failed,
        batches_processed: metrics.batches_processed,
        batches_failed: metrics.batches_failed
      },
      summary
    )

    # Log summary if there are issues
    if metrics.messages_failed > 0 or metrics.batches_failed > 0 do
      Logger.info("Pipeline metrics: #{inspect(summary)}")
    end
  end

  defp schedule_metrics_emission do
    Process.send_after(self(), :emit_metrics, @metrics_interval)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  defp attach_telemetry_handlers do
    events = [
      [:eve_dmv, :killmail, :processed],
      [:eve_dmv, :killmail, :failed],
      [:eve_dmv, :killmail, :batch_size]
    ]

    :telemetry.attach_many(
      "pipeline-monitor-handlers",
      events,
      &__MODULE__.handle_pipeline_telemetry/4,
      nil
    )
  end

  @doc false
  def handle_pipeline_telemetry(
        [:eve_dmv, :killmail, :processed],
        _measurements,
        _metadata,
        _config
      ) do
    # Processing time tracked separately
    record_message_processed(0)
  end

  def handle_pipeline_telemetry([:eve_dmv, :killmail, :failed], _measurements, metadata, _config) do
    error = metadata[:error] || :unknown_error
    record_message_failed(error)
  end

  def handle_pipeline_telemetry(
        [:eve_dmv, :killmail, :batch_size],
        measurements,
        _metadata,
        _config
      ) do
    batch_size = measurements[:size] || 0
    record_batch_processed(batch_size, 0)
  end
end
