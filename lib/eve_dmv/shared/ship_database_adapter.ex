defmodule EveDmv.Shared.ShipDatabaseAdapter do
  @moduledoc """
  Adapter for migrating from legacy ship database implementations to the consolidated ShipDatabaseService.

  This module provides backwards compatibility while we migrate all consumers to use the new
  unified ShipDatabaseService. It delegates calls from the old APIs to the new service.
  """

  alias EveDmv.Shared.ShipDatabaseService
  alias EveDmv.Result

  # ============================================================================
  # Legacy EveDmv.Intelligence.ShipDatabase compatibility
  # ============================================================================

  @doc """
  Get ship class (legacy API).
  Delegates to ShipDatabaseService.get_ship_class/1
  """
  def get_ship_class(ship_identifier) do
    ShipDatabaseService.get_ship_class(ship_identifier)
  end

  @doc """
  Get ship class by name (legacy API).
  """
  def get_ship_class_by_name(ship_name) when is_binary(ship_name) do
    ShipDatabaseService.get_ship_class(ship_name)
  end

  @doc """
  Get ship mass (legacy API).
  """
  def get_ship_mass(ship_identifier) do
    ShipDatabaseService.get_ship_mass(ship_identifier)
  end

  @doc """
  Get ship mass by name (legacy API).
  """
  def get_ship_mass_by_name(ship_name) when is_binary(ship_name) do
    ShipDatabaseService.get_ship_mass(ship_name)
  end

  @doc """
  Get ship role (legacy API).
  Maps role from new format to legacy format.
  """
  def get_ship_role(ship_name) when is_binary(ship_name) do
    case ShipDatabaseService.get_ship_info(ship_name) do
      {:ok, %{role: role}} -> map_role_to_legacy(role)
      {:error, _} -> :unknown
    end
  end

  @doc """
  Get wormhole restrictions (legacy API).
  """
  def get_wormhole_restrictions(ship_class) do
    # Legacy API expected restrictions based on ship class
    case ship_class do
      :capital ->
        %{
          allowed_in: [],
          restricted_in: ["C5", "C6"],
          mass_warning: "Capital ships have significant mass impact"
        }

      :battleship ->
        %{
          allowed_in: ["C2", "C3", "C4", "C5", "C6"],
          restricted_in: ["C1"],
          mass_warning: "May be restricted in some wormholes"
        }

      _ ->
        %{
          allowed_in: ["C1", "C2", "C3", "C4", "C5", "C6"],
          restricted_in: [],
          mass_warning: nil
        }
    end
  end

  @doc """
  Check if ship is a doctrine ship (legacy API).
  """
  def doctrine_ship?(ship_name, doctrine) do
    # Map doctrine names to roles and check
    doctrine_roles =
      case doctrine do
        "Armor HACs" -> [:combat]
        "Shield Battleships" -> [:combat]
        "Logistics Wing" -> [:logistics]
        _ -> []
      end

    case ShipDatabaseService.get_ship_info(ship_name) do
      {:ok, %{role: role}} -> role in doctrine_roles
      _ -> false
    end
  end

  @doc """
  Get ship category (legacy API).
  """
  def get_ship_category(ship_identifier) do
    ShipDatabaseService.get_ship_category(ship_identifier)
  end

  @doc """
  Get ship category by name (legacy API).
  """
  def get_ship_category_by_name(ship_name) when is_binary(ship_name) do
    ShipDatabaseService.get_ship_category(ship_name)
  end

  @doc """
  Check if ship is capital (legacy API).
  """
  def is_capital?(ship_identifier) do
    case ShipDatabaseService.get_ship_info(ship_identifier) do
      {:ok, %{is_capital: is_capital}} -> is_capital
      _ -> false
    end
  end

  @doc """
  Check if ship is capital by name (legacy API).
  """
  def is_capital_by_name?(ship_name) when is_binary(ship_name) do
    is_capital?(ship_name)
  end

  @doc """
  Check if ship is wormhole suitable (legacy API).
  """
  def wormhole_suitable?(ship_name) do
    ShipDatabaseService.wormhole_suitable?(ship_name)
  end

  @doc """
  Calculate optimal gang size (legacy API).
  """
  def optimal_gang_size(ship_composition) do
    # Estimate based on ship classes in composition
    ship_count = length(ship_composition)

    cond do
      ship_count == 0 -> 5
      ship_count <= 5 -> 5..10
      ship_count <= 15 -> 10..25
      ship_count <= 30 -> 20..40
      true -> 30..50
    end
  end

  # ============================================================================
  # Legacy EveDmv.IntelligenceV2.DataServices.ShipDatabase compatibility
  # ============================================================================

  @doc """
  Get comprehensive ship information (V2 API).
  """
  def get_ship_info(ship_name) when is_binary(ship_name) do
    ShipDatabaseService.get_ship_info(ship_name)
  end

  @doc """
  Calculate fleet mass (V2 API).
  """
  def calculate_fleet_mass(ships) when is_list(ships) do
    ShipDatabaseService.calculate_fleet_mass(ships)
  end

  @doc """
  Check wormhole compatibility (V2 API).
  """
  def check_wormhole_compatibility(ship_name, wormhole_class) do
    ShipDatabaseService.check_wormhole_compatibility(ship_name, wormhole_class)
  end

  @doc """
  Estimate ship cost (V2 API).
  Maps legacy role parameter to new fitting_type.
  """
  def estimate_ship_cost(ship_name, role \\ :general) do
    fitting_type =
      case role do
        :dps -> :standard
        :logistics -> :faction
        :command -> :faction
        :ewar -> :faction
        :tackle -> :cheap
        :covert -> :faction
        _ -> :standard
      end

    ShipDatabaseService.estimate_ship_cost(ship_name, fitting_type)
  end

  @doc """
  Get ships for role (V2 API).
  Maps V2 categories to new role system.
  """
  def get_ships_for_role(category) when is_atom(category) do
    role =
      case category do
        :dps -> :combat
        :logistics -> :logistics
        :ewar -> :ewar
        :tackle -> :tackle
        :command -> :command
        :covert -> :covert
        :capital -> :siege
        _ -> :combat
      end

    ShipDatabaseService.get_ships_by_role(role)
  end

  @doc """
  Calculate mass criticality (V2 API).
  """
  def calculate_mass_criticality(current_mass, total_mass, ship_mass) do
    ShipDatabaseService.calculate_mass_criticality(current_mass, total_mass, ship_mass)
  end

  # ============================================================================
  # Helper functions
  # ============================================================================

  defp map_role_to_legacy(role) do
    case role do
      :combat -> :dps
      :tackle -> :tackle
      :ewar -> :support
      :logistics -> :logi
      :command -> :links
      :covert -> :recon
      :bomber -> :bomber
      :marauder -> :dps
      :versatile -> :flex
      _ -> :unknown
    end
  end

  @doc """
  Migrate a module to use the new ShipDatabaseService.
  This function helps identify all ship database calls in a module.
  """
  def analyze_migration_points(module_path) do
    # This would analyze a module file and identify all calls to old ship database APIs
    # For now, return a placeholder
    {:ok,
     %{
       module: module_path,
       legacy_calls: [],
       migration_status: :pending
     }}
  end
end
