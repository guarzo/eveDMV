defmodule EveDmv.Contexts.Surveillance.Infrastructure.NotificationDispatcher do
  use EveDmv.ErrorHandler
  use GenServer

  alias EveDmv.Result

  require Logger
  @moduledoc """
  Infrastructure service for dispatching notifications to external systems.

  Handles the low-level delivery of notifications through various channels
  including email services, webhook endpoints, and real-time connections.
  """



  # HTTP client configuration
  @http_timeout 30_000
  @max_retries 3
  @retry_backoff_ms 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Dispatch an email notification.
  """
  def dispatch_email(email_data) do
    GenServer.call(__MODULE__, {:dispatch_email, email_data})
  end

  @doc """
  Dispatch a webhook notification.
  """
  def dispatch_webhook(webhook_data) do
    GenServer.call(__MODULE__, {:dispatch_webhook, webhook_data})
  end

  @doc """
  Dispatch an in-app notification.
  """
  def dispatch_in_app(notification_data) do
    GenServer.call(__MODULE__, {:dispatch_in_app, notification_data})
  end

  @doc """
  Get dispatcher health status and metrics.
  """
  def get_health_status do
    GenServer.call(__MODULE__, :get_health_status)
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      email_config: load_email_config(),
      webhook_config: load_webhook_config(),
      delivery_metrics: %{
        emails_sent: 0,
        emails_failed: 0,
        webhooks_sent: 0,
        webhooks_failed: 0,
        in_app_sent: 0,
        in_app_failed: 0,
        last_reset: DateTime.utc_now()
      },
      # Failed deliveries awaiting retry
      retry_queue: [],
      health_status: :healthy
    }

    # Schedule retry processing
    schedule_retry_processing()

    Logger.info("NotificationDispatcher started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:dispatch_email, email_data}, _from, state) do
    case send_email_notification(email_data, state.email_config) do
      {:ok, result} ->
        new_metrics = %{
          state.delivery_metrics
          | emails_sent: state.delivery_metrics.emails_sent + 1
        }

        new_state = %{state | delivery_metrics: new_metrics}
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_metrics = %{
          state.delivery_metrics
          | emails_failed: state.delivery_metrics.emails_failed + 1
        }

        # Add to retry queue if retryable
        new_retry_queue =
          if retryable_error?(reason) do
            retry_item = %{
              type: :email,
              data: email_data,
              attempts: 1,
              next_retry: DateTime.add(DateTime.utc_now(), @retry_backoff_ms, :millisecond),
              last_error: reason
            }

            [retry_item | state.retry_queue]
          else
            state.retry_queue
          end

        new_state = %{
          state
          | delivery_metrics: new_metrics,
            retry_queue: new_retry_queue
        }

        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:dispatch_webhook, webhook_data}, _from, state) do
    case send_webhook_notification(webhook_data, state.webhook_config) do
      {:ok, result} ->
        new_metrics = %{
          state.delivery_metrics
          | webhooks_sent: state.delivery_metrics.webhooks_sent + 1
        }

        new_state = %{state | delivery_metrics: new_metrics}
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_metrics = %{
          state.delivery_metrics
          | webhooks_failed: state.delivery_metrics.webhooks_failed + 1
        }

        # Add to retry queue if retryable
        new_retry_queue =
          if retryable_error?(reason) do
            retry_item = %{
              type: :webhook,
              data: webhook_data,
              attempts: 1,
              next_retry: DateTime.add(DateTime.utc_now(), @retry_backoff_ms, :millisecond),
              last_error: reason
            }

            [retry_item | state.retry_queue]
          else
            state.retry_queue
          end

        new_state = %{
          state
          | delivery_metrics: new_metrics,
            retry_queue: new_retry_queue
        }

        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:dispatch_in_app, notification_data}, _from, state) do
    case send_in_app_notification(notification_data) do
      {:ok, result} ->
        new_metrics = %{
          state.delivery_metrics
          | in_app_sent: state.delivery_metrics.in_app_sent + 1
        }

        new_state = %{state | delivery_metrics: new_metrics}
        {:reply, {:ok, result}, new_state}

      {:error, reason} ->
        new_metrics = %{
          state.delivery_metrics
          | in_app_failed: state.delivery_metrics.in_app_failed + 1
        }

        new_state = %{state | delivery_metrics: new_metrics}
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_health_status, _from, state) do
    health_info = %{
      status: state.health_status,
      delivery_metrics: state.delivery_metrics,
      retry_queue_size: length(state.retry_queue),
      email_config_status: if(state.email_config.enabled, do: :configured, else: :disabled),
      webhook_config_status: if(state.webhook_config.enabled, do: :configured, else: :disabled)
    }

    {:reply, {:ok, health_info}, state}
  end

  @impl GenServer
  def handle_info(:process_retry_queue, state) do
    current_time = DateTime.utc_now()

    # Process items ready for retry
    {ready_for_retry, still_waiting} =
      Enum.split_with(state.retry_queue, fn item ->
        DateTime.compare(current_time, item.next_retry) != :lt
      end)

    # Attempt retries
    {successful_retries, failed_retries} =
      Enum.reduce(ready_for_retry, {[], []}, fn item, {success_acc, fail_acc} ->
        case retry_delivery(item, state) do
          {:ok, _result} ->
            Logger.info(
              "Successfully retried #{item.type} notification after #{item.attempts} attempts"
            )

            {[item | success_acc], fail_acc}

          {:error, reason} ->
            if item.attempts >= @max_retries do
              Logger.error(
                "Failed to deliver #{item.type} notification after #{item.attempts} attempts: #{inspect(reason)}"
              )

              # Give up on this item
              {success_acc, fail_acc}
            else
              # Schedule another retry with exponential backoff
              next_retry_delay = @retry_backoff_ms * :math.pow(2, item.attempts)

              updated_item = %{
                item
                | attempts: item.attempts + 1,
                  next_retry: DateTime.add(current_time, round(next_retry_delay), :millisecond),
                  last_error: reason
              }

              {success_acc, [updated_item | fail_acc]}
            end
        end
      end)

    # Update metrics for successful retries
    new_metrics =
      Enum.reduce(successful_retries, state.delivery_metrics, fn item, metrics ->
        case item.type do
          :email -> %{metrics | emails_sent: metrics.emails_sent + 1}
          :webhook -> %{metrics | webhooks_sent: metrics.webhooks_sent + 1}
          :in_app -> %{metrics | in_app_sent: metrics.in_app_sent + 1}
        end
      end)

    # Update retry queue
    new_retry_queue = still_waiting ++ failed_retries

    # Update health status based on retry queue size
    new_health_status =
      if length(new_retry_queue) > 100 do
        :degraded
      else
        :healthy
      end

    # Schedule next retry processing
    schedule_retry_processing()

    new_state = %{
      state
      | delivery_metrics: new_metrics,
        retry_queue: new_retry_queue,
        health_status: new_health_status
    }

    {:noreply, new_state}
  end

  # Private delivery functions

  defp send_email_notification(email_data, email_config) do
    if email_config.enabled do
      # In a real implementation, this would integrate with email services like:
      # - SendGrid
      # - Mailgun
      # - AWS SES
      # - SMTP server

      Logger.info("Sending email notification to #{email_data.recipient}")
      Logger.debug("Email subject: #{email_data.subject}")

      # Simulate email sending with occasional failures
      if :rand.uniform() > 0.95 do
        {:error, :email_service_unavailable}
      else
        # Simulate successful delivery
        {:ok,
         %{
           message_id: generate_message_id(),
           status: :sent,
           provider: email_config.provider,
           sent_at: DateTime.utc_now()
         }}
      end
    else
      {:error, :email_not_configured}
    end
  end

  defp send_webhook_notification(webhook_data, webhook_config) do
    if webhook_config.enabled do
      # Make HTTP POST request to webhook URL
      url = webhook_data.url
      payload = webhook_data.payload
      headers = webhook_data.headers || %{}

      # Add default headers
      request_headers =
        Map.merge(
          %{
            "User-Agent" => "EVE-DMV-Surveillance/1.0",
            "X-Webhook-Timestamp" => to_string(DateTime.to_unix(DateTime.utc_now())),
            "X-Webhook-ID" => generate_webhook_id()
          },
          headers
        )

      Logger.info("Sending webhook notification to #{url}")

      # In a real implementation, this would use HTTPoison, Finch, or similar
      # For now, simulate the HTTP request
      case simulate_http_request(url, payload, request_headers) do
        {:ok, %{status_code: status_code}} when status_code in 200..299 ->
          {:ok,
           %{
             status_code: status_code,
             url: url,
             sent_at: DateTime.utc_now()
           }}

        {:ok, %{status_code: status_code}} ->
          {:error, {:http_error, status_code}}

        {:error, reason} ->
          {:error, {:http_request_failed, reason}}
      end
    else
      {:error, :webhooks_not_configured}
    end
  end

  defp send_in_app_notification(notification_data) do
    # Use Phoenix.PubSub to broadcast to connected users
    user_id = notification_data.user_id
    notification_topic = "user_notifications:#{user_id}"

    message = %{
      type: :surveillance_alert,
      alert_id: notification_data.alert_id,
      title: notification_data.title,
      message: notification_data.message,
      action_url: notification_data.action_url,
      timestamp: DateTime.utc_now()
    }

    case Phoenix.PubSub.broadcast(EveDmv.PubSub, notification_topic, {:notification, message}) do
      :ok ->
        Logger.info("Sent in-app notification to user #{user_id}")

        {:ok,
         %{
           user_id: user_id,
           topic: notification_topic,
           sent_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.error("Failed to send in-app notification to user #{user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp retry_delivery(retry_item, state) do
    case retry_item.type do
      :email -> send_email_notification(retry_item.data, state.email_config)
      :webhook -> send_webhook_notification(retry_item.data, state.webhook_config)
      :in_app -> send_in_app_notification(retry_item.data)
    end
  end

  defp retryable_error?(reason) do
    case reason do
      :email_service_unavailable -> true
      {:http_error, status_code} when status_code >= 500 -> true
      {:http_request_failed, _} -> true
      :timeout -> true
      _ -> false
    end
  end

  # Configuration loading

  defp load_email_config do
    %{
      enabled: Application.get_env(:eve_dmv, :email_notifications_enabled, false),
      provider: Application.get_env(:eve_dmv, :email_provider, :smtp),
      smtp_config: %{
        server: Application.get_env(:eve_dmv, :smtp_server),
        port: Application.get_env(:eve_dmv, :smtp_port, 587),
        username: Application.get_env(:eve_dmv, :smtp_username),
        password: Application.get_env(:eve_dmv, :smtp_password)
      },
      from_address: Application.get_env(:eve_dmv, :email_from_address, "noreply@evedmv.com"),
      from_name: Application.get_env(:eve_dmv, :email_from_name, "EVE DMV Surveillance")
    }
  end

  defp load_webhook_config do
    %{
      enabled: Application.get_env(:eve_dmv, :webhook_notifications_enabled, true),
      default_timeout: Application.get_env(:eve_dmv, :webhook_timeout, @http_timeout),
      # 1MB
      max_payload_size: Application.get_env(:eve_dmv, :webhook_max_payload_size, 1_024_000)
    }
  end

  # Simulation helpers (would be replaced with real implementations)

  defp simulate_http_request(url, _payload, _headers) do
    # Simulate HTTP request with occasional failures
    case :rand.uniform() do
      n when n > 0.95 -> {:error, :timeout}
      n when n > 0.90 -> {:ok, %{status_code: 500}}
      n when n > 0.85 -> {:ok, %{status_code: 404}}
      _ -> {:ok, %{status_code: 200}}
    end
  end

  defp generate_message_id do
    "msg_#{System.unique_integer()}_#{:rand.uniform(999_999)}"
  end

  defp generate_webhook_id do
    "whk_#{System.unique_integer()}_#{:rand.uniform(999_999)}"
  end

  defp schedule_retry_processing do
    # Process retry queue every 30 seconds
    Process.send_after(self(), :process_retry_queue, 30_000)
  end
end
