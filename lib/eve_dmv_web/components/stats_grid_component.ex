defmodule EveDmvWeb.Components.StatsGridComponent do
  @moduledoc """
  Reusable statistics grid component for displaying metrics.

  Provides consistent styling and layout for statistics cards.
  """

  use Phoenix.Component
  alias EveDmvWeb.Components.FormatHelpers

  @doc """
  Renders a grid of statistics cards.

  ## Examples

      <.stats_grid>
        <:stat label="Total Kills" value={@stats.total_kills} />
        <:stat label="ISK Destroyed" value={@stats.isk_destroyed} format="isk" />
        <:stat label="Efficiency" value={@stats.efficiency} format="percentage" color="green" />
      </.stats_grid>
  """
  attr(:class, :string, default: "")
  attr(:columns, :integer, default: 4, doc: "Number of columns in the grid")

  slot :stat, required: true do
    attr(:label, :string, required: true)
    attr(:value, :any)
    attr(:format, :string, doc: "number, isk, percentage, or none")
    attr(:color, :string, doc: "blue, green, red, yellow, purple")
    attr(:subtitle, :string, doc: "Optional subtitle text")
    attr(:icon, :string, doc: "Optional icon to display")
  end

  def stats_grid(assigns) do
    ~H"""
    <div class={"grid grid-cols-1 md:grid-cols-2 lg:grid-cols-#{@columns} gap-4 #{@class}"}>
      <div 
        :for={stat <- @stat} 
        class={"bg-gray-800 border border-gray-700 rounded-lg p-4 hover:bg-gray-750 transition-colors"}
      >
        <div class="flex items-center justify-between mb-1">
          <div class="text-sm text-gray-400 font-medium">
            <%= stat.label %>
          </div>
          <div :if={stat[:icon]} class="text-lg">
            <%= stat.icon %>
          </div>
        </div>
        <div class={"text-2xl font-bold #{stat_color_class(Map.get(stat, :color, "blue"))}"}>
          <%= if stat[:value] do %>
            <%= format_stat_value(stat.value, Map.get(stat, :format, "number")) %>
          <% else %>
            <%= stat[:inner_block] && render_slot(stat) %>
          <% end %>
        </div>
        <div :if={stat[:subtitle]} class="text-xs text-gray-500 mt-1">
          <%= stat.subtitle %>
        </div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp format_stat_value(value, format) do
    case format do
      "isk" -> FormatHelpers.format_isk(value)
      "percentage" -> "#{value}%"
      "number" -> FormatHelpers.format_number(value)
      "none" -> value
      _ -> to_string(value)
    end
  end

  defp stat_color_class(color) do
    case color do
      "blue" -> "text-blue-400"
      "green" -> "text-green-400"
      "red" -> "text-red-400"
      "yellow" -> "text-yellow-400"
      "purple" -> "text-purple-400"
      "white" -> "text-white"
      _ -> "text-blue-400"
    end
  end
end
