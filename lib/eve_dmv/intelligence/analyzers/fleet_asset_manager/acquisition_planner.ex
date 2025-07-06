defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.AcquisitionPlanner do
  @moduledoc """
  Asset acquisition planning and market analysis module.

  Provides recommendations for acquiring missing assets, including budget
  optimization, alternative ship suggestions, and market analysis.
  """

  alias EveDmv.Intelligence.Analyzers.FleetAssetManager.ShipCostCalculator

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

  @doc """
  Create a budget-optimized acquisition plan.
  """
  def create_budget_optimized_plan(missing_assets, budget_limit) do
    # Sort by cost-effectiveness (role importance / cost)
    missing_assets
    |> Enum.map(fn asset ->
      cost = Map.get(asset, "estimated_cost", 0)
      role = Map.get(asset, "role", "")
      shortage = Map.get(asset, "shortage", 1)

      importance = ShipCostCalculator.role_importance_score(role)
      total_cost = cost * shortage
      effectiveness = if total_cost > 0, do: importance / total_cost, else: 0

      Map.put(asset, "cost_effectiveness", effectiveness)
    end)
    |> Enum.sort_by(& &1["cost_effectiveness"], :desc)
    |> select_within_budget(budget_limit)
  end

  @doc """
  Find alternative ships for a given role.
  """
  def find_alternative_ships(ship_name, role) do
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

      "fc" ->
        ["Damnation", "Nighthawk", "Claymore", "Sleipnir"]
        |> Enum.reject(&(&1 == ship_name))
        |> Enum.take(3)

      "ewar" ->
        ["Griffin", "Maulus", "Crucifier", "Vigil"]
        |> Enum.reject(&(&1 == ship_name))
        |> Enum.take(3)

      _ ->
        []
    end
  end

  @doc """
  Calculate acquisition timeline based on budget and priorities.
  """
  def calculate_acquisition_timeline(missing_assets, monthly_budget) do
    total_cost = Enum.sum(Enum.map(missing_assets, & &1["estimated_cost"]))

    if monthly_budget <= 0 do
      %{timeline: "impossible", months: :infinity}
    else
      months_needed = ceil(total_cost / monthly_budget)

      %{
        timeline: "#{months_needed} months",
        months: months_needed,
        total_cost: total_cost,
        monthly_budget: monthly_budget
      }
    end
  end

  @doc """
  Generate market analysis for missing assets.
  """
  def generate_market_analysis(missing_assets) do
    # Mock market analysis - in production would connect to market APIs
    total_cost = Enum.sum(Enum.map(missing_assets, & &1["estimated_cost"]))
    ship_count = length(missing_assets)

    %{
      total_estimated_cost: total_cost,
      ship_count: ship_count,
      average_cost_per_ship: if(ship_count > 0, do: div(total_cost, ship_count), else: 0),
      availability_score: 85,
      price_trend: determine_price_trend(missing_assets),
      recommended_markets: ["Jita", "Amarr", "Dodixie"],
      bulk_discount_potential: calculate_bulk_discount_potential(ship_count),
      acquisition_difficulty: assess_acquisition_difficulty(missing_assets)
    }
  end

  @doc """
  Assess acquisition priorities based on role importance.
  """
  def assess_acquisition_priorities(missing_assets) do
    missing_assets
    |> Enum.map(fn asset ->
      role = Map.get(asset, "role", "")
      _cost = Map.get(asset, "estimated_cost", 0)
      importance = ShipCostCalculator.role_importance_score(role)

      priority_level =
        cond do
          role in ["logistics", "fc"] -> "critical"
          role == "dps" -> "high"
          role in ["tackle", "ewar"] -> "medium"
          true -> "low"
        end

      asset
      |> Map.put("importance_score", importance)
      |> Map.put("priority_level", priority_level)
    end)
    |> Enum.sort_by(&{&1["priority_level"], -&1["importance_score"]})
  end

  @doc """
  Calculate shipping and logistics costs for asset distribution.
  """
  def calculate_logistics_costs(acquisition_plan, staging_location \\ "Jita") do
    # 5M ISK base shipping
    base_shipping_cost = 5_000_000

    logistics_analysis = %{
      staging_location: staging_location,
      base_shipping_cost: base_shipping_cost,
      total_ships: length(acquisition_plan),
      estimated_shipping_time: "3-7 days",
      logistics_complexity: determine_logistics_complexity(acquisition_plan)
    }

    total_logistics_cost = base_shipping_cost * length(acquisition_plan)

    Map.put(logistics_analysis, :total_logistics_cost, total_logistics_cost)
  end

  # Private functions

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

  defp determine_price_trend(missing_assets) do
    # Mock implementation - would analyze actual market data
    capital_ships =
      Enum.count(missing_assets, fn asset ->
        Map.get(asset, "category") in ["Capital", "Supercapital"]
      end)

    if capital_ships > 0 do
      "increasing"
    else
      "stable"
    end
  end

  defp calculate_bulk_discount_potential(ship_count) when ship_count >= 10, do: 10
  defp calculate_bulk_discount_potential(ship_count) when ship_count >= 5, do: 5
  defp calculate_bulk_discount_potential(_), do: 0

  defp assess_acquisition_difficulty(missing_assets) do
    capital_count =
      Enum.count(missing_assets, fn asset ->
        Map.get(asset, "category") in ["Capital", "Supercapital"]
      end)

    t3_count =
      Enum.count(missing_assets, fn asset ->
        ship_class = Map.get(asset, "ship_class", "")
        ship_class == :strategic_cruiser
      end)

    cond do
      capital_count > 0 -> "very_high"
      t3_count > 2 -> "high"
      length(missing_assets) > 10 -> "medium"
      true -> "low"
    end
  end

  defp determine_logistics_complexity(acquisition_plan) do
    unique_ship_types =
      acquisition_plan
      |> Enum.map(&Map.get(&1, "ship_name"))
      |> Enum.uniq()
      |> length()

    cond do
      unique_ship_types > 10 -> "high"
      unique_ship_types > 5 -> "medium"
      true -> "low"
    end
  end
end
