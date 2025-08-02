defmodule EveDmvWeb.UnifiedDashboardLive do
  @moduledoc """
  Unified dashboard LiveView for surveillance, intelligence, and monitoring.

  This module provides a centralized dashboard that can display different views
  based on the route accessed (surveillance-dashboard, intelligence-dashboard, etc.)
  """
  """

  use EveDmvWeb, :live_view

  require Logger

  # LiveView lifecycle

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # Determine dashboard type from the current route
    dashboard_type = get_dashboard_type(socket)
    # Subscribe to real-time updates when connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:metrics")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:alerts")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:updates")
    end

    socket =
      socket
      |> assign(:dashboard_type, dashboard_type)
      |> assign(:page_title, get_page_title(dashboard_type))
      |> assign(:time_range, :last_24h)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign_dashboard_data(dashboard_type)
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, url, socket) do
    # Extract dashboard type from URL if not already set correctly
    dashboard_type =
      if socket.assigns[:dashboard_type] == :general do
        detect_dashboard_type_from_url(url)
      else
        socket.assigns.dashboard_type
      end
    time_range =
      case params["time_range"] do
        "last_hour" -> :last_hour
        "last_24h" -> :last_24h
        "last_7d" -> :last_7d
        "last_30d" -> :last_30d
        _ -> :last_24h
      end

    socket =
      socket
      |> assign(:dashboard_type, dashboard_type)
      |> assign(:page_title, get_page_title(dashboard_type))
      |> assign(:time_range, time_range)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  # Event handlers

  @impl Phoenix.LiveView
  def handle_event("change_time_range", %{"time_range" => time_range}, socket) do
    {:noreply, push_patch(socket, to: build_path_with_params(socket, %{"time_range" => time_range}))}
  end

  @impl Phoenix.LiveView
  def handle_event("refresh_data", _params, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> load_dashboard_data()
    {:noreply, socket}
  end

  # PubSub handlers

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, _alert}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:intelligence_update, _update}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  # Private functions

  defp get_dashboard_type(socket) do
    # Check the route name first
    case socket.assigns[:live_action] do
      :surveillance_dashboard -> :surveillance
      :intelligence_dashboard -> :intelligence
      :monitoring_dashboard -> :monitoring
      _ -> :general
    end
  end

  defp detect_dashboard_type_from_url(url) when is_binary(url) do
    cond do
      String.contains?(url, "surveillance") -> :surveillance
      String.contains?(url, "intelligence") -> :intelligence
      String.contains?(url, "monitoring") -> :monitoring
      true -> :general
    end
  end

  defp detect_dashboard_type_from_url(_), do: :general

  defp get_page_title(:surveillance), do: "Surveillance Performance Dashboard"
  defp get_page_title(:intelligence), do: "Intelligence Dashboard"
  defp get_page_title(:monitoring), do: "Monitoring Dashboard"
  defp get_page_title(_), do: "Dashboard"

  defp assign_dashboard_data(socket, :surveillance) do
    socket
    |> assign(:profiles, [])
    |> assign(:profile_metrics, %{})
    |> assign(:alert_trends, [])
    |> assign(:system_metrics, %{})
    |> assign(:top_performing_profiles, [])
    |> assign(:performance_recommendations, [])
  end

  defp assign_dashboard_data(socket, :intelligence) do
    socket
    |> assign(:character_analyses, [])
    |> assign(:threat_assessments, [])
    |> assign(:intelligence_reports, [])
    |> assign(:analysis_queue, [])
  end

  defp assign_dashboard_data(socket, :monitoring) do
    socket
    |> assign(:system_health, %{})
    |> assign(:performance_metrics, %{})
    |> assign(:error_rates, [])
    |> assign(:database_stats, %{})
  end

  defp assign_dashboard_data(socket, _) do
    socket
    |> assign(:general_metrics, %{})
    |> assign(:recent_activity, [])
    |> assign(:quick_stats, %{})
  end

  defp load_dashboard_data(%{assigns: %{dashboard_type: :surveillance}} = socket) do
    # Load surveillance-specific data
    profiles = load_surveillance_profiles(socket.assigns.time_range)
    metrics = calculate_surveillance_metrics(profiles, socket.assigns.time_range)

    socket
    |> assign(:profiles, profiles)
    |> assign(:profile_metrics, metrics)
    |> assign(:alert_trends, [])
    |> assign(:performance_recommendations, [])
    |> assign(:loading, false)
    |> assign(:error, nil)
  rescue
    error ->
      Logger.error("Failed to load surveillance dashboard data: #{inspect(error)}")

      socket
      |> assign(:loading, false)
      |> assign(:error, "Failed to load dashboard data")
      |> assign(:performance_recommendations, [])
  end

  defp load_dashboard_data(%{assigns: %{dashboard_type: type}} = socket) when type in [:intelligence, :monitoring] do
    # For now, return empty data for other dashboard types
    socket
    |> assign(:loading, false)
    |> assign(:error, nil)
  end

  defp load_dashboard_data(socket) do
    # General dashboard
    socket
    |> assign(:loading, false)
    |> assign(:error, nil)
  end

  defp load_surveillance_profiles(_time_range) do
    # Return empty list for now - this would normally load from ThreatSurveillance
    []
  end

  defp calculate_surveillance_metrics(_profiles, _time_range) do
    # Return basic metrics structure
    %{
      total_profiles: 0,
      active_alerts: 0,
      match_rate: 0.0,
      avg_response: "N/A",
      system_health: "Good"
    }
  end

  defp build_path_with_params(socket, params) do
    base_path = get_base_path(socket.assigns.dashboard_type, socket)
    query_string = URI.encode_query(params)
    "#{base_path}?#{query_string}"
  end

  defp get_base_path(:surveillance, _socket), do: "/surveillance-dashboard"
  defp get_base_path(:intelligence, _socket), do: "/intelligence-dashboard"
  defp get_base_path(:monitoring, _socket), do: "/monitoring"
  defp get_base_path(_, _socket), do: "/dashboard"
end
