# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.IntelligenceDashboardLive do
  @moduledoc """
  Real-time intelligence dashboard LiveView.

  Provides a comprehensive overview of intelligence operations,
  threat monitoring, and system performance.
  """

  use EveDmvWeb, :live_view

  require Logger

  alias EveDmv.Intelligence.Cache.IntelligenceCache
  alias EveDmv.Intelligence.Core.IntelligenceCoordinator
  alias EveDmv.Intelligence.Wormhole.Vetting, as: WHVetting

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
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
end
