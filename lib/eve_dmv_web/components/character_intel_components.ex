defmodule EveDmvWeb.CharacterIntelComponents do
  @moduledoc """
  Reusable UI components for Character Intelligence pages.
  Provides loading states, error handling, and data visualization components.
  """
  use Phoenix.Component

  @doc """
  Renders a skeleton loading state for character intel data.
  """
  attr(:class, :string, default: "")

  def intel_skeleton(assigns) do
    ~H"""
    <div class={["animate-pulse", @class]}>
      <!-- Header skeleton -->
      <div class="mb-8">
        <div class="h-8 w-64 bg-gray-700 rounded mb-2"></div>
        <div class="h-4 w-48 bg-gray-700 rounded"></div>
      </div>
      
      <!-- Stats grid skeleton -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div :for={_ <- 1..4} class="bg-gray-800 rounded-lg p-6">
          <div class="h-4 w-24 bg-gray-700 rounded mb-2"></div>
          <div class="h-8 w-32 bg-gray-700 rounded"></div>
        </div>
      </div>
      
      <!-- Tab skeleton -->
      <div class="border-b border-gray-700 mb-6">
        <div class="flex space-x-8">
          <div :for={_ <- 1..5} class="h-4 w-20 bg-gray-700 rounded mb-3"></div>
        </div>
      </div>
      
      <!-- Content skeleton -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div :for={_ <- 1..2} class="bg-gray-800 rounded-lg p-6">
          <div class="h-6 w-32 bg-gray-700 rounded mb-4"></div>
          <div class="space-y-3">
            <div :for={_ <- 1..4} class="h-4 w-full bg-gray-700 rounded"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a progress bar with label and percentage.
  """
  attr(:label, :string, required: true)
  attr(:value, :integer, required: true)
  attr(:max, :integer, default: 100)
  attr(:color, :string, default: "bg-blue-500")
  attr(:class, :string, default: "")

  def progress_bar(assigns) do
    percentage = min(100, round(assigns.value / assigns.max * 100))
    assigns = assign(assigns, :percentage, percentage)

    ~H"""
    <div class={@class}>
      <div class="flex justify-between items-center mb-1">
        <span class="text-sm text-gray-400">{@label}</span>
        <span class="text-sm font-medium">{@percentage}%</span>
      </div>
      <div class="w-full bg-gray-700 rounded-full h-2">
        <div 
          class={"#{@color} h-2 rounded-full transition-all duration-300 ease-out"}
          style={"width: #{@percentage}%"}
        ></div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a stat card with icon, label, and value.
  Enhanced version with better visual hierarchy and animations.
  """
  attr(:icon, :string, required: true)
  attr(:label, :string, required: true)
  attr(:value, :any, default: nil)
  attr(:trend, :string, default: nil)
  attr(:trend_value, :string, default: nil)
  attr(:color, :string, default: "text-white")
  attr(:format, :string, default: "text")
  slot(:inner_block)

  def stat_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg p-6 hover:bg-gray-700/50 transition-colors duration-200">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center gap-2 mb-2">
            <span class="text-2xl">{@icon}</span>
            <p class="text-sm font-medium text-gray-400">{@label}</p>
          </div>
          <div class={[@color, "mt-1"]}>
            <%= if @inner_block do %>
              <%= render_slot(@inner_block) %>
            <% else %>
              <p class="text-2xl font-bold">
                <%= format_stat_value(@value, @format) %>
              </p>
            <% end %>
          </div>
        </div>
        <%= if @trend do %>
          <div class="flex flex-col items-end">
            <span class={trend_color(@trend)}>
              <%= trend_icon(@trend) %>
            </span>
            <%= if @trend_value do %>
              <span class="text-xs text-gray-400 mt-1">{@trend_value}</span>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a visual danger rating component.
  """
  attr(:rating, :integer, required: true)
  attr(:max, :integer, default: 5)
  attr(:size, :string, default: "text-2xl")

  def danger_rating(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <span :for={i <- 1..@max} class={[@size, danger_star_color(i, @rating)]}>
        <%= if i <= @rating, do: "★", else: "☆" %>
      </span>
    </div>
    """
  end

  @doc """
  Renders an activity heatmap for timezone analysis.
  """
  attr(:data, :map, required: true)
  attr(:class, :string, default: "")

  def activity_heatmap(assigns) do
    ~H"""
    <div class={["bg-gray-800 rounded-lg p-6", @class]}>
      <h3 class="text-lg font-semibold mb-4">Activity Heatmap (EVE Time)</h3>
      <div class="grid grid-cols-24 gap-0.5">
        <div :for={hour <- 0..23} class="text-center">
          <div 
            class={"h-8 rounded-sm transition-colors duration-200 " <> activity_color(Map.get(@data, hour, 0))}
            title={"#{hour}:00 - #{Map.get(@data, hour, 0)} kills"}
          >
            <span class="text-xs text-gray-400">{hour}</span>
          </div>
        </div>
      </div>
      <div class="mt-2 flex items-center justify-center gap-4 text-xs text-gray-400">
        <span class="flex items-center gap-1">
          <div class="w-3 h-3 bg-gray-700 rounded-sm"></div> Inactive
        </span>
        <span class="flex items-center gap-1">
          <div class="w-3 h-3 bg-blue-700 rounded-sm"></div> Low
        </span>
        <span class="flex items-center gap-1">
          <div class="w-3 h-3 bg-blue-500 rounded-sm"></div> Medium
        </span>
        <span class="flex items-center gap-1">
          <div class="w-3 h-3 bg-orange-500 rounded-sm"></div> High
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a ship usage chart.
  """
  attr(:ships, :list, required: true)
  attr(:class, :string, default: "")

  def ship_usage_chart(assigns) do
    max_count =
      Enum.max_by(assigns.ships, & &1.usage_count, fn -> %{usage_count: 1} end).usage_count

    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <div class={["bg-gray-800 rounded-lg p-6", @class]}>
      <h3 class="text-lg font-semibold mb-4">Top Ships Used</h3>
      <div class="space-y-3">
        <div :for={ship <- Enum.take(@ships, 5)} class="group">
          <div class="flex justify-between items-center mb-1">
            <span class="text-sm font-medium group-hover:text-blue-400 transition-colors">
              {ship.ship_name || "Unknown Ship"}
            </span>
            <span class="text-sm text-gray-400">{ship.usage_count} kills</span>
          </div>
          <div class="w-full bg-gray-700 rounded-full h-2">
            <div 
              class="bg-gradient-to-r from-blue-500 to-blue-400 h-2 rounded-full transition-all duration-500"
              style={"width: #{round(ship.usage_count / @max_count * 100)}%"}
            ></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp format_stat_value(value, "number") when is_number(value) do
    value
    |> round()
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end

  defp format_stat_value(value, "isk") when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{round(value)}"
    end
  end

  defp format_stat_value(value, _), do: to_string(value)

  defp trend_color("up"), do: "text-green-400"
  defp trend_color("down"), do: "text-red-400"
  defp trend_color(_), do: "text-gray-400"

  defp trend_icon("up"), do: "↑"
  defp trend_icon("down"), do: "↓"
  defp trend_icon(_), do: "→"

  defp danger_star_color(position, rating) when position <= rating do
    cond do
      rating >= 5 -> "text-red-500"
      rating >= 4 -> "text-orange-500"
      rating >= 3 -> "text-yellow-500"
      rating >= 2 -> "text-blue-500"
      true -> "text-gray-500"
    end
  end

  defp danger_star_color(_, _), do: "text-gray-600"

  defp activity_color(count) do
    cond do
      count == 0 -> "bg-gray-700"
      count < 5 -> "bg-blue-700"
      count < 10 -> "bg-blue-500"
      true -> "bg-orange-500"
    end
  end
end
