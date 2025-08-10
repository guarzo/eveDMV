defmodule EveDmvWeb.Components.CorrelationMatrix do
  @moduledoc """
  Component for displaying system activity correlation matrix.
  Shows correlations between system activities over time.
  """

  use Phoenix.Component

  attr(:correlation_data, :map, required: true, doc: "Correlation matrix data")
  attr(:selected_systems, :list, default: [], doc: "Currently selected systems")
  attr(:threshold, :float, default: 0.5, doc: "Correlation threshold for highlighting")
  attr(:class, :string, default: "", doc: "Additional CSS classes")

  def correlation_matrix(assigns) do
    ~H"""
    <div class={["correlation-matrix-container", @class]}>
      <!-- Controls -->
      <div class="controls mb-4 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="flex items-center space-x-2">
            <label class="text-gray-300 text-sm">Correlation Threshold:</label>
            <input 
              type="range" 
              min="0" 
              max="1" 
              step="0.1"
              value={@threshold}
              phx-change="update-correlation-threshold"
              class="w-24 h-2 bg-gray-700 rounded-lg appearance-none cursor-pointer"
            />
            <span class="text-white text-sm font-mono w-8"><%= @threshold %></span>
          </div>
        </div>
        
        <div class="text-sm text-gray-400">
          <%= length(@correlation_data.systems || []) %> systems analyzed
        </div>
      </div>
      
      <!-- Matrix Display -->
      <%= if length(@correlation_data.systems || []) > 0 do %>
        <div class="matrix-wrapper overflow-auto bg-gray-900 rounded-lg border border-gray-700 max-h-96">
          <table class="correlation-table w-full text-xs">
            <thead class="sticky top-0 bg-gray-800 border-b border-gray-700">
              <tr>
                <th class="sticky left-0 bg-gray-800 px-2 py-2 text-left text-gray-400 min-w-24 z-10"></th>
                <%= for system <- @correlation_data.systems do %>
                  <th class="px-1 py-2 text-gray-300 min-w-12 text-center">
                    <div class="transform -rotate-45 whitespace-nowrap text-xs">
                      <%= system.name |> String.slice(0, 8) %>
                    </div>
                  </th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= for {row_system, row_idx} <- Enum.with_index(@correlation_data.systems) do %>
                <tr class="hover:bg-gray-800">
                  <td class="sticky left-0 bg-gray-900 px-2 py-2 text-gray-300 text-xs font-medium border-r border-gray-700 z-10">
                    <%= row_system.name |> String.slice(0, 12) %>
                  </td>
                  <%= for {_col_system, col_idx} <- Enum.with_index(@correlation_data.systems) do %>
                    <% correlation_value = get_correlation(@correlation_data, row_idx, col_idx) %>
                    <td 
                      class={correlation_cell_classes(correlation_value, @threshold, row_idx == col_idx)}
                      title={"Correlation: #{Float.round(correlation_value, 3)}"}
                      phx-click="select-correlation"
                      phx-value-system1={row_system.id}
                      phx-value-system2={Enum.at(@correlation_data.systems, col_idx).id}
                    >
                      <%= if row_idx == col_idx do %>
                        <span class="font-semibold">1.00</span>
                      <% else %>
                        <%= Float.round(correlation_value, 2) %>
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        
        <!-- Legend -->
        <div class="legend mt-4 flex items-center justify-center space-x-6 text-xs">
          <div class="flex items-center space-x-2">
            <div class="w-4 h-4 bg-blue-600 rounded border border-gray-600"></div>
            <span class="text-gray-400">Strong Negative (-1.0 to -0.5)</span>
          </div>
          <div class="flex items-center space-x-2">
            <div class="w-4 h-4 bg-gray-600 rounded border border-gray-600"></div>
            <span class="text-gray-400">Weak (-0.5 to 0.5)</span>
          </div>
          <div class="flex items-center space-x-2">
            <div class="w-4 h-4 bg-red-600 rounded border border-gray-600"></div>
            <span class="text-gray-400">Strong Positive (0.5 to 1.0)</span>
          </div>
          <div class="flex items-center space-x-2">
            <div class="w-4 h-4 bg-purple-600 rounded border border-gray-600"></div>
            <span class="text-gray-400">Perfect Correlation (1.0)</span>
          </div>
        </div>
        
        <!-- Interpretation Guide -->
        <div class="mt-4 bg-gray-800 rounded-lg p-4">
          <h4 class="text-sm font-semibold text-gray-200 mb-2">Interpretation Guide</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs text-gray-400">
            <div>
              <div class="font-medium text-red-400">Positive Correlation (Red)</div>
              <div>Systems with similar activity patterns. When one sees increased activity, the other tends to as well.</div>
            </div>
            <div>
              <div class="font-medium text-blue-400">Negative Correlation (Blue)</div>
              <div>Systems with opposite activity patterns. When one is active, the other tends to be quiet.</div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="text-center py-12">
          <div class="text-gray-500 text-lg mb-2">No Correlation Data</div>
          <div class="text-gray-400 text-sm">
            Select a time range with sufficient activity to generate correlation analysis.
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private helper functions

  defp get_correlation(data, row_idx, col_idx) do
    matrix = data.matrix || []

    case Enum.at(matrix, row_idx) do
      nil -> 0.0
      row -> Enum.at(row, col_idx, 0.0)
    end
  end

  defp correlation_cell_classes(value, threshold, is_diagonal) do
    base_class =
      "text-center px-1 py-2 cursor-pointer hover:bg-gray-700 transition-colors border-b border-gray-800"

    color_class =
      cond do
        is_diagonal -> "bg-purple-900 text-purple-200 font-semibold"
        value >= threshold -> "bg-red-900 text-red-200"
        value <= -threshold -> "bg-blue-900 text-blue-200"
        true -> "bg-gray-800 text-gray-400"
      end

    [base_class, color_class]
  end
end
