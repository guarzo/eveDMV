defmodule EveDmv.Historical.ImportProgressMonitor do
  @moduledoc """
  Sprint 15A: Real-time monitoring and visualization of historical import progress.

  Provides telemetry, metrics, and UI updates for import pipeline performance tracking.
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub

  defstruct [
    :current_import,
    :metrics,
    :history,
    :alerts
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start monitoring an import.
  """
  def monitor_import(import_id) do
    GenServer.cast(__MODULE__, {:monitor_import, import_id})
  end

  @doc """
  Get current import metrics.
  """
  def get_metrics(import_id \\ nil) do
    GenServer.call(__MODULE__, {:get_metrics, import_id})
  end

  @doc """
  Get import history.
  """
  def get_history(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_history, limit})
  end

  @doc """
  Subscribe to import progress updates.
  """
  def subscribe_to_progress(import_id) do
    PubSub.subscribe(EveDmv.PubSub, "import:#{import_id}")
  end

  # Server callbacks

  def init(_opts) do
    # Attach telemetry handlers
    attach_telemetry_handlers()

    state = %__MODULE__{
      current_import: nil,
      metrics: %{},
      history: [],
      alerts: []
    }

    {:ok, state}
  end

  def handle_cast({:monitor_import, import_id}, state) do
    # Subscribe to import events
    PubSub.subscribe(EveDmv.PubSub, "import:#{import_id}")

    # Initialize metrics for this import
    metrics = %{
      import_id: import_id,
      start_time: DateTime.utc_now(),
      samples: [],
      performance: %{
        rates: [],
        errors_per_batch: [],
        batch_durations: []
      }
    }

    new_state = %{
      state
      | current_import: import_id,
        metrics: Map.put(state.metrics, import_id, metrics)
    }

    Logger.info("📊 Started monitoring import: #{import_id}")

    {:noreply, new_state}
  end

  def handle_call({:get_metrics, nil}, _from, state) do
    # Return current import metrics
    if state.current_import do
      {:reply, Map.get(state.metrics, state.current_import), state}
    else
      {:reply, nil, state}
    end
  end

  def handle_call({:get_metrics, import_id}, _from, state) do
    {:reply, Map.get(state.metrics, import_id), state}
  end

  def handle_call({:get_history, limit}, _from, state) do
    history = Enum.take(state.history, limit)
    {:reply, history, state}
  end

  def handle_call(:get_active_summary, _from, state) do
    summary =
      state.metrics
      |> Map.values()
      |> Enum.map(fn metrics ->
        latest_sample = List.first(metrics.samples, %{})

        %{
          import_id: metrics.import_id,
          start_time: metrics.start_time,
          current_rate: Map.get(latest_sample, :rate, 0),
          processed: Map.get(latest_sample, :processed, 0),
          errors: Map.get(latest_sample, :errors, 0),
          avg_batch_duration: calculate_avg_duration(metrics.performance.batch_durations)
        }
      end)

    {:reply, summary, state}
  end

  # Handle import progress updates
  def handle_info({:import_progress, import_state}, state) do
    import_id = import_state.import_id

    # Update metrics
    new_state =
      case Map.get(state.metrics, import_id) do
        nil ->
          state

        metrics ->
          updated_metrics = update_import_metrics(metrics, import_state)

          # Check for performance issues
          check_performance_alerts(updated_metrics, import_state)

          %{state | metrics: Map.put(state.metrics, import_id, updated_metrics)}
      end

    {:noreply, new_state}
  end

  # Handle telemetry events
  def handle_info({:telemetry, [:eve_dmv, :import, :batch], measurements, metadata}, state) do
    import_id = metadata.import_id

    case Map.get(state.metrics, import_id) do
      nil ->
        {:noreply, state}

      metrics ->
        # Record batch performance
        batch_duration = measurements[:duration] || 0
        _batch_size = measurements[:processed] || 0
        errors = measurements[:errors] || 0

        performance = metrics.performance

        updated_performance = %{
          performance
          | batch_durations: [batch_duration | performance.batch_durations] |> Enum.take(100),
            errors_per_batch: [errors | performance.errors_per_batch] |> Enum.take(100)
        }

        updated_metrics = %{metrics | performance: updated_performance}

        {:noreply, %{state | metrics: Map.put(state.metrics, import_id, updated_metrics)}}
    end
  end

  def handle_info({:telemetry, [:eve_dmv, :import, :complete], measurements, metadata}, state) do
    import_id = metadata.import_id

    # Move to history
    case Map.get(state.metrics, import_id) do
      nil ->
        {:noreply, state}

      metrics ->
        # Create history entry
        history_entry = %{
          import_id: import_id,
          start_time: metrics.start_time,
          end_time: DateTime.utc_now(),
          duration: measurements[:duration],
          total_processed: measurements[:processed],
          success_count: measurements[:success],
          error_count: measurements[:errors],
          average_rate: calculate_average_rate(metrics),
          peak_rate: calculate_peak_rate(metrics)
        }

        new_state = %{
          state
          | history: [history_entry | state.history] |> Enum.take(100),
            metrics: Map.delete(state.metrics, import_id)
        }

        # Clear current import if it matches
        new_state =
          if state.current_import == import_id do
            %{new_state | current_import: nil}
          else
            new_state
          end

        {:noreply, new_state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp attach_telemetry_handlers do
    events = [
      [:eve_dmv, :import, :batch],
      [:eve_dmv, :import, :complete]
    ]

    Enum.each(events, fn event ->
      :telemetry.attach(
        "import-monitor-#{inspect(event)}",
        event,
        {__MODULE__, :handle_telemetry_event, []},
        nil
      )
    end)
  end

  def handle_telemetry_event(event, measurements, metadata, _config) do
    send(self(), {:telemetry, event, measurements, metadata})
  end

  defp update_import_metrics(metrics, import_state) do
    # Add current sample
    sample = %{
      timestamp: DateTime.utc_now(),
      processed: import_state.processed_count,
      rate: import_state.current_rate,
      errors: import_state.error_count
    }

    # Keep last 5 minutes at 1 sample/sec
    samples = [sample | metrics.samples] |> Enum.take(300)

    # Update rate history
    performance = metrics.performance
    rates = [import_state.current_rate | performance.rates] |> Enum.take(100)

    %{metrics | samples: samples, performance: %{performance | rates: rates}}
  end

  defp check_performance_alerts(metrics, import_state) do
    # Check for performance degradation
    recent_rates = Enum.take(metrics.performance.rates, 10)

    if length(recent_rates) >= 10 do
      avg_rate = Enum.sum(recent_rates) / length(recent_rates)

      # Alert if current rate is 50% below average
      if import_state.current_rate < avg_rate * 0.5 do
        Logger.warning("""
        ⚠️  Import performance degraded for #{import_state.import_id}
        Current rate: #{import_state.current_rate}/min
        Average rate: #{round(avg_rate)}/min
        """)

        # Broadcast alert
        PubSub.broadcast(
          EveDmv.PubSub,
          "import:alerts",
          {:performance_degradation, import_state.import_id, import_state.current_rate, avg_rate}
        )
      end
    end

    # Check error rate
    recent_errors = Enum.take(metrics.performance.errors_per_batch, 10)

    if length(recent_errors) > 0 do
      error_rate = Enum.sum(recent_errors) / length(recent_errors)

      # More than 10 errors per batch on average
      if error_rate > 10 do
        Logger.warning(
          "⚠️  High error rate in import #{import_state.import_id}: #{round(error_rate)} errors/batch"
        )
      end
    end
  end

  defp calculate_average_rate(metrics) do
    rates = metrics.performance.rates

    if length(rates) > 0 do
      round(Enum.sum(rates) / length(rates))
    else
      0
    end
  end

  defp calculate_peak_rate(metrics) do
    case metrics.performance.rates do
      [] -> 0
      rates -> Enum.max(rates)
    end
  end

  # Public utilities for monitoring dashboards

  @doc """
  Get performance summary for all active imports.
  """
  def get_active_imports_summary do
    GenServer.call(__MODULE__, :get_active_summary)
  end

  defp calculate_avg_duration([]), do: 0

  defp calculate_avg_duration(durations) do
    sum = Enum.sum(durations)
    round(sum / length(durations))
  end
end
