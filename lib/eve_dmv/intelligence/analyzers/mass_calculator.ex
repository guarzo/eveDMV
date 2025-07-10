defmodule EveDmv.Intelligence.Analyzers.MassCalculator do
  @moduledoc """
  Mass calculation utilities for wormhole fleet operations.

  This module provides comprehensive mass calculation and optimization functions
  for wormhole fleet operations, including:
  - Fleet mass calculations
  - Wormhole compatibility analysis
  - Mass optimization suggestions
  - Transport requirement calculations
  - Jump sequence optimization
  """

  alias EveDmv.Intelligence.ShipDatabase

  @doc """
  Calculate mass efficiency for a fleet doctrine.

  Takes a doctrine template and ship data and returns comprehensive mass analysis
  including total mass, wormhole compatibility, optimization suggestions, and
  transport requirements.

  Returns `{:ok, mass_analysis}` where mass_analysis contains:
  - total_fleet_mass_kg: Total mass of the fleet in kilograms
  - wormhole_compatibility: Compatibility with different wormhole types
  - mass_optimization: Optimization suggestions and efficiency metrics
  - transport_requirements: Transport planning information
  """
  def calculate_mass_efficiency(doctrine_template, ship_data) do
    total_mass = calculate_total_fleet_mass(doctrine_template, ship_data)

    mass_analysis = %{
      "total_fleet_mass_kg" => total_mass,
      "wormhole_compatibility" => calculate_wormhole_compatibility(total_mass),
      "mass_optimization" => generate_mass_optimization_suggestions(doctrine_template, ship_data),
      "transport_requirements" => calculate_transport_requirements(total_mass, doctrine_template)
    }

    {:ok, mass_analysis}
  end

  @doc """
  Calculate total fleet mass from doctrine template and ship data.

  Takes a doctrine template (map of roles with ship preferences) and ship data
  and calculates the total mass of the fleet based on the preferred ships
  and required quantities for each role.

  Returns the total mass in kilograms.
  """
  def calculate_total_fleet_mass(doctrine_template, ship_data) do
    doctrine_template
    |> Enum.map(fn {_role, config} ->
      required = config["required"] || 1
      ships = config["preferred_ships"] || []

      if length(ships) > 0 do
        # Use the first preferred ship for mass calculation
        ship_name = hd(ships)
        ship_info = ship_data[ship_name] || %{mass_kg: 10_000_000}
        required * ship_info.mass_kg
      else
        # Default ship mass
        required * 10_000_000
      end
    end)
    |> Enum.sum()
  end

  @doc """
  Calculate wormhole compatibility for a given total mass.

  Analyzes fleet compatibility with different wormhole types based on
  standard EVE Online wormhole mass limits.

  Returns a map with compatibility information for each wormhole type:
  - can_pass: Boolean indicating if fleet can pass through
  - mass_usage: Percentage of wormhole capacity used
  - mass_limit: Maximum mass limit for this wormhole type
  - remaining_mass: Remaining capacity after fleet passes
  """
  def calculate_wormhole_compatibility(total_mass) do
    # Wormhole mass limits (using standard EVE wormhole sizes)
    hole_types = %{
      # Small wormholes - 5M kg limit (frigate-only holes)
      "small_wormholes" => 5_000_000,
      # Medium wormholes - 90M kg limit (cruiser and below)
      "medium_wormholes" => 90_000_000,
      # Large wormholes - 300M kg limit (battleship and below)
      "large_wormholes" => 300_000_000,
      # XL wormholes - 1.8B kg limit (capital ships)
      "xl_wormholes" => 1_800_000_000
    }

    hole_types
    |> Enum.map(fn {hole_type, limit} ->
      can_pass = total_mass <= limit
      mass_usage = if can_pass, do: total_mass / limit, else: 999.0

      {hole_type,
       %{
         "can_pass" => can_pass,
         "mass_usage" => Float.round(mass_usage, 2),
         "mass_limit" => limit,
         "remaining_mass" => max(0, limit - total_mass)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Generate mass optimization suggestions for a fleet doctrine.

  Analyzes the fleet composition and provides suggestions for mass optimization
  to improve wormhole compatibility and efficiency.

  Returns a map with:
  - efficiency_rating: Overall mass efficiency rating (0.0-1.0)
  - wasted_mass_percentage: Percentage of mass that could be optimized
  - suggestions: List of optimization suggestions
  """
  def generate_mass_optimization_suggestions(doctrine_template, ship_data) do
    total_mass = calculate_total_fleet_mass(doctrine_template, ship_data)
    # Most common WH mass limit
    cruiser_limit = 90_000_000

    efficiency_rating = min(1.0, cruiser_limit / total_mass)
    wasted_mass_percentage = max(0.0, (total_mass - cruiser_limit) / cruiser_limit * 100)

    suggestions =
      if total_mass > cruiser_limit do
        ["Fleet exceeds cruiser hole mass limit"]
      else
        []
      end

    %{
      "efficiency_rating" => Float.round(efficiency_rating, 2),
      "wasted_mass_percentage" => Float.round(wasted_mass_percentage, 1),
      "suggestions" => suggestions
    }
  end

  @doc """
  Calculate transport requirements for a fleet.

  Analyzes fleet mass and determines transport logistics requirements
  including number of jumps needed and special considerations.

  Returns a map with:
  - jumps_required: Number of jumps needed to transport the fleet
  - pods_separate: Whether pods should be transported separately
  - logistics_ships_priority: Whether logistics ships should jump first
  """
  def calculate_transport_requirements(total_mass, _doctrine_template) do
    cruiser_limit = 90_000_000

    %{
      "jumps_required" => if(total_mass > cruiser_limit, do: 2, else: 1),
      "pods_separate" => total_mass > cruiser_limit * 0.9,
      "logistics_ships_priority" => true
    }
  end

  @doc """
  Calculate optimal jump sequence for mass management.

  Given a list of ships and wormhole parameters, calculates the optimal
  jump sequence to maximize mass utilization while respecting wormhole limits.

  Returns a map with:
  - jump_order: Ordered list of ships to jump
  - mass_utilization: Percentage of wormhole capacity used
  - remaining_capacity: Remaining wormhole capacity after jumps
  """
  def calculate_jump_mass_sequence(ships, wormhole) do
    max_mass = Map.get(wormhole, :max_mass, 0)
    max_ship_mass = Map.get(wormhole, :max_ship_mass, 0)
    current_mass = Map.get(wormhole, :current_mass, 0)

    # Filter ships that can jump individually
    jumpable_ships =
      Enum.filter(ships, fn ship ->
        ship_mass = Map.get(ship, :ship_mass, 0)
        ship_mass <= max_ship_mass
      end)

    # Calculate remaining capacity
    _remaining_capacity = max_mass - current_mass

    # Sort ships by mass (heaviest first for optimal utilization)
    sorted_ships = Enum.sort_by(jumpable_ships, &Map.get(&1, :ship_mass, 0), :desc)

    # Create jump order that fits within mass limits
    {jump_order, used_mass} =
      Enum.reduce_while(sorted_ships, {[], current_mass}, fn ship, {order, mass} ->
        ship_mass = Map.get(ship, :ship_mass, 0)

        if mass + ship_mass <= max_mass do
          ship_info = %{
            character_name: Map.get(ship, :character_name, "Unknown"),
            ship_name: Map.get(ship, :ship_name, "Unknown"),
            ship_mass: ship_mass
          }

          {:cont, {[ship_info | order], mass + ship_mass}}
        else
          {:halt, {order, mass}}
        end
      end)

    # Calculate utilization percentage
    mass_utilization = if max_mass > 0, do: used_mass / max_mass * 100, else: 0

    %{
      jump_order: Enum.reverse(jump_order),
      mass_utilization: round(mass_utilization),
      remaining_capacity: max_mass - used_mass
    }
  end

  @doc """
  Get wormhole mass limit by wormhole type.

  Returns the maximum mass limit for a specific wormhole type based on
  standard EVE Online wormhole classifications.
  """
  def wormhole_mass_limit(wormhole_type) do
    mass_limits = %{
      # Frigate holes
      "D382" => 20_000_000,
      "C125" => 20_000_000,

      # Small holes
      "D845" => 90_000_000,
      "A982" => 90_000_000,

      # Medium holes
      # C3 static
      "O477" => 300_000_000,
      # C2 static
      "L477" => 300_000_000,
      # C1 static
      "Z971" => 300_000_000,

      # Large holes
      # C4 static
      "B041" => 1_800_000_000,
      # C5 static
      "A641" => 1_800_000_000,
      # C6 static
      "X702" => 1_800_000_000,

      # Null/K-space connections
      "K162" => 3_000_000_000
    }

    # Default to medium hole
    Map.get(mass_limits, wormhole_type, 300_000_000)
  end

  @doc """
  Calculate ship mass efficiency for wormhole operations.

  Given a ship's mass in kilograms, calculates how efficiently it uses
  wormhole mass capacity relative to standard cruiser hole limits.

  Returns a float between 0.0 and 1.0 indicating efficiency.
  """
  def calculate_ship_mass_efficiency(mass_kg) do
    # Calculate how efficiently a ship uses wormhole mass
    cruiser_limit = 90_000_000
    Float.round(1.0 - mass_kg / cruiser_limit, 2)
  end

  @doc """
  Calculate ship mass by name using ShipDatabase.

  Wrapper function that delegates to ShipDatabase for consistency.
  """
  def calculate_ship_mass(ship_name) do
    ShipDatabase.get_ship_mass(ship_name)
  end

  @doc """
  Calculate total fleet mass from fleet members.

  Alternative version that takes a list of fleet members and calculates
  total mass based on their ships. Handles both explicit ship_mass fields
  and ship_name lookups.
  """
  def calculate_total_fleet_mass(fleet_members) when is_list(fleet_members) do
    fleet_members
    |> Enum.map(fn member ->
      case Map.get(member, :ship_mass) do
        nil ->
          ship_name = Map.get(member, :ship_name, "Unknown")
          calculate_ship_mass(ship_name)

        mass when is_number(mass) ->
          mass

        # Default
        _ ->
          10_000_000
      end
    end)
    |> Enum.sum()
  end

  @doc """
  Calculate average ship mass for a fleet.

  Given a list of fleet members, calculates the average mass per ship.
  Returns 0 if the fleet is empty.
  """
  def calculate_average_ship_mass(fleet_members) when is_list(fleet_members) do
    if Enum.empty?(fleet_members) do
      0
    else
      total_mass = calculate_total_fleet_mass(fleet_members)
      round(total_mass / length(fleet_members))
    end
  end
end
