defmodule EveDmv.StaticData.ShipTypes do
  @moduledoc """
  Centralized ship type classification and data.

  This module provides a single source of truth for ship type IDs, classifications,
  and related data across the application. Ship type data should be loaded from
  EVE static data exports when available.
  """

  # TODO: These ranges are approximations and should be replaced with actual EVE static data
  # when the static data import system is implemented.

  @doc """
  Ship type ID ranges by class.

  Note: These are placeholder ranges and may not be completely accurate.
  They should be replaced with data from EVE's static data export.
  """
  def ship_type_ranges do
    %{
      frigate: [
        # T1 Frigates
        {580, 599},
        # Faction Frigates
        {600, 619},
        # T2 Frigates (Assault Ships, Interceptors, etc.)
        {11176, 11200}
      ],
      destroyer: [
        # T1 Destroyers
        {420, 439},
        # T2 Destroyers (Interdictors)
        {440, 459},
        # T3 Destroyers
        {32874, 32880}
      ],
      cruiser: [
        # T1 Cruisers
        {620, 639},
        # T2 Cruisers (HACs, HICs, Recons)
        {640, 659},
        # T3 Cruisers
        {29984, 30000},
        # Faction Cruisers
        {17634, 17740}
      ],
      battlecruiser: [
        # T1 Battlecruisers
        {540, 559},
        # T2 Battlecruisers (Command Ships)
        {560, 579},
        # Navy Battlecruisers
        {16227, 16240}
      ],
      battleship: [
        # T1 Battleships
        {640, 669},
        # T2 Battleships (Marauders, Black Ops)
        {670, 699},
        # Faction/Navy Battleships
        {17636, 17740}
      ],
      capital: [
        # Carriers
        {19720, 19730},
        # Dreadnoughts
        {19740, 19750},
        # Supercarriers
        {23757, 23774},
        # Titans (specific IDs)
        {3514, 3514},
        # Erebus
        {671, 671},
        # Avatar
        {11567, 11567},
        # Ragnarok
        {23773, 23773},
        # Leviathan
        {23913, 23913}
      ],
      industrial: [
        # T1 Industrials
        {648, 657},
        # T2 Industrials (Transport Ships)
        {12729, 12753},
        # Orca
        {28606, 28606},
        # Rorqual
        {28352, 28352}
      ],
      mining: [
        # Mining Barges
        {17476, 17480},
        # Exhumers
        {22544, 22548}
      ],
      supercapital: [
        # Erebus
        {3514, 3514},
        # Avatar variant
        {671, 671},
        # Avatar
        {11567, 11567},
        # Ragnarok
        {23773, 23773},
        # Leviathan
        {23913, 23913},
        # Supercarriers
        {23917, 23919},
        # Faction Titans
        {42241, 42246}
      ]
    }
  end

  @doc """
  Classify a ship by its type ID.

  Returns the ship class as an atom, or :unknown if not found.
  """
  def classify_ship_type(type_id) when is_integer(type_id) do
    Enum.find_value(ship_type_ranges(), fn {class, ranges} ->
      if Enum.any?(ranges, fn
           {min, max} -> type_id >= min and type_id <= max
           id when is_integer(id) -> type_id == id
         end) do
        class
      end
    end) || :unknown
  end

  def classify_ship_type(_), do: :unknown

  @doc """
  Check if a ship type ID belongs to a specific class.
  """
  def is_ship_class?(type_id, class) when is_atom(class) do
    classify_ship_type(type_id) == class
  end

  @doc """
  Get all ship type IDs for a specific class.

  Note: This returns ranges, not individual IDs.
  """
  def get_ship_ids_for_class(class) when is_atom(class) do
    Map.get(ship_type_ranges(), class, [])
  end

  @doc """
  Commonly used ship groups for tactical analysis.
  """
  def tactical_ship_groups do
    %{
      tackle: [:frigate, :destroyer],
      dps: [:cruiser, :battlecruiser, :battleship],
      support: [:cruiser, :battlecruiser],
      capital: [:capital, :supercapital],
      industrial: [:industrial, :mining]
    }
  end

  @doc """
  Check if a ship is typically used for tackling.
  """
  def is_tackle_ship?(type_id) do
    classify_ship_type(type_id) in [:frigate, :destroyer]
  end

  @doc """
  Check if a ship is typically a DPS platform.
  """
  def is_dps_ship?(type_id) do
    classify_ship_type(type_id) in [:cruiser, :battlecruiser, :battleship]
  end

  @doc """
  Check if a ship is a support vessel.
  """
  def is_support_ship?(type_id) do
    # This is simplified - in reality, support ships are determined by
    # their bonuses and typical fits (logistics, command ships, etc.)
    classify_ship_type(type_id) in [:cruiser, :battlecruiser]
  end

  @doc """
  Get interceptor ship type IDs.

  Interceptors are fast, agile frigates used for tackling and fleet scouting.
  """
  def interceptor_ship_ids do
    [11_182, 11_196]
  end

  @doc """
  Get logistics ship type IDs.

  Logistics ships provide remote repair capabilities to fleets.
  """
  def logistics_ship_ids do
    [11_978, 11_987, 11_985, 12_003]
  end

  @doc """
  Get electronic warfare ship type IDs.

  EWAR ships provide electronic disruption capabilities like jamming and dampening.
  """
  def ewar_ship_ids do
    [11_957, 11_958, 11_959, 11_961]
  end

  @doc """
  Check if a ship type ID is an interceptor.
  """
  def is_interceptor?(type_id) do
    type_id in interceptor_ship_ids()
  end

  @doc """
  Check if a ship type ID is a logistics ship.
  """
  def is_logistics?(type_id) do
    type_id in logistics_ship_ids()
  end

  @doc """
  Check if a ship type ID is an EWAR ship.
  """
  def is_ewar?(type_id) do
    type_id in ewar_ship_ids()
  end
end
