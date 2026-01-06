defmodule EveDmvWeb.SystemActivityLive do
  @moduledoc """
  LiveView for displaying real-time system activity in EVE Online.

  Shows current PvP activity, recent kills, and danger metrics
  for a selected solar system with automatic updates via PubSub.
  """

  use EveDmvWeb, :live_view

  import EveDmvWeb.Components.PageHeaderComponent

  alias EveDmv.Contexts.SystemAnalysis
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Presentation.Formatters

  @topic "system_activity"

  # Load current user from session (require auth for this analytical feature)
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, @topic)
    end

    socket =
      socket
      |> assign(:selected_timeframe, :last_24_hours)
      |> assign(:selected_system_id, nil)
      |> assign(:system_metrics, nil)
      |> assign(:regional_metrics, nil)
      |> assign(:activity_heatmap, nil)
      |> assign(:activity_trends, nil)
      |> assign(:overview_metrics, %{})
      |> assign(:escalation_alerts, [])
      |> assign(:top_systems, [])
      |> assign(:auto_refresh, true)
      |> assign(:loading, false)
      |> assign(:view_mode, :overview)
      |> load_overview_data()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
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

  def handle_event("dismiss_alert", %{"alert_id" => alert_id}, socket) do
    # Remove alert from the list (in production, this might mark it as dismissed in DB)
    updated_alerts =
      Enum.reject(socket.assigns.escalation_alerts, fn alert ->
        to_string(alert.system_id) == alert_id
      end)

    socket =
      socket
      |> assign(:escalation_alerts, updated_alerts)
      |> put_flash(:info, "Alert dismissed")

    {:noreply, socket}
  end

  def handle_event("view_alert_system", %{"system_id" => system_id_str}, socket) do
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

  @impl Phoenix.LiveView
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
    # Load overview metrics using SystemAnalysis
    case SystemAnalysis.get_overview_metrics() do
      {:ok, metrics} ->
        # Load escalation alerts
        escalation_alerts = SystemAnalysis.get_escalation_alerts()

        # Load hot zones
        case SystemAnalysis.identify_hot_zones(hours: 24) do
          {:ok, zones} ->
            socket
            |> assign(:overview_metrics, metrics)
            |> assign(:escalation_alerts, escalation_alerts)
            |> assign(:top_systems, zones.hot_zones |> Enum.take(10))
            |> assign(:loading, false)

          {:error, _reason} ->
            socket
            |> assign(:overview_metrics, metrics)
            |> assign(:escalation_alerts, escalation_alerts)
            |> assign(:top_systems, [])
            |> assign(:loading, false)
        end

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Failed to load system analytics")
        |> assign(:overview_metrics, %{})
        |> assign(:escalation_alerts, [])
        |> assign(:top_systems, [])
        |> assign(:loading, false)
    end
  end

  defp load_system_detail(socket, system_id) do
    if system_id do
      timeframe = socket.assigns.selected_timeframe
      metrics = calculate_system_metrics_from_killmails(system_id, timeframe)

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
    regional_metrics = calculate_regional_metrics_from_killmails(system_ids, timeframe)

    socket
    |> assign(:regional_metrics, regional_metrics)
    |> assign(:loading, false)
  end

  defp load_trends_data(socket) do
    timeframe = socket.assigns.selected_timeframe
    trends = calculate_activity_trends_from_killmails(timeframe)

    socket
    |> assign(:activity_trends, trends)
    |> assign(:loading, false)
  end

  defp load_heatmap_data(socket) do
    hours =
      case socket.assigns.selected_timeframe do
        :last_24_hours -> 24
        :last_7_days -> 168
        :last_30_days -> 720
        :last_90_days -> 2160
        _ -> 24
      end

    case SystemAnalysis.generate_heatmap(hours: hours, limit: 100) do
      {:ok, heatmap_data} ->
        socket
        |> assign(:activity_heatmap, heatmap_data)
        |> push_event("update-heatmap", %{data: heatmap_data})
        |> assign(:loading, false)

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Failed to generate heatmap")
        |> assign(:activity_heatmap, %{})
        |> assign(:loading, false)
    end
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
    diff_seconds = DateTimeUtils.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86_400)}d ago"
    end
  end

  def format_escalation_severity(severity) do
    case severity do
      :critical -> {"Critical", "bg-red-600 text-red-100"}
      :high -> {"High", "bg-orange-600 text-orange-100"}
      :medium -> {"Medium", "bg-yellow-600 text-yellow-100"}
      :low -> {"Low", "bg-blue-600 text-blue-100"}
      _ -> {"Unknown", "bg-gray-600 text-gray-100"}
    end
  end

  def format_escalation_type(escalation_type) do
    case escalation_type do
      :massive_engagement -> "Massive Fleet Battle"
      :fleet_battle -> "Fleet Battle"
      :capital_engagement -> "Capital Ships Engaged"
      :expensive_battle -> "High-Value Engagement"
      :skirmish -> "Skirmish"
      :activity_spike -> "Activity Spike"
      _ -> "Unknown"
    end
  end

  # Real implementations using killmail data

  defp calculate_activity_trends_from_killmails(timeframe) do
    {:ok, killmails} = get_killmails_for_timeframe(timeframe)

    total_activity = length(killmails)

    # Calculate period-over-period change
    previous_timeframe = get_previous_timeframe(timeframe)
    {:ok, previous_killmails} = get_killmails_for_timeframe(previous_timeframe)
    previous_activity = length(previous_killmails)

    change =
      if previous_activity > 0 do
        (total_activity - previous_activity) / previous_activity * 100
      else
        0.0
      end

    trend_direction =
      cond do
        change > 5 -> :increasing
        change < -5 -> :decreasing
        true -> :stable
      end

    %{
      total_activity: total_activity,
      trend_direction: trend_direction,
      period_over_period_change: Float.round(change, 1)
    }
  end

  defp calculate_regional_metrics_from_killmails(system_ids, timeframe) do
    {:ok, killmails} = get_killmails_for_timeframe(timeframe)

    # Filter killmails to specified systems
    system_killmails = Enum.filter(killmails, fn km -> km.solar_system_id in system_ids end)

    # Group by system and calculate metrics
    system_metrics =
      system_killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, kms} ->
        %{
          system_id: system_id,
          killmail_count: length(kms),
          total_isk_value: Enum.sum(Enum.map(kms, &(&1.zkb_total_value || 0))),
          unique_characters: length(Enum.uniq(Enum.map(kms, & &1.victim.character_id)))
        }
      end)
      |> Enum.sort_by(& &1.killmail_count, :desc)

    # Identify hotspots (top 25% by activity)
    hotspot_threshold = max(1, div(length(system_metrics), 4))
    hotspots = Enum.take(system_metrics, hotspot_threshold)

    %{
      system_metrics: system_metrics,
      hotspots: hotspots
    }
  end

  defp calculate_system_metrics_from_killmails(system_id, timeframe) do
    {:ok, killmails} = get_killmails_for_timeframe(timeframe)

    # Filter to specific system
    system_killmails = Enum.filter(killmails, fn km -> km.solar_system_id == system_id end)

    if Enum.empty?(system_killmails) do
      %{activity_score: 0.0, classifications: [], peak_hours: []}
    else
      # Calculate activity score based on killmail frequency and value
      killmail_count = length(system_killmails)
      total_value = Enum.sum(Enum.map(system_killmails, &(&1.zkb_total_value || 0)))

      activity_score =
        Float.round(killmail_count * :math.log10(max(1, total_value / 1_000_000)), 2)

      # Classify activity type based on patterns
      classifications = classify_system_activity(system_killmails)

      # Find peak hours
      peak_hours = calculate_peak_hours(system_killmails)

      %{
        activity_score: activity_score,
        classifications: classifications,
        peak_hours: peak_hours
      }
    end
  end

  defp classify_system_activity(killmails) do
    base_classifications = []

    # High value activity
    high_value_kills = Enum.count(killmails, fn km -> (km.zkb_total_value || 0) > 100_000_000 end)

    value_classifications =
      if high_value_kills > 0,
        do: ["High Value Targets" | base_classifications],
        else: base_classifications

    # Capital activity
    capital_kills =
      Enum.count(killmails, fn km ->
        ship_class = EveDmv.StaticData.get_ship_class(km.victim.ship_type_id)
        ship_class in [:dreadnought, :carrier, :supercarrier, :titan]
      end)

    capital_classifications =
      if capital_kills > 0,
        do: ["Capital Warfare" | value_classifications],
        else: value_classifications

    # Gang activity (multiple attackers)
    gang_kills = Enum.count(killmails, fn km -> length(km.attackers) > 5 end)
    total_kills = length(killmails)

    final_classifications =
      if gang_kills / total_kills > 0.5 do
        ["Fleet Operations" | capital_classifications]
      else
        capital_classifications
      end

    final_classifications
  end

  defp calculate_peak_hours(killmails) do
    # Group by hour of day and find peaks
    hourly_activity =
      killmails
      |> Enum.group_by(fn km -> km.killmail_time.hour end)
      |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, _count} -> hour end)

    hourly_activity
  end

  defp get_previous_timeframe(:last_24h), do: :previous_24h
  defp get_previous_timeframe(:last_7d), do: :previous_7d
  defp get_previous_timeframe(:last_30d), do: :previous_30d
  defp get_previous_timeframe(_), do: :last_24h

  defp get_killmails_for_timeframe(timeframe) do
    case timeframe do
      :last_24h ->
        since = DateTimeUtils.add(DateTime.utc_now(), -24 * 60 * 60, :second)

        Ash.read(EveDmv.Killmails.KillmailRaw,
          query: [filter: [killmail_time: [greater_than: since]]],
          domain: EveDmv.Api
        )

      :previous_24h ->
        since = DateTimeUtils.add(DateTime.utc_now(), -48 * 60 * 60, :second)
        until = DateTimeUtils.add(DateTime.utc_now(), -24 * 60 * 60, :second)

        Ash.read(EveDmv.Killmails.KillmailRaw,
          query: [filter: [killmail_time: [greater_than: since, less_than: until]]],
          domain: EveDmv.Api
        )

      :last_7d ->
        since = DateTimeUtils.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

        Ash.read(EveDmv.Killmails.KillmailRaw,
          query: [filter: [killmail_time: [greater_than: since]]],
          domain: EveDmv.Api
        )

      :previous_7d ->
        since = DateTimeUtils.add(DateTime.utc_now(), -14 * 24 * 60 * 60, :second)
        until = DateTimeUtils.add(DateTime.utc_now(), -7 * 24 * 60 * 60, :second)

        Ash.read(EveDmv.Killmails.KillmailRaw,
          query: [filter: [killmail_time: [greater_than: since, less_than: until]]],
          domain: EveDmv.Api
        )

      :last_30d ->
        since = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

        Ash.read(EveDmv.Killmails.KillmailRaw,
          query: [filter: [killmail_time: [greater_than: since]]],
          domain: EveDmv.Api
        )

      :previous_30d ->
        since = DateTimeUtils.add(DateTime.utc_now(), -60 * 24 * 60 * 60, :second)
        until = DateTimeUtils.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)

        Ash.read(EveDmv.Killmails.KillmailRaw,
          query: [filter: [killmail_time: [greater_than: since, less_than: until]]],
          domain: EveDmv.Api
        )

      _ ->
        {:ok, []}
    end
  end
end
