# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.IntelligenceDashboardLive do
  @moduledoc """
  Real-time intelligence dashboard LiveView.

  Provides a comprehensive overview of intelligence operations,
  threat monitoring, and system performance.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Intelligence.Cache.IntelligenceCache
  alias EveDmv.Intelligence.Core.IntelligenceCoordinator
  alias EveDmv.Intelligence.Wormhole.Vetting, as: WHVetting

  require Logger

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time intelligence events via EventBus
      {:ok, _ref1} = EveDmv.Infrastructure.EventBus.subscribe_process(:threat_level_updated)
      {:ok, _ref2} = EveDmv.Infrastructure.EventBus.subscribe_process(:battle_detected)
      {:ok, _ref3} = EveDmv.Infrastructure.EventBus.subscribe_process(:intelligence_alert)

      {:ok, _ref4} =
        EveDmv.Infrastructure.EventBus.subscribe_process(:system_activity_spike_detected)

      {:ok, _ref5} = EveDmv.Infrastructure.EventBus.subscribe_process(:character_analysis_updated)

      # Subscribe to global intelligence updates via real-time coordinator
      {:ok, _ref6} = EveDmv.Intelligence.RealTimeCoordinator.subscribe_to_updates(:global)

      # Subscribe to legacy PubSub topics for backward compatibility
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:updates")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:alerts")

      # Schedule periodic dashboard updates (reduced frequency due to real-time events)
      # 1 minute instead of 30 seconds
      :timer.send_interval(60_000, :update_dashboard)
    end

    socket =
      socket
      |> assign(:tab, :overview)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:dashboard_data, nil)
      |> assign(:threat_alerts, [])
      |> assign(:recent_analyses, [])
      |> assign(:cache_stats, %{})
      |> assign(:system_health, %{})
      |> assign(:selected_analysis, nil)
      |> assign(:timeframe, :last_24_hours)
      # Real-time intelligence data
      |> assign(:live_threats, [])
      |> assign(:active_battles, [])
      |> assign(:recent_events, [])
      |> assign(:connection_status, :connected)
      |> assign(:last_update, DateTime.utc_now())

    # Load initial dashboard data
    send(self(), :load_dashboard)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"
    timeframe = params["timeframe"] || "last_24_hours"

    socket =
      socket
      |> assign(:tab, String.to_existing_atom(tab))
      |> assign(:timeframe, String.to_existing_atom(timeframe))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/intelligence-dashboard?tab=#{tab}&timeframe=#{socket.assigns.timeframe}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/intelligence-dashboard?tab=#{socket.assigns.tab}&timeframe=#{timeframe}"
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("refresh_dashboard", _params, socket) do
    send(self(), :load_dashboard)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_cache", _params, socket) do
    IntelligenceCache.clear_cache()
    socket = put_flash(socket, :info, "Intelligence cache cleared successfully")
    send(self(), :load_dashboard)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl Phoenix.LiveView
  def handle_event("warm_cache", _params, socket) do
    IntelligenceCoordinator.warm_intelligence_cache()
    {:noreply, put_flash(socket, :info, "Cache warming initiated")}
  end

  @impl Phoenix.LiveView
  def handle_event("view_analysis", %{"type" => type, "id" => id}, socket) do
    analysis_data = load_analysis_details(type, id)
    {:noreply, assign(socket, :selected_analysis, analysis_data)}
  end

  @impl Phoenix.LiveView
  def handle_event("close_analysis", _params, socket) do
    {:noreply, assign(socket, :selected_analysis, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("export_dashboard", %{"format" => format}, socket) do
    case generate_dashboard_export_data(socket.assigns, format) do
      {:ok, {filename, content, content_type}} ->
        socket =
          socket
          |> push_event("download_file", %{
            filename: filename,
            content: content,
            content_type: content_type
          })
          |> put_flash(:info, "Dashboard data exported successfully")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("analyze_character", %{"character_id" => character_id_str}, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        # Start comprehensive analysis asynchronously
        Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
          case IntelligenceCoordinator.analyze_character_comprehensive(character_id) do
            {:ok, analysis} ->
              # Broadcast update to dashboard
              Phoenix.PubSub.broadcast(
                EveDmv.PubSub,
                "intelligence:updates",
                {:new_analysis, analysis}
              )

            {:error, reason} ->
              Logger.error("Character analysis failed for #{character_id}: #{inspect(reason)}")
          end
        end)

        {:noreply, put_flash(socket, :info, "Character analysis started for ID #{character_id}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid character ID")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:load_dashboard, socket) do
    {:ok, dashboard_data} =
      IntelligenceCoordinator.get_intelligence_dashboard(timeframe: socket.assigns.timeframe)

    socket =
      socket
      |> assign(:dashboard_data, dashboard_data)
      |> assign(:threat_alerts, dashboard_data.threat_alerts)
      |> assign(:recent_analyses, dashboard_data.recent_analyses)
      |> assign(:cache_stats, dashboard_data.cache_performance)
      |> assign(:system_health, dashboard_data.system_health)
      |> assign(:loading, false)
      |> assign(:error, nil)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:update_dashboard, socket) do
    # Periodic dashboard update
    send(self(), :load_dashboard)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:new_analysis, analysis}, socket) do
    # Real-time analysis update
    updated_analyses = [analysis | socket.assigns.recent_analyses]

    socket =
      socket
      |> assign(:recent_analyses, Enum.take(updated_analyses, 10))
      |> put_flash(:info, "New intelligence analysis completed")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:threat_alert, alert}, socket) do
    # Real-time threat alert
    updated_alerts = [alert | socket.assigns.threat_alerts]

    socket =
      socket
      |> assign(:threat_alerts, Enum.take(updated_alerts, 5))
      |> put_flash(:error, "New threat alert: #{alert.message}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:cache_update, stats}, socket) do
    # Real-time cache statistics update
    {:noreply, assign(socket, :cache_stats, stats)}
  end

  # Real-time intelligence event handlers

  @impl Phoenix.LiveView
  def handle_info({:domain_event, :threat_level_updated, event}, socket) do
    # Handle threat level updates
    threat_info = %{
      type: :threat_update,
      character_id: event.character_id,
      threat_level: event.new_threat_level,
      system_id: event.system_id,
      timestamp: event.updated_at,
      confidence: event.confidence_score
    }

    updated_threats =
      [threat_info | socket.assigns.live_threats]
      # Keep last 20 threat updates
      |> Enum.take(20)

    recent_event = %{
      type: :threat_change,
      message: "Threat level updated for character #{event.character_id}",
      timestamp: event.updated_at,
      priority:
        if(abs(event.new_threat_level - (event.previous_threat_level || 0)) > 0.3,
          do: :high,
          else: :medium
        )
    }

    updated_events = [recent_event | socket.assigns.recent_events] |> Enum.take(50)

    socket =
      socket
      |> assign(:live_threats, updated_threats)
      |> assign(:recent_events, updated_events)
      |> assign(:last_update, DateTime.utc_now())

    # Show flash message for significant threat changes
    socket =
      if recent_event.priority == :high do
        put_flash(socket, :warning, "⚠️ Significant threat level change detected")
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:domain_event, :battle_detected, event}, socket) do
    # Handle battle detection
    battle_info = %{
      battle_id: event.battle_id,
      system_id: event.system_id,
      participant_count: event.participant_count,
      scale: event.estimated_scale,
      status: event.battle_status,
      detected_at: event.detected_at,
      isk_destroyed: event.isk_destroyed
    }

    updated_battles =
      [battle_info | socket.assigns.active_battles]
      |> Enum.filter(fn battle ->
        # Keep battles from last 2 hours or still developing
        DateTime.diff(DateTime.utc_now(), battle.detected_at, :second) < 7200 or
          battle.status == :developing
      end)
      |> Enum.take(10)

    recent_event = %{
      type: :battle_detected,
      message:
        "#{String.capitalize(to_string(event.estimated_scale))} battle detected in system #{event.system_id}",
      timestamp: event.detected_at,
      priority:
        case event.estimated_scale do
          :capital_engagement -> :critical
          :large_fleet -> :high
          :medium_fleet -> :medium
          _ -> :low
        end
    }

    updated_events = [recent_event | socket.assigns.recent_events] |> Enum.take(50)

    socket =
      socket
      |> assign(:active_battles, updated_battles)
      |> assign(:recent_events, updated_events)
      |> assign(:last_update, DateTime.utc_now())
      |> put_flash(:info, "🔥 New battle detected: #{recent_event.message}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:domain_event, :intelligence_alert, event}, socket) do
    # Handle intelligence alerts
    alert_info = %{
      id: event.alert_id,
      type: event.alert_type,
      priority: event.priority,
      title: event.title,
      description: event.description,
      created_at: event.created_at,
      expires_at: event.expires_at,
      action_required: event.action_required
    }

    updated_alerts =
      [alert_info | socket.assigns.threat_alerts]
      |> Enum.filter(fn alert ->
        # Filter out expired alerts
        is_nil(alert.expires_at) or DateTime.compare(DateTime.utc_now(), alert.expires_at) == :lt
      end)
      |> Enum.take(10)

    recent_event = %{
      type: :intelligence_alert,
      message: event.title,
      timestamp: event.created_at,
      priority: event.priority
    }

    updated_events = [recent_event | socket.assigns.recent_events] |> Enum.take(50)

    socket =
      socket
      |> assign(:threat_alerts, updated_alerts)
      |> assign(:recent_events, updated_events)
      |> assign(:last_update, DateTime.utc_now())

    # Show appropriate flash message based on priority
    socket =
      case event.priority do
        :critical -> put_flash(socket, :error, "🚨 CRITICAL ALERT: #{event.title}")
        :high -> put_flash(socket, :warning, "⚠️ HIGH PRIORITY: #{event.title}")
        :medium -> put_flash(socket, :info, "ℹ️ Alert: #{event.title}")
        _ -> socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:domain_event, :system_activity_spike_detected, event}, socket) do
    # Handle system activity spikes
    recent_event = %{
      type: :activity_spike,
      message:
        "Activity spike in system #{event.system_id} (#{Float.round(event.spike_magnitude, 1)}x normal)",
      timestamp: event.detected_at,
      priority: if(event.spike_magnitude >= 5.0, do: :high, else: :medium)
    }

    updated_events = [recent_event | socket.assigns.recent_events] |> Enum.take(50)

    socket =
      socket
      |> assign(:recent_events, updated_events)
      |> assign(:last_update, DateTime.utc_now())

    # Show flash for significant spikes
    socket =
      if event.spike_magnitude >= 3.0 do
        put_flash(socket, :info, "📈 Activity spike detected in system #{event.system_id}")
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:domain_event, :character_analysis_updated, event}, socket) do
    # Handle character analysis updates
    recent_event = %{
      type: :analysis_update,
      message: "Character analysis updated for #{event.character_id} (#{event.analysis_type})",
      timestamp: event.updated_at,
      priority: :low
    }

    updated_events = [recent_event | socket.assigns.recent_events] |> Enum.take(50)

    updated_analyses =
      if length(event.significant_changes || []) > 0 do
        analysis_info = %{
          character_id: event.character_id,
          analysis_type: event.analysis_type,
          updated_at: event.updated_at,
          significant_changes: event.significant_changes,
          confidence_level: event.confidence_level
        }

        [analysis_info | socket.assigns.recent_analyses] |> Enum.take(10)
      else
        socket.assigns.recent_analyses
      end

    socket =
      socket
      |> assign(:recent_events, updated_events)
      |> assign(:recent_analyses, updated_analyses)
      |> assign(:last_update, DateTime.utc_now())

    {:noreply, socket}
  end

  # Helper functions

  defp load_analysis_details("character", character_id_str) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        case IntelligenceCoordinator.analyze_character_comprehensive(character_id) do
          {:ok, analysis} ->
            %{
              type: "character",
              data: analysis,
              title:
                "Character Analysis: #{analysis.basic_analysis.character_name || character_id}"
            }

          {:error, reason} ->
            %{
              type: "error",
              data: %{error: reason},
              title: "Analysis Error"
            }
        end

      _ ->
        %{
          type: "error",
          data: %{error: "Invalid character ID"},
          title: "Error"
        }
    end
  end

  defp load_analysis_details("vetting", vetting_id) do
    case Ash.get(WHVetting, vetting_id, domain: EveDmv.Api) do
      {:ok, vetting} ->
        %{
          type: "vetting",
          data: vetting,
          title: "Vetting Analysis: #{vetting.character_name}"
        }

      {:error, _} ->
        %{
          type: "error",
          data: %{error: "Vetting record not found"},
          title: "Error"
        }
    end
  end

  defp load_analysis_details(_, _) do
    %{
      type: "error",
      data: %{error: "Unknown analysis type"},
      title: "Error"
    }
  end

  # Template helper functions

  defp threat_level_color(level) when is_atom(level) do
    case level do
      :extreme -> "danger"
      :very_high -> "danger"
      :high -> "warning"
      :moderate -> "info"
      :low -> "success"
      :minimal -> "secondary"
      _ -> "secondary"
    end
  end

  defp threat_level_color(_), do: "secondary"

  defp system_status_color(status) when is_binary(status) do
    case status do
      "healthy" -> "success"
      "warning" -> "warning"
      "error" -> "danger"
      "unknown" -> "secondary"
      _ -> "secondary"
    end
  end

  defp system_status_color(_), do: "secondary"

  defp relative_time(datetime) when is_struct(datetime, DateTime) do
    case EveDmvWeb.Helpers.TimeFormatter.format_relative_time(datetime) do
      result when is_binary(result) -> result
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp relative_time(_), do: "unknown"

  defp format_time(datetime) when is_struct(datetime, DateTime) do
    case EveDmvWeb.Helpers.TimeFormatter.format_datetime(datetime) do
      result when is_binary(result) -> result
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp format_time(_), do: "unknown"

  # Export functions

  defp generate_dashboard_export_data(assigns, format) do
    case assigns do
      %{dashboard_data: nil} ->
        {:error, "No dashboard data to export"}

      %{dashboard_data: dashboard_data} ->
        case format do
          "json" ->
            export_data = %{
              export_timestamp: DateTime.utc_now(),
              timeframe: assigns.timeframe,
              dashboard_data: dashboard_data,
              threat_alerts: assigns.threat_alerts,
              recent_analyses: assigns.recent_analyses,
              cache_stats: assigns.cache_stats,
              system_health: assigns.system_health
            }

            content = Jason.encode!(export_data, pretty: true)
            filename = "intelligence_dashboard_#{Date.utc_today()}.json"
            {:ok, {filename, content, "application/json"}}

          "csv" ->
            case generate_dashboard_csv_export(assigns) do
              {:ok, content} ->
                filename = "intelligence_dashboard_#{Date.utc_today()}.csv"
                {:ok, {filename, content, "text/csv"}}

              error ->
                error
            end

          _ ->
            {:error, "Unsupported format"}
        end
    end
  end

  defp generate_dashboard_csv_export(assigns) do
    try do
      # Create summary CSV of key dashboard metrics
      headers = [
        "metric",
        "value",
        "timestamp",
        "status",
        "change_24h",
        "trend"
      ]

      dashboard_data = assigns.dashboard_data

      rows = [
        [
          "Active Threats",
          Map.get(dashboard_data, :active_threats, 0),
          DateTime.utc_now(),
          "normal",
          "",
          "stable"
        ],
        [
          "Recent Analyses",
          length(assigns.recent_analyses),
          DateTime.utc_now(),
          "normal",
          "",
          "stable"
        ],
        [
          "Cache Hit Rate",
          Map.get(assigns.cache_stats, :hit_rate, 0),
          DateTime.utc_now(),
          "normal",
          "",
          "stable"
        ],
        [
          "System Health Score",
          Map.get(assigns.system_health, :overall_score, 100),
          DateTime.utc_now(),
          "normal",
          "",
          "stable"
        ]
      ]

      content =
        [headers | rows]
        |> Enum.map(fn row ->
          row
          |> Enum.map(&to_string/1)
          |> Enum.map(&escape_csv_field/1)
          |> Enum.join(",")
        end)
        |> Enum.join("\n")

      {:ok, content}
    rescue
      error ->
        Logger.error("Dashboard CSV export failed: #{inspect(error)}")
        {:error, "CSV generation failed"}
    end
  end

  defp escape_csv_field(field) do
    field_str = to_string(field)

    if String.contains?(field_str, [",", "\"", "\n"]) do
      "\"#{String.replace(field_str, "\"", "\"\"")}\""
    else
      field_str
    end
  end
end
