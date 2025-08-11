defmodule EveDmv.Core.Events.EventBus do
  @moduledoc """
  Event bus for decoupled communication between contexts.
  Implements publish-subscribe pattern for domain events.
  """

  use GenServer
  require Logger

  # Event types
  @battle_detected "battle.detected"
  @killmail_processed "killmail.processed"
  @character_analyzed "character.analyzed"
  @intelligence_updated "intelligence.updated"
  @surveillance_match "surveillance.match"

  def start_link(opts \\ []) do
    Logger.info("Starting EventBus...")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    Logger.info("EventBus init called")
    try do
      # Create ETS table for subscribers
      :ets.new(:event_bus_subscribers, [:set, :public, :named_table])
      Logger.info("EventBus ETS table created successfully")
      {:ok, %{subscribers: %{}}}
    rescue
      e ->
        Logger.error("EventBus init failed: #{inspect(e)}")
        {:stop, e}
    end
  end

  @doc """
  Subscribe to events of a specific type.
  The handler can be a function or a module implementing handle_event/2.
  """
  def subscribe(event_type, handler) do
    GenServer.call(__MODULE__, {:subscribe, event_type, handler})
  end

  @doc """
  Unsubscribe from events of a specific type.
  """
  def unsubscribe(event_type, handler) do
    GenServer.call(__MODULE__, {:unsubscribe, event_type, handler})
  end

  @doc """
  Publish an event to all subscribers.
  Events are processed asynchronously.
  """
  def publish(event_type, payload) do
    GenServer.cast(__MODULE__, {:publish, event_type, payload})
  end

  @doc """
  Publish an event synchronously and wait for all handlers to complete.
  """
  def publish_sync(event_type, payload, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:publish_sync, event_type, payload}, timeout)
  end

  # Convenience functions for common events

  @doc """
  Publish a battle detected event
  """
  def battle_detected(battle_data) do
    publish(@battle_detected, %{
      battle_id: battle_data.id,
      killmail_ids: Map.get(battle_data, :killmail_ids, []),
      participant_count: Map.get(battle_data, :participant_count, 0),
      solar_system_id: Map.get(battle_data, :solar_system_id),
      detected_at: DateTime.utc_now(),
      metadata: Map.get(battle_data, :metadata, %{})
    })
  end

  @doc """
  Publish a killmail processed event
  """
  def killmail_processed(killmail_data) do
    publish(@killmail_processed, %{
      killmail_id: killmail_data.killmail_id,
      solar_system_id: killmail_data.solar_system_id,
      victim_character_id: Map.get(killmail_data, :victim_character_id),
      victim_corporation_id: Map.get(killmail_data, :victim_corporation_id),
      total_value: Map.get(killmail_data, :total_value, 0),
      processed_at: DateTime.utc_now()
    })
  end

  @doc """
  Publish a character analyzed event
  """
  def character_analyzed(character_id, analysis_data) do
    publish(@character_analyzed, %{
      character_id: character_id,
      threat_score: Map.get(analysis_data, :threat_score),
      analysis_type: Map.get(analysis_data, :type, :basic),
      analyzed_at: DateTime.utc_now(),
      metadata: Map.get(analysis_data, :metadata, %{})
    })
  end

  @doc """
  Publish an intelligence updated event
  """
  def intelligence_updated(entity_type, entity_id, intelligence_data) do
    publish(@intelligence_updated, %{
      entity_type: entity_type,
      entity_id: entity_id,
      intelligence_type: Map.get(intelligence_data, :type),
      confidence: Map.get(intelligence_data, :confidence),
      updated_at: DateTime.utc_now(),
      data: intelligence_data
    })
  end

  @doc """
  Publish a surveillance match event
  """
  def surveillance_match(profile_id, killmail_data) do
    publish(@surveillance_match, %{
      profile_id: profile_id,
      killmail_id: killmail_data.killmail_id,
      match_confidence: Map.get(killmail_data, :confidence, 1.0),
      matched_at: DateTime.utc_now(),
      killmail_data: killmail_data
    })
  end

  # GenServer callbacks

  @impl GenServer
  def handle_call({:subscribe, event_type, handler}, _from, state) do
    subscribers = Map.get(state.subscribers, event_type, [])
    updated_subscribers = [handler | subscribers] |> Enum.uniq()

    new_state = %{
      state
      | subscribers: Map.put(state.subscribers, event_type, updated_subscribers)
    }

    Logger.debug("Subscribed handler to event type: #{event_type}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, event_type, handler}, _from, state) do
    subscribers = Map.get(state.subscribers, event_type, [])
    updated_subscribers = Enum.reject(subscribers, &(&1 == handler))

    new_state = %{
      state
      | subscribers: Map.put(state.subscribers, event_type, updated_subscribers)
    }

    Logger.debug("Unsubscribed handler from event type: #{event_type}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:publish_sync, event_type, payload}, _from, state) do
    subscribers = Map.get(state.subscribers, event_type, [])

    results =
      Enum.map(subscribers, fn handler ->
        try do
          handle_event(handler, event_type, payload)
          {:ok, handler}
        rescue
          error ->
            Logger.error("Event handler failed: #{inspect(error)}")
            {:error, handler, error}
        end
      end)

    {:reply, {:ok, results}, state}
  end

  @impl GenServer
  def handle_cast({:publish, event_type, payload}, state) do
    subscribers = Map.get(state.subscribers, event_type, [])

    # Process events asynchronously
    Enum.each(subscribers, fn handler ->
      Task.start(fn ->
        try do
          handle_event(handler, event_type, payload)
        rescue
          error ->
            Logger.error("""
            Event handler failed
            Event: #{event_type}
            Handler: #{inspect(handler)}
            Error: #{inspect(error)}
            """)
        end
      end)
    end)

    # Log high-value events
    if event_type in [@battle_detected, @surveillance_match] do
      Logger.info("Published event: #{event_type} to #{length(subscribers)} subscribers")
    end

    {:noreply, state}
  end

  # Private functions

  defp handle_event(handler, event_type, payload) when is_function(handler, 2) do
    handler.(event_type, payload)
  end

  defp handle_event(handler, _event_type, payload) when is_function(handler, 1) do
    handler.(payload)
  end

  defp handle_event(handler, event_type, payload) when is_atom(handler) do
    if function_exported?(handler, :handle_event, 2) do
      handler.handle_event(event_type, payload)
    else
      Logger.warning("Handler #{handler} does not implement handle_event/2")
    end
  end

  defp handle_event(handler, _event_type, _payload) do
    Logger.warning("Invalid event handler: #{inspect(handler)}")
  end
end
