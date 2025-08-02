defmodule EveDmv.Shared.Infrastructure.UnifiedEventProcessor do
  @moduledoc """
  Unified event processor replacing multiple context-specific event processors.

  Consolidates event processing functionality from:
  - Surveillance.Infrastructure.KillmailEventProcessor
  - CombatIntelligence.Infrastructure.KillmailEventProcessor
  - CombatIntelligence.Infrastructure.StaticDataEventProcessor
  - WormholeOperations.Infrastructure.WormholeEventProcessor
  - KillmailProcessing.Infrastructure.EventPublisher

  Provides:
  - Centralized event routing to appropriate domain handlers
  - Event transformation and validation
  - Error handling and retry logic
  - Event batching and throttling
  - Performance monitoring and statistics
  """

  use GenServer

  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.DomainEvents.KillmailReceived
  alias EveDmv.DomainEvents.StaticDataUpdated
  alias EveDmv.Infrastructure.EventBus

  require Logger

  @default_batch_size 10
  # 5 seconds
  @default_batch_timeout 5_000

  @type event_handler :: {module(), atom()} | function()
  @type event_type :: atom()
  @type processing_stats :: %{
          events_processed: non_neg_integer(),
          events_failed: non_neg_integer(),
          last_processed: DateTime.t() | nil,
          processing_errors: list()
        }

  ## Public API

  @doc """
  Start the unified event processor.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register an event handler for a specific event type.
  """
  @spec register_handler(event_type(), event_handler()) :: :ok
  def register_handler(event_type, handler) do
    GenServer.call(__MODULE__, {:register_handler, event_type, handler})
  end

  @doc """
  Unregister an event handler.
  """
  @spec unregister_handler(event_type(), event_handler()) :: :ok
  def unregister_handler(event_type, handler) do
    GenServer.call(__MODULE__, {:unregister_handler, event_type, handler})
  end

  @doc """
  Process a single event immediately.
  """
  @spec process_event(struct()) :: :ok | {:error, term()}
  def process_event(event) when is_struct(event) do
    GenServer.call(__MODULE__, {:process_event, event}, 10_000)
  end

  @doc """
  Queue an event for batch processing.
  """
  @spec queue_event(struct()) :: :ok
  def queue_event(event) when is_struct(event) do
    GenServer.cast(__MODULE__, {:queue_event, event})
  end

  @doc """
  Get processing statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Get statistics for a specific event type.
  """
  @spec get_event_stats(event_type()) :: processing_stats()
  def get_event_stats(event_type) do
    GenServer.call(__MODULE__, {:get_event_stats, event_type})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    batch_timeout = Keyword.get(opts, :batch_timeout, @default_batch_timeout)

    # Subscribe to domain events
    EventBus.subscribe(self(), :killmail_events)
    EventBus.subscribe(self(), :static_data_events)
    EventBus.subscribe(self(), :wormhole_events)

    # Register default handlers
    default_handlers = register_default_handlers()

    # Schedule batch processing
    schedule_batch_processing(batch_timeout)

    state = %{
      handlers: default_handlers,
      event_queue: [],
      batch_size: batch_size,
      batch_timeout: batch_timeout,
      stats: %{},
      processing_errors: []
    }

    Logger.info("Unified event processor started with batch size #{batch_size}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register_handler, event_type, handler}, _from, state) do
    handlers = Map.update(state.handlers, event_type, [handler], &[handler | &1])
    Logger.debug("Registered handler for #{event_type}: #{inspect(handler)}")
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl GenServer
  def handle_call({:unregister_handler, event_type, handler}, _from, state) do
    handlers = Map.update(state.handlers, event_type, [], &List.delete(&1, handler))
    Logger.debug("Unregistered handler for #{event_type}: #{inspect(handler)}")
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl GenServer
  def handle_call({:process_event, event}, _from, state) do
    result = process_single_event(event, state.handlers)
    updated_stats = update_event_stats(state.stats, event, result)
    {:reply, result, %{state | stats: updated_stats}}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    overall_stats = calculate_overall_stats(state.stats)
    {:reply, overall_stats, state}
  end

  @impl GenServer
  def handle_call({:get_event_stats, event_type}, _from, state) do
    event_stats =
      Map.get(state.stats, event_type, %{
        events_processed: 0,
        events_failed: 0,
        last_processed: nil,
        processing_errors: []
      })

    {:reply, event_stats, state}
  end

  @impl GenServer
  def handle_call(:get_queue_size, _from, state) do
    {:reply, length(state.event_queue), state}
  end

  @impl GenServer
  def handle_cast({:queue_event, event}, state) do
    new_queue = [event | state.event_queue]

    # Process batch if queue is full
    if length(new_queue) >= state.batch_size do
      {updated_state, _batch_result} = process_event_batch(new_queue, state)
      {:noreply, %{updated_state | event_queue: []}}
    else
      {:noreply, %{state | event_queue: new_queue}}
    end
  end

  @impl GenServer
  def handle_info(:process_batch, state) do
    if Enum.empty?(state.event_queue) do
      schedule_batch_processing(state.batch_timeout)
      {:noreply, state}
    else
      {updated_state, _batch_result} = process_event_batch(state.event_queue, state)
      schedule_batch_processing(state.batch_timeout)
      {:noreply, %{updated_state | event_queue: []}}
    end
  end

  @impl GenServer
  def handle_info({:event_received, event}, state) do
    # Handle events from EventBus subscriptions
    result = process_single_event(event, state.handlers)
    updated_stats = update_event_stats(state.stats, event, result)
    {:noreply, %{state | stats: updated_stats}}
  end

  ## Private Functions

  defp register_default_handlers do
    %{
      killmail_enriched: [
        {EveDmv.Contexts.Surveillance.Domain.MatchingEngine, :process_killmail},
        {EveDmv.Contexts.CombatIntelligence.Domain.CharacterAnalyzer, :analyze_killmail},
        {EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzer, :assess_threat},
        {EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer, :analyze_fleet_engagement}
      ],
      killmail_received: [
        {EveDmv.Contexts.KillmailProcessing.Domain.EnrichmentService, :enrich_killmail}
      ],
      static_data_updated: [
        {EveDmv.Contexts.CombatIntelligence.Domain.StaticDataProcessor, :update_static_data}
      ],
      wormhole_signature_detected: [
        {EveDmv.Contexts.WormholeOperations.Domain.SignatureProcessor, :process_signature}
      ]
    }
  end

  defp process_single_event(event, handlers) do
    event_type = get_event_type(event)
    event_handlers = Map.get(handlers, event_type, [])

    if Enum.empty?(event_handlers) do
      Logger.debug("No handlers registered for event type: #{event_type}")
      :ok
    else
      process_with_handlers(event, event_handlers)
    end
  end

  defp process_with_handlers(event, handlers) do
    results =
      Enum.map(handlers, fn handler ->
        process_with_handler(event, handler)
      end)

    failed_results = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(failed_results) do
      :ok
    else
      {:error, {:some_handlers_failed, failed_results}}
    end
  end

  defp process_with_handler(event, {module, function}) do
    apply(module, function, [event])
    :ok
  rescue
    error ->
      Logger.error("Event processing failed", %{
        handler: {module, function},
        event_type: get_event_type(event),
        error: inspect(error)
      })

      {:error, error}
  catch
    :exit, reason ->
      Logger.error("Event handler exited", %{
        handler: {module, function},
        event_type: get_event_type(event),
        reason: inspect(reason)
      })

      {:error, {:exit, reason}}
  end

  defp process_with_handler(event, handler) when is_function(handler) do
    handler.(event)
    :ok
  rescue
    error ->
      Logger.error("Event processing failed with function handler", %{
        handler: inspect(handler),
        event_type: get_event_type(event),
        error: inspect(error)
      })

      {:error, error}
  end

  defp process_event_batch(events, state) do
    batch_start = System.monotonic_time(:millisecond)

    results =
      Enum.map(events, fn event ->
        {event, process_single_event(event, state.handlers)}
      end)

    batch_end = System.monotonic_time(:millisecond)
    batch_duration = batch_end - batch_start

    # Update statistics for all events in batch
    updated_stats =
      Enum.reduce(results, state.stats, fn {event, result}, stats ->
        update_event_stats(stats, event, result)
      end)

    successful_count = Enum.count(results, fn {_event, result} -> result == :ok end)
    failed_count = length(results) - successful_count

    Logger.info("Processed event batch", %{
      batch_size: length(events),
      successful: successful_count,
      failed: failed_count,
      duration_ms: batch_duration
    })

    batch_result = %{
      batch_size: length(events),
      successful: successful_count,
      failed: failed_count,
      duration_ms: batch_duration
    }

    {%{state | stats: updated_stats}, batch_result}
  end

  defp get_event_type(%KillmailEnriched{}), do: :killmail_enriched
  defp get_event_type(%KillmailReceived{}), do: :killmail_received
  defp get_event_type(%StaticDataUpdated{}), do: :static_data_updated

  defp get_event_type(event) do
    module_name =
      event.__struct__
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    try do
      String.to_existing_atom(module_name)
    rescue
      ArgumentError -> :unknown_event
    end
  end

  defp update_event_stats(stats, event, result) do
    event_type = get_event_type(event)

    current_stats =
      Map.get(stats, event_type, %{
        events_processed: 0,
        events_failed: 0,
        last_processed: nil,
        processing_errors: []
      })

    case result do
      :ok ->
        %{
          current_stats
          | events_processed: current_stats.events_processed + 1,
            last_processed: DateTime.utc_now()
        }

      {:error, error} ->
        error_info = %{
          error: inspect(error),
          timestamp: DateTime.utc_now(),
          event_data: sanitize_event_for_logging(event)
        }

        recent_errors = [error_info | current_stats.processing_errors] |> Enum.take(10)

        %{
          current_stats
          | events_failed: current_stats.events_failed + 1,
            last_processed: DateTime.utc_now(),
            processing_errors: recent_errors
        }
    end
    |> then(&Map.put(stats, event_type, &1))
  end

  defp calculate_overall_stats(event_stats) do
    total_processed =
      event_stats
      |> Map.values()
      |> Enum.map(& &1.events_processed)
      |> Enum.sum()

    total_failed =
      event_stats
      |> Map.values()
      |> Enum.map(& &1.events_failed)
      |> Enum.sum()

    success_rate =
      if total_processed + total_failed > 0 do
        total_processed / (total_processed + total_failed)
      else
        0.0
      end

    %{
      total_events_processed: total_processed,
      total_events_failed: total_failed,
      overall_success_rate: Float.round(success_rate, 3),
      event_type_stats: event_stats,
      active_handlers: count_active_handlers(event_stats)
    }
  end

  defp count_active_handlers(event_stats) do
    event_stats
    |> Map.keys()
    |> length()
  end

  defp sanitize_event_for_logging(event) do
    # Remove sensitive data and limit size for logging
    event
    |> Map.from_struct()
    |> Map.take([:timestamp, :event_id, :source])
    |> Map.put(:event_type, get_event_type(event))
  end

  defp schedule_batch_processing(timeout) do
    Process.send_after(self(), :process_batch, timeout)
  end

  ## Domain-Specific Processing Functions

  @doc """
  Process killmail for surveillance matching.
  """
  def process_killmail_for_surveillance(killmail_event) do
    queue_event(killmail_event)
  end

  @doc """
  Process killmail for combat intelligence.
  """
  def process_killmail_for_combat_intelligence(killmail_event) do
    queue_event(killmail_event)
  end

  @doc """
  Process static data update.
  """
  def process_static_data_update(static_data_event) do
    process_event(static_data_event)
  end

  @doc """
  Process wormhole signature detection.
  """
  def process_wormhole_signature(signature_event) do
    queue_event(signature_event)
  end

  @doc """
  Publish domain event to event bus.
  """
  def publish_domain_event(event) do
    EventBus.publish(event)
    queue_event(event)
  end

  ## Event Processing Retry Logic

  # defp process_with_retry - removed as unused

  ## Health Check and Monitoring

  @doc """
  Perform health check on the event processor.
  """
  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    stats = get_stats()

    # Check if processor is responsive
    if stats.total_events_processed >= 0 do
      :ok
    else
      {:error, :invalid_stats}
    end
  rescue
    error -> {:error, error}
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  @doc """
  Get current event queue size.
  """
  @spec get_queue_size() :: non_neg_integer()
  def get_queue_size do
    GenServer.call(__MODULE__, :get_queue_size)
  end
end
