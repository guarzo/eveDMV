defmodule EveDmvWeb.Components.ThreatLevelComponent do
  @moduledoc """
  Reusable threat level display component for characters and corporations.
  """
  use Phoenix.Component

  @doc """
  Renders a threat level card with score and description.

  ## Examples

      <.threat_level 
        score={85} 
        level="High" 
        summary="Experienced PvP pilot"
        type="character"
      />
  """
  attr(:score, :integer, required: true)
  attr(:level, :string, required: true)
  attr(:summary, :string, default: nil)
  attr(:type, :string, default: "character")
  attr(:class, :string, default: "")

  def threat_level(assigns) do
    ~H"""
    <div class={"threat-level-card #{@class}"}>
      <div class={"p-4 rounded-lg border #{threat_level_bg(@score)}"}>
        <div class="flex items-center gap-3">
          <div class="text-center">
            <span class={"text-3xl font-bold #{threat_level_color(@score)}"}>
              <%= @score %>
            </span>
            <div class="text-xs text-gray-400">/ 100</div>
          </div>
          <div class="flex-1">
            <p class={"font-medium text-lg #{threat_level_color(@score)}"}>
              <%= @level %> Threat
            </p>
            <%= if @summary do %>
              <p class="text-sm text-gray-400 mt-1"><%= @summary %></p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for threat level styling
  defp threat_level_color(score) when score >= 90, do: "text-red-500"
  defp threat_level_color(score) when score >= 75, do: "text-orange-500"
  defp threat_level_color(score) when score >= 50, do: "text-yellow-500"
  defp threat_level_color(score) when score >= 25, do: "text-blue-500"
  defp threat_level_color(_), do: "text-green-500"

  defp threat_level_bg(score) when score >= 90, do: "border-red-900 bg-red-950/30"
  defp threat_level_bg(score) when score >= 75, do: "border-orange-900 bg-orange-950/30"
  defp threat_level_bg(score) when score >= 50, do: "border-yellow-900 bg-yellow-950/30"
  defp threat_level_bg(score) when score >= 25, do: "border-blue-900 bg-blue-950/30"
  defp threat_level_bg(_), do: "border-green-900 bg-green-950/30"
end
