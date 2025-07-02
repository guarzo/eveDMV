defmodule EveDmv.Intelligence.ShipDatabase do
  @moduledoc """
  Static ship data and classifications for fleet analysis
  """

  @doc """
  Get ship class classification by ship type ID or name.
  """
  def get_ship_class(ship_type_id) when is_integer(ship_type_id) do
    ship_classes()[ship_type_id] || :unknown
  end

  def get_ship_class(ship_name) when is_binary(ship_name) do
    ship_name_to_class()[ship_name] || :unknown
  end

  @doc """
  Get ship mass by ship type ID or name.
  """
  def get_ship_mass(ship_type_id) when is_integer(ship_type_id) do
    ship_masses()[ship_type_id] || 10_000_000
  end

  def get_ship_mass(ship_name) when is_binary(ship_name) do
    ship_masses_by_name()[ship_name] || 10_000_000
  end

  @doc """
  Get ship role based on ship name.
  """
  def get_ship_role(ship_name) when is_binary(ship_name) do
    ship_roles()[ship_name] || "unknown"
  end

  @doc """
  Get wormhole restrictions for a ship class.
  """
  def get_wormhole_restrictions(ship_class) do
    wormhole_restrictions()[ship_class] ||
      %{
        can_pass_small: false,
        can_pass_medium: false,
        can_pass_large: true,
        can_pass_xl: true
      }
  end

  @doc """
  Check if ship is part of a specific doctrine.
  """
  def doctrine_ship?(ship_name, doctrine) do
    ships = doctrine_ships()[doctrine] || []
    ship_name in ships
  end

  @doc """
  Get ship category (frigate, cruiser, etc.) by ship type ID.
  """
  def get_ship_category(ship_type_id) when is_integer(ship_type_id) do
    cond do
      ship_type_id in frigate_ids() -> "Frigate"
      ship_type_id in destroyer_ids() -> "Destroyer"
      ship_type_id in cruiser_ids() -> "Cruiser"
      ship_type_id in battlecruiser_ids() -> "Battlecruiser"
      ship_type_id in battleship_ids() -> "Battleship"
      ship_type_id in capital_ids() -> "Capital"
      ship_type_id in supercapital_ids() -> "Supercapital"
      true -> "Unknown"
    end
  end

  @doc """
  Get ship category by ship name.
  """
  def get_ship_category(ship_name) when is_binary(ship_name) do
    ship_name_to_category()[ship_name] || "Unknown"
  end

  @doc """
  Check if ship is a capital ship.
  """
  def is_capital?(ship_type_id) when is_integer(ship_type_id) do
    ship_type_id in (capital_ids() ++ supercapital_ids())
  end

  def is_capital?(ship_name) when is_binary(ship_name) do
    category = get_ship_category(ship_name)
    category in ["Capital", "Supercapital"]
  end

  @doc """
  Check if ship is suitable for wormhole operations.
  """
  def wormhole_suitable?(ship_name) do
    role = get_ship_role(ship_name)
    mass = get_ship_mass(ship_name)

    # Ships under 350M kg and with useful roles are generally WH suitable
    mass < 350_000_000 and role in ["dps", "logistics", "tackle", "ewar", "fc"]
  end

  @doc """
  Get optimal gang size for ship composition.
  """
  def optimal_gang_size(ship_composition) do
    roles = Enum.map(ship_composition, &get_ship_role/1)

    dps_count = Enum.count(roles, &(&1 == "dps"))
    logi_count = Enum.count(roles, &(&1 == "logistics"))

    cond do
      logi_count >= 2 && dps_count >= 5 -> "medium_gang"
      logi_count >= 1 && dps_count >= 3 -> "small_gang"
      dps_count >= 2 -> "micro_gang"
      true -> "solo"
    end
  end

  # Private data functions

  defp ship_classes do
    %{
      # Frigates
      # Rifter
      587 => :frigate,
      # Punisher
      588 => :frigate,
      # Merlin
      589 => :frigate,
      # Incursus
      590 => :frigate,

      # Destroyers
      # Corax
      16219 => :destroyer,
      # Algos
      16227 => :destroyer,
      # Catalyst
      16236 => :destroyer,
      # Thrasher
      16242 => :destroyer,

      # Cruisers
      # Arbitrator
      621 => :cruiser,
      # Omen
      622 => :cruiser,
      # Caracal
      623 => :cruiser,
      # Vexor
      624 => :cruiser,

      # Battlecruisers
      # Drake
      1201 => :battlecruiser,
      # Harbinger
      1202 => :battlecruiser,
      # Ferox
      1203 => :battlecruiser,
      # Myrmidon
      1204 => :battlecruiser,

      # Battleships
      # Raven
      643 => :battleship,
      # Apocalypse
      644 => :battleship,
      # Rokh
      645 => :battleship,
      # Megathron
      646 => :battleship,

      # Strategic Cruisers
      # Tengu
      29984 => :strategic_cruiser,
      # Legion
      29986 => :strategic_cruiser,
      # Proteus
      29988 => :strategic_cruiser,
      # Loki
      29990 => :strategic_cruiser,

      # Command Ships
      # Damnation
      22442 => :command_ship,
      # Nighthawk
      22444 => :command_ship,
      # Claymore
      22446 => :command_ship,
      # Sleipnir
      22448 => :command_ship,

      # Logistics
      # Guardian
      11985 => :logistics,
      # Basilisk
      11987 => :logistics,
      # Oneiros
      11989 => :logistics,
      # Scimitar
      11993 => :logistics,

      # Interceptors
      # Ares
      11174 => :interceptor,
      # Stiletto
      11176 => :interceptor,
      # Crow
      11178 => :interceptor,
      # Malediction
      11180 => :interceptor,

      # Capitals
      # Revelation
      19720 => :dreadnought,
      # Naglfar
      19722 => :dreadnought,
      # Moros
      19724 => :dreadnought,
      # Phoenix
      19726 => :dreadnought,
      # Archon
      23757 => :carrier,
      # Chimera
      23911 => :carrier,
      # Thanatos
      23913 => :carrier,
      # Nidhoggur
      23915 => :carrier,

      # Supercarriers
      # Nyx
      3514 => :supercarrier,
      # Aeon
      22852 => :supercarrier,
      # Thanatos
      23913 => :supercarrier,
      # Wyvern
      23917 => :supercarrier,
      # Hel
      23919 => :supercarrier,

      # Titans
      # Erebus
      671 => :titan,
      # Leviathan
      3764 => :titan,
      # Avatar
      11567 => :titan,
      # Ragnarok
      23773 => :titan
    }
  end

  defp ship_masses do
    %{
      # Strategic Cruisers
      # Tengu
      29984 => 12_900_000,
      # Legion
      29986 => 13_000_000,
      # Proteus
      29988 => 12_800_000,
      # Loki
      29990 => 13_100_000,

      # Command Ships
      # Damnation
      22442 => 13_500_000,
      # Nighthawk
      22444 => 13_200_000,
      # Claymore
      22446 => 13_800_000,
      # Sleipnir
      22448 => 13_600_000,

      # Logistics Cruisers
      # Guardian
      11985 => 11_800_000,
      # Basilisk
      11987 => 11_900_000,
      # Oneiros
      11989 => 12_100_000,
      # Scimitar
      11993 => 12_000_000,

      # Heavy Assault Cruisers
      # Muninn
      12003 => 12_200_000,
      # Cerberus
      12005 => 12_000_000,
      # Zealot
      12011 => 12_400_000,
      # Eagle
      12015 => 12_100_000,

      # Interceptors
      # Ares
      11174 => 1_200_000,
      # Stiletto
      11176 => 1_150_000,
      # Crow
      11178 => 1_180_000,
      # Malediction
      11180 => 1_100_000,

      # EWAR Frigates
      # Crucifier
      11192 => 1_300_000,
      # Maulus
      11200 => 1_250_000,
      # Vigil
      11202 => 1_280_000,
      # Griffin
      11196 => 1_220_000,

      # Common ships
      # Rifter
      587 => 1_400_000,
      # Punisher
      588 => 1_350_000,
      # Bantam
      648 => 1_300_000,
      # Arbitrator
      621 => 11_500_000,
      # Drake
      1201 => 14_500_000
    }
  end

  defp ship_masses_by_name do
    %{
      # Command Ships
      "Damnation" => 13_500_000,
      "Nighthawk" => 13_200_000,
      "Claymore" => 13_800_000,
      "Sleipnir" => 13_600_000,

      # Strategic Cruisers
      "Legion" => 13_000_000,
      "Proteus" => 12_800_000,
      "Tengu" => 12_900_000,
      "Loki" => 13_100_000,

      # Logistics
      "Guardian" => 11_800_000,
      "Scimitar" => 12_000_000,
      "Basilisk" => 11_900_000,
      "Oneiros" => 12_100_000,

      # Heavy Assault Cruisers
      "Muninn" => 12_200_000,
      "Cerberus" => 12_000_000,
      "Zealot" => 12_400_000,
      "Eagle" => 12_100_000,

      # Interceptors
      "Ares" => 1_200_000,
      "Malediction" => 1_100_000,
      "Stiletto" => 1_150_000,
      "Crow" => 1_180_000,

      # EWAR Frigates
      "Crucifier" => 1_300_000,
      "Maulus" => 1_250_000,
      "Vigil" => 1_280_000,
      "Griffin" => 1_220_000,

      # Common ships
      "Rifter" => 1_400_000,
      "Punisher" => 1_350_000,
      "Bantam" => 1_300_000,
      "Maller" => 11_500_000,
      "Drake" => 14_500_000
    }
  end

  defp ship_roles do
    %{
      # Fleet Command
      "Damnation" => "fc",
      "Nighthawk" => "fc",
      "Claymore" => "fc",
      "Sleipnir" => "fc",

      # DPS
      "Legion" => "dps",
      "Proteus" => "dps",
      "Tengu" => "dps",
      "Loki" => "dps",
      "Muninn" => "dps",
      "Cerberus" => "dps",
      "Zealot" => "dps",
      "Eagle" => "dps",

      # Logistics
      "Guardian" => "logistics",
      "Scimitar" => "logistics",
      "Basilisk" => "logistics",
      "Oneiros" => "logistics",

      # Tackle
      "Ares" => "tackle",
      "Malediction" => "tackle",
      "Stiletto" => "tackle",
      "Crow" => "tackle",
      "Interceptor" => "tackle",

      # EWAR
      "Crucifier" => "ewar",
      "Maulus" => "ewar",
      "Vigil" => "ewar",
      "Griffin" => "ewar"
    }
  end

  defp ship_name_to_class do
    %{
      # Strategic Cruisers
      "Tengu" => :strategic_cruiser,
      "Legion" => :strategic_cruiser,
      "Proteus" => :strategic_cruiser,
      "Loki" => :strategic_cruiser,

      # Command Ships
      "Damnation" => :command_ship,
      "Nighthawk" => :command_ship,
      "Claymore" => :command_ship,
      "Sleipnir" => :command_ship,

      # Logistics
      "Guardian" => :logistics,
      "Basilisk" => :logistics,
      "Oneiros" => :logistics,
      "Scimitar" => :logistics,

      # Interceptors
      "Ares" => :interceptor,
      "Stiletto" => :interceptor,
      "Crow" => :interceptor,
      "Malediction" => :interceptor
    }
  end

  defp ship_name_to_category do
    %{
      # Frigates
      "Rifter" => "Frigate",
      "Punisher" => "Frigate",
      "Merlin" => "Frigate",
      "Incursus" => "Frigate",
      "Ares" => "Frigate",
      "Stiletto" => "Frigate",
      "Crow" => "Frigate",
      "Malediction" => "Frigate",
      "Crucifier" => "Frigate",
      "Maulus" => "Frigate",
      "Vigil" => "Frigate",
      "Griffin" => "Frigate",

      # Cruisers
      "Guardian" => "Cruiser",
      "Basilisk" => "Cruiser",
      "Oneiros" => "Cruiser",
      "Scimitar" => "Cruiser",
      "Muninn" => "Cruiser",
      "Cerberus" => "Cruiser",
      "Zealot" => "Cruiser",
      "Eagle" => "Cruiser",
      "Legion" => "Cruiser",
      "Proteus" => "Cruiser",
      "Tengu" => "Cruiser",
      "Loki" => "Cruiser",
      "Damnation" => "Cruiser",
      "Nighthawk" => "Cruiser",
      "Claymore" => "Cruiser",
      "Sleipnir" => "Cruiser",

      # Battlecruisers
      "Drake" => "Battlecruiser",
      "Harbinger" => "Battlecruiser",
      "Ferox" => "Battlecruiser",
      "Myrmidon" => "Battlecruiser"
    }
  end

  defp doctrine_ships do
    %{
      "armor_cruiser" => [
        "Legion",
        "Proteus",
        "Damnation",
        "Guardian",
        "Zealot",
        "Muninn",
        "Ares",
        "Crucifier"
      ],
      "armor" => [
        "Legion",
        "Proteus",
        "Damnation",
        "Guardian",
        "Zealot",
        "Muninn",
        "Ares",
        "Crucifier"
      ],
      "shield_cruiser" => [
        "Tengu",
        "Loki",
        "Nighthawk",
        "Scimitar",
        "Cerberus",
        "Eagle",
        "Stiletto",
        "Griffin"
      ],
      "shield" => [
        "Tengu",
        "Loki",
        "Nighthawk",
        "Scimitar",
        "Cerberus",
        "Eagle",
        "Stiletto",
        "Griffin"
      ],
      "unknown" => [],
      "mixed" => []
    }
  end

  defp wormhole_restrictions do
    %{
      frigate: %{
        can_pass_small: true,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 5_000_000
      },
      destroyer: %{
        can_pass_small: true,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 5_000_000
      },
      cruiser: %{
        can_pass_small: false,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 62_000_000
      },
      battlecruiser: %{
        can_pass_small: false,
        can_pass_medium: true,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 62_000_000
      },
      battleship: %{
        can_pass_small: false,
        can_pass_medium: false,
        can_pass_large: true,
        can_pass_xl: true,
        max_mass: 375_000_000
      },
      capital: %{
        can_pass_small: false,
        can_pass_medium: false,
        can_pass_large: false,
        can_pass_xl: true,
        max_mass: 1_800_000_000
      }
    }
  end

  # Ship type ID ranges
  defp frigate_ids do
    [
      587,
      588,
      589,
      590,
      591,
      592,
      593,
      594,
      596,
      597,
      598,
      599,
      11174,
      11176,
      11178,
      11180,
      11182,
      11184,
      11186,
      11188,
      11192,
      11194,
      11196,
      11198,
      11200,
      11202
    ]
  end

  defp destroyer_ids do
    [16219, 16227, 16236, 16242, 4302, 4306, 4308, 4310]
  end

  defp cruiser_ids do
    [
      621,
      622,
      623,
      624,
      625,
      626,
      627,
      628,
      629,
      630,
      11985,
      11987,
      11989,
      11993,
      12003,
      12005,
      12011,
      12015,
      29984,
      29986,
      29988,
      29990,
      22442,
      22444,
      22446,
      22448
    ]
  end

  defp battlecruiser_ids do
    [1201, 1202, 1203, 1204, 1205, 1206]
  end

  defp battleship_ids do
    [643, 644, 645, 646, 647, 648, 16231, 17738, 17740, 17918, 17920, 24688]
  end

  defp capital_ids do
    [
      19720,
      19722,
      19724,
      19726,
      23757,
      23911,
      23913,
      23915,
      # FAX ships
      37604,
      37605,
      37606,
      37607
    ]
  end

  defp supercapital_ids do
    # Supercarriers
    [
      3514,
      22852,
      23917,
      23919,
      # Titans
      671,
      3764,
      11567,
      23773
    ]
  end
end
