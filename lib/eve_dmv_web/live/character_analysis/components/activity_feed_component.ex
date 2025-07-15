defmodule EveDmvWeb.CharacterAnalysis.Components.ActivityFeedComponent do
  @moduledoc """
  Activity feed component displaying recent activity, ship preferences, and weapons.
  """

  use EveDmvWeb, :live_component
  import EveDmvWeb.EveImageComponents

  def render(assigns) do
    ~H"""
    <div>
      <!-- Recent Activity -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          ⚡ Recent Activity
        </h3>
        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">Last 30 days:</span>
            <span class="text-blue-400"><%= @analysis.recent_kills %> kills</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Most Active Day:</span>
            <span class="text-gray-300"><%= @analysis.most_active_day || "N/A" %></span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Days Active:</span>
            <span class="text-gray-300"><%= @analysis.active_days %></span>
          </div>
        </div>
      </div>
      
      <!-- Ships & Weapons -->
      <div class="bg-gray-800 rounded-lg p-6 mt-6">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          🚀 Ships & Weapons
        </h3>
        <div class="space-y-3">
          <%= for {ship_name, stats} <- @analysis.top_ships do %>
            <% weapon = Enum.find(@analysis.weapon_preferences, fn w -> w.ship_name == ship_name end) %>
            <div class="bg-gray-700 rounded p-3">
              <div class="flex items-center gap-3">
                <.ship_image 
                  type_id={String.to_integer(stats.ship_type_id || "0")}
                  name={ship_name}
                  size={48}
                />
                <div class="flex-1">
                  <div class="text-gray-200 font-medium"><%= ship_name %></div>
                  <%= if weapon do %>
                    <div class="text-xs text-gray-400"><%= weapon.weapon_name %></div>
                  <% end %>
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
    </div>
    """
  end
end
