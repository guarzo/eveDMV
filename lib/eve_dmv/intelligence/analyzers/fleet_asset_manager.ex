defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager do
  @moduledoc """
  Fleet Asset Management module for EVE DMV intelligence system.

  This module provides comprehensive asset management capabilities for fleet operations,
  including ship availability tracking, cost estimation, and asset requirement calculations.
  It integrates with ESI (EVE Swagger Interface) for real-time asset data when authentication
  tokens are provided.

  ## Features

  - **Ship Asset Tracking**: Track ship availability across multiple locations
  - **Cost Estimation**: Calculate ship costs based on categories and roles
  - **Asset Availability Analysis**: Determine readiness scores for fleet operations
  - **Ship Requirements**: Generate detailed ship requirements for doctrine compliance
  - **ESI Integration**: Fetch real-time asset data when auth tokens are available
  - **Wormhole Compatibility**: Assess ship suitability for wormhole operations

  ## Authentication

  Asset tracking requires valid ESI authentication tokens. Without tokens, the module
  provides placeholder data and cost estimations based on ship categories and roles.

  ## Usage

  ```elixir
  # Get asset availability for a fleet composition
  {:ok, asset_data} = FleetAssetManager.get_asset_availability(composition, auth_token)

  # Calculate ship costs
  cost = FleetAssetManager.estimate_ship_cost_by_category("Cruiser", "dps")

  # Build ship requirements for doctrine
  requirements = FleetAssetManager.build_ship_requirements(doctrine_template, ship_data)
  ```
  """

  require Logger

  alias EveDmv.Intelligence.{ShipDatabase}
  alias EveDmv.Intelligence.Analyzers.{AssetAnalyzer, MassCalculator}

  @doc """
  Get asset availability for a fleet composition.

  This function analyzes asset availability for a given fleet composition, optionally
  using ESI authentication to fetch real-time asset data. When no auth token is provided,
  it returns placeholder data with cost estimations.

  ## Parameters

  - `composition` - Fleet composition record containing doctrine and requirements
  - `auth_token` - Optional ESI authentication token for real-time asset data

  ## Returns

  - `{:ok, asset_data}` - Asset availability data with readiness scores
  - `{:error, reason}` - Error information if asset fetching fails

  ## Examples

      # Without authentication (placeholder data)
      {:ok, assets} = FleetAssetManager.get_asset_availability(composition, nil)

      # With ESI authentication
      {:ok, assets} = FleetAssetManager.get_asset_availability(composition, auth_token)
  """
  def get_asset_availability(_composition, nil) do
    # No auth token provided, return placeholder data
    {:ok,
     %{
       "asset_tracking_enabled" => false,
       "ship_availability" => %{},
       "readiness_score" => 0,
       "message" => "Asset tracking requires authentication token"
     }}
  end

  def get_asset_availability(composition, auth_token) do
    # Use AssetAnalyzer to get real asset data
    case AssetAnalyzer.analyze_fleet_assets(composition.id, auth_token) do
      {:error, reason} ->
        Logger.warning("Failed to fetch asset data: #{inspect(reason)}")

        # Return empty asset data on failure
        {:ok,
         %{
           "asset_tracking_enabled" => false,
           "ship_availability" => %{},
           "readiness_score" => 0,
           "error" => "Failed to fetch asset data"
         }}

      {:ok, asset_analysis} ->
        {:ok, Map.put(asset_analysis, "asset_tracking_enabled", true)}
    end
  end

  @doc """
  Get detailed ship information including mass, cost, and wormhole suitability.

  This function retrieves comprehensive ship data from the ShipDatabase and calculates
  cost estimates based on ship category and role. It includes wormhole compatibility
  assessment for fleet planning.

  ## Parameters

  - `ship_name` - Name of the ship to analyze

  ## Returns

  Map containing:
  - `:mass_kg` - Ship mass in kilograms
  - `:estimated_cost` - Estimated ship cost in ISK
  - `:category` - Ship category (Frigate, Cruiser, etc.)
  - `:role` - Ship role (dps, logistics, tackle, etc.)
  - `:ship_class` - Ship class classification
  - `:wormhole_suitable` - Boolean indicating WH suitability

  ## Examples

      ship_info = FleetAssetManager.get_ship_info("Ishtar")
      # => %{
      #   mass_kg: 12500000,
      #   estimated_cost: 150000000,
      #   category: "Cruiser",
      #   role: "dps",
      #   ship_class: "heavy_assault_cruiser",
      #   wormhole_suitable: true
      # }
  """
  def get_ship_info(ship_name) do
    # Use centralized ShipDatabase for ship data
    mass_kg = ShipDatabase.get_ship_mass(ship_name)

    # Get ship role and category for cost estimation
    role = ShipDatabase.get_ship_role(ship_name)
    category = ShipDatabase.get_ship_category(ship_name)

    # Estimate cost based on ship category and role
    estimated_cost = estimate_ship_cost_by_category(category, role)

    %{
      mass_kg: mass_kg,
      estimated_cost: estimated_cost,
      category: category,
      role: role,
      ship_class: ShipDatabase.get_ship_class(ship_name),
      wormhole_suitable: ShipDatabase.wormhole_suitable?(ship_name)
    }
  end

  @doc """
  Estimate ship cost based on category and role.

  This function calculates an estimated ship cost using base category costs and
  role-specific multipliers. The estimates are based on typical market values
  and serve as approximations for fleet planning purposes.

  ## Parameters

  - `category` - Ship category (Frigate, Cruiser, Battleship, etc.)
  - `role` - Ship role (dps, logistics, fc, tackle, ewar)

  ## Returns

  Estimated ship cost in ISK as an integer.

  ## Examples

      cost = FleetAssetManager.estimate_ship_cost_by_category("Cruiser", "logistics")
      # => 180000000 (100M base * 1.8 logistics multiplier)

      cost = FleetAssetManager.estimate_ship_cost_by_category("Battleship", "dps")
      # => 300000000 (200M base * 1.5 dps multiplier)
  """
  def estimate_ship_cost_by_category(category, role) do
    base_cost = get_base_cost_by_category(category)
    role_multiplier = get_role_multiplier(role)
    round(base_cost * role_multiplier)
  end

  @doc """
  Get base cost for a ship category.

  This function returns the base cost estimate for different ship categories,
  representing typical hull costs without fittings or special roles.

  ## Parameters

  - `category` - Ship category string

  ## Returns

  Base cost in ISK as an integer.

  ## Ship Category Costs

  - Frigate: 15M ISK
  - Destroyer: 25M ISK
  - Cruiser: 100M ISK
  - Battlecruiser: 150M ISK
  - Battleship: 200M ISK
  - Capital: 2B ISK
  - Supercapital: 20B ISK
  - Unknown: 50M ISK (default)

  ## Examples

      cost = FleetAssetManager.get_base_cost_by_category("Cruiser")
      # => 100000000

      cost = FleetAssetManager.get_base_cost_by_category("Capital")
      # => 2000000000
  """
  def get_base_cost_by_category(category) do
    category_costs = %{
      "Frigate" => 15_000_000,
      "Destroyer" => 25_000_000,
      "Cruiser" => 100_000_000,
      "Battlecruiser" => 150_000_000,
      "Battleship" => 200_000_000,
      "Capital" => 2_000_000_000,
      "Supercapital" => 20_000_000_000
    }

    Map.get(category_costs, category, 50_000_000)
  end

  @doc """
  Get role-specific cost multiplier.

  This function returns multipliers that adjust base ship costs based on the
  ship's role in fleet operations. Specialized roles typically require more
  expensive ships and fittings.

  ## Parameters

  - `role` - Ship role string

  ## Returns

  Multiplier as a float.

  ## Role Multipliers

  - FC (Fleet Commander): 2.5x - Command ships are expensive
  - Logistics: 1.8x - Logistics ships cost more due to specialized modules
  - DPS: 1.5x - T3/HACs are pricey
  - EWAR: 1.2x - EWAR ships moderate cost increase
  - Tackle: 1.0x - Interceptors are base cost
  - Unknown: 1.0x (default)

  ## Examples

      multiplier = FleetAssetManager.get_role_multiplier("logistics")
      # => 1.8

      multiplier = FleetAssetManager.get_role_multiplier("fc")
      # => 2.5
  """
  def get_role_multiplier(role) do
    role_multipliers = %{
      # Command ships are expensive
      "fc" => 2.5,
      # Logistics ships cost more
      "logistics" => 1.8,
      # T3/HACs are pricey
      "dps" => 1.5,
      # Interceptors are base cost
      "tackle" => 1.0,
      # EWAR ships moderate cost
      "ewar" => 1.2
    }

    Map.get(role_multipliers, role, 1.0)
  end

  @doc """
  Build comprehensive ship requirements for a doctrine template.

  This function generates detailed ship requirements based on a doctrine template,
  including quantities needed, mass calculations, cost estimates, and wormhole
  compatibility assessments. It creates a complete asset manifest for fleet planning.

  ## Parameters

  - `doctrine_template` - Doctrine configuration with roles and ship preferences
  - `ship_data` - Ship information data collected from ShipDatabase

  ## Returns

  Map with ship type IDs as keys and requirement details as values.

  ## Requirement Details

  Each ship requirement includes:
  - `ship_name` - Ship name
  - `role` - Assigned role in doctrine
  - `quantity_needed` - Required quantity
  - `quantity_available` - Available quantity (placeholder: 5)
  - `mass_kg` - Ship mass in kilograms
  - `estimated_cost` - Estimated cost per ship
  - `category` - Ship category
  - `ship_class` - Ship class
  - `wormhole_suitable` - Boolean for WH suitability
  - `wormhole_suitability` - Detailed WH compatibility data

  ## Examples

      requirements = FleetAssetManager.build_ship_requirements(doctrine_template, ship_data)
      # Returns comprehensive ship requirements for fleet planning
  """
  def build_ship_requirements(doctrine_template, ship_data) do
    doctrine_template
    |> Enum.reduce(%{}, fn {role, role_config}, acc ->
      preferred_ships = role_config["preferred_ships"] || []
      required_count = role_config["required"] || 1

      Enum.reduce(preferred_ships, acc, fn ship_name, acc2 ->
        ship_info = ship_data[ship_name] || %{mass_kg: 10_000_000, estimated_cost: 50_000_000}

        # Get wormhole restrictions from ShipDatabase
        ship_class = ShipDatabase.get_ship_class(ship_name)
        wh_restrictions = ShipDatabase.get_wormhole_restrictions(ship_class)

        # Use a hash of ship_name as type_id for demo purposes
        type_id = :erlang.phash2(ship_name) |> Integer.to_string()

        Map.put(acc2, type_id, %{
          "ship_name" => ship_name,
          "role" => role,
          "quantity_needed" => required_count,
          # Placeholder
          "quantity_available" => 5,
          "mass_kg" => ship_info.mass_kg,
          "estimated_cost" => ship_info.estimated_cost,
          "category" => ship_info.category,
          "ship_class" => ship_class,
          "wormhole_suitable" => ship_info.wormhole_suitable,
          "wormhole_suitability" => %{
            "small_wormholes" => wh_restrictions.can_pass_small,
            "medium_wormholes" => wh_restrictions.can_pass_medium,
            "large_wormholes" => wh_restrictions.can_pass_large,
            "xl_wormholes" => wh_restrictions.can_pass_xl,
            "mass_efficiency" => MassCalculator.calculate_ship_mass_efficiency(ship_info.mass_kg)
          }
        })
      end)
    end)
  end

  @doc """
  Calculate total asset value for a fleet composition.

  This function calculates the total estimated value of all ships required
  for a fleet composition, useful for budgeting and insurance planning.

  ## Parameters

  - `ship_requirements` - Ship requirements map from build_ship_requirements/2

  ## Returns

  Total estimated value in ISK as an integer.

  ## Examples

      total_value = FleetAssetManager.calculate_total_asset_value(ship_requirements)
      # => 5000000000 (5B ISK total fleet value)
  """
  def calculate_total_asset_value(ship_requirements) when is_map(ship_requirements) do
    ship_requirements
    |> Enum.reduce(0, fn {_type_id, ship_data}, acc ->
      cost = Map.get(ship_data, "estimated_cost", 0)
      quantity = Map.get(ship_data, "quantity_needed", 1)
      acc + cost * quantity
    end)
  end

  @doc """
  Analyze asset readiness for immediate fleet deployment.

  This function evaluates how ready a fleet is for immediate deployment
  based on asset availability, ship requirements, and pilot assignments.

  ## Parameters

  - `ship_requirements` - Ship requirements from build_ship_requirements/2
  - `asset_availability` - Asset availability data from get_asset_availability/2

  ## Returns

  Readiness analysis map with:
  - `:overall_readiness` - Overall readiness percentage (0-100)
  - `:missing_ships` - List of ships that are short
  - `:surplus_ships` - List of ships with excess availability
  - `:deployment_blockers` - Critical missing assets that prevent deployment

  ## Examples

      readiness = FleetAssetManager.analyze_asset_readiness(ship_requirements, asset_data)
      # => %{
      #   overall_readiness: 85,
      #   missing_ships: ["Guardian", "Scimitar"],
      #   surplus_ships: ["Ishtar"],
      #   deployment_blockers: ["Guardian"]
      # }
  """
  def analyze_asset_readiness(ship_requirements, asset_availability) do
    # Extract ship availability data
    _ship_availability = Map.get(asset_availability, "ship_availability", %{})

    # Calculate readiness for each ship type
    ship_readiness =
      ship_requirements
      |> Enum.map(fn {_type_id, ship_data} ->
        ship_name = Map.get(ship_data, "ship_name", "Unknown")
        needed = Map.get(ship_data, "quantity_needed", 1)
        available = Map.get(ship_data, "quantity_available", 0)

        readiness_ratio = if needed > 0, do: min(1.0, available / needed), else: 1.0

        %{
          ship_name: ship_name,
          needed: needed,
          available: available,
          readiness_ratio: readiness_ratio,
          is_critical: Map.get(ship_data, "role") in ["logistics", "fc"]
        }
      end)

    # Calculate overall readiness
    overall_readiness =
      if length(ship_readiness) > 0 do
        avg_readiness =
          Enum.sum(Enum.map(ship_readiness, & &1.readiness_ratio)) / length(ship_readiness)

        round(avg_readiness * 100)
      else
        0
      end

    # Identify missing ships
    missing_ships =
      ship_readiness
      |> Enum.filter(fn ship -> ship.available < ship.needed end)
      |> Enum.map(& &1.ship_name)

    # Identify surplus ships
    surplus_ships =
      ship_readiness
      |> Enum.filter(fn ship -> ship.available > ship.needed end)
      |> Enum.map(& &1.ship_name)

    # Identify deployment blockers (critical missing ships)
    deployment_blockers =
      ship_readiness
      |> Enum.filter(fn ship -> ship.is_critical and ship.available < ship.needed end)
      |> Enum.map(& &1.ship_name)

    %{
      overall_readiness: overall_readiness,
      missing_ships: missing_ships,
      surplus_ships: surplus_ships,
      deployment_blockers: deployment_blockers
    }
  end

  @doc """
  Calculate asset distribution across locations.

  This function analyzes how assets are distributed across different stations
  and systems, useful for logistics planning and asset consolidation.

  ## Parameters

  - `asset_data` - Asset data from ESI or mock data

  ## Returns

  Map with location analysis:
  - `:locations` - List of locations with asset counts
  - `:consolidation_score` - How consolidated assets are (0-100)
  - `:primary_staging` - Recommended primary staging location
  - `:logistics_complexity` - Complexity score for moving assets

  ## Examples

      distribution = FleetAssetManager.calculate_asset_distribution(asset_data)
      # => %{
      #   locations: [%{name: "Jita IV - Moon 4", ships: 15}, ...],
      #   consolidation_score: 75,
      #   primary_staging: "Jita IV - Moon 4",
      #   logistics_complexity: 25
      # }
  """
  def calculate_asset_distribution(_asset_data) do
    # Mock implementation for demonstration
    # In production, this would analyze real ESI asset data
    %{
      locations: [
        %{name: "Jita IV - Moon 4", ships: 15, systems: ["Jita"]},
        %{name: "Amarr VIII - Emperor Family Academy", ships: 8, systems: ["Amarr"]},
        %{name: "Dodixie IX - Moon 20", ships: 3, systems: ["Dodixie"]}
      ],
      consolidation_score: 65,
      primary_staging: "Jita IV - Moon 4",
      logistics_complexity: 35
    }
  end

  @doc """
  Generate asset acquisition recommendations.

  This function analyzes current asset availability against requirements and
  generates recommendations for acquiring missing assets, including market
  analysis and cost optimization suggestions.

  ## Parameters

  - `ship_requirements` - Ship requirements from build_ship_requirements/2
  - `current_assets` - Current asset availability data
  - `budget_limit` - Optional budget constraint in ISK

  ## Returns

  Map with acquisition recommendations:
  - `:priority_purchases` - List of high-priority ships to acquire
  - `:budget_recommendations` - Cost-optimized purchase plan
  - `:alternative_ships` - Suggested alternative ships if originals unavailable
  - `:market_analysis` - Market availability and pricing trends

  ## Examples

      recommendations = FleetAssetManager.generate_asset_acquisition_recommendations(
        ship_requirements,
        current_assets,
        1_000_000_000
      )
  """
  def generate_asset_acquisition_recommendations(
        ship_requirements,
        current_assets,
        budget_limit \\ nil
      ) do
    # Analyze gaps between requirements and current assets
    missing_assets = identify_missing_assets(ship_requirements, current_assets)

    # Priority purchases based on role criticality
    priority_purchases =
      missing_assets
      |> Enum.filter(fn asset ->
        role = Map.get(asset, "role", "")
        role in ["logistics", "fc"]
      end)
      |> Enum.sort_by(& &1["estimated_cost"])

    # Budget-constrained recommendations
    budget_recommendations =
      if budget_limit do
        create_budget_optimized_plan(missing_assets, budget_limit)
      else
        missing_assets
      end

    # Alternative ship suggestions
    alternative_ships =
      missing_assets
      |> Enum.map(fn asset ->
        ship_name = Map.get(asset, "ship_name", "")
        role = Map.get(asset, "role", "")
        alternatives = find_alternative_ships(ship_name, role)

        %{
          original_ship: ship_name,
          alternatives: alternatives,
          role: role
        }
      end)

    %{
      priority_purchases: priority_purchases,
      budget_recommendations: budget_recommendations,
      alternative_ships: alternative_ships,
      market_analysis: generate_market_analysis(missing_assets)
    }
  end

  # Private helper functions

  defp identify_missing_assets(ship_requirements, current_assets) do
    _ship_availability = Map.get(current_assets, "ship_availability", %{})

    ship_requirements
    |> Enum.filter(fn {_type_id, ship_data} ->
      needed = Map.get(ship_data, "quantity_needed", 1)
      available = Map.get(ship_data, "quantity_available", 0)
      available < needed
    end)
    |> Enum.map(fn {_type_id, ship_data} ->
      shortage =
        Map.get(ship_data, "quantity_needed", 1) - Map.get(ship_data, "quantity_available", 0)

      Map.put(ship_data, "shortage", shortage)
    end)
  end

  defp create_budget_optimized_plan(missing_assets, budget_limit) do
    # Sort by cost-effectiveness (role importance / cost)
    missing_assets
    |> Enum.map(fn asset ->
      cost = Map.get(asset, "estimated_cost", 0)
      role = Map.get(asset, "role", "")
      shortage = Map.get(asset, "shortage", 1)

      importance = role_importance_score(role)
      total_cost = cost * shortage
      effectiveness = if total_cost > 0, do: importance / total_cost, else: 0

      Map.put(asset, "cost_effectiveness", effectiveness)
    end)
    |> Enum.sort_by(& &1["cost_effectiveness"], :desc)
    |> select_within_budget(budget_limit)
  end

  defp role_importance_score(role) do
    role_scores = %{
      "fc" => 100,
      "logistics" => 90,
      "dps" => 70,
      "tackle" => 60,
      "ewar" => 50
    }

    Map.get(role_scores, role, 40)
  end

  defp select_within_budget(assets, budget_limit) do
    {selected, _remaining_budget} =
      assets
      |> Enum.reduce({[], budget_limit}, fn asset, {selected, remaining_budget} ->
        cost = Map.get(asset, "estimated_cost", 0) * Map.get(asset, "shortage", 1)

        if cost <= remaining_budget do
          {[asset | selected], remaining_budget - cost}
        else
          {selected, remaining_budget}
        end
      end)

    Enum.reverse(selected)
  end

  defp find_alternative_ships(ship_name, role) do
    # Use ShipDatabase to find alternative ships for the same role
    case role do
      "logistics" ->
        ["Guardian", "Scimitar", "Osprey", "Exequror"]
        |> Enum.reject(&(&1 == ship_name))
        |> Enum.take(3)

      "dps" ->
        ["Ishtar", "Cerberus", "Zealot", "Eagle"]
        |> Enum.reject(&(&1 == ship_name))
        |> Enum.take(3)

      "tackle" ->
        ["Stiletto", "Malediction", "Crow", "Ares"]
        |> Enum.reject(&(&1 == ship_name))
        |> Enum.take(3)

      _ ->
        []
    end
  end

  defp generate_market_analysis(missing_assets) do
    # Mock market analysis - in production would connect to market APIs
    %{
      total_estimated_cost: Enum.sum(Enum.map(missing_assets, & &1["estimated_cost"])),
      availability_score: 85,
      price_trend: "stable",
      recommended_markets: ["Jita", "Amarr", "Dodixie"],
      bulk_discount_potential: 5
    }
  end
end
