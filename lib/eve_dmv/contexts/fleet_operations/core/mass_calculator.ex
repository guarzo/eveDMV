defmodule EveDmv.Contexts.FleetOperations.Core.MassCalculator do
  @moduledoc """
  Mass calculation utilities for fleet operations and wormhole analysis.

  Provides functions to calculate ship mass, fleet composition mass efficiency,
  and wormhole mass limits for strategic planning.
  """

  alias EveDmv.Api
  alias EveDmv.StaticData.ShipTypes
  require Logger

  # Standard wormhole mass limits (in kg)
  @wormhole_mass_limits %{
    # C1-C3 connections
    # 1B kg
    "X877" => 1_000_000_000,
    # 2B kg
    "B274" => 2_000_000_000,
    # 3B kg
    "A982" => 3_000_000_000,

    # C4-C5 connections
    # 1.8B kg
    "O477" => 1_800_000_000,
    # 2.5B kg
    "L477" => 2_500_000_000,
    # 3B kg
    "Z647" => 3_000_000_000,

    # Null-sec connections
    # 3B kg
    "V283" => 3_000_000_000,
    # Varies, using average
    "K346" => 3_000_000_000,

    # High-sec connections
    # 2B kg
    "B449" => 2_000_000_000,
    # 5B kg - largest
    "N110" => 5_000_000_000
  }

  # Type definitions
  @type mass_calculation_error ::
          :empty_fleet
          | :invalid_ship_type
          | :ship_data_unavailable
          | :unknown_wormhole_type
          | :invalid_doctrine
          | :calculation_failed
          | :unknown_doctrine

  @type fleet_optimization_result :: %{
          optimal_composition: [%{ship_type_id: integer(), count: integer(), role: atom()}],
          total_mass: integer(),
          mass_efficiency: float(),
          max_ships: integer(),
          wormhole_type: String.t(),
          doctrine: atom(),
          calculated_at: DateTime.t()
        }

  # Standard wormhole mass limits (in kg)

  @doc """
  Calculate ship mass efficiency based on role and fitting.

  Returns a score from 0.0 to 1.0 where higher values indicate
  better mass efficiency for the ship's intended role.
  """
  @spec calculate_ship_mass_efficiency(map()) :: float()
  def calculate_ship_mass_efficiency(ship_analysis) do
    ship_type_id = ship_analysis[:ship_type_id]
    role = ship_analysis[:role] || :unknown

    case get_ship_mass_data(ship_type_id) do
      {:ok, mass_data} ->
        calculate_efficiency_score(mass_data, role)

      {:error, _reason} ->
        # Default efficiency for unknown ships
        0.5
    end
  end

  @doc """
  Calculate total mass for a fleet composition.
  """
  @spec calculate_fleet_mass([map()]) :: {:ok, integer()} | {:error, mass_calculation_error()}
  def calculate_fleet_mass(fleet_composition) when is_list(fleet_composition) do
    if Enum.empty?(fleet_composition) do
      {:error, :empty_fleet}
    else
      total_mass =
        fleet_composition
        |> Enum.map(&get_ship_mass/1)
        |> Enum.sum()

      {:ok, total_mass}
    end
  end

  @doc """
  Determine if a fleet can fit through a wormhole type.
  """
  @spec can_fleet_traverse_wormhole?([map()], String.t()) :: boolean()
  def can_fleet_traverse_wormhole?(fleet_composition, wormhole_type) do
    case calculate_fleet_mass(fleet_composition) do
      {:ok, fleet_mass} ->
        wormhole_limit = Map.get(@wormhole_mass_limits, wormhole_type, 3_000_000_000)
        fleet_mass <= wormhole_limit

      {:error, _} ->
        false
    end
  end

  @doc """
  Get optimal fleet composition for a wormhole type.
  """
  @spec optimize_fleet_for_wormhole(String.t(), keyword()) ::
          {:ok, fleet_optimization_result()} | {:error, mass_calculation_error()}
  def optimize_fleet_for_wormhole(wormhole_type, opts \\ []) do
    mass_limit = Map.get(@wormhole_mass_limits, wormhole_type, 3_000_000_000)
    doctrine = Keyword.get(opts, :doctrine, :balanced)

    case doctrine do
      :heavy_assault ->
        optimize_heavy_assault_fleet(mass_limit)

      :fast_attack ->
        optimize_fast_attack_fleet(mass_limit)

      :balanced ->
        optimize_balanced_fleet(mass_limit)

      _ ->
        {:error, :unknown_doctrine}
    end
  end

  @doc """
  Calculate mass utilization percentage for a wormhole.
  """
  @spec calculate_mass_utilization([map()], String.t()) :: float()
  def calculate_mass_utilization(fleet_composition, wormhole_type) do
    case calculate_fleet_mass(fleet_composition) do
      {:ok, fleet_mass} ->
        wormhole_limit = Map.get(@wormhole_mass_limits, wormhole_type, 3_000_000_000)
        fleet_mass / wormhole_limit * 100.0

      {:error, _} ->
        0.0
    end
  end

  # Private functions

  defp get_ship_mass_data(ship_type_id) do
    case Ash.get(ShipTypes, ship_type_id, domain: Api) do
      {:ok, ship_type} ->
        {:ok,
         %{
           base_mass: ship_type.mass || estimate_mass_by_group(ship_type.group_id),
           group_id: ship_type.group_id,
           category_id: ship_type.category_id
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_efficiency_score(mass_data, role) do
    base_mass = mass_data.base_mass
    _group_id = mass_data.group_id

    # Role-based efficiency calculations using realistic mass thresholds
    case role do
      :tackle ->
        # Tackle ships: lighter is better (based on actual EVE ship masses)
        cond do
          # Interceptors (~1.2-1.3M kg)
          base_mass < 1_500_000 -> 1.0
          # T2 Frigates (~1.5-1.8M kg)
          base_mass < 2_000_000 -> 0.9
          # T1 Frigates (~1.8-2.5M kg)
          base_mass < 3_000_000 -> 0.8
          # Destroyers (~2-8M kg)
          base_mass < 15_000_000 -> 0.6
          # Light cruisers
          base_mass < 50_000_000 -> 0.4
          true -> 0.2
        end

      :dps ->
        # DPS ships: balance mass vs firepower (based on actual ship classes)
        cond do
          # Light cruisers
          base_mass < 15_000_000 -> 0.8
          # Heavy cruisers (~12-18M kg)
          base_mass < 20_000_000 -> 0.95
          # Battlecruisers (~60-70M kg)
          base_mass < 80_000_000 -> 1.0
          # Battleships (~100-110M kg)
          base_mass < 120_000_000 -> 1.0
          # Capitals (~1.2-1.4B kg)
          base_mass < 1_500_000_000 -> 0.7
          # Supercapitals
          true -> 0.4
        end

      :logistics ->
        # Logistics: moderate mass preferred
        cond do
          # Cruiser logi
          base_mass < 20_000_000 -> 1.0
          # Battleship logi
          base_mass < 200_000_000 -> 0.8
          true -> 0.5
        end

      :support ->
        # Support ships: efficiency varies by function
        cond do
          # Small support
          base_mass < 5_000_000 -> 0.9
          # Medium support
          base_mass < 50_000_000 -> 1.0
          true -> 0.7
        end

      _ ->
        # Unknown role: neutral efficiency
        0.5
    end
  end

  defp get_ship_mass(ship_data) do
    ship_type_id = ship_data[:ship_type_id] || ship_data["ship_type_id"]

    case get_ship_mass_data(ship_type_id) do
      {:ok, mass_data} -> mass_data.base_mass
      {:error, _} -> estimate_mass_by_ship_type(ship_type_id)
    end
  end

  defp estimate_mass_by_group(group_id) when is_integer(group_id) do
    # Rough mass estimates by ship group
    cond do
      # Frigates
      group_id in [25, 26, 27, 28, 29, 30] -> 1_200_000
      # Destroyers
      group_id in [420, 541] -> 1_800_000
      # Cruisers
      group_id in [26, 358, 832, 833, 834] -> 12_000_000
      # Battlecruisers
      group_id in [419, 540] -> 65_000_000
      # Battleships
      group_id in [27, 28, 898] -> 125_000_000
      # Capitals
      group_id in [547, 485] -> 1_200_000_000
      # Default
      true -> 50_000_000
    end
  end

  defp estimate_mass_by_group(_), do: 50_000_000

  defp estimate_mass_by_ship_type(ship_type_id) when is_integer(ship_type_id) do
    # Use proper ship attributes service to get actual mass
    case EveDmv.StaticData.ShipAttributesService.get_ship_attributes(ship_type_id) do
      {:ok, attrs} when not is_nil(attrs.mass) ->
        # Convert mass from kg to proper units (EVE mass is in kg)
        round(attrs.mass)

      {:ok, attrs} ->
        # No mass data, estimate based on ship class
        estimate_mass_by_ship_class(attrs.size_class)

      {:error, _} ->
        # Fallback: estimate based on ship type ID (as last resort)
        estimate_mass_by_ship_class_fallback(ship_type_id)
    end
  end

  # Default for unknown types
  defp estimate_mass_by_ship_type(_), do: 50_000_000

  defp estimate_mass_by_ship_class(size_class) when is_binary(size_class) do
    case size_class do
      # ~1.2M kg typical frigate
      "frigate" -> 1_200_000
      # ~1.8M kg typical destroyer
      "destroyer" -> 1_800_000
      # ~12M kg typical cruiser
      "cruiser" -> 12_000_000
      # ~60M kg typical battlecruiser
      "battlecruiser" -> 60_000_000
      # ~100M kg typical battleship
      "battleship" -> 100_000_000
      # ~1.2B kg typical capital
      "capital" -> 1_200_000_000
      # ~2.5B kg typical supercapital
      "supercapital" -> 2_500_000_000
      # Default estimate
      _ -> 50_000_000
    end
  end

  defp estimate_mass_by_ship_class(size_class) when is_atom(size_class) do
    estimate_mass_by_ship_class(Atom.to_string(size_class))
  end

  defp estimate_mass_by_ship_class_fallback(ship_type_id) when is_integer(ship_type_id) do
    # Last resort: estimate based on type ID ranges with realistic masses
    cond do
      # Small ships (frigates)
      ship_type_id < 1000 -> 1_500_000
      # Medium ships (cruisers)
      ship_type_id < 5000 -> 12_000_000
      # Large ships (battlecruisers)
      ship_type_id < 10_000 -> 60_000_000
      # Battleships
      ship_type_id < 20_000 -> 100_000_000
      # Capitals and specials
      true -> 300_000_000
    end
  end

  defp optimize_heavy_assault_fleet(mass_limit) do
    # Heavy assault optimization focuses on maximum DPS within mass limit
    # Use 85% of limit for safety
    target_mass = trunc(mass_limit * 0.85)

    composition = %{
      battleships: calculate_optimal_bs_count(target_mass * 0.6),
      battlecruisers: calculate_optimal_bc_count(target_mass * 0.25),
      support: calculate_optimal_support_count(target_mass * 0.15)
    }

    {:ok,
     %{
       optimal_composition: format_composition_for_result(composition),
       total_mass: target_mass,
       mass_efficiency: 0.85,
       max_ships: calculate_total_ship_count(composition),
       wormhole_type: "unknown",
       doctrine: :heavy_assault,
       calculated_at: DateTime.utc_now()
     }}
  end

  defp optimize_fast_attack_fleet(mass_limit) do
    # Fast attack optimization focuses on mobility and tackle
    # Use less mass for faster movement
    target_mass = trunc(mass_limit * 0.6)

    composition = %{
      interceptors: calculate_optimal_inty_count(target_mass * 0.3),
      assault_frigates: calculate_optimal_af_count(target_mass * 0.4),
      cruisers: calculate_optimal_cruiser_count(target_mass * 0.3)
    }

    {:ok,
     %{
       optimal_composition: format_composition_for_result(composition),
       total_mass: target_mass,
       mass_efficiency: 0.6,
       max_ships: calculate_total_ship_count(composition),
       wormhole_type: "unknown",
       doctrine: :fast_attack,
       calculated_at: DateTime.utc_now()
     }}
  end

  defp optimize_balanced_fleet(mass_limit) do
    # Balanced fleet with mix of roles
    target_mass = trunc(mass_limit * 0.8)

    composition = %{
      battlecruisers: calculate_optimal_bc_count(target_mass * 0.4),
      cruisers: calculate_optimal_cruiser_count(target_mass * 0.3),
      destroyers: calculate_optimal_destroyer_count(target_mass * 0.2),
      support: calculate_optimal_support_count(target_mass * 0.1)
    }

    {:ok,
     %{
       optimal_composition: format_composition_for_result(composition),
       total_mass: target_mass,
       mass_efficiency: 0.8,
       max_ships: calculate_total_ship_count(composition),
       wormhole_type: "unknown",
       doctrine: :balanced,
       calculated_at: DateTime.utc_now()
     }}
  end

  # Helper functions for fleet optimization
  defp calculate_optimal_bs_count(mass_budget), do: max(1, trunc(mass_budget / 125_000_000))
  defp calculate_optimal_bc_count(mass_budget), do: max(1, trunc(mass_budget / 65_000_000))
  defp calculate_optimal_cruiser_count(mass_budget), do: max(2, trunc(mass_budget / 12_000_000))
  defp calculate_optimal_destroyer_count(mass_budget), do: max(3, trunc(mass_budget / 1_800_000))
  defp calculate_optimal_af_count(mass_budget), do: max(5, trunc(mass_budget / 1_400_000))
  defp calculate_optimal_inty_count(mass_budget), do: max(3, trunc(mass_budget / 1_200_000))
  defp calculate_optimal_support_count(mass_budget), do: max(1, trunc(mass_budget / 15_000_000))

  defp estimate_fleet_dps(composition) do
    # Rough DPS estimates per ship class
    Enum.reduce(composition, 0, fn {ship_class, count}, acc ->
      dps_per_ship =
        case ship_class do
          :battleships -> 800
          :battlecruisers -> 600
          :cruisers -> 400
          :destroyers -> 250
          :assault_frigates -> 300
          :interceptors -> 150
          :support -> 100
        end

      acc + count * dps_per_ship
    end)
  end

  defp format_composition_for_result(composition) do
    # Convert composition map to required format
    Enum.map(composition, fn {ship_class, count} ->
      %{
        ship_type_id: get_representative_ship_type(ship_class),
        count: count,
        role: ship_class
      }
    end)
  end

  defp calculate_total_ship_count(composition) do
    Enum.reduce(composition, 0, fn {_class, count}, acc -> acc + count end)
  end

  defp get_representative_ship_type(ship_class) do
    # Representative ship type IDs for each class
    case ship_class do
      :battleships -> 24692  # Abaddon
      :battlecruisers -> 24483  # Oracle
      :cruisers -> 11176  # Zealot
      :destroyers -> 16242  # Coercer
      :assault_frigates -> 11365  # Retribution
      :interceptors -> 11184  # Crusader
      :support -> 11987  # Guardian
      _ -> 24692  # Default to Abaddon
    end
  end

  @doc """
  Calculate total fleet mass for a list of fleet members.
  """
  def calculate_total_fleet_mass(fleet_members) when is_list(fleet_members) do
    total_mass =
      fleet_members
      |> Enum.map(&get_ship_mass/1)
      |> Enum.sum()

    total_mass
  end

  @doc """
  Calculate ship mass by ship name or type ID.
  """
  def calculate_ship_mass(ship_identifier) do
    case ship_identifier do
      ship_name when is_binary(ship_name) ->
        # Try to find ship by name and get mass
        case EveDmv.StaticData.get_type_by_name(ship_name) do
          %{type_id: type_id} -> get_ship_mass(%{ship_type_id: type_id})
          # Default mass
          _ -> 50_000_000
        end

      ship_type_id when is_integer(ship_type_id) ->
        get_ship_mass(%{ship_type_id: ship_type_id})

      _ ->
        # Default mass
        50_000_000
    end
  end

  @doc """
  Calculate jump mass sequence through multiple wormholes.
  """
  def calculate_jump_mass_sequence(ships, wormhole_chain) when is_list(ships) do
    fleet_mass = calculate_total_fleet_mass(ships)

    case wormhole_chain do
      %{type: wormhole_type} ->
        # Single wormhole
        limit = wormhole_mass_limit(wormhole_type)
        {fleet_mass <= limit, %{fleet_mass: fleet_mass, limit: limit}}

      wormholes when is_list(wormholes) ->
        # Multiple wormholes - all must have sufficient mass limit
        results =
          Enum.map(wormholes, fn wh ->
            limit = wormhole_mass_limit(wh.type || wh["type"])
            {fleet_mass <= limit, %{wormhole: wh, fleet_mass: fleet_mass, limit: limit}}
          end)

        all_passable = Enum.all?(results, fn {passable, _} -> passable end)
        {all_passable, results}

      _ ->
        {false, %{error: "Invalid wormhole data"}}
    end
  end

  @doc """
  Get wormhole mass limit by type.
  """
  def wormhole_mass_limit(wormhole_type) when is_binary(wormhole_type) do
    Map.get(@wormhole_mass_limits, wormhole_type, 3_000_000_000)
  end

  def wormhole_mass_limit(_), do: 3_000_000_000
end
