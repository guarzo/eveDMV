defmodule EveDmv.Platform.PubSub.NotificationHub do
  @moduledoc """
  Real-time notification hub for user-facing notifications.

  This module handles broadcasting notifications to web clients, managing
  notification channels, and providing utilities for LiveView components
  to subscribe to relevant updates.

  ## Usage

      # Broadcast to specific user
      NotificationHub.notify_user(user_id, %{
        type: :alert,
        title: "Threat Detected",
        message: "High-value target spotted in system"
      })

      # Broadcast to all users in a corporation
      NotificationHub.notify_corporation(corp_id, notification)

      # Broadcast to system watchers
      NotificationHub.notify_system_watchers(system_id, notification)

  ## Notification Types

  - `:alert` - Security alerts and warnings
  - `:killmail` - New killmail notifications
  - `:battle` - Battle detection notifications
  - `:system_activity` - System activity updates
  - `:intelligence` - Intelligence updates
  """
  """

  alias Phoenix.PubSub
  require Logger

  @pubsub EveDmv.PubSub

  # Channel prefixes
  @user_channel_prefix "user:"
  @corporation_channel_prefix "corporation:"
  @system_channel_prefix "system:"
  @alliance_channel_prefix "alliance:"
  @global_channel "global"

  @type notification :: %{
          type: atom(),
          title: String.t(),
          message: String.t(),
          data: map(),
          timestamp: DateTime.t()
        }

  # User notifications

  @doc """
  Send a notification to a specific user.
  """
  @spec notify_user(integer(), map()) :: :ok
  def notify_user(user_id, notification) do
    enriched_notification = enrich_notification(notification)
    channel = user_channel(user_id)

    Logger.debug("Sending user notification", %{
      user_id: user_id,
      type: notification.type
    })

    PubSub.broadcast(@pubsub, channel, {:notification, enriched_notification})
  end

  @doc """
  Subscribe to notifications for a specific user.
  """
  @spec subscribe_user(integer()) :: :ok | {:error, term()}
  def subscribe_user(user_id) do
    channel = user_channel(user_id)
    PubSub.subscribe(@pubsub, channel)
  end

  @doc """
  Unsubscribe from user notifications.
  """
  @spec unsubscribe_user(integer()) :: :ok
  def unsubscribe_user(user_id) do
    channel = user_channel(user_id)
    PubSub.unsubscribe(@pubsub, channel)
  end

  # Corporation notifications

  @doc """
  Send a notification to all members of a corporation.
  """
  @spec notify_corporation(integer(), map()) :: :ok
  def notify_corporation(corporation_id, notification) do
    enriched_notification = enrich_notification(notification)
    channel = corporation_channel(corporation_id)

    Logger.debug("Sending corporation notification", %{
      corporation_id: corporation_id,
      type: notification.type
    })

    PubSub.broadcast(@pubsub, channel, {:notification, enriched_notification})
  end

  @doc """
  Subscribe to notifications for a corporation.
  """
  @spec subscribe_corporation(integer()) :: :ok | {:error, term()}
  def subscribe_corporation(corporation_id) do
    channel = corporation_channel(corporation_id)
    PubSub.subscribe(@pubsub, channel)
  end

  @doc """
  Unsubscribe from corporation notifications.
  """
  @spec unsubscribe_corporation(integer()) :: :ok
  def unsubscribe_corporation(corporation_id) do
    channel = corporation_channel(corporation_id)
    PubSub.unsubscribe(@pubsub, channel)
  end

  # System notifications

  @doc """
  Send a notification to all watchers of a solar system.
  """
  @spec notify_system_watchers(integer(), map()) :: :ok
  def notify_system_watchers(system_id, notification) do
    enriched_notification = enrich_notification(notification)
    channel = system_channel(system_id)

    Logger.debug("Sending system notification", %{
      system_id: system_id,
      type: notification.type
    })

    PubSub.broadcast(@pubsub, channel, {:notification, enriched_notification})
  end

  @doc """
  Subscribe to notifications for a solar system.
  """
  @spec subscribe_system(integer()) :: :ok | {:error, term()}
  def subscribe_system(system_id) do
    channel = system_channel(system_id)
    PubSub.subscribe(@pubsub, channel)
  end

  @doc """
  Unsubscribe from system notifications.
  """
  @spec unsubscribe_system(integer()) :: :ok
  def unsubscribe_system(system_id) do
    channel = system_channel(system_id)
    PubSub.unsubscribe(@pubsub, channel)
  end

  # Alliance notifications

  @doc """
  Send a notification to all members of an alliance.
  """
  @spec notify_alliance(integer(), map()) :: :ok
  def notify_alliance(alliance_id, notification) do
    enriched_notification = enrich_notification(notification)
    channel = alliance_channel(alliance_id)

    Logger.debug("Sending alliance notification", %{
      alliance_id: alliance_id,
      type: notification.type
    })

    PubSub.broadcast(@pubsub, channel, {:notification, enriched_notification})
  end

  @doc """
  Subscribe to notifications for an alliance.
  """
  @spec subscribe_alliance(integer()) :: :ok | {:error, term()}
  def subscribe_alliance(alliance_id) do
    channel = alliance_channel(alliance_id)
    PubSub.subscribe(@pubsub, channel)
  end

  @doc """
  Unsubscribe from alliance notifications.
  """
  @spec unsubscribe_alliance(integer()) :: :ok
  def unsubscribe_alliance(alliance_id) do
    channel = alliance_channel(alliance_id)
    PubSub.unsubscribe(@pubsub, channel)
  end

  # Global notifications

  @doc """
  Send a global notification to all connected users.
  """
  @spec notify_global(map()) :: :ok
  def notify_global(notification) do
    enriched_notification = enrich_notification(notification)

    Logger.info("Sending global notification", %{
      type: notification.type
    })

    PubSub.broadcast(@pubsub, @global_channel, {:notification, enriched_notification})
  end

  @doc """
  Subscribe to global notifications.
  """
  @spec subscribe_global() :: :ok | {:error, term()}
  def subscribe_global do
    PubSub.subscribe(@pubsub, @global_channel)
  end

  @doc """
  Unsubscribe from global notifications.
  """
  @spec unsubscribe_global() :: :ok
  def unsubscribe_global do
    PubSub.unsubscribe(@pubsub, @global_channel)
  end

  # Batch operations

  @doc """
  Send notifications to multiple users at once.
  """
  @spec notify_users([integer()], map()) :: :ok
  def notify_users(user_ids, notification) when is_list(user_ids) do
    enriched_notification = enrich_notification(notification)

    Enum.each(user_ids, fn user_id ->
      channel = user_channel(user_id)
      PubSub.broadcast(@pubsub, channel, {:notification, enriched_notification})
    end)
  end

  @doc """
  Send notifications to multiple corporations at once.
  """
  @spec notify_corporations([integer()], map()) :: :ok
  def notify_corporations(corporation_ids, notification) when is_list(corporation_ids) do
    enriched_notification = enrich_notification(notification)

    Enum.each(corporation_ids, fn corp_id ->
      channel = corporation_channel(corp_id)
      PubSub.broadcast(@pubsub, channel, {:notification, enriched_notification})
    end)
  end

  # Channel utilities

  @doc """
  Get all subscribers for a channel.
  """
  @spec get_subscribers(String.t()) :: [pid()]
  def get_subscribers(channel) do
    Registry.lookup(Phoenix.PubSub.PG2, channel)
    |> Enum.map(fn {pid, _} -> pid end)
  end

  @doc """
  Get subscriber count for a channel.
  """
  @spec subscriber_count(String.t()) :: integer()
  def subscriber_count(channel) do
    get_subscribers(channel) |> length()
  end

  # Notification utilities

  @doc """
  Create an alert notification.
  """
  @spec alert(String.t(), String.t(), map()) :: notification()
  def alert(title, message, data \\ %{}) do
    %{
      type: :alert,
      title: title,
      message: message,
      data: data,
      priority: :high
    }
  end

  @doc """
  Create an info notification.
  """
  @spec info(String.t(), String.t(), map()) :: notification()
  def info(title, message, data \\ %{}) do
    %{
      type: :info,
      title: title,
      message: message,
      data: data,
      priority: :normal
    }
  end

  @doc """
  Create a warning notification.
  """
  @spec warning(String.t(), String.t(), map()) :: notification()
  def warning(title, message, data \\ %{}) do
    %{
      type: :warning,
      title: title,
      message: message,
      data: data,
      priority: :medium
    }
  end

  # Private functions

  defp user_channel(user_id), do: "#{@user_channel_prefix}#{user_id}"
  defp corporation_channel(corp_id), do: "#{@corporation_channel_prefix}#{corp_id}"
  defp system_channel(system_id), do: "#{@system_channel_prefix}#{system_id}"
  defp alliance_channel(alliance_id), do: "#{@alliance_channel_prefix}#{alliance_id}"

  defp enrich_notification(notification) do
    notification
    |> Map.put(:id, generate_notification_id())
    |> Map.put_new(:timestamp, DateTime.utc_now())
    |> Map.put_new(:priority, :normal)
    |> Map.put_new(:data, %{})
  end

  defp generate_notification_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
