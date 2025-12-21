defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.RequirementsBuilder do
  @moduledoc """
  Ship requirements building and doctrine planning module.

  Handles the creation of comprehensive ship requirements based on doctrine
  templates, including mass calculations, cost estimates, and wormhole compatibility.

  ## Default Ship Values

  When ship data is unavailable from StaticData, this module uses conservative
  fallback values based on typical cruiser-class specifications:

  - `default_ship_mass_kg` (12,000,000 kg): Approximate mass of a standard T1 cruiser.
    This is a mid-range value that provides reasonable wormhole compatibility
    estimates without being overly optimistic or pessimistic.

  - `default_ship_estimated_cost` (50,000,000 ISK): Conservative estimate for a
    fitted T1 cruiser hull. This value provides a reasonable baseline for
    doctrine cost calculations when specific ship pricing is unavailable.

  These defaults ensure fleet planning calculations can proceed even when
  encountering unknown ship types in doctrine templates.
  """

  alias EveDmv.Intelligence.Analyzers.FleetAssetManager.ShipCostCalculator
  alias EveDmv.Contexts.FleetOperations.Core.MassCalculator

  # =============================================================================
  # Default Ship Configuration Constants
  # =============================================================================

  # Default mass used when ship data is unavailable from StaticData.
  # 12,000,000 kg represents a standard T1 cruiser mass (e.g., Caracal, Thorax).
  # This mid-range value provides reasonable wormhole compatibility estimates
  # for unknown ships without being overly restrictive.
  @default_ship_mass_kg 12_000_000

  # Default cost estimate when ship pricing is unavailable.
  # 50,000,000 ISK represents a conservatively fitted T1 cruiser.
  # This baseline ensures doctrine cost calculations remain reasonable
  # even for unknown ship types.
  @default_ship_estimated_cost 50_000_000

  # =============================================================================
  # Public API - Default Ship Configuration
  # =============================================================================

  @doc """
  Returns the default ship mass in kilograms used when ship data is unavailable.

  The default value of 12,000,000 kg represents a standard T1 cruiser mass,
  providing a reasonable baseline for wormhole compatibility calculations.
  """
  @spec default_ship_mass_kg() :: integer()
  def default_ship_mass_kg, do: @default_ship_mass_kg

  @doc """
  Returns the default estimated ship cost in ISK used when pricing is unavailable.

  The default value of 50,000,000 ISK represents a conservatively fitted T1 cruiser,
  providing a reasonable baseline for doctrine cost calculations.
  """
  @spec default_ship_estimated_cost() :: integer()
  def default_ship_estimated_cost, do: @default_ship_estimated_cost

  @doc """
  Returns a map containing default ship information for fallback scenarios.

  This is used when ship data cannot be retrieved from StaticData, ensuring
  fleet planning calculations can proceed with reasonable estimates.

  ## Returns

  Map containing:
  - `:mass_kg` - Default ship mass (12,000,000 kg)
  - `:estimated_cost` - Default estimated cost (50,000,000 ISK)
  - `:category` - Default category ("Unknown")
  - `:role` - Default role ("unknown")
  - `:ship_class` - Default ship class ("Unknown")
  - `:wormhole_suitable` - Default WH suitability (false)
  """
  @spec default_ship_info() :: map()
  def default_ship_info do
    %{
      mass_kg: @default_ship_mass_kg,
      estimated_cost: @default_ship_estimated_cost,
      category: "Unknown",
      role: "unknown",
      ship_class: "Unknown",
      wormhole_suitable: false
    }
  end

  # =============================================================================
  # Public API - Ship Information
  # =============================================================================

  @doc """
  Get detailed ship information including mass, cost, and wormhole suitability.

  This function retrieves comprehensive ship data from StaticData and calculates
  cost estimates based on ship category and role. It includes wormhole compatibility
  assessment for fleet planning.

  When StaticData returns nil for any field, default values from `default_ship_info/0`
  are used to ensure calculations can proceed.

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
    defaults = default_ship_info()

    # First look up the type_id from the ship name
    case EveDmv.StaticData.get_type_by_name(ship_name) do
      %{type_id: type_id} when is_integer(type_id) ->
        # Ship found - use real data with fallbacks for any nil values
        mass_result = EveDmv.StaticData.get_ship_mass(type_id)
        mass_kg = if is_number(mass_result), do: mass_result, else: defaults.mass_kg

        role = EveDmv.StaticData.get_ship_role(type_id)
        role = if role == :unknown, do: defaults.role, else: Atom.to_string(role)

        category = EveDmv.StaticData.get_ship_category(type_id)
        category_str = if category, do: Atom.to_string(category), else: defaults.category

        # Estimate cost based on ship category and role, with fallback to default
        estimated_cost =
          case ShipCostCalculator.estimate_ship_cost_by_category(category_str, role) do
            cost when is_number(cost) and cost > 0 -> cost
            _ -> defaults.estimated_cost
          end

        ship_class_result = EveDmv.StaticData.get_ship_class(type_id)

        ship_class =
          if ship_class_result == :unknown,
            do: defaults.ship_class,
            else: Atom.to_string(ship_class_result)

        wormhole_suitable = EveDmv.StaticData.wormhole_suitable?(type_id)
        # Handle :c5_c6_only as truthy for general wormhole suitability
        wormhole_suitable = wormhole_suitable != false

        %{
          mass_kg: mass_kg,
          estimated_cost: estimated_cost,
          category: category_str,
          role: role,
          ship_class: ship_class,
          wormhole_suitable: wormhole_suitable
        }

      _ ->
        # Ship not found - return all defaults
        defaults
    end
  end

  @doc """
  Build comprehensive ship requirements for a doctrine template.

  This function generates detailed ship requirements based on a doctrine template,
  including quantities needed, mass calculations, cost estimates, and wormhole
  compatibility assessments. It creates a complete asset manifest for fleet planning.

  Ships without data in `ship_data` are skipped and logged as warnings.
  Use `build_ship_requirements_with_missing/2` to also receive a list of skipped ships.

  ## Parameters

  - `doctrine_template` - Doctrine configuration with roles and ship preferences
  - `ship_data` - Ship information data collected from StaticData

  ## Returns

  Map with ship type IDs as keys and requirement details as values.

  ## Requirement Details

  Each ship requirement includes:
  - `ship_name` - Ship name
  - `role` - Assigned role in doctrine
  - `quantity_needed` - Required quantity
  - `mass_kg` - Ship mass in kilograms
  - `estimated_cost` - Estimated cost per ship
  - `category` - Ship category
  - `ship_class` - Ship class
  - `wormhole_suitable` - Boolean for WH suitability
  - `wormhole_suitability` - Detailed WH compatibility data
  """
  def build_ship_requirements(doctrine_template, ship_data) do
    {requirements, _missing} = build_ship_requirements_with_missing(doctrine_template, ship_data)
    requirements
  end

  @doc """
  Build ship requirements and return both the requirements and a list of missing ships.

  Returns `{requirements_map, missing_ships_list}` where `missing_ships_list` contains
  tuples of `{ship_name, role}` for ships that were skipped due to missing data.

  ## Example

      {requirements, missing} = build_ship_requirements_with_missing(doctrine, ship_data)
      if missing != [] do
        Logger.warning("Skipped ships due to missing data: \#{inspect(missing)}")
      end
  """
  def build_ship_requirements_with_missing(doctrine_template, ship_data) do
    require Logger

    {requirements, missing} =
      Enum.reduce(doctrine_template, {%{}, []}, fn {role, role_config}, {acc, missing_acc} ->
        preferred_ships = role_config["preferred_ships"] || []
        required_count = role_config["required"] || 1

        Enum.reduce(preferred_ships, {acc, missing_acc}, fn ship_name, {acc2, missing_acc2} ->
          case ship_data[ship_name] do
            nil ->
              Logger.warning(
                "Skipping ship '#{ship_name}' for role '#{role}': no ship data available in ship_data map"
              )

              {acc2, [{ship_name, role} | missing_acc2]}

            ship_info ->
              ship_class = EveDmv.StaticData.get_ship_class(ship_name)
              mass_kg = ship_info.mass_kg

              # Use real type_id from StaticData
              type_id = get_ship_type_id(ship_name)

              # Build ship_analysis map for mass efficiency calculation
              ship_type_id = parse_type_id(type_id)
              role_atom = safe_to_atom(role)
              ship_analysis = %{ship_type_id: ship_type_id, role: role_atom, mass_kg: mass_kg}

              requirement = %{
                "ship_name" => ship_name,
                "role" => role,
                "quantity_needed" => required_count,
                "mass_kg" => mass_kg,
                "estimated_cost" => ship_info.estimated_cost,
                "category" => ship_info.category,
                "ship_class" => ship_class,
                "wormhole_suitable" => ship_info.wormhole_suitable,
                "wormhole_suitability" => %{
                  "can_use_frigate_holes" => is_number(mass_kg) and mass_kg <= 20_000_000,
                  "can_use_cruiser_holes" => is_number(mass_kg) and mass_kg <= 90_000_000,
                  "can_use_battleship_holes" => is_number(mass_kg) and mass_kg <= 300_000_000,
                  "can_use_capital_holes" => is_number(mass_kg) and mass_kg <= 1_800_000_000,
                  "mass_efficiency" => MassCalculator.calculate_ship_mass_efficiency(ship_analysis)
                }
              }

              {Map.put(acc2, type_id, requirement), missing_acc2}
          end
        end)
      end)

    {requirements, Enum.reverse(missing)}
  end

  @doc """
  Build ship requirements from a simple ship list.
  """
  def build_ship_requirements_from_list(ship_list) do
    ship_list
    |> Enum.reduce(%{}, fn ship_name, acc ->
      ship_info = get_ship_info(ship_name)
      type_id = get_ship_type_id(ship_name)

      Map.put(acc, type_id, %{
        "ship_name" => ship_name,
        "role" => ship_info.role,
        "quantity_needed" => 1,
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
          Enum.reject(required_fields, &Map.has_key?(role_config, &1))

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
      Enum.count(ship_requirements, fn {_type_id, ship_data} ->
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

  # Get real type_id from StaticData, returns string for map key consistency
  defp get_ship_type_id(ship_name) do
    case EveDmv.StaticData.get_type_by_name(ship_name) do
      %{type_id: type_id} when is_integer(type_id) ->
        Integer.to_string(type_id)

      _ ->
        # Ship not found in StaticData - log warning and use ship name as fallback
        require Logger
        Logger.warning("Ship not found in StaticData: #{ship_name}")
        "unknown_#{ship_name}"
    end
  end

  defp grade_wormhole_suitability(ratio) when ratio >= 0.9, do: "Excellent"
  defp grade_wormhole_suitability(ratio) when ratio >= 0.7, do: "Good"
  defp grade_wormhole_suitability(ratio) when ratio >= 0.5, do: "Fair"
  defp grade_wormhole_suitability(ratio) when ratio >= 0.3, do: "Poor"
  defp grade_wormhole_suitability(_), do: "Unsuitable"

  # Parse type_id string to integer, returns nil for unknown ships
  defp parse_type_id("unknown_" <> _), do: nil
  defp parse_type_id(type_id) when is_binary(type_id), do: String.to_integer(type_id)
  defp parse_type_id(type_id) when is_integer(type_id), do: type_id

  # Safely convert role to atom, defaulting to :unknown for invalid roles
  defp safe_to_atom(role) when is_atom(role), do: role
  defp safe_to_atom(role) when is_binary(role) do
    String.to_existing_atom(role)
  rescue
    ArgumentError -> :unknown
  end
end
