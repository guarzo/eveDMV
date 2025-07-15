defmodule EveDmvWeb.CharacterAnalysisLive do
  @moduledoc """
  Live view for character combat analysis.

  MVP: Simple kill/death analysis with real data from killmails_raw table.
  This is our first real intelligence feature - no mock data!
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Cache.AnalysisCache
  alias EveDmv.Contexts.CharacterIntelligence
  alias EveDmv.Analytics.BattleDetector
  alias EveDmv.Integrations.ShipIntelligenceBridge
  alias EveDmvWeb.CharacterAnalysis.Helpers.{CharacterDataLoader, DisplayFormatters}

  alias EveDmvWeb.CharacterAnalysis.Components.{
    CharacterHeaderComponent,
    IntelligenceSummaryComponent,
    StatisticsPanelComponent,
    ActivityFeedComponent
  }

  require Logger

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
        CharacterIntelligence.get_character_intelligence_report(character_id)
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

    case basic_analysis_result do
      {:ok, analysis} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:analysis, analysis)
          |> assign(:intelligence, intelligence_result)
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
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
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
          
          <.live_component
            module={ActivityFeedComponent}
            id="activity-feed"
            analysis={@analysis}
          />
          
          <!-- Additional components would go here -->
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
