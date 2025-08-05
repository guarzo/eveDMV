defmodule EveDmv.Contexts.ThreatSurveillance.Domain.NotificationService do
  @moduledoc """
  Service for delivering surveillance and threat notifications.

  Handles multi-channel notification delivery including in-app notifications,
  webhooks, email alerts, and real-time push notifications.
  """

  use GenServer

  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias Phoenix.PubSub

  require Logger

  # Notification channels
  @channels [:in_app, :webhook, :email, :push, :discord]

  # Rate limiting
  # 1 minute
  @rate_limit_window 60_000
  # Max 10 notifications per user per minute
  @rate_limit_count 10

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Send notification for surveillance match.
  """
  def send_match_notification(match_data) do
    GenServer.cast(__MODULE__, {:send_match_notification, match_data})
  end

  @doc """
  Send threat level alert.
  """
  def send_threat_alert(threat_data) do
    GenServer.cast(__MODULE__, {:send_threat_alert, threat_data})
  end

  @doc """
  Send custom notification.
  """
  def send_notification(user_id, notification_data, channels \\ [:in_app]) do
    GenServer.cast(__MODULE__, {:send_notification, user_id, notification_data, channels})
  end

  @doc """
  Configure notification preferences for a user.
  """
  def configure_user_preferences(user_id, preferences) do
    GenServer.call(__MODULE__, {:configure_user_preferences, user_id, preferences})
  end

  @doc """
  Get notification statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Process a surveillance match event.
  """
  def process_surveillance_match(event) do
    # Convert event to match data format
    match_data = %{
      user_id: event.profile.user_id,
      profile_id: event.profile_id,
      killmail_id: event.killmail_id,
      match_type: event.match_type,
      confidence: event.confidence,
      timestamp: DateTime.utc_now()
    }

    send_match_notification(match_data)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      notifications_sent: 0,
      failed_deliveries: 0,
      channel_stats: Enum.map(@channels, &{&1, 0}) |> Map.new(),
      rate_limits: %{},
      user_preferences: %{}
    }

    Logger.info("NotificationService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:send_match_notification, match_data}, state) do
    user_id = match_data[:user_id] || match_data.user_id

    notification = %{
      id: generate_notification_id(),
      type: :surveillance_match,
      user_id: user_id,
      title: "Surveillance Match Detected",
      message: format_match_message(match_data),
      data: sanitize_match_data(match_data),
      priority: determine_match_priority(match_data),
      created_at: DateTime.utc_now()
    }

    channels = get_user_notification_channels(user_id, :surveillance_match)

    case deliver_notification(notification, channels, state) do
      {:ok, _delivery_results, updated_state} ->
        Logger.info("Sent surveillance match notification to user #{user_id}")
        {:noreply, updated_state}

      {:error, reason, updated_state} ->
        Logger.error("Failed to send surveillance match notification: #{inspect(reason)}")
        {:noreply, %{updated_state | failed_deliveries: updated_state.failed_deliveries + 1}}
    end
  rescue
    error ->
      Logger.error("Failed to process surveillance match notification: #{inspect(error)}")
      {:noreply, %{state | failed_deliveries: state.failed_deliveries + 1}}
  end

  @impl GenServer
  def handle_cast({:send_threat_alert, threat_data}, state) do
    user_id = threat_data[:user_id] || threat_data.user_id

    notification = %{
      id: generate_notification_id(),
      type: :threat_alert,
      user_id: user_id,
      title: "Threat Level Alert",
      message: format_threat_message(threat_data),
      data: sanitize_threat_data(threat_data),
      priority: determine_threat_priority(threat_data),
      created_at: DateTime.utc_now()
    }

    channels = get_user_notification_channels(user_id, :threat_alert)

    case deliver_notification(notification, channels, state) do
      {:ok, _delivery_results, updated_state} ->
        Logger.info("Sent threat alert notification to user #{user_id}")
        {:noreply, updated_state}

      {:error, reason, updated_state} ->
        Logger.error("Failed to send threat alert notification: #{inspect(reason)}")
        {:noreply, %{updated_state | failed_deliveries: updated_state.failed_deliveries + 1}}
    end
  rescue
    error ->
      Logger.error("Failed to process threat alert notification: #{inspect(error)}")
      {:noreply, %{state | failed_deliveries: state.failed_deliveries + 1}}
  end

  @impl GenServer
  def handle_cast({:send_notification, user_id, notification_data, channels}, state) do
    notification = %{
      id: generate_notification_id(),
      type: :custom,
      user_id: user_id,
      title: notification_data[:title] || "Notification",
      message: notification_data[:message] || "",
      data: notification_data[:data] || %{},
      priority: notification_data[:priority] || :normal,
      created_at: DateTime.utc_now()
    }

    case deliver_notification(notification, channels, state) do
      {:ok, _delivery_results, updated_state} ->
        Logger.debug("Sent custom notification to user #{user_id}")
        {:noreply, updated_state}

      {:error, reason, updated_state} ->
        Logger.error("Failed to send custom notification: #{inspect(reason)}")
        {:noreply, %{updated_state | failed_deliveries: updated_state.failed_deliveries + 1}}
    end
  rescue
    error ->
      Logger.error("Failed to process custom notification: #{inspect(error)}")
      {:noreply, %{state | failed_deliveries: state.failed_deliveries + 1}}
  end

  @impl GenServer
  def handle_call({:configure_user_preferences, user_id, preferences}, _from, state) do
    validated_preferences = validate_user_preferences(preferences)

    # Cache preferences
    cache_key = {:notification_preferences, user_id}
    # 1 hour
    UnifiedCache.put(:surveillance, cache_key, validated_preferences, 3600)

    updated_state = %{
      state
      | user_preferences: Map.put(state.user_preferences, user_id, validated_preferences)
    }

    {:reply, {:ok, validated_preferences}, updated_state}
  rescue
    error ->
      Logger.error("Failed to configure user preferences: #{inspect(error)}")
      {:reply, {:error, :configuration_failed}, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      notifications_sent: state.notifications_sent,
      failed_deliveries: state.failed_deliveries,
      success_rate: calculate_success_rate(state),
      channel_stats: state.channel_stats,
      active_users: map_size(state.user_preferences)
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  # Private functions

  defp deliver_notification(notification, channels, state) do
    # Check rate limiting
    case check_rate_limit(notification.user_id, state) do
      {:ok, updated_rate_limits} ->
        # Deliver to all channels
        delivery_results =
          Enum.map(channels, fn channel ->
            deliver_to_channel(notification, channel)
          end)

        # Update statistics
        successful_deliveries = Enum.count(delivery_results, &match?({:ok, _}, &1))
        failed_deliveries = length(delivery_results) - successful_deliveries

        updated_channel_stats =
          Enum.reduce(channels, state.channel_stats, fn channel, acc ->
            Map.update(acc, channel, 1, &(&1 + 1))
          end)

        updated_state = %{
          state
          | notifications_sent: state.notifications_sent + successful_deliveries,
            failed_deliveries: state.failed_deliveries + failed_deliveries,
            channel_stats: updated_channel_stats,
            rate_limits: updated_rate_limits
        }

        if successful_deliveries > 0 do
          {:ok, delivery_results, updated_state}
        else
          {:error, :all_deliveries_failed, updated_state}
        end

      {:error, :rate_limited} ->
        Logger.warning("Rate limit exceeded for user #{notification.user_id}")
        {:error, :rate_limited, state}
    end
  end

  defp deliver_to_channel(notification, channel) do
    case channel do
      :in_app ->
        deliver_in_app_notification(notification)

      :webhook ->
        deliver_webhook_notification(notification)

      :email ->
        deliver_email_notification(notification)

      :push ->
        deliver_push_notification(notification)

      :discord ->
        deliver_discord_notification(notification)

      _ ->
        {:error, :unsupported_channel}
    end
  end

  defp deliver_in_app_notification(notification) do
    # Publish to PubSub for real-time delivery
    PubSub.broadcast(
      EveDmv.PubSub,
      "user:#{notification.user_id}:notifications",
      {:new_notification, notification}
    )

    # Store in database for persistence
    store_notification_in_database(notification)

    {:ok, :delivered}
  rescue
    error ->
      Logger.error("Failed to deliver in-app notification: #{inspect(error)}")
      {:error, :delivery_failed}
  end

  defp deliver_webhook_notification(notification) do
    # Get user's webhook URL
    case get_user_webhook_url(notification.user_id) do
      {:ok, webhook_url} ->
        # Send HTTP POST to webhook
        payload =
          Jason.encode!(%{
            id: notification.id,
            type: notification.type,
            title: notification.title,
            message: notification.message,
            data: notification.data,
            timestamp: notification.created_at
          })

        case HTTPoison.post(webhook_url, payload, [{"Content-Type", "application/json"}]) do
          {:ok, %{status_code: status}} when status in 200..299 ->
            {:ok, :delivered}

          {:ok, %{status_code: status}} ->
            {:error, {:http_error, status}}

          {:error, reason} ->
            {:error, {:request_failed, reason}}
        end

      {:error, :not_configured} ->
        {:error, :webhook_not_configured}
    end
  end

  defp deliver_email_notification(notification) do
    # Get user's email address
    case get_user_email(notification.user_id) do
      {:ok, email} ->
        # Send email using Phoenix.Swoosh or similar
        case send_notification_email(email, notification) do
          {:ok, _} -> {:ok, :delivered}
          error -> error
        end

      {:error, :not_configured} ->
        {:error, :email_not_configured}
    end
  end

  defp deliver_push_notification(notification) do
    # Get user's push subscription
    case get_user_push_subscription(notification.user_id) do
      {:ok, subscription} ->
        # Send push notification using web push or similar
        case send_push_notification(subscription, notification) do
          {:ok, _} -> {:ok, :delivered}
          error -> error
        end

      {:error, :not_configured} ->
        {:error, :push_not_configured}
    end
  end

  defp deliver_discord_notification(notification) do
    # Get user's Discord webhook
    case get_user_discord_webhook(notification.user_id) do
      {:ok, webhook_url} ->
        # Send Discord webhook
        case send_discord_webhook(webhook_url, notification) do
          {:ok, _} -> {:ok, :delivered}
          error -> error
        end

      {:error, :not_configured} ->
        {:error, :discord_not_configured}
    end
  end

  # Helper functions

  defp format_match_message(match_data) do
    profile_name = match_data[:profile_name] || "Unknown Profile"
    killmail_id = match_data[:killmail_id] || "Unknown"
    confidence = match_data[:confidence_score] || 0.0

    "Surveillance profile '#{profile_name}' matched killmail #{killmail_id} with #{Float.round(confidence * 100, 1)}% confidence"
  end

  defp format_threat_message(threat_data) do
    entity_type = threat_data[:entity_type] || :unknown
    entity_id = threat_data[:entity_id] || "Unknown"
    threat_level = threat_data[:threat_level] || :unknown

    "#{String.capitalize(to_string(entity_type))} #{entity_id} threat level changed to #{threat_level}"
  end

  defp sanitize_match_data(match_data) do
    # Remove sensitive data before including in notification
    %{
      profile_id: match_data[:profile_id],
      killmail_id: match_data[:killmail_id],
      confidence_score: match_data[:confidence_score],
      matched_at: match_data[:matched_at]
    }
  end

  defp sanitize_threat_data(threat_data) do
    # Remove sensitive data before including in notification
    %{
      entity_type: threat_data[:entity_type],
      entity_id: threat_data[:entity_id],
      threat_level: threat_data[:threat_level],
      threat_score: threat_data[:threat_score]
    }
  end

  defp determine_match_priority(match_data) do
    confidence = match_data[:confidence_score] || 0.0

    cond do
      confidence >= 0.9 -> :critical
      confidence >= 0.7 -> :high
      confidence >= 0.5 -> :normal
      true -> :low
    end
  end

  defp determine_threat_priority(threat_data) do
    threat_level = threat_data[:threat_level] || :low

    case threat_level do
      :critical -> :critical
      :high -> :high
      :medium -> :normal
      _ -> :low
    end
  end

  defp get_user_notification_channels(user_id, notification_type) do
    # Get user preferences from cache or database
    case UnifiedCache.get(:surveillance, {:notification_preferences, user_id}) do
      {:ok, preferences} ->
        Map.get(preferences, notification_type, [:in_app])

      {:error, :not_found} ->
        # Default to in-app notifications
        [:in_app]
    end
  end

  defp validate_user_preferences(preferences) do
    # Validate and sanitize user notification preferences
    validated = %{
      surveillance_match: validate_channels(Map.get(preferences, :surveillance_match, [:in_app])),
      threat_alert: validate_channels(Map.get(preferences, :threat_alert, [:in_app])),
      custom: validate_channels(Map.get(preferences, :custom, [:in_app])),
      quiet_hours: validate_quiet_hours(Map.get(preferences, :quiet_hours, %{})),
      rate_limit: validate_rate_limit(Map.get(preferences, :rate_limit, @rate_limit_count))
    }

    validated
  end

  defp validate_channels(channels) when is_list(channels) do
    Enum.filter(channels, &(&1 in @channels))
  end

  defp validate_channels(_), do: [:in_app]

  defp validate_quiet_hours(quiet_hours) when is_map(quiet_hours) do
    %{
      enabled: Map.get(quiet_hours, :enabled, false),
      start_hour: max(0, min(23, Map.get(quiet_hours, :start_hour, 22))),
      end_hour: max(0, min(23, Map.get(quiet_hours, :end_hour, 8))),
      timezone: Map.get(quiet_hours, :timezone, "UTC")
    }
  end

  defp validate_quiet_hours(_), do: %{enabled: false}

  defp validate_rate_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100 do
    limit
  end

  defp validate_rate_limit(_), do: @rate_limit_count

  defp check_rate_limit(user_id, state) do
    current_time = System.system_time(:millisecond)
    window_start = current_time - @rate_limit_window

    # Get current rate limit data for user
    current_limits = Map.get(state.rate_limits, user_id, [])

    # Filter out old entries
    recent_limits = Enum.filter(current_limits, &(&1 > window_start))

    if length(recent_limits) < @rate_limit_count do
      # Allow notification and update rate limits
      updated_limits = [current_time | recent_limits]
      updated_rate_limits = Map.put(state.rate_limits, user_id, updated_limits)
      {:ok, updated_rate_limits}
    else
      # Rate limit exceeded
      {:error, :rate_limited}
    end
  end

  defp calculate_success_rate(state) do
    total = state.notifications_sent + state.failed_deliveries

    if total > 0 do
      Float.round(state.notifications_sent / total, 3)
    else
      0.0
    end
  end

  defp generate_notification_id do
    "notification_#{System.system_time(:second)}_#{:rand.uniform(10_000)}"
  end

  # Placeholder implementations for external integrations

  @spec store_notification_in_database(map()) :: {:ok, :stored}
  defp store_notification_in_database(_notification), do: {:ok, :stored}

  @spec get_user_webhook_url(integer()) :: {:ok, String.t()} | {:error, :not_configured}
  defp get_user_webhook_url(_user_id), do: {:error, :not_configured}

  @spec get_user_email(integer()) :: {:ok, String.t()} | {:error, :not_configured}
  defp get_user_email(_user_id), do: {:error, :not_configured}

  @spec get_user_push_subscription(integer()) :: {:ok, map()} | {:error, :not_configured}
  defp get_user_push_subscription(_user_id), do: {:error, :not_configured}

  @spec get_user_discord_webhook(integer()) :: {:ok, String.t()} | {:error, :not_configured}
  defp get_user_discord_webhook(_user_id), do: {:error, :not_configured}

  @spec send_notification_email(String.t(), map()) :: {:ok, :sent}
  defp send_notification_email(_email, _notification), do: {:ok, :sent}

  @spec send_push_notification(map(), map()) :: {:ok, :sent}
  defp send_push_notification(_subscription, _notification), do: {:ok, :sent}

  @spec send_discord_webhook(String.t(), map()) :: {:ok, :sent}
  defp send_discord_webhook(_webhook_url, _notification), do: {:ok, :sent}
end
