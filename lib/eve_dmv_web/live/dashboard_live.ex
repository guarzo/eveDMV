# credo:disable-for-this-file Credo.Check.Readability.StrictModuleLayout
defmodule EveDmvWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView displaying user statistics and recent activity.
  """

  use EveDmvWeb, :live_view

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  # Import reusable components

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    current_user = socket.assigns[:current_user]

    # Debug logging to understand the issue
    require Logger
    Logger.debug("DashboardLive mount - current_user: #{inspect(current_user)}")
    Logger.debug("DashboardLive mount - session user_id: #{inspect(session["current_user_id"])}")
    Logger.debug("DashboardLive mount - socket assigns: #{inspect(Map.keys(socket.assigns))}")

    # Redirect to login if not authenticated
    if current_user do
      socket =
        socket
        |> assign(:page_title, "Dashboard")
        |> assign(:current_user, current_user)
        |> assign(:killmail_count, get_killmail_count(current_user.eve_character_id, :kills))
        |> assign(:loss_count, get_killmail_count(current_user.eve_character_id, :losses))
        |> assign(:isk_destroyed, get_total_isk_destroyed(current_user.eve_character_id))
        |> assign(:isk_lost, get_total_isk_lost(current_user.eve_character_id))
        |> assign(:recent_kills, get_recent_kills())
        |> assign(:threat_score, get_character_threat_score(current_user.eve_character_id))

      {:ok, socket}
    else
      # Check if we have an invalid session (user ID exists but user doesn't)
      if Map.get(session, "current_user_id") do
        Logger.warning("DashboardLive: Invalid session detected, redirecting to clear session")
        {:ok, redirect(socket, to: ~p"/session/clear")}
      else
        Logger.warning("DashboardLive: No current_user found, redirecting to login")
        {:ok, redirect(socket, to: ~p"/login")}
      end
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />

    <!-- Enhanced Header with Character Info -->
    <div class="mb-8 bg-gray-800 rounded-lg p-6">
      <div class="flex items-start justify-between">
        <div class="flex items-center space-x-6">
          <!-- Character Portrait -->
          <img 
            src={character_portrait(@current_user.eve_character_id)} 
            alt="Character portrait"
            class="w-24 h-24 rounded-lg border-2 border-gray-600"
          />
          
          <!-- Character Info -->
          <div>
            <h1 class="text-3xl font-bold text-white mb-2">
              {@current_user.eve_character_name}
            </h1>
            
            <!-- Corporation Info -->
            <div class="flex items-center space-x-4 mb-2">
              <%= if @current_user.eve_corporation_name && @current_user.eve_corporation_id do %>
                <div class="flex items-center space-x-2">
                  <img 
                    src={corporation_logo(@current_user.eve_corporation_id)}
                    alt="Corporation logo"
                    class="w-8 h-8 rounded"
                  />
                  <span class="text-gray-300">{@current_user.eve_corporation_name}</span>
                </div>
              <% else %>
                <span class="text-gray-400">Independent Pilot</span>
              <% end %>
              
              <!-- Alliance Info -->
              <%= if @current_user.eve_alliance_name && @current_user.eve_alliance_id do %>
                <div class="flex items-center space-x-2">
                  <img 
                    src={alliance_logo(@current_user.eve_alliance_id)}
                    alt="Alliance logo"
                    class="w-8 h-8 rounded"
                  />
                  <span class="text-blue-400">{@current_user.eve_alliance_name}</span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
        <!-- Threat Score -->
        <%= if @threat_score.score > 0 do %>
          <div class={"ml-auto px-6 py-3 rounded-lg border " <> threat_level_bg(@threat_score.level)}>
            <div class="text-center">
              <p class="text-sm text-gray-400 mb-1">Threat Score</p>
              <p class={"text-3xl font-bold " <> threat_level_color(@threat_score.level)}>
                {@threat_score.score}/10
              </p>
              <p class="text-sm mt-1 capitalize">{@threat_score.level} Threat</p>
            </div>
          </div>
        <% end %>
      </div>
    </div>


    <!-- Main Dashboard Content -->
    <div class="grid grid-cols-1 lg:grid-cols-4 gap-6 mb-8">
      
      <!-- Favorites & Bookmarks -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          ⭐ Favorites & Bookmarks
        </h3>
        <div class="space-y-4">
          <!-- Favorite Characters & Corporations -->
          <div>
            <h4 class="text-gray-300 text-sm font-medium mb-2">Characters & Corporations</h4>
            <div class="bg-gray-900 rounded p-3 text-center">
              <svg class="mx-auto h-8 w-8 text-gray-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
              <p class="text-gray-500 text-xs">No favorites yet</p>
              <p class="text-gray-600 text-xs mt-1">Star pilots and corps from analysis pages</p>
            </div>
          </div>
          
          <!-- Favorite Battles -->
          <div>
            <h4 class="text-gray-300 text-sm font-medium mb-2">Notable Battles</h4>
            <div class="bg-gray-900 rounded p-3 text-center">
              <svg class="mx-auto h-8 w-8 text-gray-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
              </svg>
              <p class="text-gray-500 text-xs">No bookmarked battles yet</p>
              <p class="text-gray-600 text-xs mt-1">Save interesting fights for later review</p>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Combat Statistics -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          ⚔️ Combat Statistics
        </h3>
        <div class="space-y-4">
          <!-- Kill/Loss Summary -->
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-gray-900 rounded-lg p-4 text-center">
              <div class="text-2xl font-bold text-green-400">{@killmail_count}</div>
              <div class="text-sm text-gray-400">Kills</div>
            </div>
            <div class="bg-gray-900 rounded-lg p-4 text-center">
              <div class="text-2xl font-bold text-red-400">{@loss_count}</div>
              <div class="text-sm text-gray-400">Losses</div>
            </div>
          </div>
          
          <!-- ISK Summary -->
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-gray-900 rounded-lg p-3 text-center">
              <div class="text-lg font-bold text-green-400">{format_isk_simple(@isk_destroyed)}</div>
              <div class="text-xs text-gray-400">Destroyed</div>
            </div>
            <div class="bg-gray-900 rounded-lg p-3 text-center">
              <div class="text-lg font-bold text-red-400">{format_isk_simple(@isk_lost)}</div>
              <div class="text-xs text-gray-400">Lost</div>
            </div>
          </div>
          
          <!-- Efficiency -->
          <div class="bg-gray-900 rounded-lg p-4">
            <div class="flex justify-between items-center mb-2">
              <span class="text-gray-400 text-sm">Efficiency</span>
              <span class="text-white font-bold">{calculate_efficiency(@killmail_count, @loss_count, @isk_destroyed, @isk_lost)}%</span>
            </div>
            <div class="w-full bg-gray-700 rounded-full h-2">
              <div class="bg-gradient-to-r from-green-500 to-blue-500 h-2 rounded-full" 
                   style={"width: #{calculate_efficiency(@killmail_count, @loss_count, @isk_destroyed, @isk_lost)}%"}></div>
            </div>
            <p class="text-gray-500 text-xs mt-1">Last 30 days</p>
          </div>
        </div>
      </div>
      
      <!-- Chain Activity -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          🔗 Chain Activity
        </h3>
        <div class="space-y-3">
          <!-- Current Chain Status -->
          <div class="bg-gray-900 rounded p-3">
            <div class="flex justify-between items-center mb-2">
              <span class="text-gray-400 text-sm">Current Chain</span>
              <span class="text-green-400 text-xs">Connected</span>
            </div>
            <div class="space-y-1">
              <p class="text-white text-sm">J123456 → Jita</p>
              <p class="text-gray-400 text-xs">3 jumps via wormholes</p>
            </div>
          </div>
          
          <!-- Recent Chain Kills -->
          <div class="bg-gray-900 rounded p-3">
            <div class="flex justify-between items-center mb-2">
              <span class="text-gray-400 text-sm">Chain Activity</span>
              <span class="text-orange-400 text-xs">Last 1h</span>
            </div>
            <div class="space-y-1">
              <p class="text-white text-sm">5 kills detected</p>
              <p class="text-gray-400 text-xs">Mostly in J-space systems</p>
            </div>
          </div>
          
          <!-- Quick Chain Access -->
          <.link navigate={~p"/chain-intelligence"} 
                class="flex items-center p-2 bg-blue-900 hover:bg-blue-800 rounded transition-colors text-center">
            <div class="flex-1">
              <span class="text-blue-300 text-sm font-medium">→ View Full Chain Map</span>
            </div>
          </.link>
        </div>
      </div>
      
      <!-- Surveillance -->
      <div class="bg-gray-800 rounded-lg p-6">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          👁️ Surveillance
        </h3>
        <div class="space-y-3">
          <!-- Active Profiles -->
          <div class="bg-gray-900 rounded p-3">
            <div class="flex justify-between items-center mb-2">
              <span class="text-gray-400 text-sm">Active Profiles</span>
              <span class="text-green-400 text-xs">3 Running</span>
            </div>
            <div class="space-y-1">
              <p class="text-white text-sm">Hostile Corps</p>
              <p class="text-gray-400 text-xs">Monitoring 12 corporations</p>
            </div>
          </div>
          
          <!-- Recent Alerts -->
          <div class="bg-gray-900 rounded p-3">
            <div class="flex justify-between items-center mb-2">
              <span class="text-gray-400 text-sm">Recent Alerts</span>
              <span class="text-red-400 text-xs">2 new</span>
            </div>
            <div class="space-y-1">
              <p class="text-white text-sm">Hostile detected</p>
              <p class="text-gray-400 text-xs">J152430 - 15m ago</p>
            </div>
          </div>
          
          <!-- Quick Surveillance Access -->
          <.link navigate={~p"/surveillance-profiles"} 
                class="flex items-center p-2 bg-purple-900 hover:bg-purple-800 rounded transition-colors text-center">
            <div class="flex-1">
              <span class="text-purple-300 text-sm font-medium">→ Manage Profiles</span>
            </div>
          </.link>
        </div>
      </div>
    </div>

    <!-- Recent Activity Timeline -->
    <%= if @recent_kills && length(@recent_kills) > 0 do %>
      <div class="bg-gray-800 rounded-lg p-6 mb-8">
        <h2 class="text-xl font-semibold text-white mb-4 flex items-center">
          ⚡ Recent Combat Activity
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for kill <- Enum.take(@recent_kills, 6) do %>
            <.link
              navigate={~p"/killmail/#{kill.killmail_id}"}
              class="block bg-gray-900 rounded-lg p-4 border border-gray-700 hover:border-gray-600 hover:bg-gray-850 transition-all duration-200 group"
            >
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-3">
                  <img 
                    src={character_portrait(kill.character_id)}
                    alt="Victim"
                    class="w-8 h-8 rounded border border-gray-600 group-hover:border-gray-500 transition-colors"
                  />
                  <div>
                    <p class="text-white font-medium text-sm group-hover:text-blue-300 transition-colors">
                      {String.slice(kill.character_name || "Unknown", 0, 15)}<%= if String.length(kill.character_name || "Unknown") > 15 do %>...<% end %>
                    </p>
                    <p class="text-gray-400 text-xs">{get_ship_name(kill.ship_type_id)}</p>
                  </div>
                </div>
                <div class="text-right">
                  <p class="text-red-400 font-bold text-sm group-hover:text-red-300 transition-colors">
                    {format_isk_simple(kill.fitted_value || 0)}
                  </p>
                  <p class="text-gray-500 text-xs">{format_time_ago(kill.killmail_time)}</p>
                </div>
              </div>
              
              <!-- Additional kill context -->
              <div class="mt-3 pt-3 border-t border-gray-700 flex items-center justify-between text-xs">
                <span class="text-gray-500">
                  Kill #{kill.killmail_id}
                </span>
                <span class="text-blue-400 opacity-0 group-hover:opacity-100 transition-opacity">
                  View Details →
                </span>
              </div>
            </.link>
          <% end %>
        </div>
      </div>
    <% else %>
      <!-- Empty state for recent activity -->
      <div class="bg-gray-800 rounded-lg p-6 mb-8">
        <h2 class="text-xl font-semibold text-white mb-4 flex items-center">
          ⚡ Recent Combat Activity
        </h2>
        <div class="text-center py-8">
          <svg class="mx-auto h-12 w-12 text-gray-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
          </svg>
          <h3 class="text-gray-400 font-medium mb-2">No Recent Activity</h3>
          <p class="text-gray-500 text-sm">
            No killmails have been received yet. Combat activity will appear here once the kill feed is active.
          </p>
        </div>
      </div>
    <% end %>

    <!-- Intelligence Summary -->
    <%= if @threat_score.score > 0 do %>
      <div class="bg-gray-800 rounded-lg p-6 mb-8">
        <h3 class="text-white font-semibold mb-4 flex items-center">
          🎯 Personal Threat Assessment
        </h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="bg-gray-900 rounded p-4">
            <div class="flex justify-between items-center mb-2">
              <span class="text-gray-400">Threat Level</span>
              <span class={"font-semibold " <> threat_level_color(@threat_score.level)}>
                {String.capitalize(to_string(@threat_score.level))}
              </span>
            </div>
            <div class="w-full bg-gray-700 rounded-full h-3">
              <div class={"h-3 rounded-full " <> threat_level_bar_color(@threat_score.level)} 
                   style={"width: #{@threat_score.score * 10}%"}></div>
            </div>
            <p class="text-gray-500 text-xs mt-2">Score: {@threat_score.score}/10</p>
          </div>
          
          <div class="bg-gray-900 rounded p-4">
            <h4 class="text-gray-400 text-sm mb-2">Analysis Period</h4>
            <p class="text-white font-medium">Last 90 Days</p>
            <p class="text-gray-500 text-xs mt-1">
              {if @killmail_count > 0, do: "#{@killmail_count} engagements analyzed", else: "No combat data"}
            </p>
          </div>
          
          <div class="bg-gray-900 rounded p-4">
            <h4 class="text-gray-400 text-sm mb-2">Intelligence Status</h4>
            <p class="text-green-400 font-medium">Active Profile</p>
            <.link navigate={~p"/character/#{@current_user.eve_character_id}"} 
                  class="text-blue-400 hover:text-blue-300 text-xs transition-colors">
              → View Full Analysis
            </.link>
          </div>
        </div>
      </div>
    <% end %>

    """
  end

  # Private helper functions

  defp get_killmail_count(character_id, type) do
    case type do
      :kills ->
        # Count killmails where character is an attacker (not victim)
        query = """
        SELECT COUNT(*) 
        FROM killmails_raw 
        WHERE killmail_time >= NOW() - INTERVAL '30 days'
        AND victim_character_id != $1
        AND raw_data->'attackers' @> $2::jsonb
        """

        attacker_filter = Jason.encode!([%{"character_id" => character_id}])

        case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [character_id, attacker_filter]) do
          {:ok, %{rows: [[count]]}} when is_number(count) -> count
          _ -> 0
        end

      :losses ->
        # Count killmails where character is the victim
        query = """
        SELECT COUNT(*) 
        FROM killmails_raw 
        WHERE killmail_time >= NOW() - INTERVAL '30 days'
        AND victim_character_id = $1
        """

        case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [character_id]) do
          {:ok, %{rows: [[count]]}} when is_number(count) -> count
          _ -> 0
        end
    end
  rescue
    _ -> 0
  end

  defp get_recent_kills do
    # Get recent killmails from killmails_raw table with ISK values
    query = """
    SELECT 
      killmail_id, 
      victim_character_id, 
      victim_ship_type_id, 
      killmail_time,
      COALESCE(CAST(raw_data->>'zkb'->>'totalValue' AS NUMERIC), 0) as fitted_value,
      COALESCE(raw_data->>'victim'->>'character_name', 'Unknown Pilot') as character_name
    FROM killmails_raw 
    ORDER BY killmail_time DESC 
    LIMIT 6
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, []) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            killmail_id,
                            character_id,
                            ship_type_id,
                            killmail_time,
                            fitted_value,
                            character_name
                          ] ->
          %{
            killmail_id: killmail_id,
            character_id: character_id,
            character_name: character_name || "Unknown Pilot",
            # Would need ship type lookup for real names
            ship_name: "Unknown Ship",
            ship_type_id: ship_type_id,
            fitted_value: round(fitted_value || 0),
            killmail_time: killmail_time
          }
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp get_total_isk_destroyed(character_id) do
    # Calculate total ISK destroyed by character (as attacker, not victim)
    query = """
    SELECT COALESCE(SUM(CAST(raw_data->>'zkb'->>'totalValue' AS NUMERIC)), 0) as total_isk
    FROM killmails_raw 
    WHERE killmail_time >= NOW() - INTERVAL '30 days'
    AND victim_character_id != $1
    AND raw_data->'attackers' @> $2::jsonb
    AND raw_data->'zkb'->>'totalValue' IS NOT NULL
    """

    attacker_filter = Jason.encode!([%{"character_id" => character_id}])

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [character_id, attacker_filter]) do
      {:ok, %{rows: [[total_isk]]}} when is_number(total_isk) ->
        round(total_isk)

      _ ->
        0
    end
  rescue
    _ -> 0
  end

  defp get_total_isk_lost(character_id) do
    # Calculate total ISK lost by character (as victim)
    query = """
    SELECT COALESCE(SUM(CAST(raw_data->>'zkb'->>'totalValue' AS NUMERIC)), 0) as total_isk
    FROM killmails_raw 
    WHERE killmail_time >= NOW() - INTERVAL '30 days'
    AND victim_character_id = $1
    AND raw_data->'zkb'->>'totalValue' IS NOT NULL
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [character_id]) do
      {:ok, %{rows: [[total_isk]]}} when is_number(total_isk) ->
        round(total_isk)

      _ ->
        0
    end
  rescue
    _ -> 0
  end

  # defp get_fleet_engagements do
  #   # Count unique battles/engagements from the last 30 days
  #   thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

  #   query = """
  #   SELECT COUNT(DISTINCT DATE_TRUNC('hour', killmail_time)) as engagements
  #   FROM killmails_raw 
  #   WHERE killmail_time >= $1
  #   """

  #   case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [thirty_days_ago]) do
  #     {:ok, %{rows: [[count]]}} when is_number(count) -> count
  #     _ -> 0
  #   end
  # rescue
  #   _ -> 0
  # end

  defp character_portrait(character_id, size \\ 128) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end

  defp corporation_logo(corporation_id, size \\ 64) do
    "https://images.evetech.net/corporations/#{corporation_id}/logo?size=#{size}"
  end

  defp alliance_logo(alliance_id, size \\ 64) do
    "https://images.evetech.net/alliances/#{alliance_id}/logo?size=#{size}"
  end

  defp format_isk_simple(amount) when amount >= 1_000_000_000 do
    "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk_simple(amount) when amount >= 1_000_000 do
    "#{Float.round(amount / 1_000_000, 1)}M ISK"
  end

  defp format_isk_simple(amount) when amount >= 1_000 do
    "#{Float.round(amount / 1_000, 1)}K ISK"
  end

  defp format_isk_simple(amount), do: "#{amount} ISK"

  defp format_time_ago(datetime) when is_nil(datetime), do: "Unknown"

  defp format_time_ago(datetime) do
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, dt} ->
        diff = DateTime.diff(DateTime.utc_now(), dt, :second)

        cond do
          diff < 60 -> "#{diff}s ago"
          diff < 3600 -> "#{div(diff, 60)}m ago"
          diff < 86400 -> "#{div(diff, 3600)}h ago"
          true -> "#{div(diff, 86400)}d ago"
        end

      _ ->
        "Unknown"
    end
  rescue
    _ -> "Unknown"
  end

  defp get_character_threat_score(character_id) do
    case EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine.calculate_threat_score(
           character_id,
           analysis_window_days: 90,
           include_detailed_breakdown: false
         ) do
      {:ok, assessment} ->
        %{
          score: round(assessment.overall_score),
          level: assessment.threat_level
        }

      {:error, _} ->
        %{score: 0, level: :unknown}
    end
  rescue
    _ -> %{score: 0, level: :unknown}
  end

  defp threat_level_color(threat_level) do
    case threat_level do
      :extreme -> "text-red-500"
      :very_high -> "text-red-400"
      :high -> "text-orange-400"
      :moderate -> "text-yellow-400"
      :low -> "text-green-400"
      :minimal -> "text-green-500"
      _ -> "text-gray-400"
    end
  end

  defp threat_level_bg(threat_level) do
    case threat_level do
      :extreme -> "bg-red-900 border-red-600"
      :very_high -> "bg-red-800 border-red-500"
      :high -> "bg-orange-800 border-orange-500"
      :moderate -> "bg-yellow-800 border-yellow-500"
      :low -> "bg-green-800 border-green-500"
      :minimal -> "bg-green-900 border-green-600"
      _ -> "bg-gray-800 border-gray-600"
    end
  end

  defp threat_level_bar_color(threat_level) do
    case threat_level do
      :extreme -> "bg-red-500"
      :very_high -> "bg-red-400"
      :high -> "bg-orange-400"
      :moderate -> "bg-yellow-400"
      :low -> "bg-green-400"
      :minimal -> "bg-green-500"
      _ -> "bg-gray-400"
    end
  end

  defp get_ship_name(ship_type_id) when is_integer(ship_type_id) do
    case EveDmv.Eve.NameResolver.ship_name(ship_type_id) do
      name when is_binary(name) -> name
      _ -> "Unknown Ship"
    end
  end

  defp get_ship_name(_), do: "Unknown Ship"

  defp calculate_efficiency(kills, losses, isk_destroyed, isk_lost) do
    # Calculate combined efficiency based on both kill/loss ratio and ISK ratio
    kill_efficiency =
      case {kills, losses} do
        {0, 0} -> 50
        {k, 0} when k > 0 -> 100
        {0, l} when l > 0 -> 0
        {k, l} -> min(100, round(k / (k + l) * 100))
      end

    isk_efficiency =
      case {isk_destroyed, isk_lost} do
        {0, 0} -> 50
        {d, 0} when d > 0 -> 100
        {0, l} when l > 0 -> 0
        {d, l} -> min(100, round(d / (d + l) * 100))
      end

    # Weighted average: 40% kill ratio, 60% ISK ratio
    round(kill_efficiency * 0.4 + isk_efficiency * 0.6)
  end
end
