defmodule EveDmvWeb.Components.DataTableComponent do
  use Phoenix.Component
  @moduledoc """
  Reusable data table component with consistent dark theme styling.

  Provides sortable columns, responsive design, and hover effects.
  """


  @doc """
  Renders a data table with configurable columns and rows.

  ## Examples

      <.data_table rows={@killmails} row_id={&"killmail-\#{&1.id}"}>
        <:col :let={killmail} label="Victim" sortable>
          <%= killmail.victim_character_name %>
        </:col>
        <:col :let={killmail} label="Ship" class="text-center">
          <%= killmail.victim_ship_type %>
        </:col>
        <:col :let={killmail} label="Value" class="text-right" sortable>
          <%= format_isk(killmail.total_value) %>
        </:col>
      </.data_table>
  """
  attr(:rows, :list, required: true)
  attr(:row_id, :any, default: nil, doc: "Function to generate row ID")
  attr(:row_click, :any, default: nil, doc: "Function called when row is clicked")
  attr(:class, :string, default: "")
  attr(:empty_message, :string, default: "No data available")

  slot :col, required: true do
    attr(:label, :string, required: true)
    attr(:sortable, :boolean)
    attr(:class, :string)
  end

  def data_table(assigns) do
    ~H"""
    <div class={"overflow-x-auto #{@class}"}>
      <table class="min-w-full bg-gray-800 border border-gray-700 rounded-lg">
        <thead>
          <tr class="bg-gray-900 border-b border-gray-700">
            <th
              :for={col <- @col}
              class={"px-4 py-3 text-left text-xs font-medium text-gray-300 uppercase tracking-wider #{Map.get(col, :class, "")} #{if Map.get(col, :sortable, false), do: "cursor-pointer hover:text-white", else: ""}"}
            >
              <div class="flex items-center space-x-1">
                <span><%= col.label %></span>
                <svg
                  :if={Map.get(col, :sortable, false)}
                  class="w-3 h-3 text-gray-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
                </svg>
              </div>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-700">
          <tr
            :if={Enum.empty?(@rows)}
            class="bg-gray-800"
          >
            <td class="px-4 py-8 text-center text-gray-400 text-sm" colspan={length(@col)}>
              <%= @empty_message %>
            </td>
          </tr>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class={"bg-gray-800 hover:bg-gray-700 transition-colors #{if @row_click, do: "cursor-pointer", else: ""}"}
            phx-click={@row_click && @row_click.(row)}
          >
            <td
              :for={col <- @col}
              class={"px-4 py-3 text-sm text-gray-300 #{Map.get(col, :class, "")}"}
            >
              <%= render_slot(col, row) %>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
