defmodule EveDmv.Contexts.KillmailProcessing.Domain.KillmailOrchestrator do
  @moduledoc """
  Main orchestrator for killmail processing operations.

  This service coordinates the entire killmail processing workflow:
  1. Pipeline management (start/stop/monitor)
  2. Event publishing coordination
  3. Performance monitoring and metrics
  4. Error handling and recovery
  """

  use GenServer
  alias EveDmv.Contexts.KillmailProcessing.Domain
  # alias EveDmv.Contexts.KillmailProcessing.Infrastructure
  alias EveDmv.DomainEvents
  alias EveDmv.Infrastructure.EventBus
  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_pipeline do
    GenServer.call(__MODULE__, :start_pipeline)
  end

  def stop_pipeline do
    GenServer.call(__MODULE__, :stop_pipeline)
  end

  def pipeline_status do
    GenServer.call(__MODULE__, :pipeline_status)
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def process_killmail(raw_killmail) do
    GenServer.call(__MODULE__, {:process_killmail, raw_killmail})
  end

  # Server implementation

  @impl GenServer
  def init(_opts) do
    # Set up periodic metrics collection
    :timer.send_interval(:timer.minutes(1), :collect_metrics)

    {:ok,
     %{
       pipeline_status: :stopped,
       pipeline_start_time: nil,
       metrics: initialize_metrics(),
       error_count: 0,
       last_error: nil
     }}
  end

  @impl GenServer
  def handle_call(:start_pipeline, _from, state) do
    case state.pipeline_status do
      :running ->
        {:reply, {:ok, :already_running}, state}

      _ ->
        # Start the Broadway pipeline
        case start_broadway_pipeline() do
          {:ok, _pid} ->
            new_state = %{
              state
              | pipeline_status: :running,
                pipeline_start_time: DateTime.utc_now()
            }

            Logger.info("Killmail processing pipeline started")
            {:reply, {:ok, :started}, new_state}

          error ->
            Logger.error("Failed to start killmail pipeline: #{inspect(error)}")
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:stop_pipeline, _from, state) do
    case state.pipeline_status do
      :stopped ->
        {:reply, {:ok, :already_stopped}, state}

      _ ->
        # Stop the Broadway pipeline
        case stop_broadway_pipeline() do
          :ok ->
            new_state = %{state | pipeline_status: :stopped, pipeline_start_time: nil}

            Logger.info("Killmail processing pipeline stopped")
            {:reply, {:ok, :stopped}, new_state}

          error ->
            Logger.error("Failed to stop killmail pipeline: #{inspect(error)}")
            {:reply, error, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:pipeline_status, _from, state) do
    status = %{
      status: state.pipeline_status,
      start_time: state.pipeline_start_time,
      uptime_seconds: calculate_uptime(state.pipeline_start_time),
      error_count: state.error_count,
      last_error: state.last_error
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl GenServer
  def handle_call({:process_killmail, raw_killmail}, _from, state) do
    # Process a single killmail (used for testing or manual processing)
    start_time = System.monotonic_time(:millisecond)

    result =
      with {:ok, enriched_data} <- Domain.EnrichmentService.enrich_killmail(raw_killmail),
           {:ok, storage_result} <-
             Domain.StorageService.store_killmail(raw_killmail, enriched_data),
           :ok <- publish_killmail_events(raw_killmail, enriched_data) do
        processing_time = System.monotonic_time(:millisecond) - start_time

        # Update metrics
        new_metrics = update_processing_metrics(state.metrics, processing_time)
        _new_state = %{state | metrics: new_metrics}

        {:ok, storage_result}
      else
        error ->
          # Update error metrics
          new_state = %{
            state
            | error_count: state.error_count + 1,
              last_error: {DateTime.utc_now(), error}
          }

          Logger.error("Killmail processing failed", %{
            killmail_id: raw_killmail[:killmail_id],
            error: inspect(error)
          })

          {error, new_state}
      end

    case result do
      {:ok, storage_result} ->
        {:reply, {:ok, storage_result}, state}

      {error, new_state} ->
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_info(:collect_metrics, state) do
    # Collect current performance metrics
    new_metrics = collect_current_metrics(state.metrics)

    # Publish metrics as telemetry
    :telemetry.execute(
      [:eve_dmv, :killmail_processing, :metrics],
      new_metrics,
      %{context: :killmail_processing}
    )

    {:noreply, %{state | metrics: new_metrics}}
  end

  # Private functions

  defp start_broadway_pipeline do
    # This would start the actual Broadway pipeline
    # For now, we'll simulate success
    {:ok, :mock_pipeline_pid}
  end

  defp stop_broadway_pipeline do
    # This would stop the actual Broadway pipeline
    :ok
  end

  defp publish_killmail_events(raw_killmail, enriched_data) do
    # Publish KillmailReceived event
    received_event =
      DomainEvents.new(DomainEvents.KillmailReceived, %{
        killmail_id: raw_killmail.killmail_id,
        hash: Map.get(raw_killmail, :hash, ""),
        occurred_at: raw_killmail.killmail_time,
        solar_system_id: Map.get(raw_killmail, :solar_system_id),
        victim: extract_victim_summary(raw_killmail),
        attackers: extract_attackers_summary(raw_killmail),
        zkb_data: Map.get(raw_killmail, :zkb),
        received_at: DateTime.utc_now()
      })

    EventBus.publish(received_event)

    # Publish KillmailEnriched event
    enriched_event =
      DomainEvents.new(DomainEvents.KillmailEnriched, %{
        killmail_id: raw_killmail.killmail_id,
        enriched_data: enriched_data,
        enrichment_duration_ms: Map.get(enriched_data, :processing_time_ms),
        timestamp: DateTime.utc_now()
      })

    EventBus.publish(enriched_event)

    :ok
  end

  defp extract_victim_summary(raw_killmail) do
    victim = raw_killmail.victim

    %{
      character_id: Map.get(victim, :character_id),
      corporation_id: Map.get(victim, :corporation_id),
      alliance_id: Map.get(victim, :alliance_id),
      ship_type_id: Map.get(victim, :ship_type_id),
      damage_taken: Map.get(victim, :damage_taken, 0)
    }
  end

  defp extract_attackers_summary(raw_killmail) do
    raw_killmail.attackers
    # Limit to top 5 attackers for event
    |> Enum.take(5)
    |> Enum.map(fn attacker ->
      %{
        character_id: Map.get(attacker, :character_id),
        corporation_id: Map.get(attacker, :corporation_id),
        alliance_id: Map.get(attacker, :alliance_id),
        ship_type_id: Map.get(attacker, :ship_type_id),
        damage_done: Map.get(attacker, :damage_done, 0),
        final_blow: Map.get(attacker, :final_blow, false)
      }
    end)
  end

  defp calculate_uptime(nil), do: nil

  defp calculate_uptime(start_time) do
    DateTime.diff(DateTime.utc_now(), start_time, :second)
  end

  defp initialize_metrics do
    %{
      killmails_processed: 0,
      killmails_failed: 0,
      average_processing_time_ms: 0,
      total_processing_time_ms: 0,
      throughput_per_minute: 0,
      last_processed_at: nil,
      peak_throughput: 0,
      error_rate: 0.0
    }
  end

  defp update_processing_metrics(metrics, processing_time_ms) do
    new_total = metrics.total_processing_time_ms + processing_time_ms
    new_count = metrics.killmails_processed + 1
    new_average = div(new_total, new_count)

    %{
      metrics
      | killmails_processed: new_count,
        average_processing_time_ms: new_average,
        total_processing_time_ms: new_total,
        last_processed_at: DateTime.utc_now()
    }
  end

  defp collect_current_metrics(metrics) do
    # Calculate throughput based on recent activity
    now = DateTime.utc_now()

    current_throughput =
      case metrics.last_processed_at do
        nil ->
          0

        last_time ->
          time_diff_minutes = DateTime.diff(now, last_time, :second) / 60
          if time_diff_minutes > 0, do: 1 / time_diff_minutes, else: 0
      end

    peak_throughput = max(metrics.peak_throughput, current_throughput)

    error_rate =
      if metrics.killmails_processed > 0 do
        metrics.killmails_failed / metrics.killmails_processed
      else
        0.0
      end

    %{
      metrics
      | throughput_per_minute: current_throughput,
        peak_throughput: peak_throughput,
        error_rate: error_rate
    }
  end
end
