defmodule EveDmv.Intelligence.ShipDatabase.ShipClassification do
  @moduledoc """
  Ship classification data and utilities.

  Handles ship classes, categories, and type ID classifications for
  fleet analysis and ship identification.
  """

  @doc """
  Get ship class classification by ship type ID.
  """
  def get_ship_class(ship_type_id) when is_integer(ship_type_id) do
    ship_classes()[ship_type_id] || :unknown
  end

  @doc """
  Get ship class classification by ship name.
  """
  def get_ship_class_by_name(ship_name) when is_binary(ship_name) do
    ship_name_to_class()[ship_name] || :unknown
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
  def get_ship_category_by_name(ship_name) when is_binary(ship_name) do
    ship_name_to_category()[ship_name] || "Unknown"
  end

  @doc """
  Check if ship is a capital ship by type ID.
  """
  def is_capital?(ship_type_id) when is_integer(ship_type_id) do
    ship_type_id in (capital_ids() ++ supercapital_ids())
  end

  @doc """
  Check if ship is a capital ship by name.
  """
  def is_capital_by_name?(ship_name) when is_binary(ship_name) do
    category = get_ship_category_by_name(ship_name)
    category in ["Capital", "Supercapital"]
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
      16_219 => :destroyer,
      # Algos
      16_227 => :destroyer,
      # Catalyst
      16_236 => :destroyer,
      # Thrasher
      16_242 => :destroyer,

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
      29_984 => :strategic_cruiser,
      # Legion
      29_986 => :strategic_cruiser,
      # Proteus
      29_988 => :strategic_cruiser,
      # Loki
      29_990 => :strategic_cruiser,

      # Command Ships
      # Damnation
      22_442 => :command_ship,
      # Nighthawk
      22_444 => :command_ship,
      # Claymore
      22_446 => :command_ship,
      # Sleipnir
      22_448 => :command_ship,

      # Logistics
      # Guardian
      11_985 => :logistics,
      # Basilisk
      11_987 => :logistics,
      # Oneiros
      11_989 => :logistics,
      # Scimitar
      11_993 => :logistics,

      # Interceptors
      # Ares
      11_174 => :interceptor,
      # Stiletto
      11_176 => :interceptor,
      # Crow
      11_178 => :interceptor,
      # Malediction
      11_180 => :interceptor,

      # Capitals
      # Revelation
      19_720 => :dreadnought,
      # Naglfar
      19_722 => :dreadnought,
      # Moros
      19_724 => :dreadnought,
      # Phoenix
      19_726 => :dreadnought,
      # Archon
      23_757 => :carrier,
      # Chimera
      23_911 => :carrier,
      # Thanatos
      23_913 => :carrier,
      # Nidhoggur
      23_915 => :carrier,

      # Supercarriers
      # Nyx
      3514 => :supercarrier,
      # Aeon
      22_852 => :supercarrier,
      # Wyvern
      23_917 => :supercarrier,
      # Hel
      23_919 => :supercarrier,

      # Titans
      # Erebus
      671 => :titan,
      # Leviathan
      3764 => :titan,
      # Avatar
      11_567 => :titan,
      # Ragnarok
      23_773 => :titan
    }
  end

  defp ship_name_to_class do
    %{
      # Frigates
      "Rifter" => :frigate,
      "Punisher" => :frigate,
      "Merlin" => :frigate,
      "Incursus" => :frigate,

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
      "Myrmidon" => "Battlecruiser",

      # Capital Ships - Dreadnoughts
      "Revelation" => "Capital",
      "Naglfar" => "Capital",
      "Moros" => "Capital",
      "Phoenix" => "Capital",

      # Capital Ships - Carriers
      "Archon" => "Capital",
      "Chimera" => "Capital",
      "Thanatos" => "Capital",
      "Nidhoggur" => "Capital",

      # Capital Ships - Force Auxiliaries
      "Apostle" => "Capital",
      "Minokawa" => "Capital",
      "Ninazu" => "Capital",
      "Lif" => "Capital",

      # Supercarriers
      "Nyx" => "Supercapital",
      "Aeon" => "Supercapital",
      "Wyvern" => "Supercapital",
      "Hel" => "Supercapital",

      # Titans
      "Erebus" => "Supercapital",
      "Leviathan" => "Supercapital",
      "Avatar" => "Supercapital",
      "Ragnarok" => "Supercapital"
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
      11_174,
      11_176,
      11_178,
      11_180,
      11_182,
      11_184,
      11_186,
      11_188,
      11_192,
      11_194,
      11_196,
      11_198,
      11_200,
      11_202
    ]
  end

  defp destroyer_ids do
    [16_219, 16_227, 16_236, 16_242, 4302, 4306, 4308, 4310]
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
      11_985,
      11_987,
      11_989,
      11_993,
      12_003,
      12_005,
      12_011,
      12_015,
      29_984,
      29_986,
      29_988,
      29_990,
      22_442,
      22_444,
      22_446,
      22_448
    ]
  end

  defp battlecruiser_ids do
    [1201, 1202, 1203, 1204, 1205, 1206]
  end

  defp battleship_ids do
    [643, 644, 645, 646, 647, 648, 16_231, 17_738, 17_740, 17_918, 17_920, 24_688]
  end

  defp capital_ids do
    [
      19_720,
      19_722,
      19_724,
      19_726,
      23_757,
      23_911,
      23_913,
      23_915,
      # FAX ships
      37_604,
      37_605,
      37_606,
      37_607
    ]
  end

  defp supercapital_ids do
    # Supercarriers
    [
      3514,
      22_852,
      23_917,
      23_919,
      # Titans
      671,
      3764,
      11_567,
      23_773
    ]
  end
end
