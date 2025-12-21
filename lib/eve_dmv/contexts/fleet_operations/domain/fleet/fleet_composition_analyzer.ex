defmodule EveDmv.Intelligence.Fleet.FleetCompositionAnalyzer do
  @moduledoc """
  Fleet composition analysis module for wormhole operations.

  Provides detailed ship-by-ship analysis, role balance evaluation,
  wormhole compatibility assessment, and doctrine compliance scoring.
  """

  alias EveDmv.Intelligence.Analyzers.MassCalculator

  # Wormhole mass limits in kg - based on EVE Online wormhole mechanics.
  # These are the maximum ship mass that can pass through each wormhole category.
  # Source: EVE Online SDE - wormhole static data.
  @frigate_hole_mass_limit 20_000_000
  @cruiser_hole_mass_limit 90_000_000
  @battleship_hole_mass_limit 300_000_000
  @capital_hole_mass_limit 1_800_000_000
  @kspace_hole_mass_limit 3_000_000_000

  # EVE Online wormhole types mapped to their maximum single-ship mass limits.
  # Wormholes are grouped by ship class compatibility:
  # - Frigate holes (D382, C125): frigates, destroyers
  # - Cruiser holes (D845, A982): cruisers, battlecruisers
  # - Battleship holes (O477, L477, Z971): battleships
  # - Capital holes (B041, A641, X702): capitals except supers/titans
  # - K-space connections (K162): all ships
  @wormhole_mass_limits %{
    "D382" => @frigate_hole_mass_limit,
    "C125" => @frigate_hole_mass_limit,
    "D845" => @cruiser_hole_mass_limit,
    "A982" => @cruiser_hole_mass_limit,
    "O477" => @battleship_hole_mass_limit,
    "L477" => @battleship_hole_mass_limit,
    "Z971" => @battleship_hole_mass_limit,
    "B041" => @capital_hole_mass_limit,
    "A641" => @capital_hole_mass_limit,
    "X702" => @capital_hole_mass_limit,
    "K162" => @kspace_hole_mass_limit
  }

  @doc """
  Enhanced fleet composition analysis using StaticData.
  Provides detailed ship-by-ship analysis with wormhole suitability.
  """
  def analyze_enhanced_fleet_composition(ship_list) when is_list(ship_list) do
    ship_analysis =
      Enum.reject(Enum.map(ship_list, &analyze_individual_ship/1), &is_nil/1)

    %{
      total_ships: length(ship_analysis),
      total_mass: Enum.sum(Enum.map(ship_analysis, & &1.mass_kg)),
      composition_balance: analyze_composition_balance(ship_analysis),
      wormhole_compatibility: analyze_fleet_wh_compatibility(ship_analysis),
      doctrine_compliance: analyze_ship_doctrine_compliance(ship_analysis),
      optimization_suggestions: generate_enhanced_suggestions(ship_analysis)
    }
  end

  @doc """
  Analyze individual ship characteristics and capabilities.
  """
  def analyze_individual_ship(ship_name) do
    mass_kg = EveDmv.StaticData.get_ship_mass(ship_name)

    %{
      name: ship_name,
      category: EveDmv.StaticData.get_ship_category(ship_name),
      mass_kg: mass_kg,
      role: EveDmv.StaticData.get_ship_role(ship_name),
      ship_class: EveDmv.StaticData.get_ship_class(ship_name),
      wormhole_suitable: EveDmv.StaticData.wormhole_suitable?(ship_name),
      is_capital: EveDmv.StaticData.capital?(ship_name),
      passable_wormhole_types: get_passable_wormhole_types(mass_kg)
    }
  end

  # Determine which wormhole types a ship can pass through based on its mass.
  # Uses @wormhole_mass_limits module attribute for consistent data.
  defp get_passable_wormhole_types(nil), do: []

  defp get_passable_wormhole_types(mass_kg) when is_number(mass_kg) do
    @wormhole_mass_limits
    |> Enum.filter(fn {_type, max_mass} -> mass_kg <= max_mass end)
    |> Enum.map(fn {type, _} -> type end)
  end

  @doc """
  Analyze fleet composition balance based on ship roles.

  Returns role distribution ratios and overall balance score.
  """
  def analyze_composition_balance(ship_analysis) do
    role_counts = Enum.frequencies_by(ship_analysis, & &1.role)
    total = length(ship_analysis)

    %{
      dps_ratio: Map.get(role_counts, "dps", 0) / total,
      logistics_ratio: Map.get(role_counts, "logistics", 0) / total,
      tackle_ratio: Map.get(role_counts, "tackle", 0) / total,
      ewar_ratio: Map.get(role_counts, "ewar", 0) / total,
      fc_ratio: Map.get(role_counts, "fc", 0) / total,
      balance_score: calculate_balance_score(role_counts, total)
    }
  end

  @doc """
  Analyze fleet wormhole compatibility based on ship masses.

  Uses real EVE wormhole type identifiers to determine fleet compatibility:
  - Frigate holes (D382, C125): Max 20M kg per ship
  - Cruiser holes (D845, A982): Max 90M kg per ship
  - Battleship holes (O477, L477, Z971): Max 300M kg per ship
  - Capital holes (B041, A641, X702): Max 1.8B kg per ship
  - K-space connections (K162): Max 3B kg per ship
  """
  def analyze_fleet_wh_compatibility(ship_analysis) do
    total_mass = Enum.sum(Enum.map(ship_analysis, & &1.mass_kg))
    ship_count = length(ship_analysis)

    # Count ships by which wormhole categories they can pass through
    # Using real EVE wormhole mass limits
    frigate_hole_compatible =
      Enum.count(ship_analysis, &(is_number(&1.mass_kg) and &1.mass_kg <= @frigate_hole_mass_limit))

    cruiser_hole_compatible =
      Enum.count(ship_analysis, &(is_number(&1.mass_kg) and &1.mass_kg <= @cruiser_hole_mass_limit))

    battleship_hole_compatible =
      Enum.count(
        ship_analysis,
        &(is_number(&1.mass_kg) and &1.mass_kg <= @battleship_hole_mass_limit)
      )

    capital_hole_compatible =
      Enum.count(ship_analysis, &(is_number(&1.mass_kg) and &1.mass_kg <= @capital_hole_mass_limit))

    # Find which wormhole types the entire fleet can use
    # (where all ships can pass)
    fleet_can_use_frigate_holes = frigate_hole_compatible == ship_count
    fleet_can_use_cruiser_holes = cruiser_hole_compatible == ship_count
    fleet_can_use_battleship_holes = battleship_hole_compatible == ship_count
    fleet_can_use_capital_holes = capital_hole_compatible == ship_count

    %{
      total_mass: total_mass,
      average_ship_mass: if(ship_count > 0, do: round(total_mass / ship_count), else: 0),
      mass_distribution: MassCalculator.calculate_wormhole_compatibility(total_mass),
      ship_compatibility: %{
        frigate_holes: frigate_hole_compatible,
        cruiser_holes: cruiser_hole_compatible,
        battleship_holes: battleship_hole_compatible,
        capital_holes: capital_hole_compatible
      },
      fleet_wormhole_access: %{
        frigate_holes: fleet_can_use_frigate_holes,
        cruiser_holes: fleet_can_use_cruiser_holes,
        battleship_holes: fleet_can_use_battleship_holes,
        capital_holes: fleet_can_use_capital_holes
      }
    }
  end

  @doc """
  Analyze ship doctrine compliance against common wormhole doctrines.
  """
  def analyze_ship_doctrine_compliance(ship_analysis) do
    # Check compliance with common WH doctrines
    doctrines = ["armor", "shield", "armor_cruiser", "shield_cruiser"]

    doctrine_scores =
      doctrines
      |> Enum.map(fn doctrine ->
        compliant_ships =
          Enum.count(ship_analysis, &EveDmv.StaticData.doctrine_ship?(&1.name, doctrine))

        {doctrine, compliant_ships / length(ship_analysis)}
      end)
      |> Map.new()

    {best_doctrine, _score} = Enum.max_by(doctrine_scores, fn {_doctrine, score} -> score end)

    %{
      doctrine_scores: doctrine_scores,
      recommended_doctrine: best_doctrine,
      compliance_score: Map.get(doctrine_scores, best_doctrine, 0.0)
    }
  end

  @doc """
  Generate optimization suggestions for fleet composition.
  """
  def generate_enhanced_suggestions(ship_analysis) do
    # Check if any ships exceed cruiser-class wormhole mass limits (D845, A982)
    # These are the most common WH connections
    heavy_ships =
      Enum.count(
        ship_analysis,
        &(is_number(&1.mass_kg) and &1.mass_kg > @cruiser_hole_mass_limit)
      )

    suggestions =
      if heavy_ships > 0 do
        limit_in_millions = div(@cruiser_hole_mass_limit, 1_000_000)

        [
          "#{heavy_ships} ship(s) exceed cruiser-class wormhole limit (#{limit_in_millions}M kg) - consider lighter alternatives"
        ]
      else
        []
      end

    # Role balance suggestions
    role_counts = Enum.frequencies_by(ship_analysis, & &1.role)
    logi_count = Map.get(role_counts, "logistics", 0)
    dps_count = Map.get(role_counts, "dps", 0)

    suggestions_with_logi =
      if logi_count == 0 and dps_count > 2 do
        ["Add logistics ships for fleet sustainability" | suggestions]
      else
        suggestions
      end

    # Capital ship warnings
    capital_count = Enum.count(ship_analysis, & &1.is_capital)

    final_suggestions =
      if capital_count > 0 do
        [
          "Capital ships restrict wormhole movement - ensure XL wormhole access"
          | suggestions_with_logi
        ]
      else
        suggestions_with_logi
      end

    if Enum.empty?(final_suggestions) do
      ["Fleet composition appears well-balanced for wormhole operations"]
    else
      final_suggestions
    end
  end

  # Private helper functions

  defp calculate_balance_score(role_counts, total) do
    # Ideal ratios for balanced WH fleet
    ideal_ratios = %{
      "dps" => 0.6,
      "logistics" => 0.2,
      "tackle" => 0.1,
      "ewar" => 0.05,
      "fc" => 0.05
    }

    actual_ratios =
      Map.new(Enum.map(role_counts, fn {role, count} -> {role, count / total} end))

    # Calculate deviation from ideal
    deviations =
      Enum.map(ideal_ratios, fn {role, ideal} ->
        actual = Map.get(actual_ratios, role, 0.0)
        abs(ideal - actual)
      end)

    # Lower deviation = higher score
    max(0.0, 1.0 - Enum.sum(deviations))
  end
end
