# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout
defmodule EveDmvWeb.CorporationLive do
  @moduledoc """
  LiveView for displaying corporation overview and member activity.

  Shows corporation statistics, member list, recent activity, and
  top performing pilots within the corporation.
  """

  use EveDmvWeb, :live_view

  import EveDmvWeb.Components.ErrorStateComponent
  import EveDmvWeb.Components.EmptyStateComponent
  import EveDmvWeb.Components.ThreatLevelComponent
  import EveDmvWeb.Components.ActivityOverviewComponent
  import EveDmvWeb.Components.IskStatsComponent
  import EveDmvWeb.Components.HistoricalFetchIndicator
  import EveDmvWeb.EveImageComponents
  import EveDmvWeb.FormatHelpers

  alias EveDmv.Contexts.BattleAnalysis.Domain.Services.DetectionService, as: BattleDetector
  alias EveDmv.Contexts.CorporationIntelligence
  alias EveDmv.Contexts.KillmailProcessing
  alias EveDmv.Pagination.CursorPaginator
  alias EveDmv.Platform.Cache.AnalysisCache
  alias EveDmvWeb.CorporationLive.DataLoader
  alias EveDmvWeb.Helpers.TimeFormatter

  require Logger

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  # Template helper functions
  def format_relative_time(datetime) do
    TimeFormatter.format_friendly_time(datetime)
  end

  @impl Phoenix.LiveView
  def mount(%{"corporation_id" => corp_id_str}, _session, socket) do
    case Integer.parse(corp_id_str) do
      {corporation_id, ""} ->
        # Subscribe to historical fetch updates when connected
        if connected?(socket) do
          subscribe_to_historical_fetch(:corporation, corporation_id)
        end

        # Get current historical fetch status
        historical_status = get_historical_fetch_status(:corporation, corporation_id)

        # Start with loading state
        socket =
          socket
          |> assign(:loading, true)
          |> assign(:corporation_id, corporation_id)
          |> assign(:error, nil)
          |> assign(:active_tab, "overview")
          |> assign(:historical_fetch_status, historical_status)

        # Load data asynchronously
        send(self(), :load_corporation_data)

        # Use temporary_assigns to clear large list-based data from process memory after render
        # Members and recent_activity already use streams; this handles other large lists
        {:ok, socket,
         temporary_assigns: [
           recent_battles: [],
           fleet_doctrines: [],
           ship_usage: []
         ]}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid corporation ID")
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:load_corporation_data, socket) do
    corporation_id = socket.assigns.corporation_id

    # Load all data using the optimized data loader
    case load_all_corporation_data(corporation_id) do
      {:ok, data} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:corp_info, data.info)
          |> assign(:corp_stats, data.stats.last_30_days)
          |> assign(:comprehensive_stats, data.stats)
          |> assign(:timezone_data, data.timezone)
          |> assign(:ship_usage, data.ships)
          |> assign(:location_stats, data.location_stats || %{})
          |> assign(:victim_stats, data.victim_stats || %{})
          |> assign(:intelligence_data, data.intelligence)
          |> assign(:recent_battles, data.battles)
          |> assign(:battle_stats, data.battle_stats)
          |> assign(:fleet_doctrines, data.fleet_doctrines)
          |> assign(:participation_data, calculate_participation_data(data.members, data.info))
          |> stream(:members, data.members || [], at: -1, dom_id: &"member-#{&1.character_id}")
          |> stream(:recent_activity, data.activity || [],
            at: -1,
            dom_id: &"activity-#{&1.killmail_id}-#{&1.character_id}"
          )

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to load corporation data: #{inspect(reason)}")

        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load corporation data")

        {:noreply, socket}
    end
  end

  # Handle historical fetch status updates via PubSub
  def handle_info({:historical_fetch_update, :corporation, entity_id, update}, socket) do
    corporation_id = socket.assigns.corporation_id

    # Only process updates for this corporation
    if entity_id != corporation_id do
      {:noreply, socket}
    else
      case update do
        {:progress, progress} ->
          # Targeted update: Only update progress status, no database queries
          status = get_historical_fetch_status(:corporation, corporation_id)

          socket =
            socket
            |> assign(:historical_fetch_status, status)
            |> maybe_update_progress_info(progress)

          {:noreply, socket}

        {:completed, result} ->
          # Targeted update: Update status and incrementally update stats
          status = get_historical_fetch_status(:corporation, corporation_id)

          # Calculate incremental stats update without full reload
          new_killmails_count = Map.get(result, :new_killmails, 0)

          socket =
            socket
            |> assign(:historical_fetch_status, status)
            |> update(:comp_stats, &increment_comp_stats_kills(&1, new_killmails_count))
            |> update(
              :comprehensive_stats,
              &increment_last_30_days_kills(&1, new_killmails_count)
            )
            |> put_flash(
              :info,
              "Historical data fetch completed. #{new_killmails_count} new killmails loaded."
            )

          {:noreply, socket}

        {:failed, reason} ->
          status = get_historical_fetch_status(:corporation, corporation_id)

          socket =
            socket
            |> assign(:historical_fetch_status, status)
            |> put_flash(:error, "Historical fetch failed: #{inspect(reason)}")

          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    end
  end

  # Helper for progress updates
  defp maybe_update_progress_info(socket, progress) do
    case progress do
      %{killmails_fetched: count} when is_integer(count) and count > 0 ->
        # Update a progress indicator if we track it in assigns
        socket

      _ ->
        socket
    end
  end

  # Helper for incrementing comp_stats kills count
  defp increment_comp_stats_kills(nil, _count), do: nil

  defp increment_comp_stats_kills(stats, count) do
    Map.update(stats, :total_kills, count, &(&1 + count))
  end

  # Helper for incrementing last 30 days kills count
  defp increment_last_30_days_kills(nil, _count), do: nil

  defp increment_last_30_days_kills(stats, count) do
    if stats[:last_30_days] do
      current = get_in(stats, [:last_30_days, :total_kills]) || 0
      put_in(stats, [:last_30_days, :total_kills], current + count)
    else
      stats
    end
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    corporation_id = socket.assigns.corporation_id

    # Invalidate cache for this corporation
    AnalysisCache.invalidate_corporation(corporation_id)

    # Show loading state
    socket =
      socket
      |> assign(:loading, true)
      |> put_flash(:info, "Refreshing corporation data...")

    # Reload data asynchronously
    send(self(), :load_corporation_data)

    {:noreply, socket}
  end

  def handle_event("paginate_members_next", %{"cursor" => cursor}, socket) do
    corporation_id = socket.assigns.corporation_id
    page_size = socket.assigns[:members_page_size] || 50

    case CursorPaginator.paginate_corporation_members(
           corporation_id,
           after: cursor,
           page_size: page_size
         ) do
      paginator ->
        pagination = CursorPaginator.pagination_assigns(paginator)

        socket =
          socket
          |> stream(:members, pagination.items, at: -1, dom_id: &"member-#{&1.character_id}")
          |> assign(:members_pagination, pagination)

        {:noreply, socket}
    end
  end

  def handle_event("paginate_members_prev", %{"cursor" => cursor}, socket) do
    corporation_id = socket.assigns.corporation_id
    page_size = socket.assigns[:members_page_size] || 50

    case CursorPaginator.paginate_corporation_members(
           corporation_id,
           before: cursor,
           page_size: page_size
         ) do
      paginator ->
        pagination = CursorPaginator.pagination_assigns(paginator)

        socket =
          socket
          |> stream(:members, pagination.items, reset: true, dom_id: &"member-#{&1.character_id}")
          |> assign(:members_pagination, pagination)

        {:noreply, socket}
    end
  end

  def handle_event("paginate_members_size", %{"value" => size_str}, socket) do
    corporation_id = socket.assigns.corporation_id
    page_size = String.to_integer(size_str)

    # Reset to first page with new size
    case CursorPaginator.paginate_corporation_members(
           corporation_id,
           page_size: page_size
         ) do
      paginator ->
        pagination = CursorPaginator.pagination_assigns(paginator)

        socket =
          socket
          |> stream(:members, pagination.items, reset: true, dom_id: &"member-#{&1.character_id}")
          |> assign(:members_pagination, pagination)
          |> assign(:members_page_size, page_size)

        {:noreply, socket}
    end
  end

  # Activity pagination handlers
  def handle_event("load_more_activity", %{"cursor" => cursor}, socket) do
    corporation_id = socket.assigns.corporation_id

    # Load more activity using cursor pagination
    case load_more_recent_activity(corporation_id, cursor) do
      {:ok, activities} ->
        socket =
          stream(socket, :recent_activity, activities,
            at: -1,
            dom_id: &"activity-#{&1.killmail_id}-#{&1.character_id}"
          )

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load more activity")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("force_refresh", _params, socket) do
    corporation_id = socket.assigns.corporation_id
    # Clear cache for this corporation
    AnalysisCache.invalidate_corporation(corporation_id)
    # Also clear any corporation intelligence cache
    CorporationIntelligence.clear_corporation_cache(corporation_id)
    # Redirect to reload the page with fresh data
    {:noreply, push_navigate(socket, to: ~p"/corporation/#{corporation_id}")}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "retry_historical_fetch",
        %{"entity_type" => "corporation", "entity_id" => id},
        socket
      ) do
    entity_id = String.to_integer(id)
    queue_historical_fetch(:corporation, entity_id)
    status = get_historical_fetch_status(:corporation, entity_id)
    {:noreply, assign(socket, :historical_fetch_status, status)}
  end

  # Private helper functions
  defp load_all_corporation_data(corporation_id) do
    # Load all data using the optimized data loader
    data = DataLoader.load_corporation_data(corporation_id)

    # Placeholder: location_stats and victim_stats need dedicated loader functions
    {:ok, location_stats} = DataLoader.load_corporation_info(corporation_id)
    {:ok, victim_stats} = DataLoader.load_corporation_info(corporation_id)

    # Load intelligence data
    # get_corporation_intelligence_report always returns {:ok, map()} per its spec
    {:ok, intelligence_data} =
      CorporationIntelligence.get_corporation_intelligence_report(corporation_id)

    # Load battle data
    battles = BattleDetector.detect_corporation_battles(corporation_id, 10)
    battle_stats = BattleDetector.get_corporation_battle_stats(corporation_id)
    fleet_doctrines = BattleDetector.get_corporation_fleet_doctrines(corporation_id)

    # Combine all data
    {:ok,
     Map.merge(data, %{
       location_stats: location_stats,
       victim_stats: victim_stats,
       intelligence: intelligence_data,
       battles: battles,
       battle_stats: battle_stats,
       fleet_doctrines: fleet_doctrines
     })}
  rescue
    error ->
      Logger.error("Error loading corporation data: #{inspect(error)}")
      {:error, error}
  end

  # Helper functions
  defp round_value(value, precision) when is_number(value) do
    if is_float(value) do
      Float.round(value, precision)
    else
      # Convert integer to float for rounding
      Float.round(value * 1.0, precision)
    end
  end

  defp round_value(_value, _precision), do: 0.0

  # Template helper functions (using FormatHelpers for numbers and ISK)
  def activity_indicator(activity_count) do
    cond do
      activity_count >= 50 -> {"🔥", "text-red-400"}
      activity_count >= 20 -> {"⚡", "text-yellow-400"}
      activity_count >= 5 -> {"✅", "text-green-400"}
      activity_count > 0 -> {"📍", "text-blue-400"}
      true -> {"💤", "text-gray-500"}
    end
  end

  def activity_level(activity_count) do
    cond do
      activity_count >= 50 -> "Very High"
      activity_count >= 20 -> "High"
      activity_count >= 5 -> "Active"
      activity_count > 0 -> "Low"
      true -> "Inactive"
    end
  end

  # Using TimeFormatter.format_friendly_time for time formatting
  def activity_type_badge(is_kill) do
    if is_kill do
      {"🎯 Kill", "bg-green-600 text-white"}
    else
      {"💀 Loss", "bg-red-600 text-white"}
    end
  end

  defp load_more_recent_activity(corporation_id, cursor) do
    activities =
      CursorPaginator.paginate_character_activity(
        corporation_id,
        after: cursor,
        page_size: 50
      )

    {:ok, activities.edges |> Enum.map(& &1.node)}
  rescue
    _ -> {:error, :pagination_failed}
  end

  defp calculate_participation_data(members, corp_info) do
    # Use the actual number of members we have data for
    members_with_data = length(members)
    # Get the actual ESI member count
    total_corp_members = Map.get(corp_info || %{}, :member_count, members_with_data)
    # Use total corp members for participation rates if we have ESI data
    # This gives a more accurate representation of corp activity
    participation_base =
      if total_corp_members > 0 && total_corp_members >= members_with_data do
        total_corp_members
      else
        members_with_data
      end

    # Calculate PvP participation (members with any activity vs total members)
    pvp_participants = Enum.count(members, &(&1.total_activity > 0))

    pvp_rate =
      if participation_base > 0, do: pvp_participants / participation_base * 100, else: 0.0

    # Calculate fleet participation (members with 3+ activities suggesting group play)
    fleet_participants = Enum.count(members, &(&1.total_activity >= 3))

    fleet_rate =
      if participation_base > 0, do: fleet_participants / participation_base * 100, else: 0.0

    # Calculate corporate activity (active members with 5+ activities)
    active_participants = Enum.count(members, &(&1.total_activity >= 5))

    active_rate =
      if participation_base > 0, do: active_participants / participation_base * 100, else: 0.0

    # Overall participation score (weighted average)
    overall_score = pvp_rate * 0.3 + fleet_rate * 0.4 + active_rate * 0.3

    %{
      pvp_participation: %{participants: pvp_participants, rate: Float.round(pvp_rate, 1)},
      fleet_participation: %{participants: fleet_participants, rate: Float.round(fleet_rate, 1)},
      corporate_activity: %{participants: active_participants, rate: Float.round(active_rate, 1)},
      overall_participation_score: Float.round(overall_score, 1),
      members_with_data: members_with_data,
      total_members: total_corp_members
    }
  end

  def format_doctrine_name(doctrine) do
    to_string(doctrine)
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def get_doctrine_description(doctrine) do
    case doctrine do
      :shield_kiting ->
        "Long-range shield tanked ships with high mobility and standoff capability"

      :armor_brawling ->
        "Close-range armor tanked ships focused on sustained DPS and tank"

      :ewar_heavy ->
        "Electronic warfare focused doctrine with force multiplication through disruption"

      :capital_escalation ->
        "Doctrine built around capital ship deployment and escalation scenarios"

      :alpha_strike ->
        "High alpha damage doctrine focused on quickly eliminating priority targets"

      :nano_gang ->
        "High speed, high mobility doctrine for hit-and-run tactics"

      :logistics_heavy ->
        "Doctrine emphasizing survivability through extensive logistics support"

      _ ->
        "Unknown doctrine pattern"
    end
  end

  def threat_level_color("Very High"), do: "text-red-500"
  def threat_level_color("High"), do: "text-orange-500"
  def threat_level_color("Moderate"), do: "text-yellow-500"
  def threat_level_color("Low"), do: "text-blue-500"
  def threat_level_color(_), do: "text-green-500"

  # Historical fetch helpers
  # These functions integrate with the KillmailProcessing context for 2-year historical data.
  # Uses the KillmailProcessing.Api for the actual implementation.

  defp get_historical_fetch_status(entity_type, entity_id) do
    case KillmailProcessing.Api.get_historical_fetch_status(entity_type, entity_id) do
      {:ok, status} -> status
      {:error, :not_found} -> nil
    end
  end

  defp subscribe_to_historical_fetch(entity_type, entity_id) do
    KillmailProcessing.Api.subscribe_to_historical_fetch(entity_type, entity_id)
  end

  defp queue_historical_fetch(entity_type, entity_id) do
    KillmailProcessing.Api.queue_extended_historical_fetch(entity_type, entity_id)
  end
end
