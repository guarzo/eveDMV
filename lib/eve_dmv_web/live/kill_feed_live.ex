# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout
defmodule EveDmvWeb.KillFeedLive do

  @moduledoc """

  import EveDmvWeb.Components.StatsGridComponent
  import EveDmvWeb.Components.EmptyStateComponent
  import EveDmvWeb.Components.PageHeaderComponent
  import EveDmvWeb.EveImageComponents
  alias EveDmv.Killmails.DisplayService
  alias EveDmv.Presentation.Formatters
  @moduledoc """
  Public live kill feed displaying real-time killmail data.
  """

  use EveDmvWeb, :live_view

  # Import reusable components
  @topic "kill_feed"
  @feed_limit 50
  # Load current user from session on mount (optional for public pages)
  on_mount({EveDmvWeb.AuthLive, :load_from_session_optional})

  def mount(_params, _session, socket) do
    # Subscribe to kill feed updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, @topic)
    end

    # Load initial page of killmails
    page_data = DisplayService.load_killmails_page(@feed_limit, %{}, 0)
    system_stats = DisplayService.calculate_system_stats(page_data.killmails)

    socket =
      socket
      |> assign(:killmails, page_data.killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(page_data.killmails))
      |> assign(:total_isk_destroyed, DisplayService.calculate_total_isk(page_data.killmails))
      |> assign(:filters, %{})
      |> assign(:show_filters, false)
      |> assign(:available_alliances, [])
      |> assign(:available_ship_types, [])
      |> assign(:has_more, page_data.has_more)
      |> assign(:loading_more, false)
      |> assign(:offset, page_data.next_offset)
      |> stream(:killmail_stream, page_data.killmails)

    {:ok, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "kill_feed", event: "new_kill", payload: killmail_data},
        socket
      ) do
    # Add new killmail to the stream
    new_killmail = DisplayService.build_killmail_display(killmail_data)
    # Update stats
    current_killmails = [new_killmail | socket.assigns.killmails]
    limited_killmails = Enum.take(current_killmails, @feed_limit)
    system_stats = DisplayService.calculate_system_stats(limited_killmails)

    socket =
      socket
      |> assign(:killmails, limited_killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, socket.assigns.total_kills_today + 1)
      |> assign(
        :total_isk_destroyed,
        Decimal.add(socket.assigns.total_isk_destroyed, new_killmail.total_value)
      )
      |> stream_insert(:killmail_stream, new_killmail, at: 0)

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def handle_event("refresh_feed", _params, socket) do
    # Refresh with current filters, reset to first page
    page_data = DisplayService.load_killmails_page(@feed_limit, socket.assigns.filters, 0)
    system_stats = DisplayService.calculate_system_stats(page_data.killmails)

    socket =
      socket
      |> assign(:killmails, page_data.killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(page_data.killmails))
      |> assign(:total_isk_destroyed, DisplayService.calculate_total_isk(page_data.killmails))
      |> assign(:has_more, page_data.has_more)
      |> assign(:offset, page_data.next_offset)
      |> stream(:killmail_stream, page_data.killmails, reset: true)

    {:noreply, socket}
  end

  def handle_event("filter_by_system", %{"system_id" => system_id}, socket) do
    case Integer.parse(system_id) do
      {system_id_int, ""} ->
        filters = Map.put(socket.assigns.filters, :system_id, system_id_int)
        apply_filters(socket, filters)

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid system ID")}
    end
  end

  def handle_event("toggle_filters", _params, socket) do
    show_filters = !socket.assigns.show_filters

    socket =
      if show_filters && socket.assigns.available_alliances == [] do
        # Load filter options when first showing filters
        socket
        |> assign(:available_alliances, DisplayService.get_recent_alliances())
        |> assign(:available_ship_types, DisplayService.get_recent_ship_types())
      else
        socket
      end

    {:noreply, assign(socket, :show_filters, show_filters)}
  end

  def handle_event("apply_filters", params, socket) do
    filters = build_filters_from_params(params)
    apply_filters(socket, filters)
  end

  def handle_event("clear_filters", _params, socket) do
    apply_filters(socket, %{})
  end

  def handle_event("filter_by_alliance", %{"alliance" => alliance}, socket) do
    filters = Map.put(socket.assigns.filters, :alliance_name, alliance)
    apply_filters(socket, filters)
  end

  def handle_event("filter_by_ship", %{"ship" => ship}, socket) do
    filters = Map.put(socket.assigns.filters, :ship_class, ship)
    apply_filters(socket, filters)
  end

  def handle_event("load_more", _params, socket) do
    if socket.assigns.has_more and not socket.assigns.loading_more do
      socket = assign(socket, :loading_more, true)

      # Load next page
      page_data =
        DisplayService.load_killmails_page(
          @feed_limit,
          socket.assigns.filters,
          socket.assigns.offset
        )

      # Append to existing killmails
      all_killmails = socket.assigns.killmails ++ page_data.killmails

      socket =
        socket
        |> assign(:killmails, all_killmails)
        |> assign(:has_more, page_data.has_more)
        |> assign(:loading_more, false)
        |> assign(:offset, page_data.next_offset)
        |> stream(:killmail_stream, page_data.killmails)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Private helpers
  defp apply_filters(socket, filters) do
    # Reset pagination when applying filters
    page_data = DisplayService.load_killmails_page(@feed_limit, filters, 0)
    system_stats = DisplayService.calculate_system_stats(page_data.killmails)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:killmails, page_data.killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(page_data.killmails))
      |> assign(:total_isk_destroyed, DisplayService.calculate_total_isk(page_data.killmails))
      |> assign(:has_more, page_data.has_more)
      |> assign(:offset, page_data.next_offset)
      |> stream(:killmail_stream, page_data.killmails, reset: true)

    {:noreply, socket}
  end

  defp build_filters_from_params(params) do
    %{}
    |> maybe_add_filter(:alliance_name, params["alliance_name"])
    |> maybe_add_filter(:corporation_name, params["corporation_name"])
    |> maybe_add_filter(:character_name, params["character_name"])
    |> maybe_add_filter(:ship_class, params["ship_class"])
    |> maybe_add_value_filter(:min_value, params["min_value"])
    |> maybe_add_value_filter(:max_value, params["max_value"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp maybe_add_value_filter(filters, _key, nil), do: filters
  defp maybe_add_value_filter(filters, _key, ""), do: filters

  defp maybe_add_value_filter(filters, key, value) do
    case Decimal.parse(value) do
      {decimal, ""} -> Map.put(filters, key, decimal)
      _ -> filters
    end
  end

  # Delegate formatting to the Formatters module
  defdelegate format_isk(value), to: Formatters
  defdelegate format_time_ago(minutes), to: Formatters

  # Helper functions for filter display
  def humanize_filter_key(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def truncate_filter_value(value) when is_binary(value) do
    if String.length(value) > 20 do
      String.slice(value, 0, 20) <> "..."
    else
      value
    end
  end

  def truncate_filter_value(value), do: to_string(value)
end
