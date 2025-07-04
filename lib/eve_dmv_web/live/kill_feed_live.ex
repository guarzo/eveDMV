defmodule EveDmvWeb.KillFeedLive do
  @moduledoc """
  Public live kill feed displaying real-time killmail data.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Killmails.DisplayService
  alias EveDmv.Presentation.Formatters

  @topic "kill_feed"
  @feed_limit 50

  def mount(_params, _session, socket) do
    # Subscribe to kill feed updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, @topic)
    end

    # Load initial killmails
    killmails = DisplayService.load_recent_killmails()
    system_stats = DisplayService.calculate_system_stats(killmails)

    socket =
      socket
      |> assign(:killmails, killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(killmails))
      |> assign(:total_isk_destroyed, DisplayService.calculate_total_isk(killmails))
      |> stream(:killmail_stream, killmails)

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
    killmails = DisplayService.load_recent_killmails()
    system_stats = DisplayService.calculate_system_stats(killmails)

    socket =
      socket
      |> assign(:killmails, killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(killmails))
      |> assign(:total_isk_destroyed, DisplayService.calculate_total_isk(killmails))
      |> stream(:killmail_stream, killmails, reset: true)

    {:noreply, socket}
  end

  def handle_event("filter_by_system", %{"system_id" => system_id}, socket) do
    case Integer.parse(system_id) do
      {system_id_int, ""} ->
        filtered_killmails =
          Enum.filter(socket.assigns.killmails, &(&1.solar_system_id == system_id_int))

        socket =
          socket
          |> stream(:killmail_stream, filtered_killmails, reset: true)

        {:noreply, socket}

      _ ->
        # Invalid system ID format, show all killmails
        socket =
          socket
          |> stream(:killmail_stream, socket.assigns.killmails, reset: true)
          |> put_flash(:error, "Invalid system ID")

        {:noreply, socket}
    end
  end

  # Delegate formatting to the Formatters module
  defdelegate format_isk(value), to: Formatters
  defdelegate format_time_ago(minutes), to: Formatters
end
