defmodule EveDmv.Shared.ShipAnalysis do
  @moduledoc """
  Shared ship analysis utilities to eliminate code duplication.

  Contains common functions for analyzing ship usage patterns, roles,
  specializations, and other ship-related metrics across the application.
  """

  @doc """
  Analyze ship usage patterns for character statistics.
  """
  def analyze_ship_usage(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{}) || %{}

    # Calculate total usage across all ships
    total_usage =
      ship_usage
      |> Map.values()
      |> Enum.reduce(0, fn ship_data, acc ->
        acc + Map.get(ship_data, "times_used", 0)
      end)

    # Analyze top ships by usage
    top_ships =
      Enum.map(ship_usage, fn {ship_id, ship_data} ->
        times_used = Map.get(ship_data, "times_used", 0)
        usage_percentage = if total_usage > 0, do: times_used / total_usage, else: 0.0

        %{
          ship_id: ship_id,
          ship_name: Map.get(ship_data, "ship_name", "Unknown"),
          ship_group: Map.get(ship_data, "ship_group", "Unknown"),
          times_used: times_used,
          usage_percentage: usage_percentage,
          avg_ship_value: Map.get(ship_data, "avg_value", 0),
          last_used: Map.get(ship_data, "last_used")
        }
      end)
      |> Enum.sort_by(& &1.usage_percentage, :desc)

    # Calculate specialization metrics
    usage_distribution = Enum.map(top_ships, & &1.usage_percentage)
    specialization_index = calculate_specialization_index(usage_distribution)

    %{
      total_ships_used: map_size(ship_usage),
      total_usage_count: total_usage,
      top_ships: Enum.take(top_ships, 10),
      most_used_ship: List.first(top_ships),
      specialization_index: specialization_index,
      ship_diversity: calculate_ship_diversity(ship_usage),
      usage_concentration: calculate_usage_concentration(usage_distribution)
    }
  end

  @doc """
  Analyze role specialization patterns for character statistics.
  """
  def analyze_role_specialization(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{}) || %{}

    # Categorize ships by role
    role_usage =
      Enum.reduce(ship_usage, %{}, fn {_ship_id, ship_data}, acc ->
        ship_group = Map.get(ship_data, "ship_group", "Unknown")
        role = categorize_ship_role(ship_group)
        times_used = Map.get(ship_data, "times_used", 0)

        Map.update(acc, role, times_used, &(&1 + times_used))
      end)

    # Calculate role percentages
    total_role_usage = Enum.sum(Map.values(role_usage))

    role_percentages =
      Enum.map(role_usage, fn {role, usage} ->
        percentage = if total_role_usage > 0, do: usage / total_role_usage, else: 0.0
        {role, %{usage: usage, percentage: percentage}}
      end)
      |> Enum.into(%{})

    # Determine primary and secondary roles
    sorted_roles =
      Enum.sort_by(role_percentages, fn {_role, data} -> data.percentage end, :desc)
    primary_role =
      case List.first(sorted_roles) do
        {role, _data} -> role
        nil -> nil
      end

    secondary_role =
      sorted_roles
      |> Enum.at(1)
      |> case do
        nil -> nil
        {role, _data} -> role
      end

    %{
      role_distribution: role_percentages,
      primary_role: primary_role,
      secondary_role: secondary_role,
      role_specialization_score: calculate_role_specialization(role_percentages),
      role_flexibility: assess_role_flexibility(role_percentages),
      combat_role_focus: determine_combat_focus(role_percentages)
    }
  end

  @doc """
  Calculate specialization index using Gini coefficient.
  """
  def calculate_specialization_index(usage_distribution) do
    if Enum.empty?(usage_distribution), do: 0.0

    # Calculate Gini coefficient as specialization measure
    sorted_usage = Enum.sort(usage_distribution)
    n = length(sorted_usage)

    # Complete specialization if only one ship
    if n <= 1, do: 1.0

    sum_products =
      sorted_usage
      |> Enum.with_index(1)
      |> Enum.map(fn {usage, index} -> usage * index end)
      |> Enum.sum()

    mean_usage = Enum.sum(sorted_usage) / n

    gini = 2 * sum_products / (n * n * mean_usage) - (n + 1) / n
    max(0.0, min(1.0, gini))
  end

  @doc """
  Calculate ship diversity based on number of ships used.
  """
  def calculate_ship_diversity(ship_usage) do
    total_ships = map_size(ship_usage)

    case total_ships do
      0 -> 0.0
      1 -> 0.0
      n when n <= 5 -> 0.3
      n when n <= 10 -> 0.6
      n when n <= 20 -> 0.8
      _ -> 1.0
    end
  end

  @doc """
  Calculate usage concentration (percentage of usage in top ship).
  """
  def calculate_usage_concentration(usage_distribution) do
    if Enum.empty?(usage_distribution), do: 1.0

    # Calculate what percentage of usage is in top ship
    max_usage = Enum.max(usage_distribution, fn -> 0.0 end)
    max_usage
  end

  @doc """
  Categorize ship role based on ship group.
  """
  def categorize_ship_role(ship_group) do
    cond do
      String.contains?(ship_group, ["Battleship", "Dreadnought", "Titan"]) -> :heavy_dps
      String.contains?(ship_group, ["Cruiser", "Destroyer", "Frigate"]) -> :light_dps
      String.contains?(ship_group, ["Logistics", "Logi"]) -> :logistics
      String.contains?(ship_group, ["Interceptor", "Covert"]) -> :tackle
      String.contains?(ship_group, ["Electronic", "ECM"]) -> :ewar
      String.contains?(ship_group, ["Industrial", "Transport"]) -> :industrial
      String.contains?(ship_group, ["Mining"]) -> :mining
      true -> :other
    end
  end

  @doc """
  Calculate role specialization score.
  """
  def calculate_role_specialization(role_percentages) do
    if map_size(role_percentages) == 0, do: 0.0

    max_percentage =
      role_percentages
      |> Map.values()
      |> Enum.map(& &1.percentage)
      |> Enum.max(fn -> 0.0 end)

    max_percentage
  end

  @doc """
  Assess role flexibility based on number of roles with significant usage.
  """
  def assess_role_flexibility(role_percentages) do
    roles_with_significant_usage =
      role_percentages
      |> Enum.count(fn {_role, data} -> data.percentage > 0.1 end)

    case roles_with_significant_usage do
      0..1 -> :highly_specialized
      2 -> :moderately_flexible
      3 -> :flexible
      _ -> :very_flexible
    end
  end

  @doc """
  Determine combat focus based on role distribution.
  """
  def determine_combat_focus(role_percentages) do
    combat_roles = [:heavy_dps, :light_dps, :tackle, :ewar, :logistics]

    combat_percentage =
      Enum.filter(role_percentages, fn {role, _data} -> role in combat_roles end)
      |> Enum.map(fn {_role, data} -> data.percentage end)
      |> Enum.sum()

    cond do
      combat_percentage > 0.8 -> :combat_focused
      combat_percentage > 0.5 -> :mixed_combat
      combat_percentage > 0.2 -> :some_combat
      true -> :non_combatant
    end
  end

  @doc """
  Determine tech level of ship group.
  """
  def determine_tech_level(ship_group) do
    cond do
      String.contains?(ship_group, ["Tech II", "T2"]) -> :tech2
      String.contains?(ship_group, ["Tech III", "T3"]) -> :tech3
      String.contains?(ship_group, ["Faction"]) -> :faction
      true -> :tech1
    end
  end

  @doc """
  Determine ship size based on ship group.
  """
  def determine_ship_size(ship_group) do
    cond do
      String.contains?(ship_group, ["Frigate", "Destroyer"]) -> :small
      String.contains?(ship_group, ["Cruiser"]) -> :medium
      String.contains?(ship_group, ["Battlecruiser", "Battleship"]) -> :large
      String.contains?(ship_group, ["Capital", "Dreadnought", "Titan"]) -> :capital
      true -> :unknown
    end
  end

  @doc """
  Get most used ship from ship usage statistics.
  """
  def get_most_used_ship(ship_usage) do
    if map_size(ship_usage) == 0 do
      nil
    else
      most_used_ship = find_most_used_ship(ship_usage)
      format_ship_usage(most_used_ship)
    end
  end

  @doc """
  Check if character flies capital ships.
  """
  def flies_capitals?(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{}) || %{}

    ship_usage
    |> Enum.any?(fn {_ship_id, ship_data} ->
      ship_group = Map.get(ship_data, "ship_group", "")
      String.contains?(ship_group, ["Capital", "Dreadnought", "Titan", "Supercarrier"])
    end)
  end

  @doc """
  Categorize ship values into brackets.
  """
  def categorize_ship_values(ship_values) do
    if Enum.empty?(ship_values) do
      %{}
    else
      %{
        budget: Enum.count(ship_values, &(&1 < 50_000_000)),
        moderate: Enum.count(ship_values, &(&1 >= 50_000_000 and &1 < 500_000_000)),
        expensive: Enum.count(ship_values, &(&1 >= 500_000_000))
      }
    end
  end

  @doc """
  Determine risk comfort level based on average ship value.
  """
  def determine_risk_comfort(avg_ship_value) do
    cond do
      avg_ship_value > 5_000_000_000 -> :very_high_risk
      avg_ship_value > 1_000_000_000 -> :high_risk
      avg_ship_value > 100_000_000 -> :moderate_risk
      avg_ship_value > 10_000_000 -> :low_risk
      true -> :very_low_risk
    end
  end

  @doc """
  Calculate bling ratio (expensive ships to total ships).
  """
  def calculate_bling_ratio(ship_values) do
    if Enum.empty?(ship_values) do
      0.0
    else
      expensive_count = Enum.count(ship_values, &(&1 > 1_000_000_000))
      expensive_count / length(ship_values)
    end
  end

  defp find_most_used_ship(ship_usage) do
    Enum.max_by(
      ship_usage,
      fn {_ship_id, ship_data} -> Map.get(ship_data, "times_used", 0) end,
      fn -> {nil, %{}} end
    )
  end

  defp format_ship_usage({nil, _}), do: nil
  defp format_ship_usage({_ship_id, ship_data}) do
    %{
      name: Map.get(ship_data, "ship_name", "Unknown"),
      usage: Map.get(ship_data, "times_used", 0)
    }
  end
end
