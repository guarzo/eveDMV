defmodule EveDmvWeb.SystemActivityLive do
  use EveDmvWeb, :live_view

  import EveDmvWeb.Components.PageHeaderComponent
  import EveDmvWeb.Components.StatsGridComponent

  alias EveDmv.Analytics.SystemActivityMetrics
  alias EveDmv.Presentation.Formatters

  @topic "system_activity"

  # Load current user from session (require auth for this analytical feature)
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, @topic)
    end

    socket =
      socket
      |> assign(:selected_timeframe, :last_7_days)
      |> assign(:selected_system_id, nil)
      |> assign(:system_metrics, nil)
      |> assign(:regional_metrics, nil)
      |> assign(:activity_heatmap, nil)
      |> assign(:activity_trends, nil)
      |> assign(:loading, false)
      |> assign(:view_mode, :overview)
      |> load_overview_data()

    {:ok, socket}
  end

  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    timeframe_atom = String.to_existing_atom(timeframe)

    socket =
      socket
      |> assign(:selected_timeframe, timeframe_atom)
      |> assign(:loading, true)
      |> load_data_for_current_view()

    {:noreply, socket}
  end

  def handle_event("select_system", %{"system_id" => system_id_str}, socket) do
    case Integer.parse(system_id_str) do
      {system_id, ""} ->
        socket =
          socket
          |> assign(:selected_system_id, system_id)
          |> assign(:view_mode, :system_detail)
          |> assign(:loading, true)
          |> load_system_detail(system_id)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid system ID")}
    end
  end

  def handle_event("change_view", %{"view" => view}, socket) do
    view_atom = String.to_existing_atom(view)

    socket =
      socket
      |> assign(:view_mode, view_atom)
      |> assign(:loading, true)
      |> load_data_for_current_view()

    {:noreply, socket}
  end

  def handle_event("refresh_data", _params, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> load_data_for_current_view()

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "system_activity", event: "update"}, socket) do
    # Refresh data when new killmails arrive
    socket = load_data_for_current_view(socket)
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Private helper functions

  defp load_data_for_current_view(socket) do
    case socket.assigns.view_mode do
      :overview -> load_overview_data(socket)
      :system_detail -> load_system_detail(socket, socket.assigns.selected_system_id)
      :regional -> load_regional_data(socket)
      :trends -> load_trends_data(socket)
      :heatmap -> load_heatmap_data(socket)
    end
  end

  defp load_overview_data(socket) do
    timeframe = socket.assigns.selected_timeframe

    # Load activity trends for overview
    trends = SystemActivityMetrics.get_activity_trends(timeframe)

    # Load sample regional data for top systems
    # Get top 10 active systems
    top_systems = get_top_active_system_ids(10)

    regional_metrics =
      if length(top_systems) > 0 do
        SystemActivityMetrics.get_regional_activity_metrics(top_systems, timeframe)
      else
        %{system_metrics: [], hotspots: []}
      end

    socket
    |> assign(:activity_trends, trends)
    |> assign(:regional_metrics, regional_metrics)
    |> assign(:loading, false)
  end

  defp load_system_detail(socket, system_id) do
    if system_id do
      timeframe = socket.assigns.selected_timeframe
      metrics = SystemActivityMetrics.get_system_metrics(system_id, timeframe)

      socket
      |> assign(:system_metrics, metrics)
      |> assign(:loading, false)
    else
      socket |> assign(:loading, false)
    end
  end

  defp load_regional_data(socket) do
    timeframe = socket.assigns.selected_timeframe

    # Get active systems for regional analysis
    system_ids = get_active_system_ids_for_timeframe(timeframe, 50)
    regional_metrics = SystemActivityMetrics.get_regional_activity_metrics(system_ids, timeframe)

    socket
    |> assign(:regional_metrics, regional_metrics)
    |> assign(:loading, false)
  end

  defp load_trends_data(socket) do
    timeframe = socket.assigns.selected_timeframe
    trends = SystemActivityMetrics.get_activity_trends(timeframe)

    socket
    |> assign(:activity_trends, trends)
    |> assign(:loading, false)
  end

  defp load_heatmap_data(socket) do
    timeframe = socket.assigns.selected_timeframe
    heatmap = SystemActivityMetrics.get_activity_heatmap(timeframe, 100)

    socket
    |> assign(:activity_heatmap, heatmap)
    |> assign(:loading, false)
  end

  # Helper functions for getting system IDs
  defp get_top_active_system_ids(limit) do
    # This would query for the most active systems
    # For now, return some sample system IDs
    [
      30_000_142,
      30_000_144,
      30_000_145,
      30_000_146,
      30_000_147,
      30_000_148,
      30_000_149,
      30_000_150,
      30_000_151,
      30_000_152
    ]
    |> Enum.take(limit)
  end

  defp get_active_system_ids_for_timeframe(_timeframe, limit) do
    # This would query for active systems in the timeframe
    # For now, return more sample system IDs
    30_000_142..30_000_200
    |> Enum.to_list()
    |> Enum.take(limit)
  end

  # Delegate formatting functions
  defdelegate format_isk(value), to: Formatters
  defdelegate format_number(value), to: Formatters
  defdelegate format_percentage(value), to: Formatters

  # Helper functions for UI
  def format_danger_rating(rating) do
    case rating do
      :safe -> {"Safe", "text-green-400"}
      :low -> {"Low Risk", "text-yellow-400"}
      :moderate -> {"Moderate", "text-orange-400"}
      :high -> {"High Risk", "text-red-400"}
      :extreme -> {"Extreme", "text-red-600"}
    end
  end

  def format_activity_trend(trend) do
    case trend do
      :increasing -> {"↗ Increasing", "text-green-400"}
      :decreasing -> {"↘ Decreasing", "text-red-400"}
      :stable -> {"→ Stable", "text-gray-400"}
    end
  end

  def format_timeframe(timeframe) do
    case timeframe do
      :last_24_hours -> "Last 24 Hours"
      :last_7_days -> "Last 7 Days"
      :last_30_days -> "Last 30 Days"
      :last_90_days -> "Last 90 Days"
    end
  end

  def security_class_color(security_class) do
    case security_class do
      :highsec -> "text-green-400"
      :lowsec -> "text-yellow-400"
      :nullsec -> "text-red-400"
      :wormhole -> "text-purple-400"
      _ -> "text-gray-400"
    end
  end

  def format_datetime_ago(datetime) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86_400)}d ago"
    end
  end
end
