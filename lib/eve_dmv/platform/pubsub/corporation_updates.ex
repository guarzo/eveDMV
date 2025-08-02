defmodule EveDmv.Platform.PubSub.CorporationUpdates do
  @moduledoc """
  PubSub module for broadcasting corporation-related events.

  Handles broadcasting of corporation updates, recruitment events,
  and member activity changes to interested subscribers.
  """
  """

  alias Phoenix.PubSub

  require Logger

  @pubsub_name EveDmv.PubSub

  @doc """
  Broadcast a recruitment event.
  """
  def broadcast_recruitment_event(event_type, corporation_id, data) do
    topic = "corporation:#{corporation_id}:recruitment"

    event = %{
      type: event_type,
      corporation_id: corporation_id,
      data: data,
      timestamp: DateTime.utc_now()
    }

    case PubSub.broadcast(@pubsub_name, topic, {:recruitment_event, event}) do
      :ok ->
        Logger.debug(
          "Broadcast recruitment event #{event_type} for corporation #{corporation_id}"
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to broadcast recruitment event: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.warning("Error broadcasting recruitment event: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Broadcast corporation member update.
  """
  def broadcast_member_update(corporation_id, member_data) do
    topic = "corporation:#{corporation_id}:members"

    event = %{
      type: :member_update,
      corporation_id: corporation_id,
      member: member_data,
      timestamp: DateTime.utc_now()
    }

    case PubSub.broadcast(@pubsub_name, topic, {:member_update, event}) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to broadcast member update: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.warning("Error broadcasting member update: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Subscribe to corporation recruitment events.
  """
  def subscribe_recruitment(corporation_id) do
    topic = "corporation:#{corporation_id}:recruitment"
    PubSub.subscribe(@pubsub_name, topic)
  end

  @doc """
  Subscribe to corporation member updates.
  """
  def subscribe_members(corporation_id) do
    topic = "corporation:#{corporation_id}:members"
    PubSub.subscribe(@pubsub_name, topic)
  end

  @doc """
  Unsubscribe from corporation events.
  """
  def unsubscribe(corporation_id, event_type \\ :all) do
    case event_type do
      :all ->
        PubSub.unsubscribe(@pubsub_name, "corporation:#{corporation_id}:recruitment")
        PubSub.unsubscribe(@pubsub_name, "corporation:#{corporation_id}:members")

      :recruitment ->
        PubSub.unsubscribe(@pubsub_name, "corporation:#{corporation_id}:recruitment")

      :members ->
        PubSub.unsubscribe(@pubsub_name, "corporation:#{corporation_id}:members")
    end
  end

  @doc """
  Subscribe to all corporation events.
  """
  def subscribe(corporation_id) when is_integer(corporation_id) do
    subscribe_recruitment(corporation_id)
    subscribe_members(corporation_id)
  end

  def subscribe(_), do: {:error, :invalid_corporation_id}

  @doc """
  Broadcast that a corporation was created.
  """
  def broadcast_corporation_created(corporation) when is_map(corporation) do
    topic = "corporation:all"
    event = {:corporation_created, corporation}

    case PubSub.broadcast(@pubsub_name, topic, event) do
      :ok ->
        Logger.debug("Broadcast corporation created: #{inspect(corporation[:id])}")
        :ok

      error ->
        error
    end
  end

  def broadcast_corporation_created(_), do: {:error, :invalid_corporation}

  @doc """
  Broadcast that a corporation was updated.
  """
  def broadcast_corporation_updated(corporation) when is_map(corporation) do
    topic = "corporation:#{corporation[:id]}"
    event = {:corporation_updated, corporation}

    case PubSub.broadcast(@pubsub_name, topic, event) do
      :ok ->
        Logger.debug("Broadcast corporation updated: #{inspect(corporation[:id])}")
        :ok

      error ->
        error
    end
  end

  def broadcast_corporation_updated(_), do: {:error, :invalid_corporation}

  @doc """
  Broadcast that a member was added to a corporation.
  """
  def broadcast_member_added(corporation_id, member)
      when is_integer(corporation_id) and is_map(member) do
    broadcast_member_update(corporation_id, Map.put(member, :action, :added))
  end

  def broadcast_member_added(_, _), do: {:error, :invalid_parameters}

  @doc """
  Broadcast that a member was updated.
  """
  def broadcast_member_updated(member) when is_map(member) do
    corporation_id = Map.get(member, :corporation_id)

    if corporation_id do
      broadcast_member_update(corporation_id, Map.put(member, :action, :updated))
    else
      {:error, :missing_corporation_id}
    end
  end

  def broadcast_member_updated(_), do: {:error, :invalid_member}

  @doc """
  Broadcast that a member was removed from a corporation.
  """
  def broadcast_member_removed(corporation_id, member)
      when is_integer(corporation_id) and is_map(member) do
    broadcast_member_update(corporation_id, Map.put(member, :action, :removed))
  end

  def broadcast_member_removed(_, _), do: {:error, :invalid_parameters}
end
