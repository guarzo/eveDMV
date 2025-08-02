defmodule EveDmv.Telemetry.OtelSpans do
  @moduledoc """
  OpenTelemetry span wrapper for EVE DMV telemetry events.

  This module provides a lightweight OpenTelemetry integration that works alongside
  the existing :telemetry.execute() calls to provide distributed tracing.

  When full OpenTelemetry dependencies are added to the project, this module will
  automatically use them. Until then, it provides a no-op implementation that
  maintains the same API.
  """

  require Logger

  @doc """
  Start an OpenTelemetry span for a task execution.
  """
  def start_task_span(task_name, metadata \\ %{}) do
    span_name = "task.#{task_name}"

    case opentelemetry_available?() do
      true ->
        # Full OpenTelemetry implementation when available
        start_otel_span(span_name, metadata)

      false ->
        # Lightweight span simulation using process dictionary
        start_simple_span(span_name, metadata)
    end
  end

  @doc """
  End an OpenTelemetry span with success status.
  """
  def end_task_span(span, measurements \\ %{}) do
    case opentelemetry_available?() do
      true ->
        end_otel_span(span, :ok, measurements)

      false ->
        end_simple_span(span, :ok, measurements)
    end
  end

  @doc """
  End an OpenTelemetry span with error status.
  """
  def end_task_span_with_error(span, error, measurements \\ %{}) do
    case opentelemetry_available?() do
      true ->
        end_otel_span(span, {:error, error}, measurements)

      false ->
        end_simple_span(span, {:error, error}, measurements)
    end
  end

  @doc """
  Wrap a function with OpenTelemetry span.
  """
  def with_span(span_name, metadata \\ %{}, fun) when is_function(fun, 0) do
    span = start_task_span(span_name, metadata)
    start_time = System.monotonic_time(:microsecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:microsecond) - start_time
      end_task_span(span, %{duration: duration})
      result
    rescue
      error ->
        duration = System.monotonic_time(:microsecond) - start_time
        end_task_span_with_error(span, error, %{duration: duration})
        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Add attributes to the current span.
  """
  def add_span_attributes(span, attributes) do
    case opentelemetry_available?() do
      true ->
        add_otel_attributes(span, attributes)

      false ->
        add_simple_attributes(span, attributes)
    end
  end

  @doc """
  Record an event in the current span.
  """
  def add_span_event(span, event_name, attributes \\ %{}) do
    case opentelemetry_available?() do
      true ->
        add_otel_event(span, event_name, attributes)

      false ->
        add_simple_event(span, event_name, attributes)
    end
  end

  # Private functions

  defp opentelemetry_available? do
    # Check if OpenTelemetry modules are available
    Code.ensure_loaded?(:opentelemetry) and
      Code.ensure_loaded?(:opentelemetry_api)
  end

  # Full OpenTelemetry implementation (when dependencies are available)

  defp start_otel_span(span_name, metadata) do
    if Code.ensure_loaded?(:opentelemetry) do
      try do
        # This will work when OpenTelemetry is properly configured
        span = apply(:opentelemetry, :start_span, [span_name, %{kind: :internal}])
        apply(:opentelemetry, :set_current_span, [span])

        if map_size(metadata) > 0 do
          apply(:opentelemetry, :set_attributes, [span, metadata])
        end

        span
      rescue
        _ ->
          Logger.debug("OpenTelemetry not fully configured, using simple span")
          start_simple_span(span_name, metadata)
      end
    else
      Logger.debug("OpenTelemetry not available, using simple span")
      start_simple_span(span_name, metadata)
    end
  end

  defp end_otel_span(span, status, measurements) do
    if Code.ensure_loaded?(:opentelemetry) do
      try do
        case status do
          :ok ->
            apply(:opentelemetry, :set_span_status, [span, :ok])

          {:error, error} ->
            apply(:opentelemetry, :set_span_status, [span, :error, inspect(error)])
        end

        if map_size(measurements) > 0 do
          apply(:opentelemetry, :set_attributes, [span, measurements])
        end

        apply(:opentelemetry, :end_span, [span])
      rescue
        _ ->
          end_simple_span(span, status, measurements)
      end
    else
      end_simple_span(span, status, measurements)
    end
  end

  defp add_otel_attributes(span, attributes) do
    if Code.ensure_loaded?(:opentelemetry) do
      try do
        apply(:opentelemetry, :set_attributes, [span, attributes])
      rescue
        _ ->
          add_simple_attributes(span, attributes)
      end
    else
      add_simple_attributes(span, attributes)
    end
  end

  defp add_otel_event(span, event_name, attributes) do
    if Code.ensure_loaded?(:opentelemetry) do
      try do
        apply(:opentelemetry, :add_event, [span, event_name, attributes])
      rescue
        _ ->
          add_simple_event(span, event_name, attributes)
      end
    else
      add_simple_event(span, event_name, attributes)
    end
  end

  # Simple span implementation (fallback when OpenTelemetry is not available)

  defp start_simple_span(span_name, metadata) do
    span_id = make_ref()
    start_time = System.monotonic_time(:microsecond)

    span_data = %{
      span_id: span_id,
      span_name: span_name,
      start_time: start_time,
      metadata: metadata,
      attributes: %{},
      events: []
    }

    # Store in process dictionary for this process
    Process.put({:otel_span, span_id}, span_data)

    Logger.debug("Started span: #{span_name}", span_data)
    span_id
  end

  defp end_simple_span(span_id, status, measurements) do
    case Process.get({:otel_span, span_id}) do
      nil ->
        Logger.warning("Attempted to end unknown span: #{inspect(span_id)}")

      span_data ->
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - span_data.start_time

        final_data = %{
          span_data
          | end_time: end_time,
            duration: duration,
            status: status,
            measurements: measurements
        }

        # Emit telemetry event for observability tools
        :telemetry.execute(
          [:eve_dmv, :otel, :span, :completed],
          %{duration: duration},
          final_data
        )

        Logger.debug("Completed span: #{span_data.span_name}", final_data)
        Process.delete({:otel_span, span_id})
    end
  end

  defp add_simple_attributes(span_id, attributes) do
    case Process.get({:otel_span, span_id}) do
      nil ->
        Logger.warning("Attempted to add attributes to unknown span: #{inspect(span_id)}")

      span_data ->
        updated_data = %{
          span_data
          | attributes: Map.merge(span_data.attributes, attributes)
        }

        Process.put({:otel_span, span_id}, updated_data)
    end
  end

  defp add_simple_event(span_id, event_name, attributes) do
    case Process.get({:otel_span, span_id}) do
      nil ->
        Logger.warning("Attempted to add event to unknown span: #{inspect(span_id)}")

      span_data ->
        event = %{
          name: event_name,
          attributes: attributes,
          timestamp: System.monotonic_time(:microsecond)
        }

        updated_data = %{
          span_data
          | events: [event | span_data.events]
        }

        Process.put({:otel_span, span_id}, updated_data)
    end
  end
end
