defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.RequirementsBuilder do
  @moduledoc """
  Ship requirements building and doctrine planning module.

  Handles the creation of comprehensive ship requirements based on doctrine
  templates, including mass calculations, cost estimates, and wormhole compatibility.
  """

    alias EveDmv.Intelligence.Analyzers.MassCalculator
    alias EveDmv.Intelligence.ShipDatabase
  alias EveDmv.Intelligence.Analyzers.FleetAssetManager.ShipCostCalculator

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
  """
  def get_ship_info(ship_name) do
    # Use centralized ShipDatabase for ship data
    mass_kg = ShipDatabase.get_ship_mass(ship_name)

    # Get ship role and category for cost estimation
    role = ShipDatabase.get_ship_role(ship_name)
    category = ShipDatabase.get_ship_category(ship_name)

    # Estimate cost based on ship category and role
    estimated_cost = ShipCostCalculator.estimate_ship_cost_by_category(category, role)

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
  """
  def build_ship_requirements(doctrine_template, ship_data) do
    Enum.reduce(doctrine_template, %{}, fn {role, role_config}, acc ->
      preferred_ships = role_config["preferred_ships"] || []
      required_count = role_config["required"] || 1

      Enum.reduce(preferred_ships, acc, fn ship_name, acc2 ->
        ship_info = ship_data[ship_name] || %{mass_kg: 10_000_000, estimated_cost: 50_000_000}

        # Get wormhole restrictions from ShipDatabase
        ship_class = ShipDatabase.get_ship_class(ship_name)
        wh_restrictions = ShipDatabase.get_wormhole_restrictions(ship_class)

        # Use a hash of ship_name as type_id for demo purposes
        hash_value = :erlang.phash2(ship_name)
        type_id = Integer.to_string(hash_value)

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
  Build ship requirements from a simple ship list.
  """
  def build_ship_requirements_from_list(ship_list) do
    ship_list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {ship_name, index}, acc ->
      ship_info = get_ship_info(ship_name)
      type_id = Integer.to_string(index)

      Map.put(acc, type_id, %{
        "ship_name" => ship_name,
        "role" => ship_info.role,
        "quantity_needed" => 1,
        "quantity_available" => 0,
        "mass_kg" => ship_info.mass_kg,
        "estimated_cost" => ship_info.estimated_cost,
        "category" => ship_info.category,
        "ship_class" => ship_info.ship_class,
        "wormhole_suitable" => ship_info.wormhole_suitable
      })
    end)
  end

  @doc """
  Validate doctrine template structure.
  """
  def validate_doctrine_template(doctrine_template) do
    required_fields = ["preferred_ships", "required"]

    validation_results =
      Enum.map(doctrine_template, fn {role, role_config} ->
        missing_fields =
          required_fields
          |> Enum.reject(&Map.has_key?(role_config, &1))

        if missing_fields == [] do
          {:ok, role}
        else
          {:error, {role, missing_fields}}
        end
      end)

    errors = Enum.filter(validation_results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, "Doctrine template is valid"}
    else
      {:error, errors}
    end
  end

  @doc """
  Calculate total requirements by role.
  """
  def calculate_requirements_by_role(ship_requirements) do
    Enum.reduce(ship_requirements, %{}, fn {_type_id, ship_data}, acc ->
      role = Map.get(ship_data, "role", "unknown")
      quantity = Map.get(ship_data, "quantity_needed", 1)

      Map.update(acc, role, quantity, &(&1 + quantity))
    end)
  end

  @doc """
  Calculate total mass of requirements.
  """
  def calculate_total_requirements_mass(ship_requirements) do
    Enum.reduce(ship_requirements, 0, fn {_type_id, ship_data}, acc ->
      mass = Map.get(ship_data, "mass_kg", 0)
      quantity = Map.get(ship_data, "quantity_needed", 1)
      acc + mass * quantity
    end)
  end

  @doc """
  Get wormhole suitability summary for requirements.
  """
  def get_wormhole_suitability_summary(ship_requirements) do
    total_ships = map_size(ship_requirements)

    wh_suitable =
      ship_requirements
      |> Enum.count(fn {_type_id, ship_data} ->
        Map.get(ship_data, "wormhole_suitable", false)
      end)

    suitability_ratio = if total_ships > 0, do: wh_suitable / total_ships, else: 0.0

    %{
      total_ships: total_ships,
      wormhole_suitable: wh_suitable,
      suitability_ratio: suitability_ratio,
      suitability_grade: grade_wormhole_suitability(suitability_ratio)
    }
  end

  # Private functions

  defp grade_wormhole_suitability(ratio) when ratio >= 0.9, do: "Excellent"
  defp grade_wormhole_suitability(ratio) when ratio >= 0.7, do: "Good"
  defp grade_wormhole_suitability(ratio) when ratio >= 0.5, do: "Fair"
  defp grade_wormhole_suitability(ratio) when ratio >= 0.3, do: "Poor"
  defp grade_wormhole_suitability(_), do: "Unsuitable"
end
