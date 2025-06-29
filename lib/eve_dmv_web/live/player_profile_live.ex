defmodule EveDmvWeb.PlayerProfileLive do
  @moduledoc """
  LiveView for displaying player PvP statistics and performance analytics.

  Shows comprehensive player statistics including K/D ratios, ISK efficiency,
  ship preferences, activity patterns, and historical performance.
  """

  use EveDmvWeb, :live_view
  alias EveDmv.Api
  alias EveDmv.Analytics.{PlayerStats, AnalyticsEngine}
  alias EveDmv.Intelligence.{CharacterStats, CharacterAnalyzer}

  # Load current user from session on mount
  on_mount {EveDmvWeb.AuthLive, :load_from_session}

  @impl true
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        # Load player statistics
        player_stats = load_player_stats(character_id)
        character_intel = load_character_intel(character_id)

        socket =
          socket
          |> assign(:character_id, character_id)
          |> assign(:player_stats, player_stats)
          |> assign(:character_intel, character_intel)
          |> assign(:loading, false)
          |> assign(:error, nil)

        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid character ID")
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    character_id = socket.assigns.character_id

    # Trigger analytics calculation for this character
    Task.start(fn ->
      AnalyticsEngine.calculate_player_stats(days: 90, batch_size: 1)
    end)

    # Reload the statistics
    player_stats = load_player_stats(character_id)
    character_intel = load_character_intel(character_id)

    socket =
      socket
      |> assign(:player_stats, player_stats)
      |> assign(:character_intel, character_intel)
      |> put_flash(:info, "Statistics refreshed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_stats", _params, socket) do
    character_id = socket.assigns.character_id

    # Generate statistics if they don't exist
    case create_player_stats(character_id) do
      {:ok, _stats} ->
        player_stats = load_player_stats(character_id)

        socket =
          socket
          |> assign(:player_stats, player_stats)
          |> put_flash(:info, "Player statistics generated successfully")

        {:noreply, socket}

      {:error, error} ->
        socket = put_flash(socket, :error, "Failed to generate statistics: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  # Private helper functions

  defp load_player_stats(character_id) do
    case Ash.get(PlayerStats, character_id: character_id, domain: Api) do
      {:ok, stats} -> stats
      {:error, _} -> nil
    end
  end

  defp load_character_intel(character_id) do
    case Ash.get(CharacterStats, character_id: character_id, domain: Api) do
      {:ok, intel} -> intel
      {:error, _} -> nil
    end
  end

  defp create_player_stats(character_id) do
    # Analyze the character and create player stats
    case CharacterAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        # Convert intelligence data to player stats format
        player_data = convert_intel_to_stats(character_id, analysis)
        Ash.create(PlayerStats, player_data, domain: Api)

      error ->
        error
    end
  end

  defp convert_intel_to_stats(character_id, intel) do
    %{
      character_id: character_id,
      character_name: intel.character_name || "Unknown",
      total_kills: intel.total_kills || 0,
      total_losses: intel.total_losses || 0,
      solo_kills: intel.solo_kills || 0,
      solo_losses: intel.solo_losses || 0,
      gang_kills: (intel.total_kills || 0) - (intel.solo_kills || 0),
      gang_losses: (intel.total_losses || 0) - (intel.solo_losses || 0),
      total_isk_destroyed: intel.total_isk_destroyed || Decimal.new(0),
      total_isk_lost: intel.total_isk_lost || Decimal.new(0),
      danger_rating: intel.danger_rating || 1,
      ship_types_used: intel.ship_usage |> Map.keys() |> length(),
      avg_gang_size: intel.avg_gang_size || Decimal.new(1),
      preferred_gang_size: determine_gang_preference(intel.avg_gang_size),
      primary_activity: classify_activity(intel),
      last_updated: DateTime.utc_now()
    }
  end

  defp determine_gang_preference(avg_gang_size) when is_nil(avg_gang_size), do: "solo"

  defp determine_gang_preference(avg_gang_size) do
    size = Decimal.to_float(avg_gang_size)

    cond do
      size <= 1.2 -> "solo"
      size <= 5.0 -> "small_gang"
      size <= 15.0 -> "medium_gang"
      true -> "fleet"
    end
  end

  defp classify_activity(intel) do
    solo_ratio =
      if (intel.total_kills || 0) > 0 do
        (intel.solo_kills || 0) / (intel.total_kills || 1)
      else
        0
      end

    cond do
      solo_ratio > 0.7 -> "solo_pvp"
      solo_ratio > 0.3 -> "small_gang"
      true -> "fleet_pvp"
    end
  end

  # Template helper functions

  def format_number(nil), do: "0"

  def format_number(number) when is_integer(number) do
    number |> Integer.to_string() |> add_commas()
  end

  def format_number(%Decimal{} = number), do: number |> Decimal.to_float() |> format_number()

  def format_number(number) when is_float(number) do
    cond do
      number >= 1_000_000_000 ->
        "#{Float.round(number / 1_000_000_000, 1)}B"

      number >= 1_000_000 ->
        "#{Float.round(number / 1_000_000, 1)}M"

      number >= 1_000 ->
        "#{Float.round(number / 1_000, 1)}K"

      true ->
        number |> Float.round(2) |> Float.to_string() |> add_commas()
    end
  end

  defp add_commas(number_string) do
    number_string
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_isk(nil), do: "0 ISK"
  def format_isk(amount), do: "#{format_number(amount)} ISK"

  def format_percentage(nil), do: "0%"

  def format_percentage(%Decimal{} = decimal) do
    decimal |> Decimal.to_float() |> format_percentage()
  end

  def format_percentage(percentage) do
    "#{Float.round(percentage, 1)}%"
  end

  def format_ratio(kills, losses) do
    if losses > 0 do
      ratio = kills / losses
      Float.round(ratio, 2)
    else
      kills
    end
  end

  def danger_badge(rating) do
    stars = String.duplicate("⭐", rating)

    class =
      case rating do
        5 -> "bg-red-600 text-white"
        4 -> "bg-red-500 text-white"
        3 -> "bg-yellow-500 text-black"
        2 -> "bg-blue-500 text-white"
        _ -> "bg-gray-500 text-white"
      end

    {stars, class}
  end

  def activity_badge(activity) do
    case activity do
      "solo_pvp" -> {"🎯 Solo PvP", "bg-purple-600 text-white"}
      "small_gang" -> {"👥 Small Gang", "bg-blue-600 text-white"}
      "fleet_pvp" -> {"🚢 Fleet PvP", "bg-green-600 text-white"}
      _ -> {"❓ Unknown", "bg-gray-600 text-white"}
    end
  end

  def gang_size_badge(size) do
    case size do
      "solo" -> {"🎯 Solo", "bg-purple-600 text-white"}
      "small_gang" -> {"👥 Small Gang", "bg-blue-600 text-white"}
      "medium_gang" -> {"👥 Medium Gang", "bg-yellow-600 text-black"}
      "fleet" -> {"🚢 Fleet", "bg-green-600 text-white"}
      _ -> {"❓ Unknown", "bg-gray-600 text-white"}
    end
  end
end
