defmodule EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.WormholeCompatibility do
  @moduledoc """
  Handles wormhole compatibility analysis and mass calculations.

  This module provides functionality for calculating fleet mass,
  wormhole viability, jump sequences, and mass efficiency.
  """

  alias EveDmv.Intelligence.Analyzers.MassCalculator

  require Logger

  @doc """
  Calculate wormhole viability for a fleet.

  ## Parameters
  - `fleet_data` - Fleet analysis data
  - `wormhole` - Wormhole information

  ## Returns
  - Map with viability analysis and recommendations
  """
  def calculate_wormhole_viability(fleet_data, wormhole) do
    total_mass = Map.get(fleet_data, :total_mass, 0)
    ship_count = Map.get(fleet_data, :ship_count, 0)
    avg_ship_mass = Map.get(fleet_data, :average_ship_mass, 0)

    max_mass = Map.get(wormhole, :max_mass, 0)
    max_ship_mass = Map.get(wormhole, :max_ship_mass, 0)

    # Check if individual ships can jump
    ships_that_can_jump = if avg_ship_mass <= max_ship_mass, do: ship_count, else: 0

    # Check if fleet can jump
    can_jump = total_mass <= max_mass and avg_ship_mass <= max_ship_mass

    # Calculate mass efficiency (how much of the wormhole capacity we use)
    mass_efficiency = if max_mass > 0, do: min(100, total_mass / max_mass * 100), else: 0

    # Generate recommended jump order
    jump_order =
      if can_jump do
        # Simple recommendation: heaviest ships first
        ["Heavy ships first", "Medium ships next", "Light ships last"]
      else
        []
      end

    %{
      can_jump: can_jump,
      mass_efficiency: mass_efficiency,
      ships_that_can_jump: ships_that_can_jump,
      recommended_jump_order: jump_order
    }
  end

  @doc """
  Calculate optimal jump sequence for mass management.

  ## Parameters
  - `ships` - List of ships to calculate sequence for
  - `wormhole` - Wormhole information

  ## Returns
  - Optimal jump sequence from MassCalculator
  """
  def calculate_jump_mass_sequence(ships, wormhole) do
    MassCalculator.calculate_jump_mass_sequence(ships, wormhole)
  end

  @doc """
  Calculate ship mass based on ship name.

  ## Parameters
  - `ship_name` - Name of the ship

  ## Returns
  - Mass of the ship from MassCalculator
  """
  def calculate_ship_mass(ship_name) do
    MassCalculator.calculate_ship_mass(ship_name)
  end

  @doc """
  Get wormhole mass limit by type.

  ## Parameters
  - `wormhole_type` - Type of wormhole

  ## Returns
  - Mass limit for the wormhole type
  """
  def wormhole_mass_limit(wormhole_type) do
    MassCalculator.wormhole_mass_limit(wormhole_type)
  end

  @doc """
  Calculate total fleet mass.

  ## Parameters
  - `fleet_members` - List of fleet members

  ## Returns
  - Total mass of the fleet
  """
  def calculate_total_fleet_mass(fleet_members) when is_list(fleet_members) do
    MassCalculator.calculate_total_fleet_mass(fleet_members)
  end

  @doc """
  Calculate average ship mass.

  ## Parameters
  - `fleet_members` - List of fleet members

  ## Returns
  - Average mass per ship in the fleet
  """
  def calculate_average_ship_mass(fleet_members) when is_list(fleet_members) do
    MassCalculator.calculate_average_ship_mass(fleet_members)
  end

  @doc """
  Check if fleet is compatible with wormhole.

  ## Parameters
  - `fleet_data` - Fleet analysis data
  - `wormhole` - Wormhole information

  ## Returns
  - Boolean indicating compatibility
  """
  def fleet_wormhole_compatible?(fleet_data, wormhole) do
    fleet_total_mass = Map.get(fleet_data, :total_mass, 0)
    fleet_max_ship_mass = Map.get(fleet_data, :max_ship_mass, 0)

    wh_max_mass = Map.get(wormhole, :max_mass, 0)
    wh_max_ship_mass = Map.get(wormhole, :max_ship_mass, 0)

    fleet_total_mass <= wh_max_mass and fleet_max_ship_mass <= wh_max_ship_mass
  end
end
