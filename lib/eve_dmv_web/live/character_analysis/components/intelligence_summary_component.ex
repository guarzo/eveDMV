defmodule EveDmvWeb.CharacterAnalysis.Components.IntelligenceSummaryComponent do
  @moduledoc """
  Intelligence summary component displaying peak activity, location patterns, and timezone information.
  """

  use EveDmvWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-white font-semibold mb-4 flex items-center">
        🧠 Intelligence Summary
      </h3>
      <div class="space-y-3">
        <%= if @analysis.intelligence_summary.peak_activity_hour do %>
          <div class="flex items-center space-x-2">
            <span class="text-yellow-400">🕐</span>
            <div>
              <div class="text-xs text-gray-400">Peak Activity</div>
              <div class="text-sm text-white font-medium">
                <%= String.pad_leading(Integer.to_string(@analysis.intelligence_summary.peak_activity_hour), 2, "0") %>:00 EVE
              </div>
            </div>
          </div>
        <% end %>
        
        <%= if @analysis.intelligence_summary.top_location do %>
          <div class="flex items-center space-x-2">
            <span class="text-blue-400">🌍</span>
            <div>
              <div class="text-xs text-gray-400">Top Location</div>
              <div class="text-sm text-white font-medium">
                <%= @analysis.intelligence_summary.top_location %>
              </div>
            </div>
          </div>
        <% end %>
        
        <%= if @analysis.intelligence_summary.primary_timezone do %>
          <div class="flex items-center space-x-2">
            <span class="text-green-400">⏰</span>
            <div>
              <div class="text-xs text-gray-400">Primary TZ</div>
              <div class="text-sm text-white font-medium">
                <%= @analysis.intelligence_summary.primary_timezone %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
