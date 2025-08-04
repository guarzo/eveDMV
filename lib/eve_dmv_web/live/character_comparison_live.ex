defmodule EveDmvWeb.CharacterComparisonLive do
  @moduledoc """
  LiveView for comparing multiple EVE Online characters side-by-side.

  Provides detailed comparison of combat statistics, ship preferences,
  and engagement patterns between selected characters.
  """

  use EveDmvWeb, :live_view
  import EveDmvWeb.Components.PageHeaderComponent

  alias EveDmv.Analytics.CharacterComparisonService
  alias EveDmv.Presentation.Formatters

  # Load current user from session (require auth for this analytical feature)
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:selected_characters, [])
      |> assign(:character_input, "")
      |> assign(:character_suggestions, [])
      |> assign(:comparison_mode, :multi_character)
      |> assign(:timeframe, :last_30_days)
      |> assign(:comparison_result, nil)
      |> assign(:similarity_result, nil)
      |> assign(:loading, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  def handle_event("change_comparison_mode", %{"mode" => mode}, socket) do
    mode_atom = String.to_existing_atom(mode)

    socket =
      socket
      |> assign(:comparison_mode, mode_atom)
      |> assign(:comparison_result, nil)
      |> assign(:similarity_result, nil)
      |> assign(:error, nil)

    {:noreply, socket}
  end

  def handle_event("change_timeframe", %{"timeframe" => timeframe}, socket) do
    timeframe_atom = String.to_existing_atom(timeframe)

    socket =
      socket
      |> assign(:timeframe, timeframe_atom)
      |> maybe_refresh_results()

    {:noreply, socket}
  end

  def handle_event("character_input_changed", %{"value" => input}, socket) do
    suggestions =
      if String.length(input) >= 3 do
        search_character_suggestions(input)
      else
        []
      end

    socket =
      socket
      |> assign(:character_input, input)
      |> assign(:character_suggestions, suggestions)

    {:noreply, socket}
  end

  def handle_event("add_character", %{"character_id" => character_id_str}, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        if character_id in socket.assigns.selected_characters do
          {:noreply, put_flash(socket, :info, "Character already selected")}
        else
          selected_characters = [character_id | socket.assigns.selected_characters]

          socket =
            socket
            |> assign(:selected_characters, selected_characters)
            |> assign(:character_input, "")
            |> assign(:character_suggestions, [])
            |> assign(:error, nil)

          {:noreply, socket}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid character ID")}
    end
  end

  def handle_event("remove_character", %{"character_id" => character_id_str}, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        selected_characters = List.delete(socket.assigns.selected_characters, character_id)

        socket =
          socket
          |> assign(:selected_characters, selected_characters)
          |> assign(:comparison_result, nil)
          |> assign(:similarity_result, nil)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("run_comparison", _params, socket) do
    case socket.assigns.comparison_mode do
      :multi_character ->
        run_multi_character_comparison(socket)

      :head_to_head ->
        run_head_to_head_comparison(socket)

      :find_similar ->
        run_similarity_search(socket)
    end
  end

  def handle_event("clear_all", _params, socket) do
    socket =
      socket
      |> assign(:selected_characters, [])
      |> assign(:comparison_result, nil)
      |> assign(:similarity_result, nil)
      |> assign(:error, nil)

    {:noreply, socket}
  end

  # Private helper functions

  defp run_multi_character_comparison(socket) do
    if length(socket.assigns.selected_characters) < 2 do
      socket = put_flash(socket, :error, "Please select at least 2 characters to compare")
      {:noreply, socket}
    else
      socket = assign(socket, :loading, true)

      try do
        case CharacterComparisonService.compare_characters(
               socket.assigns.selected_characters,
               socket.assigns.timeframe
             ) do
          {:ok, result} when is_map(result) ->
            socket =
              socket
              |> assign(:comparison_result, result)
              |> assign(:similarity_result, nil)
              |> assign(:loading, false)
              |> assign(:error, nil)

            {:noreply, socket}

          {:error, reason} ->
            socket =
              socket
              |> assign(:loading, false)
              |> assign(:error, format_error(reason))

            {:noreply, socket}

          _other ->
            socket =
              socket
              |> assign(:loading, false)
              |> assign(:error, "Service unavailable")

            {:noreply, put_flash(socket, :error, "Comparison service is currently unavailable")}
        end
      rescue
        _error ->
          socket =
            socket
            |> assign(:loading, false)
            |> assign(:error, "Service error")

          {:noreply, put_flash(socket, :error, "Comparison service is currently unavailable")}
      end
    end
  end

  defp run_head_to_head_comparison(socket) do
    if length(socket.assigns.selected_characters) != 2 do
      socket =
        put_flash(
          socket,
          :error,
          "Please select exactly 2 characters for head-to-head comparison"
        )

      {:noreply, socket}
    else
      [char1_id, char2_id] = socket.assigns.selected_characters
      socket = assign(socket, :loading, true)

      {:ok, result} =
        CharacterComparisonService.head_to_head_comparison(
          char1_id,
          char2_id,
          socket.assigns.timeframe
        )

      socket =
        socket
        |> assign(:comparison_result, result)
        |> assign(:similarity_result, nil)
        |> assign(:loading, false)
        |> assign(:error, nil)

      {:noreply, socket}
    end
  end

  defp run_similarity_search(socket) do
    if length(socket.assigns.selected_characters) != 1 do
      socket =
        put_flash(socket, :error, "Please select exactly 1 character to find similar pilots")

      {:noreply, socket}
    else
      [character_id] = socket.assigns.selected_characters
      socket = assign(socket, :loading, true)

      case CharacterComparisonService.find_similar_characters(
             character_id,
             socket.assigns.timeframe,
             10
           ) do
        {:ok, result} ->
          socket =
            socket
            |> assign(:similarity_result, result)
            |> assign(:comparison_result, nil)
            |> assign(:loading, false)
            |> assign(:error, nil)

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> assign(:loading, false)
            |> assign(:error, reason)

          {:noreply, put_flash(socket, :error, "Similarity search failed: #{reason}")}
      end
    end
  end

  defp maybe_refresh_results(socket) do
    cond do
      socket.assigns.comparison_result != nil ->
        run_multi_character_comparison(socket) |> elem(1)

      socket.assigns.similarity_result != nil ->
        run_similarity_search(socket) |> elem(1)

      true ->
        socket
    end
  end

  defp search_character_suggestions(_input) do
    # This would normally search character names from database or API
    # For now, return empty list - would need character name search implementation
    []
  end

  # Delegate formatting functions
  defdelegate format_isk(value), to: Formatters
  defdelegate format_number(value), to: Formatters
  defdelegate format_percentage(value), to: Formatters

  # Helper functions for UI
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(:insufficient_data), do: "Insufficient data for comparison"
  defp format_error(:service_unavailable), do: "Comparison service temporarily unavailable"
  defp format_error(_), do: "An error occurred during comparison"

  def format_timeframe(timeframe) do
    case timeframe do
      :last_7_days -> "Last 7 Days"
      :last_30_days -> "Last 30 Days"
      :last_90_days -> "Last 90 Days"
      :last_180_days -> "Last 180 Days"
    end
  end

  def format_combat_style(style) do
    case style do
      :aggressive -> {"🔥 Aggressive", "text-red-400"}
      :cautious -> {"🛡️ Cautious", "text-blue-400"}
      :balanced -> {"⚖️ Balanced", "text-green-400"}
      :hunter -> {"🎯 Hunter", "text-yellow-400"}
      :target -> {"🎯 Target", "text-orange-400"}
      :inactive -> {"💤 Inactive", "text-gray-400"}
    end
  end

  def format_danger_rating(rating) do
    case rating do
      :minimal -> {"Minimal", "text-green-400"}
      :low -> {"Low", "text-yellow-400"}
      :moderate -> {"Moderate", "text-orange-400"}
      :high -> {"High", "text-red-400"}
      :very_high -> {"Very High", "text-red-600"}
    end
  end

  def format_survival_rating(rating) do
    case rating do
      :excellent -> {"Excellent", "text-green-400"}
      :good -> {"Good", "text-green-300"}
      :average -> {"Average", "text-yellow-400"}
      :poor -> {"Poor", "text-orange-400"}
      :very_poor -> {"Very Poor", "text-red-400"}
    end
  end

  def get_character_display_name(character_id) do
    # This would normally resolve character names
    # For now, return a placeholder
    "Character #{character_id}"
  end

  def comparison_mode_requirements(mode) do
    case mode do
      :multi_character -> "2-10 characters"
      :head_to_head -> "exactly 2 characters"
      :find_similar -> "exactly 1 character"
    end
  end

  def can_run_comparison?(mode, selected_count) do
    case mode do
      :multi_character -> selected_count >= 2 and selected_count <= 10
      :head_to_head -> selected_count == 2
      :find_similar -> selected_count == 1
    end
  end
end
