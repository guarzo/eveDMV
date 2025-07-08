defmodule EveDmvWeb.PriceMonitorComponent do
  @moduledoc """
  LiveView component for monitoring real-time price updates.

  This component subscribes to price update events and displays
  them in real-time to users monitoring killmail values.
  """

  alias EveDmv.Enrichment.RealTimePriceUpdater
  use EveDmvWeb, :live_component

  @impl Phoenix.LiveView
  def mount(socket) do
    # Subscribe to all price updates
    if connected?(socket) do
      RealTimePriceUpdater.subscribe_to_all_updates()
    end

    socket =
      socket
      |> assign(:price_updates, [])
      |> assign(:max_updates, 20)
      |> assign(:monitoring_enabled, true)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_monitoring", _params, socket) do
    new_state = not socket.assigns.monitoring_enabled

    socket =
      socket
      |> assign(:monitoring_enabled, new_state)
      |> put_flash(
        :info,
        if(new_state, do: "Price monitoring enabled", else: "Price monitoring paused")
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_updates", _params, socket) do
    socket =
      socket
      |> assign(:price_updates, [])
      |> put_flash(:info, "Price update history cleared")

    {:noreply, socket}
  end

  # Handle incoming price updates
  def handle_info({:price_updated, update}, socket) do
    if socket.assigns.monitoring_enabled do
      new_updates =
        [update | socket.assigns.price_updates]
        |> Enum.take(socket.assigns.max_updates)

      socket = assign(socket, :price_updates, new_updates)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Ignore other messages
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg border border-gray-700 p-4">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-bold text-white flex items-center">
          <span class="mr-2">💰</span>
          Real-time Price Updates
          <%= if @monitoring_enabled do %>
            <span class="ml-2 text-xs px-2 py-1 bg-green-600 text-white rounded">LIVE</span>
          <% else %>
            <span class="ml-2 text-xs px-2 py-1 bg-gray-600 text-white rounded">PAUSED</span>
          <% end %>
        </h3>

        <div class="flex space-x-2">
          <button
            phx-click="toggle_monitoring"
            phx-target={@myself}
            class={"px-3 py-1 text-sm rounded transition-colors #{
              if @monitoring_enabled do
                "bg-red-600 hover:bg-red-700 text-white"
              else
                "bg-green-600 hover:bg-green-700 text-white"
              end
            }"}
          >
            {if @monitoring_enabled, do: "Pause", else: "Resume"}
          </button>

          <button
            phx-click="clear_updates"
            phx-target={@myself}
            class="px-3 py-1 text-sm bg-gray-600 hover:bg-gray-700 text-white rounded transition-colors"
          >
            Clear
          </button>
        </div>
      </div>

      <div class="space-y-2 max-h-64 overflow-y-auto">
        <%= if @price_updates == [] do %>
          <div class="text-center py-8 text-gray-400">
            <div class="text-2xl mb-2">📊</div>
            <p class="text-sm">No price updates yet</p>
            <p class="text-xs">Updates will appear here when killmail values change</p>
          </div>
        <% else %>
          <%= for update <- @price_updates do %>
            <div class="bg-gray-700 rounded p-3 hover:bg-gray-600 transition-colors">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-3">
                  <div class={price_change_indicator_class(update.change_percentage)}>
                    {price_change_indicator(update.change_percentage)}
                  </div>

                  <div>
                    <div class="text-sm font-medium text-white">
                      Killmail #{update.killmail_id}
                    </div>
                    <div class="text-xs text-gray-400">
                      {format_isk_value(update.old_value)} → {format_isk_value(update.new_value)}
                      <span class={change_percentage_class(update.change_percentage)}>
                        ({format_percentage(update.change_percentage)})
                      </span>
                    </div>
                  </div>
                </div>

                <div class="text-right">
                  <div class="text-xs text-gray-400">
                    {format_time_ago(update.updated_at)}
                  </div>
                  <div class="text-xs text-gray-500">
                    via {update.price_source}
                  </div>
                </div>
              </div>

              <div class="mt-2 flex space-x-4 text-xs text-gray-400">
                <div>Ship: {format_isk_value(update.ship_value)}</div>
                <div>Fittings: {format_isk_value(update.fitted_value)}</div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <%= if @price_updates != [] do %>
        <div class="mt-3 pt-3 border-t border-gray-700">
          <div class="text-xs text-gray-400 text-center">
            Showing {length(@price_updates)} most recent updates
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp format_isk_value(nil), do: "0 ISK"

  defp format_isk_value(%Decimal{} = value) do
    float_value = Decimal.to_float(value)
    format_isk_value(float_value)
  end

  defp format_isk_value(value) when is_float(value) do
    cond do
      value >= 1_000_000_000 ->
        "#{Float.round(value / 1_000_000_000, 2)}B ISK"

      value >= 1_000_000 ->
        "#{Float.round(value / 1_000_000, 2)}M ISK"

      value >= 1_000 ->
        "#{Float.round(value / 1_000, 2)}K ISK"

      true ->
        "#{Float.round(value, 2)} ISK"
    end
  end

  defp format_percentage(nil), do: "0%"

  defp format_percentage(percentage) when is_float(percentage) do
    "#{if percentage > 0, do: "+"}#{Float.round(percentage, 2)}%"
  end

  defp price_change_indicator(percentage) when is_float(percentage) do
    cond do
      percentage > 0 -> "📈"
      percentage < 0 -> "📉"
      true -> "➡️"
    end
  end

  defp price_change_indicator(_), do: "➡️"

  defp price_change_indicator_class(percentage) when is_float(percentage) do
    cond do
      percentage > 0 -> "text-2xl text-green-400"
      percentage < 0 -> "text-2xl text-red-400"
      true -> "text-2xl text-gray-400"
    end
  end

  defp price_change_indicator_class(_), do: "text-2xl text-gray-400"

  defp change_percentage_class(percentage) when is_float(percentage) do
    cond do
      percentage > 0 -> "text-green-400"
      percentage < 0 -> "text-red-400"
      true -> "text-gray-400"
    end
  end

  defp change_percentage_class(_), do: "text-gray-400"

  defp format_time_ago(datetime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      seconds_ago < 60 ->
        "#{seconds_ago}s ago"

      seconds_ago < 3600 ->
        "#{div(seconds_ago, 60)}m ago"

      seconds_ago < 86_400 ->
        "#{div(seconds_ago, 3600)}h ago"

      true ->
        "#{div(seconds_ago, 86_400)}d ago"
    end
  end
end
