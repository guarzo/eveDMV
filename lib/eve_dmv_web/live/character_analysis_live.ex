defmodule EveDmvWeb.CharacterAnalysisLive do
  @moduledoc """
  Live view for character combat analysis.
  
  MVP: Simple kill/death analysis with real data from killmails_raw table.
  This is our first real intelligence feature - no mock data!
  """
  
  use EveDmvWeb, :live_view
  
  alias EveDmv.Repo
  alias EveDmv.Cache.AnalysisCache
  import EveDmvWeb.EveImageComponents
  
  require Logger
  
  @impl true
  def mount(%{"character_id" => character_id}, _session, socket) do
    character_id = String.to_integer(character_id)
    
    # Start with simple loading state
    socket = 
      socket
      |> assign(:character_id, character_id)
      |> assign(:loading, true)
      |> assign(:analysis, nil)
      |> assign(:error, nil)
    
    # Load analysis asynchronously
    send(self(), :load_analysis)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_info(:load_analysis, socket) do
    character_id = socket.assigns.character_id
    
    # Use cache for character analysis
    case AnalysisCache.get_or_compute(
      AnalysisCache.char_analysis_key(character_id),
      fn -> analyze_character(character_id) end,
      :timer.minutes(10)  # Shorter TTL for character analysis
    ) do
      {:ok, analysis} ->
        {:noreply, 
         socket
         |> assign(:loading, false)
         |> assign(:analysis, analysis)}
      
      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, reason)}
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <h1 class="text-3xl font-bold text-white">Character Combat Analysis</h1>
      </div>
      
      <%= if @loading do %>
        <div class="bg-gray-800 rounded-lg p-6">
          <div class="flex items-center space-x-3">
            <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-400"></div>
            <span class="text-gray-300">Analyzing killmail data...</span>
          </div>
        </div>
      <% end %>
      
      <%= if @error do %>
        <div class="bg-red-900 border border-red-600 rounded-lg p-6">
          <h3 class="text-red-300 font-semibold mb-2">Analysis Error</h3>
          <p class="text-red-400">Error: <%= @error %></p>
        </div>
      <% end %>
      
      <%= if @analysis do %>
        <!-- Character Header with Portrait -->
        <div class="mb-6 bg-gray-800 rounded-lg p-6">
          <div class="flex items-start justify-between">
            <div class="flex items-center gap-4">
              <.character_portrait 
                character_id={@character_id} 
                name={@analysis.character_name || "Unknown Pilot"}
                size={96}
              />
              <div>
                <h2 class="text-2xl font-bold text-white"><%= @analysis.character_name || "Unknown Pilot" %></h2>
                <p class="text-gray-400">Character ID: <%= @character_id %></p>
              </div>
            </div>
            
            <!-- Quick Intelligence Summary - Right Side -->
            <div class="flex flex-col space-y-3">
              <%= if @analysis.intelligence_summary.peak_activity_hour do %>
                <div class="flex items-center space-x-2">
                  <span class="text-yellow-400">🕐</span>
                  <div>
                    <div class="text-xs text-gray-400">Peak Activity</div>
                    <div class="text-sm text-white font-medium">
                      <%= String.pad_leading(Integer.to_string(@analysis.intelligence_summary.peak_activity_hour), 2, "0") %>:00 EVE
                    </div>
                  </div>
                </div>
              <% end %>
              
              <%= if @analysis.intelligence_summary.top_location do %>
                <div class="flex items-center space-x-2">
                  <span class="text-blue-400">🌍</span>
                  <div>
                    <div class="text-xs text-gray-400">Top Location</div>
                    <div class="text-sm text-white font-medium">
                      <%= @analysis.intelligence_summary.top_location %>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <%= if @analysis.intelligence_summary.primary_timezone do %>
                <div class="flex items-center space-x-2">
                  <span class="text-green-400">⏰</span>
                  <div>
                    <div class="text-xs text-gray-400">Primary TZ</div>
                    <div class="text-sm text-white font-medium">
                      <%= @analysis.intelligence_summary.primary_timezone %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          
          <!-- Basic Stats -->
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
          
          <!-- Recent Activity -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              ⚡ Recent Activity
            </h3>
            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-gray-400">Last 30 days:</span>
                <span class="text-blue-400"><%= @analysis.recent_kills %> kills</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-400">Most Active Day:</span>
                <span class="text-gray-300"><%= @analysis.most_active_day || "N/A" %></span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-400">Days Active:</span>
                <span class="text-gray-300"><%= @analysis.active_days %></span>
              </div>
            </div>
          </div>
          
          <!-- Ships & Weapons -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🚀 Ships & Weapons
            </h3>
            <div class="space-y-3">
              <%= for {ship_name, stats} <- @analysis.top_ships do %>
                <% weapon = Enum.find(@analysis.weapon_preferences, fn w -> w.ship_name == ship_name end) %>
                <div class="bg-gray-700 rounded p-3">
                  <div class="flex items-center gap-3">
                    <.ship_image 
                      type_id={String.to_integer(stats.ship_type_id || "0")}
                      name={ship_name}
                      size={48}
                    />
                    <div class="flex-1">
                      <div class="text-gray-200 font-medium"><%= ship_name %></div>
                      <%= if weapon do %>
                        <div class="text-xs text-gray-400"><%= weapon.weapon_name %></div>
                      <% end %>
                      <div class="flex gap-4 text-xs mt-1">
                        <span class="text-green-400"><%= stats.kills %> kills</span>
                        <span class="text-red-400"><%= stats.deaths %> deaths</span>
                        <%= if stats.kills > 0 and stats.deaths > 0 do %>
                          <span class="text-blue-400">K/D: <%= Float.round(stats.kills / stats.deaths, 1) %></span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= if Enum.empty?(@analysis.top_ships) do %>
                <p class="text-gray-500 italic">No ship data available</p>
              <% end %>
            </div>
          </div>
          
        </div>
        
        <!-- External Groups Analysis -->
        <%= if not Enum.empty?(@analysis.external_groups) do %>
          <div class="mt-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🤝 Recent Flight Partners (15 days)
            </h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for group <- @analysis.external_groups do %>
                <div class="bg-gray-800 rounded-lg p-4">
                  <div class="flex items-start gap-3">
                    <!-- Show alliance logo if exists, otherwise corp logo -->
                    <div class="flex-shrink-0">
                      <%= if group.alliance_id do %>
                        <.alliance_logo 
                          alliance_id={String.to_integer(group.alliance_id || "0")}
                          name={group.alliance_name}
                          size={48}
                        />
                      <% else %>
                        <.corporation_logo 
                          corporation_id={String.to_integer(group.corp_id || "0")}
                          name={group.corp_name}
                          size={48}
                        />
                      <% end %>
                    </div>
                    <div class="flex-1">
                      <div class="flex items-center justify-between mb-1">
                        <div>
                          <a 
                            href={~p"/corporation/#{group.corp_id}"}
                            class="text-gray-200 font-medium text-sm hover:text-blue-400 transition-colors"
                          >
                            <%= group.corp_name %>
                          </a>
                          <div class="text-gray-400 text-xs"><%= group.alliance_name || "No Alliance" %></div>
                        </div>
                        <%= if group.group_type == :external_alliance do %>
                          <span class="text-xs bg-orange-600 text-white px-2 py-1 rounded">External</span>
                        <% else %>
                          <span class="text-xs bg-blue-600 text-white px-2 py-1 rounded">Allied</span>
                        <% end %>
                      </div>
                      <div class="text-green-400 text-sm mt-2">
                        <%= group.shared_kills %> shared kills
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
        
        <!-- Gang Size Patterns -->
        <%= if @analysis.gang_size_patterns.total_kills > 0 do %>
          <div class="mt-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              👥 Gang Size Preferences (90 days)
            </h3>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
              <!-- Solo -->
              <div class="bg-gray-800 rounded-lg p-4 text-center">
                <div class="text-2xl mb-2">🚀</div>
                <div class="text-white font-medium text-sm">Solo</div>
                <div class="text-gray-400 text-xs mb-2">1 pilot</div>
                <div class="text-green-400 font-semibold"><%= @analysis.gang_size_patterns.solo.kills %></div>
                <div class="text-blue-400 text-xs"><%= @analysis.gang_size_patterns.solo.percentage %>%</div>
              </div>
              
              <!-- Small Gang -->
              <div class="bg-gray-800 rounded-lg p-4 text-center">
                <div class="text-2xl mb-2">⚔️</div>
                <div class="text-white font-medium text-sm">Small Gang</div>
                <div class="text-gray-400 text-xs mb-2">2-4 pilots</div>
                <div class="text-green-400 font-semibold"><%= @analysis.gang_size_patterns.small_gang.kills %></div>
                <div class="text-blue-400 text-xs"><%= @analysis.gang_size_patterns.small_gang.percentage %>%</div>
              </div>
              
              <!-- Medium Gang -->
              <div class="bg-gray-800 rounded-lg p-4 text-center">
                <div class="text-2xl mb-2">🛡️</div>
                <div class="text-white font-medium text-sm">Medium Gang</div>
                <div class="text-gray-400 text-xs mb-2">5-10 pilots</div>
                <div class="text-green-400 font-semibold"><%= @analysis.gang_size_patterns.medium_gang.kills %></div>
                <div class="text-blue-400 text-xs"><%= @analysis.gang_size_patterns.medium_gang.percentage %>%</div>
              </div>
              
              <!-- Large Fleet -->
              <div class="bg-gray-800 rounded-lg p-4 text-center">
                <div class="text-2xl mb-2">🏴‍☠️</div>
                <div class="text-white font-medium text-sm">Large Fleet</div>
                <div class="text-gray-400 text-xs mb-2">11+ pilots</div>
                <div class="text-green-400 font-semibold"><%= @analysis.gang_size_patterns.large_fleet.kills %></div>
                <div class="text-blue-400 text-xs"><%= @analysis.gang_size_patterns.large_fleet.percentage %>%</div>
              </div>
            </div>
          </div>
        <% end %>
        
      <% end %>
    </div>
    """
  end
  
  # Character analysis with name resolution using real database queries
  defp analyze_character(character_id) do
    try do
      Logger.info("Starting analysis for character #{character_id}")
      
      # First, try to get character name from killmail data
      character_name = get_character_name(character_id)
      Logger.info("Found character name: #{character_name || "Unknown"}")
      
      # Simple count queries
      ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)
      
      # Query kills (simplified)
      kills_query = """
      SELECT COUNT(DISTINCT km.killmail_id) as kill_count
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $1
        AND km.killmail_time >= $2
      """
      
      # Query deaths (simplified)
      deaths_query = """
      SELECT COUNT(*) as death_count
      FROM killmails_raw km
      WHERE victim_character_id = $1
        AND killmail_time >= $2
      """
      
      Logger.info("Executing kill query for character #{character_id}")
      {:ok, %{rows: [[kill_count]]}} = 
        Repo.query(kills_query, [to_string(character_id), ninety_days_ago])
      
      Logger.info("Found #{kill_count} kills for character #{character_id}")
      
      {:ok, %{rows: [[death_count]]}} = 
        Repo.query(deaths_query, [character_id, ninety_days_ago])
        
      Logger.info("Found #{death_count} deaths for character #{character_id}")
      
      # Calculate simple metrics
      kd_ratio = if death_count > 0, do: Float.round(kill_count / death_count, 2), else: kill_count
      
      # Get ship and weapon preferences
      top_ships = get_ship_preferences(character_id, ninety_days_ago)
      weapon_preferences = get_weapon_preferences(character_id, ninety_days_ago)
      Logger.info("Found ship preferences for character #{character_id}: #{inspect(top_ships)}")
      Logger.info("Found weapon preferences for character #{character_id}: #{inspect(weapon_preferences)}")
      
      # Calculate ISK efficiency
      isk_stats = calculate_isk_efficiency(character_id, ninety_days_ago)
      Logger.info("Calculated ISK efficiency for character #{character_id}: #{inspect(isk_stats)}")
      
      # Get external groups analysis (15-day window for more recent activity)
      fifteen_days_ago = DateTime.utc_now() |> DateTime.add(-15, :day)
      external_groups = get_external_groups(character_id, fifteen_days_ago)
      Logger.info("Found external groups for character #{character_id}: #{inspect(external_groups)}")
      
      # Get gang size patterns
      gang_size_patterns = get_gang_size_patterns(character_id, ninety_days_ago)
      Logger.info("Found gang size patterns for character #{character_id}: #{inspect(gang_size_patterns)}")
      
      # Calculate activity metrics for the last 30 days
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
      activity_stats = calculate_activity_stats(character_id, thirty_days_ago)
      
      # Calculate intelligence summary
      intelligence_summary = calculate_character_intelligence_summary(character_id, ninety_days_ago)
      
      analysis = %{
        character_id: character_id,
        character_name: character_name,
        total_kills: kill_count,
        total_deaths: death_count,
        kd_ratio: kd_ratio,
        isk_efficiency: isk_stats.efficiency,
        isk_destroyed: isk_stats.destroyed,
        isk_lost: isk_stats.lost,
        recent_kills: activity_stats.recent_kills,
        top_ships: top_ships,
        weapon_preferences: weapon_preferences,
        external_groups: external_groups,
        gang_size_patterns: gang_size_patterns,
        active_days: activity_stats.active_days,
        most_active_day: activity_stats.most_active_day,
        intelligence_summary: intelligence_summary,
        data_points: kill_count + death_count
      }
      
      Logger.info("Analysis complete for character #{character_id}: #{inspect(analysis)}")
      {:ok, analysis}
      
    rescue
      error ->
        Logger.error("Character analysis failed for #{character_id}: #{inspect(error)}")
        {:error, "Database query failed: #{Exception.message(error)}"}
    end
  end
  
  # Get character name from killmail data (victim or attacker records)
  defp get_character_name(character_id) do
    try do
      # First, try to find the character as a victim
      victim_query = """
      SELECT victim_character_name
      FROM killmails_raw 
      WHERE victim_character_id = $1 
        AND victim_character_name IS NOT NULL
      LIMIT 1
      """
      
      case Repo.query(victim_query, [character_id]) do
        {:ok, %{rows: [[name]]}} when is_binary(name) ->
          name
        _ ->
          # If not found as victim, try as attacker
          attacker_query = """
          SELECT attacker->>'character_name' as character_name
          FROM killmails_raw km,
               jsonb_array_elements(raw_data->'attackers') as attacker
          WHERE attacker->>'character_id' = $1
            AND attacker->>'character_name' IS NOT NULL
          LIMIT 1
          """
          
          case Repo.query(attacker_query, [to_string(character_id)]) do
            {:ok, %{rows: [[name]]}} when is_binary(name) ->
              name
            _ ->
              nil
          end
      end
    rescue
      error ->
        Logger.error("Failed to get character name for #{character_id}: #{inspect(error)}")
        nil
    end
  end
  
  # Get ship and weapon preferences from killmail data
  defp get_ship_preferences(character_id, ninety_days_ago) do
    try do
      # Query ship usage from kills (attacker data)
      kills_ships_query = """
      SELECT 
        attacker->>'ship_name' as ship_name,
        attacker->>'ship_type_id' as ship_type_id,
        COUNT(*) as kill_count
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $1
        AND km.killmail_time >= $2
        AND attacker->>'ship_name' IS NOT NULL
      GROUP BY attacker->>'ship_name', attacker->>'ship_type_id'
      ORDER BY kill_count DESC
      LIMIT 5
      """
      
      # Query ship usage from deaths (victim data)
      deaths_ships_query = """
      SELECT 
        raw_data->'victim'->>'ship_name' as ship_name,
        raw_data->'victim'->>'ship_type_id' as ship_type_id,
        COUNT(*) as death_count
      FROM killmails_raw km
      WHERE victim_character_id = $1
        AND killmail_time >= $2
        AND raw_data->'victim'->>'ship_name' IS NOT NULL
      GROUP BY raw_data->'victim'->>'ship_name', raw_data->'victim'->>'ship_type_id'
      ORDER BY death_count DESC
      LIMIT 5
      """
      
      Logger.info("Querying ship preferences for character #{character_id}")
      
      # Get kill ships
      {:ok, kill_ships_result} = Repo.query(kills_ships_query, [to_string(character_id), ninety_days_ago])
      kill_ships = Enum.map(kill_ships_result.rows, fn [ship_name, ship_type_id, count] ->
        %{ship_name: ship_name, ship_type_id: ship_type_id, kills: count, deaths: 0}
      end)
      
      # Get death ships  
      {:ok, death_ships_result} = Repo.query(deaths_ships_query, [character_id, ninety_days_ago])
      death_ships = Enum.map(death_ships_result.rows, fn [ship_name, ship_type_id, count] ->
        %{ship_name: ship_name, ship_type_id: ship_type_id, kills: 0, deaths: count}
      end)
      
      # Combine and aggregate ship data
      all_ships = (kill_ships ++ death_ships)
      |> Enum.group_by(& &1.ship_name)
      |> Enum.map(fn {ship_name, ships} ->
        total_kills = Enum.sum(Enum.map(ships, & &1.kills))
        total_deaths = Enum.sum(Enum.map(ships, & &1.deaths))
        ship_type_id = ships |> Enum.find(& &1.ship_type_id) |> Map.get(:ship_type_id)
        
        {ship_name, %{kills: total_kills, deaths: total_deaths, ship_type_id: ship_type_id}}
      end)
      |> Enum.sort_by(fn {_name, stats} -> stats.kills + stats.deaths end, :desc)
      |> Enum.take(5)
      
      Logger.info("Ship analysis complete: #{inspect(all_ships)}")
      all_ships
      
    rescue
      error ->
        Logger.error("Failed to get ship preferences for #{character_id}: #{inspect(error)}")
        []
    end
  end
  
  # Get weapon preferences from killmail data
  defp get_weapon_preferences(character_id, ninety_days_ago) do
    try do
      # Query weapon usage from kills (attacker data)
      weapons_query = """
      SELECT 
        attacker->>'weapon_type_id' as weapon_type_id,
        attacker->>'ship_name' as ship_name,
        COUNT(*) as usage_count
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $1
        AND km.killmail_time >= $2
        AND attacker->>'weapon_type_id' IS NOT NULL
        AND attacker->>'ship_name' IS NOT NULL
      GROUP BY attacker->>'weapon_type_id', attacker->>'ship_name'
      ORDER BY usage_count DESC
      LIMIT 5
      """
      
      Logger.info("Querying weapon preferences for character #{character_id}")
      
      {:ok, weapons_result} = Repo.query(weapons_query, [to_string(character_id), ninety_days_ago])
      
      weapons = Enum.map(weapons_result.rows, fn [weapon_type_id, ship_name, count] ->
        # For now, use weapon_type_id as name - we could enhance this with EVE static data later
        weapon_name = get_weapon_name(weapon_type_id) || "Weapon #{weapon_type_id}"
        %{
          weapon_name: weapon_name,
          weapon_type_id: weapon_type_id,
          ship_name: ship_name,
          usage_count: count
        }
      end)
      
      Logger.info("Weapon analysis complete: #{inspect(weapons)}")
      weapons
      
    rescue
      error ->
        Logger.error("Failed to get weapon preferences for #{character_id}: #{inspect(error)}")
        []
    end
  end
  
  # Enhanced weapon name resolution using EVE static data
  defp get_weapon_name(weapon_type_id) do
    try do
      # Query the eve_item_types table for weapon name
      weapon_name_query = """
      SELECT type_name 
      FROM eve_item_types 
      WHERE type_id = $1
      LIMIT 1
      """
      
      case Repo.query(weapon_name_query, [String.to_integer(weapon_type_id)]) do
        {:ok, %{rows: [[weapon_name]]}} -> weapon_name
        _ -> nil
      end
      
    rescue
      _error -> nil
    end
  end
  
  # Calculate ISK efficiency from killmail data
  defp calculate_isk_efficiency(character_id, ninety_days_ago) do
    try do
      # Query ISK destroyed from kills (where character was involved as attacker)
      isk_destroyed_query = """
      SELECT COALESCE(SUM(CAST(raw_data->'zkb'->>'totalValue' AS DECIMAL)), 0) as total_destroyed
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $1
        AND km.killmail_time >= $2
        AND raw_data->'zkb'->>'totalValue' IS NOT NULL
      """
      
      # Query ISK lost from deaths (where character was victim)
      isk_lost_query = """
      SELECT COALESCE(SUM(CAST(raw_data->'zkb'->>'totalValue' AS DECIMAL)), 0) as total_lost
      FROM killmails_raw km
      WHERE victim_character_id = $1
        AND killmail_time >= $2
        AND raw_data->'zkb'->>'totalValue' IS NOT NULL
      """
      
      Logger.info("Querying ISK destroyed for character #{character_id}")
      {:ok, destroyed_result} = Repo.query(isk_destroyed_query, [to_string(character_id), ninety_days_ago])
      [[isk_destroyed_decimal]] = destroyed_result.rows
      isk_destroyed = Decimal.to_float(isk_destroyed_decimal)
      
      Logger.info("Querying ISK lost for character #{character_id}")
      {:ok, lost_result} = Repo.query(isk_lost_query, [character_id, ninety_days_ago])
      [[isk_lost_decimal]] = lost_result.rows
      isk_lost = Decimal.to_float(isk_lost_decimal)
      
      # Calculate efficiency percentage
      total_isk = isk_destroyed + isk_lost
      efficiency = if total_isk > 0 do
        Float.round((isk_destroyed / total_isk) * 100, 1)
      else
        0.0
      end
      
      Logger.info("ISK calculation: destroyed=#{isk_destroyed}, lost=#{isk_lost}, efficiency=#{efficiency}%")
      
      %{
        destroyed: isk_destroyed,
        lost: isk_lost,
        efficiency: efficiency
      }
      
    rescue
      error ->
        Logger.error("Failed to calculate ISK efficiency for #{character_id}: #{inspect(error)}")
        %{destroyed: 0.0, lost: 0.0, efficiency: 0.0}
    end
  end
  
  # Format ISK values in human-readable format
  defp format_isk(isk_value) when is_float(isk_value) or is_integer(isk_value) do
    cond do
      isk_value >= 1_000_000_000_000 ->
        "#{Float.round(isk_value / 1_000_000_000_000, 1)}T ISK"
      isk_value >= 1_000_000_000 ->
        "#{Float.round(isk_value / 1_000_000_000, 1)}B ISK"
      isk_value >= 1_000_000 ->
        "#{Float.round(isk_value / 1_000_000, 1)}M ISK"
      isk_value >= 1_000 ->
        "#{Float.round(isk_value / 1_000, 1)}K ISK"
      true ->
        "#{Float.round(isk_value, 0)} ISK"
    end
  end
  
  defp format_isk(_), do: "0 ISK"
  
  # Get external groups (corps/alliances) the character has flown with
  defp get_external_groups(character_id, since_date) do
    try do
      # First, find character's own corp/alliance
      own_group_query = """
      SELECT attacker->>'corporation_name' as corp_name, attacker->>'alliance_name' as alliance_name
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE attacker->>'character_id' = $1
        AND km.killmail_time >= $2
      LIMIT 1
      """
      
      Logger.info("Finding character's own corp/alliance for #{character_id}")
      {:ok, own_group_result} = Repo.query(own_group_query, [to_string(character_id), since_date])
      
      {own_corp, own_alliance} = case own_group_result.rows do
        [[corp, alliance]] -> {corp, alliance}
        [] -> {nil, nil}
      end
      
      Logger.info("Character #{character_id} belongs to corp: #{own_corp}, alliance: #{own_alliance}")
      
      # Find external groups they've fought with
      external_groups_query = """
      SELECT 
        attacker->>'corporation_id' as corp_id,
        attacker->>'corporation_name' as corp_name,
        attacker->>'alliance_id' as alliance_id,
        attacker->>'alliance_name' as alliance_name,
        COUNT(DISTINCT km.killmail_id) as shared_kills
      FROM killmails_raw km,
           jsonb_array_elements(raw_data->'attackers') as attacker
      WHERE km.killmail_id IN (
        SELECT DISTINCT km2.killmail_id 
        FROM killmails_raw km2,
             jsonb_array_elements(km2.raw_data->'attackers') as att 
        WHERE att->>'character_id' = $1
          AND km2.killmail_time >= $2
      )
      AND attacker->>'corporation_name' IS NOT NULL
      AND attacker->>'corporation_name' <> COALESCE($3, '')
      AND attacker->>'character_id' <> $1
      GROUP BY attacker->>'corporation_id', attacker->>'corporation_name', 
               attacker->>'alliance_id', attacker->>'alliance_name'
      ORDER BY shared_kills DESC
      LIMIT 5
      """
      
      Logger.info("Querying external groups for character #{character_id}")
      {:ok, external_result} = Repo.query(external_groups_query, [
        to_string(character_id), 
        since_date, 
        own_corp
      ])
      
      external_groups = Enum.map(external_result.rows, fn [corp_id, corp_name, alliance_id, alliance_name, shared_kills] ->
        # Determine if this is truly external (different alliance) or just different corp
        is_external_alliance = alliance_name != own_alliance
        group_type = if is_external_alliance, do: :external_alliance, else: :same_alliance
        
        %{
          corp_id: corp_id,
          corp_name: corp_name,
          alliance_id: alliance_id,
          alliance_name: alliance_name,
          shared_kills: shared_kills,
          group_type: group_type
        }
      end)
      
      Logger.info("External groups analysis complete: #{inspect(external_groups)}")
      external_groups
      
    rescue
      error ->
        Logger.error("Failed to get external groups for #{character_id}: #{inspect(error)}")
        []
    end
  end
  
  # Analyze gang size patterns from killmail data
  defp get_gang_size_patterns(character_id, ninety_days_ago) do
    try do
      # Query gang sizes for kills where character participated
      gang_size_query = """
      SELECT 
        jsonb_array_length(raw_data->'attackers') as attacker_count,
        COUNT(*) as kill_count
      FROM killmails_raw km
      WHERE EXISTS (
        SELECT 1 
        FROM jsonb_array_elements(raw_data->'attackers') as att 
        WHERE att->>'character_id' = $1
      )
      AND km.killmail_time >= $2
      GROUP BY jsonb_array_length(raw_data->'attackers')
      ORDER BY attacker_count
      """
      
      Logger.info("Querying gang size patterns for character #{character_id}")
      {:ok, gang_size_result} = Repo.query(gang_size_query, [to_string(character_id), ninety_days_ago])
      
      # Categorize based on attacker count
      {solo_kills, small_gang_kills, medium_gang_kills, large_fleet_kills} = 
        Enum.reduce(gang_size_result.rows, {0, 0, 0, 0}, fn [attacker_count, kill_count], {solo, small, medium, large} ->
          case attacker_count do
            1 -> {solo + kill_count, small, medium, large}
            count when count in 2..4 -> {solo, small + kill_count, medium, large}
            count when count in 5..10 -> {solo, small, medium + kill_count, large}
            count when count > 10 -> {solo, small, medium, large + kill_count}
            _ -> {solo, small, medium, large}
          end
        end)
      
      # Calculate total and percentages
      total_kills = solo_kills + small_gang_kills + medium_gang_kills + large_fleet_kills
      
      # Calculate percentages
      solo_percentage = if total_kills > 0, do: Float.round(solo_kills / total_kills * 100, 1), else: 0.0
      small_gang_percentage = if total_kills > 0, do: Float.round(small_gang_kills / total_kills * 100, 1), else: 0.0
      medium_gang_percentage = if total_kills > 0, do: Float.round(medium_gang_kills / total_kills * 100, 1), else: 0.0
      large_fleet_percentage = if total_kills > 0, do: Float.round(large_fleet_kills / total_kills * 100, 1), else: 0.0
      
      patterns = %{
        solo: %{
          kills: solo_kills,
          percentage: solo_percentage
        },
        small_gang: %{
          kills: small_gang_kills,
          percentage: small_gang_percentage
        },
        medium_gang: %{
          kills: medium_gang_kills,
          percentage: medium_gang_percentage
        },
        large_fleet: %{
          kills: large_fleet_kills,
          percentage: large_fleet_percentage
        },
        total_kills: total_kills
      }
      
      Logger.info("Gang size analysis complete: #{inspect(patterns)}")
      patterns
      
    rescue
      error ->
        Logger.error("Failed to get gang size patterns for #{character_id}: #{inspect(error)}")
        %{
          solo: %{kills: 0, percentage: 0.0},
          small_gang: %{kills: 0, percentage: 0.0},
          medium_gang: %{kills: 0, percentage: 0.0},
          large_fleet: %{kills: 0, percentage: 0.0},
          total_kills: 0
        }
    end
  end
  
  # Calculate character intelligence summary (peak activity, top location, primary timezone)
  defp calculate_character_intelligence_summary(character_id, since_date) do
    try do
      # Calculate peak activity hour
      peak_activity_hour = calculate_character_peak_activity_hour(character_id, since_date)
      
      # Calculate top location
      top_location = calculate_character_top_location(character_id, since_date)
      
      # Calculate primary timezone
      primary_timezone = calculate_character_primary_timezone(character_id, since_date)
      
      %{
        peak_activity_hour: peak_activity_hour,
        top_location: top_location,
        primary_timezone: primary_timezone
      }
      
    rescue
      error ->
        Logger.error("Failed to calculate character intelligence summary for #{character_id}: #{inspect(error)}")
        %{
          peak_activity_hour: nil,
          top_location: nil,
          primary_timezone: nil
        }
    end
  end
  
  # Calculate peak activity hour for character
  defp calculate_character_peak_activity_hour(character_id, since_date) do
    try do
      # Query activity by hour
      peak_hour_query = """
      SELECT 
        CAST(EXTRACT(HOUR FROM km.killmail_time AT TIME ZONE 'UTC') AS INTEGER) as hour,
        COUNT(*) as activity_count
      FROM killmails_raw km
      WHERE (
        victim_character_id = $1
        OR EXISTS (
          SELECT 1 
          FROM jsonb_array_elements(raw_data->'attackers') as att 
          WHERE att->>'character_id' = $2
        )
      )
      AND km.killmail_time >= $3
      GROUP BY hour
      ORDER BY activity_count DESC
      LIMIT 1
      """
      
      case Repo.query(peak_hour_query, [character_id, to_string(character_id), since_date]) do
        {:ok, %{rows: [[hour, _count]]}} -> hour  # Should be an integer now due to CAST
        _ -> nil
      end
      
    rescue
      error ->
        Logger.error("Failed to calculate peak activity hour for character #{character_id}: #{inspect(error)}")
        nil
    end
  end
  
  # Calculate top location for character
  defp calculate_character_top_location(character_id, since_date) do
    try do
      # Query top location by activity
      top_location_query = """
      SELECT 
        km.solar_system_id,
        COUNT(*) as activity_count
      FROM killmails_raw km
      WHERE (
        victim_character_id = $1
        OR EXISTS (
          SELECT 1 
          FROM jsonb_array_elements(raw_data->'attackers') as att 
          WHERE att->>'character_id' = $2
        )
      )
      AND km.killmail_time >= $3
      AND km.solar_system_id IS NOT NULL
      GROUP BY km.solar_system_id
      ORDER BY activity_count DESC
      LIMIT 1
      """
      
      case Repo.query(top_location_query, [character_id, to_string(character_id), since_date]) do
        {:ok, %{rows: [[system_id, _count]]}} -> 
          get_system_name_from_db(system_id)
        _ -> nil
      end
      
    rescue
      error ->
        Logger.error("Failed to calculate top location for character #{character_id}: #{inspect(error)}")
        nil
    end
  end
  
  # Calculate primary timezone for character
  defp calculate_character_primary_timezone(character_id, since_date) do
    try do
      # Query hourly activity distribution
      timezone_query = """
      SELECT 
        CAST(EXTRACT(HOUR FROM km.killmail_time AT TIME ZONE 'UTC') AS INTEGER) as hour,
        COUNT(*) as activity_count
      FROM killmails_raw km
      WHERE (
        victim_character_id = $1
        OR EXISTS (
          SELECT 1 
          FROM jsonb_array_elements(raw_data->'attackers') as att 
          WHERE att->>'character_id' = $2
        )
      )
      AND km.killmail_time >= $3
      GROUP BY hour
      ORDER BY hour
      """
      
      {:ok, hourly_result} = Repo.query(timezone_query, [character_id, to_string(character_id), since_date])
      
      # Create hourly distribution map (hour should be integer now due to CAST)
      hourly_distribution = 
        hourly_result.rows
        |> Enum.map(fn [hour, count] -> {hour, count} end)
        |> Map.new()
      
      # Analyze timezone based on activity patterns
      analyze_character_timezone(hourly_distribution)
      
    rescue
      error ->
        Logger.error("Failed to calculate primary timezone for character #{character_id}: #{inspect(error)}")
        nil
    end
  end
  
  # Analyze timezone based on hourly activity distribution
  defp analyze_character_timezone(hourly_distribution) do
    # Define timezone blocks (approximate EVE time zones)
    timezone_blocks = %{
      "EU" => 18..22,
      "US" => 0..4,
      "AUTZ" => 10..14
    }
    
    # Calculate activity for each timezone
    timezone_scores = 
      Enum.map(timezone_blocks, fn {tz_name, hours} ->
        total_activity = 
          Enum.to_list(hours)
          |> Enum.map(&Map.get(hourly_distribution, &1, 0))
          |> Enum.sum()
        
        {tz_name, total_activity}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
    
    # Return the timezone with highest activity, or nil if no significant activity
    case timezone_scores do
      [{tz_name, activity} | _] when activity > 0 -> tz_name
      _ -> nil
    end
  end
  
  # Get system name from database
  defp get_system_name_from_db(system_id) do
    try do
      system_name_query = """
      SELECT system_name 
      FROM eve_solar_systems 
      WHERE system_id = $1
      LIMIT 1
      """
      
      case Repo.query(system_name_query, [system_id]) do
        {:ok, %{rows: [[system_name]]}} -> system_name
        _ -> "System #{system_id}"
      end
      
    rescue
      _error -> "System #{system_id}"
    end
  end

  # Calculate activity statistics for the last 30 days
  defp calculate_activity_stats(character_id, since_date) do
    try do
      # Query kills by day for the last 30 days
      activity_query = """
      SELECT 
        DATE(km.killmail_time) as activity_date,
        COUNT(*) as daily_kills
      FROM killmails_raw km
      WHERE (
        victim_character_id = $1
        OR EXISTS (
          SELECT 1 
          FROM jsonb_array_elements(raw_data->'attackers') as att 
          WHERE att->>'character_id' = $2
        )
      )
      AND km.killmail_time >= $3
      GROUP BY DATE(km.killmail_time)
      ORDER BY daily_kills DESC
      """
      
      Logger.info("Querying activity stats for character #{character_id}")
      {:ok, activity_result} = Repo.query(activity_query, [character_id, to_string(character_id), since_date])
      
      # Extract statistics
      active_days_count = length(activity_result.rows)
      
      {most_active_date, most_active_kills} = case activity_result.rows do
        [[date, kills] | _] -> {date, kills}
        [] -> {nil, 0}
      end
      
      # Format most active day as "Weekday (X kills)"
      most_active_day_formatted = if most_active_date do
        weekday = Calendar.strftime(most_active_date, "%A")
        "#{weekday} (#{most_active_kills} kills)"
      else
        "No activity"
      end
      
      # Count recent kills (last 30 days)
      recent_kills = activity_result.rows
        |> Enum.map(fn [_, kills] -> kills end)
        |> Enum.sum()
      
      %{
        recent_kills: recent_kills,
        active_days: active_days_count,
        most_active_day: most_active_day_formatted
      }
      
    rescue
      error ->
        Logger.error("Failed to calculate activity stats for #{character_id}: #{inspect(error)}")
        %{
          recent_kills: 0,
          active_days: 0,
          most_active_day: "No activity"
        }
    end
  end
end