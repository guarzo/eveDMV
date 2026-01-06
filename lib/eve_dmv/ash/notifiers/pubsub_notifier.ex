defmodule EveDmv.Ash.Notifiers.PubSubNotifier do
  @moduledoc """
  Ash Notifier that broadcasts resource changes via Phoenix PubSub.

  This replaces manual PubSub.broadcast calls scattered throughout the codebase
  with a declarative, centralized approach for Ash resource changes.

  ## Usage in Resources

      use Ash.Resource,
        notifiers: [EveDmv.Ash.Notifiers.PubSubNotifier]

  ## Topic Format

  Topics are formatted as `resource_name:id` (e.g., `profile:abc-123-uuid`).
  For resources without an id, the topic is `resource_name:all`.

  ## Event Format

  Events are broadcast as `{:resource_event, action_type, resource_name, data}`.
  """

  use Ash.Notifier

  alias Phoenix.PubSub

  require Logger

  @pubsub EveDmv.PubSub

  @impl Ash.Notifier
  def notify(%Ash.Notifier.Notification{} = notification) do
    %{resource: resource, data: data, action: action} = notification

    resource_name = extract_resource_name(resource)
    topic = build_topic(resource_name, data)
    event = build_event(action.type, resource_name, data)

    case PubSub.broadcast(@pubsub, topic, event) do
      :ok ->
        Logger.debug("PubSubNotifier broadcast to #{topic}: #{action.type} #{resource_name}")

      {:error, reason} ->
        Logger.warning("PubSubNotifier broadcast failed for #{topic}: #{inspect(reason)}")
    end

    # Also broadcast to the "all" topic for this resource type
    all_topic = "#{resource_name}:all"

    if topic != all_topic do
      PubSub.broadcast(@pubsub, all_topic, event)
    end

    :ok
  end

  @doc """
  Subscribe to all changes for a resource type.

  ## Examples

      PubSubNotifier.subscribe_all(:profile)
  """
  @spec subscribe_all(atom()) :: :ok | {:error, term()}
  def subscribe_all(resource_name) when is_atom(resource_name) do
    PubSub.subscribe(@pubsub, "#{resource_name}:all")
  end

  @doc """
  Subscribe to changes for a specific resource instance.

  ## Examples

      PubSubNotifier.subscribe(:profile, "abc-123-uuid")
  """
  @spec subscribe(atom(), term()) :: :ok | {:error, term()}
  def subscribe(resource_name, id) when is_atom(resource_name) do
    PubSub.subscribe(@pubsub, "#{resource_name}:#{id}")
  end

  @doc """
  Unsubscribe from a resource topic.
  """
  @spec unsubscribe(atom(), term()) :: :ok
  def unsubscribe(resource_name, id) when is_atom(resource_name) do
    PubSub.unsubscribe(@pubsub, "#{resource_name}:#{id}")
  end

  @doc """
  Build a topic string for a resource.
  """
  @spec topic_for(atom(), term()) :: String.t()
  def topic_for(resource_name, id) when is_atom(resource_name) do
    "#{resource_name}:#{id}"
  end

  # Private functions

  @spec extract_resource_name(module()) :: String.t()
  defp extract_resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  @spec build_topic(String.t(), map()) :: String.t()
  defp build_topic(resource_name, data) do
    case Map.get(data, :id) do
      nil -> "#{resource_name}:all"
      id -> "#{resource_name}:#{id}"
    end
  end

  @spec build_event(atom(), String.t(), map()) :: tuple()
  defp build_event(action_type, resource_name, data) do
    # Use to_existing_atom since resource names are derived from module names
    # which are already known atoms at compile time
    resource_atom =
      try do
        String.to_existing_atom(resource_name)
      rescue
        ArgumentError -> resource_name
      end

    {:resource_event, action_type, resource_atom, data}
  end
end
