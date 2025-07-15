defmodule EveDmvWeb.SurveillanceAlertsLive do
  @moduledoc """
  LiveView for real-time surveillance alerts display.

  Features:
  - Real-time alert notifications with visual and audio feedback
  - Alert history and filtering
  - Alert acknowledgment and resolution
  - Alert details and context
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.Surveillance.Domain.AlertService
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmvWeb.Helpers.TimeFormatter

  require Logger

  @alerts_per_page 25

  # LiveView lifecycle

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time alert notifications
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:alerts")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:notifications")
    end

    socket =
      socket
      |> assign(:page_title, "Surveillance Alerts")
      |> assign(:alerts, [])
      |> assign(:alert_filters, default_filters())
      |> assign(:selected_alert, nil)
      |> assign(:show_alert_details, false)
      |> assign(:new_alert_count, 0)
      |> assign(:sound_enabled, true)
      |> assign(:auto_acknowledge, false)
      |> assign(:alert_metrics, %{})
      |> load_alerts()
      |> load_alert_metrics()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    case params do
      %{"alert_id" => alert_id} ->
        {:noreply, show_alert_details(socket, alert_id)}

      _ ->
        {:noreply, assign(socket, :show_alert_details, false)}
    end
  end

  # Event handlers

  @impl Phoenix.LiveView
  def handle_event("filter_alerts", %{"filter" => filter_params}, socket) do
    updated_filters = update_filters(socket.assigns.alert_filters, filter_params)

    socket =
      socket
      |> assign(:alert_filters, updated_filters)
      |> load_alerts()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("acknowledge_alert", %{"alert_id" => alert_id}, socket) do
    # Get current user from session
    user_id = get_user_id(socket)

    case safe_call(fn -> AlertService.update_alert_state(alert_id, "acknowledged", user_id) end) do
      {:ok, _updated_alert} ->
        socket =
          socket
          |> put_flash(:info, "Alert acknowledged")
          |> load_alerts()

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Failed to acknowledge alert")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("resolve_alert", %{"alert_id" => alert_id}, socket) do
    # Get current user from session
    user_id = get_user_id(socket)

    case safe_call(fn -> AlertService.update_alert_state(alert_id, "resolved", user_id) end) do
      {:ok, _updated_alert} ->
        socket =
          socket
          |> put_flash(:info, "Alert resolved")
          |> load_alerts()

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Failed to resolve alert")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("bulk_acknowledge", _params, socket) do
    # Get current user from session
    user_id = get_user_id(socket)
    criteria = %{state: "new"}

    case safe_call(fn -> AlertService.bulk_acknowledge_alerts(criteria, user_id) end) do
      {:ok, count} ->
        socket =
          socket
          |> put_flash(:info, "Acknowledged #{count} alerts")
          |> assign(:new_alert_count, 0)
          |> load_alerts()

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Failed to bulk acknowledge")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show_alert_details", %{"alert_id" => alert_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/surveillance-alerts?alert_id=#{alert_id}")}
  end

  @impl Phoenix.LiveView
  def handle_event("close_alert_details", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/surveillance-alerts")}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_sound", _params, socket) do
    new_sound_enabled = !socket.assigns.sound_enabled
    {:noreply, assign(socket, :sound_enabled, new_sound_enabled)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_auto_acknowledge", _params, socket) do
    new_auto_acknowledge = !socket.assigns.auto_acknowledge
    {:noreply, assign(socket, :auto_acknowledge, new_auto_acknowledge)}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_new_alerts", _params, socket) do
    {:noreply, assign(socket, :new_alert_count, 0)}
  end

  @impl Phoenix.LiveView
  def handle_event("test_notification", %{"profile_id" => profile_id}, socket) do
    case NotificationService.test_notification_delivery(profile_id) do
      {:ok, test_results} ->
        socket = put_flash(socket, :info, "Test notifications sent: #{inspect(test_results)}")
        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Test notification failed: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  # PubSub handlers

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, alert_data}, socket) do
    # New real-time alert received
    Logger.info("Received real-time surveillance alert: #{alert_data.alert_id}")

    # Trigger visual and audio notifications
    socket =
      socket
      |> update(:new_alert_count, &(&1 + 1))
      |> load_alerts()
      |> trigger_alert_notification(alert_data)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:alert_updated, alert_id}, socket) do
    # Alert state changed, refresh list
    socket =
      socket
      |> load_alerts()
      |> then(fn socket ->
        # Update details if this alert is currently shown
        if socket.assigns.selected_alert && socket.assigns.selected_alert.id == alert_id do
          case safe_call(fn -> AlertService.get_alert(alert_id) end) do
            {:ok, updated_alert} -> assign(socket, :selected_alert, updated_alert)
            _ -> assign(socket, :selected_alert, nil)
          end
        else
          socket
        end
      end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:notification_delivered, notification_data}, socket) do
    Logger.debug("Notification delivered: #{notification_data.notification_id}")
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_alerts(socket) do
    filters = socket.assigns.alert_filters

    # Convert filter map to options list
    base_opts = [
      limit: @alerts_per_page,
      priority: Map.get(filters, :priority),
      state: Map.get(filters, :state),
      profile_id: Map.get(filters, :profile_id)
    ]

    opts = Enum.reject(base_opts, fn {_k, v} -> is_nil(v) end)

    case safe_call(fn -> AlertService.get_recent_alerts(opts) end) do
      {:ok, alerts} ->
        assign(socket, :alerts, alerts)

      _ ->
        assign(socket, :alerts, [])
    end
  end

  defp load_alert_metrics(socket) do
    case safe_call(fn -> AlertService.get_alert_metrics(:last_24h) end) do
      {:ok, metrics} ->
        assign(socket, :alert_metrics, metrics)

      _ ->
        assign(socket, :alert_metrics, %{})
    end
  end

  defp show_alert_details(socket, alert_id) do
    case safe_call(fn -> AlertService.get_alert(alert_id) end) do
      {:ok, alert} ->
        socket
        |> assign(:selected_alert, alert)
        |> assign(:show_alert_details, true)

      _ ->
        socket
        |> put_flash(:error, "Alert not found")
        |> assign(:show_alert_details, false)
    end
  end

  defp default_filters do
    %{
      priority: nil,
      state: nil,
      profile_id: nil,
      time_range: :last_24h
    }
  end

  defp update_filters(current_filters, filter_params) do
    Enum.reduce(filter_params, current_filters, fn {key, value}, acc ->
      key_atom = String.to_existing_atom(key)

      # Convert empty strings to nil
      processed_value = if value == "", do: nil, else: value

      # Convert certain values to atoms or integers as needed
      final_value =
        case key_atom do
          :priority when is_binary(processed_value) ->
            case Integer.parse(processed_value) do
              {num, _} -> num
              :error -> nil
            end

          :state when is_binary(processed_value) ->
            processed_value

          :profile_id when is_binary(processed_value) ->
            processed_value

          :time_range when is_binary(processed_value) ->
            String.to_existing_atom(processed_value)

          _ ->
            processed_value
        end

      Map.put(acc, key_atom, final_value)
    end)
  end

  defp trigger_alert_notification(socket, alert_data) do
    # Send client-side notification for visual/audio feedback
    if socket.assigns.sound_enabled do
      # Push event to client to play notification sound
      push_event(socket, "play_alert_sound", %{
        priority: alert_data.priority,
        alert_type: alert_data.alert_type
      })
    else
      socket
    end
  end

  # Formatting helpers

  def format_alert_priority(priority) do
    case priority do
      1 -> {"Critical", "bg-red-100 text-red-800 border-red-200"}
      2 -> {"High", "bg-orange-100 text-orange-800 border-orange-200"}
      3 -> {"Medium", "bg-yellow-100 text-yellow-800 border-yellow-200"}
      4 -> {"Low", "bg-blue-100 text-blue-800 border-blue-200"}
      _ -> {"Unknown", "bg-gray-100 text-gray-800 border-gray-200"}
    end
  end

  def format_alert_state(state) do
    case state do
      "new" -> {"New", "bg-green-100 text-green-800"}
      "acknowledged" -> {"Acknowledged", "bg-blue-100 text-blue-800"}
      "resolved" -> {"Resolved", "bg-gray-100 text-gray-800"}
      _ -> {"Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  def format_alert_type(alert_type) do
    case alert_type do
      :target_killed -> "Target Eliminated"
      :target_active -> "Target Activity"
      :location_activity -> "Location Activity"
      :general_match -> "Profile Match"
      _ -> "Unknown"
    end
  end

  def format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> TimeFormatter.format_relative_time(dt)
      _ -> timestamp
    end
  end

  def format_timestamp(%DateTime{} = dt), do: TimeFormatter.format_relative_time(dt)
  def format_timestamp(%NaiveDateTime{} = ndt), do: format_naive_datetime(ndt)
  def format_timestamp(_), do: "Unknown"

  defp format_naive_datetime(ndt) do
    case DateTime.from_naive(ndt, "Etc/UTC") do
      {:ok, dt} -> TimeFormatter.format_relative_time(dt)
      _ -> "Unknown"
    end
  end

  def format_confidence_score(score) when is_number(score) do
    "#{Float.round(score * 100, 1)}%"
  end

  def format_confidence_score(_), do: "N/A"

  # Safe call helper for surveillance services
  defp safe_call(fun) when is_function(fun, 0) do
    try do
      fun.()
    rescue
      error ->
        Logger.error("Surveillance service call failed: #{inspect(error)}")
        {:error, :service_unavailable}
    catch
      :exit, reason ->
        Logger.error("Surveillance service process not available: #{inspect(reason)}")
        {:error, :service_unavailable}
    end
  end

  # Helper function to get user ID from socket
  defp get_user_id(socket) do
    case socket.assigns[:current_user] do
      %{id: user_id} -> user_id
      %{eve_character_id: char_id} -> char_id
      _ -> "anonymous"
    end
  end
end
