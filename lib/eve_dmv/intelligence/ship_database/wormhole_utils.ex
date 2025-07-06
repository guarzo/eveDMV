defmodule EveDmv.Intelligence.ShipDatabase.WormholeUtils do
  @moduledoc """
  Wormhole utility functions for ship analysis.

  Handles wormhole mass restrictions, ship suitability checks,
  and wormhole-specific tactical analysis.
  """

  alias EveDmv.Intelligence.ShipDatabase.{ShipClassification, ShipMassData, ShipRoleData}

  @doc """
  Get wormhole restrictions for a ship class.
  """
  def get_wormhole_restrictions(ship_class) do
    wormhole_restrictions()[ship_class] ||
      %{
        can_pass_small: false,
        can_pass_medium: false,
        can_pass_large: true,
        can_pass_xl: true
      }
  end

  @doc """
  Check if ship is suitable for wormhole operations.
  """
  def wormhole_suitable?(ship_name) do
    role = ShipRoleData.get_ship_role(ship_name)
    mass = ShipMassData.get_ship_mass_by_name(ship_name)

    # Ships under 350M kg and with useful roles are generally WH suitable
    mass < 350_000_000 and role in ["dps", "logistics", "tackle", "ewar", "fc"]
  end

  @doc """
  Check if a ship can pass through a specific wormhole type.
  """
  def can_pass_wormhole?(ship_name, wormhole_type) do
    ship_class = ShipClassification.get_ship_class_by_name(ship_name)
    restrictions = get_wormhole_restrictions(ship_class)

    case wormhole_type do
      :small -> restrictions.can_pass_small
      :medium -> restrictions.can_pass_medium
      :large -> restrictions.can_pass_large
      :xl -> restrictions.can_pass_xl
      _ -> false
    end
  end

  @doc """
  Calculate total fleet mass for wormhole planning.
  """
  def calculate_fleet_mass(ship_list) do
    ship_list
    |> Enum.map(&ShipMassData.get_ship_mass_by_name/1)
    |> Enum.sum()
  end

  @doc """
  Analyze fleet suitability for wormhole operations.
  """
  def analyze_wormhole_fleet(ship_list) do
    total_mass = calculate_fleet_mass(ship_list)
    suitable_ships = Enum.count(ship_list, &wormhole_suitable?/1)

    mass_analysis = %{
      total_mass: total_mass,
      average_mass: div(total_mass, max(length(ship_list), 1)),
      suitable_for_small_wh: total_mass < 20_000_000,
      suitable_for_medium_wh: total_mass < 300_000_000,
      suitable_for_large_wh: total_mass < 1_800_000_000
    }

    %{
      total_ships: length(ship_list),
      wormhole_suitable_ships: suitable_ships,
      suitability_ratio: suitable_ships / max(length(ship_list), 1),
      mass_analysis: mass_analysis,
      recommendations: generate_wormhole_recommendations(ship_list, mass_analysis)
    }
  end

  @doc """
  Get maximum number of ships that can pass through wormhole given mass limit.
  """
  def max_ships_through_wormhole(ship_list, mass_limit) do
    sorted_ships =
      ship_list
      |> Enum.map(fn ship -> {ship, ShipMassData.get_ship_mass_by_name(ship)} end)
      |> Enum.sort_by(fn {_, mass} -> mass end)

    {ships, _total_mass} =
      Enum.reduce_while(sorted_ships, {[], 0}, fn {ship, mass}, {acc_ships, acc_mass} ->
        new_mass = acc_mass + mass

        if new_mass <= mass_limit do
          {:cont, {[ship | acc_ships], new_mass}}
        else
          {:halt, {acc_ships, acc_mass}}
        end
      end)

    %{
      ships: Enum.reverse(ships),
      count: length(ships),
      total_mass: calculate_fleet_mass(ships),
      remaining_capacity: mass_limit - calculate_fleet_mass(ships)
    }
  end

  # Private functions

  defp wormhole_restrictions do
    %{
      frigate: %{
        can_pass_small: true,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 5_000_000
      },
      destroyer: %{
        can_pass_small: true,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 5_000_000
      },
      cruiser: %{
        can_pass_small: false,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 62_000_000
      },
      battlecruiser: %{
        can_pass_small: false,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 62_000_000
      },
      battleship: %{
        can_pass_small: false,
        can_pass_medium: false,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 375_000_000
      },
      capital: %{
        can_pass_small: false,
        can_pass_medium: false,
        can_pass_large: false,
        can_pass_xl: true,
        max_mass: 1_800_000_000
      }
    }
  end

  defp generate_wormhole_recommendations(ship_list, mass_analysis) do
    recommendations = []

    recommendations =
      if mass_analysis.total_mass > 1_800_000_000 do
        ["Fleet too heavy for most wormholes - consider lighter ships" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Enum.count(ship_list, &wormhole_suitable?/1) < length(ship_list) * 0.7 do
        ["Consider more wormhole-suitable ships (tackle, ewar, logistics)" | recommendations]
      else
        recommendations
      end

    recommendations =
      if mass_analysis.average_mass > 50_000_000 do
        ["Average ship mass is high - may limit wormhole options" | recommendations]
      else
        recommendations
      end

    if recommendations == [] do
      ["Fleet composition suitable for wormhole operations"]
    else
      recommendations
    end
  end
end
