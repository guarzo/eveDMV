defmodule EveDmv.Shared.ShipDatabaseService do
  @moduledoc """
  Consolidated ship database service for EVE DMV.

  This module provides a unified interface for ship information across all bounded contexts,
  combining data from both legacy and V2 implementations. It serves as the single source
  of truth for ship data, mass calculations, wormhole compatibility, and cost estimation.

  ## Features
  - Comprehensive ship data (mass, class, cost)
  - Wormhole compatibility checking
  - Fleet mass calculations
  - Ship role categorization
  - Cost estimation with role modifiers
  - Mass criticality calculations
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  require Logger

  # Comprehensive ship database with all known ships
  @ship_database %{
    # === FRIGATES ===
    # T1 Frigates
    "Rifter" => %{mass: 1_067_000, class: :frigate, base_cost: 500_000, role: :combat},
    "Merlin" => %{mass: 1_010_000, class: :frigate, base_cost: 500_000, role: :combat},
    "Incursus" => %{mass: 1_010_000, class: :frigate, base_cost: 500_000, role: :combat},
    "Punisher" => %{mass: 1_067_000, class: :frigate, base_cost: 500_000, role: :combat},

    # Interceptors
    "Stiletto" => %{mass: 1_030_000, class: :frigate, base_cost: 25_000_000, role: :tackle},
    "Crow" => %{mass: 1_030_000, class: :frigate, base_cost: 25_000_000, role: :tackle},
    "Malediction" => %{mass: 1_030_000, class: :frigate, base_cost: 25_000_000, role: :tackle},
    "Ares" => %{mass: 1_030_000, class: :frigate, base_cost: 25_000_000, role: :tackle},
    "Interceptor" => %{mass: 1_050_000, class: :frigate, base_cost: 25_000_000, role: :tackle},

    # Assault Frigates
    "Wolf" => %{mass: 3_500_000, class: :frigate, base_cost: 40_000_000, role: :combat},
    "Hawk" => %{mass: 3_500_000, class: :frigate, base_cost: 40_000_000, role: :combat},
    "Harpy" => %{mass: 3_500_000, class: :frigate, base_cost: 40_000_000, role: :combat},
    "Jaguar" => %{mass: 3_500_000, class: :frigate, base_cost: 40_000_000, role: :combat},
    "Assault Frigate" => %{mass: 3_500_000, class: :frigate, base_cost: 40_000_000, role: :combat},

    # Covert Ops
    "Cheetah" => %{mass: 1_180_000, class: :frigate, base_cost: 30_000_000, role: :covert},
    "Buzzard" => %{mass: 1_180_000, class: :frigate, base_cost: 30_000_000, role: :covert},
    "Helios" => %{mass: 1_180_000, class: :frigate, base_cost: 30_000_000, role: :covert},
    "Anathema" => %{mass: 1_180_000, class: :frigate, base_cost: 30_000_000, role: :covert},

    # Stealth Bombers
    "Hound" => %{mass: 1_280_000, class: :frigate, base_cost: 35_000_000, role: :bomber},
    "Manticore" => %{mass: 1_280_000, class: :frigate, base_cost: 35_000_000, role: :bomber},
    "Purifier" => %{mass: 1_280_000, class: :frigate, base_cost: 35_000_000, role: :bomber},
    "Nemesis" => %{mass: 1_280_000, class: :frigate, base_cost: 35_000_000, role: :bomber},
    "Stealth Bomber" => %{mass: 1_280_000, class: :frigate, base_cost: 35_000_000, role: :bomber},

    # Pirate/Special Frigates
    "Astero" => %{mass: 1_380_000, class: :frigate, base_cost: 80_000_000, role: :covert},
    "Pacifier" => %{mass: 1_200_000, class: :frigate, base_cost: 350_000_000, role: :covert},
    "Garmur" => %{mass: 1_100_000, class: :frigate, base_cost: 60_000_000, role: :combat},
    "Worm" => %{mass: 1_000_000, class: :frigate, base_cost: 40_000_000, role: :combat},

    # === DESTROYERS ===
    # T1 Destroyers
    "Thrasher" => %{mass: 1_480_000, class: :destroyer, base_cost: 1_500_000, role: :combat},
    "Catalyst" => %{mass: 1_480_000, class: :destroyer, base_cost: 1_500_000, role: :combat},
    "Coercer" => %{mass: 1_480_000, class: :destroyer, base_cost: 1_500_000, role: :combat},
    "Cormorant" => %{mass: 1_480_000, class: :destroyer, base_cost: 1_500_000, role: :combat},

    # Interdictors
    "Sabre" => %{mass: 2_000_000, class: :destroyer, base_cost: 70_000_000, role: :tackle},
    "Flycatcher" => %{mass: 2_000_000, class: :destroyer, base_cost: 55_000_000, role: :tackle},
    "Eris" => %{mass: 2_000_000, class: :destroyer, base_cost: 55_000_000, role: :tackle},
    "Heretic" => %{mass: 2_000_000, class: :destroyer, base_cost: 55_000_000, role: :tackle},

    # T3 Destroyers
    "Confessor" => %{mass: 2_000_000, class: :destroyer, base_cost: 65_000_000, role: :combat},
    "Svipul" => %{mass: 2_000_000, class: :destroyer, base_cost: 65_000_000, role: :combat},
    "Jackdaw" => %{mass: 2_000_000, class: :destroyer, base_cost: 65_000_000, role: :combat},
    "Hecate" => %{mass: 2_000_000, class: :destroyer, base_cost: 65_000_000, role: :combat},

    # === CRUISERS ===
    # T1 Cruisers
    "Vexor" => %{mass: 10_050_000, class: :cruiser, base_cost: 10_000_000, role: :combat},
    "Thorax" => %{mass: 10_050_000, class: :cruiser, base_cost: 10_000_000, role: :combat},
    "Moa" => %{mass: 10_050_000, class: :cruiser, base_cost: 10_000_000, role: :combat},
    "Rupture" => %{mass: 10_050_000, class: :cruiser, base_cost: 10_000_000, role: :combat},
    "Maller" => %{mass: 10_050_000, class: :cruiser, base_cost: 10_000_000, role: :combat},
    "Caracal" => %{mass: 10_050_000, class: :cruiser, base_cost: 10_000_000, role: :combat},

    # Heavy Assault Cruisers
    "Cerberus" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Vagabond" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Deimos" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Ishtar" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Zealot" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Muninn" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Eagle" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :combat},
    "Heavy Assault Cruiser" => %{
      mass: 11_250_000,
      class: :cruiser,
      base_cost: 200_000_000,
      role: :combat
    },

    # Recon Ships
    "Curse" => %{mass: 9_480_000, class: :cruiser, base_cost: 150_000_000, role: :ewar},
    "Pilgrim" => %{mass: 9_480_000, class: :cruiser, base_cost: 160_000_000, role: :ewar},
    "Falcon" => %{mass: 9_480_000, class: :cruiser, base_cost: 140_000_000, role: :ewar},
    "Rook" => %{mass: 9_480_000, class: :cruiser, base_cost: 140_000_000, role: :ewar},
    "Arazu" => %{mass: 9_480_000, class: :cruiser, base_cost: 160_000_000, role: :ewar},
    "Lachesis" => %{mass: 9_480_000, class: :cruiser, base_cost: 160_000_000, role: :ewar},

    # T3 Cruisers
    "Loki" => %{mass: 11_500_000, class: :cruiser, base_cost: 400_000_000, role: :versatile},
    "Tengu" => %{mass: 11_500_000, class: :cruiser, base_cost: 400_000_000, role: :versatile},
    "Proteus" => %{mass: 11_500_000, class: :cruiser, base_cost: 400_000_000, role: :versatile},
    "Legion" => %{mass: 11_500_000, class: :cruiser, base_cost: 400_000_000, role: :versatile},

    # Heavy Interdictors
    "Broadsword" => %{mass: 100_000_000, class: :cruiser, base_cost: 250_000_000, role: :tackle},
    "Onyx" => %{mass: 100_000_000, class: :cruiser, base_cost: 250_000_000, role: :tackle},
    "Devoter" => %{mass: 100_000_000, class: :cruiser, base_cost: 250_000_000, role: :tackle},
    "Phobos" => %{mass: 100_000_000, class: :cruiser, base_cost: 250_000_000, role: :tackle},
    "Heavy Interdictor" => %{
      mass: 100_000_000,
      class: :cruiser,
      base_cost: 250_000_000,
      role: :tackle
    },

    # Logistics Cruisers
    "Guardian" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :logistics},
    "Basilisk" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :logistics},
    "Oneiros" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :logistics},
    "Scimitar" => %{mass: 11_250_000, class: :cruiser, base_cost: 200_000_000, role: :logistics},

    # Pirate/Special Cruisers
    "Stratios" => %{mass: 11_900_000, class: :cruiser, base_cost: 350_000_000, role: :covert},
    "Gila" => %{mass: 10_050_000, class: :cruiser, base_cost: 250_000_000, role: :combat},
    "Orthrus" => %{mass: 10_050_000, class: :cruiser, base_cost: 280_000_000, role: :combat},

    # === BATTLECRUISERS ===
    # T1 Battlecruisers
    "Hurricane" => %{
      mass: 15_000_000,
      class: :battlecruiser,
      base_cost: 50_000_000,
      role: :combat
    },
    "Drake" => %{mass: 15_000_000, class: :battlecruiser, base_cost: 50_000_000, role: :combat},
    "Harbinger" => %{
      mass: 15_000_000,
      class: :battlecruiser,
      base_cost: 50_000_000,
      role: :combat
    },
    "Brutix" => %{mass: 15_000_000, class: :battlecruiser, base_cost: 50_000_000, role: :combat},
    "Ferox" => %{mass: 15_000_000, class: :battlecruiser, base_cost: 50_000_000, role: :combat},

    # Command Ships
    "Sleipnir" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Claymore" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Vulture" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Absolution" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Damnation" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Astarte" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Eos" => %{mass: 30_000_000, class: :battlecruiser, base_cost: 450_000_000, role: :command},
    "Nighthawk" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },
    "Command Ship" => %{
      mass: 30_000_000,
      class: :battlecruiser,
      base_cost: 450_000_000,
      role: :command
    },

    # Special Battlecruisers
    "Gnosis" => %{
      mass: 15_000_000,
      class: :battlecruiser,
      base_cost: 70_000_000,
      role: :versatile
    },

    # === BATTLESHIPS ===
    # T1 Battleships
    "Typhoon" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :combat},
    "Raven" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :combat},
    "Megathron" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :combat},
    "Apocalypse" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 200_000_000,
      role: :combat
    },
    "Maelstrom" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :combat},
    "Hyperion" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :combat},
    "Abaddon" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :combat},
    "Scorpion" => %{mass: 100_000_000, class: :battleship, base_cost: 200_000_000, role: :ewar},

    # Marauders
    "Golem" => %{mass: 100_000_000, class: :battleship, base_cost: 1_500_000_000, role: :marauder},
    "Vargur" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_500_000_000,
      role: :marauder
    },
    "Paladin" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_500_000_000,
      role: :marauder
    },
    "Kronos" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_500_000_000,
      role: :marauder
    },
    "Marauder" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_500_000_000,
      role: :marauder
    },

    # Black Ops
    "Redeemer" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_000_000_000,
      role: :covert
    },
    "Panther" => %{mass: 100_000_000, class: :battleship, base_cost: 1_000_000_000, role: :covert},
    "Sin" => %{mass: 100_000_000, class: :battleship, base_cost: 1_000_000_000, role: :covert},
    "Widow" => %{mass: 100_000_000, class: :battleship, base_cost: 1_000_000_000, role: :covert},
    "Black Ops" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_000_000_000,
      role: :covert
    },

    # Special Battleships
    "Nestor" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 1_200_000_000,
      role: :logistics
    },
    "Praxis" => %{mass: 100_000_000, class: :battleship, base_cost: 150_000_000, role: :combat},
    "Rattlesnake" => %{
      mass: 100_000_000,
      class: :battleship,
      base_cost: 900_000_000,
      role: :combat
    },
    "Bhaalgorn" => %{mass: 100_000_000, class: :battleship, base_cost: 800_000_000, role: :combat},

    # === CAPITAL SHIPS (restricted in most wormholes) ===
    "Dreadnought" => %{
      mass: 1_000_000_000,
      class: :capital,
      base_cost: 2_500_000_000,
      role: :siege
    },
    "Carrier" => %{mass: 1_000_000_000, class: :capital, base_cost: 3_000_000_000, role: :fighter},
    "Force Auxiliary" => %{
      mass: 1_000_000_000,
      class: :capital,
      base_cost: 3_500_000_000,
      role: :logistics
    },
    "Rorqual" => %{
      mass: 1_000_000_000,
      class: :capital,
      base_cost: 8_000_000_000,
      role: :industrial
    },

    # === SUPER CAPITALS ===
    "Supercarrier" => %{
      mass: 2_500_000_000,
      class: :super_capital,
      base_cost: 20_000_000_000,
      role: :fighter
    },
    "Titan" => %{
      mass: 2_800_000_000,
      class: :super_capital,
      base_cost: 80_000_000_000,
      role: :doomsday
    }
  }

  # Wormhole mass limits by class
  @wormhole_limits %{
    "C1" => %{total: 20_000_000, jump: 5_000_000, regen: 0},
    "C2" => %{total: 300_000_000, jump: 62_500_000, regen: 0},
    "C3" => %{total: 300_000_000, jump: 62_500_000, regen: 0},
    "C4" => %{total: 300_000_000, jump: 62_500_000, regen: 0},
    "C5" => %{total: 1_000_000_000, jump: 250_000_000, regen: 0},
    "C6" => %{total: 1_800_000_000, jump: 250_000_000, regen: 0},
    # Special wormhole types
    "Thera" => %{total: 2_000_000_000, jump: 300_000_000, regen: 0},
    "Shattered" => %{total: 1_000_000_000, jump: 62_500_000, regen: 0},
    "Drifter" => %{total: 1_000_000_000, jump: 250_000_000, regen: 0},
    "K162" => %{total: :variable, jump: :variable, regen: 0},
    # Frigate-only wormholes
    "E175" => %{total: 28_000_000, jump: 5_000_000, regen: 0},
    "C729" => %{total: 5_000_000, jump: 1_800_000, regen: 0},
    # Mass-regenerating wormholes
    "M267" => %{total: 1_000_000_000, jump: 300_000_000, regen: 100_000_000},
    "M555" => %{total: 3_000_000_000, jump: 1_000_000_000, regen: 500_000_000}
  }

  # Ship type IDs for ESI compatibility
  @ship_type_ids %{
    # Add common ship type IDs here as needed
    587 => "Rifter",
    602 => "Merlin",
    11176 => "Crow",
    11182 => "Sabre",
    29984 => "Tengu",
    29990 => "Loki"
    # ... more type IDs can be added
  }

  # Public API

  @doc """
  Get comprehensive ship information.

  ## Examples
      iex> ShipDatabaseService.get_ship_info("Loki")
      {:ok, %{name: "Loki", mass: 11_500_000, class: :cruiser, ...}}
  """
  @spec get_ship_info(String.t() | integer()) :: Result.t(map())
  def get_ship_info(ship_identifier) when is_binary(ship_identifier) do
    case Map.get(@ship_database, ship_identifier) do
      nil ->
        Result.error(:ship_not_found, "Unknown ship: #{ship_identifier}")

      ship_data ->
        Result.ok(%{
          name: ship_identifier,
          mass: ship_data.mass,
          class: ship_data.class,
          base_cost: ship_data.base_cost,
          role: ship_data.role,
          category: get_ship_category_by_role(ship_data.role),
          is_capital: ship_data.class in [:capital, :super_capital],
          wormhole_capable: ship_data.class not in [:capital, :super_capital],
          mass_formatted: format_mass(ship_data.mass),
          cost_formatted: format_isk(ship_data.base_cost)
        })
    end
  end

  def get_ship_info(type_id) when is_integer(type_id) do
    case Map.get(@ship_type_ids, type_id) do
      nil -> Result.error(:ship_not_found, "Unknown ship type ID: #{type_id}")
      ship_name -> get_ship_info(ship_name)
    end
  end

  @doc """
  Get ship class.
  """
  @spec get_ship_class(String.t() | integer()) :: atom()
  def get_ship_class(ship_identifier) when is_binary(ship_identifier) do
    case Map.get(@ship_database, ship_identifier) do
      nil -> :unknown
      %{class: class} -> class
    end
  end

  def get_ship_class(type_id) when is_integer(type_id) do
    case Map.get(@ship_type_ids, type_id) do
      nil -> :unknown
      ship_name -> get_ship_class(ship_name)
    end
  end

  @doc """
  Get ship mass in kg.
  """
  @spec get_ship_mass(String.t() | integer() | map()) :: float()
  def get_ship_mass(ship_name) when is_binary(ship_name) do
    case Map.get(@ship_database, ship_name) do
      # Default 10M kg for unknown ships
      nil -> 10_000_000
      %{mass: mass} -> mass
    end
  end

  def get_ship_mass(type_id) when is_integer(type_id) do
    case Map.get(@ship_type_ids, type_id) do
      nil -> 10_000_000
      ship_name -> get_ship_mass(ship_name)
    end
  end

  def get_ship_mass(%{ship_name: name}), do: get_ship_mass(name)
  def get_ship_mass(%{"ship_name" => name}), do: get_ship_mass(name)
  def get_ship_mass(%{ship_type_id: id}), do: get_ship_mass(id)
  def get_ship_mass(%{"ship_type_id" => id}), do: get_ship_mass(id)
  def get_ship_mass(_), do: 10_000_000

  @doc """
  Calculate total fleet mass.
  """
  @spec calculate_fleet_mass(list()) :: float()
  def calculate_fleet_mass(ships) when is_list(ships) do
    ships
    |> Enum.map(&get_ship_mass/1)
    |> Enum.sum()
  end

  @doc """
  Check wormhole compatibility for a ship.
  """
  @spec check_wormhole_compatibility(String.t(), String.t()) :: Result.t(atom())
  def check_wormhole_compatibility(ship_name, wormhole_class) do
    with {:ok, ship_info} <- get_ship_info(ship_name),
         {:ok, wh_limits} <- get_wormhole_limits(wormhole_class) do
      cond do
        ship_info.is_capital and wormhole_class in ["C1", "C2", "C3", "C4"] ->
          Result.error(:too_heavy, "Capital ships cannot enter #{wormhole_class} wormholes")

        ship_info.mass > wh_limits.jump ->
          Result.error(
            :too_heavy,
            "Ship mass (#{format_mass(ship_info.mass)}) exceeds jump limit (#{format_mass(wh_limits.jump)})"
          )

        ship_info.mass > wh_limits.jump * 0.9 ->
          Result.ok(:restricted)

        true ->
          Result.ok(:allowed)
      end
    end
  end

  @doc """
  Calculate mass criticality for wormholes.
  """
  @spec calculate_mass_criticality(float(), float(), float()) :: map()
  def calculate_mass_criticality(current_mass, total_mass, ship_mass) do
    remaining = total_mass - current_mass
    jumps_remaining = div(remaining, ship_mass)

    %{
      remaining_mass: remaining,
      jumps_possible: jumps_remaining,
      criticality: calculate_criticality_level(remaining, total_mass),
      risk_level: if(jumps_remaining <= 2, do: :high, else: :normal),
      percentage_remaining: Float.round(remaining / total_mass * 100, 1)
    }
  end

  @doc """
  Estimate ship cost with role modifiers.
  """
  @spec estimate_ship_cost(String.t(), atom()) :: float()
  def estimate_ship_cost(ship_name, fitting_type \\ :standard) do
    base_cost =
      case Map.get(@ship_database, ship_name) do
        # Default 100M for unknown ships
        nil -> 100_000_000
        %{base_cost: cost} -> cost
      end

    modifier =
      case fitting_type do
        :cheap -> 0.7
        :standard -> 1.0
        :faction -> 2.0
        :officer -> 5.0
        :abyssal -> 10.0
        _ -> 1.0
      end

    round(base_cost * modifier)
  end

  @doc """
  Get recommended ships for a specific role.
  """
  @spec get_ships_by_role(atom()) :: list(String.t())
  def get_ships_by_role(role) when is_atom(role) do
    @ship_database
    |> Enum.filter(fn {_name, data} -> data.role == role end)
    |> Enum.map(fn {name, _data} -> name end)
    |> Enum.sort()
  end

  @doc """
  Check if ship is suitable for wormhole operations.
  """
  @spec wormhole_suitable?(String.t()) :: boolean()
  def wormhole_suitable?(ship_name) do
    case get_ship_class(ship_name) do
      class when class in [:capital, :super_capital] -> false
      :unknown -> false
      _ -> true
    end
  end

  @doc """
  Get ship category based on role.
  """
  @spec get_ship_category(String.t()) :: atom()
  def get_ship_category(ship_name) when is_binary(ship_name) do
    case Map.get(@ship_database, ship_name) do
      nil -> :unknown
      %{role: role} -> get_ship_category_by_role(role)
    end
  end

  @doc """
  Analyze fleet composition for wormhole mass limits.
  """
  @spec analyze_fleet_for_wormhole(list(), String.t()) :: Result.t(map())
  def analyze_fleet_for_wormhole(fleet_ships, wormhole_class) do
    with {:ok, wh_limits} <- get_wormhole_limits(wormhole_class) do
      fleet_mass = calculate_fleet_mass(fleet_ships)

      # Group ships by mass
      ships_by_mass =
        fleet_ships
        |> Enum.group_by(&get_ship_mass/1)
        |> Enum.map(fn {mass, ships} -> {mass, length(ships)} end)
        |> Enum.sort_by(fn {mass, _count} -> -mass end)

      # Calculate logistics
      total_jumps = length(fleet_ships)
      mass_per_jump = fleet_mass / total_jumps

      # Determine if fleet can pass
      can_pass =
        fleet_mass <= wh_limits.total and
          Enum.all?(fleet_ships, fn ship ->
            get_ship_mass(ship) <= wh_limits.jump
          end)

      Result.ok(%{
        fleet_mass: fleet_mass,
        wormhole_limits: wh_limits,
        can_pass: can_pass,
        total_jumps_required: total_jumps,
        ships_by_mass: ships_by_mass,
        mass_efficiency: Float.round(mass_per_jump / wh_limits.jump * 100, 1),
        recommendations: generate_fleet_recommendations(fleet_ships, wh_limits)
      })
    end
  end

  # Private helper functions

  defp get_wormhole_limits(wormhole_class) do
    case Map.get(@wormhole_limits, wormhole_class) do
      nil ->
        Result.error(:unknown_wormhole, "Unknown wormhole class: #{wormhole_class}")

      %{total: :variable} ->
        # K162 and other variable wormholes - use C5 limits as default
        Result.ok(@wormhole_limits["C5"])

      limits ->
        Result.ok(limits)
    end
  end

  defp format_mass(mass) when mass >= 1_000_000_000 do
    "#{Float.round(mass / 1_000_000_000, 1)}B kg"
  end

  defp format_mass(mass) when mass >= 1_000_000 do
    "#{Float.round(mass / 1_000_000, 1)}M kg"
  end

  defp format_mass(mass) do
    "#{Float.round(mass / 1_000, 1)}K kg"
  end

  defp format_isk(amount) when amount >= 1_000_000_000 do
    "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
  end

  defp format_isk(amount) when amount >= 1_000_000 do
    "#{Float.round(amount / 1_000_000, 1)}M ISK"
  end

  defp format_isk(amount) do
    "#{Float.round(amount / 1_000, 1)}K ISK"
  end

  defp calculate_criticality_level(remaining, total) do
    percentage = remaining / total * 100

    cond do
      percentage <= 10 -> :critical
      percentage <= 25 -> :stressed
      percentage <= 50 -> :reduced
      true -> :stable
    end
  end

  defp get_ship_category_by_role(role) do
    case role do
      :combat -> :dps
      :tackle -> :tackle
      :ewar -> :support
      :logistics -> :support
      :command -> :force_multiplier
      :covert -> :special_ops
      :bomber -> :special_ops
      :marauder -> :heavy_dps
      :versatile -> :flex
      :siege -> :capital_warfare
      :fighter -> :capital_warfare
      :doomsday -> :strategic
      _ -> :general
    end
  end

  defp generate_fleet_recommendations(fleet_ships, wh_limits) do
    recommendations = []

    # Check for capitals in low-class wormholes
    capital_ships =
      Enum.filter(fleet_ships, fn ship ->
        get_ship_class(ship) in [:capital, :super_capital]
      end)

    recommendations =
      if length(capital_ships) > 0 and wh_limits.jump < 300_000_000 do
        ["#{length(capital_ships)} capital ship(s) cannot enter this wormhole" | recommendations]
      else
        recommendations
      end

    # Check for mass-critical ships
    heavy_ships =
      Enum.filter(fleet_ships, fn ship ->
        get_ship_mass(ship) > wh_limits.jump * 0.5
      end)

    recommendations =
      if length(heavy_ships) > 0 do
        ["#{length(heavy_ships)} ship(s) will significantly impact hole mass" | recommendations]
      else
        recommendations
      end

    # Check total mass vs limit
    total_mass = calculate_fleet_mass(fleet_ships)

    if total_mass > wh_limits.total * 0.8 do
      ["Fleet will likely collapse the wormhole (>80% of total mass)" | recommendations]
    else
      recommendations
    end
  end
end
