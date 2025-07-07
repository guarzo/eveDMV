defmodule EveDmvWeb.Components.BattleTimelineComponent do
  use Phoenix.Component

  alias Phoenix.HTML
  @moduledoc """
  Battle timeline visualization component for EVE DMV.

  Displays engagement timelines with interactive features:
  - Kill event markers with hover details
  - Intensity visualization over time
  - Phase identification and markers
  - Fleet composition changes
  - Key moment highlights
  """


  @doc """
  Renders a battle timeline visualization.

  ## Props
  - timeline_data: Battle timeline data from BattleAnalysisService
  - height: Height of the timeline (default: 400px)
  - interactive: Enable interactive features (default: true)
  """
  attr :timeline_data, :map, required: true
  attr :height, :string, default: "400"
  attr :interactive, :boolean, default: true
  attr :class, :string, default: ""

  def battle_timeline(assigns) do
    ~H"""
    <div class={["battle-timeline-container", @class]}>
      <div class="timeline-header mb-4">
        <h3 class="text-lg font-semibold">Battle Timeline</h3>
        <div class="timeline-stats flex gap-4 text-sm text-gray-400">
          <span>Duration: <%= format_duration(@timeline_data.duration) %></span>
          <span>Events: <%= length(@timeline_data.events) %></span>
        </div>
      </div>

      <div class="timeline-visualization" style={"height: #{@height}px"}>
        <%= if length(@timeline_data.events) > 0 do %>
          <div class="timeline-chart relative">
            <!-- Intensity curve background -->
            <div class="intensity-layer absolute inset-0">
              <%= render_intensity_curve(assigns) %>
            </div>

            <!-- Timeline axis -->
            <div class="timeline-axis absolute bottom-0 left-0 right-0 h-8 border-t border-gray-700">
              <%= render_time_axis(assigns) %>
            </div>

            <!-- Event markers -->
            <div class="event-layer absolute inset-0">
              <%= for {event, index} <- Enum.with_index(@timeline_data.events) do %>
                <%= render_event_marker(event, index, assigns) %>
              <% end %>
            </div>

            <!-- Phase markers -->
            <%= if Map.get(@timeline_data, :phases) do %>
              <div class="phase-layer absolute inset-0">
                <%= for phase <- @timeline_data.phases do %>
                  <%= render_phase_marker(phase, assigns) %>
                <% end %>
              </div>
            <% end %>

            <!-- Key moments -->
            <%= if Map.get(@timeline_data, :key_moments) do %>
              <div class="key-moments-layer absolute inset-0">
                <%= for moment <- @timeline_data.key_moments do %>
                  <%= render_key_moment(moment, assigns) %>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Legend -->
          <div class="timeline-legend mt-4 flex gap-4 text-sm">
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full bg-red-500"></div>
              <span class="text-gray-400">Kill</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
              <span class="text-gray-400">Key Moment</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 bg-blue-500 opacity-30"></div>
              <span class="text-gray-400">Battle Phase</span>
            </div>
          </div>
        <% else %>
          <div class="no-timeline-data flex items-center justify-center h-full">
            <p class="text-gray-500">No timeline data available</p>
          </div>
        <% end %>
      </div>

      <!-- Participant flow visualization -->
      <%= if Map.get(@timeline_data, :participant_flow) do %>
        <div class="participant-flow mt-6">
          <h4 class="text-md font-semibold mb-2">Participant Flow</h4>
          <%= render_participant_flow(@timeline_data.participant_flow) %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a compact battle summary card.
  """
  attr :battle_analysis, :map, required: true
  attr :show_recommendations, :boolean, default: false
  attr :class, :string, default: ""

  def battle_summary_card(assigns) do
    ~H"""
    <div class={["battle-summary-card bg-gray-800 rounded p-4", @class]}>
      <div class="summary-header flex justify-between items-start mb-4">
        <div>
          <h3 class="text-lg font-semibold">
            <%= format_battle_type(@battle_analysis.battle_type) %> Battle
          </h3>
          <p class="text-sm text-gray-400">
            <%= format_timestamp(@battle_analysis.analyzed_at) %>
          </p>
        </div>
        <div class="text-right">
          <div class="text-2xl font-bold text-green-400">
            <%= format_isk(@battle_analysis.isk_destroyed) %>
          </div>
          <p class="text-sm text-gray-400">ISK Destroyed</p>
        </div>
      </div>

      <div class="summary-stats grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
        <div>
          <p class="text-sm text-gray-400">Participants</p>
          <p class="text-lg font-semibold"><%= @battle_analysis.total_participants %></p>
        </div>
        <div>
          <p class="text-sm text-gray-400">Duration</p>
          <p class="text-lg font-semibold"><%= format_duration(@battle_analysis.duration_seconds) %></p>
        </div>
        <div>
          <p class="text-sm text-gray-400">Scale</p>
          <p class="text-lg font-semibold">
            <span class={scale_color_class(@battle_analysis.engagement_scale)}>
              <%= format_scale(@battle_analysis.engagement_scale) %>
            </span>
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-400">Winner</p>
          <p class="text-lg font-semibold">
            <%= format_winner(@battle_analysis.winner) %>
          </p>
        </div>
      </div>

      <!-- Fleet compositions -->
      <%= if @battle_analysis.fleet_compositions do %>
        <div class="fleet-compositions mb-4">
          <h4 class="text-sm font-semibold text-gray-400 mb-2">Fleet Compositions</h4>
          <div class="grid grid-cols-2 gap-2">
            <%= for {side, comp} <- @battle_analysis.fleet_compositions do %>
              <div class="side-composition bg-gray-900 rounded p-2">
                <p class="text-sm font-semibold mb-1"><%= format_side(side) %></p>
                <p class="text-xs text-gray-400">
                  <%= comp.pilot_count %> pilots •
                  <%= format_percentage(comp.logistics_ratio * 100) %> logi
                </p>
                <%= if comp.doctrine_detected do %>
                  <p class="text-xs text-blue-400 mt-1">
                    Doctrine: <%= comp.doctrine_detected %>
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Victory factors -->
      <%= if @battle_analysis.victory_factors do %>
        <div class="victory-factors">
          <h4 class="text-sm font-semibold text-gray-400 mb-2">Key Victory Factors</h4>
          <div class="flex flex-wrap gap-2">
            <%= for factor <- @battle_analysis.victory_factors do %>
              <span class="text-xs bg-gray-700 rounded px-2 py-1">
                <%= format_victory_factor(factor) %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Recommendations -->
      <%= if @show_recommendations && Map.get(@battle_analysis, :recommendations) do %>
        <div class="recommendations mt-4 pt-4 border-t border-gray-700">
          <h4 class="text-sm font-semibold text-gray-400 mb-2">Tactical Recommendations</h4>
          <ul class="text-sm space-y-1">
            <%= for rec <- Enum.take(@battle_analysis.recommendations.tactical, 3) do %>
              <li class="flex items-start gap-2">
                <span class="text-yellow-500 mt-0.5">•</span>
                <span class="text-gray-300"><%= rec %></span>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders fleet composition breakdown.
  """
  attr :fleet_analysis, :map, required: true
  attr :side, :atom, required: true
  attr :class, :string, default: ""

  def fleet_composition_breakdown(assigns) do
    ~H"""
    <div class={["fleet-composition-breakdown bg-gray-800 rounded p-4", @class]}>
      <h3 class="text-lg font-semibold mb-4">
        <%= format_side(@side) %> Fleet Composition
      </h3>

      <!-- Ship class distribution -->
      <div class="ship-distribution mb-4">
        <h4 class="text-sm font-semibold text-gray-400 mb-2">Ship Classes</h4>
        <%= render_ship_class_bars(@fleet_analysis.ship_composition) %>
      </div>

      <!-- Fleet metrics -->
      <div class="fleet-metrics grid grid-cols-2 gap-4 mb-4">
        <div>
          <p class="text-sm text-gray-400">Pilot Count</p>
          <p class="text-xl font-semibold"><%= @fleet_analysis.pilot_count %></p>
        </div>
        <div>
          <p class="text-sm text-gray-400">Average Efficiency</p>
          <p class="text-xl font-semibold">
            <span class={efficiency_color_class(@fleet_analysis.average_pilot_efficiency)}>
              <%= format_efficiency(@fleet_analysis.average_pilot_efficiency) %>
            </span>
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-400">Logistics Ratio</p>
          <p class="text-xl font-semibold">
            <%= format_percentage(@fleet_analysis.logistics_ratio * 100) %>
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-400">EWAR Present</p>
          <p class="text-xl font-semibold">
            <%= if @fleet_analysis.ewar_presence, do: "Yes", else: "No" %>
          </p>
        </div>
      </div>

      <!-- Doctrine effectiveness -->
      <%= if @fleet_analysis.doctrine_detected do %>
        <div class="doctrine-info bg-gray-900 rounded p-3">
          <h4 class="text-sm font-semibold text-gray-400 mb-2">Doctrine Analysis</h4>
          <p class="text-sm mb-2">
            Detected: <span class="text-blue-400 font-semibold"><%= @fleet_analysis.doctrine_detected %></span>
          </p>
          <%= if Map.get(@fleet_analysis, :doctrine_effectiveness) do %>
            <div class="effectiveness-meter">
              <div class="flex justify-between text-xs text-gray-400 mb-1">
                <span>Effectiveness</span>
                <span><%= format_percentage(@fleet_analysis.doctrine_effectiveness * 100) %></span>
              </div>
              <div class="w-full bg-gray-700 rounded-full h-2">
                <div
                  class="bg-gradient-to-r from-red-500 via-yellow-500 to-green-500 h-2 rounded-full"
                  style={"width: #{@fleet_analysis.doctrine_effectiveness * 100}%"}
                ></div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Private rendering functions

  defp render_intensity_curve(assigns) do
    intensity_data = Map.get(assigns.timeline_data, :intensity_curve, [])

    if length(intensity_data) > 0 do
      # Convert intensity data to SVG path
      assigns = assign(assigns, :intensity_path, build_intensity_path(intensity_data))

      ~H"""
      <svg class="w-full h-full" preserveAspectRatio="none">
        <defs>
          <linearGradient id="intensityGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:rgb(239,68,68);stop-opacity:0.3" />
            <stop offset="100%" style="stop-color:rgb(239,68,68);stop-opacity:0" />
          </linearGradient>
        </defs>
        <path
          d={@intensity_path}
          fill="url(#intensityGradient)"
          stroke="rgb(239,68,68)"
          stroke-width="2"
        />
      </svg>
      """
    else
      ~H""
    end
  end

  defp render_time_axis(assigns) do
    ~H"""
    <div class="flex justify-between px-2 h-full items-center text-xs text-gray-500">
      <span>0:00</span>
      <span><%= format_duration(@timeline_data.duration / 4) %></span>
      <span><%= format_duration(@timeline_data.duration / 2) %></span>
      <span><%= format_duration(3 * @timeline_data.duration / 4) %></span>
      <span><%= format_duration(@timeline_data.duration) %></span>
    </div>
    """
  end

  defp render_event_marker(event, index, assigns) do
    # Calculate position based on timestamp
    position = calculate_event_position(event, assigns.timeline_data)

    assigns = assigns
    |> assign(:event, event)
    |> assign(:index, index)
    |> assign(:position, position)

    ~H"""
    <div
      id={"event-marker-#{@index}"}
      class="event-marker absolute"
      style={"left: #{@position}%; bottom: 40px;"}
      phx-hook="Tooltip"
      data-tooltip={event_tooltip(@event)}
    >
      <div class={[
        "w-3 h-3 rounded-full cursor-pointer transform -translate-x-1/2",
        event_color_class(@event),
        "hover:scale-150 transition-transform"
      ]}>
      </div>
    </div>
    """
  end

  defp render_phase_marker(phase, assigns) do
    start_pos = calculate_phase_position(phase.start_time, assigns.timeline_data)
    end_pos = calculate_phase_position(phase.end_time, assigns.timeline_data)
    width = end_pos - start_pos

    assigns = assigns
    |> assign(:phase, phase)
    |> assign(:start_pos, start_pos)
    |> assign(:width, width)

    ~H"""
    <div
      class="phase-marker absolute h-full bg-blue-500 opacity-10"
      style={"left: #{@start_pos}%; width: #{@width}%;"}
    >
      <div class="phase-label absolute top-2 left-2 text-xs text-blue-400 font-semibold">
        <%= @phase.name %>
      </div>
    </div>
    """
  end

  defp render_key_moment(moment, assigns) do
    position = calculate_event_position(moment, assigns.timeline_data)

    assigns = assigns
    |> assign(:moment, moment)
    |> assign(:position, position)

    ~H"""
    <div
      class="key-moment absolute"
      style={"left: #{@position}%; top: 20px;"}
    >
      <div class="flex flex-col items-center">
        <div class="w-4 h-4 rounded-full bg-yellow-500 animate-pulse"></div>
        <div class="absolute top-5 whitespace-nowrap text-xs text-yellow-400 font-semibold">
          <%= @moment.description %>
        </div>
      </div>
    </div>
    """
  end

  defp render_participant_flow(flow_data) do
    assigns = %{flow_data: flow_data}

    ~H"""
    <div class="participant-flow-chart bg-gray-900 rounded p-3">
      <div class="flow-stats grid grid-cols-2 gap-4 text-sm">
        <div>
          <p class="text-gray-400">Pilots Joined</p>
          <p class="text-lg font-semibold text-green-400">
            +<%= length(@flow_data.joiners) %>
          </p>
        </div>
        <div>
          <p class="text-gray-400">Pilots Left</p>
          <p class="text-lg font-semibold text-red-400">
            -<%= length(@flow_data.leavers) %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp render_ship_class_bars(ship_composition) do
    total = Enum.sum(Map.values(ship_composition))

    assigns = %{
      ship_composition: ship_composition,
      total: total
    }

    ~H"""
    <div class="ship-class-bars space-y-2">
      <%= for {ship_class, count} <- Enum.sort_by(@ship_composition, &elem(&1, 1), :desc) do %>
        <div class="ship-class-bar">
          <div class="flex justify-between text-xs mb-1">
            <span class="text-gray-400"><%= format_ship_class(ship_class) %></span>
            <span class="text-gray-300"><%= count %></span>
          </div>
          <div class="w-full bg-gray-700 rounded-full h-2">
            <div
              class="bg-blue-500 h-2 rounded-full"
              style={"width: #{(count / @total) * 100}%"}
            ></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp format_duration(seconds) when is_number(seconds) do
    minutes = div(trunc(seconds), 60)
    secs = rem(trunc(seconds), 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
  defp format_duration(_), do: "0:00"

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S")
  end

  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{trunc(value)}"
    end
  end
  defp format_isk(_), do: "0"

  defp format_battle_type(type) do
    case type do
      :small_gang -> "Small Gang"
      :fleet_fight -> "Fleet"
      :large_scale_battle -> "Large Scale"
      _ -> "Unknown"
    end
  end

  defp format_scale(scale) do
    case scale do
      :skirmish -> "Skirmish"
      :small_gang -> "Small Gang"
      :medium_gang -> "Medium Gang"
      :fleet -> "Fleet"
      :large_fleet -> "Large Fleet"
      :massive_battle -> "Massive Battle"
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

  defp format_winner(winner) do
    case winner do
      {:side, side} -> format_side(side)
      :undetermined -> "Undetermined"
      _ -> "Unknown"
    end
  end

  defp format_side(side) do
    case side do
      :side_a -> "Alpha Force"
      :side_b -> "Bravo Force"
      _ -> "Unknown"
    end
  end

  defp format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end
  defp format_percentage(_), do: "0%"

  defp format_efficiency(value) when is_number(value) do
    "#{Float.round(value, 2)}"
  end
  defp format_efficiency(_), do: "0.00"

  defp efficiency_color_class(efficiency) when is_number(efficiency) do
    cond do
      efficiency >= 2.0 -> "text-green-400"
      efficiency >= 1.0 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end
  defp efficiency_color_class(_), do: "text-gray-400"

  defp format_victory_factor(factor) do
    case factor do
      :superior_numbers -> "Superior Numbers"
      :better_composition -> "Better Composition"
      :tactical_execution -> "Tactical Execution"
      :logistics_advantage -> "Logistics Advantage"
      :focus_fire -> "Focus Fire Discipline"
      _ -> to_string(factor)
    end
  end

  defp format_ship_class(class) do
    class
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp event_color_class(event) do
    case event.event_type do
      :kill -> "bg-red-500"
      :loss -> "bg-gray-500"
      :objective -> "bg-blue-500"
      _ -> "bg-gray-400"
    end
  end

  defp event_tooltip(event) do
    ship_name = Map.get(event.victim, :ship_name, "Unknown")
    character_name = Map.get(event.victim, :character_name, "Unknown")
    isk = format_isk(Map.get(event, :isk_destroyed, 0))

    "#{ship_name} - #{character_name}\n#{isk} ISK"
  end

  defp calculate_event_position(event, timeline_data) do
    if timeline_data.duration > 0 do
      first_event = List.first(timeline_data.events)
      event_offset = DateTime.diff(event.timestamp, first_event.timestamp)
      (event_offset / timeline_data.duration) * 100
    else
      0
    end
  end

  defp calculate_phase_position(timestamp, timeline_data) do
    if timeline_data.duration > 0 && length(timeline_data.events) > 0 do
      first_event = List.first(timeline_data.events)
      offset = DateTime.diff(timestamp, first_event.timestamp)
      (offset / timeline_data.duration) * 100
    else
      0
    end
  end

  defp build_intensity_path(intensity_data) do
    # Build SVG path from intensity data points
    # This is a simplified implementation
    "M 0,100 L 50,20 L 100,100"
  end
end