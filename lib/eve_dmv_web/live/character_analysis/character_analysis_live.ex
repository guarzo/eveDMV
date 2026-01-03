defmodule EveDmvWeb.CharacterAnalysisLive do
  @moduledoc """
  Live view for character combat analysis.

  MVP: Simple kill/death analysis with real data from killmails_raw table.
  This is our first real intelligence feature - no mock data!
  """

  use EveDmvWeb, :live_view

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  alias EveDmv.Analytics.BattleDetector
  alias EveDmv.Integrations.ShipIntelligenceBridge
  alias EveDmv.Platform.Cache.AnalysisCache
  alias EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader
  alias EveDmvWeb.CharacterAnalysis.Helpers.DisplayFormatters

  alias EveDmvWeb.CharacterAnalysis.Components.CharacterHeaderComponent
  alias EveDmvWeb.CharacterAnalysis.Components.IntelligenceSummaryComponent
  alias EveDmvWeb.CharacterAnalysis.Components.StatisticsPanelComponent

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
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
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

        <!-- Bottom row: Ships with Loadouts -->
        <div class="grid grid-cols-1 gap-6">
          <!-- Ship Loadouts - Shows weapons actually used per ship -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🚀 Ship Loadouts
              <span class="ml-2 text-xs text-gray-500 font-normal">(from killmail data)</span>
            </h3>
            <%= if Enum.empty?(@analysis.ship_loadouts) do %>
              <p class="text-gray-500 italic">No ship loadout data available</p>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
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
        </div>
      <% end %>
    </div>
    """
  end

  # Import formatting helpers
  defdelegate format_isk(value), to: DisplayFormatters
  defdelegate threat_level_color(score), to: DisplayFormatters
  defdelegate threat_level_bg(score), to: DisplayFormatters
end
