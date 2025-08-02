defmodule EveDmvWeb.CharacterAnalysis.Components.StatisticsPanelComponent do
  @moduledoc """
  Statistics panel component displaying combat statistics and ISK efficiency.
  """

  use EveDmvWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6">
      <h3 class="text-white font-semibold mb-4 flex items-center">
        📊 Combat Statistics (90 days)
      </h3>
      <div class="space-y-3">
        <div class="flex justify-between">
          <span class="text-gray-400">Total Kills:</span>
          <span class="text-green-400 font-semibold"><%= @analysis.total_kills %></span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-400">Total Deaths:</span>
          <span class="text-red-400 font-semibold"><%= @analysis.total_deaths %></span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-400">Kill/Death Ratio:</span>
          <span class="text-blue-400 font-semibold"><%= @analysis.kd_ratio %></span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-400">ISK Efficiency:</span>
          <span class="text-yellow-400 font-semibold"><%= @analysis.isk_efficiency %>%</span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-gray-500">ISK Destroyed:</span>
          <span class="text-green-300"><%= format_isk(@analysis.isk_destroyed) %></span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-gray-500">ISK Lost:</span>
          <span class="text-red-300"><%= format_isk(@analysis.isk_lost) %></span>
        </div>
      </div>
    </div>
    """
  end

  defp format_isk(isk) when is_number(isk) do
    cond do
      isk >= 1_000_000_000_000 -> "#{Float.round(isk / 1_000_000_000_000, 1)}T ISK"
      isk >= 1_000_000_000 -> "#{Float.round(isk / 1_000_000_000, 1)}B ISK"
      isk >= 1_000_000 -> "#{Float.round(isk / 1_000_000, 1)}M ISK"
      isk >= 1_000 -> "#{Float.round(isk / 1_000, 1)}K ISK"
      true -> "#{isk} ISK"
    end
  end

  defp format_isk(_), do: "0 ISK"
end
