defmodule EveDmvWeb.UnifiedDashboardLive do
  @moduledoc """
  Unified dashboard LiveView for surveillance, intelligence, and monitoring.

  This module provides a centralized dashboard that can display different views
  based on the route accessed (surveillance-dashboard, intelligence-dashboard, etc.)
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.Surveillance

  require Logger

  # System health thresholds
  # Response time above this value (in ms) indicates critical system issues
  @critical_response_threshold_ms 5000
  # Response time above this value (in ms) indicates degraded performance
  @degraded_response_threshold_ms 1000
  # Cache hit rate below this value indicates suboptimal caching
  @minimum_acceptable_cache_hit_rate 0.5

  # Time range constants in seconds
  @seconds_per_hour 3_600
  @seconds_per_day 86_400
  @seconds_per_week 604_800
  @seconds_per_30_days 2_592_000

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
    {:noreply,
     push_patch(socket, to: build_path_with_params(socket, %{"time_range" => time_range}))}
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
  def handle_info({:surveillance_alert, alert}, socket) do
    # Only reload dashboard data for surveillance dashboard and if it's a meaningful alert
    if socket.assigns.dashboard_type == :surveillance and should_reload_for_alert?(alert) do
      {:noreply, load_dashboard_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:intelligence_update, update}, socket) do
    # Only reload dashboard data for intelligence dashboard and if it's a meaningful update
    if socket.assigns.dashboard_type == :intelligence and should_reload_for_update?(update) do
      {:noreply, load_dashboard_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:alert_updated, _alert_id}, socket) do
    # Only reload for surveillance dashboard when alerts are updated
    if socket.assigns.dashboard_type == :surveillance do
      {:noreply, load_dashboard_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(_msg, socket) do
    # Ignore other PubSub messages to prevent unnecessary reloads
    {:noreply, socket}
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

  defp load_dashboard_data(%{assigns: %{dashboard_type: type}} = socket)
       when type in [:intelligence, :monitoring] do
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
    # Load profiles from the Surveillance context
    case Surveillance.list_profiles(active_only: true, limit: 100) do
      {:ok, profiles} ->
        profiles

      {:error, reason} ->
        Logger.warning("Failed to load surveillance profiles: #{inspect(reason)}")
        []
    end
  rescue
    error ->
      Logger.error("Exception loading surveillance profiles: #{inspect(error)}")
      []
  end

  defp calculate_surveillance_metrics(profiles, time_range) do
    # Calculate real metrics from profiles and surveillance data
    total_profiles = length(profiles)

    # Get surveillance metrics from the context
    metrics_result =
      try do
        Surveillance.get_surveillance_metrics()
      rescue
        _ -> {:error, :service_unavailable}
      end

    # Get recent matches count for the time range
    recent_matches_count = get_recent_matches_count(time_range)

    case metrics_result do
      {:ok, surveillance_metrics} ->
        %{
          total_profiles: total_profiles,
          active_alerts: recent_matches_count,
          match_rate: calculate_match_rate(profiles, time_range),
          avg_response: format_response_time(surveillance_metrics.avg_response_time_ms),
          system_health: determine_system_health(surveillance_metrics)
        }

      {:error, _} ->
        # Fallback when service is unavailable
        %{
          total_profiles: total_profiles,
          active_alerts: recent_matches_count,
          match_rate: 0.0,
          avg_response: "N/A",
          system_health: "Unknown"
        }
    end
  end

  defp get_recent_matches_count(time_range) do
    since = time_range_to_datetime(time_range)

    case Surveillance.get_recent_matches(since: since, limit: 1000) do
      {:ok, matches} -> length(matches)
      {:error, _} -> 0
    end
  rescue
    _ -> 0
  end

  defp calculate_match_rate(profiles, time_range) do
    if Enum.empty?(profiles) do
      0.0
    else
      since = time_range_to_datetime(time_range)

      # Get match counts for each profile
      match_counts =
        profiles
        |> Enum.map(fn profile ->
          case Surveillance.get_match_statistics(profile.id, since) do
            {:ok, stats} -> Map.get(stats, :total_matches, 0)
            {:error, _} -> 0
          end
        end)

      active_profiles = Enum.count(match_counts, &(&1 > 0))
      active_profiles / length(profiles) * 100
    end
  rescue
    _ -> 0.0
  end

  defp time_range_to_datetime(:last_hour) do
    DateTime.add(DateTime.utc_now(), -@seconds_per_hour, :second)
  end

  defp time_range_to_datetime(:last_24h) do
    DateTime.add(DateTime.utc_now(), -@seconds_per_day, :second)
  end

  defp time_range_to_datetime(:last_7d) do
    DateTime.add(DateTime.utc_now(), -@seconds_per_week, :second)
  end

  defp time_range_to_datetime(:last_30d) do
    DateTime.add(DateTime.utc_now(), -@seconds_per_30_days, :second)
  end

  defp time_range_to_datetime(_) do
    DateTime.add(DateTime.utc_now(), -@seconds_per_day, :second)
  end

  defp format_response_time(nil), do: "N/A"

  defp format_response_time(ms) when is_number(ms) do
    cond do
      ms < 1 -> "< 1ms"
      ms < 1000 -> "#{round(ms)}ms"
      true -> "#{Float.round(ms / 1000, 1)}s"
    end
  end

  defp format_response_time(_), do: "N/A"

  defp determine_system_health(metrics) do
    avg_response = Map.get(metrics, :avg_response_time_ms, 0)
    cache_hit_rate = Map.get(metrics, :cache_hit_rate, 0)

    cond do
      avg_response > @critical_response_threshold_ms -> "Critical"
      avg_response > @degraded_response_threshold_ms -> "Degraded"
      cache_hit_rate < @minimum_acceptable_cache_hit_rate -> "Fair"
      true -> "Good"
    end
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

  defp should_reload_for_alert?(alert) do
    # Only reload for high priority alerts or specific alert types that affect dashboard metrics
    case alert do
      # Critical or High priority
      %{priority: priority} when priority in [1, 2] ->
        true

      %{alert_type: type} when type in ["new_profile", "profile_updated", "metrics_updated"] ->
        true

      _ ->
        false
    end
  end

  defp should_reload_for_update?(update) do
    # Only reload for intelligence updates that affect dashboard data
    case update do
      %{type: type}
      when type in ["analysis_completed", "threat_assessment_updated", "batch_processed"] ->
        true

      _ ->
        false
    end
  end
end
