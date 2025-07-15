defmodule EveDmvWeb.CharacterAnalysis.Components.CharacterHeaderComponent do
  @moduledoc """
  Character header component displaying character portrait, name, corporation, alliance, and threat score.
  """

  use EveDmvWeb, :live_component
  import EveDmvWeb.EveImageComponents

  def render(assigns) do
    ~H"""
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
            <div class="text-gray-400 mt-1">
              <%= if @intelligence && @intelligence.character && @intelligence.character.corporation_name do %>
                <.link navigate={~p"/corporation/#{@intelligence.character.corporation_id}"} class="text-lg hover:text-blue-400 transition-colors">
                  <%= @intelligence.character.corporation_name %>
                </.link>
                <%= if @intelligence.character.alliance_name do %>
                  <.link navigate={~p"/alliance/#{@intelligence.character.alliance_id}"} class="text-sm text-gray-500 hover:text-blue-400 transition-colors">
                    [<%= @intelligence.character.alliance_name %>]
                  </.link>
                <% end %>
              <% else %>
                <%= if Map.get(@analysis, :corporation_name) do %>
                  <%= if Map.get(@analysis, :corporation_id) do %>
                    <.link navigate={~p"/corporation/#{@analysis.corporation_id}"} class="text-lg hover:text-blue-400 transition-colors">
                      <%= @analysis.corporation_name %>
                    </.link>
                  <% else %>
                    <p class="text-lg"><%= @analysis.corporation_name %></p>
                  <% end %>
                  <%= if Map.get(@analysis, :alliance_name) do %>
                    <%= if Map.get(@analysis, :alliance_id) do %>
                      <.link navigate={~p"/alliance/#{@analysis.alliance_id}"} class="text-sm text-gray-500 hover:text-blue-400 transition-colors">
                        [<%= @analysis.alliance_name %>]
                      </.link>
                    <% else %>
                      <p class="text-sm text-gray-500">[<%= @analysis.alliance_name %>]</p>
                    <% end %>
                  <% end %>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
        
        <!-- Threat Score (if intelligence data available) -->
        <%= if @intelligence && @intelligence.threat_analysis do %>
          <div class={"ml-auto px-6 py-3 rounded-lg border " <> threat_level_bg(@intelligence.threat_analysis.threat_score)}>
            <div class="text-center">
              <p class="text-sm text-gray-400 mb-1">Threat Score</p>
              <p class={"text-3xl font-bold " <> threat_level_color(@intelligence.threat_analysis.threat_score)}>
                <%= @intelligence.threat_analysis.threat_score %>/100
              </p>
              <p class="text-sm mt-1 capitalize"><%= @intelligence.summary.threat_level %> Threat</p>
            </div>
          </div>
        <% end %>
        
      </div>
    </div>
    """
  end

  def threat_level_color(score) when score >= 90, do: "text-red-500"
  def threat_level_color(score) when score >= 75, do: "text-orange-500"
  def threat_level_color(score) when score >= 50, do: "text-yellow-500"
  def threat_level_color(score) when score >= 25, do: "text-blue-500"
  def threat_level_color(_), do: "text-green-500"

  def threat_level_bg(score) when score >= 90, do: "bg-red-900/20 border-red-800"
  def threat_level_bg(score) when score >= 75, do: "bg-orange-900/20 border-orange-800"
  def threat_level_bg(score) when score >= 50, do: "bg-yellow-900/20 border-yellow-800"
  def threat_level_bg(score) when score >= 25, do: "bg-blue-900/20 border-blue-800"
  def threat_level_bg(_), do: "bg-green-900/20 border-green-800"
end
