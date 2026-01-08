defmodule EveDmv.Contexts.Surveillance.Domain.AlertBatcher do
  @moduledoc """
  Batches surveillance alerts before broadcasting to reduce PubSub message frequency.

  ## Performance Optimization

  During high-activity periods (100+ kills/min), individual alert broadcasts can
  overwhelm LiveView processes with handle_info callbacks. This GenServer batches
  alerts over a configurable interval before broadcasting them together.

  ## Configuration

  - `batch_interval` - Time in milliseconds between batch flushes (default: 5000ms)
  - Alerts are queued and broadcast together, reducing individual PubSub messages

  ## Usage

      # Queue an alert for batched delivery
      AlertBatcher.queue_alert(alert)

      # Or queue with metrics update
      AlertBatcher.queue_alert_with_metrics(alert, metrics_update)

  ## PubSub Topics

  Broadcasts to:
  - `"surveillance:alerts"` with `{:alerts_batch, alerts}` message
  """

  use GenServer

  require Logger

  @pubsub EveDmv.PubSub
  @default_batch_interval 5_000

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
        merge_metrics_update(updates, metrics_update)
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
        merge_metrics_update(updates, metrics_update)
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
    # Nothing to flush, but still send metrics if any
    if map_size(state.metrics_updates) > 0 do
      broadcast_metrics_only(state.metrics_updates)
      %{state | metrics_updates: %{}}
    else
      state
    end
  end

  defp do_flush(state) do
    alert_count = length(state.alerts)

    if alert_count > 0 do
      # Reverse to maintain chronological order
      alerts = Enum.reverse(state.alerts)

      # Build batch payload
      batch_payload = %{
        alerts: alerts,
        metrics: state.metrics_updates,
        batch_size: alert_count,
        batch_timestamp: DateTime.utc_now()
      }

      # Broadcast batched alerts
      Phoenix.PubSub.broadcast(
        @pubsub,
        "surveillance:alerts",
        {:alerts_batch, batch_payload}
      )

      # Also broadcast individual alerts for backwards compatibility
      # This allows existing subscribers to work without modification
      for alert <- alerts do
        Phoenix.PubSub.broadcast(
          @pubsub,
          "surveillance:alerts",
          {:surveillance_alert, alert}
        )
      end

      # Update stats
      new_stats = update_stats(state.stats, alert_count)

      Logger.debug("AlertBatcher flushed batch of #{alert_count} alerts")

      %{state | alerts: [], metrics_updates: %{}, stats: new_stats}
    else
      state
    end
  end

  defp broadcast_metrics_only(metrics_updates) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      "surveillance:alerts",
      {:metrics_update, metrics_updates}
    )
  end

  defp schedule_flush(state) do
    timer = Process.send_after(self(), :flush, state.batch_interval)
    %{state | flush_timer: timer}
  end

  defp merge_metrics_update(existing, new_update) do
    # Merge metrics updates intelligently
    # For counters, sum them; for gauges, take latest
    Map.merge(existing, new_update, fn _key, v1, v2 ->
      if is_number(v1) and is_number(v2), do: v1 + v2, else: v2
    end)
  end

  defp update_stats(stats, batch_size) do
    total_batches = stats.total_batches + 1
    # Running average
    avg_batch_size =
      (stats.avg_batch_size * stats.total_batches + batch_size) / total_batches

    %{stats | total_batches: total_batches, avg_batch_size: avg_batch_size}
  end
end
