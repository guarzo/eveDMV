defmodule EveDmv.Contexts.Surveillance.Domain.AlertBatcher do
  @moduledoc """
  Batches surveillance alerts before broadcasting to reduce PubSub message frequency.

  ## Performance Optimization

  During high-activity periods (100+ kills/min), individual alert broadcasts can
  overwhelm LiveView processes with handle_info callbacks. This GenServer batches
  alerts over a configurable interval before broadcasting them together.

  ## Migration Note

  As of January 2026, backward compatibility mode is disabled by default. All subscribers
  must now handle `{:alerts_batch, payload}` messages instead of individual
  `{:surveillance_alert, alert}` messages. If you need to temporarily re-enable
  backward compatibility during migration, set:

      config :eve_dmv, alert_batcher: [backward_compat: true]

  ## Configuration

  - `batch_interval` - Time in milliseconds between batch flushes (default: 5000ms)
  - `backward_compat` - When true, broadcasts individual alerts in addition to batches
    for backward compatibility with existing subscribers (default: false).
    Set to true via `config :eve_dmv, alert_batcher: [backward_compat: true]`
    only if subscribers still need individual `{:surveillance_alert, alert}` messages.
  - Alerts are queued and broadcast together, reducing individual PubSub messages

  ## Usage

      # Queue an alert for batched delivery
      AlertBatcher.queue_alert(alert)

      # Or queue with metrics update
      AlertBatcher.queue_alert_with_metrics(alert, metrics_update)

  ## PubSub Topics

  Broadcasts to:
  - `"surveillance:alerts"` with `{:alerts_batch, alerts}` message

  ## Metrics Naming Convention

  When batching metrics updates, the merge behavior depends on the metric name:

  - **Counter metrics**: Metrics with names starting with `count_` or ending with `_count`
    are treated as counters and their values are **summed** during batching.
    Examples: `count_kills`, `alert_count`, `match_count`

  - **Gauge metrics**: All other metrics are treated as gauges and only the **latest value**
    is kept during batching.
    Examples: `last_seen_timestamp`, `current_threat_level`, `active_profiles`

  This convention ensures that counter values accumulate correctly across batch intervals
  while point-in-time values reflect the most recent state.
  """

  use GenServer

  alias EveDmv.Contexts.Surveillance.Domain.MetricsUtils
  alias EveDmv.Telemetry.OtelSpans

  require Logger

  @pubsub EveDmv.PubSub
  @default_batch_interval 5_000
  # Backward compatibility mode broadcasts individual alerts in addition to batches.
  # Enable only during migration if subscribers still need individual alerts.
  @backward_compat_enabled Application.compile_env(
                             :eve_dmv,
                             [:alert_batcher, :backward_compat],
                             false
                           )

  # Public API

  @doc """
  Start the AlertBatcher GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue an alert for batched delivery.

  The alert will be included in the next batch broadcast.
  """
  @spec queue_alert(map()) :: :ok
  def queue_alert(alert) do
    GenServer.cast(__MODULE__, {:queue_alert, alert})
  end

  @doc """
  Queue an alert with associated metrics update.

  Both the alert and metrics will be included in the batch.
  """
  @spec queue_alert_with_metrics(map(), map()) :: :ok
  def queue_alert_with_metrics(alert, metrics_update) do
    GenServer.cast(__MODULE__, {:queue_alert_with_metrics, alert, metrics_update})
  end

  @doc """
  Queue a metrics-only update for batching.

  Use this when only metrics need updating without a new alert.
  """
  @spec queue_metrics_update(map()) :: :ok
  def queue_metrics_update(metrics_update) do
    GenServer.cast(__MODULE__, {:queue_metrics_update, metrics_update})
  end

  @doc """
  Force an immediate flush of all queued alerts.

  Useful for testing or when immediate delivery is required.
  """
  @spec flush() :: :ok
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Get the current queue size.

  Returns the number of alerts waiting to be broadcast.
  """
  @spec queue_size() :: non_neg_integer()
  def queue_size do
    GenServer.call(__MODULE__, :queue_size)
  end

  @doc """
  Get current batch interval configuration.
  """
  @spec batch_interval() :: pos_integer()
  def batch_interval do
    GenServer.call(__MODULE__, :batch_interval)
  end

  @doc """
  Update the batch interval dynamically.

  Useful for adjusting to traffic patterns.
  """
  @spec set_batch_interval(pos_integer()) :: :ok
  def set_batch_interval(interval_ms) when is_integer(interval_ms) and interval_ms > 0 do
    GenServer.call(__MODULE__, {:set_batch_interval, interval_ms})
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    batch_interval = Keyword.get(opts, :batch_interval, @default_batch_interval)

    state = %{
      alerts: [],
      metrics_updates: %{},
      batch_interval: batch_interval,
      flush_timer: nil,
      stats: %{
        total_queued: 0,
        total_batches: 0,
        avg_batch_size: 0.0
      }
    }

    # Schedule first flush
    scheduled_state = schedule_flush(state)

    # Emit telemetry event for initialization
    :telemetry.execute(
      [:eve_dmv, :alert_batcher, :init],
      %{system_time: System.system_time()},
      %{batch_interval: batch_interval, queue_depth: 0}
    )

    Logger.info("AlertBatcher started with #{batch_interval}ms batch interval")
    {:ok, scheduled_state}
  end

  @impl GenServer
  def handle_cast({:queue_alert, alert}, state) do
    new_state =
      state
      |> Map.update!(:alerts, fn alerts -> [alert | alerts] end)
      |> Map.update!(:stats, fn stats ->
        %{stats | total_queued: stats.total_queued + 1}
      end)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:queue_alert_with_metrics, alert, metrics_update}, state) do
    new_state =
      state
      |> Map.update!(:alerts, fn alerts -> [alert | alerts] end)
      |> Map.update!(:metrics_updates, fn updates ->
        MetricsUtils.merge_metrics_update(updates, metrics_update)
      end)
      |> Map.update!(:stats, fn stats ->
        %{stats | total_queued: stats.total_queued + 1}
      end)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:queue_metrics_update, metrics_update}, state) do
    new_state =
      state
      |> Map.update!(:metrics_updates, fn updates ->
        MetricsUtils.merge_metrics_update(updates, metrics_update)
      end)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:flush, _from, state) do
    new_state = do_flush(state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:queue_size, _from, state) do
    {:reply, length(state.alerts), state}
  end

  @impl GenServer
  def handle_call(:batch_interval, _from, state) do
    {:reply, state.batch_interval, state}
  end

  @impl GenServer
  def handle_call({:set_batch_interval, interval_ms}, _from, state) do
    # Cancel existing timer and schedule new one
    if state.flush_timer, do: Process.cancel_timer(state.flush_timer)

    new_state =
      state
      |> Map.put(:batch_interval, interval_ms)
      |> schedule_flush()

    Logger.info("AlertBatcher batch interval updated to #{interval_ms}ms")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:flush, state) do
    new_state =
      state
      |> do_flush()
      |> schedule_flush()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp do_flush(%{alerts: []} = state) do
    batch_timestamp = DateTime.utc_now()

    span =
      OtelSpans.start_task_span("AlertBatcher.flush", %{
        batch_size: 0,
        batch_timestamp: DateTime.to_iso8601(batch_timestamp),
        metrics_only: map_size(state.metrics_updates) > 0
      })

    start_time = System.monotonic_time()

    # Nothing to flush, but still send metrics if any
    result =
      if map_size(state.metrics_updates) > 0 do
        case broadcast_metrics_only(state.metrics_updates) do
          :ok ->
            OtelSpans.add_span_attributes(span, %{
              broadcast_result: :ok,
              metrics_count: map_size(state.metrics_updates)
            })

          {:error, reason} ->
            OtelSpans.add_span_attributes(span, %{
              broadcast_result: :error,
              error_reason: inspect(reason)
            })
        end

        %{state | metrics_updates: %{}}
      else
        OtelSpans.add_span_attributes(span, %{
          broadcast_result: :skipped,
          reason: :empty_batch
        })

        state
      end

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:eve_dmv, :alert_batcher, :flush],
      %{
        duration: duration,
        batch_size: 0,
        alert_count: 0,
        metrics_only: map_size(state.metrics_updates) > 0
      },
      %{batch_interval: state.batch_interval}
    )

    OtelSpans.end_task_span(span, %{duration_native: duration})

    result
  end

  defp do_flush(state) do
    alert_count = length(state.alerts)
    batch_timestamp = DateTime.utc_now()

    span =
      OtelSpans.start_task_span("AlertBatcher.flush", %{
        batch_size: alert_count,
        batch_timestamp: DateTime.to_iso8601(batch_timestamp),
        metrics_only: false
      })

    start_time = System.monotonic_time()

    result =
      if alert_count > 0 do
        # Reverse to maintain chronological order
        alerts = Enum.reverse(state.alerts)

        # Build batch payload
        batch_payload = %{
          alerts: alerts,
          metrics: state.metrics_updates,
          batch_size: alert_count,
          batch_timestamp: batch_timestamp
        }

        # Broadcast batched alerts
        batch_broadcast_result =
          case Phoenix.PubSub.broadcast(
                 @pubsub,
                 "surveillance:alerts",
                 {:alerts_batch, batch_payload}
               ) do
            :ok ->
              OtelSpans.add_span_attributes(span, %{
                batch_broadcast_result: :ok
              })

              :ok

            {:error, reason} ->
              Logger.error(
                "#{__MODULE__}.do_flush/1: Failed to broadcast to topic \"surveillance:alerts\", reason: #{inspect(reason)}"
              )

              OtelSpans.add_span_attributes(span, %{
                batch_broadcast_result: :error,
                batch_broadcast_error: inspect(reason)
              })

              {:error, reason}
          end

        # Backward compatibility - can be disabled via config once all subscribers
        # are updated to handle {:alerts_batch, payload} messages
        compat_errors = broadcast_individual_alerts_if_enabled(alerts)

        OtelSpans.add_span_attributes(span, %{
          backward_compat_enabled: @backward_compat_enabled,
          backward_compat_errors_count: length(compat_errors)
        })

        # Update stats
        new_stats = update_stats(state.stats, alert_count)

        Logger.debug("AlertBatcher flushed batch of #{alert_count} alerts")

        # Record overall result
        case {batch_broadcast_result, compat_errors} do
          {:ok, []} ->
            OtelSpans.add_span_attributes(span, %{overall_result: :success})

          {:ok, _errors} ->
            OtelSpans.add_span_attributes(span, %{overall_result: :partial_success})

          {{:error, _}, _} ->
            OtelSpans.add_span_attributes(span, %{overall_result: :error})
        end

        %{state | alerts: [], metrics_updates: %{}, stats: new_stats}
      else
        OtelSpans.add_span_attributes(span, %{
          broadcast_result: :skipped,
          reason: :empty_batch
        })

        state
      end

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:eve_dmv, :alert_batcher, :flush],
      %{
        duration: duration,
        batch_size: alert_count,
        alert_count: alert_count,
        metrics_only: false
      },
      %{batch_interval: state.batch_interval}
    )

    OtelSpans.end_task_span(span, %{duration_native: duration})

    result
  end

  defp broadcast_individual_alerts_if_enabled(alerts) do
    if @backward_compat_enabled do
      alerts
      |> Enum.map(&broadcast_individual_alert/1)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  defp broadcast_individual_alert(alert) do
    case Phoenix.PubSub.broadcast(
           @pubsub,
           "surveillance:alerts",
           {:surveillance_alert, alert}
         ) do
      :ok ->
        nil

      {:error, reason} ->
        Logger.error(
          "#{__MODULE__}.do_flush/1: Failed to broadcast individual alert to topic \"surveillance:alerts\", reason: #{inspect(reason)}"
        )

        reason
    end
  end

  defp broadcast_metrics_only(metrics_updates) do
    case Phoenix.PubSub.broadcast(
           @pubsub,
           "surveillance:alerts",
           {:metrics_update, metrics_updates}
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(
          "#{__MODULE__}.broadcast_metrics_only/1: Failed to broadcast to topic \"surveillance:alerts\", reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp schedule_flush(state) do
    timer = Process.send_after(self(), :flush, state.batch_interval)
    %{state | flush_timer: timer}
  end

  defp update_stats(stats, batch_size) do
    total_batches = stats.total_batches + 1
    # Running average
    avg_batch_size =
      (stats.avg_batch_size * stats.total_batches + batch_size) / total_batches

    %{stats | total_batches: total_batches, avg_batch_size: avg_batch_size}
  end
end
