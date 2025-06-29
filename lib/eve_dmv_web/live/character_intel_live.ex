defmodule EveDmvWeb.CharacterIntelLive do
  @moduledoc """
  LiveView for displaying hunter-focused character intelligence.

  Shows tactical information about a character including:
  - Ship preferences and typical fits
  - Gang composition and frequent associates
  - Geographic patterns and active zones
  - Target preferences and engagement patterns
  - Identified weaknesses and behavioral patterns
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Intelligence.{CharacterAnalyzer, CharacterStats}

  @impl true
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    character_id = String.to_integer(character_id_str)

    socket =
      socket
      |> assign(:character_id, character_id)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:stats, nil)
      |> assign(:tab, :overview)

    # Load character stats asynchronously
    send(self(), {:load_character, character_id})

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab =
      case params["tab"] do
        "ships" -> :ships
        "associates" -> :associates
        "geography" -> :geography
        "weaknesses" -> :weaknesses
        _ -> :overview
      end

    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def handle_info({:load_character, character_id}, socket) do
    case load_or_analyze_character(character_id) do
      {:ok, stats} ->
        # Enrich associates data with corporation names and logistics flags
        enriched_stats = enrich_associates_data(stats)

        {:noreply,
         socket
         |> assign(:stats, enriched_stats)
         |> assign(:loading, false)
         |> assign(:error, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, format_error(reason))}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    character_id = socket.assigns.character_id

    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)

    # Force re-analysis
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, _stats} ->
          send(self(), {:load_character, character_id})

        {:error, reason} ->
          require Logger
          Logger.warning("Character re-analysis failed for #{character_id}: #{inspect(reason)}")
          :ok
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:tab, String.to_atom(tab))
     |> push_patch(to: ~p"/intel/#{socket.assigns.character_id}?tab=#{tab}")}
  end

  # Private functions

  defp load_or_analyze_character(character_id) do
    # Try to load existing stats first
    case CharacterStats
         |> Ash.Query.for_read(:get_by_character_id, %{character_id: character_id})
         |> Ash.read_one(domain: EveDmv.Api) do
      {:ok, nil} ->
        # No stats exist, analyze the character
        CharacterAnalyzer.analyze_character(character_id)

      {:ok, stats} ->
        # Check if stats are stale (>24 hours old)
        staleness_threshold = Application.get_env(:eve_dmv, :character_stats_staleness_hours, 24)

        if stale_stats?(stats, staleness_threshold) do
          start_background_analysis(character_id)
        end

        {:ok, stats}

      {:error, error} ->
        {:error, error}
    end
  end

  defp stale_stats?(stats, threshold_hours) do
    case stats.last_calculated_at do
      nil ->
        true

      last_calc ->
        hours_old = DateTime.diff(DateTime.utc_now(), last_calc, :hour)
        hours_old > threshold_hours
    end
  end

  defp start_background_analysis(character_id) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          require Logger

          Logger.warning(
            "Background character analysis failed for #{character_id}: #{inspect(reason)}"
          )

          :ok
      end
    end)
  end

  # Enrich associates data with corporation names and logistics detection
  defp enrich_associates_data(stats) do
    enriched_associates =
      stats.frequent_associates
      |> Enum.map(fn {char_id, associate} ->
        # Add corporation name
        corp_name = EveDmv.Eve.NameResolver.corporation_name(associate["corp_id"])

        # Detect logistics ships
        is_logistics = logistics_pilot?(associate["name"], associate["ships_flown"] || [])

        enriched_associate =
          associate
          |> Map.put("corp_name", corp_name)
          |> Map.put("is_logistics", is_logistics)

        {char_id, enriched_associate}
      end)
      |> Map.new()

    # Update the stats with enriched associates
    Map.put(stats, :frequent_associates, enriched_associates)
  end

  # Detect logistics pilots based on name and ships flown
  defp logistics_pilot?(name, ships_flown) do
    # Check pilot name for logistics indicators
    name_indicates_logi =
      name && String.contains?(String.downcase(name), ["logi", "guardian", "deacon", "scimi"])

    # Check ships flown for logistics ship types
    ships_indicate_logi =
      Enum.any?(ships_flown, fn ship ->
        String.contains?(String.downcase(ship), [
          "guardian",
          "basilisk",
          "oneiros",
          "scimitar",
          "deacon",
          "thalia",
          "minokawa",
          "apostle",
          "fax",
          "nestor"
        ])
      end)

    name_indicates_logi || ships_indicate_logi
  end

  defp format_error(:insufficient_activity),
    do: "Not enough activity to analyze (minimum 10 kills/losses required)"

  defp format_error(:character_not_found), do: "Character not found in killmail database"
  defp format_error(_), do: "Failed to load character intelligence"

  # View helpers

  defp danger_color(rating) when rating >= 4, do: "text-red-500"
  defp danger_color(rating) when rating >= 3, do: "text-yellow-500"
  defp danger_color(_), do: "text-green-500"

  defp format_isk(value) when is_float(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{round(value)}"
    end
  end

  defp format_isk(_), do: "0"

  defp ship_success_color(rate) when rate >= 0.8, do: "text-green-400"
  defp ship_success_color(rate) when rate >= 0.6, do: "text-yellow-400"
  defp ship_success_color(_), do: "text-red-400"

  defp gang_size_label(size) when size <= 1.5, do: {"Solo", "text-purple-400"}
  defp gang_size_label(size) when size <= 5, do: {"Small Gang", "text-blue-400"}
  defp gang_size_label(size) when size <= 15, do: {"Mid Gang", "text-yellow-400"}
  defp gang_size_label(_), do: {"Fleet", "text-red-400"}

  defp security_color("highsec"), do: "text-green-400"
  defp security_color("lowsec"), do: "text-yellow-400"
  defp security_color("nullsec"), do: "text-red-400"
  defp security_color("wormhole"), do: "text-purple-400"
  defp security_color(_), do: "text-gray-400"

  defp weakness_icon("predictable_schedule"), do: "🕐"
  defp weakness_icon("overconfident"), do: "💀"
  defp weakness_icon("weak_to_neuts"), do: "⚡"
  defp weakness_icon(_), do: "⚠️"

  defp weakness_label("predictable_schedule"), do: "Predictable Schedule"
  defp weakness_label("overconfident"), do: "Takes Bad Fights"
  defp weakness_label("weak_to_neuts"), do: "Vulnerable to Neuts"
  defp weakness_label(weakness), do: Phoenix.Naming.humanize(weakness)
end
