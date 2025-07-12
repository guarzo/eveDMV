defmodule EveDmvWeb.Components.IskStatsComponent do
  @moduledoc """
  Reusable ISK statistics component showing destroyed/lost values and efficiency.
  """
  use Phoenix.Component

  @doc """
  Renders ISK statistics card with destroyed/lost values and efficiency.

  ## Examples

      <.isk_stats 
        destroyed={2_500_000_000}
        lost={500_000_000}
        time_period="90 days"
      />
  """
  attr(:destroyed, :integer, required: true)
  attr(:lost, :integer, required: true)
  attr(:time_period, :string, default: nil)
  attr(:class, :string, default: "")

  def isk_stats(assigns) do
    # Calculate efficiency
    assigns = assign(assigns, :efficiency, calculate_efficiency(assigns.destroyed, assigns.lost))

    ~H"""
    <div class={"isk-stats-card bg-gray-800 rounded-lg border border-gray-700 #{@class}"}>
      <div class="p-4">
        <h3 class="text-sm font-medium text-gray-400 mb-3">ISK Statistics</h3>
        
        <div class="space-y-3">
          <!-- ISK Values -->
          <div class="flex justify-between items-center">
            <div>
              <p class="text-xs text-gray-500">Destroyed</p>
              <p class="text-lg font-bold text-green-400"><%= format_isk(@destroyed) %></p>
            </div>
            <div class="text-center px-2">
              <p class="text-gray-500">/</p>
            </div>
            <div class="text-right">
              <p class="text-xs text-gray-500">Lost</p>
              <p class="text-lg font-bold text-red-400"><%= format_isk(@lost) %></p>
            </div>
          </div>
          
          <!-- Efficiency Bar -->
          <div>
            <div class="flex justify-between items-center mb-1">
              <span class="text-xs text-gray-500">Efficiency</span>
              <span class={"text-sm font-bold #{efficiency_color(@efficiency)}"}>
                <%= @efficiency %>%
              </span>
            </div>
            <div class="w-full bg-gray-700 rounded-full h-2">
              <div 
                class={"h-2 rounded-full transition-all duration-300 #{efficiency_bg(@efficiency)}"}
                style={"width: #{@efficiency}%"}
              />
            </div>
          </div>
          
          <%= if @time_period do %>
            <p class="text-xs text-gray-500 text-center mt-2"><%= @time_period %></p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp calculate_efficiency(destroyed, lost) when destroyed + lost > 0 do
    round(destroyed / (destroyed + lost) * 100)
  end

  defp calculate_efficiency(_, _), do: 0

  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000_000 ->
        "#{Float.round(value / 1_000_000_000_000, 1)}T"

      value >= 1_000_000_000 ->
        "#{Float.round(value / 1_000_000_000, 1)}B"

      value >= 1_000_000 ->
        "#{Float.round(value / 1_000_000, 1)}M"

      value >= 1_000 ->
        "#{Float.round(value / 1_000, 1)}K"

      true ->
        "#{round(value)}"
    end
  end

  defp format_isk(_), do: "0"

  defp efficiency_color(eff) when eff >= 90, do: "text-green-400"
  defp efficiency_color(eff) when eff >= 75, do: "text-green-500"
  defp efficiency_color(eff) when eff >= 50, do: "text-yellow-500"
  defp efficiency_color(eff) when eff >= 25, do: "text-orange-500"
  defp efficiency_color(_), do: "text-red-500"

  defp efficiency_bg(eff) when eff >= 90, do: "bg-green-500"
  defp efficiency_bg(eff) when eff >= 75, do: "bg-green-600"
  defp efficiency_bg(eff) when eff >= 50, do: "bg-yellow-600"
  defp efficiency_bg(eff) when eff >= 25, do: "bg-orange-600"
  defp efficiency_bg(_), do: "bg-red-600"
end
