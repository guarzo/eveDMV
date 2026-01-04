defmodule EveDmvWeb.CharacterAnalysisLive do
  @moduledoc """
  Live view for character combat analysis.

  MVP: Simple kill/death analysis with real data from killmails_raw table.
  This is our first real intelligence feature - no mock data!
  """

  use EveDmvWeb, :live_view

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  alias EveDmv.Contexts.BattleAnalysis.Domain.Services.DetectionService, as: BattleDetector
  alias EveDmv.Integrations.ShipIntelligenceBridge
  alias EveDmv.Platform.Cache.AnalysisCache
  alias EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader
  alias EveDmvWeb.CharacterAnalysis.Helpers.DisplayFormatters

  alias EveDmvWeb.CharacterAnalysis.Components.CharacterHeaderComponent
  alias EveDmvWeb.CharacterAnalysis.Components.IntelligenceSummaryComponent
  alias EveDmvWeb.CharacterAnalysis.Components.StatisticsPanelComponent

  @valid_tabs ~w(overview battles ships weapons activity)a

  @impl Phoenix.LiveView
  def mount(%{"character_id" => character_id}, _session, socket) do
    character_id = String.to_integer(character_id)

    # Start with simple loading state
    socket =
      socket
      |> assign(:character_id, character_id)
      |> assign(:loading, true)
      |> assign(:analysis, nil)
      |> assign(:intelligence, nil)
      |> assign(:recent_battles, [])
      |> assign(:battle_stats, nil)
      |> assign(:ship_specialization, nil)
      |> assign(:ship_preferences, nil)
      |> assign(:error, nil)
      |> assign(:active_tab, :overview)

    # Load analysis asynchronously
    send(self(), :load_analysis)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:load_analysis, socket) do
    character_id = socket.assigns.character_id

    # Load both basic analysis and intelligence data
    basic_analysis_task =
      Task.async(fn ->
        AnalysisCache.get_or_compute(
          AnalysisCache.char_analysis_key(character_id),
          fn -> CharacterDataLoader.analyze_character(character_id) end,
          :timer.minutes(10)
        )
      end)

    intelligence_task =
      Task.async(fn ->
        EveDmv.Contexts.CharacterIntelligence.get_character_intelligence_report(character_id)
      end)

    battle_data_task =
      Task.async(fn ->
        {
          BattleDetector.detect_character_battles(character_id, 10),
          BattleDetector.get_character_battle_stats(character_id)
        }
      end)

    ship_intelligence_task =
      Task.async(fn ->
        {
          ShipIntelligenceBridge.calculate_ship_specialization(character_id),
          ShipIntelligenceBridge.get_character_ship_preferences(character_id)
        }
      end)

    # Await all tasks
    basic_analysis_result = Task.await(basic_analysis_task, 30_000)
    intelligence_result = Task.await(intelligence_task, 30_000)
    {battles, battle_stats} = Task.await(battle_data_task, 30_000)
    {ship_specialization, ship_preferences} = Task.await(ship_intelligence_task, 30_000)

    # Unwrap intelligence result - it returns {:ok, data} or {:error, reason}
    intelligence =
      case intelligence_result do
        {:ok, data} -> data
        {:error, _} -> nil
        data when is_map(data) -> data
        _ -> nil
      end

    case basic_analysis_result do
      {:ok, analysis} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:analysis, analysis)
          |> assign(:intelligence, intelligence)
          |> assign(:recent_battles, battles)
          |> assign(:battle_stats, battle_stats)
          |> assign(:ship_specialization, ship_specialization)
          |> assign(:ship_preferences, ship_preferences)
          |> assign(:error, nil)

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, error)

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)

    if tab_atom in @valid_tabs do
      {:noreply, assign(socket, :active_tab, tab_atom)}
    else
      {:noreply, socket}
    end
  rescue
    ArgumentError ->
      {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("force_refresh", _params, socket) do
    character_id = socket.assigns.character_id

    # Clear cache and reload
    AnalysisCache.delete(AnalysisCache.char_analysis_key(character_id))

    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)

    send(self(), :load_analysis)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6 flex justify-between items-center">
        <h1 class="text-3xl font-bold text-white">Character Combat Analysis</h1>
        <div class="flex space-x-2">
          <button
            phx-click="force_refresh"
            class="p-2 bg-gray-700 hover:bg-gray-600 text-white rounded-md transition-colors"
            title="Force Refresh"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
          </button>
        </div>
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
        <.live_component
          module={CharacterHeaderComponent}
          id="character-header"
          character_id={@character_id}
          analysis={@analysis}
          intelligence={@intelligence}
        />

        <!-- Top row: Summary cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          <.live_component
            module={IntelligenceSummaryComponent}
            id="intelligence-summary"
            analysis={@analysis}
          />

          <.live_component
            module={StatisticsPanelComponent}
            id="statistics-panel"
            analysis={@analysis}
          />

          <!-- Recent Activity card (moved from ActivityFeedComponent) -->
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
        </div>

        <!-- Bait Warning Banner (if applicable) -->
        <%= if @analysis.bait_indicators && @analysis.bait_indicators.is_likely_bait do %>
          <div class="bg-yellow-900 border border-yellow-600 rounded-lg p-4 mb-6">
            <div class="flex items-center gap-3">
              <span class="text-2xl">⚠️</span>
              <div>
                <h3 class="text-yellow-300 font-semibold">Potential Bait Pilot</h3>
                <p class="text-yellow-400 text-sm"><%= @analysis.bait_indicators.bait_assessment %></p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Ship Loadouts -->
        <div class="bg-gray-800 rounded-lg p-6 mb-6">
          <h3 class="text-white font-semibold mb-4 flex items-center">
            🚀 Ship Loadouts
            <span class="ml-2 text-xs text-gray-500 font-normal">(from killmail data)</span>
          </h3>
          <%= if Enum.empty?(@analysis.ship_loadouts) do %>
            <p class="text-gray-500 italic">No ship loadout data available</p>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for ship <- @analysis.ship_loadouts do %>
                <div class="bg-gray-700 rounded-lg p-4">
                  <div class="flex items-center gap-3 mb-3">
                    <img
                      src={"https://images.evetech.net/types/#{ship.ship_type_id}/icon?size=32"}
                      alt={ship.ship_name}
                      class="w-8 h-8 rounded"
                    />
                    <div>
                      <div class="text-white font-medium"><%= ship.ship_name %></div>
                      <div class="text-xs">
                        <span class="text-green-400"><%= ship.total_kills %> kills</span>
                        <span class="text-gray-500 mx-1">/</span>
                        <span class="text-red-400"><%= ship.total_deaths %> deaths</span>
                      </div>
                    </div>
                  </div>
                  <%= if Enum.empty?(ship.weapons) do %>
                    <p class="text-gray-500 text-sm italic">No weapon data recorded</p>
                  <% else %>
                    <div class="space-y-1">
                      <%= for weapon <- ship.weapons do %>
                        <div class="flex justify-between items-center text-sm">
                          <span class="text-gray-300 truncate" title={weapon.weapon_name}>
                            <%= weapon.weapon_name %>
                          </span>
                          <span class="text-blue-400 ml-2 whitespace-nowrap">
                            <%= weapon.usage_count %>x
                          </span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Two column layout for Known Associates and Hunting Grounds -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <!-- Known Associates -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              👥 Known Associates
              <span class="ml-2 text-xs text-gray-500 font-normal">(frequent allies)</span>
            </h3>
            <%= if @analysis.known_associates && @analysis.known_associates.associates != [] do %>
              <div class="space-y-2">
                <%= for associate <- Enum.take(@analysis.known_associates.associates, 8) do %>
                  <div class="flex items-center justify-between bg-gray-700 rounded px-3 py-2">
                    <div class="flex items-center gap-2">
                      <img
                        src={"https://images.evetech.net/characters/#{associate.character_id}/portrait?size=32"}
                        alt={associate.character_name}
                        class="w-6 h-6 rounded-full"
                      />
                      <a
                        href={"/character/#{associate.character_id}"}
                        class="text-blue-400 hover:text-blue-300 text-sm"
                      >
                        <%= associate.character_name || "Unknown" %>
                      </a>
                    </div>
                    <span class="text-gray-400 text-xs">
                      <%= associate.shared_kills %> times
                    </span>
                  </div>
                <% end %>
              </div>
              <%= if @analysis.known_associates.total_associates > 8 do %>
                <p class="text-gray-500 text-xs mt-2 italic">
                  + <%= @analysis.known_associates.total_associates - 8 %> more associates
                </p>
              <% end %>
            <% else %>
              <p class="text-gray-500 italic">No frequent associates found</p>
            <% end %>
          </div>

          <!-- Hunting Grounds -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🎯 Hunting Grounds
            </h3>
            <%= if @analysis.hunting_grounds && @analysis.hunting_grounds.top_systems != [] do %>
              <div class="mb-4">
                <div class="text-sm text-gray-400 mb-2">Primary Security:</div>
                <span class={"px-2 py-1 rounded text-sm font-medium #{security_badge_color(@analysis.hunting_grounds.primary_security)}"}>
                  <%= String.upcase(@analysis.hunting_grounds.primary_security || "unknown") %>
                </span>
              </div>
              <div class="text-sm text-gray-400 mb-2">Active Systems:</div>
              <div class="space-y-1">
                <%= for system <- Enum.take(@analysis.hunting_grounds.top_systems, 6) do %>
                  <div class="flex justify-between items-center text-sm">
                    <.link navigate={~p"/system/#{system.system_id}"} class={"hover:underline #{security_text_color(system.security_status)}"}>
                      <%= system.system_name %>
                      <span class="text-gray-500 text-xs">(<%= Float.round(system.security_status || 0.0, 1) %>)</span>
                    </.link>
                    <span class="text-gray-400">
                      <%= system.activity_count %> kills
                    </span>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500 italic">No hunting ground data available</p>
            <% end %>
          </div>
        </div>

        <!-- Two column layout for Target Selection and Fleet Size -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <!-- Target Selection Patterns -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🎯 Target Selection
            </h3>
            <%= if @analysis.target_selection && @analysis.target_selection.top_targets != [] do %>
              <div class="mb-4">
                <div class="flex justify-between items-center mb-2">
                  <span class="text-gray-400 text-sm">Avg Victim Value:</span>
                  <span class="text-yellow-400"><%= format_isk(@analysis.target_selection.avg_victim_value) %></span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-gray-400 text-sm">Target Assessment:</span>
                  <span class={target_assessment_color(@analysis.target_selection.target_assessment)}>
                    <%= @analysis.target_selection.target_assessment %>
                  </span>
                </div>
              </div>
              <div class="text-sm text-gray-400 mb-2">Preferred Targets:</div>
              <div class="space-y-1">
                <%= for target <- Enum.take(@analysis.target_selection.top_targets, 5) do %>
                  <div class="flex justify-between items-center text-sm bg-gray-700 rounded px-2 py-1">
                    <span class="text-gray-300"><%= target.ship_name %></span>
                    <span class="text-red-400"><%= target.kill_count %> kills</span>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500 italic">No target selection data available</p>
            <% end %>
          </div>

          <!-- Fleet Size Distribution -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              👨‍👩‍👧‍👦 Fleet Size Patterns
            </h3>
            <%= if @analysis.gang_size_patterns do %>
              <div class="space-y-3">
                <%= for {category, data} <- gang_size_display(@analysis.gang_size_patterns) do %>
                  <div>
                    <div class="flex justify-between items-center text-sm mb-1">
                      <span class="text-gray-300"><%= category %></span>
                      <span class="text-gray-400">
                        <%= data.count %> (<%= data.percentage %>%)
                      </span>
                    </div>
                    <div class="w-full bg-gray-700 rounded-full h-2">
                      <div
                        class={"#{gang_bar_color(category)} h-2 rounded-full"}
                        style={"width: #{data.percentage}%"}
                      ></div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500 italic">No fleet size data available</p>
            <% end %>
          </div>
        </div>

        <!-- Activity Timeline and Corp Context -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <!-- Activity Timeline -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              📅 Activity Timeline
              <span class="ml-2 text-xs text-gray-500 font-normal">(last 30 days)</span>
            </h3>
            <%= if @analysis.activity_timeline && @analysis.activity_timeline.timeline != [] do %>
              <div class="mb-4 grid grid-cols-2 gap-4">
                <div class="bg-gray-700 rounded p-3 text-center">
                  <div class="text-2xl font-bold text-green-400">
                    <%= @analysis.activity_timeline.week_kills %>
                  </div>
                  <div class="text-xs text-gray-400">Kills (7 days)</div>
                </div>
                <div class="bg-gray-700 rounded p-3 text-center">
                  <div class="text-2xl font-bold text-red-400">
                    <%= @analysis.activity_timeline.week_deaths %>
                  </div>
                  <div class="text-xs text-gray-400">Deaths (7 days)</div>
                </div>
              </div>
              <div class="text-sm">
                <div class="flex justify-between items-center mb-2">
                  <span class="text-gray-400">Activity Trend:</span>
                  <span class={activity_trend_color(@analysis.activity_timeline.activity_trend)}>
                    <%= @analysis.activity_timeline.activity_trend %>
                  </span>
                </div>
              </div>
              <!-- Mini activity chart -->
              <div class="flex items-end gap-1 h-16 mt-4">
                <%= for day <- Enum.take(@analysis.activity_timeline.timeline, 14) do %>
                  <div
                    class="flex-1 bg-blue-500 rounded-t opacity-75 hover:opacity-100"
                    style={"height: #{max(4, min(100, (day.kills + day.deaths) * 15))}%"}
                    title={"#{day.date}: #{day.kills} kills, #{day.deaths} deaths"}
                  ></div>
                <% end %>
              </div>
              <div class="text-xs text-gray-500 text-center mt-1">Last 14 days</div>
            <% else %>
              <p class="text-gray-500 italic">No activity timeline data available</p>
            <% end %>
          </div>

          <!-- Corp/Alliance Context -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🏢 Corp Context
            </h3>
            <%= if @analysis.corp_context do %>
              <div class="space-y-3">
                <div class="flex justify-between items-center">
                  <span class="text-gray-400">Active Corp Pilots:</span>
                  <span class="text-white font-medium">
                    <%= @analysis.corp_context.active_pilots %>
                  </span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-gray-400">Corp Kills (90d):</span>
                  <span class="text-green-400 font-medium">
                    <%= @analysis.corp_context.corp_kills %>
                  </span>
                </div>
                <div class="flex justify-between items-center">
                  <span class="text-gray-400">Corp Size Assessment:</span>
                  <span class={"font-medium #{corp_size_color(@analysis.corp_context.corp_size_assessment)}"}>
                    <%= @analysis.corp_context.corp_size_assessment %>
                  </span>
                </div>
                <%= if @analysis.corporation_id do %>
                  <div class="mt-4 pt-4 border-t border-gray-700">
                    <a
                      href={"/corporation/#{@analysis.corporation_id}"}
                      class="text-blue-400 hover:text-blue-300 text-sm"
                    >
                      View Full Corporation Analysis →
                    </a>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500 italic">No corp context data available</p>
            <% end %>
          </div>
        </div>

        <!-- External Groups -->
        <%= if @analysis.external_groups && @analysis.external_groups != [] do %>
          <div class="bg-gray-800 rounded-lg p-6 mb-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🔗 External Group Collaboration
              <span class="ml-2 text-xs text-gray-500 font-normal">(other corps/alliances they fly with)</span>
            </h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for group <- Enum.take(@analysis.external_groups, 6) do %>
                <div class="bg-gray-700 rounded-lg p-3">
                  <%= if group.alliance_id do %>
                    <.link navigate={~p"/alliance/#{group.alliance_id}"} class="font-medium text-white truncate block hover:text-blue-400 hover:underline">
                      <%= group.alliance_name || "Unknown Alliance" %>
                    </.link>
                    <div class="text-sm text-gray-400">Alliance</div>
                  <% else %>
                    <.link navigate={~p"/corporation/#{group.corporation_id}"} class="font-medium text-white truncate block hover:text-blue-400 hover:underline">
                      <%= group.corporation_name || "Unknown Corporation" %>
                    </.link>
                    <div class="text-sm text-gray-400">Corporation</div>
                  <% end %>
                  <div class="text-sm text-blue-400"><%= group.interaction_count %> engagements</div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Helper functions for display formatting

  defp security_badge_color(security) do
    case security do
      "highsec" -> "bg-green-700 text-green-200"
      "lowsec" -> "bg-yellow-700 text-yellow-200"
      "nullsec" -> "bg-red-700 text-red-200"
      "wormhole" -> "bg-purple-700 text-purple-200"
      _ -> "bg-gray-700 text-gray-200"
    end
  end

  defp security_text_color(sec_status) when is_number(sec_status) do
    cond do
      sec_status >= 0.5 -> "text-green-400"
      sec_status > 0.0 -> "text-yellow-400"
      sec_status > -0.5 -> "text-orange-400"
      true -> "text-red-400"
    end
  end

  defp security_text_color(_), do: "text-gray-400"

  defp target_assessment_color(assessment) do
    case assessment do
      "high_value_hunter" -> "text-red-400"
      "standard_pvp" -> "text-blue-400"
      "opportunist" -> "text-yellow-400"
      "ganker" -> "text-orange-400"
      # Legacy values
      "opportunistic" -> "text-yellow-400"
      "selective" -> "text-blue-400"
      "predatory" -> "text-red-400"
      "defensive" -> "text-green-400"
      _ -> "text-gray-400"
    end
  end

  defp gang_size_display(patterns) do
    total =
      Enum.reduce(patterns, 0, fn {_k, v}, acc ->
        count = if is_map(v), do: Map.get(v, :count, 0), else: 0
        acc + count
      end)

    categories = [
      {"Solo", Map.get(patterns, :solo, %{})},
      {"Small Gang (2-5)", Map.get(patterns, :small_gang, %{})},
      {"Medium Gang (6-15)", Map.get(patterns, :medium_gang, %{})},
      {"Large Gang (16-40)", Map.get(patterns, :large_gang, %{})},
      {"Fleet (40+)", Map.get(patterns, :fleet, %{})}
    ]

    for {name, data} <- categories do
      count = if is_map(data), do: Map.get(data, :count, 0), else: 0
      percentage = if total > 0, do: round(count / total * 100), else: 0
      {name, %{count: count, percentage: percentage}}
    end
  end

  defp gang_bar_color(category) do
    case category do
      "Solo" -> "bg-purple-500"
      "Small Gang (2-5)" -> "bg-blue-500"
      "Medium Gang (6-15)" -> "bg-green-500"
      "Large Gang (16-40)" -> "bg-yellow-500"
      "Fleet (40+)" -> "bg-red-500"
      _ -> "bg-gray-500"
    end
  end

  defp activity_trend_color(trend) do
    case trend do
      "increasing" -> "text-green-400"
      "stable" -> "text-blue-400"
      "decreasing" -> "text-yellow-400"
      "insufficient_data" -> "text-gray-400"
      "inactive" -> "text-red-400"
      _ -> "text-gray-400"
    end
  end

  defp corp_size_color(assessment) do
    case assessment do
      "large_active_corp" -> "text-red-400"
      "medium_active_corp" -> "text-yellow-400"
      "small_active_corp" -> "text-blue-400"
      "micro_corp" -> "text-green-400"
      "solo_corp" -> "text-purple-400"
      # Legacy values
      "large" -> "text-red-400"
      "medium" -> "text-yellow-400"
      "small" -> "text-blue-400"
      "solo" -> "text-purple-400"
      _ -> "text-gray-400"
    end
  end

  # Import formatting helpers
  defdelegate format_isk(value), to: DisplayFormatters
  defdelegate threat_level_color(score), to: DisplayFormatters
  defdelegate threat_level_bg(score), to: DisplayFormatters
end
