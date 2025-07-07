defmodule EveDmv.Contexts.Surveillance.Domain.NotificationService do
  @moduledoc """
  Notification delivery service for surveillance alerts.

  Handles the delivery of surveillance alerts through various channels
  including email, webhooks, and in-app notifications.
  """

  use GenServer
  use EveDmv.ErrorHandler
  alias EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository
  alias EveDmv.Result

  require Logger

  # Notification channels
  @channel_email "email"
  @channel_webhook "webhook"
  @channel_in_app "in_app"

  # Delivery status
  @status_pending "pending"
  @status_sent "sent"
  @status_failed "failed"
  @status_rate_limited "rate_limited"

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Send alert notification for a surveillance match.
  """
  def send_alert_notification(alert) do
    GenServer.cast(__MODULE__, {:send_alert_notification, alert})
  end

  @doc """
  Configure notifications for a profile.
  """
  def configure_notifications(profile_id, notification_config) do
    GenServer.call(__MODULE__, {:configure_notifications, profile_id, notification_config})
  end

  @doc """
  Get notification history for a profile.
  """
  def get_notification_history(profile_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_notification_history, profile_id, opts})
  end

  @doc """
  Test notification delivery for a profile.
  """
  def test_notification_delivery(profile_id) do
    GenServer.call(__MODULE__, {:test_notification_delivery, profile_id})
  end

  @doc """
  Get notification statistics and metrics.
  """
  def get_notification_metrics(time_range \\ :last_24h) do
    GenServer.call(__MODULE__, {:get_notification_metrics, time_range})
  end

  @doc """
  Update notification delivery status.
  """
  def update_delivery_status(notification_id, status, error_message \\ nil) do
    GenServer.cast(__MODULE__, {:update_delivery_status, notification_id, status, error_message})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      # notification_id -> notification_data
      notifications: %{},
      # Queue of pending notifications
      delivery_queue: [],
      # profile_id -> rate limit tracking
      rate_limits: %{},
      metrics: %{
        total_sent: 0,
        total_failed: 0,
        total_rate_limited: 0,
        last_reset: DateTime.utc_now()
      },
      # profile_id -> [notifications]
      notification_history: %{}
    }

    # Start delivery worker
    schedule_delivery_worker()

    # Start rate limit reset worker
    schedule_rate_limit_reset()

    Logger.info("NotificationService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:send_alert_notification, alert}, state) do
    # Get profile notification configuration
    case ProfileRepository.get_profile(alert.profile_id) do
      {:ok, profile} ->
        notifications = prepare_notifications(alert, profile)

        # Add to delivery queue with rate limiting check
        {queued_notifications, new_rate_limits} =
          Enum.reduce(notifications, {[], state.rate_limits}, fn notification,
                                                                 {queue_acc, rate_limits_acc} ->
            case check_rate_limit(alert.profile_id, rate_limits_acc) do
              {:ok, updated_limits} ->
                {[notification | queue_acc], updated_limits}

              {:error, :rate_limited} ->
                rate_limited_notification = %{notification | status: @status_rate_limited}
                Logger.warning("Rate limited notification for profile #{alert.profile_id}")
                {[rate_limited_notification | queue_acc], rate_limits_acc}
            end
          end)

        # Update state
        new_delivery_queue = state.delivery_queue ++ queued_notifications

        new_state = %{
          state
          | delivery_queue: new_delivery_queue,
            rate_limits: new_rate_limits
        }

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error(
          "Failed to get profile #{alert.profile_id} for notification: #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:update_delivery_status, notification_id, status, error_message}, state) do
    case Map.get(state.notifications, notification_id) do
      nil ->
        Logger.warning("Attempted to update unknown notification: #{notification_id}")
        {:noreply, state}

      notification ->
        updated_notification = %{
          notification
          | status: status,
            delivered_at:
              if(status == @status_sent, do: DateTime.utc_now(), else: notification.delivered_at),
            error_message: error_message,
            updated_at: DateTime.utc_now()
        }

        new_notifications = Map.put(state.notifications, notification_id, updated_notification)

        # Update metrics
        new_metrics = update_delivery_metrics(state.metrics, status)

        # Update notification history
        new_history =
          add_to_notification_history(state.notification_history, updated_notification)

        new_state = %{
          state
          | notifications: new_notifications,
            metrics: new_metrics,
            notification_history: new_history
        }

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_call({:configure_notifications, profile_id, notification_config}, _from, state) do
    # Validate configuration
    case validate_notification_config(notification_config) do
      {:ok, validated_config} ->
        # Update profile with new notification configuration
        case ProfileRepository.update_profile(profile_id, %{notification_config: validated_config}) do
          {:ok, _updated_profile} ->
            Logger.info("Updated notification config for profile #{profile_id}")
            {:reply, {:ok, validated_config}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_notification_history, profile_id, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 50)
    since = Keyword.get(opts, :since)

    profile_history = Map.get(state.notification_history, profile_id, [])

    filtered_history =
      if since do
        Enum.filter(profile_history, fn notification ->
          DateTime.compare(notification.created_at, since) == :gt
        end)
      else
        profile_history
      end

    limited_history = Enum.take(filtered_history, limit)

    {:reply, {:ok, limited_history}, state}
  end

  @impl GenServer
  def handle_call({:test_notification_delivery, profile_id}, _from, state) do
    case ProfileRepository.get_profile(profile_id) do
      {:ok, profile} ->
        test_alert = create_test_alert(profile_id)
        test_notifications = prepare_notifications(test_alert, profile)

        # Send test notifications immediately (bypass rate limiting)
        test_results =
          Enum.map(test_notifications, fn notification ->
            case deliver_notification(notification) do
              {:ok, result} -> {:ok, notification.channel, result}
              {:error, reason} -> {:error, notification.channel, reason}
            end
          end)

        {:reply, {:ok, test_results}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_notification_metrics, time_range}, _from, state) do
    metrics = calculate_notification_metrics(state, time_range)
    {:reply, {:ok, metrics}, state}
  end

  @impl GenServer
  def handle_info(:process_delivery_queue, state) do
    # Process pending notifications in delivery queue
    {processed_notifications, remaining_queue} = process_delivery_queue(state.delivery_queue)

    # Update notifications store
    new_notifications =
      Enum.reduce(processed_notifications, state.notifications, fn notification, acc ->
        Map.put(acc, notification.id, notification)
      end)

    # Update notification history
    new_history =
      Enum.reduce(processed_notifications, state.notification_history, fn notification, acc ->
        add_to_notification_history(acc, notification)
      end)

    # Schedule next delivery cycle
    schedule_delivery_worker()

    new_state = %{
      state
      | notifications: new_notifications,
        delivery_queue: remaining_queue,
        notification_history: new_history
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:reset_rate_limits, state) do
    # Reset rate limits for new period
    new_rate_limits =
      Map.new(state.rate_limits, fn {profile_id, limits} ->
        current_time = DateTime.utc_now()
        reset_time = DateTime.add(current_time, 3600, :second)
        {profile_id, %{limits | current_count: 0, reset_at: reset_time}}
      end)

    # Schedule next reset
    schedule_rate_limit_reset()

    new_state = %{state | rate_limits: new_rate_limits}

    Logger.debug("Reset notification rate limits")
    {:noreply, new_state}
  end

  # Private functions

  defp prepare_notifications(alert, profile) do
    notification_config = profile.notification_config || %{}

    enabled_channels = get_enabled_channels(notification_config)

    Enum.map(enabled_channels, fn channel ->
      %{
        id: generate_notification_id(),
        alert_id: alert.id,
        profile_id: alert.profile_id,
        channel: channel,
        status: @status_pending,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        delivered_at: nil,
        error_message: nil,
        content: generate_notification_content(alert, channel),
        delivery_config: Map.get(notification_config, channel, %{})
      }
    end)
  end

  defp get_enabled_channels(notification_config) do
    Enum.filter([@channel_email, @channel_webhook, @channel_in_app], fn channel ->
      channel_config = Map.get(notification_config, channel, %{})
      Map.get(channel_config, :enabled, false)
    end)
  end

  defp generate_notification_content(alert, channel) do
    base_content = %{
      alert_id: alert.id,
      profile_id: alert.profile_id,
      priority: alert.priority,
      alert_type: alert.alert_type,
      confidence_score: alert.confidence_score,
      matched_criteria: alert.matched_criteria,
      timestamp: alert.created_at
    }

    case channel do
      @channel_email ->
        email_content = %{
          subject: format_email_subject(alert),
          body: format_email_body(alert),
          html_body: format_html_email_body(alert)
        }

        Map.merge(email_content, base_content)

      @channel_webhook ->
        webhook_content = %{
          payload: Jason.encode!(base_content),
          headers: %{"Content-Type" => "application/json"}
        }

        Map.merge(webhook_content, base_content)

      @channel_in_app ->
        in_app_content = %{
          title: format_in_app_title(alert),
          message: format_in_app_message(alert),
          action_url: "/surveillance/alerts/#{alert.id}"
        }

        Map.merge(in_app_content, base_content)
    end
  end

  defp format_email_subject(alert) do
    priority_prefix =
      case alert.priority do
        1 -> "[CRITICAL]"
        2 -> "[HIGH]"
        3 -> "[MEDIUM]"
        4 -> "[LOW]"
      end

    "#{priority_prefix} Surveillance Alert - #{format_alert_type_description(alert.alert_type)}"
  end

  defp format_email_body(alert) do
    """
    Surveillance Alert Notification

    Alert ID: #{alert.id}
    Priority: #{format_priority_name(alert.priority)}
    Type: #{format_alert_type_description(alert.alert_type)}
    Confidence: #{Float.round(alert.confidence_score * 100, 1)}%
    Timestamp: #{DateTime.to_string(alert.created_at)}

    Matched Criteria:
    #{format_matched_criteria_text(alert.matched_criteria)}

    View alert details: [Link would be here in production]
    """
  end

  defp format_html_email_body(alert) do
    # HTML version of email body - simplified for this implementation
    email_body = format_email_body(alert)

    email_body
    |> String.replace("\n", "<br>")
    |> String.replace("  ", "&nbsp;&nbsp;")
  end

  defp format_in_app_title(alert) do
    "#{format_alert_type_description(alert.alert_type)} Alert"
  end

  defp format_in_app_message(alert) do
    "#{format_priority_name(alert.priority)} priority surveillance alert detected with #{Float.round(alert.confidence_score * 100, 1)}% confidence"
  end

  defp format_alert_type_description(alert_type) do
    case alert_type do
      :target_killed -> "Target Eliminated"
      :target_active -> "Target Activity Detected"
      :location_activity -> "Location Activity"
      :general_match -> "Profile Match"
      _ -> "Unknown Alert"
    end
  end

  defp format_priority_name(priority) do
    case priority do
      1 -> "Critical"
      2 -> "High"
      3 -> "Medium"
      4 -> "Low"
      _ -> "Unknown"
    end
  end

  defp format_matched_criteria_text(matched_criteria) do
    Enum.map_join(matched_criteria, "\n", fn criterion ->
      "- #{String.capitalize(to_string(criterion.type))}: #{inspect(Map.delete(criterion, :type))}"
    end)
  end

  defp check_rate_limit(profile_id, rate_limits) do
    current_time = DateTime.utc_now()

    profile_limits =
      Map.get(rate_limits, profile_id, %{
        current_count: 0,
        max_per_hour: 10,
        reset_at: DateTime.add(current_time, 3600, :second)
      })

    if DateTime.compare(current_time, profile_limits.reset_at) == :gt do
      # Reset period has passed
      new_limits = %{
        profile_limits
        | current_count: 1,
          reset_at: DateTime.add(current_time, 3600, :second)
      }

      {:ok, Map.put(rate_limits, profile_id, new_limits)}
    else
      if profile_limits.current_count >= profile_limits.max_per_hour do
        {:error, :rate_limited}
      else
        new_limits = %{profile_limits | current_count: profile_limits.current_count + 1}
        {:ok, Map.put(rate_limits, profile_id, new_limits)}
      end
    end
  end

  defp process_delivery_queue(delivery_queue) do
    # Process up to 10 notifications per cycle to avoid blocking
    {to_process, remaining} = Enum.split(delivery_queue, 10)

    processed =
      Enum.map(to_process, fn notification ->
        case deliver_notification(notification) do
          {:ok, _result} ->
            %{
              notification
              | status: @status_sent,
                delivered_at: DateTime.utc_now(),
                updated_at: DateTime.utc_now()
            }

          {:error, reason} ->
            %{
              notification
              | status: @status_failed,
                error_message: to_string(reason),
                updated_at: DateTime.utc_now()
            }
        end
      end)

    {processed, remaining}
  end

  defp deliver_notification(notification) do
    case notification.channel do
      @channel_email ->
        deliver_email_notification(notification)

      @channel_webhook ->
        deliver_webhook_notification(notification)

      @channel_in_app ->
        deliver_in_app_notification(notification)

      _ ->
        {:error, :unknown_channel}
    end
  end

  defp deliver_email_notification(notification) do
    # In a real implementation, this would integrate with an email service
    # For now, we'll simulate successful delivery
    Logger.info("Simulated email delivery for alert #{notification.alert_id}")
    {:ok, :simulated_email_sent}
  end

  defp deliver_webhook_notification(notification) do
    # In a real implementation, this would make HTTP requests to configured webhooks
    # For now, we'll simulate successful delivery
    Logger.info("Simulated webhook delivery for alert #{notification.alert_id}")
    {:ok, :simulated_webhook_sent}
  end

  defp deliver_in_app_notification(notification) do
    # In a real implementation, this would use Phoenix.PubSub to broadcast to connected users
    # For now, we'll simulate successful delivery
    Logger.info("Simulated in-app notification for alert #{notification.alert_id}")
    {:ok, :simulated_in_app_sent}
  end

  defp validate_notification_config(config) when is_map(config) do
    # Validate each channel configuration
    result =
      Enum.reduce_while(config, {:ok, %{}}, fn {channel, channel_config}, {:ok, acc} ->
        case validate_channel_config(channel, channel_config) do
          {:ok, validated_config} -> {:cont, {:ok, Map.put(acc, channel, validated_config)}}
          {:error, reason} -> {:halt, {:error, {channel, reason}}}
        end
      end)

    result
  end

  defp validate_notification_config(_), do: {:error, :invalid_config_format}

  defp validate_channel_config(@channel_email, config) do
    if Map.get(config, :enabled, false) do
      if Map.has_key?(config, :email_address) and is_binary(config.email_address) do
        {:ok, config}
      else
        {:error, :missing_email_address}
      end
    else
      {:ok, config}
    end
  end

  defp validate_channel_config(@channel_webhook, config) do
    if Map.get(config, :enabled, false) do
      if Map.has_key?(config, :webhook_url) and is_binary(config.webhook_url) do
        {:ok, config}
      else
        {:error, :missing_webhook_url}
      end
    else
      {:ok, config}
    end
  end

  defp validate_channel_config(@channel_in_app, config) do
    # In-app notifications don't require additional configuration
    {:ok, config}
  end

  defp validate_channel_config(channel, _config) do
    {:error, {:unsupported_channel, channel}}
  end

  defp create_test_alert(profile_id) do
    %{
      id: "test-alert-#{System.unique_integer()}",
      profile_id: profile_id,
      # Medium priority for test
      priority: 3,
      alert_type: :general_match,
      confidence_score: 0.75,
      matched_criteria: [%{type: :test, message: "This is a test alert"}],
      created_at: DateTime.utc_now()
    }
  end

  defp update_delivery_metrics(metrics, status) do
    case status do
      @status_sent -> %{metrics | total_sent: metrics.total_sent + 1}
      @status_failed -> %{metrics | total_failed: metrics.total_failed + 1}
      @status_rate_limited -> %{metrics | total_rate_limited: metrics.total_rate_limited + 1}
      _ -> metrics
    end
  end

  defp add_to_notification_history(history, notification) do
    profile_history = Map.get(history, notification.profile_id, [])

    # Keep last 100 notifications per profile
    new_profile_history = [notification | Enum.take(profile_history, 99)]

    Map.put(history, notification.profile_id, new_profile_history)
  end

  defp calculate_notification_metrics(state, time_range) do
    current_time = DateTime.utc_now()

    cutoff_time =
      case time_range do
        :last_hour -> DateTime.add(current_time, -3600, :second)
        :last_24h -> DateTime.add(current_time, -24 * 3600, :second)
        :last_7d -> DateTime.add(current_time, -7 * 24 * 3600, :second)
        :last_30d -> DateTime.add(current_time, -30 * 24 * 3600, :second)
      end

    recent_notifications =
      state.notifications
      |> Map.values()
      |> Enum.filter(&(DateTime.compare(&1.created_at, cutoff_time) == :gt))

    channel_distribution =
      recent_notifications
      |> Enum.group_by(& &1.channel)
      |> Map.new(fn {channel, notifications} -> {channel, length(notifications)} end)

    status_distribution =
      recent_notifications
      |> Enum.group_by(& &1.status)
      |> Map.new(fn {status, notifications} -> {status, length(notifications)} end)

    %{
      time_range: time_range,
      total_notifications: length(recent_notifications),
      channel_distribution: channel_distribution,
      status_distribution: status_distribution,
      success_rate: calculate_success_rate(recent_notifications),
      current_rate_limits: map_size(state.rate_limits)
    }
  end

  defp calculate_success_rate(notifications) do
    if Enum.empty?(notifications) do
      0.0
    else
      successful = Enum.count(notifications, &(&1.status == @status_sent))
      successful / length(notifications)
    end
  end

  defp schedule_delivery_worker do
    # Process delivery queue every 5 seconds
    Process.send_after(self(), :process_delivery_queue, 5_000)
  end

  defp schedule_rate_limit_reset do
    # Reset rate limits every hour
    Process.send_after(self(), :reset_rate_limits, 60 * 60 * 1000)
  end

  defp generate_notification_id do
    random_bytes = :crypto.strong_rand_bytes(16)
    Base.encode16(random_bytes, case: :lower)
  end
end
