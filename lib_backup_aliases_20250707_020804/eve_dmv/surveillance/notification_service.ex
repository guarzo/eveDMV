defmodule EveDmv.Surveillance.NotificationService do
  @moduledoc """
  Service for creating and managing surveillance notifications.

  Handles creating notifications for surveillance profile matches,
  managing user notification preferences, and delivering notifications
  via various channels (LiveView, email, webhooks, etc.).
  """

  require Logger
    alias EveDmv.Surveillance.Notification
  alias EveDmv.Api
  alias EveDmv.Surveillance.Profile
  alias EveDmvWeb.Endpoint

  @doc """
  Create a notification for a surveillance profile match.
  """
  @spec create_profile_match_notification(String.t(), map(), [String.t()]) ::
          :ok | {:error, term()}
  def create_profile_match_notification(profile_id, killmail, matched_profile_ids) do
    case Ash.get(Profile, profile_id, domain: Api) do
      {:ok, profile} ->
        notification_data = %{
          user_id: profile.user_id,
          notification_type: :profile_match,
          profile_id: profile_id,
          killmail_id: killmail["killmail_id"],
          title: "Surveillance Alert: #{profile.name}",
          message: build_match_message(profile, killmail),
          data: %{
            killmail: extract_killmail_summary(killmail),
            all_matched_profiles: matched_profile_ids,
            profile_name: profile.name
          },
          priority: determine_priority(killmail, profile)
        }

        case Ash.create(Notification, notification_data, domain: Api) do
          {:ok, notification} ->
            # Broadcast to user's personal notification channel
            broadcast_to_user(profile.user_id, "new_notification", %{
              notification: notification,
              killmail: killmail,
              profile: profile
            })

            Logger.debug("Created notification for profile match: #{profile.name}")
            :ok

          {:error, error} ->
            Logger.error("Failed to create notification: #{inspect(error)}")
            {:error, error}
        end

      {:error, error} ->
        Logger.warning("Profile not found for notification: #{profile_id} - #{inspect(error)}")
        {:error, :profile_not_found}
    end
  end

  @doc """
  Create notifications for multiple profile matches from a single killmail.
  """
  @spec create_batch_match_notifications(map(), [String.t()]) :: :ok
  def create_batch_match_notifications(killmail, matched_profile_ids) do
    # Group profiles by user to avoid duplicate notifications
    profiles_by_user = get_profiles_by_user(matched_profile_ids)

    Enum.each(profiles_by_user, fn {user_id, user_profiles} ->
      # Create a single notification for all matched profiles for this user
      create_user_batch_notification(user_id, user_profiles, killmail)
    end)

    :ok
  end

  @doc """
  Create a system notification (not tied to a specific profile).
  """
  @spec create_system_notification(String.t(), String.t(), String.t(), map(), atom()) ::
          :ok | {:error, term()}
  def create_system_notification(user_id, title, message, data \\ %{}, priority \\ :normal) do
    notification_data = %{
      user_id: user_id,
      notification_type: :system_alert,
      title: title,
      message: message,
      data: data,
      priority: priority
    }

    case Ash.create(Notification, notification_data, domain: Api) do
      {:ok, notification} ->
        broadcast_to_user(user_id, "new_notification", %{notification: notification})
        :ok

      {:error, error} ->
        Logger.error("Failed to create system notification: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Mark a notification as read.
  """
  @spec mark_notification_read(String.t()) :: :ok | {:error, term()}
  def mark_notification_read(notification_id) do
    case Ash.get(Notification, notification_id, domain: Api) do
      {:ok, notification} ->
        case Ash.update(notification, action: :mark_read, domain: Api) do
          {:ok, _} -> :ok
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get unread notification count for a user.
  """
  @spec get_unread_count(String.t()) :: integer()
  def get_unread_count(user_id) do
    case Ash.read(Notification, action: :unread_for_user, input: %{user_id: user_id}, domain: Api) do
      {:ok, notifications} -> length(notifications)
      {:error, _} -> 0
    end
  end

  @doc """
  Get recent notifications for a user.
  """
  @spec get_recent_notifications(String.t(), integer()) :: [Notification.t()]
  def get_recent_notifications(user_id, hours \\ 24) do
    case Ash.read(Notification,
           action: :recent_for_user,
           input: %{user_id: user_id, hours: hours},
           domain: Api
         ) do
      {:ok, notifications} -> notifications
      {:error, _} -> []
    end
  end

  # Private helper functions

  defp build_match_message(_profile, killmail) do
    victim_name = get_in(killmail, ["victim", "character_name"]) || "Unknown Pilot"
    victim_ship = get_in(killmail, ["victim", "ship_name"]) || "Unknown Ship"
    system_name = killmail["solar_system_name"] || "Unknown System"

    value = killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]) || 0
    value_formatted = format_isk_value(value)

    "#{victim_name} lost a #{victim_ship} (#{value_formatted} ISK) in #{system_name}"
  end

  defp extract_killmail_summary(killmail) do
    %{
      killmail_id: killmail["killmail_id"],
      victim_name: get_in(killmail, ["victim", "character_name"]),
      victim_ship: get_in(killmail, ["victim", "ship_name"]),
      system_name: killmail["solar_system_name"],
      total_value: killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]),
      attacker_count: killmail["attacker_count"] || length(killmail["attackers"] || [])
    }
  end

  defp determine_priority(killmail, profile) do
    value = killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]) || 0

    cond do
      # 10B+ ISK
      value > 10_000_000_000 -> :urgent
      # 1B+ ISK
      value > 1_000_000_000 -> :high
      String.contains?(String.downcase(profile.name), ["high"]) -> :high
      true -> :normal
    end
  end

  defp get_profiles_by_user(profile_ids) do
    case Ash.read(Profile, domain: Api) do
      {:ok, all_profiles} ->
        profiles = Enum.filter(all_profiles, &(&1.id in profile_ids))
        Enum.group_by(profiles, & &1.user_id)

      _ ->
        %{}
    end
  end

  defp create_user_batch_notification(user_id, user_profiles, killmail) do
    title =
      if length(user_profiles) == 1 do
        "Surveillance Alert: #{hd(user_profiles).name}"
      else
        "Multiple Surveillance Alerts (#{length(user_profiles)})"
      end

    message = build_batch_message(user_profiles, killmail)

    notification_data = %{
      user_id: user_id,
      notification_type: :profile_match,
      killmail_id: killmail["killmail_id"],
      title: title,
      message: message,
      data: %{
        killmail: extract_killmail_summary(killmail),
        matched_profiles: Enum.map(user_profiles, &%{id: &1.id, name: &1.name}),
        profile_count: length(user_profiles)
      },
      priority: determine_batch_priority(killmail, user_profiles)
    }

    case Ash.create(Notification, notification_data, domain: Api) do
      {:ok, notification} ->
        broadcast_to_user(user_id, "new_notification", %{
          notification: notification,
          killmail: killmail,
          profiles: user_profiles
        })

      {:error, error} ->
        Logger.error("Failed to create batch notification for user #{user_id}: #{inspect(error)}")
    end
  end

  defp build_batch_message(profiles, killmail) do
    victim_name = get_in(killmail, ["victim", "character_name"]) || "Unknown Pilot"
    victim_ship = get_in(killmail, ["victim", "ship_name"]) || "Unknown Ship"
    system_name = killmail["solar_system_name"] || "Unknown System"

    value = killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]) || 0
    value_formatted = format_isk_value(value)

    mapped_names = Enum.map(profiles, & &1.name)
    profile_names = mapped_names |> Enum.take(3) |> Enum.join(", ")
    more_text = if length(profiles) > 3, do: " and #{length(profiles) - 3} more", else: ""

    "#{victim_name} lost a #{victim_ship} (#{value_formatted} ISK) in #{system_name} - matched profiles: #{profile_names}#{more_text}"
  end

  defp determine_batch_priority(killmail, profiles) do
    value = killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]) || 0

    has_urgent_profiles =
      Enum.any?(profiles, &String.contains?(String.downcase(&1.name), ["urgent", "priority"]))

    cond do
      value > 10_000_000_000 or has_urgent_profiles -> :urgent
      value > 1_000_000_000 or length(profiles) > 3 -> :high
      true -> :normal
    end
  end

  defp broadcast_to_user(user_id, event, payload) do
    # Broadcast to user-specific channel
    user_topic = "user:#{user_id}"
    Endpoint.broadcast(user_topic, event, payload)

    # Also broadcast to general surveillance channel for LiveView updates
    Endpoint.broadcast("surveillance", event, Map.put(payload, :user_id, user_id))
  end

  defp format_isk_value(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{value}"
    end
  end

  defp format_isk_value(_), do: "0"
end
