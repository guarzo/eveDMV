defmodule EveDmvWeb.CharacterAnalysisLive do
  @moduledoc """
  Live view for character combat analysis.

  MVP: Simple kill/death analysis with real data from killmails_raw table.
  This is our first real intelligence feature - no mock data!
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Platform.Cache.AnalysisCache
  alias EveDmvWeb.CharacterAnalysis.Components.CharacterHeaderComponent
  alias EveDmvWeb.CharacterAnalysis.Components.IntelligenceSummaryComponent
  alias EveDmvWeb.CharacterAnalysis.Components.StatisticsPanelComponent
  alias EveDmvWeb.CharacterAnalysis.Helpers.CharacterDataLoader
  alias EveDmvWeb.CharacterAnalysis.Helpers.DisplayFormatters

  require Logger

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @valid_tabs ~w(overview battles ships weapons activity)a

  @impl Phoenix.LiveView
  def mount(%{"character_id" => character_id}, _session, socket) do
    character_id = String.to_integer(character_id)

    # Subscribe to real-time updates when connected
    if connected?(socket) do
      subscribe_to_updates(character_id)
    end

    socket =
      socket
      |> assign(:character_id, character_id)
      |> init_socket_state()
      |> start_async_loads(character_id)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"character_id" => character_id_str}, _uri, socket) do
    character_id = String.to_integer(character_id_str)
    maybe_reload_character(character_id, socket)
  end

  # Same character - no reload needed
  defp maybe_reload_character(character_id, %{assigns: %{character_id: character_id}} = socket) do
    {:noreply, socket}
  end

  # Different character - unsubscribe from old, subscribe to new, and reload
  defp maybe_reload_character(character_id, socket) do
    old_character_id = socket.assigns.character_id

    # Update subscriptions for the new character
    if connected?(socket) do
      unsubscribe_from_updates(old_character_id)
      subscribe_to_updates(character_id)
    end

    socket =
      socket
      |> assign(:character_id, character_id)
      |> init_socket_state()
      |> start_async_loads(character_id)

    {:noreply, socket}
  end

  # Subscribe to PubSub topics for real-time updates
  defp subscribe_to_updates(character_id) do
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:updates")
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "character:#{character_id}")
  end

  # Unsubscribe from PubSub topics when changing characters
  defp unsubscribe_from_updates(character_id) do
    Phoenix.PubSub.unsubscribe(EveDmv.PubSub, "character:#{character_id}")
    # Keep intelligence:updates subscription as it's shared
  end

  # Initialize socket state - shared between mount and handle_params
  defp init_socket_state(socket) do
    socket
    |> assign(:active_tab, :overview)
    |> assign(:loading, true)
    |> assign(:error, nil)
    |> assign(:analysis, nil)
    |> assign(:intelligence, nil)
    |> assign(:associates, [])
    |> assign(:associates_count, 0)
    |> assign(:ship_loadouts, [])
    |> assign(:ship_loadouts_count, 0)
  end

  # Start all async data loads for a character
  defp start_async_loads(socket, character_id) do
    socket
    |> start_async(:analysis_data, fn -> fetch_analysis(character_id) end)
    |> start_async(:intelligence_data, fn -> fetch_intelligence(character_id) end)
  end

  # Fetch functions for async loading

  defp fetch_analysis(character_id) do
    # Return the map directly - Phoenix's start_async wraps it in {:ok, result}
    {:ok, analysis} =
      AnalysisCache.get_or_compute(
        AnalysisCache.char_analysis_key(character_id),
        fn -> CharacterDataLoader.analyze_character(character_id) end,
        :timer.minutes(10)
      )

    associates = get_associates_from_analysis(analysis)
    ship_loadouts = analysis.ship_loadouts || []

    %{
      analysis: analysis,
      associates: Enum.take(associates, 8),
      associates_count: length(associates),
      ship_loadouts: ship_loadouts,
      ship_loadouts_count: length(ship_loadouts)
    }
  end

  defp fetch_intelligence(character_id) do
    # Return the map directly - Phoenix's start_async wraps it in {:ok, result}
    {:ok, report} =
      EveDmv.Contexts.CharacterIntelligence.get_character_intelligence_report(character_id)

    %{intelligence: report}
  end

  # Extract associates list from analysis data
  defp get_associates_from_analysis(analysis) do
    case analysis.known_associates do
      %{associates: associates} when is_list(associates) ->
        associates

      _ ->
        []
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
      |> init_socket_state()
      |> start_async_loads(character_id)

    {:noreply, socket}
  end

  # Handle async completion for analysis data
  @impl Phoenix.LiveView
  def handle_async(:analysis_data, {:ok, result}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:analysis, result.analysis)
      |> assign(:associates, result.associates)
      |> assign(:associates_count, result.associates_count)
      |> assign(:ship_loadouts, result.ship_loadouts)
      |> assign(:ship_loadouts_count, result.ship_loadouts_count)

    {:noreply, socket}
  end

  def handle_async(:analysis_data, {:exit, reason}, socket) do
    error_message = format_async_error(reason)

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error, error_message)

    {:noreply, socket}
  end

  # Handle async completion for intelligence data
  @impl Phoenix.LiveView
  def handle_async(:intelligence_data, {:ok, result}, socket) do
    socket = assign(socket, :intelligence, result.intelligence)
    {:noreply, socket}
  end

  def handle_async(:intelligence_data, {:exit, _reason}, socket) do
    # Intelligence failure is non-critical, just leave it nil
    {:noreply, socket}
  end

  defp format_async_error(reason) do
    case reason do
      {exception, _stacktrace} when is_exception(exception) ->
        Exception.message(exception)

      reason when is_binary(reason) ->
        reason

      reason ->
        try do
          Exception.format_exit(reason)
        rescue
          _ -> inspect(reason)
        end
    end
  end

  # Handle real-time updates via PubSub - consolidated handler for character-specific updates
  @impl Phoenix.LiveView
  def handle_info({:intelligence_update, %{character_id: char_id}}, socket) do
    maybe_refresh_for_character(char_id, socket)
  end

  def handle_info({:character_update, %{character_id: char_id}}, socket) do
    maybe_refresh_for_character(char_id, socket)
  end

  def handle_info(_msg, socket) do
    # Catch-all for unhandled messages (including intelligence updates without character_id)
    {:noreply, socket}
  end

  # Only refresh if this update is for the character we're viewing
  defp maybe_refresh_for_character(
         char_id,
         %Phoenix.LiveView.Socket{assigns: %{character_id: char_id}} = socket
       ) do
    socket = start_async_loads(socket, char_id)
    {:noreply, socket}
  end

  defp maybe_refresh_for_character(_char_id, socket), do: {:noreply, socket}

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

        <!-- Bait Analysis Section (shows when score > 0 or is_likely_bait) -->
        <%= if @analysis.bait_indicators && (@analysis.bait_indicators.is_likely_bait || (@analysis.bait_indicators[:bait_score] || 0) >= 30) do %>
          <div class={bait_banner_class(@analysis.bait_indicators[:bait_score] || 0)}>
            <div class="flex items-start gap-4">
              <span class="text-2xl mt-1"><%= bait_icon(@analysis.bait_indicators[:bait_score] || 0) %></span>
              <div class="flex-1">
                <div class="flex justify-between items-center mb-2">
                  <h3 class={bait_title_class(@analysis.bait_indicators[:bait_score] || 0)}>
                    <%= @analysis.bait_indicators.bait_assessment %>
                  </h3>
                  <span class="text-white font-bold">
                    Score: <%= @analysis.bait_indicators[:bait_score] || 0 %>/100
                  </span>
                </div>
                <!-- Score progress bar -->
                <div class="w-full bg-gray-700 rounded-full h-2 mb-3">
                  <div
                    class={bait_progress_class(@analysis.bait_indicators[:bait_score] || 0)}
                    style={"width: #{min(@analysis.bait_indicators[:bait_score] || 0, 100)}%"}
                  ></div>
                </div>
                <!-- Contributing Factors -->
                <%= if @analysis.bait_indicators[:bait_factors] && length(@analysis.bait_indicators.bait_factors) > 0 do %>
                  <div class="text-sm text-gray-300 mb-2">Contributing Factors:</div>
                  <div class="space-y-1">
                    <%= for factor <- @analysis.bait_indicators.bait_factors do %>
                      <div class="flex justify-between items-center text-sm bg-black/20 rounded px-2 py-1">
                        <span class="text-gray-300"><%= factor.description %></span>
                        <span class="text-yellow-400">+<%= factor.contribution %></span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
                <!-- Key Stats -->
                <div class="grid grid-cols-2 md:grid-cols-4 gap-2 mt-3 text-xs">
                  <div class="bg-black/20 rounded px-2 py-1">
                    <span class="text-gray-400">Cheap Deaths:</span>
                    <span class="text-white ml-1"><%= @analysis.bait_indicators[:cheap_death_percentage] || 0 %>%</span>
                  </div>
                  <div class="bg-black/20 rounded px-2 py-1">
                    <span class="text-gray-400">Final Blows:</span>
                    <span class="text-white ml-1"><%= @analysis.bait_indicators[:final_blow_rate] || 0 %>%</span>
                  </div>
                  <div class="bg-black/20 rounded px-2 py-1">
                    <span class="text-gray-400">Trade Ratio:</span>
                    <span class="text-white ml-1"><%= @analysis.bait_indicators[:trade_ratio] || 0 %>:1</span>
                  </div>
                  <div class="bg-black/20 rounded px-2 py-1">
                    <span class="text-gray-400">Corp Kills:</span>
                    <span class="text-white ml-1"><%= @analysis.bait_indicators[:corp_kill_correlation] || 0 %>%</span>
                  </div>
                </div>
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
          <%= if @ship_loadouts_count == 0 do %>
            <p class="text-gray-500 italic">No ship loadout data available</p>
          <% else %>
            <div id="ship-loadouts" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div :for={ship <- @ship_loadouts} id={"loadout-#{ship.ship_type_id}"} class="bg-gray-700 rounded-lg p-4">
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
            <%= if @associates_count > 0 do %>
              <div id="known-associates" class="space-y-2">
                <div :for={associate <- @associates} id={"associates-#{associate.character_id}"} class="flex items-center justify-between bg-gray-700 rounded px-3 py-2">
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
              </div>
              <%= if @associates_count > 8 do %>
                <p class="text-gray-500 text-xs mt-2 italic">
                  + <%= @associates_count - 8 %> more associates
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
          <!-- Target Selection Patterns (Enhanced) -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h3 class="text-white font-semibold mb-4 flex items-center">
              🎯 Target Selection Patterns
            </h3>
            <%= if @analysis.target_selection && @analysis.target_selection.total_kills > 0 do %>
              <!-- Primary Assessment -->
              <div class="mb-4 p-3 bg-gray-700 rounded-lg">
                <div class="flex justify-between items-center">
                  <span class="text-gray-400 text-sm">Primary Pattern:</span>
                  <span class={"font-semibold #{target_assessment_color(@analysis.target_selection.target_assessment)}"}>
                    <%= humanize_target_assessment(@analysis.target_selection.target_assessment) %>
                  </span>
                </div>
                <div class="flex justify-between items-center mt-1">
                  <span class="text-gray-400 text-sm">Avg Victim Value:</span>
                  <span class="text-yellow-400"><%= format_isk(@analysis.target_selection.avg_victim_value) %></span>
                </div>
              </div>

              <!-- Security Space Breakdown -->
              <%= if @analysis.target_selection[:security_breakdown] do %>
                <div class="mb-4">
                  <div class="text-sm text-gray-400 mb-2">Hunting Ground:</div>
                  <div class="space-y-1">
                    <%= for {sec_type, data} <- security_breakdown_sorted(@analysis.target_selection.security_breakdown), data.percentage > 0 do %>
                      <div class="flex items-center gap-2">
                        <span class={"w-16 text-xs #{security_class_color(sec_type)}"}><%= humanize_sec_type(sec_type) %></span>
                        <div class="flex-1 bg-gray-700 rounded-full h-2">
                          <div class={"h-2 rounded-full #{security_bar_color(sec_type)}"} style={"width: #{data.percentage}%"}></div>
                        </div>
                        <span class="text-xs text-gray-400 w-12 text-right"><%= data.percentage %>%</span>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Kill Style Stats -->
              <div class="grid grid-cols-2 gap-2 mb-4 text-xs">
                <div class="bg-gray-700 rounded px-2 py-1">
                  <span class="text-gray-400">Solo Kills:</span>
                  <span class="text-green-400 ml-1"><%= @analysis.target_selection[:solo_percentage] || 0 %>%</span>
                </div>
                <div class="bg-gray-700 rounded px-2 py-1">
                  <span class="text-gray-400">Final Blows:</span>
                  <span class="text-blue-400 ml-1"><%= @analysis.target_selection[:final_blow_percentage] || 0 %>%</span>
                </div>
              </div>

              <!-- Top Targets -->
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
      # New multi-dimensional assessments
      "capital_hunter" -> "text-purple-400"
      "wormhole_hunter" -> "text-cyan-400"
      "industrial_hunter" -> "text-yellow-400"
      "highsec_ganker" -> "text-orange-400"
      "pod_hunter" -> "text-red-400"
      "solo_hunter" -> "text-green-400"
      "fleet_pvper" -> "text-blue-400"
      "elite_hunter" -> "text-red-400"
      "standard_combatant" -> "text-blue-400"
      "casual_pvper" -> "text-gray-300"
      "opportunist" -> "text-gray-400"
      "insufficient_data" -> "text-gray-500"
      # Legacy values
      "high_value_hunter" -> "text-red-400"
      "standard_pvp" -> "text-blue-400"
      "ganker" -> "text-orange-400"
      "opportunistic" -> "text-yellow-400"
      "selective" -> "text-blue-400"
      "predatory" -> "text-red-400"
      "defensive" -> "text-green-400"
      _ -> "text-gray-400"
    end
  end

  defp humanize_target_assessment(assessment) do
    case assessment do
      "capital_hunter" -> "Capital Hunter"
      "wormhole_hunter" -> "Wormhole Hunter"
      "industrial_hunter" -> "Industrial Hunter"
      "highsec_ganker" -> "Highsec Ganker"
      "pod_hunter" -> "Pod Hunter"
      "solo_hunter" -> "Solo Hunter"
      "fleet_pvper" -> "Fleet PvPer"
      "elite_hunter" -> "Elite Hunter"
      "standard_combatant" -> "Standard Combatant"
      "casual_pvper" -> "Casual PvPer"
      "opportunist" -> "Opportunist"
      "insufficient_data" -> "Insufficient Data"
      # Legacy values
      "high_value_hunter" -> "High Value Hunter"
      "standard_pvp" -> "Standard PvP"
      "ganker" -> "Ganker"
      _ -> String.capitalize(String.replace(assessment || "unknown", "_", " "))
    end
  end

  # Bait detection UI helpers
  defp bait_banner_class(score) do
    cond do
      score >= 70 -> "bg-red-900 border border-red-600 rounded-lg p-4 mb-6"
      score >= 50 -> "bg-orange-900 border border-orange-600 rounded-lg p-4 mb-6"
      score >= 30 -> "bg-yellow-900 border border-yellow-600 rounded-lg p-4 mb-6"
      true -> "bg-gray-800 border border-gray-600 rounded-lg p-4 mb-6"
    end
  end

  defp bait_title_class(score) do
    cond do
      score >= 70 -> "text-red-300 font-semibold"
      score >= 50 -> "text-orange-300 font-semibold"
      score >= 30 -> "text-yellow-300 font-semibold"
      true -> "text-gray-300 font-semibold"
    end
  end

  defp bait_progress_class(score) do
    cond do
      score >= 70 -> "h-2 rounded-full bg-red-500"
      score >= 50 -> "h-2 rounded-full bg-orange-500"
      score >= 30 -> "h-2 rounded-full bg-yellow-500"
      true -> "h-2 rounded-full bg-gray-500"
    end
  end

  defp bait_icon(score) do
    cond do
      score >= 70 -> "🚨"
      score >= 50 -> "⚠️"
      score >= 30 -> "⚡"
      true -> "ℹ️"
    end
  end

  # Security breakdown helpers for target selection
  defp security_breakdown_sorted(breakdown) do
    breakdown
    |> Enum.sort_by(fn {_k, v} -> -v.percentage end)
  end

  defp humanize_sec_type(sec_type) do
    case sec_type do
      :highsec -> "Highsec"
      :lowsec -> "Lowsec"
      :nullsec -> "Nullsec"
      :wormhole -> "W-Space"
      _ -> "Unknown"
    end
  end

  defp security_class_color(sec_type) do
    case sec_type do
      :highsec -> "text-green-400"
      :lowsec -> "text-yellow-400"
      :nullsec -> "text-red-400"
      :wormhole -> "text-purple-400"
      _ -> "text-gray-400"
    end
  end

  defp security_bar_color(sec_type) do
    case sec_type do
      :highsec -> "bg-green-500"
      :lowsec -> "bg-yellow-500"
      :nullsec -> "bg-red-500"
      :wormhole -> "bg-purple-500"
      _ -> "bg-gray-500"
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
