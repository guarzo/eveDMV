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

  All numeric thresholds and limits are defined in `PipelineAutoscalerConfig`.
  """

  use GenServer

  alias EveDmv.Killmails.PipelineAutoscalerConfig, as: Config
  alias EveDmv.Monitoring.PipelineMonitor

  require Logger

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
            current_concurrency: non_neg_integer() | nil,
            recommended_concurrency: non_neg_integer() | nil,
            last_check: DateTime.t() | nil,
            utilization_history: [float()],
            scale_events: list(any())
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
      batcher_concurrency: max(Config.min_concurrency(), div(state.recommended_concurrency, 2)),
      batch_size: calculate_optimal_batch_size(state),
      batch_timeout: Config.batch_timeout_ms()
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
        utilization > Config.scale_up_threshold() and
            state.recommended_concurrency < Config.max_concurrency() ->
          new_conc = min(state.recommended_concurrency + 2, Config.max_concurrency())
          log_scaling_recommendation(:up, state.recommended_concurrency, new_conc, utilization)
          new_conc

        utilization < Config.scale_down_threshold() and
            state.recommended_concurrency > Config.min_concurrency() ->
          new_conc = max(state.recommended_concurrency - 2, Config.min_concurrency())
          log_scaling_recommendation(:down, state.recommended_concurrency, new_conc, utilization)
          new_conc

        true ->
          state.recommended_concurrency
      end

    # Track utilization history (keep last 100 entries)
    utilization_entry = %{
      timestamp: now,
      utilization: utilization,
      messages_processed: get_messages_processed(metrics),
      batches_processed: get_batches_processed(metrics),
      avg_processing_time_ms: get_avg_batch_time_ms(metrics)
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

    # Defensively extract avg_batch_time_ms from metrics.performance.avg_processing_time_ms
    # Returns 0.0 if metrics is nil, performance is nil/missing, or value is nil/non-positive
    avg_batch_time_ms = get_avg_batch_time_ms(metrics)

    if avg_batch_time_ms == 0.0 do
      0.0
    else
      # Utilization = actual processing time / available time window
      utilization = avg_batch_time_ms / Config.batch_timeout_ms()

      # Defensively extract success_rate from metrics.batches.success_rate
      # Returns safe default of 100 if nil/missing, then clamps to prevent division by zero
      success_rate = get_success_rate(metrics)

      # Convert to float ratio and ensure we never divide by zero using max(..., 0.5)
      success_rate_ratio = max(success_rate / 100, 0.5)

      # Also factor in success rate - lower success rate indicates stress
      adjusted_utilization = utilization / success_rate_ratio

      # Clamp to reasonable range
      min(adjusted_utilization, 1.0)
    end
  end

  # Safely extract avg_processing_time_ms from nested metrics structure
  # Returns 0.0 if metrics is nil, performance is nil/missing, or value is nil/non-positive
  defp get_avg_batch_time_ms(nil), do: 0.0

  defp get_avg_batch_time_ms(%{performance: nil}), do: 0.0

  defp get_avg_batch_time_ms(%{performance: performance}) when is_map(performance) do
    case Map.get(performance, :avg_processing_time_ms) do
      time when is_number(time) and time > 0 -> time
      _ -> 0.0
    end
  end

  defp get_avg_batch_time_ms(_), do: 0.0

  # Safely extract success_rate from metrics.batches.success_rate
  # Returns 100 (safe default) if nil/missing, coerces nil to 100
  defp get_success_rate(nil), do: 100

  defp get_success_rate(%{batches: nil}), do: 100

  defp get_success_rate(%{batches: batches}) when is_map(batches) do
    case Map.get(batches, :success_rate) do
      rate when is_number(rate) -> rate
      nil -> 100
      _ -> 100
    end
  end

  defp get_success_rate(_), do: 100

  # Safely extract messages.processed from nested metrics structure
  # Returns 0 if metrics is nil, messages is nil/missing, or value is nil/non-positive
  defp get_messages_processed(nil), do: 0

  defp get_messages_processed(%{messages: nil}), do: 0

  defp get_messages_processed(%{messages: messages}) when is_map(messages) do
    case Map.get(messages, :processed) do
      count when is_integer(count) and count >= 0 -> count
      _ -> 0
    end
  end

  defp get_messages_processed(_), do: 0

  # Safely extract batches.processed from nested metrics structure
  # Returns 0 if metrics is nil, batches is nil/missing, or value is nil/non-positive
  defp get_batches_processed(nil), do: 0

  defp get_batches_processed(%{batches: nil}), do: 0

  defp get_batches_processed(%{batches: batches}) when is_map(batches) do
    case Map.get(batches, :processed) do
      count when is_integer(count) and count >= 0 -> count
      _ -> 0
    end
  end

  defp get_batches_processed(_), do: 0

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
      avg_utilization > Config.high_utilization_batch_threshold() ->
        Config.batch_size_small()

      # Low utilization - larger batches for efficiency
      avg_utilization < Config.low_utilization_batch_threshold() ->
        Config.batch_size_large()

      # Normal - standard batch size
      true ->
        Config.batch_size_standard()
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
    Process.send_after(self(), :check_scaling, Config.check_interval_ms())
  end

  defp get_configured_concurrency do
    Application.get_env(:eve_dmv, :pipeline_concurrency, Config.default_concurrency())
  end
end
