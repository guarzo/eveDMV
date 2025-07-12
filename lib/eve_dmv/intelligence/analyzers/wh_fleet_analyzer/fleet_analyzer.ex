defmodule EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.FleetAnalyzer do
  @moduledoc """
  Handles fleet composition analysis and effectiveness calculations.

  This module provides comprehensive fleet analysis including composition,
  doctrine compliance, effectiveness metrics, and role distribution.
  """

  alias EveDmv.Intelligence.Analyzers.MassCalculator
  alias EveDmv.Intelligence.Fleet.FleetCompositionAnalyzer
  alias EveDmv.Intelligence.ShipDatabase

  require Logger

  @doc """
  Enhanced fleet composition analysis using ShipDatabase.
  Provides detailed ship-by-ship analysis with wormhole suitability.

  ## Parameters
  - `ship_list` - List of ships to analyze

  ## Returns
  - Detailed fleet composition analysis
  """
  def analyze_enhanced_fleet_composition(ship_list) when is_list(ship_list) do
    FleetCompositionAnalyzer.analyze_enhanced_fleet_composition(ship_list)
  end

  @doc """
  Analyze fleet composition from member data.

  ## Parameters
  - `members` - List of fleet members with ship information

  ## Returns
  - Fleet composition analysis including categories, mass, and compliance
  """
  def analyze_fleet_composition_from_members(members) when is_list(members) do
    if Enum.empty?(members) do
      %{
        total_members: 0,
        ship_categories: %{},
        total_mass: 0,
        doctrine_compliance: 0,
        role_distribution: %{}
      }
    else
      # Aggregate ship categories
      ship_categories =
        members
        |> Enum.group_by(& &1.ship_category)
        |> Enum.map(fn {category, ships} -> {category, length(ships)} end)
        |> Enum.into(%{})

      # Calculate total mass
      total_mass = MassCalculator.calculate_total_fleet_mass(members)

      # Analyze doctrine compliance
      doctrine_compliance = analyze_doctrine_compliance(members).compliance_score

      # Analyze role distribution
      role_distribution =
        members
        |> Enum.group_by(&Map.get(&1, :role, categorize_ship_role(&1.ship_name)))
        |> Enum.map(fn {role, ships} -> {role, length(ships)} end)
        |> Enum.into(%{})

      %{
        total_members: length(members),
        ship_categories: ship_categories,
        total_mass: total_mass,
        doctrine_compliance: doctrine_compliance,
        role_distribution: role_distribution
      }
    end
  end

  @doc """
  Analyze doctrine compliance of a fleet.

  ## Parameters
  - `fleet_members` - List of fleet members

  ## Returns
  - Map with compliance metrics and identified doctrine
  """
  def analyze_doctrine_compliance(fleet_members) when is_list(fleet_members) do
    if Enum.empty?(fleet_members) do
      %{
        compliance_score: 0,
        doctrine_ships: 0,
        off_doctrine_ships: 0,
        identified_doctrine: nil
      }
    else
      # Identify the primary doctrine
      identified_doctrine = identify_fleet_doctrine(fleet_members)

      # Count doctrine vs off-doctrine ships
      {doctrine_ships, off_doctrine_ships} =
        Enum.reduce(fleet_members, {0, 0}, fn member, {doctrine, off_doctrine} ->
          ship_name = Map.get(member, :ship_name, "Unknown")

          if doctrine_ship?(ship_name, identified_doctrine) do
            {doctrine + 1, off_doctrine}
          else
            {doctrine, off_doctrine + 1}
          end
        end)

      total_ships = length(fleet_members)

      compliance_score =
        if total_ships > 0, do: round(doctrine_ships / total_ships * 100), else: 0

      %{
        compliance_score: compliance_score,
        doctrine_ships: doctrine_ships,
        off_doctrine_ships: off_doctrine_ships,
        identified_doctrine: identified_doctrine
      }
    end
  end

  @doc """
  Calculate fleet effectiveness metrics.

  ## Parameters
  - `fleet_analysis` - Fleet analysis data

  ## Returns
  - Map with effectiveness ratings and capabilities
  """
  def calculate_fleet_effectiveness(fleet_analysis) do
    total_members = Map.get(fleet_analysis, :total_members, 0)
    ship_categories = Map.get(fleet_analysis, :ship_categories, %{})
    role_distribution = Map.get(fleet_analysis, :role_distribution, %{})
    doctrine_compliance = Map.get(fleet_analysis, :doctrine_compliance, 0)

    if total_members == 0 do
      %{
        overall_effectiveness: 0,
        dps_rating: 0,
        survivability_rating: 0,
        flexibility_rating: 0,
        fc_capability: false,
        estimated_dps: 0,
        estimated_ehp: 0,
        logistics_ratio: 0,
        force_multiplier: 0
      }
    else
      # Calculate DPS ships from multiple sources (be defensive about data types)
      dps_ships =
        safe_get_count(role_distribution, "dps") +
          safe_get_count(role_distribution, :dps) +
          safe_get_count(ship_categories, "battlecruiser") +
          safe_get_count(ship_categories, "cruiser") +
          safe_get_count(ship_categories, "destroyer") +
          safe_get_count(ship_categories, "frigate")

      # Calculate logistics ships from multiple sources
      logi_ships =
        safe_get_count(role_distribution, "logistics") +
          safe_get_count(role_distribution, :logistics) +
          safe_get_count(ship_categories, "logistics")

      # Calculate EWAR ships
      ewar_ships =
        safe_get_count(role_distribution, "ewar") +
          safe_get_count(role_distribution, :ewar)

      # Calculate tackle ships
      tackle_ships =
        safe_get_count(role_distribution, "tackle") +
          safe_get_count(role_distribution, :tackle)

      # Calculate real DPS rating (60% weight on DPS ships, 40% on support)
      dps_ratio = dps_ships / total_members
      support_ratio = (logi_ships + ewar_ships + tackle_ships) / total_members
      dps_rating = min(100, round(dps_ratio * 60 + support_ratio * 40))

      # Calculate survivability (logistics critical, diminishing returns)
      logi_ratio = logi_ships / total_members

      survivability_rating =
        cond do
          # Excellent logistics coverage
          logi_ratio >= 0.2 -> 90
          # Good coverage
          logi_ratio >= 0.15 -> 75
          # Adequate coverage
          logi_ratio >= 0.1 -> 60
          # Minimal coverage
          logi_ratio >= 0.05 -> 40
          # Some logistics
          logi_ships > 0 -> 25
          # No logistics
          true -> 10
        end

      # Calculate flexibility based on ship type diversity and roles
      ship_type_count = map_size(ship_categories)
      role_count = map_size(role_distribution)
      base_flexibility = min(100, ship_type_count * 10 + role_count * 15)
      flexibility_rating = round(base_flexibility)

      # Check FC capability (command ships or designated FCs)
      fc_capable =
        safe_get_count(role_distribution, "fc") > 0 or
          safe_get_count(role_distribution, :fc) > 0 or
          safe_get_count(ship_categories, "command_ship") > 0

      # Calculate estimated fleet DPS (rough approximation)
      estimated_dps = calculate_estimated_fleet_dps(dps_ships, ship_categories)

      # Calculate estimated EHP (rough approximation)
      estimated_ehp = calculate_estimated_fleet_ehp(total_members, logi_ships, ship_categories)

      # Calculate force multiplier (EWAR + logistics effectiveness)
      force_multiplier = min(100, round((ewar_ships + logi_ships) / max(1, total_members) * 100))

      # Calculate overall effectiveness with weighted factors
      overall_effectiveness =
        round(
          dps_rating * 0.3 +
            survivability_rating * 0.3 +
            flexibility_rating * 0.2 +
            doctrine_compliance * 0.1 +
            if(fc_capable, do: 10, else: 0)
        )

      %{
        overall_effectiveness: min(100, overall_effectiveness),
        dps_rating: dps_rating,
        survivability_rating: survivability_rating,
        flexibility_rating: flexibility_rating,
        fc_capability: fc_capable,
        estimated_dps: estimated_dps,
        estimated_ehp: estimated_ehp,
        logistics_ratio: round(logi_ratio * 100),
        force_multiplier: force_multiplier
      }
    end
  end

  @doc """
  Recommend fleet improvements.

  ## Parameters
  - `fleet_data` - Fleet analysis data

  ## Returns
  - Map with improvement recommendations
  """
  def recommend_fleet_improvements(fleet_data) do
    effectiveness = Map.get(fleet_data, :effectiveness_metrics, %{})
    role_distribution = Map.get(fleet_data, :role_distribution, %{})
    doctrine_compliance = Map.get(fleet_data, :doctrine_compliance, 0)

    # Check survivability
    survivability = Map.get(effectiveness, :survivability_rating, 0)
    logi_count = Map.get(role_distribution, "logistics", 0)

    {priority_improvements, suggested_additions} =
      cond do
        survivability < 50 and logi_count == 0 ->
          {["Add logistics ships immediately"], ["Guardian", "Scimitar"]}

        survivability < 50 ->
          {["Increase logistics count"], []}

        true ->
          {[], []}
      end

    # Check FC capability
    fc_capable = Map.get(effectiveness, :fc_capability, false)

    {priority_improvements_2, suggested_additions_2} =
      if fc_capable do
        {priority_improvements, suggested_additions}
      else
        {["Add fleet commander ship" | priority_improvements],
         ["Damnation", "Nighthawk" | suggested_additions]}
      end

    # Check doctrine compliance
    doctrine_suggestions =
      if doctrine_compliance < 70 do
        ["Standardize ship types", "Remove off-doctrine ships"]
      else
        []
      end

    # Role recommendations
    role_recommendations = %{
      "logistics" => "Increase to 20-25% of fleet",
      "dps" => "Should be 60-70% of fleet",
      "tackle" => "Add fast tackle for mobility",
      "ewar" => "Consider EWAR for force multiplication"
    }

    %{
      priority_improvements: priority_improvements_2,
      suggested_additions: suggested_additions_2,
      role_recommendations: role_recommendations,
      doctrine_suggestions: doctrine_suggestions
    }
  end

  @doc """
  Analyze fleet roles and balance.

  ## Parameters
  - `fleet_members` - List of fleet members

  ## Returns
  - Map with role analysis and recommendations
  """
  def analyze_fleet_roles(fleet_members) when is_list(fleet_members) do
    if Enum.empty?(fleet_members) do
      %{
        role_balance: %{},
        missing_roles: [],
        role_coverage: %{},
        recommended_ratio: %{}
      }
    else
      # Categorize each member by role
      role_counts =
        fleet_members
        |> Enum.group_by(fn member ->
          ship_name = Map.get(member, :ship_name, "Unknown")
          categorize_ship_role(ship_name)
        end)
        |> Enum.map(fn {role, members} -> {role, length(members)} end)
        |> Enum.into(%{})

      total_members = length(fleet_members)

      # Calculate role coverage percentages
      role_coverage =
        role_counts
        |> Enum.map(fn {role, count} ->
          {role, round(count / total_members * 100)}
        end)
        |> Enum.into(%{})

      # Define recommended ratios
      recommended_ratio = %{
        "dps" => 60,
        "logistics" => 20,
        "fc" => 10,
        "tackle" => 5,
        "ewar" => 5
      }

      # Identify missing critical roles
      missing_roles = []

      missing_roles =
        if Map.get(role_counts, "logistics", 0) == 0,
          do: ["logistics" | missing_roles],
          else: missing_roles

      missing_roles =
        if Map.get(role_counts, "fc", 0) == 0, do: ["fc" | missing_roles], else: missing_roles

      missing_roles =
        if Map.get(role_counts, "tackle", 0) == 0,
          do: ["tackle" | missing_roles],
          else: missing_roles

      %{
        role_balance: role_counts,
        missing_roles: missing_roles,
        role_coverage: role_coverage,
        recommended_ratio: recommended_ratio
      }
    end
  end

  @doc """
  Categorize ship role based on ship name.

  ## Parameters
  - `ship_name` - Name of the ship

  ## Returns
  - String representing the ship's role
  """
  def categorize_ship_role(ship_name) do
    ShipDatabase.get_ship_role(ship_name)
  end

  @doc """
  Check if ship is part of a specific doctrine.

  ## Parameters
  - `ship_name` - Name of the ship
  - `doctrine` - Doctrine to check against

  ## Returns
  - Boolean indicating if ship is part of doctrine
  """
  def doctrine_ship?(ship_name, doctrine) do
    ShipDatabase.doctrine_ship?(ship_name, doctrine)
  end

  @doc """
  Calculate logistics ratio for a fleet.

  ## Parameters
  - `fleet_data` - Fleet analysis data

  ## Returns
  - Float representing logistics ratio (0.0 to 1.0)
  """
  def calculate_logistics_ratio(fleet_data) do
    total_members = Map.get(fleet_data, :total_members, 0)
    ship_categories = Map.get(fleet_data, :ship_categories, %{})
    logi_count = Map.get(ship_categories, "logistics", 0)

    if total_members > 0, do: logi_count / total_members, else: 0.0
  end

  @doc """
  Identify the primary doctrine of a fleet.

  ## Parameters
  - `fleet_members` - List of fleet members

  ## Returns
  - String representing the identified doctrine
  """
  # Helper functions for safe data access
  defp safe_get_count(map, key) when is_map(map) do
    case Map.get(map, key, 0) do
      count when is_integer(count) -> count
      _ -> 0
    end
  end

  defp safe_get_count(_, _), do: 0

  defp calculate_estimated_fleet_dps(_dps_ships, ship_categories) do
    # Rough DPS estimates based on ship classes
    battleship_dps = safe_get_count(ship_categories, "battleship") * 800
    battlecruiser_dps = safe_get_count(ship_categories, "battlecruiser") * 600
    cruiser_dps = safe_get_count(ship_categories, "cruiser") * 400
    destroyer_dps = safe_get_count(ship_categories, "destroyer") * 300
    frigate_dps = safe_get_count(ship_categories, "frigate") * 200

    battleship_dps + battlecruiser_dps + cruiser_dps + destroyer_dps + frigate_dps
  end

  defp calculate_estimated_fleet_ehp(_total_members, logi_ships, ship_categories) do
    # Base EHP per ship type
    base_ehp =
      safe_get_count(ship_categories, "battleship") * 100_000 +
        safe_get_count(ship_categories, "battlecruiser") * 80_000 +
        safe_get_count(ship_categories, "cruiser") * 50_000 +
        safe_get_count(ship_categories, "destroyer") * 15_000 +
        safe_get_count(ship_categories, "frigate") * 8_000

    # Logistics multiplier (each logi ship increases effective HP)
    logi_multiplier = 1 + logi_ships * 0.5
    round(base_ehp * logi_multiplier)
  end

  def identify_fleet_doctrine(fleet_members) when is_list(fleet_members) do
    if Enum.empty?(fleet_members) do
      "unknown"
    else
      # Count ships by potential doctrine
      armor_ships =
        Enum.count(fleet_members, fn member ->
          ship_name = Map.get(member, :ship_name, "Unknown")
          doctrine_ship?(ship_name, "armor_cruiser")
        end)

      shield_ships =
        Enum.count(fleet_members, fn member ->
          ship_name = Map.get(member, :ship_name, "Unknown")
          doctrine_ship?(ship_name, "shield_cruiser")
        end)

      total_ships = length(fleet_members)

      # Determine primary doctrine based on majority
      cond do
        armor_ships / total_ships >= 0.6 -> "armor_cruiser"
        shield_ships / total_ships >= 0.6 -> "shield_cruiser"
        armor_ships > shield_ships -> "armor"
        shield_ships > armor_ships -> "shield"
        # If no clear doctrine, return unknown
        true -> "unknown"
      end
    end
  end
end
