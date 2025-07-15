defmodule EveDmvWeb.SurveillanceDashboardLive do
  @moduledoc """
  LiveView for surveillance profile performance dashboard.

  Features:
  - Profile performance metrics and analytics
  - Alert generation statistics per profile
  - Filter efficiency monitoring
  - Real-time performance tracking
  - Profile optimization recommendations
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.Surveillance
  alias EveDmv.Contexts.Surveillance.Domain.AlertService
  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine

  require Logger

  # LiveView lifecycle

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time surveillance updates
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:metrics")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:alerts")
    end

    socket =
      socket
      |> assign(:page_title, "Surveillance Dashboard")
      |> assign(:time_range, :last_24h)
      |> assign(:selected_profile, nil)
      |> assign(:profiles, [])
      |> assign(:profile_metrics, %{})
      |> assign(:system_metrics, %{})
      |> assign(:alert_trends, [])
      |> assign(:top_performing_profiles, [])
      |> assign(:performance_recommendations, [])
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
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
      |> assign(:time_range, time_range)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  # Event handlers

  @impl Phoenix.LiveView
  def handle_event("change_time_range", %{"time_range" => time_range}, socket) do
    {:noreply, push_patch(socket, to: ~p"/surveillance-dashboard?time_range=#{time_range}")}
  end

  @impl Phoenix.LiveView
  def handle_event("select_profile", %{"profile_id" => profile_id}, socket) do
    socket =
      socket
      |> assign(:selected_profile, profile_id)
      |> load_profile_details(profile_id)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("refresh_metrics", _params, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("optimize_profile", %{"profile_id" => profile_id}, socket) do
    {:ok, recommendations} = generate_optimization_recommendations(profile_id)

    socket =
      put_flash(
        socket,
        :info,
        "Generated #{length(recommendations)} optimization recommendations"
      )

    {:noreply, socket}
  end

  # PubSub handlers

  @impl Phoenix.LiveView
  def handle_info({:surveillance_metrics_updated, _metrics}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:surveillance_alert, _alert_data}, socket) do
    # New alert, refresh metrics
    {:noreply, load_dashboard_data(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_dashboard_data(socket) do
    time_range = socket.assigns.time_range

    socket
    |> load_profiles()
    |> load_system_metrics(time_range)
    |> load_profile_metrics(time_range)
    |> load_alert_trends(time_range)
    |> load_top_performing_profiles(time_range)
    |> load_performance_recommendations()
  end

  defp load_profiles(socket) do
    try do
      case Surveillance.list_profiles(%{}) do
        {:ok, profiles} ->
          assign(socket, :profiles, profiles)

        {:error, reason} ->
          Logger.error("Failed to load profiles: #{inspect(reason)}")

          assign(socket, :profiles, [])
      end
    rescue
      error ->
        Logger.error("Surveillance service unavailable: #{inspect(error)}")

        assign(socket, :profiles, [])
    catch
      :exit, reason ->
        Logger.error("Surveillance service process not available: #{inspect(reason)}")

        assign(socket, :profiles, [])
    end
  end

  defp load_system_metrics(socket, time_range) do
    # Get overall surveillance system performance
    system_metrics = %{
      total_profiles: length(socket.assigns.profiles),
      active_profiles: count_active_profiles(socket.assigns.profiles),
      total_alerts: get_total_alerts(time_range),
      alerts_per_hour: get_alerts_per_hour(time_range),
      average_response_time: get_average_response_time(),
      system_load: get_system_load(),
      memory_usage: get_memory_usage(),
      cache_hit_rate: get_cache_hit_rate()
    }

    assign(socket, :system_metrics, system_metrics)
  end

  defp load_profile_metrics(socket, time_range) do
    profiles = socket.assigns.profiles

    profile_metrics =
      Enum.map(profiles, fn profile ->
        %{
          profile_id: profile.id,
          profile_name: profile.name,
          alerts_generated: get_profile_alert_count(profile.id, time_range),
          match_rate: get_profile_match_rate(profile.id, time_range),
          false_positive_rate: get_profile_false_positive_rate(profile.id, time_range),
          avg_confidence: get_profile_avg_confidence(profile.id, time_range),
          performance_score: calculate_profile_performance_score(profile.id, time_range),
          last_alert: get_profile_last_alert(profile.id),
          criteria_efficiency: analyze_criteria_efficiency(profile.criteria)
        }
      end)

    profile_metrics = Enum.sort_by(profile_metrics, & &1.performance_score, :desc)

    assign(socket, :profile_metrics, profile_metrics)
  end

  defp load_alert_trends(socket, time_range) do
    # Generate time-series data for alert trends
    trends = generate_alert_trends(time_range)
    assign(socket, :alert_trends, trends)
  end

  defp load_top_performing_profiles(socket, _time_range) do
    profile_metrics = socket.assigns.profile_metrics

    top_profiles =
      Enum.filter(profile_metrics, &(&1.alerts_generated > 0))
      |> Enum.sort_by(& &1.performance_score, :desc)
      |> Enum.take(5)

    assign(socket, :top_performing_profiles, top_profiles)
  end

  defp load_performance_recommendations(socket) do
    profiles = socket.assigns.profiles
    profile_metrics = socket.assigns.profile_metrics

    recommendations = generate_system_recommendations(profiles, profile_metrics)
    assign(socket, :performance_recommendations, recommendations)
  end

  defp load_profile_details(socket, profile_id) do
    # Load detailed metrics for a specific profile
    detailed_metrics = %{
      hourly_breakdown: get_profile_hourly_breakdown(profile_id),
      criteria_performance: get_criteria_performance_breakdown(profile_id),
      recent_matches: get_recent_profile_matches(profile_id, 10),
      optimization_suggestions: generate_profile_optimization_suggestions(profile_id)
    }

    assign(socket, :profile_details, detailed_metrics)
  end

  # Metrics calculation functions

  defp count_active_profiles(profiles) do
    Enum.count(profiles, & &1.enabled)
  end

  defp get_total_alerts(time_range) do
    case safe_call(fn -> AlertService.get_alert_metrics(time_range) end) do
      {:ok, metrics} -> Map.get(metrics, :total_alerts, 0)
      _ -> 0
    end
  end

  defp get_alerts_per_hour(time_range) do
    total_alerts = get_total_alerts(time_range)

    hours =
      case time_range do
        :last_hour -> 1
        :last_24h -> 24
        :last_7d -> 168
        :last_30d -> 720
      end

    if hours > 0, do: Float.round(total_alerts / hours, 2), else: 0.0
  end

  defp get_average_response_time do
    # Get surveillance engine response time from monitoring
    case safe_call(fn -> Surveillance.get_surveillance_metrics() end) do
      {:ok, metrics} -> Map.get(metrics, :avg_response_time_ms, 0)
      _ -> 0
    end
  end

  defp get_system_load do
    # Get current system load percentage
    case safe_call(fn -> Surveillance.get_surveillance_metrics() end) do
      {:ok, metrics} -> Map.get(metrics, :system_load_percent, 0)
      _ -> 0
    end
  end

  defp get_memory_usage do
    # Get memory usage of surveillance processes
    # Convert to MB
    :erlang.memory(:total) / (1024 * 1024)
  end

  defp get_cache_hit_rate do
    # Get cache hit rate from MatchingEngine
    case safe_call(fn -> MatchingEngine.get_cache_stats() end) do
      {:ok, stats} -> Map.get(stats, :hit_rate, 0.0)
      _ -> 0.0
    end
  end

  defp get_profile_alert_count(profile_id, time_range) do
    case safe_call(fn -> AlertService.get_recent_alerts(profile_id: profile_id, limit: 1000) end) do
      {:ok, alerts} ->
        cutoff_time = get_cutoff_time(time_range)

        Enum.count(alerts, fn alert ->
          DateTime.compare(alert.created_at, cutoff_time) == :gt
        end)

      _ ->
        0
    end
  end

  defp get_profile_match_rate(profile_id, time_range) do
    # Calculate matches vs total killmails processed
    alert_count = get_profile_alert_count(profile_id, time_range)

    # Estimate total killmails processed (would be tracked in real system)
    estimated_total =
      case time_range do
        :last_hour -> 100
        :last_24h -> 2400
        :last_7d -> 16_800
        :last_30d -> 72_000
      end

    if estimated_total > 0, do: Float.round(alert_count / estimated_total * 100, 2), else: 0.0
  end

  defp get_profile_false_positive_rate(profile_id, _time_range) do
    # In a real system, this would track user feedback on alert accuracy
    # For now, simulate based on profile complexity
    case safe_call(fn -> Surveillance.get_profile(profile_id) end) do
      {:ok, profile} ->
        criteria_count = length(Map.get(profile.criteria, :conditions, []))
        # More complex filters tend to have fewer false positives
        # 10% base false positive rate
        base_rate = 10.0
        # Max 8% reduction
        complexity_adjustment = min(criteria_count * 2, 8)
        max(base_rate - complexity_adjustment, 1.0)

      _ ->
        0.0
    end
  end

  defp get_profile_avg_confidence(profile_id, time_range) do
    case safe_call(fn -> AlertService.get_recent_alerts(profile_id: profile_id, limit: 100) end) do
      {:ok, alerts} ->
        cutoff_time = get_cutoff_time(time_range)

        recent_alerts =
          Enum.filter(alerts, fn alert ->
            DateTime.compare(alert.created_at, cutoff_time) == :gt
          end)

        if length(recent_alerts) > 0 do
          total_confidence = Enum.sum(Enum.map(recent_alerts, & &1.confidence_score))
          Float.round(total_confidence / length(recent_alerts), 3)
        else
          0.0
        end

      _ ->
        0.0
    end
  end

  defp calculate_profile_performance_score(profile_id, time_range) do
    alert_count = get_profile_alert_count(profile_id, time_range)
    avg_confidence = get_profile_avg_confidence(profile_id, time_range)
    false_positive_rate = get_profile_false_positive_rate(profile_id, time_range)

    # Weighted performance score
    # Max 40 points for alerts
    alert_score = min(alert_count * 2, 40)
    # Max 30 points for confidence
    confidence_score = avg_confidence * 30
    # Max 30 points for accuracy
    accuracy_score = max(0, 30 - false_positive_rate)

    Float.round(alert_score + confidence_score + accuracy_score, 1)
  end

  defp get_profile_last_alert(profile_id) do
    case safe_call(fn -> AlertService.get_recent_alerts(profile_id: profile_id, limit: 1) end) do
      {:ok, [alert | _]} -> alert.created_at
      _ -> nil
    end
  end

  defp analyze_criteria_efficiency(criteria) do
    conditions = Map.get(criteria, :conditions, [])

    %{
      total_conditions: length(conditions),
      simple_conditions: count_simple_conditions(conditions),
      complex_conditions: count_complex_conditions(conditions),
      estimated_performance: estimate_criteria_performance(conditions)
    }
  end

  defp count_simple_conditions(conditions) do
    Enum.count(conditions, fn condition ->
      condition.type in [:character_watch, :corporation_watch, :alliance_watch]
    end)
  end

  defp count_complex_conditions(conditions) do
    Enum.count(conditions, fn condition ->
      condition.type in [:chain_watch, :isk_value, :participant_count]
    end)
  end

  defp estimate_criteria_performance(conditions) do
    # Estimate performance impact of criteria
    base_score = 100

    performance_penalty =
      Enum.reduce(conditions, 0, fn condition, acc ->
        penalty =
          case condition.type do
            :character_watch -> 1
            :corporation_watch -> 1
            :alliance_watch -> 2
            :system_watch -> 3
            :ship_type_watch -> 2
            # More expensive due to Wanderer API calls
            :chain_watch -> 5
            :isk_value -> 1
            :participant_count -> 2
            _ -> 3
          end

        acc + penalty
      end)

    max(base_score - performance_penalty, 10)
  end

  defp generate_alert_trends(time_range) do
    # Generate sample trend data (in real system, query from database)
    hours =
      case time_range do
        :last_hour -> 1
        :last_24h -> 24
        :last_7d -> 168
        :last_30d -> 720
      end

    current_time = DateTime.utc_now()

    hourly_activity =
      Enum.map(0..min(hours - 1, 23), fn hour_offset ->
        timestamp = DateTime.add(current_time, -hour_offset * 3600, :second)
        # Simulate varying alert counts
        alert_count = :rand.uniform(10)

        %{
          timestamp: timestamp,
          alert_count: alert_count,
          hour_label: String.slice(Time.to_string(DateTime.to_time(timestamp)), 0, 5)
        }
      end)

    Enum.reverse(hourly_activity)
  end

  defp generate_system_recommendations(profiles, profile_metrics) do
    recommendations = []

    # Check for inactive profiles
    inactive_profiles = Enum.filter(profiles, &(!&1.enabled))

    recommendations =
      if length(inactive_profiles) > 0 do
        [
          %{
            type: :inactive_profiles,
            priority: :medium,
            title: "Inactive Profiles Detected",
            description:
              "#{length(inactive_profiles)} profiles are disabled and not generating alerts",
            action: "Review and enable relevant profiles"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Check for low-performing profiles
    low_performers = Enum.filter(profile_metrics, &(&1.performance_score < 30))

    recommendations =
      if length(low_performers) > 0 do
        [
          %{
            type: :low_performance,
            priority: :high,
            title: "Low-Performing Profiles",
            description: "#{length(low_performers)} profiles have performance scores below 30",
            action: "Optimize criteria or disable underperforming profiles"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Check for high false positive rates
    high_fp_profiles = Enum.filter(profile_metrics, &(&1.false_positive_rate > 15))

    recommendations =
      if length(high_fp_profiles) > 0 do
        [
          %{
            type: :high_false_positives,
            priority: :high,
            title: "High False Positive Rates",
            description:
              "#{length(high_fp_profiles)} profiles have false positive rates above 15%",
            action: "Refine criteria to improve accuracy"
          }
          | recommendations
        ]
      else
        recommendations
      end

    # Check system performance
    avg_response = get_average_response_time()

    recommendations =
      if avg_response > 200 do
        [
          %{
            type: :performance_degradation,
            priority: :critical,
            title: "Slow Response Times",
            description: "Average response time is #{avg_response}ms (target: <200ms)",
            action: "Optimize queries or reduce criteria complexity"
          }
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  defp generate_optimization_recommendations(profile_id) do
    # Generate specific recommendations for a profile
    case safe_call(fn -> Surveillance.get_profile(profile_id) end) do
      {:ok, profile} ->
        recommendations = []

        # Analyze criteria complexity
        conditions = Map.get(profile.criteria, :conditions, [])

        recommendations =
          if length(conditions) > 10 do
            [
              %{
                type: :reduce_complexity,
                description:
                  "Profile has #{length(conditions)} conditions. Consider reducing to improve performance."
              }
              | recommendations
            ]
          else
            recommendations
          end

        # Check for conflicting criteria
        has_chain_and_system =
          Enum.any?(conditions, &(&1.type == :chain_watch)) and
            Enum.any?(conditions, &(&1.type == :system_watch))

        recommendations =
          if has_chain_and_system do
            [
              %{
                type: :conflicting_criteria,
                description:
                  "Profile has both chain and system filters. Chain filters may be redundant."
              }
              | recommendations
            ]
          else
            recommendations
          end

        {:ok, recommendations}

      _ ->
        {:ok, []}
    end
  end

  # Helper functions

  defp get_cutoff_time(time_range) do
    current_time = DateTime.utc_now()

    case time_range do
      :last_hour -> DateTime.add(current_time, -3600, :second)
      :last_24h -> DateTime.add(current_time, -24 * 3600, :second)
      :last_7d -> DateTime.add(current_time, -7 * 24 * 3600, :second)
      :last_30d -> DateTime.add(current_time, -30 * 24 * 3600, :second)
    end
  end

  defp get_profile_hourly_breakdown(_profile_id) do
    # Generate sample hourly data
    Enum.map(0..23, fn hour ->
      %{hour: hour, alerts: :rand.uniform(5)}
    end)
  end

  defp get_criteria_performance_breakdown(_profile_id) do
    # Sample criteria performance data
    [
      %{type: "character_watch", matches: 15, performance: 95},
      %{type: "isk_value", matches: 8, performance: 87},
      %{type: "chain_watch", matches: 3, performance: 92}
    ]
  end

  defp get_recent_profile_matches(_profile_id, limit) do
    # Sample recent matches
    Enum.map(1..limit, fn i ->
      %{
        match_id: "match_#{i}",
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        confidence: 0.7 + :rand.uniform() * 0.3,
        killmail_id: "#{30_000_000 + i}"
      }
    end)
  end

  defp generate_profile_optimization_suggestions(_profile_id) do
    [
      "Consider adding ISK value filter to reduce low-value matches",
      "Chain filter performance could be improved by caching topology",
      "Participant count filter may be redundant with current criteria"
    ]
  end

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

  # Formatting helpers

  def format_performance_score(score) when is_number(score) do
    cond do
      score >= 80 -> {"#{score}", "text-green-600"}
      score >= 60 -> {"#{score}", "text-yellow-600"}
      score >= 40 -> {"#{score}", "text-orange-600"}
      true -> {"#{score}", "text-red-600"}
    end
  end

  def format_performance_score(_), do: {"N/A", "text-gray-500"}

  def format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end

  def format_percentage(_), do: "N/A"

  def format_recommendation_priority(priority) do
    case priority do
      :critical -> {"Critical", "bg-red-100 text-red-800 border-red-200"}
      :high -> {"High", "bg-orange-100 text-orange-800 border-orange-200"}
      :medium -> {"Medium", "bg-yellow-100 text-yellow-800 border-yellow-200"}
      :low -> {"Low", "bg-blue-100 text-blue-800 border-blue-200"}
      _ -> {"Unknown", "bg-gray-100 text-gray-800 border-gray-200"}
    end
  end

  def format_memory_usage(bytes) when is_number(bytes) do
    "#{Float.round(bytes, 1)} MB"
  end

  def format_memory_usage(_), do: "N/A"
end
