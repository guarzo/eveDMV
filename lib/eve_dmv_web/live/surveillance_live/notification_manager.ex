defmodule EveDmvWeb.SurveillanceLive.NotificationManager do
  @moduledoc """
  Handles notification operations for surveillance profiles.

  Provides functions for loading, marking as read, and managing surveillance
  notifications with proper error handling.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Surveillance.{Notification, NotificationService}

  @doc """
  Load recent notifications for a user.
  """
  @spec load_user_notifications(String.t()) :: [Notification.t()]
  def load_user_notifications(user_id) do
    NotificationService.get_recent_notifications(user_id, 24)
  end

  @doc """
  Get the count of unread notifications for a user.
  """
  @spec get_unread_count(String.t()) :: non_neg_integer()
  def get_unread_count(user_id) do
    NotificationService.get_unread_count(user_id)
  end

  @doc """
  Mark a single notification as read.
  """
  @spec mark_notification_read(String.t()) :: :ok | {:error, String.t()}
  def mark_notification_read(notification_id) do
    case NotificationService.mark_notification_read(notification_id) do
      :ok -> :ok
      {:error, _} -> {:error, "Failed to mark notification as read"}
    end
  end

  @doc """
  Mark all unread notifications for a user as read.

  Returns a result map with success and failure counts.
  """
  @spec mark_all_notifications_read(String.t(), map()) ::
          {:ok, %{success: non_neg_integer(), failed: non_neg_integer()}} | {:error, String.t()}
  def mark_all_notifications_read(user_id, current_user) do
    # Get all unread notifications for the user
    case Ash.read(Notification,
           action: :unread_for_user,
           input: %{user_id: user_id},
           domain: Api
         ) do
      {:ok, unread_notifications} ->
        # Bulk update them to read with individual error handling
        results =
          Enum.reduce(unread_notifications, %{success: 0, failed: 0}, fn notification, acc ->
            case Ash.update(notification,
                   action: :mark_read,
                   domain: Api,
                   actor: current_user
                 ) do
              {:ok, _} ->
                %{acc | success: acc.success + 1}

              {:error, error} ->
                Logger.warning(
                  "Failed to mark notification #{notification.id} as read: #{inspect(error)}"
                )

                %{acc | failed: acc.failed + 1}
            end
          end)

        {:ok, results}

      {:error, _} ->
        {:error, "Failed to load unread notifications"}
    end
  end

  @doc """
  Format flash message for mark all notifications result.
  """
  @spec format_mark_all_message(%{success: non_neg_integer(), failed: non_neg_integer()}) ::
          String.t()
  def format_mark_all_message(results) do
    if results.failed > 0 do
      "Marked #{results.success} notifications as read, #{results.failed} failed"
    else
      "All #{results.success} notifications marked as read"
    end
  end
end
