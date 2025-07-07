defmodule EveDmvWeb.BattleAnalysisLive do
  @moduledoc """
  LiveView for battle analysis and tactical intelligence.

  Provides real-time battle analysis, fleet composition breakdowns,
  tactical recommendations, and historical battle comparisons.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysisService
  alias EveDmvWeb.Components.BattleTimelineComponent
  alias EveDmvWeb.Helpers.TimeFormatter
  alias Phoenix.PubSub

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    battle_id = Map.get(params, "battle_id")

    # Subscribe to battle analysis updates
    if connected?(socket) do
      PubSub.subscribe(EveDmv.PubSub, "battle_analysis:updates")

      if battle_id do
        PubSub.subscribe(EveDmv.PubSub, "battle:#{battle_id}")
      end
    end

    socket =
      socket
      |> assign(:page_title, "Battle Analysis")
      |> assign(:battle_id, battle_id)
      |> assign(:battle_analysis, nil)
      |> assign(:timeline_data, nil)
      |> assign(:recommendations, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:view_mode, :overview)
      |> assign(:selected_side, nil)
      |> assign(:comparison_battles, [])
      |> assign(:live_engagements, %{})

    if battle_id do
      load_battle_analysis(socket, battle_id)
    else
      socket
      |> assign(:loading, false)
      |> load_recent_battles()
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    battle_id = Map.get(params, "battle_id")

    socket =
      if battle_id && battle_id != socket.assigns.battle_id do
        socket
        |> assign(:battle_id, battle_id)
        |> load_battle_analysis(battle_id)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="battle-analysis-page">
      <div class="page-header mb-6">
        <h1 class="text-2xl font-bold">Battle Analysis</h1>
        <p class="text-gray-400">Advanced tactical intelligence and engagement analytics</p>
      </div>

      <%= if @loading do %>
        <div class="flex justify-center items-center h-64">
          <div class="loading-spinner"></div>
        </div>
      <% else %>
        <%= if @battle_id && @battle_analysis do %>
          <!-- Single Battle Analysis View -->
          <div class="battle-analysis-container">
            <!-- View mode tabs -->
            <div class="view-tabs mb-6">
              <div class="flex gap-2">
                <button
                  class={tab_class(@view_mode == :overview)}
                  phx-click="set_view_mode"
                  phx-value-mode="overview"
                >
                  Overview
                </button>
                <button
                  class={tab_class(@view_mode == :timeline)}
                  phx-click="set_view_mode"
                  phx-value-mode="timeline"
                >
                  Timeline
                </button>
                <button
                  class={tab_class(@view_mode == :fleets)}
                  phx-click="set_view_mode"
                  phx-value-mode="fleets"
                >
                  Fleet Analysis
                </button>
                <button
                  class={tab_class(@view_mode == :tactical)}
                  phx-click="set_view_mode"
                  phx-value-mode="tactical"
                >
                  Tactical Analysis
                </button>
                <button
                  class={tab_class(@view_mode == :recommendations)}
                  phx-click="set_view_mode"
                  phx-value-mode="recommendations"
                >
                  Recommendations
                </button>
              </div>
            </div>

            <!-- Content based on view mode -->
            <div class="view-content">
              <%= case @view_mode do %>
                <% :overview -> %>
                  <%= render_overview(assigns) %>
                <% :timeline -> %>
                  <%= render_timeline_view(assigns) %>
                <% :fleets -> %>
                  <%= render_fleet_analysis(assigns) %>
                <% :tactical -> %>
                  <%= render_tactical_analysis(assigns) %>
                <% :recommendations -> %>
                  <%= render_recommendations(assigns) %>
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- Battle List / Live Engagements View -->
          <%= render_battle_list(assigns) %>
        <% end %>
      <% end %>
    </div>
    """
  end

  # View renderers

  defp render_overview(assigns) do
    ~H"""
    <div class="battle-overview">
      <!-- Battle summary card -->
      <div class="mb-6">
        <BattleTimelineComponent.battle_summary_card
          battle_analysis={@battle_analysis}
          show_recommendations={false}
        />
      </div>

      <!-- Key metrics grid -->
      <div class="metrics-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <%= render_metric_card("Total Kills", @battle_analysis.total_kills, "kills") %>
        <%= render_metric_card("Participants", @battle_analysis.total_participants, "pilots") %>
        <%= render_metric_card("ISK Destroyed", format_isk(@battle_analysis.isk_destroyed), "") %>
        <%= render_metric_card("Duration", format_duration(@battle_analysis.duration_seconds), "") %>
      </div>

      <!-- Side performance comparison -->
      <div class="side-comparison mb-6">
        <h3 class="text-lg font-semibold mb-4">Side Performance</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for {side, performance} <- @battle_analysis.side_performance do %>
            <div class="side-performance-card bg-gray-800 rounded p-4">
              <h4 class="text-md font-semibold mb-3"><%= format_side(side) %></h4>

              <div class="performance-stats space-y-2">
                <div class="stat-row flex justify-between">
                  <span class="text-gray-400">Kills</span>
                  <span class="font-semibold"><%= performance.kills %></span>
                </div>
                <div class="stat-row flex justify-between">
                  <span class="text-gray-400">Losses</span>
                  <span class="font-semibold"><%= performance.losses %></span>
                </div>
                <div class="stat-row flex justify-between">
                  <span class="text-gray-400">K/D Ratio</span>
                  <span class="font-semibold text-green-400">
                    <%= Float.round(performance.k_d_ratio, 2) %>
                  </span>
                </div>
                <div class="stat-row flex justify-between">
                  <span class="text-gray-400">ISK Efficiency</span>
                  <span class="font-semibold">
                    <%= format_percentage(performance.efficiency) %>
                  </span>
                </div>
              </div>

              <button
                class="mt-3 text-sm text-blue-400 hover:text-blue-300"
                phx-click="view_side_details"
                phx-value-side={side}
              >
                View Fleet Details →
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Top performers -->
      <%= if @battle_analysis.top_performers do %>
        <div class="top-performers">
          <h3 class="text-lg font-semibold mb-4">Top Performers</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for performer <- Enum.take(@battle_analysis.top_performers, 6) do %>
              <div class="performer-card bg-gray-800 rounded p-3 flex items-center gap-3">
                <div class="flex-1">
                  <p class="font-semibold"><%= performer.character_name || "Unknown" %></p>
                  <p class="text-sm text-gray-400"><%= performer.corporation_name || "Unknown" %></p>
                </div>
                <div class="text-right">
                  <p class="text-lg font-bold text-green-400"><%= performer.kills %></p>
                  <p class="text-xs text-gray-400">kills</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_timeline_view(assigns) do
    ~H"""
    <div class="timeline-view">
      <%= if @timeline_data do %>
        <BattleTimelineComponent.battle_timeline
          timeline_data={@timeline_data}
          height="500"
          interactive={true}
        />
      <% else %>
        <div class="loading-timeline flex justify-center items-center h-64">
          <p class="text-gray-500">Loading timeline data...</p>
        </div>
      <% end %>

      <!-- Battle phases breakdown -->
      <%= if @battle_analysis.phases do %>
        <div class="battle-phases mt-6">
          <h3 class="text-lg font-semibold mb-4">Battle Phases</h3>
          <div class="phases-list space-y-3">
            <%= for phase <- @battle_analysis.phases do %>
              <div class="phase-card bg-gray-800 rounded p-4">
                <div class="flex justify-between items-start mb-2">
                  <h4 class="font-semibold"><%= phase.name %></h4>
                  <span class="text-sm text-gray-400">
                    <%= format_duration(phase.duration) %>
                  </span>
                </div>
                <p class="text-sm text-gray-300"><%= phase.description %></p>
                <div class="phase-stats flex gap-4 mt-2 text-sm">
                  <span>Kills: <strong><%= phase.kill_count %></strong></span>
                  <span>Intensity: <strong class={intensity_color(phase.intensity)}>
                    <%= phase.intensity %>
                  </strong></span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_fleet_analysis(assigns) do
    ~H"""
    <div class="fleet-analysis">
      <!-- Side selector -->
      <div class="side-selector mb-6">
        <div class="flex gap-2">
          <%= for {side, _comp} <- @battle_analysis.fleet_compositions do %>
            <button
              class={side_button_class(@selected_side == side)}
              phx-click="select_side"
              phx-value-side={side}
            >
              <%= format_side(side) %>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Fleet composition for selected side -->
      <%= if @selected_side && @battle_analysis.fleet_compositions[@selected_side] do %>
        <BattleTimelineComponent.fleet_composition_breakdown
          fleet_analysis={@battle_analysis.fleet_compositions[@selected_side]}
          side={@selected_side}
        />
      <% else %>
        <div class="text-center text-gray-500 py-8">
          Select a side to view fleet composition
        </div>
      <% end %>

      <!-- Ship class effectiveness comparison -->
      <%= if @battle_analysis.ship_class_effectiveness do %>
        <div class="ship-effectiveness mt-6">
          <h3 class="text-lg font-semibold mb-4">Ship Class Effectiveness</h3>
          <div class="effectiveness-chart bg-gray-800 rounded p-4">
            <%= render_ship_effectiveness_chart(@battle_analysis.ship_class_effectiveness) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_tactical_analysis(assigns) do
    ~H"""
    <div class="tactical-analysis">
      <!-- Key moments -->
      <%= if @battle_analysis.key_moments do %>
        <div class="key-moments mb-6">
          <h3 class="text-lg font-semibold mb-4">Key Moments</h3>
          <div class="moments-timeline space-y-3">
            <%= for moment <- @battle_analysis.key_moments do %>
              <div class="moment-card bg-gray-800 rounded p-4 border-l-4 border-yellow-500">
                <div class="flex justify-between items-start mb-2">
                  <h4 class="font-semibold"><%= moment.description %></h4>
                  <span class="text-sm text-gray-400">
                    <%= format_timestamp(moment.timestamp) %>
                  </span>
                </div>
                <p class="text-sm text-gray-300"><%= moment.impact %></p>
                <%= if moment.involved_pilots do %>
                  <div class="involved-pilots mt-2 flex gap-2 flex-wrap">
                    <%= for pilot <- Enum.take(moment.involved_pilots, 3) do %>
                      <span class="text-xs bg-gray-700 rounded px-2 py-1">
                        <%= pilot %>
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Tactical patterns -->
      <%= if @battle_analysis.tactical_patterns do %>
        <div class="tactical-patterns mb-6">
          <h3 class="text-lg font-semibold mb-4">Tactical Patterns Identified</h3>
          <div class="patterns-grid grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for pattern <- @battle_analysis.tactical_patterns do %>
              <div class="pattern-card bg-gray-800 rounded p-4">
                <h4 class="font-semibold mb-2 text-blue-400">
                  <%= format_pattern_name(pattern.type) %>
                </h4>
                <p class="text-sm text-gray-300 mb-2"><%= pattern.description %></p>
                <div class="pattern-stats text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-400">Occurrences</span>
                    <span><%= pattern.count %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Effectiveness</span>
                    <span class={effectiveness_color(pattern.effectiveness)}>
                      <%= format_percentage(pattern.effectiveness * 100) %>
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Victory factors -->
      <div class="victory-analysis">
        <h3 class="text-lg font-semibold mb-4">Victory Analysis</h3>
        <div class="bg-gray-800 rounded p-4">
          <div class="winner mb-4">
            <p class="text-sm text-gray-400">Battle Winner</p>
            <p class="text-xl font-bold">
              <%= format_winner(@battle_analysis.winner) %>
            </p>
          </div>

          <%= if @battle_analysis.victory_factors do %>
            <div class="factors">
              <p class="text-sm text-gray-400 mb-2">Contributing Factors</p>
              <div class="flex flex-wrap gap-2">
                <%= for factor <- @battle_analysis.victory_factors do %>
                  <span class="bg-green-900 text-green-300 text-sm rounded px-3 py-1">
                    <%= format_victory_factor(factor) %>
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_recommendations(assigns) do
    ~H"""
    <div class="recommendations-view">
      <%= if @recommendations do %>
        <!-- Tactical recommendations -->
        <div class="tactical-recommendations mb-6">
          <h3 class="text-lg font-semibold mb-4">Tactical Recommendations</h3>
          <div class="recommendations-list space-y-3">
            <%= for rec <- @recommendations.tactical do %>
              <div class="recommendation-card bg-gray-800 rounded p-4">
                <div class="flex gap-3">
                  <div class="rec-icon text-2xl">💡</div>
                  <div class="flex-1">
                    <h4 class="font-semibold mb-1"><%= rec.title %></h4>
                    <p class="text-sm text-gray-300"><%= rec.description %></p>
                    <%= if rec.priority do %>
                      <span class={priority_badge_class(rec.priority)}>
                        <%= rec.priority %>
                      </span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Strategic recommendations -->
        <div class="strategic-recommendations mb-6">
          <h3 class="text-lg font-semibold mb-4">Strategic Recommendations</h3>
          <div class="recommendations-list space-y-3">
            <%= for rec <- @recommendations.strategic do %>
              <div class="recommendation-card bg-gray-800 rounded p-4">
                <div class="flex gap-3">
                  <div class="rec-icon text-2xl">🎯</div>
                  <div class="flex-1">
                    <h4 class="font-semibold mb-1"><%= rec.title %></h4>
                    <p class="text-sm text-gray-300"><%= rec.description %></p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Doctrine recommendations -->
        <%= if @recommendations.doctrine && length(@recommendations.doctrine) > 0 do %>
          <div class="doctrine-recommendations">
            <h3 class="text-lg font-semibold mb-4">Doctrine Adjustments</h3>
            <div class="doctrine-cards grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for rec <- @recommendations.doctrine do %>
                <div class="doctrine-card bg-gray-800 rounded p-4">
                  <h4 class="font-semibold mb-2 text-yellow-400"><%= rec.doctrine_name %></h4>
                  <p class="text-sm text-gray-300 mb-2"><%= rec.adjustment %></p>
                  <div class="expected-improvement text-sm">
                    <span class="text-gray-400">Expected Improvement:</span>
                    <span class="text-green-400 font-semibold">
                      +<%= format_percentage(rec.improvement * 100) %>
                    </span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="generating-recommendations flex flex-col items-center justify-center h-64">
          <div class="loading-spinner mb-4"></div>
          <p class="text-gray-500">Generating tactical recommendations...</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_battle_list(assigns) do
    ~H"""
    <div class="battle-list-view">
      <!-- Live engagements -->
      <%= if map_size(@live_engagements) > 0 do %>
        <div class="live-engagements mb-8">
          <h2 class="text-xl font-semibold mb-4 flex items-center gap-2">
            <span class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></span>
            Live Engagements
          </h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for {system_id, engagement} <- @live_engagements do %>
              <div class="engagement-card bg-gray-800 rounded p-4 border border-red-500 border-opacity-50">
                <div class="flex justify-between items-start mb-2">
                  <h3 class="font-semibold">System <%= system_id %></h3>
                  <span class="text-xs bg-red-900 text-red-300 rounded px-2 py-1">
                    <%= engagement.status %>
                  </span>
                </div>
                <div class="engagement-stats text-sm space-y-1">
                  <div class="flex justify-between">
                    <span class="text-gray-400">Participants</span>
                    <span><%= engagement.participant_count %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Kills</span>
                    <span><%= engagement.kill_count %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-400">Duration</span>
                    <span><%= format_duration(engagement.duration_seconds) %></span>
                  </div>
                </div>
                <button
                  class="mt-3 w-full bg-red-600 hover:bg-red-700 text-white rounded py-2 text-sm"
                  phx-click="analyze_live_engagement"
                  phx-value-system={system_id}
                >
                  Analyze Engagement
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Recent battles -->
      <div class="recent-battles">
        <h2 class="text-xl font-semibold mb-4">Recent Battles</h2>

        <%= if @recent_battles && length(@recent_battles) > 0 do %>
          <div class="battles-table">
            <table class="w-full">
              <thead>
                <tr class="text-left border-b border-gray-700">
                  <th class="pb-2">Time</th>
                  <th class="pb-2">Type</th>
                  <th class="pb-2">Participants</th>
                  <th class="pb-2">ISK Destroyed</th>
                  <th class="pb-2">Duration</th>
                  <th class="pb-2"></th>
                </tr>
              </thead>
              <tbody>
                <%= for battle <- @recent_battles do %>
                  <tr class="border-b border-gray-800 hover:bg-gray-800">
                    <td class="py-3">
                      <%= format_relative_time(battle.timestamp) %>
                    </td>
                    <td class="py-3">
                      <span class={scale_color_class(battle.scale)}>
                        <%= format_scale(battle.scale) %>
                      </span>
                    </td>
                    <td class="py-3"><%= battle.participant_count %></td>
                    <td class="py-3"><%= format_isk(battle.isk_destroyed) %></td>
                    <td class="py-3"><%= format_duration(battle.duration) %></td>
                    <td class="py-3 text-right">
                      <.link
                        navigate={~p"/battle/#{battle.id}"}
                        class="text-blue-400 hover:text-blue-300"
                      >
                        Analyze →
                      </.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="no-battles text-center py-8 text-gray-500">
            No recent battles found
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Event handlers

  @impl Phoenix.LiveView
  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_existing_atom(mode))}
  end

  @impl Phoenix.LiveView
  def handle_event("select_side", %{"side" => side}, socket) do
    {:noreply, assign(socket, :selected_side, String.to_existing_atom(side))}
  end

  @impl Phoenix.LiveView
  def handle_event("view_side_details", %{"side" => side}, socket) do
    socket =
      socket
      |> assign(:view_mode, :fleets)
      |> assign(:selected_side, String.to_existing_atom(side))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("analyze_live_engagement", %{"system" => system_id}, socket) do
    case BattleAnalysisService.analyze_live_engagement(String.to_integer(system_id)) do
      {:ok, analysis} ->
        # Create a temporary battle ID for the live engagement
        temp_battle_id = "live_#{system_id}_#{:os.system_time(:second)}"

        socket =
          socket
          |> assign(:battle_id, temp_battle_id)
          |> assign(:battle_analysis, analysis)
          |> assign(:view_mode, :overview)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to analyze engagement: #{reason}")}
    end
  end

  # PubSub handlers

  @impl Phoenix.LiveView
  def handle_info({:battle_analysis_complete, battle_id}, socket) do
    if socket.assigns.battle_id == battle_id do
      {:noreply, load_battle_analysis(socket, battle_id)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:live_engagement_update, engagement}, socket) do
    live_engagements =
      Map.put(
        socket.assigns.live_engagements,
        engagement.system_id,
        engagement
      )

    {:noreply, assign(socket, :live_engagements, live_engagements)}
  end

  # Private functions

  defp load_battle_analysis(socket, battle_id) do
    socket = assign(socket, :loading, true)

    case BattleAnalysisService.analyze_battle(battle_id) do
      {:ok, analysis} ->
        # Load timeline data
        timeline_task =
          Task.async(fn ->
            BattleAnalysisService.get_battle_timeline(battle_id)
          end)

        # Load recommendations
        recommendations_task =
          Task.async(fn ->
            BattleAnalysisService.generate_tactical_recommendations(analysis)
          end)

        timeline_data =
          case Task.await(timeline_task, 5000) do
            {:ok, data} -> data
            _ -> nil
          end

        recommendations =
          case Task.await(recommendations_task, 5000) do
            {:ok, recs} -> recs
            _ -> nil
          end

        socket
        |> assign(:loading, false)
        |> assign(:battle_analysis, analysis)
        |> assign(:timeline_data, timeline_data)
        |> assign(:recommendations, recommendations)
        |> assign(:error, nil)

      {:error, reason} ->
        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load battle analysis: #{reason}")
    end
  end

  defp load_recent_battles(socket) do
    # This would load recent battles from the database
    # Mock implementation for now
    recent_battles = [
      %{
        id: "battle_001",
        timestamp: DateTime.add(DateTime.utc_now(), -3600, :second),
        scale: :fleet,
        participant_count: 47,
        isk_destroyed: 2_450_000_000,
        duration: 1200
      },
      %{
        id: "battle_002",
        timestamp: DateTime.add(DateTime.utc_now(), -7200, :second),
        scale: :small_gang,
        participant_count: 12,
        isk_destroyed: 450_000_000,
        duration: 600
      }
    ]

    assign(socket, :recent_battles, recent_battles)
  end

  # UI helper functions

  defp tab_class(active) do
    base = "px-4 py-2 rounded transition-colors"

    if active do
      "#{base} bg-blue-600 text-white"
    else
      "#{base} bg-gray-800 text-gray-400 hover:bg-gray-700 hover:text-white"
    end
  end

  defp side_button_class(active) do
    base = "px-6 py-2 rounded transition-colors"

    if active do
      "#{base} bg-blue-600 text-white"
    else
      "#{base} bg-gray-800 text-gray-400 hover:bg-gray-700 hover:text-white"
    end
  end

  defp render_metric_card(label, value, unit) do
    assigns = %{label: label, value: value, unit: unit}

    ~H"""
    <div class="metric-card bg-gray-800 rounded p-4">
      <p class="text-sm text-gray-400 mb-1"><%= @label %></p>
      <p class="text-2xl font-bold">
        <%= @value %>
        <%= if @unit != "" do %>
          <span class="text-lg text-gray-400"><%= @unit %></span>
        <% end %>
      </p>
    </div>
    """
  end

  defp render_ship_effectiveness_chart(effectiveness_data) do
    assigns = %{data: effectiveness_data}

    ~H"""
    <div class="effectiveness-bars space-y-3">
      <%= for {ship_class, stats} <- @data do %>
        <div class="ship-class-effectiveness">
          <div class="flex justify-between text-sm mb-1">
            <span><%= format_ship_class(ship_class) %></span>
            <span>
              K/D: <strong class={kd_color(stats.kd_ratio)}><%= Float.round(stats.kd_ratio, 2) %></strong>
            </span>
          </div>
          <div class="effectiveness-bar w-full bg-gray-700 rounded-full h-2">
            <div
              class="h-2 rounded-full bg-gradient-to-r from-red-500 to-green-500"
              style={"width: #{stats.effectiveness * 100}%"}
            ></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Formatting helpers

  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{trunc(value)}"
    end
  end

  defp format_isk(_), do: "0"

  defp format_duration(seconds) when is_number(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end

  defp format_duration(_), do: "0s"

  defp format_side(side) do
    case side do
      :side_a -> "Alpha Force"
      :side_b -> "Bravo Force"
      _ -> "Unknown"
    end
  end

  defp format_winner(winner) do
    case winner do
      {:side, side} -> format_side(side)
      :undetermined -> "Undetermined"
      _ -> "Unknown"
    end
  end

  defp format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end

  defp format_percentage(_), do: "0%"

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%H:%M:%S")
  end

  defp format_relative_time(timestamp),
    do: TimeFormatter.format_relative_time(timestamp)

  defp format_scale(scale) do
    case scale do
      :skirmish -> "Skirmish"
      :small_gang -> "Small Gang"
      :medium_gang -> "Medium Gang"
      :fleet -> "Fleet"
      :large_fleet -> "Large Fleet"
      :massive_battle -> "Massive"
      _ -> "Unknown"
    end
  end

  defp scale_color_class(scale) do
    case scale do
      :skirmish -> "text-gray-400"
      :small_gang -> "text-blue-400"
      :medium_gang -> "text-green-400"
      :fleet -> "text-yellow-400"
      :large_fleet -> "text-orange-400"
      :massive_battle -> "text-red-400"
      _ -> "text-gray-400"
    end
  end

  defp intensity_color(intensity) do
    case intensity do
      :extreme -> "text-red-500"
      :high -> "text-orange-500"
      :moderate -> "text-yellow-500"
      :low -> "text-green-500"
      _ -> "text-gray-500"
    end
  end

  defp effectiveness_color(effectiveness) when is_number(effectiveness) do
    cond do
      effectiveness >= 0.8 -> "text-green-400"
      effectiveness >= 0.6 -> "text-yellow-400"
      effectiveness >= 0.4 -> "text-orange-400"
      true -> "text-red-400"
    end
  end

  defp effectiveness_color(_), do: "text-gray-400"

  defp kd_color(ratio) when is_number(ratio) do
    cond do
      ratio >= 2.0 -> "text-green-400"
      ratio >= 1.0 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end

  defp kd_color(_), do: "text-gray-400"

  defp format_pattern_name(pattern_type) do
    pattern_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_victory_factor(factor) do
    case factor do
      :superior_numbers ->
        "Superior Numbers"

      :better_composition ->
        "Better Fleet Composition"

      :tactical_execution ->
        "Superior Tactics"

      :logistics_advantage ->
        "Logistics Advantage"

      :focus_fire ->
        "Focus Fire Discipline"

      _ ->
        factor
        |> to_string()
        |> String.replace("_", " ")
        |> String.capitalize()
    end
  end

  defp format_ship_class(class) do
    class
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp priority_badge_class(priority) do
    base = "inline-block px-2 py-1 text-xs rounded mt-2"

    case priority do
      :critical -> "#{base} bg-red-900 text-red-300"
      :high -> "#{base} bg-orange-900 text-orange-300"
      :medium -> "#{base} bg-yellow-900 text-yellow-300"
      :low -> "#{base} bg-gray-700 text-gray-300"
      _ -> "#{base} bg-gray-700 text-gray-300"
    end
  end
end
