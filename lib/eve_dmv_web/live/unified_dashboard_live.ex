defmodule EveDmvWeb.UnifiedDashboardLive do
  @moduledoc """
  Unified dashboard LiveView for surveillance, intelligence, and monitoring.

  This module provides a centralized dashboard that can display different views
  based on the route accessed (surveillance-dashboard, intelligence-dashboard, etc.)
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.KillmailProcessing
  alias EveDmv.Contexts.Surveillance
  alias EveDmv.Contexts.ThreatSurveillance
  alias EveDmv.Intelligence.Analyzers.CharacterAnalyzer

  require Logger

  # Dialyzer has issues inferring return types through multiple layers of bounded context calls
  @dialyzer {:nowarn_function, load_recent_character_analyses: 1}

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

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

  # Maximum number of characters to analyze concurrently
  # Keep low to avoid overwhelming the database and ESI
  @character_analysis_max_concurrency 3
  # Maximum number of characters to analyze total
  # Reduced from 10 to 5 to improve page load times
  @character_analysis_limit 5
  # Timeout for each character analysis task (5 seconds)
  @character_analysis_timeout_ms 5_000

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

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, %{type: :metrics_updated, metrics: metrics}}, socket) do
    # Targeted update: Only update the metrics that changed
    if socket.assigns.dashboard_type == :surveillance do
      {:noreply,
       assign(socket, :profile_metrics, Map.merge(socket.assigns.profile_metrics, metrics))}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, %{type: :new_match, match: match}}, socket) do
    # Targeted update: Prepend new match and increment alert count
    if socket.assigns.dashboard_type == :surveillance do
      socket =
        socket
        |> update(:profile_metrics, fn metrics ->
          Map.update(metrics, :active_alerts, 1, &(&1 + 1))
        end)
        |> update(:recent_matches, fn matches ->
          [match | Enum.take(matches || [], 9)]
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, %{type: :profile_created, profile: profile}}, socket) do
    # Targeted update: Add new profile to list and update count
    if socket.assigns.dashboard_type == :surveillance do
      socket =
        socket
        |> update(:profiles, fn profiles ->
          # Cap at 100 profiles to match load_surveillance_profiles limit
          [profile | profiles] |> Enum.take(100)
        end)
        |> update(:profile_metrics, fn metrics ->
          Map.update(metrics, :total_profiles, 1, &(&1 + 1))
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, alert}, socket) do
    # For trackable alerts (high-priority or metrics-affecting), increment the alert count
    if socket.assigns.dashboard_type == :surveillance and trackable_alert?(alert) do
      socket =
        update(socket, :profile_metrics, fn metrics ->
          Map.update(metrics, :active_alerts, 1, &(&1 + 1))
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:intelligence_update, %{type: :analysis_completed, report: report}}, socket) do
    # Targeted update: Add completed analysis to list
    if socket.assigns.dashboard_type == :intelligence do
      socket =
        update(socket, :character_analyses, fn analyses ->
          [report | Enum.take(analyses || [], 9)]
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:intelligence_update, %{type: :threat_assessment_updated, assessment: assessment}},
        socket
      ) do
    # Targeted update: Update specific threat assessment
    if socket.assigns.dashboard_type == :intelligence do
      socket =
        update(socket, :threat_assessments, fn assessments ->
          [assessment | Enum.take(assessments || [], 9)]
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:intelligence_update, _update}, socket) do
    # Ignore other intelligence updates to prevent unnecessary reloads
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:alert_updated, alert_id}, socket) do
    # Targeted update: Just refresh the specific alert status, not full reload
    if socket.assigns.dashboard_type == :surveillance do
      # Only log the update for monitoring; avoid database query
      Logger.debug("Alert #{alert_id} updated - using cached data")
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(
        {:alerts_batch, batch_payload},
        %{assigns: %{dashboard_type: :surveillance}} = socket
      ) do
    # Handle batched alerts for improved performance (Stream 9 optimization)
    # This is the optimized path during high-activity periods (100+ kills/min)
    {:noreply, handle_surveillance_alerts_batch(socket, batch_payload)}
  end

  @impl Phoenix.LiveView
  def handle_info({:alerts_batch, _batch_payload}, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_info({:metrics_update, metrics}, socket) do
    # Handle metrics-only updates from AlertBatcher (Stream 9 optimization)
    # Light-weight update without full reload
    if socket.assigns.dashboard_type == :surveillance do
      socket =
        update(socket, :profile_metrics, fn current_metrics ->
          Map.merge(current_metrics, metrics)
        end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Handle async character analyses loading for intelligence dashboard
  @impl Phoenix.LiveView
  def handle_info({:load_character_analyses_async, time_range}, socket) do
    if socket.assigns.dashboard_type == :intelligence do
      # Perform the async loading in a task to avoid blocking
      # Store the parent PID so the task can send results back
      parent_pid = self()

      Task.start(fn ->
        analyses = load_recent_character_analyses(time_range)
        send(parent_pid, {:character_analyses_loaded, analyses})
      end)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:character_analyses_loaded, analyses}, socket) do
    if socket.assigns.dashboard_type == :intelligence do
      socket =
        socket
        |> assign(:character_analyses, analyses)
        |> assign(:character_analyses_loading, false)

      {:noreply, socket}
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

  defp handle_surveillance_alerts_batch(socket, batch_payload) do
    alerts = Map.get(batch_payload, :alerts, [])
    batch_size = Map.get(batch_payload, :batch_size, length(alerts))

    if batch_size > 0 or alerts != [] do
      # Ensure profile_metrics is never nil before merging operations
      socket = update(socket, :profile_metrics, fn metrics -> metrics || %{} end)

      socket
      |> update(:profile_metrics, fn metrics ->
        # Use length(alerts) if alerts present, otherwise fall back to batch_size
        increment = if alerts != [], do: length(alerts), else: batch_size
        Map.update(metrics, :active_alerts, increment, &(&1 + increment))
      end)
      |> update(:recent_matches, fn matches ->
        # Prepend new alerts and truncate to keep max 10 recent matches
        (alerts ++ (matches || []))
        |> Enum.take(10)
      end)
    else
      socket
    end
  end

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
    |> assign(:recent_matches, [])
  end

  defp assign_dashboard_data(socket, :intelligence) do
    # Fetch recent threat assessments for initial render
    threat_assessments = load_recent_threat_assessments()

    socket
    |> assign(:character_analyses, [])
    |> assign(:character_analyses_loading, true)
    |> assign(:threat_assessments, threat_assessments)
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
    time_range = socket.assigns.time_range
    profiles = load_surveillance_profiles(time_range)
    metrics = calculate_surveillance_metrics(profiles, time_range)
    recent_matches = load_recent_matches(time_range)

    socket
    |> assign(:profiles, profiles)
    |> assign(:profile_metrics, metrics)
    |> assign(:recent_matches, recent_matches)
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

  defp load_dashboard_data(%{assigns: %{dashboard_type: :intelligence}} = socket) do
    # Load threat assessments synchronously (fast query)
    threat_assessments = load_recent_threat_assessments()

    # Character analyses are loaded asynchronously to avoid blocking page render
    # Send message to self to trigger async loading
    send(self(), {:load_character_analyses_async, socket.assigns.time_range})

    socket
    |> assign(:character_analyses, [])
    |> assign(:character_analyses_loading, true)
    |> assign(:threat_assessments, threat_assessments)
    |> assign(:loading, false)
    |> assign(:error, nil)
  rescue
    error ->
      Logger.error("Failed to load intelligence dashboard data: #{inspect(error)}")

      socket
      |> assign(:character_analyses, [])
      |> assign(:character_analyses_loading, false)
      |> assign(:threat_assessments, [])
      |> assign(:loading, false)
      |> assign(:error, "Failed to load dashboard data")
  end

  defp load_dashboard_data(%{assigns: %{dashboard_type: :monitoring}} = socket) do
    # For now, return empty data for monitoring dashboard
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

  defp load_recent_matches(time_range) do
    since = time_range_to_datetime(time_range)

    case Surveillance.get_recent_matches(since: since, limit: 10) do
      {:ok, matches} -> matches
      {:error, _} -> []
    end
  rescue
    error ->
      Logger.error(
        "Exception loading recent matches: #{inspect(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}"
      )

      []
  end

  defp load_recent_threat_assessments do
    case ThreatSurveillance.list_recent_threat_assessments(limit: 10) do
      {:ok, assessments} ->
        assessments

      {:error, err} ->
        Logger.warning("Failed to load recent threat assessments: #{inspect(err)}")
        []
    end
  rescue
    error ->
      Logger.error("Exception loading recent threat assessments: #{inspect(error)}")
      []
  end

  defp load_recent_character_analyses(time_range) do
    # Get recent killmails and extract unique character IDs for analysis
    since = time_range_to_datetime(time_range)

    case KillmailProcessing.get_recent_killmails(limit: 50) do
      {:ok, killmails} ->
        # Filter killmails by time range and extract unique victim character IDs
        character_ids =
          killmails
          |> Enum.filter(fn km ->
            case km do
              %{killmail_time: time} when not is_nil(time) ->
                DateTime.compare(time, since) != :lt

              _ ->
                true
            end
          end)
          |> Enum.map(fn km -> Map.get(km, :victim_character_id) end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.take(@character_analysis_limit)

        # Analyze characters concurrently with bounded parallelism
        # Using Task.async_stream to prevent blocking on slow analyses
        character_ids
        |> Task.async_stream(
          fn character_id ->
            case CharacterAnalyzer.analyze_character(character_id) do
              {:ok, analysis} ->
                # Add timestamp for display purposes
                Map.put(analysis, :analyzed_at, DateTime.utc_now())

              {:error, _} ->
                nil
            end
          end,
          max_concurrency: @character_analysis_max_concurrency,
          timeout: @character_analysis_timeout_ms,
          on_timeout: :kill_task
        )
        |> Enum.reduce([], fn
          {:ok, nil}, acc -> acc
          {:ok, analysis}, acc -> [analysis | acc]
          {:exit, _reason}, acc -> acc
        end)
        |> Enum.reverse()

      {:error, _} ->
        []
    end
  rescue
    error ->
      Logger.warning("Failed to load recent character analyses: #{inspect(error)}")
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
      # Convert time_range to format expected by get_match_statistics
      stats_time_range = normalize_time_range_for_statistics(time_range)

      # Get match counts for each profile
      match_counts =
        profiles
        |> Enum.map(fn profile ->
          case Surveillance.get_match_statistics(profile.id, stats_time_range) do
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

  # Normalize time_range to format expected by get_match_statistics
  # which accepts :last_24h, :last_7d, :last_30d or {DateTime.t(), DateTime.t()}
  defp normalize_time_range_for_statistics(:last_hour) do
    # Convert to DateTime tuple since :last_hour isn't directly supported
    now = DateTime.utc_now()
    {DateTime.add(now, -@seconds_per_hour, :second), now}
  end

  defp normalize_time_range_for_statistics(time_range)
       when time_range in [:last_24h, :last_7d, :last_30d] do
    time_range
  end

  defp normalize_time_range_for_statistics(_), do: :last_24h

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

  defp trackable_alert?(alert) do
    # Check if alert should be tracked (increment active_alerts counter)
    # Returns true for high-priority alerts or specific alert types that affect dashboard metrics
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

  # Note: should_reload_for_update?/1 removed in Stream 2 optimization.
  # should_reload_for_alert?/1 was renamed to trackable_alert?/1 since it only increments
  # :profile_metrics.active_alerts and never reloads. We now use targeted pattern-matched
  # handlers instead of full reloads.

  # Render functions

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-white">{@page_title}</h1>
          <p class="mt-2 text-gray-400">
            <%= case @dashboard_type do %>
              <% :surveillance -> %>
                Monitor your surveillance profiles and alerts in real-time.
              <% :intelligence -> %>
                Access character and corporation intelligence reports.
              <% :monitoring -> %>
                System health and performance monitoring.
              <% _ -> %>
                Welcome to your EVE DMV dashboard.
            <% end %>
          </p>
        </div>

        <%= if @loading do %>
          <div class="flex items-center justify-center py-12">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-500"></div>
          </div>
        <% else %>
          <%= if @error do %>
            <div class="bg-red-900/50 border border-red-700 rounded-lg p-4 mb-6">
              <div class="flex items-center">
                <svg class="w-5 h-5 text-red-400 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                </svg>
                <span class="text-red-200">{@error}</span>
              </div>
            </div>
          <% end %>

          {render_dashboard_content(assigns)}
        <% end %>
      </div>
    </div>
    """
  end

  defp render_dashboard_content(%{dashboard_type: :surveillance} = assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Surveillance Metrics Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-gray-400 text-sm">Total Profiles</p>
              <p class="text-2xl font-bold text-white mt-1">{Map.get(@profile_metrics, :total_profiles, 0)}</p>
            </div>
            <div class="p-3 bg-indigo-600/20 rounded-lg">
              <svg class="w-6 h-6 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-gray-400 text-sm">Active Alerts</p>
              <p class="text-2xl font-bold text-white mt-1">{Map.get(@profile_metrics, :active_alerts, 0)}</p>
            </div>
            <div class="p-3 bg-yellow-600/20 rounded-lg">
              <svg class="w-6 h-6 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-gray-400 text-sm">Match Rate</p>
              <p class="text-2xl font-bold text-white mt-1">{Float.round(Map.get(@profile_metrics, :match_rate, 0.0), 1)}%</p>
            </div>
            <div class="p-3 bg-green-600/20 rounded-lg">
              <svg class="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-gray-400 text-sm">System Health</p>
              <p class="text-2xl font-bold text-white mt-1">{Map.get(@profile_metrics, :system_health, "Unknown")}</p>
            </div>
            <div class={"p-3 rounded-lg #{health_color_class(Map.get(@profile_metrics, :system_health, "Unknown"))}"}>
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- Surveillance Profiles List -->
      <div class="bg-gray-800 rounded-lg border border-gray-700">
        <div class="px-6 py-4 border-b border-gray-700">
          <h2 class="text-lg font-semibold text-white">Active Surveillance Profiles</h2>
        </div>
        <div class="p-6">
          <%= if Enum.empty?(@profiles) do %>
            <div class="text-center py-8">
              <svg class="mx-auto h-12 w-12 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
              </svg>
              <p class="mt-2 text-gray-400">No active surveillance profiles</p>
              <a href="/surveillance-profiles" class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
                Create Profile
              </a>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for profile <- Enum.take(@profiles, 10) do %>
                <div class="flex items-center justify-between p-4 bg-gray-700/50 rounded-lg">
                  <div>
                    <p class="text-white font-medium">{profile.name}</p>
                    <p class="text-gray-400 text-sm">{profile.description || "No description"}</p>
                  </div>
                  <a href={"/surveillance-profiles"} class="text-indigo-400 hover:text-indigo-300 text-sm">
                    View Details
                  </a>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_dashboard_content(%{dashboard_type: :intelligence} = assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h2 class="text-lg font-semibold text-white mb-4">Intelligence Dashboard</h2>
        <p class="text-gray-400">
          Access character threat assessments, corporation analysis, and behavioral patterns.
        </p>
        <div class="mt-6 flex flex-wrap gap-4">
          <a href="/search" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
            Search Characters
          </a>
          <a href="/surveillance" class="inline-flex items-center px-4 py-2 border border-gray-600 text-sm font-medium rounded-md text-gray-300 hover:bg-gray-700">
            Surveillance Center
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp render_dashboard_content(%{dashboard_type: :monitoring} = assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h2 class="text-lg font-semibold text-white mb-4">System Monitoring</h2>
        <p class="text-gray-400">
          Monitor system health, performance metrics, and operational status.
        </p>
        <div class="mt-6">
          <a href="/admin/performance" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
            View Performance Dashboard
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp render_dashboard_content(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <a href="/feed" class="bg-gray-800 rounded-lg p-6 border border-gray-700 hover:border-indigo-500 transition-colors">
          <div class="flex items-center">
            <div class="p-3 bg-red-600/20 rounded-lg">
              <svg class="w-6 h-6 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-gray-400 text-sm">Kill Feed</p>
              <p class="text-white font-semibold">Real-time kills</p>
            </div>
          </div>
        </a>

        <a href="/surveillance" class="bg-gray-800 rounded-lg p-6 border border-gray-700 hover:border-indigo-500 transition-colors">
          <div class="flex items-center">
            <div class="p-3 bg-indigo-600/20 rounded-lg">
              <svg class="w-6 h-6 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-gray-400 text-sm">Surveillance</p>
              <p class="text-white font-semibold">Track entities</p>
            </div>
          </div>
        </a>

        <a href="/search" class="bg-gray-800 rounded-lg p-6 border border-gray-700 hover:border-indigo-500 transition-colors">
          <div class="flex items-center">
            <div class="p-3 bg-green-600/20 rounded-lg">
              <svg class="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-gray-400 text-sm">Search</p>
              <p class="text-white font-semibold">Find pilots & corps</p>
            </div>
          </div>
        </a>
      </div>

      <!-- Quick Actions -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h2 class="text-lg font-semibold text-white mb-4">Quick Actions</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <a href="/surveillance-profiles" class="flex flex-col items-center p-4 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition-colors">
            <svg class="w-8 h-8 text-indigo-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
            </svg>
            <span class="text-gray-300 text-sm">Profiles</span>
          </a>

          <a href="/battle" class="flex flex-col items-center p-4 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition-colors">
            <svg class="w-8 h-8 text-red-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            <span class="text-gray-300 text-sm">Battles</span>
          </a>

          <a href="/fleet" class="flex flex-col items-center p-4 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition-colors">
            <svg class="w-8 h-8 text-blue-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
            </svg>
            <span class="text-gray-300 text-sm">Fleet</span>
          </a>

          <a href="/profile" class="flex flex-col items-center p-4 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition-colors">
            <svg class="w-8 h-8 text-purple-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
            <span class="text-gray-300 text-sm">Profile</span>
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp health_color_class("Good"), do: "bg-green-600/20 text-green-400"
  defp health_color_class("Fair"), do: "bg-yellow-600/20 text-yellow-400"
  defp health_color_class("Degraded"), do: "bg-orange-600/20 text-orange-400"
  defp health_color_class("Critical"), do: "bg-red-600/20 text-red-400"
  defp health_color_class(_), do: "bg-gray-600/20 text-gray-400"
end
