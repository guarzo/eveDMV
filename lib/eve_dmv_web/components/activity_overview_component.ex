defmodule EveDmvWeb.Components.ActivityOverviewComponent do
  @moduledoc """
  Reusable activity overview component for characters and corporations.
  """
  use Phoenix.Component

  @doc """
  Renders an activity overview card with peak time, location, and timezone.

  ## Examples

      <.activity_overview 
        peak_time="18:00 EVE"
        peak_activity_count={42}
        top_location="Jita"
        location_activity_count={156}
        primary_timezone="EUTZ"
        timezone_coverage={85}
      />
  """
  attr(:peak_time, :string, default: nil)
  attr(:peak_activity_count, :integer, default: nil)
  attr(:top_location, :string, default: nil)
  attr(:location_activity_count, :integer, default: nil)
  attr(:primary_timezone, :string, default: nil)
  attr(:timezone_coverage, :float, default: nil)
  attr(:class, :string, default: "")

  def activity_overview(assigns) do
    ~H"""
    <div class={"activity-overview-card bg-gray-800 rounded-lg border border-gray-700 #{@class}"}>
      <div class="p-4">
        <h3 class="text-sm font-medium text-gray-400 mb-3">Activity Overview</h3>
        <div class="grid grid-cols-3 gap-4 text-center">
          <!-- Peak Activity -->
          <div>
            <div class="text-2xl mb-1">🕐</div>
            <h4 class="text-xs text-gray-500 mb-1">Peak Time</h4>
            <%= if @peak_time do %>
              <p class="text-sm font-bold text-yellow-400"><%= @peak_time %></p>
              <%= if @peak_activity_count do %>
                <p class="text-xs text-gray-500 mt-1"><%= @peak_activity_count %> kills/hr</p>
              <% end %>
            <% else %>
              <p class="text-sm font-bold text-gray-500">Unknown</p>
            <% end %>
          </div>
          
          <!-- Top Location -->
          <div>
            <div class="text-2xl mb-1">🌍</div>
            <h4 class="text-xs text-gray-500 mb-1">Top System</h4>
            <%= if @top_location do %>
              <p class="text-sm font-bold text-blue-400 truncate" title={@top_location}>
                <%= @top_location %>
              </p>
              <%= if @location_activity_count do %>
                <p class="text-xs text-gray-500 mt-1"><%= @location_activity_count %> kills</p>
              <% end %>
            <% else %>
              <p class="text-sm font-bold text-gray-500">Unknown</p>
            <% end %>
          </div>
          
          <!-- Primary Timezone -->
          <div>
            <div class="text-2xl mb-1">⏰</div>
            <h4 class="text-xs text-gray-500 mb-1">Timezone</h4>
            <%= if @primary_timezone do %>
              <p class="text-sm font-bold text-green-400"><%= @primary_timezone %></p>
              <%= if @timezone_coverage do %>
                <p class="text-xs text-gray-500 mt-1"><%= round(@timezone_coverage) %>% coverage</p>
              <% end %>
            <% else %>
              <p class="text-sm font-bold text-gray-500">Unknown</p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
