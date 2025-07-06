defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.ShipCostCalculator do
  @moduledoc """
  Ship cost calculation and estimation module.

  Provides cost estimation capabilities for ships based on categories, roles,
  and market analysis for fleet planning and budgeting purposes.
  """

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

      cost = ShipCostCalculator.estimate_ship_cost_by_category("Cruiser", "logistics")
      # => 180000000 (100M base * 1.8 logistics multiplier)

      cost = ShipCostCalculator.estimate_ship_cost_by_category("Battleship", "dps")
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

  ## Ship Category Costs

  - Frigate: 15M ISK
  - Destroyer: 25M ISK
  - Cruiser: 100M ISK
  - Battlecruiser: 150M ISK
  - Battleship: 200M ISK
  - Capital: 2B ISK
  - Supercapital: 20B ISK
  - Unknown: 50M ISK (default)
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

  ## Role Multipliers

  - FC (Fleet Commander): 2.5x - Command ships are expensive
  - Logistics: 1.8x - Logistics ships cost more due to specialized modules
  - DPS: 1.5x - T3/HACs are pricey
  - EWAR: 1.2x - EWAR ships moderate cost increase
  - Tackle: 1.0x - Interceptors are base cost
  - Unknown: 1.0x (default)
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
  Calculate total asset value for a fleet composition.

  This function calculates the total estimated value of all ships required
  for a fleet composition, useful for budgeting and insurance planning.
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
  Calculate cost breakdown by ship role.
  """
  def calculate_cost_breakdown_by_role(ship_requirements) do
    ship_requirements
    |> Enum.reduce(%{}, fn {_type_id, ship_data}, acc ->
      role = Map.get(ship_data, "role", "unknown")
      cost = Map.get(ship_data, "estimated_cost", 0)
      quantity = Map.get(ship_data, "quantity_needed", 1)
      total_cost = cost * quantity

      Map.update(acc, role, total_cost, &(&1 + total_cost))
    end)
  end

  @doc """
  Calculate cost breakdown by ship category.
  """
  def calculate_cost_breakdown_by_category(ship_requirements) do
    ship_requirements
    |> Enum.reduce(%{}, fn {_type_id, ship_data}, acc ->
      category = Map.get(ship_data, "category", "Unknown")
      cost = Map.get(ship_data, "estimated_cost", 0)
      quantity = Map.get(ship_data, "quantity_needed", 1)
      total_cost = cost * quantity

      Map.update(acc, category, total_cost, &(&1 + total_cost))
    end)
  end

  @doc """
  Get role importance score for cost-effectiveness calculations.
  """
  def role_importance_score(role) do
    role_scores = %{
      "fc" => 100,
      "logistics" => 90,
      "dps" => 70,
      "tackle" => 60,
      "ewar" => 50
    }

    Map.get(role_scores, role, 40)
  end

  @doc """
  Calculate cost per effectiveness ratio.
  """
  def calculate_cost_effectiveness(ship_data) do
    cost = Map.get(ship_data, "estimated_cost", 0)
    role = Map.get(ship_data, "role", "")
    importance = role_importance_score(role)

    if cost > 0 do
      importance / cost
    else
      0.0
    end
  end

  @doc """
  Format ISK amount for display.
  """
  def format_isk(amount) when amount >= 1_000_000_000_000 do
    "#{Float.round(amount / 1_000_000_000_000, 1)}T ISK"
  end

  def format_isk(amount) when amount >= 1_000_000_000 do
    "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
  end

  def format_isk(amount) when amount >= 1_000_000 do
    "#{Float.round(amount / 1_000_000, 1)}M ISK"
  end

  def format_isk(amount) when amount >= 1_000 do
    "#{Float.round(amount / 1_000, 1)}K ISK"
  end

  def format_isk(amount) do
    "#{amount} ISK"
  end
end
