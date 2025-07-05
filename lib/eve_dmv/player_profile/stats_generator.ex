defmodule EveDmv.PlayerProfile.StatsGenerator do
  @moduledoc """
  Statistics generation service for player profiles.

  Handles conversion of intelligence data to player statistics format,
  including calculation of derived metrics, gang preferences, activity
  classification, and statistical transformations.
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Analytics.PlayerStats
  alias EveDmv.IntelligenceEngine

  @doc """
  Create player statistics from character analysis data.

  Analyzes character and converts intelligence data to player stats format.
  """
  def create_player_stats(character_id) do
    # Analyze the character using Intelligence Engine and create player stats
    case IntelligenceEngine.analyze(:character, character_id, scope: :standard) do
      {:ok, analysis} ->
        create_player_stats_from_analysis(character_id, analysis)

      error ->
        error
    end
  end

  @doc """
  Create player statistics from existing analysis data.

  Converts intelligence analysis results to player stats format.
  """
  def create_player_stats_from_analysis(character_id, analysis) do
    # Convert intelligence data to player stats format
    player_data = convert_intel_to_stats(character_id, analysis)
    Ash.create(PlayerStats, player_data, domain: Api)
  end

  @doc """
  Convert intelligence data to player statistics format.

  Transforms character intelligence data into the standardized player stats structure.
  """
  def convert_intel_to_stats(character_id, intelligence_result) do
    # Extract data from Intelligence Engine result format
    combat_stats = get_in(intelligence_result, [:analysis, :combat_stats]) || %{}
    behavioral_patterns = get_in(intelligence_result, [:analysis, :behavioral_patterns]) || %{}
    ship_preferences = get_in(intelligence_result, [:analysis, :ship_preferences]) || %{}

    %{
      character_id: character_id,
      character_name: extract_character_name(intelligence_result),
      total_kills: Map.get(combat_stats, :total_kills, 0),
      total_losses: Map.get(combat_stats, :total_losses, 0),
      solo_kills: Map.get(combat_stats, :solo_kills, 0),
      solo_losses: Map.get(combat_stats, :solo_losses, 0),
      gang_kills: calculate_gang_kills(combat_stats),
      gang_losses: calculate_gang_losses(combat_stats),
      total_isk_destroyed: Map.get(combat_stats, :isk_destroyed, 0) |> ensure_decimal(),
      total_isk_lost: Map.get(combat_stats, :isk_lost, 0) |> ensure_decimal(),
      danger_rating: extract_danger_rating(behavioral_patterns),
      ship_types_used: get_ship_types_count(ship_preferences),
      avg_gang_size: Map.get(behavioral_patterns, :avg_gang_size, 1.0) |> ensure_decimal(),
      preferred_gang_size:
        determine_gang_preference(Map.get(behavioral_patterns, :avg_gang_size)),
      primary_activity: classify_activity(combat_stats, behavioral_patterns),
      last_updated: DateTime.utc_now()
    }
  end

  # Private calculation functions

  defp extract_character_name(intelligence_result) do
    # Try to get character name from various sources in the intelligence result
    get_in(intelligence_result, [:analysis, :character_info, :name]) ||
      get_in(intelligence_result, [:metadata, :character_name]) ||
      "Unknown"
  end

  defp extract_danger_rating(behavioral_patterns) do
    # Calculate danger rating from behavioral patterns
    case Map.get(behavioral_patterns, :engagement_style) do
      "aggressive" -> 4
      "opportunistic" -> 3
      "defensive" -> 2
      _ -> 1
    end
  end

  defp ensure_decimal(value) when is_number(value), do: Decimal.new(value)

  defp ensure_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> Decimal.new(0)
    end
  end

  defp ensure_decimal(_), do: Decimal.new(0)

  defp calculate_gang_kills(combat_stats) do
    total_kills = Map.get(combat_stats, :total_kills, 0)
    solo_kills = Map.get(combat_stats, :solo_kills, 0)
    max(total_kills - solo_kills, 0)
  end

  defp calculate_gang_losses(combat_stats) do
    total_losses = Map.get(combat_stats, :total_losses, 0)
    solo_losses = Map.get(combat_stats, :solo_losses, 0)
    max(total_losses - solo_losses, 0)
  end

  defp get_ship_types_count(ship_preferences) do
    case Map.get(ship_preferences, :ship_usage) do
      ship_usage when is_map(ship_usage) -> map_size(ship_usage)
      ship_list when is_list(ship_list) -> length(ship_list)
      _ -> 0
    end
  end

  defp determine_gang_preference(avg_gang_size) when is_nil(avg_gang_size), do: "solo"

  defp determine_gang_preference(avg_gang_size) when is_number(avg_gang_size) do
    cond do
      avg_gang_size <= 1.2 -> "solo"
      avg_gang_size <= 5.0 -> "small_gang"
      avg_gang_size <= 15.0 -> "medium_gang"
      true -> "fleet"
    end
  end

  defp determine_gang_preference(%Decimal{} = avg_gang_size) do
    avg_gang_size |> Decimal.to_float() |> determine_gang_preference()
  end

  defp determine_gang_preference(_), do: "solo"

  defp classify_activity(combat_stats, behavioral_patterns) do
    # Use behavioral patterns if available, otherwise fall back to kill ratios
    case Map.get(behavioral_patterns, :engagement_style) do
      "solo" -> "solo_pvp"
      "small_gang" -> "small_gang"
      "fleet" -> "fleet_pvp"
      _ -> classify_activity_from_kills(combat_stats)
    end
  end

  defp classify_activity_from_kills(combat_stats) do
    total_kills = Map.get(combat_stats, :total_kills, 0)
    solo_kills = Map.get(combat_stats, :solo_kills, 0)

    solo_ratio =
      if total_kills > 0 do
        solo_kills / total_kills
      else
        0
      end

    cond do
      solo_ratio > 0.7 -> "solo_pvp"
      solo_ratio > 0.3 -> "small_gang"
      true -> "fleet_pvp"
    end
  end
end
