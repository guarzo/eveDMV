defmodule EveDmvWeb.CharacterIntelligenceLive do
  @moduledoc """
  LiveView for character intelligence and threat analysis.

  Displays comprehensive threat scoring, behavioral patterns, and tactical recommendations
  for EVE Online characters based on their combat history.
  """

  use EveDmvWeb, :live_view

  import EveDmvWeb.Components.ThreatLevelComponent
  import EveDmvWeb.LiveHelpers.ApiErrorHelper
  import EveDmvWeb.IntelligenceComponents

  alias EveDmv.Contexts.CharacterIntelligence

  @impl Phoenix.LiveView
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    character_id = String.to_integer(character_id_str)

    socket =
      socket
      |> assign(:page_title, "Character Intelligence")
      |> assign(:character_id, character_id)
      |> assign(:loading, true)
      |> assign(:error_message, nil)
      |> assign(:intelligence_report, nil)
      |> assign(:comparison_characters, [])
      |> assign(:show_comparison, false)
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> load_character_intelligence(character_id)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"character_id" => character_id_str}, _uri, socket) do
    character_id = String.to_integer(character_id_str)

    if character_id != socket.assigns.character_id do
      {:noreply,
       socket
       |> assign(:character_id, character_id)
       |> assign(:loading, true)
       |> load_character_intelligence(character_id)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    updated_socket =
      socket
      |> assign(:loading, true)
      |> load_character_intelligence(socket.assigns.character_id)

    {:noreply, updated_socket}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_comparison", _params, socket) do
    {:noreply, assign(socket, :show_comparison, !socket.assigns.show_comparison)}
  end

  @impl Phoenix.LiveView
  def handle_event("search_character", %{"query" => query}, socket) do
    # Search character database for matching names
    results =
      case EveDmv.Search.SearchSuggestionService.get_character_suggestions(query, limit: 8) do
        {:ok, suggestions} -> suggestions
        {:error, _reason} -> []
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  @impl Phoenix.LiveView
  def handle_event("add_to_comparison", %{"character_id" => character_id_str}, socket) do
    character_id = String.to_integer(character_id_str)
    comparison_characters = socket.assigns.comparison_characters

    if character_id not in Enum.map(comparison_characters, & &1.character_id) and
         character_id != socket.assigns.character_id do
      case CharacterIntelligence.analyze_character_threat(character_id) do
        {:ok, analysis} ->
          character_info = %{
            character_id: character_id,
            name: "Character #{character_id}",
            threat_analysis: analysis
          }

          {:noreply,
           socket
           |> assign(
             :comparison_characters,
             List.insert_at(comparison_characters, -1, character_info)
           )
           |> assign(:search_query, "")
           |> assign(:search_results, [])}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("remove_from_comparison", %{"character_id" => character_id_str}, socket) do
    character_id = String.to_integer(character_id_str)

    comparison_characters =
      Enum.reject(socket.assigns.comparison_characters, &(&1.character_id == character_id))

    {:noreply, assign(socket, :comparison_characters, comparison_characters)}
  end

  # Private functions

  defp load_character_intelligence(socket, character_id) do
    case safe_api_call(
           socket,
           fn ->
             CharacterIntelligence.get_character_intelligence_report(character_id)
           end,
           "Loading character intelligence"
         ) do
      {:ok, report} ->
        socket
        |> assign(:intelligence_report, report)
        |> assign(:loading, false)
        |> assign(:error_message, nil)
        |> update_page_title(report.character.name)

      {:error, error_socket} ->
        error_socket
        |> assign(:loading, false)
        |> assign(:intelligence_report, nil)
    end
  end

  defp update_page_title(socket, character_name) do
    assign(socket, :page_title, "Intelligence: #{character_name}")
  end

  # View helpers

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

  def behavior_pattern_icon(:solo_hunter), do: "🎯"
  def behavior_pattern_icon(:fleet_anchor), do: "⚓"
  def behavior_pattern_icon(:specialist), do: "🔧"
  def behavior_pattern_icon(:opportunist), do: "🦊"
  def behavior_pattern_icon(_), do: "❓"

  def format_dimension_name(dimension) do
    dimension
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def trend_indicator(current, previous) when current > previous, do: {"↑", "text-red-400"}
  def trend_indicator(current, previous) when current < previous, do: {"↓", "text-green-400"}
  def trend_indicator(_, _), do: {"→", "text-gray-400"}

  def character_portrait(character_id, size \\ 64) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end

  def format_isk(amount) when amount >= 1_000_000_000 do
    "#{Float.round(amount / 1_000_000_000, 1)}B"
  end

  def format_isk(amount) when amount >= 1_000_000 do
    "#{Float.round(amount / 1_000_000, 1)}M"
  end

  def format_isk(amount) when amount >= 1_000 do
    "#{Float.round(amount / 1_000, 1)}K"
  end

  def format_isk(amount), do: "#{amount}"

  # Helper functions for template
  def determine_grade(threat_score) do
    case threat_score do
      score when score >= 0.9 -> "A+"
      score when score >= 0.8 -> "A"
      score when score >= 0.7 -> "B+"
      score when score >= 0.6 -> "B"
      score when score >= 0.5 -> "C+"
      score when score >= 0.4 -> "C"
      score when score >= 0.3 -> "D+"
      score when score >= 0.2 -> "D"
      _ -> "F"
    end
  end

  def generate_threat_recommendations(threat_analysis) do
    case threat_analysis.threat_level do
      level when level in [:high, :critical] ->
        [
          "Enhanced monitoring recommended",
          "Consider escalation protocols",
          "Review access permissions"
        ]

      level when level in [:medium, :moderate] ->
        ["Standard monitoring", "Periodic review"]

      _ ->
        ["Standard processing", "Routine monitoring"]
    end
  end

  def transform_behavioral_characteristics(characteristics) when is_list(characteristics) do
    characteristics
    |> Enum.with_index()
    |> Enum.map(fn {char, index} ->
      %{
        indicator_type: "behavioral_#{index}",
        description: char,
        confidence: 0.8,
        relevance: :high
      }
    end)
  end

  def transform_behavioral_characteristics(_), do: []

  def calculate_pattern_confidence(patterns) when is_map(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      patterns
      |> Map.values()
      |> Enum.sum()
      |> Kernel./(length(Map.values(patterns)))
    end
  end

  def calculate_pattern_confidence(_), do: 0.0

  def generate_behavioral_recommendations(behavioral_patterns) do
    base_recommendations = ["Continue behavioral monitoring", "Analyze engagement patterns"]

    pattern_specific =
      case behavioral_patterns.primary_pattern do
        :aggressive -> ["Expect direct engagement", "Prepare for sustained combat"]
        :cautious -> ["Anticipate defensive tactics", "Watch for retreat patterns"]
        :opportunistic -> ["Monitor for third-party opportunities", "Expect engagement timing"]
        :nomadic -> ["Track movement patterns", "Anticipate relocation"]
        :territorial -> ["Expect area defense", "Monitor home system activity"]
        _ -> ["General pattern analysis needed"]
      end

    base_recommendations ++ pattern_specific
  end
end
