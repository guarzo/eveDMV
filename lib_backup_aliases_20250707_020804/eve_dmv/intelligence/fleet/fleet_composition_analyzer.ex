defmodule EveDmv.Intelligence.Fleet.FleetCompositionAnalyzer do
  @moduledoc """
  Fleet composition analysis module for wormhole operations.

  Provides detailed ship-by-ship analysis, role balance evaluation,
  wormhole compatibility assessment, and doctrine compliance scoring.
  """

  alias EveDmv.Intelligence.Analyzers.MassCalculator
  alias EveDmv.Intelligence.ShipDatabase

  @doc """
  Enhanced fleet composition analysis using ShipDatabase.
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
    %{
      name: ship_name,
      category: ShipDatabase.get_ship_category(ship_name),
      mass_kg: ShipDatabase.get_ship_mass(ship_name),
      role: ShipDatabase.get_ship_role(ship_name),
      ship_class: ShipDatabase.get_ship_class(ship_name),
      wormhole_suitable: ShipDatabase.wormhole_suitable?(ship_name),
      is_capital: ShipDatabase.is_capital?(ship_name),
      wh_restrictions:
        ShipDatabase.get_wormhole_restrictions(ShipDatabase.get_ship_class(ship_name))
    }
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
  Analyze fleet wormhole compatibility based on ship masses and restrictions.
  """
  def analyze_fleet_wh_compatibility(ship_analysis) do
    total_mass = Enum.sum(Enum.map(ship_analysis, & &1.mass_kg))

    small_compatible = Enum.count(ship_analysis, & &1.wh_restrictions.can_pass_small)
    medium_compatible = Enum.count(ship_analysis, & &1.wh_restrictions.can_pass_medium)
    large_compatible = Enum.count(ship_analysis, & &1.wh_restrictions.can_pass_large)

    %{
      total_mass: total_mass,
      small_wh_ships: small_compatible,
      medium_wh_ships: medium_compatible,
      large_wh_ships: large_compatible,
      mass_distribution: MassCalculator.calculate_wormhole_compatibility(total_mass),
      average_ship_mass: round(total_mass / length(ship_analysis))
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
          Enum.count(ship_analysis, &ShipDatabase.doctrine_ship?(&1.name, doctrine))

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
    suggestions = []

    # Mass optimization suggestions
    total_mass = Enum.sum(Enum.map(ship_analysis, & &1.mass_kg))

    suggestions =
      if total_mass > 90_000_000 do
        ["Consider lighter ships for better wormhole mobility" | suggestions]
      else
        suggestions
      end

    # Role balance suggestions
    role_counts = Enum.frequencies_by(ship_analysis, & &1.role)
    logi_count = Map.get(role_counts, "logistics", 0)
    dps_count = Map.get(role_counts, "dps", 0)

    suggestions =
      if logi_count == 0 and dps_count > 2 do
        ["Add logistics ships for fleet sustainability" | suggestions]
      else
        suggestions
      end

    # Capital ship warnings
    capital_count = Enum.count(ship_analysis, & &1.is_capital)

    suggestions =
      if capital_count > 0 do
        ["Capital ships restrict wormhole movement - ensure XL wormhole access" | suggestions]
      else
        suggestions
      end

    if Enum.empty?(suggestions) do
      ["Fleet composition appears well-balanced for wormhole operations"]
    else
      suggestions
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
