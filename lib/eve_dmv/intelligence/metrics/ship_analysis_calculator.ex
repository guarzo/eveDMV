defmodule EveDmv.Intelligence.Metrics.ShipAnalysisCalculator do
  @moduledoc """
  Ship usage analysis calculator for character metrics.

  This module provides ship usage pattern analysis, categorization,
  and preference identification for character intelligence analysis.
  """

  @doc """
  Calculate ship usage patterns and preferences from killmail data.

  Returns comprehensive ship usage analysis including categories,
  preferences, diversity metrics, and capital/T2 usage.
  """
  def calculate_ship_usage(killmail_data) do
    # Group by ship types used
    ship_usage =
      killmail_data
      |> Enum.flat_map(fn killmail ->
        participants = get_participants(killmail)

        participants
        |> Enum.map(fn participant ->
          %{
            ship_type_id: participant[:ship_type_id] || participant["ship_type_id"],
            ship_name: participant[:ship_name] || participant["ship_name"] || "Unknown",
            is_victim: get_is_victim(participant)
          }
        end)
      end)
      |> Enum.group_by(& &1.ship_name)
      |> Enum.map(fn {ship_name, usages} ->
        {ship_name,
         %{
           total_usage: length(usages),
           kills_in_ship: Enum.count(usages, &(!&1.is_victim)),
           losses_in_ship: Enum.count(usages, & &1.is_victim),
           ship_type_id: List.first(usages).ship_type_id
         }}
      end)
      |> Enum.into(%{})

    # Calculate ship categories
    ship_categories = categorize_ships(ship_usage)
    preferred_ships = identify_preferred_ships(ship_usage)

    %{
      ship_usage: ship_usage,
      ship_categories: ship_categories,
      preferred_ships: preferred_ships,
      favorite_ships:
        Enum.map(preferred_ships, fn {ship_name, data} ->
          data
          |> Map.put(:ship_name, ship_name)
          |> Map.put(:count, data.total_usage)
          |> Map.put(:kills, data.kills_in_ship)
          |> Map.put(:losses, data.losses_in_ship)
        end),
      ship_diversity: calculate_ship_diversity(ship_usage),
      capital_usage: extract_capital_ships(ship_usage),
      t2_usage: extract_t2_ships(ship_usage)
    }
  end

  @doc """
  Categorize ships by type from ship usage data.

  Returns categorized ship data grouped by ship class.
  """
  def categorize_ships(ship_usage) do
    categories = %{
      frigates: [],
      destroyers: [],
      cruisers: [],
      battlecruisers: [],
      battleships: [],
      capitals: [],
      other: []
    }

    Enum.reduce(ship_usage, categories, fn {ship_name, _data}, acc ->
      category = categorize_ship_type(ship_name)
      %{acc | category => [ship_name | Map.get(acc, category, [])]}
    end)
  end

  @doc """
  Categorize individual ship type by name.

  Returns atom representing ship category.
  """
  def categorize_ship_type(ship_name) do
    ship_str = String.downcase(to_string(ship_name))

    cond do
      String.contains?(ship_str, "frigate") ->
        :frigates

      String.contains?(ship_str, "destroyer") ->
        :destroyers

      String.contains?(ship_str, "cruiser") and not String.contains?(ship_str, "battle") ->
        :cruisers

      String.contains?(ship_str, "battlecruiser") ->
        :battlecruisers

      String.contains?(ship_str, "battleship") ->
        :battleships

      String.contains?(ship_str, ["carrier", "dreadnought", "titan"]) ->
        :capitals

      true ->
        :other
    end
  end

  @doc """
  Identify preferred ships from usage data.

  Returns top 5 most used ships.
  """
  def identify_preferred_ships(ship_usage) do
    ship_usage
    |> Enum.sort_by(fn {_name, data} -> data.total_usage end, :desc)
    |> Enum.take(5)
    |> Enum.into(%{})
  end

  @doc """
  Calculate ship diversity score.

  Returns diversity score from 0.0 to 1.0.
  """
  def calculate_ship_diversity(ship_usage) do
    ship_count = map_size(ship_usage)
    min(ship_count / 10.0, 1.0)
  end

  @doc """
  Extract capital ships from usage data.

  Returns map of capital ships used.
  """
  def extract_capital_ships(ship_usage) do
    ship_usage
    |> Enum.filter(fn {ship_name, _data} ->
      ship_str = String.downcase(to_string(ship_name))
      String.contains?(ship_str, ["carrier", "dreadnought", "titan", "supercarrier"])
    end)
    |> Enum.into(%{})
  end

  @doc """
  Extract T2 ships from usage data.

  Returns map of T2/Tech2 ships used.
  """
  def extract_t2_ships(ship_usage) do
    ship_usage
    |> Enum.filter(fn {ship_name, _data} ->
      ship_str = String.downcase(to_string(ship_name))
      String.contains?(ship_str, ["t2", "tech2", "assault", "heavy assault", "interceptor"])
    end)
    |> Enum.into(%{})
  end

  @doc """
  Detect capital usage in killmail data.

  Returns boolean indicating if character uses capital ships.
  """
  def detect_capital_usage(killmail_data) do
    capital_ships = ["Dreadnought", "Carrier", "Supercarrier", "Titan", "Force Auxiliary"]

    killmail_data
    |> Enum.flat_map(fn killmail ->
      participants = get_participants(killmail)

      participants
      |> Enum.map(fn participant ->
        participant[:ship_name] || participant["ship_name"]
      end)
    end)
    |> Enum.any?(fn ship_name ->
      ship_str = to_string(ship_name)
      Enum.any?(capital_ships, &String.contains?(ship_str, &1))
    end)
  end

  # Private helper functions

  defp get_participants(killmail) when is_map(killmail) do
    killmail[:participants] || killmail["participants"] || []
  end

  defp get_is_victim(participant) when is_map(participant) do
    participant[:is_victim] || participant["is_victim"] || false
  end
end
