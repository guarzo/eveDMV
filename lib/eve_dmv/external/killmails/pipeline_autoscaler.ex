defmodule EveDmv.Killmails.PipelineAutoscaler do
  @moduledoc """
  Monitors pipeline load and recommends concurrency adjustments.

  Since Broadway doesn't support dynamic concurrency changes at runtime,
  this module:
  1. Monitors pipeline utilization metrics
  2. Logs scaling recommendations
  3. Tracks recommended concurrency for next restart
  4. Emits telemetry for observability

  Configuration for next restart can be retrieved via `get_recommended_config/0`.
  """

  use GenServer

  alias EveDmv.Monitoring.PipelineMonitor

  require Logger

  @check_interval 30_000
  @scale_up_threshold 0.8
  @scale_down_threshold 0.3
  @min_concurrency 4
  @max_concurrency 16
  @default_concurrency 8
  @batch_timeout_ms 30_000

  defmodule State do
    @moduledoc false

    defstruct [
      :current_concurrency,
      :recommended_concurrency,
      :last_check,
      :utilization_history,
      :scale_events
    ]

    @typedoc "A utilization measurement entry"
    @type utilization_entry :: %{
            timestamp: DateTime.t(),
            utilization: float(),
            messages_processed: non_neg_integer(),
            batches_processed: non_neg_integer(),
            avg_processing_time_ms: float()
          }

    @typedoc "A scaling event record"
    @type scale_event :: %{
            timestamp: DateTime.t(),
            from: non_neg_integer(),
            to: non_neg_integer(),
            utilization: float(),
            direction: :up | :down
          }

    @type t :: %__MODULE__{
            current_concurrency: non_neg_integer(),
            recommended_concurrency: non_neg_integer(),
            last_check: DateTime.t() | nil,
            utilization_history: [utilization_entry()],
            scale_events: [scale_event()]
          }
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current scaling state and recommendations.
  """
  @spec get_scaling_status() :: map()
  def get_scaling_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Get recommended configuration for next pipeline restart.
  """
  @spec get_recommended_config() :: map()
  def get_recommended_config do
    GenServer.call(__MODULE__, :get_recommended_config)
  end

  @doc """
  Get utilization history for trend analysis.
  """
  @spec get_utilization_history() :: list()
  def get_utilization_history do
    GenServer.call(__MODULE__, :get_utilization_history)
  end

  @doc """
  Force a scaling check (useful for testing).
  """
  @spec force_check() :: :ok
  def force_check do
    GenServer.cast(__MODULE__, :force_check)
  end

  # Server callbacks

  @impl GenServer
  def init(_opts) do
    schedule_check()

    state = %State{
      current_concurrency: get_configured_concurrency(),
      recommended_concurrency: get_configured_concurrency(),
      last_check: nil,
      utilization_history: [],
      scale_events: []
    }

    Logger.info("Pipeline autoscaler started with concurrency: #{state.current_concurrency}")

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      current_concurrency: state.current_concurrency,
      recommended_concurrency: state.recommended_concurrency,
      last_check: state.last_check,
      needs_restart: state.recommended_concurrency != state.current_concurrency,
      recent_utilization: Enum.take(state.utilization_history, 10),
      scale_events: Enum.take(state.scale_events, 5)
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:get_recommended_config, _from, state) do
    config = %{
      pipeline_concurrency: state.recommended_concurrency,
      batcher_concurrency: max(@min_concurrency, div(state.recommended_concurrency, 2)),
      batch_size: calculate_optimal_batch_size(state),
      batch_timeout: @batch_timeout_ms
    }

    {:reply, config, state}
  end

  @impl GenServer
  def handle_call(:get_utilization_history, _from, state) do
    {:reply, state.utilization_history, state}
  end

  @impl GenServer
  def handle_cast(:force_check, state) do
    new_state = perform_scaling_check(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:check_scaling, state) do
    new_state = perform_scaling_check(state)
    schedule_check()
    {:noreply, new_state}
  end

  # Private functions

  defp fetch_metrics_safely do
    PipelineMonitor.get_metrics()
  catch
    :exit, reason ->
      Logger.warning(
        "PipelineAutoscaler: Failed to fetch metrics from PipelineMonitor, " <>
          "using defaults. Reason: #{inspect(reason)}"
      )

      default_metrics()
  end

  defp default_metrics do
    %{
      messages: %{received: 0, processed: 0, failed: 0, success_rate: 100.0},
      batches: %{processed: 0, failed: 0, average_size: 0.0, success_rate: 100.0},
      performance: %{
        avg_processing_time_ms: 0.0,
        p95_processing_time_ms: 0.0,
        p99_processing_time_ms: 0.0
      },
      errors: %{},
      last_success: nil,
      last_failure: nil,
      uptime_minutes: 0
    }
  end

  defp perform_scaling_check(state) do
    metrics = fetch_metrics_safely()
    utilization = calculate_utilization(metrics)
    now = DateTime.utc_now()

    new_recommended =
      cond do
        utilization > @scale_up_threshold and state.recommended_concurrency < @max_concurrency ->
          new_conc = min(state.recommended_concurrency + 2, @max_concurrency)
          log_scaling_recommendation(:up, state.recommended_concurrency, new_conc, utilization)
          new_conc

        utilization < @scale_down_threshold and state.recommended_concurrency > @min_concurrency ->
          new_conc = max(state.recommended_concurrency - 2, @min_concurrency)
          log_scaling_recommendation(:down, state.recommended_concurrency, new_conc, utilization)
          new_conc

        true ->
          state.recommended_concurrency
      end

    # Track utilization history (keep last 100 entries)
    utilization_entry = %{
      timestamp: now,
      utilization: utilization,
      messages_processed: metrics.messages.processed,
      batches_processed: metrics.batches.processed,
      avg_processing_time_ms: metrics.performance.avg_processing_time_ms
    }

    utilization_history =
      [utilization_entry | state.utilization_history]
      |> Enum.take(100)

    # Track scale events if recommendation changed
    scale_events =
      if new_recommended != state.recommended_concurrency do
        event = %{
          timestamp: now,
          from: state.recommended_concurrency,
          to: new_recommended,
          utilization: utilization,
          direction: if(new_recommended > state.recommended_concurrency, do: :up, else: :down)
        }

        [event | state.scale_events] |> Enum.take(20)
      else
        state.scale_events
      end

    # Emit telemetry
    emit_scaling_telemetry(utilization, state.current_concurrency, new_recommended)

    %{
      state
      | recommended_concurrency: new_recommended,
        last_check: now,
        utilization_history: utilization_history,
        scale_events: scale_events
    }
  end

  defp calculate_utilization(metrics) do
    # Calculate utilization based on batch processing time vs batch timeout
    # Higher ratio = higher utilization = need more capacity

    # Safely extract avg_batch_time_ms, returning 0.0 if nil or non-positive
    avg_batch_time_ms =
      case metrics do
        %{performance: %{avg_processing_time_ms: time}} when is_number(time) and time > 0 ->
          time

        _ ->
          nil
      end

    if is_nil(avg_batch_time_ms) do
      0.0
    else
      # Utilization = actual processing time / available time window
      utilization = avg_batch_time_ms / @batch_timeout_ms

      # Safely extract success_rate, defaulting to 100 if nil/missing
      raw_success_rate =
        case metrics do
          %{batches: %{success_rate: rate}} when is_number(rate) -> rate
          _ -> 100
        end

      # Convert to float ratio and clamp to prevent division by zero
      success_rate_ratio = max(raw_success_rate / 100, 0.5)

      # Also factor in success rate - lower success rate indicates stress
      adjusted_utilization = utilization / success_rate_ratio

      # Clamp to reasonable range
      min(adjusted_utilization, 1.0)
    end
  end

  defp calculate_optimal_batch_size(state) do
    # Based on utilization trends, recommend batch size
    recent_utilization =
      state.utilization_history
      |> Enum.take(10)
      |> Enum.map(& &1.utilization)

    avg_utilization =
      if Enum.empty?(recent_utilization) do
        0.5
      else
        Enum.sum(recent_utilization) / length(recent_utilization)
      end

    cond do
      # High utilization - smaller batches for faster processing
      avg_utilization > 0.7 -> 100
      # Low utilization - larger batches for efficiency
      avg_utilization < 0.3 -> 300
      # Normal - standard batch size
      true -> 200
    end
  end

  defp log_scaling_recommendation(direction, from, to, utilization) do
    direction_str = if direction == :up, do: "UP", else: "DOWN"
    utilization_pct = Float.round(utilization * 100, 1)

    Logger.info(
      "Pipeline autoscaler: SCALE #{direction_str} recommended " <>
        "(#{from} -> #{to} processors) at #{utilization_pct}% utilization. " <>
        "Restart pipeline to apply."
    )
  end

  defp emit_scaling_telemetry(utilization, current, recommended) do
    :telemetry.execute(
      [:eve_dmv, :pipeline, :autoscaler],
      %{
        utilization: utilization,
        current_concurrency: current,
        recommended_concurrency: recommended
      },
      %{
        needs_adjustment: current != recommended
      }
    )
  end

  defp schedule_check do
    Process.send_after(self(), :check_scaling, @check_interval)
  end

  defp get_configured_concurrency do
    Application.get_env(:eve_dmv, :pipeline_concurrency, @default_concurrency)
  end
end
