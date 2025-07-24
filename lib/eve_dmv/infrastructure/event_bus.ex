defmodule EveDmv.Infrastructure.EventBus do
  @moduledoc """
  Event bus for domain event publishing and subscription.

  This module provides the infrastructure for bounded contexts to communicate
  through events without direct dependencies. It uses Phoenix.PubSub for
  reliable message delivery and supports both synchronous and asynchronous
  event handling.
  """

  use GenServer

  alias EveDmv.Contexts
  alias Phoenix.PubSub

  require Logger

  @pubsub EveDmv.PubSub
  @event_topic_prefix "domain_event:"

  @type handler :: (... -> any()) | module() | {module(), atom()}

  # Client API

  @doc """
  Start the event bus process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Publish a domain event.

  The event will be delivered to all subscribers of the event type.
  Returns :ok immediately (fire-and-forget).
  """
  @spec publish(struct()) :: :ok | {:error, term()}
  def publish(event) when is_struct(event) do
    event_type =
      event.__struct__
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_existing_atom()

    # Log event publication
    Logger.debug("Publishing domain event", %{
      event_type: event_type,
      event_id:
        Map.get(event, :id) || Map.get(event, :killmail_id) || Map.get(event, :character_id),
      context: get_publishing_context(event_type)
    })

    # Publish to PubSub
    topic = topic_for_event(event_type)

    case PubSub.broadcast(@pubsub, topic, {:domain_event, event_type, event}) do
      :ok ->
        # Track metrics
        :telemetry.execute(
          [:eve_dmv, :event_bus, :event_published],
          %{count: 1},
          %{event_type: event_type}
        )

        :ok

      error ->
        Logger.error("Failed to publish event", %{
          event_type: event_type,
          error: inspect(error)
        })

        error
    end
  end

  @doc """
  Subscribe to a specific event type.

  The handler function will be called with the event as the only argument.
  The handler can be:
  - A function: fn event -> ... end
  - A module implementing handle_event/1
  - A {module, function} tuple
  """
  @spec subscribe(atom(), handler()) :: {:ok, reference()} | {:error, term()}
  def subscribe(event_type, handler) do
    GenServer.call(__MODULE__, {:subscribe, event_type, handler, self()})
  end

  @doc """
  Subscribe a GenServer process to events.

  Events will be sent as messages in the format:
  {:domain_event, event_type, event}
  """
  @spec subscribe_process(atom(), pid()) :: {:ok, reference()} | {:error, term()}
  def subscribe_process(event_type, pid \\ self()) do
    topic = topic_for_event(event_type)

    case PubSub.subscribe(@pubsub, topic) do
      :ok ->
        ref = make_ref()
        GenServer.cast(__MODULE__, {:track_subscription, event_type, pid, ref})
        {:ok, ref}

      error ->
        error
    end
  end

  @doc """
  Unsubscribe from an event type.
  """
  @spec unsubscribe(reference()) :: :ok
  def unsubscribe(ref) do
    GenServer.call(__MODULE__, {:unsubscribe, ref})
  end

  @doc """
  List all active subscriptions.
  """
  @spec list_subscriptions() :: [{atom(), pid(), reference()}]
  def list_subscriptions do
    GenServer.call(__MODULE__, :list_subscriptions)
  end

  @doc """
  Get event flow statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  @impl GenServer
  def init(_opts) do
    # Set up ETS table for tracking subscriptions
    :ets.new(:event_subscriptions, [:named_table, :set, :protected])

    # Validate event flow on startup
    case Contexts.validate_event_flow() do
      :ok ->
        Logger.info("Event bus initialized with valid event flow")

      {:error, missing_publishers} ->
        Logger.warning("Event flow validation found issues", %{
          missing_publishers: inspect(missing_publishers)
        })
    end

    {:ok,
     %{
       subscriptions: %{},
       stats: %{
         events_published: 0,
         events_delivered: 0,
         delivery_failures: 0
       }
     }}
  end

  @impl GenServer
  def handle_call({:subscribe, event_type, handler, subscriber_pid}, _from, state) do
    ref = make_ref()
    topic = topic_for_event(event_type)

    # Subscribe to PubSub topic
    case PubSub.subscribe(@pubsub, topic) do
      :ok ->
        # Track subscription
        subscription = %{
          event_type: event_type,
          handler: handler,
          subscriber_pid: subscriber_pid,
          ref: ref,
          subscribed_at: DateTime.utc_now()
        }

        new_subscriptions = Map.put(state.subscriptions, ref, subscription)
        :ets.insert(:event_subscriptions, {ref, subscription})

        Logger.debug("Subscription created", %{
          event_type: event_type,
          subscriber: inspect(subscriber_pid),
          ref: ref
        })

        {:reply, {:ok, ref}, %{state | subscriptions: new_subscriptions}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe, ref}, _from, state) do
    case Map.get(state.subscriptions, ref) do
      nil ->
        {:reply, :ok, state}

      subscription ->
        topic = topic_for_event(subscription.event_type)
        PubSub.unsubscribe(@pubsub, topic)

        new_subscriptions = Map.delete(state.subscriptions, ref)
        :ets.delete(:event_subscriptions, ref)

        Logger.debug("Subscription removed", %{
          event_type: subscription.event_type,
          ref: ref
        })

        {:reply, :ok, %{state | subscriptions: new_subscriptions}}
    end
  end

  @impl GenServer
  def handle_call(:list_subscriptions, _from, state) do
    subscriptions =
      Enum.map(state.subscriptions, fn {ref, sub} ->
        {sub.event_type, sub.subscriber_pid, ref}
      end)

    {:reply, subscriptions, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        active_subscriptions: map_size(state.subscriptions),
        subscriptions_by_event: count_subscriptions_by_event(state.subscriptions)
      })

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_cast({:track_subscription, event_type, pid, ref}, state) do
    subscription = %{
      event_type: event_type,
      handler: :process,
      subscriber_pid: pid,
      ref: ref,
      subscribed_at: DateTime.utc_now()
    }

    new_subscriptions = Map.put(state.subscriptions, ref, subscription)
    :ets.insert(:event_subscriptions, {ref, subscription})

    {:noreply, %{state | subscriptions: new_subscriptions}}
  end

  @impl GenServer
  def handle_info({:domain_event, event_type, event}, state) do
    # Handle events that this process itself receives
    # This happens when using subscribe_process

    # Find matching subscriptions
    matching_subs =
      Enum.filter(state.subscriptions, fn {_, sub} -> sub.event_type == event_type end)

    # Deliver to handlers
    delivered_count =
      Enum.reduce(matching_subs, 0, fn {_, sub}, count ->
        case deliver_event(event, sub) do
          :ok -> count + 1
          _ -> count
        end
      end)

    # Update stats
    new_stats =
      Map.update!(state.stats, :events_delivered, &(&1 + delivered_count))

    {:noreply, %{state | stats: new_stats}}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("EventBus received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp topic_for_event(event_type) do
    "#{@event_topic_prefix}#{event_type}"
  end

  defp get_publishing_context(event_type) do
    event_type
    |> Contexts.publishers_of()
    |> List.first()
  end

  defp deliver_event(event, subscription) do
    case subscription.handler do
      :process ->
        # For process subscriptions, the process handles the raw message
        :ok

      handler when is_function(handler, 1) ->
        handler.(event)
        :ok

      {module, function} ->
        apply(module, function, [event])
        :ok

      module when is_atom(module) ->
        module.handle_event(event)
        :ok
    end
  rescue
    error ->
      Logger.error("Event handler failed", %{
        event_type: subscription.event_type,
        handler: inspect(subscription.handler),
        error: inspect(error),
        stacktrace: __STACKTRACE__
      })

      {:error, error}
  end

  defp count_subscriptions_by_event(subscriptions) do
    subscriptions
    |> Enum.group_by(fn {_, sub} -> sub.event_type end)
    |> Enum.map(fn {event_type, subs} -> {event_type, length(subs)} end)
    |> Map.new()
  end
end
