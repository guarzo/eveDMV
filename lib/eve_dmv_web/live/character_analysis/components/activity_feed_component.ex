defmodule EveDmvWeb.CharacterAnalysis.Components.ActivityFeedComponent do
  @moduledoc """
  Activity feed component displaying recent activity, ship preferences, and weapons.
  """

  use EveDmvWeb, :live_component
  import EveDmvWeb.EveImageComponents

  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-white font-semibold mb-4 flex items-center">
        🚀 Top Ships
      </h3>
      <div class="space-y-3">
        <%= for {ship_name, stats} <- @analysis.top_ships do %>
          <div class="bg-gray-700 rounded p-3">
            <div class="flex items-center gap-3">
              <.ship_image
                type_id={to_integer(stats.ship_type_id)}
                name={ship_name}
                size={48}
              />
              <div class="flex-1">
                <div class="text-gray-200 font-medium"><%= ship_name %></div>
                <div class="flex gap-4 text-xs mt-1">
                  <span class="text-green-400"><%= stats.kills %> kills</span>
                  <span class="text-red-400"><%= stats.deaths %> deaths</span>
                  <%= if stats.kills > 0 and stats.deaths > 0 do %>
                    <span class="text-blue-400">K/D: <%= Float.round(stats.kills / stats.deaths, 1) %></span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        <%= if Enum.empty?(@analysis.top_ships) do %>
          <p class="text-gray-500 italic">No ship data available</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp to_integer(nil), do: 0
  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
end
