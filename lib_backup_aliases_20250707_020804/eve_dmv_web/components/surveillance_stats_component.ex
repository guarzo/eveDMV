defmodule EveDmvWeb.SurveillanceStatsComponent do
  @moduledoc """
  Sidebar component showing surveillance engine statistics and recent matches.

  Displays active profiles count, matches processed, last reload time,
  and a list of recent profile matches with killmail details.
  """

  use EveDmvWeb, :live_component

  @doc """
  Renders the surveillance stats sidebar with engine statistics and recent matches.
  """
  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="w-80 bg-gray-800 border-r border-gray-700 h-screen overflow-y-auto">
      <!-- Engine Stats -->
      <div class="p-6 border-b border-gray-700">
        <h2 class="text-lg font-semibold text-gray-200 mb-4">Engine Statistics</h2>
        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">Active Profiles:</span>
            <span class="text-green-400 font-mono">{@engine_stats.profiles_loaded || 0}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Matches Processed:</span>
            <span class="text-blue-400 font-mono">{@engine_stats.matches_processed || 0}</span>
          </div>
          <%= if @engine_stats[:last_reload] do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Last Reload:</span>
              <span class="text-yellow-400 text-xs">
                {format_datetime(@engine_stats.last_reload)}
              </span>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Recent Matches -->
      <div class="p-6">
        <h2 class="text-lg font-semibold text-gray-200 mb-4">Recent Matches</h2>
        <div class="space-y-3">
          <%= if length(@recent_matches) > 0 do %>
            <%= for match <- Enum.take(@recent_matches, 10) do %>
              <div class="bg-gray-700 rounded-lg p-3">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-medium text-green-400">
                    🎯 {length(match.profile_ids)} matches
                  </div>
                  <div class="text-xs text-gray-400">
                    {format_datetime(match.matched_at)}
                  </div>
                </div>
                <div class="text-sm text-gray-300">
                  {get_in(match, [:killmail, "victim", "character_name"]) || "Unknown Pilot"}
                </div>
                <div class="text-xs text-gray-500">
                  {get_in(match, [:killmail, "solar_system_name"]) || "Unknown System"}
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="text-center py-8">
              <div class="text-4xl text-gray-600 mb-2">🔍</div>
              <div class="text-gray-400">No recent matches</div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper function for datetime formatting
  defp format_datetime(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _} -> format_datetime(dt)
      _ -> datetime
    end
  end

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%m/%d %H:%M")
  end

  defp format_datetime(nil), do: "N/A"
  defp format_datetime(_), do: "N/A"
end
