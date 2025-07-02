defmodule EveDmvWeb.IntelligenceDashboardLive do
  @moduledoc """
  Real-time intelligence dashboard LiveView.

  Provides a comprehensive overview of intelligence operations,
  threat monitoring, and system performance.
  """

  use EveDmvWeb, :live_view

  require Logger

  alias EveDmv.Intelligence.{
    CharacterStats,
    IntelligenceCache,
    IntelligenceCoordinator,
    WHVetting
  }

  on_mount {EveDmvWeb.AuthLive, :load_from_session}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to intelligence updates
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:updates")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:alerts")

      # Schedule periodic dashboard updates
      # 30 seconds
      :timer.send_interval(30_000, :update_dashboard)
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

    # Load initial dashboard data
    send(self(), :load_dashboard)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"
    timeframe = params["timeframe"] || "last_24_hours"

    socket =
      socket
      |> assign(:tab, String.to_atom(tab))
      |> assign(:timeframe, String.to_atom(timeframe))

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/intelligence-dashboard?tab=#{tab}&timeframe=#{socket.assigns.timeframe}"
     )}
  end

  @impl true
  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/intelligence-dashboard?tab=#{socket.assigns.tab}&timeframe=#{timeframe}"
     )}
  end

  @impl true
  def handle_event("refresh_dashboard", _params, socket) do
    send(self(), :load_dashboard)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl true
  def handle_event("clear_cache", _params, socket) do
    case IntelligenceCache.clear_cache() do
      :ok ->
        socket = put_flash(socket, :info, "Intelligence cache cleared successfully")
        send(self(), :load_dashboard)
        {:noreply, assign(socket, :loading, true)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to clear cache: #{reason}")}
    end
  end

  @impl true
  def handle_event("warm_cache", _params, socket) do
    IntelligenceCoordinator.warm_intelligence_cache()
    {:noreply, put_flash(socket, :info, "Cache warming initiated")}
  end

  @impl true
  def handle_event("view_analysis", %{"type" => type, "id" => id}, socket) do
    analysis_data = load_analysis_details(type, id)
    {:noreply, assign(socket, :selected_analysis, analysis_data)}
  end

  @impl true
  def handle_event("close_analysis", _params, socket) do
    {:noreply, assign(socket, :selected_analysis, nil)}
  end

  @impl true
  def handle_event("analyze_character", %{"character_id" => character_id_str}, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        # Start comprehensive analysis asynchronously
        Task.start(fn ->
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

  @impl true
  def handle_info(:load_dashboard, socket) do
    case IntelligenceCoordinator.get_intelligence_dashboard(timeframe: socket.assigns.timeframe) do
      {:ok, dashboard_data} ->
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

      {:error, reason} ->
        Logger.error("Failed to load dashboard: #{inspect(reason)}")

        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load dashboard data")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:update_dashboard, socket) do
    # Periodic dashboard update
    send(self(), :load_dashboard)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_analysis, analysis}, socket) do
    # Real-time analysis update
    updated_analyses = [analysis | socket.assigns.recent_analyses]

    socket =
      socket
      |> assign(:recent_analyses, Enum.take(updated_analyses, 10))
      |> put_flash(:info, "New intelligence analysis completed")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:threat_alert, alert}, socket) do
    # Real-time threat alert
    updated_alerts = [alert | socket.assigns.threat_alerts]

    socket =
      socket
      |> assign(:threat_alerts, Enum.take(updated_alerts, 5))
      |> put_flash(:error, "New threat alert: #{alert.message}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:cache_update, stats}, socket) do
    # Real-time cache statistics update
    {:noreply, assign(socket, :cache_stats, stats)}
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
    case EveDmv.Api.get(WHVetting, vetting_id) do
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

  defp format_threat_level(level) do
    case level do
      "Critical" -> {"Critical", "text-red-600 bg-red-100"}
      "High" -> {"High", "text-orange-600 bg-orange-100"}
      "Medium" -> {"Medium", "text-yellow-600 bg-yellow-100"}
      "Low" -> {"Low", "text-blue-600 bg-blue-100"}
      "Minimal" -> {"Minimal", "text-green-600 bg-green-100"}
      _ -> {"Unknown", "text-gray-600 bg-gray-100"}
    end
  end

  defp format_timeframe(timeframe) do
    case timeframe do
      :last_hour -> "Last Hour"
      :last_6_hours -> "Last 6 Hours"
      :last_24_hours -> "Last 24 Hours"
      :last_week -> "Last Week"
      :last_month -> "Last Month"
      _ -> "Last 24 Hours"
    end
  end

  defp format_cache_health(hit_ratio) when is_number(hit_ratio) do
    cond do
      hit_ratio >= 80 -> {"Excellent", "text-green-600"}
      hit_ratio >= 60 -> {"Good", "text-blue-600"}
      hit_ratio >= 40 -> {"Fair", "text-yellow-600"}
      hit_ratio >= 20 -> {"Poor", "text-orange-600"}
      true -> {"Critical", "text-red-600"}
    end
  end

  defp format_cache_health(_), do: {"Unknown", "text-gray-600"}

  defp format_system_status(status) do
    case status do
      "operational" -> {"Operational", "text-green-600"}
      "degraded" -> {"Degraded", "text-yellow-600"}
      "error" -> {"Error", "text-red-600"}
      _ -> {"Unknown", "text-gray-600"}
    end
  end

  defp format_relative_time(datetime) when is_struct(datetime, DateTime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86_400)}d ago"
    end
  end

  defp format_relative_time(_), do: "Unknown"

  defp get_confidence_color(confidence) when is_number(confidence) do
    cond do
      confidence >= 0.9 -> "text-green-600"
      confidence >= 0.7 -> "text-blue-600"
      confidence >= 0.5 -> "text-yellow-600"
      confidence >= 0.3 -> "text-orange-600"
      true -> "text-red-600"
    end
  end

  defp get_confidence_color(_), do: "text-gray-600"

  defp get_analysis_type_badge(type) do
    case type do
      "character" -> {"Character", "bg-blue-100 text-blue-800"}
      "vetting" -> {"Vetting", "bg-purple-100 text-purple-800"}
      "correlation" -> {"Correlation", "bg-green-100 text-green-800"}
      "group" -> {"Group", "bg-yellow-100 text-yellow-800"}
      _ -> {"Unknown", "bg-gray-100 text-gray-800"}
    end
  end

  defp format_number(number) when is_integer(number) do
    Number.Delimit.number_to_delimited(number, delimiter: ",")
  end

  defp format_number(number) when is_float(number) do
    :erlang.float_to_binary(number, decimals: 1)
  end

  defp format_number(_), do: "0"

  defp get_timeframe_options do
    [
      {:last_hour, "Last Hour"},
      {:last_6_hours, "Last 6 Hours"},
      {:last_24_hours, "Last 24 Hours"},
      {:last_week, "Last Week"},
      {:last_month, "Last Month"}
    ]
  end
end
