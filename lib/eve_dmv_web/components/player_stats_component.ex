defmodule EveDmvWeb.PlayerStatsComponent do
  @moduledoc """
  Component for displaying player statistics in a grid layout.

  Shows basic stats, solo vs gang performance, and ISK statistics
  in organized cards with proper formatting.
  """

  use EveDmvWeb, :live_component
  import EveDmvWeb.FormatHelpers

  @doc """
  Renders the complete player statistics section with multiple cards:
  - Basic Statistics (kills, losses, K/D, efficiency)
  - Solo vs Gang Performance 
  - ISK Performance (destroyed, lost, net)
  - Activity & Behavior (danger rating, activity type, gang preference)
  - Ship Usage (favorite ship, diversity, regions)
  - Time Information (last updated, period)
  """
  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
      <!-- Basic Stats Card -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-blue-400">Basic Statistics</h3>

        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">Character:</span>
            <span class="font-medium">{@player_stats.character_name}</span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Total Kills:</span>
            <span class="font-medium text-green-400">
              {format_number(@player_stats.total_kills)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Total Losses:</span>
            <span class="font-medium text-red-400">
              {format_number(@player_stats.total_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">K/D Ratio:</span>
            <span class="font-medium">
              {format_ratio(@player_stats.total_kills, @player_stats.total_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">ISK Efficiency:</span>
            <span class="font-medium">
              {format_percentage(@player_stats.isk_efficiency_percent)}
            </span>
          </div>
        </div>
      </div>
      
      <!-- Solo vs Gang Stats -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-purple-400">Solo vs Gang Performance</h3>

        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">Solo Kills:</span>
            <span class="font-medium text-purple-400">
              {format_number(@player_stats.solo_kills)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Solo Losses:</span>
            <span class="font-medium text-purple-300">
              {format_number(@player_stats.solo_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Gang Kills:</span>
            <span class="font-medium text-blue-400">
              {format_number(@player_stats.gang_kills)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Gang Losses:</span>
            <span class="font-medium text-blue-300">
              {format_number(@player_stats.gang_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Solo K/D:</span>
            <span class="font-medium">
              {format_ratio(@player_stats.solo_kills, @player_stats.solo_losses)}
            </span>
          </div>
        </div>
      </div>
      
      <!-- ISK Statistics -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-yellow-400">ISK Performance</h3>

        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">ISK Destroyed:</span>
            <span class="font-medium text-green-400">
              {format_isk(@player_stats.total_isk_destroyed)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">ISK Lost:</span>
            <span class="font-medium text-red-400">
              {format_isk(@player_stats.total_isk_lost)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Net ISK:</span>
            <span class={"font-medium #{net_isk_class(@player_stats.total_isk_destroyed, @player_stats.total_isk_lost)}"}>
              {format_net_isk(@player_stats.total_isk_destroyed, @player_stats.total_isk_lost)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Efficiency:</span>
            <span class="font-medium">
              {format_percentage(@player_stats.isk_efficiency_percent)}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Additional Information -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      <!-- Activity & Behavior -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-cyan-400">Activity & Behavior</h3>

        <div class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-gray-400">Danger Rating:</span>
            <div>
              <% {stars, badge_class} = danger_badge(@player_stats.danger_rating) %>
              <span class={"px-2 py-1 rounded text-sm font-medium #{badge_class}"}>{stars}</span>
            </div>
          </div>

          <div class="flex justify-between items-center">
            <span class="text-gray-400">Primary Activity:</span>
            <div>
              <% {activity_text, activity_class} =
                activity_badge(@player_stats.primary_activity) %>
              <span class={"px-2 py-1 rounded text-sm font-medium #{activity_class}"}>
                {activity_text}
              </span>
            </div>
          </div>

          <div class="flex justify-between items-center">
            <span class="text-gray-400">Gang Preference:</span>
            <div>
              <% {gang_text, gang_class} = gang_size_badge(@player_stats.preferred_gang_size) %>
              <span class={"px-2 py-1 rounded text-sm font-medium #{gang_class}"}>{gang_text}</span>
            </div>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Avg Gang Size:</span>
            <span class="font-medium">
              {format_avg_gang_size(@player_stats.avg_gang_size)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Ship Types Used:</span>
            <span class="font-medium">{@player_stats.ship_types_used}</span>
          </div>
        </div>
      </div>
      
      <!-- Ship Information -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-orange-400">Ship Usage</h3>

        <div class="space-y-3">
          <%= if @player_stats.favorite_ship_name do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Favorite Ship:</span>
              <span class="font-medium text-orange-400">
                {@player_stats.favorite_ship_name}
              </span>
            </div>
          <% end %>

          <div class="flex justify-between">
            <span class="text-gray-400">Ship Diversity:</span>
            <span class="font-medium">
              {@player_stats.ship_types_used} different ships
            </span>
          </div>

          <%= if @player_stats.active_regions && @player_stats.active_regions > 0 do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Active Regions:</span>
              <span class="font-medium">{@player_stats.active_regions}</span>
            </div>
          <% end %>

          <%= if @player_stats.home_region_name do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Home Region:</span>
              <span class="font-medium">{@player_stats.home_region_name}</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Time Information -->
    <%= if @player_stats.last_updated do %>
      <div class="bg-gray-800 rounded-lg p-4 border border-gray-700">
        <div class="flex justify-between items-center text-sm text-gray-400">
          <span>
            Statistics last updated: {Calendar.strftime(
              @player_stats.last_updated,
              "%Y-%m-%d %H:%M:%S UTC"
            )}
          </span>
          <%= if @player_stats.stats_period_start && @player_stats.stats_period_end do %>
            <span>
              Period: {Date.to_string(@player_stats.stats_period_start)} to {Date.to_string(
                @player_stats.stats_period_end
              )}
            </span>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  # Badge helper functions

  defp danger_badge(rating) do
    stars = String.duplicate("⭐", rating)

    class =
      case rating do
        5 -> "bg-red-600 text-white"
        4 -> "bg-red-500 text-white"
        3 -> "bg-yellow-500 text-black"
        2 -> "bg-blue-500 text-white"
        _ -> "bg-gray-500 text-white"
      end

    {stars, class}
  end

  defp activity_badge(activity) do
    case activity do
      "solo_pvp" -> {"🎯 Solo PvP", "bg-purple-600 text-white"}
      "small_gang" -> {"👥 Small Gang", "bg-blue-600 text-white"}
      "fleet_pvp" -> {"🚢 Fleet PvP", "bg-green-600 text-white"}
      _ -> {"❓ Unknown", "bg-gray-600 text-white"}
    end
  end

  defp gang_size_badge(size) do
    case size do
      "solo" -> {"🎯 Solo", "bg-purple-600 text-white"}
      "small_gang" -> {"👥 Small Gang", "bg-blue-600 text-white"}
      "medium_gang" -> {"👥 Medium Gang", "bg-yellow-600 text-black"}
      "fleet" -> {"🚢 Fleet", "bg-green-600 text-white"}
      _ -> {"❓ Unknown", "bg-gray-600 text-white"}
    end
  end
end
