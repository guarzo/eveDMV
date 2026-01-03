defmodule EveDmvWeb.CharacterAnalysis.Components.IntelligenceSummaryComponent do
  @moduledoc """
  Intelligence summary component displaying peak activity, location patterns, and timezone information.
  """

  use EveDmvWeb, :live_component

  def render(assigns) do
    # Safely extract values with defaults
    summary = assigns.analysis.intelligence_summary || %{}
    peak_hour = Map.get(summary, :peak_activity_hour)
    top_location = Map.get(summary, :top_location)
    primary_tz = Map.get(summary, :primary_timezone)

    assigns =
      assigns
      |> assign(:peak_hour, peak_hour)
      |> assign(:top_location, top_location)
      |> assign(:primary_tz, primary_tz)

    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-white font-semibold mb-4 flex items-center">
        🧠 Intelligence Summary
      </h3>
      <div class="space-y-3">
        <%= if @peak_hour do %>
          <div class="flex items-center space-x-2">
            <span class="text-yellow-400">🕐</span>
            <div>
              <div class="text-xs text-gray-400">Peak Activity</div>
              <div class="text-sm text-white font-medium">
                <%= format_hour(@peak_hour) %>:00 EVE
              </div>
            </div>
          </div>
        <% end %>

        <%= if @top_location && @top_location != %{} do %>
          <div class="flex items-center space-x-2">
            <span class="text-blue-400">🌍</span>
            <div>
              <div class="text-xs text-gray-400">Top Location</div>
              <div class="text-sm text-white font-medium">
                <%= format_location(@top_location) %>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @primary_tz do %>
          <div class="flex items-center space-x-2">
            <span class="text-green-400">⏰</span>
            <div>
              <div class="text-xs text-gray-400">Primary TZ</div>
              <div class="text-sm text-white font-medium">
                <%= @primary_tz %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_location(location) when is_map(location) do
    Map.get(location, :name) || Map.get(location, "name") || "Unknown"
  end

  defp format_location(location) when is_binary(location), do: location
  defp format_location(_), do: "Unknown"

  # Convert hour to two-digit string, handling floats from PostgreSQL EXTRACT
  defp format_hour(hour) when is_float(hour), do: format_hour(trunc(hour))
  defp format_hour(hour) when is_integer(hour), do: String.pad_leading(Integer.to_string(hour), 2, "0")
  defp format_hour(%Decimal{} = hour), do: format_hour(Decimal.to_integer(hour))
  defp format_hour(_), do: "??"
end
